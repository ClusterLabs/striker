package AN::OneDB;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Carp;
use Const::Fast;
use Data::Dumper;
use DBI;
use English '-no_match_vars';
use File::Basename;
use File::Spec::Functions 'catdir';
use POSIX 'strftime';
use YAML;

use AN::Unix;

# ======================================================================
# CLASS ATTRIBUTES & CONSTRUCTOR
#
const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

use Class::Tiny (
    qw( connect   dbh     dbconf  filename logdir node_args
        node_table_id     owner   sth) );

sub BUILD {
    my $self = shift;
    my ($args) = @_;

    $self->startup( { from_build => 1 } ) if $self->connect;
    $self->filename(
                   catdir( $self->logdir,
                           'db.' . $PROG . '.alternate.' . $self->dbconf->{host}
                         ) );
}

# ======================================================================
# CONSTANTS
#
const my $ID_FIELD         => 'id';
const my $SCANNER_USER_NUM => 0;

const my %DB_CONNECT_ARGS => ( AutoCommit         => 1,
                               RaiseError         => 1,
                               PrintError         => 0,
                               dbi_connect_method => undef );

const my $DSN_SHORT_FMT => 'dbi:Pg:dbname=%s';
const my $DSN_FMT       => 'dbi:Pg:dbname=%s;host=%s;port=%s';

const my $DB_PROCESS_TABLE => 'node';

const my $PROC_STATUS_NEW     => 'pre_run';
const my $PROC_STATUS_RUNNING => 'running';
const my $PROC_STATUS_HALTED  => 'halted';

const my $DB_ERR => 'DB error => ';

# ======================================================================
# SQL
#
const my %SQL => (
    New_Process => <<"EOSQL",

INSERT INTO node
( agent_name, agent_host, pid, status, modified_user,
  target_name, target_ip, target_type )
values
(  ?, ?, ?, ?, ?, ?, ?, ? )

EOSQL

    Node_Entries => <<"EOSQL",

SELECT node_id, agent_name, agent_host, pid, 
       round( extract( epoch from age( now(), modified_date ))) as age
FROM   node
WHERE  pid = any ( ? )
AND    agent_host = ?
ORDER BY modified_date desc

EOSQL

    Start_Process => <<"EOSQL",

UPDATE node
SET    status    = '$PROC_STATUS_RUNNING',
       modified_date = now()
WHERE  node_id = ?

EOSQL

    Halt_Process => <<"EOSQL",

UPDATE node
SET    status  = '$PROC_STATUS_HALTED',
       modified_date = now()
WHERE  node_id = ?

EOSQL

    Table_Exists => <<"EOSQL",

SELECT EXISTS (
    SELECT 1
    FROM   pg_tables
    WHERE  schemaname = 'public'
    AND    tablename  = ?
)

EOSQL

    Get_Schema => <<"EOSQL",

SELECT	column_name, data_type,       udt_name,
        is_nullable, column_default , ordinal_position
FROM	information_schema.columns
WHERE	table_name = ?
ORDER BY ordinal_position

EOSQL

    I_am_dying => <<"EOSQL",

INSERT INTO alerts
( node_id, target_name, target_type, target_extra,      field,
  value,   status,      message_tag, message_arguments)
VALUES
( ?, ?, ?, ?, ?, ?, ?, ?, ? )

EOSQL

    Node_Server_Status => <<"EOSQL",

SELECT   *, round( extract( epoch from age( now(), timestamp ))) as age
FROM     alerts
WHERE    message_tag = 'NODE_SERVER_STATUS'
AND      value = ?
ORDER BY timestamp desc
LIMIT    1

EOSQL

    Auto_Boot => <<"EOSQL",
SELECT   *, round( extract( epoch from age( now(), timestamp ))) as age
FROM     alerts
WHERE    message_tag = 'AUTO_BOOY'
AND      value = ?
ORDER BY timestamp desc
LIMIT    1

EOSQL
                 );

# ======================================================================
# Methods
#

# ----------------------------------------------------------------------
# Extend simple accessor to set & fetch a specific DBI sth
# corresponding to specified key.
#
sub connected {
    my $self = shift;

    return defined $self->dbh & 'DBI::db' eq ref $self->dbh;
}

# ----------------------------------------------------------------------
# Set and retrieve map from SQL string ==> DBI::sth for that string.
#
sub set_sth {
    my $self = shift;
    my ( $key, $value ) = @_;

    $self->sth->{$key} = $value;
    return $value;
}

sub get_sth {
    my $self = shift;
    my ($key) = @_;

    return $self->sth->{$key} || undef;
}

# ----------------------------------------------------------------------
# Create new node table entry for this process.
#
sub log_new_process {
    my $self = shift;
    my (@args) = @_;

    my $sql = $SQL{New_Process};
    my ( $sth, $id ) = ( $self->get_sth($sql) );

    if ( !$sth ) {
        eval {
            $sth = $self->dbh->prepare($sql)
                if $self->dbh->ping;
            $self->set_sth( $sql, $sth );
        };
        warn "DB error in log_new_process() @{[$DBI::errstr]}."
            if $@;
    }
    eval {
        my $rows = $sth->execute(@args)
            if $self->dbh->ping;
        $id
            = $self->dbh->last_insert_id( undef, undef, $DB_PROCESS_TABLE,
                                          undef )
            if $self->dbh->ping;
    };
    warn "DB error in log_new_process() @{[$DBI::errstr]}."
        if $@;
    return $id;
}

# ----------------------------------------------------------------------
# Create an alerts table record to report dying server.
#
sub tell_db_Im_dying {
    my $self = shift;

    my $sql = $SQL{I_am_dying};
    my ( $sth, $id ) = ( $self->get_sth($sql) );

    eval { $sth = $self->dbh->prepare($sql); };
    warn "DB error in tell_db_Im_dying() @{[$DBI::errstr]}."
        if $@;

    my $hostname = AN::Unix::hostname('-short');
    my @args = ( $self->node_table_id, 'scanner', $hostname, $PID,
                 'shutdown', 'shutting down', 'DEAD',
                 'NODE_SERVER_STATUS', "host=$hostname" );
    eval { my $rows = $sth->execute(@args); };
    warn "DB error in tell_db_Im_dying() @{[$DBI::errstr]}."
        if $@;
    return;
}

# ----------------------------------------------------------------------
# Mark this process's node table entry as no longer running .
#
sub halt_process {
    my $self = shift;

    my $sql = $SQL{Halt_Process};
    my ($sth) = $self->get_sth($sql);

    if ( !$sth ) {
        eval {
            $sth = $self->dbh->prepare($sql)
                if $self->dbh->ping;
            $self->set_sth( $sql, $sth );
        };
        warn "DB error in halt_process() @{[$DBI::errstr]}."
            if $@;
    }
    my $rows;
    eval { $rows = $sth->execute( $self->node_table_id ) if $self->dbh->ping; };
    warn "DB error in halt_process() @{[$DBI::errstr]}."
        if $@;
    return $rows;
}

# ----------------------------------------------------------------------
# mark this process's node table entry as running.
#
sub start_process {
    my $self = shift;

    my $sql = $SQL{Start_Process};
    my ($sth) = $self->get_sth($sql);

    if ( !$sth ) {
        eval {
            $sth = $self->dbh()->prepare($sql)
                if $self->dbh->ping;
            $self->set_sth( $sql, $sth );
        };
        warn "DB error in start_process() @{[$DBI::errstr]}."
            if $@;
    }
    my $rows;
    eval { $rows = $sth->execute( $self->node_table_id ) if $self->dbh->ping; };
    warn "DB error in start_process() @{[$DBI::errstr]}."
        if $@;
    return $rows;
}

# ......................................................................
# mark this process's node table entry as running.
#
sub finalize_node_table_status {
    my $self = shift;

    my $sql = $SQL{Halt_Process};
    my ($sth) = $self->get_sth($sql);

    if ( !$sth ) {
        eval {
            $sth = $self->dbh()->prepare($sql)
                if $self->dbh->ping;
            $self->set_sth( $sql, $sth );
        };
        warn "DB error in start_process() @{[$DBI::errstr]}."
            if $@;
    }
    my $rows;
    eval { $rows = $sth->execute( $self->node_table_id ) if $self->dbh->ping; };
    warn "DB error in start_process() @{[$DBI::errstr]}."
        if $@;
    return $rows;
}

# ----------------------------------------------------------------------
# Connect to database and create a node table entry. Reset sth cache.
#
sub startup {
    my $self = shift;
    my ($args) = @_;

    $self->sth( {} );
    $self->dbh( $self->connect_db( $self->dbconf ) );
    if ( $self->dbh ) {
        $self->register_start();
    }
    return;
}

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
# Connect to database.
#
sub connect_db {
    my $self = shift;
    my ($args) = @_;

    if (    !'HASH' eq ref $args
         || !exists $args->{host} ) {
        carp "In ", __PACKAGE__, "::connect_db() arg is: ",
            Data::Dumper::Dumper( [$args] ),

            return;
    }

    my $dsn = ( $args->{host} eq 'localhost'
                ? sprintf( $DSN_SHORT_FMT, $args->{name} )
                : sprintf( $DSN_FMT,       @{$args}{qw(name host port)} ) );
    my %args = %DB_CONNECT_ARGS;    # need to copy to avoid readonly error.

    my $dbh = eval {
        DBI->connect_cached( $dsn, $args->{user}, $args->{password}, \%args );
    };

    return $dbh;
}

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
# Create node table entry for process and save the node table id.
#
sub register_start {
    my $self = shift;

    my $hostname = AN::Unix::hostname '-short';

    my ( $target_name, $target_ip, $target_type )
        = ( 'ARRAY' eq ref $self->node_args
            ? @{ $self->node_args }
            : ( '', '', '' ) );
    $self->node_table_id( $self->log_new_process(
                              $PROG,            $hostname,         $PID,
                              $PROC_STATUS_NEW, $SCANNER_USER_NUM, $target_name,
                              $target_ip,       $target_type
                                                ) );
    $self->start_process();
}

# ----------------------------------------------------------------------
# Report node table id for this database connection, for reporting to
# scanCore component.
#
sub dump_metadata {
    my $self = shift;
    my ($prefix) = @_;

    my $metadata = <<"EODUMP";
${prefix}::node_table_id=@{[$self->node_table_id]}
EODUMP

    chomp $metadata;    # discard final newline.
    return $metadata;
}

# ----------------------------------------------------------------------
# Generate SQL for insert_raw_record. Returns the SQL, a hash of field
# names and the value to return for that field, and an array of field
# names to define the order in which to provide the values.
#
sub generate_insert_sql {
    my $self = shift;
    my ($options) = @_;

    my $tablename         = $options->{table};
    my $node_table_id_ref = $options->{with_node_table_id} || '';
    my $args              = $options->{args};
    my @fields            = sort keys %$args;

    if ( $node_table_id_ref
         && not $args->{$node_table_id_ref} ) {
        push @fields, $node_table_id_ref;
        $args->{$node_table_id_ref} = $self->node_table_id;
    }
    my $fieldlist = join ', ', @fields;
    my $placeholders = join ', ', ('?') x scalar @fields;

    my $sql = <<"EOSQL";
INSERT INTO $tablename
($fieldlist)
VALUES
($placeholders)
EOSQL

    return ( $sql, \@fields, $args );
}

# ----------------------------------------------------------------------
# When a record was saved to file, due to the database being
# unavailable, the current time was archived as well. Modify the SQL,
# field list and values to include that timestamp. A archive file will
# contain a few varieties of SQL, with many occurences of each. So
# archive the converted SQL, to replace text modification with simple
# text lookup.
#
sub manual_timestamp {
    my $self = shift;
    my ( $sql, $fields, $args, $timestamp ) = @_;

    # nothing to do if timestamp is already in the fields list.
    #
    return $sql if -1 < index $sql, ', timestamp';

    state %cache;

    # Nope, gotta get things dirty.
    #
    my $newsql;
    if ( $cache{$sql} ) {
        $newsql = $cache{$sql};
    }
    else {
        $newsql = $sql;
        $newsql =~ s{(\)\nVALUES)}{, timestamp $1}xms;
        $newsql =~ s{(\)\n)\z}
	{, timestamp with time zone 'epoch' + ? * interval '1 second'$1}xms;
        $cache{$sql} = $newsql;
    }
    push @$fields, 'timestamp';
    $args->{timestamp} = $timestamp;
    $args->{node_id}   = $self->node_table_id;

    return $newsql;
}

# ----------------------------------------------------------------------
# Attempt to restart connection to database. If it succeeds, save the
# record to the database, otherwise save it to file.
#
sub fail_write {
    my $self = shift;
    my ( $sql, $fields, $args, $timestamp ) = @_;

    my ( $pkg, $file, $line ) = caller();
    $line--;

    say $DB_ERR, __PACKAGE__, "::failwrite() invoked due to error: \n",
        $DB_ERR, "'@{[$DBI::errstr]}' \n", $DB_ERR, "at line $line in $file.";
    $self->startup();

    if ( $self->dbh() ) {
        $self->save_to_db( $sql, $fields, $args, $timestamp );
        return 1;
    }
    elsif ($timestamp) {
        $self->save_to_file( $sql, $fields, $args, $timestamp );
        return;
    }
}

# ----------------------------------------------------------------------
# Save the record to the database.
#
sub save_to_db {
    my $self = shift;
    my ( $sql, $fields, $args, $timestamp ) = @_;

    $sql = $self->manual_timestamp( $sql, $fields, $args, $timestamp )
        if $timestamp;

    my $sth = $self->get_sth($sql);
    my ( $ok, $id ) = ( 1, undef );

    if ( !$sth ) {
        eval {
            $sth = $self->dbh->prepare($sql)
                if $self->dbh->ping;
            $self->set_sth( $sql, $sth );
        };
        $ok
            = $@
            ? $self->fail_write( $sql, $fields, $args, $timestamp )
            : 1;
        return unless $ok;
    }

    say Dumper ( [ $sql, $fields, $args ] )
        if grep {/\binsert_raw_record\b/} ( $ENV{VERBOSE} || '' );

    # extract the hash values in the order specified by the array of
    # key names.
    my $rows = eval { $sth->execute( @{$args}{@$fields} ) }
        if $self->dbh->ping;
    $ok = $self->fail_write( $sql, $fields, $args, $timestamp )
        if $@;
    return unless $ok;
    return 1 if $timestamp;    # Don't need record id during bulkload

    eval {
        $id
            = $self->dbh->last_insert_id( undef, undef, $DB_PROCESS_TABLE,
                                          undef )
            if $self->dbh->ping;
    } if $rows;

    $ok = $self->fail_write( $sql, $fields, $args, $timestamp )
        if $@;
    return unless $ok;
    return $id;
}

# ----------------------------------------------------------------------
# Note, to convert epoch into Pg timestamp, use "SELECT TIMESTAMP WITH
# TIME ZONE 'epoch' + 982384720 * INTERVAL '1 second';" from section
# 9.9.1 of
# http://www.postgresql.org/docs/8.0/interactive/functions-datetime.html
#
# Save record to file, since DB is not available.
#
sub save_to_file {
    my $self = shift;
    my ( $sql, $fields, $args ) = @_;

    my $str = YAML::Dump { sql    => $sql,
                           fields => $fields,
                           args   => $args,
                           epoch  => time(), };
    open my $fh, '>>',
        $self->filename
        or die( 'Could not open for append DB-alternate file ',
                "'@{[$self->filename]}'.\n$!" );
    say $fh $str;
    close $fh;

    return 1;
}

# ----------------------------------------------------------------------
# Load data into DB, archive the file.
#
sub load_db_from_file {
    my $self = shift;

    return unless ref $self->dbh;        # no DBI:db to talk to.
    return unless -e $self->filename;    # no file to load from.

    say "Loading DB @{[$self->dbconf()->{host}]} from @{[$self->filename]}."
        if $self->owner->verbose;

    my $load_succeeded = 1;
    eval {
        $self->save_to_db( @{$_}{qw( sql fields args epoch )} )
            for YAML::LoadFile( $self->filename );
    };
    $load_succeeded = 0 if $@;           # error occured

    if ($load_succeeded) {
        rename $self->filename,
            $self->filename . '_@_' . strftime '%F_%T', localtime;
        $self->filename(undef);
    }
    return;
}

# ----------------------------------------------------------------------
# If node table id is not pre-defined, it is specificed dynamically
# for each DB. In that case, delete the field from the args hash so it
# is similarly undefined for the other DBes.
#
sub insert_raw_record {
    my $self = shift;
    my ($db_args) = @_;

    if ( !$self->dbh() ) {    # See if DB has come back.
        $self->startup();
        $self->load_db_from_file()
            if $self->dbh();
    }

    my $node_table_name = $db_args->{with_node_table_id};
    my $dynamic_node_id = !defined $db_args->{args}{$node_table_name};

    my ( $sql, $fields, $args ) = $self->generate_insert_sql($db_args);

    my $id = (   $self->dbh
               ? $self->save_to_db( $sql, $fields, $args )
               : $self->save_to_file( $sql, $fields, $args ) );

    # re-enable dynamic node_table_id
    #
    delete $db_args->{args}{$node_table_name}
        if $dynamic_node_id;

    return $id;
}

# ----------------------------------------------------------------------
# Was unable to read from database. AN::DBS::switch_next_db() actually
# restarts the entire program.
#
sub fail_read {
    my $self = shift;

    warn __PACKAGE__, "::failread called from ", join ' ', caller(), "\n";
    $self->owner()->switch_next_db;
}

# ----------------------------------------------------------------------
# generate SQL to fetch current records from a particular database table.
#
sub generate_fetch_sql {
    my $self = shift;
    my ($options) = @_;

    my ($db_data)  = $options->{db_data};
    my ($db_ident) = grep {/\b\d+\b/} keys %$db_data;
    my $db_info    = $db_data->{$db_ident};

    my $tablename     = $db_data->{datatable_name};
    my $node_table_id = $db_info->{node_table_id};

    my $sql = <<"EOSQL";
SELECT *, round( extract( epoch from age( now(), timestamp ))) as age
FROM $tablename
WHERE node_id = ?
and timestamp > now() - interval '60 seconds'
ORDER BY timestamp desc

EOSQL

    return ( $sql, $node_table_id );
}

# ----------------------------------------------------------------------
# Fetch records from alerts table.
#
sub fetch_alert_data {
    my $self = shift;

    my ( $sql, $node_table_id ) = $self->generate_fetch_sql(@_);
    my ( $sth, $id )            = ( $self->get_sth($sql) );

    say Dumper ( [ $sql, $node_table_id ] )
        if grep {/\bfetch_alert_records\b/} ( $ENV{VERBOSE} || '' );

    # prepare and archive sth unless it has already been done.
    #
    if ( !$sth ) {
        eval {
            $sth = $self->dbh->prepare($sql)
                if $self->dbh->ping;
            $self->set_sth( $sql, $sth );
        };
        $self->fail_read() if $@;
    }

    # extract the hash values in the order specified by the array of
    # key names.

    my ( $records, $rows ) = (-1);
    eval {
        $rows = eval { $sth->execute($node_table_id) }
            if $self->dbh->ping;
        $records = eval { $sth->fetchall_hashref($ID_FIELD) }
            if $self->dbh->ping;
    };
    $self->fail_read()
        if $@ || -1 == $records;
    return $records;
}

# ----------------------------------------------------------------------
# Fetch records from database using a predefined SQL.
#
sub generic_fetch {
    my $self = shift;
    my ( $sql_tag, $verbose, $args ) = @_;

    my $sql = $SQL{$sql_tag};
    my ( $sth, $id ) = ( $self->get_sth($sql) );

    if ($verbose) {
        my $caller_sub = ( caller(1) )[3];
        say __PACKAGE__, "::${caller_sub} for $sql_tag uses:\n",
            @{ [ Dumper( [$sql] ) ] }
            if $verbose;
    }

    # prepare and archive sth unless it has already been done.
    #
    if ( !$sth ) {
        eval {
            $sth = $self->dbh->prepare($sql)
                if $self->dbh->ping;
            $self->set_sth( $sql, $sth );
        };
        $self->fail_read() if $@;
    }

    # extract the hash values in the order specified by the array of
    # key names.

    my ( $records, $rows ) = (-1);
    $args ||= [];    # if no args provide, need an empty array
    eval {
        $rows    = eval { $sth->execute(@$args) };
        $records = eval { $sth->fetchall_hashref($ID_FIELD) };
    };
    $self->fail_read()
        if $@ || !defined $records || -1 == $records;
    return $records;
}

# ----------------------------------------------------------------------
# Fetch AUTO_BOOT and NODE_SERVER_STATUS records from the alerts table.
#
sub check_node_server_status {
    my $self = shift;
    my ($ns_host) = @_;

    state $verbose
        = grep {/\bcheck node server status\b/} ( $ENV{VERBOSE} || '' );

    my @results;
    for my $tag ( 'Auto_Boot', 'Node_Server_Status' ) {
        my $records = $self->generic_fetch( $tag, $verbose, [$ns_host] );
        my @keys = sort { $b <=> $a } keys %$records
            if 'HASH' eq ref $records;
        push @results, $records->{ $keys[0] } if @keys;
    }
    return \@results;
}

# ----------------------------------------------------------------------
# Fetch node table entries.
#
sub fetch_node_entries {
    my $self = shift;
    my ($pids) = @_;

    my ( $nodes, @retval, $u );    # $u is undef

    if ( $self->dbh->ping ) {
        eval {
            my $sql = $SQL{Node_Entries};
            $nodes = $self->dbh->selectall_hashref( $sql, 'node_id', $u, $pids,
                                                 AN::Unix::hostname('-short') );
        };
        $self->fail_read
            if $@ || 'HASH' ne ref $nodes;

        for my $tag ( keys %$nodes ) {
            push @retval, $nodes->{$tag}
                unless 'scanner' eq $nodes->{$tag}->{agent_name};
        }
    }
    return \@retval;
}

# ----------------------------------------------------------------------
# Fetch all records from alert listeners table ( there aren't many).
#
sub fetch_alert_listeners {
    my $self = shift;

    my $sql = <<"EOSQL";

SELECT  *
FROM    alert_listeners

EOSQL

    my $records = eval { $self->dbh()->selectall_hashref( $sql, 'id' ) }
        if $self->dbh->ping;

    die "Failed to fetch alert listeners."
        if $@;
    return $records;
}

# ----------------------------------------------------------------------
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     AN::OneDB.pm - Class to handle queries to one database.

=head1 VERSION

This document describes AN::OneDB.pm version 1.0.0

=head1 SYNOPSIS

    use AN::OneDB;
    my $onedb_args = { dbconf    => $self->dbconf->{$tag},
                       node_args => $self->node_args,
                       connect   => $connect_flag,
                       owner     => $self,
                       logdir    => $self->logdir, };
    my $oneDB = AN::OneDB->new($onedb_args);
    $onedb->insert_raw_record();
    $onedb->fetch_alert_data();
    $onedb->check_node_server_status();
    $onedb->fetch_node_entries();
    $onedb->fetch_alert_listeners();
    $onedb->tell_db_Im_dying();
    $onedb->finalize_node_table_status();

=head1 DESCRIPTION

This module provides the Scanner program implementation. It monitors a
HA system to ensure the system is working properly.

=head1 METHODS

An object of this class represents a scanner object.

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<dbconf>

Contents of the db.conf file, we need type of database, the database
within the server, and the user name and password, as well as the host
name or IP number.

=item B<node_args>

Optional reference to array which contains, in order: $target_name,
$target_ip, $target_type.

=item B<connect>

Flag to indicate whether connection should be made immediately or
deferred.

=item B<owner>

Reference to the owner object. Used to notify the system if a database
connection fails.

=item B<logdir>

Directory in which to archive queries which cannot be written due to a
failed database.

=back

=item B<insert_raw_record>

Insert a record into specified table.  User provides field list and
associated values. Code assumes presence of a timestamp field.

If node table id is not pre-defined, it is specificed dynamically
for each DB. In that case, delete the field from the args hash so it
is similarly undefined for the other DBes.

=item B<fetch_alert_data>

Fetch records from alerts table which are less than 1 minute old..

=item B<check_node_server_status>

Fetch AUTO_BOOT and NODE_SERVER_STATUS records from the alerts table.

=item B<fetch_node_entries>

Fetch all records from the node table which match a set of specified
process ids running on the current host. Used by the scanCore to
locate the agents it has spawned.

=item B<fetch_alert_listeners>

Select all records from the alert_listeners table.

=item B<tell_db_Im_dying>

Insert a record in the alerts table reporting that the server is being
shut down.

=item B<finalize_node_table_status>

Set the node table entry for the current process to a final, 'halted'
state.

=back

=head1 DEPENDENCIES

=over 4

=item B<Carp> I<core>

Report errors as occuring at the caller site.

=item B<Const::Fast>

Provide fast constants.

=item B<Data::Dumper> I<core>

Used to display records and variables in log messages.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<File::Spec::Functions> I<code>

Portably perform operations on file names.

=item B<POSIX> I<core>

Provide date-time formatting routine C<strftime>.

=item B<YAML>

Text archive SQL, field llist, data value hashes, when a database
becomes unavailable.

=item B<version> I<core>

Parses version strings.

=back

=head1 LICENSE AND COPYRIGHT

This program is part of Aleeve's Anvil! system, and is released under
the GNU GPL v2+ license.

=head1 BUGS AND LIMITATIONS

We don't yet know of any bugs or limitations. Report problems to 

    Alteeve's Niche!  -  https://alteeve.ca

No warranty is provided. Do not use this software unless you are
willing and able to take full liability for it's use. The authors take
care to prevent unexpected side effects when using this
program. However, no software is perfect and bugs may exist which
could lead to hangs or crashes in the program, in your cluster and
possibly even data loss.

=begin unused

=head1  INCOMPATIBILITIES

There are no current incompatabilities.


=head1 CONFIGURATION

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 REQUIRED ARGUMENTS

=head1 USAGE

=end unused

=head1 AUTHOR

Alteeve's Niche!  -  https://alteeve.ca

Tom Legrady       -  tom@alteeve.ca	November 2014

=cut

# End of File
# ======================================================================
