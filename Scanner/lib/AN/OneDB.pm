package AN::OneDB;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;
use Const::Fast;
use Data::Dumper;
use DBI;

use File::Spec::Functions 'catdir';
use File::Basename;
use FindBin qw($Bin);
use POSIX 'strftime';
use YAML;

use AN::Unix;

const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

use Class::Tiny (qw( connect   dbh     dbconf  filename logdir node_args
                     node_table_id     owner   sth)) ;

sub BUILD {
    my $self = shift;
    my ($args) = @_;

    $self->startup( {from_build => 1} ) if $self->connect;
    $self->filename( catdir( $self->logdir,
			     'db.' . $PROG . '.alternate.' . $self->dbconf->{host}
		     ));
}

# ======================================================================
# CONSTANTS
#
const my $ID_FIELD         => 'id';
const my $SCANNER_USER_NUM => 0;

const my %DB_CONNECT_ARGS => ( AutoCommit         => 0,
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

                 );

# ======================================================================
# Subroutines
#

# ......................................................................
# Extend simple accessor to set & fetch a specific DBI sth
# corresponding to specified key.
#
sub connected {
    my $self = shift;

    return defined $self->dbh & 'DBI::db' eq ref $self->dbh;
}

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

# ......................................................................
# create new node table entry for this process.
#
sub log_new_process {
    my $self = shift;
    my (@args) = @_;

    my $sql = $SQL{New_Process};
    my ( $sth, $id ) = ( $self->get_sth($sql) );

    if ( !$sth ) {
	eval {
	    $sth = $self->dbh->prepare($sql)
		if $self->dbh->ping;;
	    $self->set_sth( $sql, $sth );
	};
	warn "DB error in log_new_process() @{[$DBI::errstr]}."
	    if $@;
    }
    eval {
	my $rows = $sth->execute(@args)
	    if $self->dbh->ping;
	if ( $rows ) {
	    $self->dbh->commit()
		if $self->dbh->ping;
	    $id = $self->dbh->last_insert_id( undef, undef, $DB_PROCESS_TABLE,
					      undef )
		if $self->dbh->ping;
	}
	else {
	    $self->dbh->rollback
		if $self->dbh->ping;
	}
    };
    warn "DB error in log_new_process() @{[$DBI::errstr]}."
	if $@;
    return $id;
}

# ......................................................................
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
    eval {
	$rows = $sth->execute( $self->node_table_id )
	    if $self->dbh->ping;
	
	if ( 0 < $rows ) {
	    $self->dbh->commit()
		if $self->dbh->ping;
	}
	else {
	    $self->dbh->rollback
		if $self->dbh->ping;
	}
    };
    warn "DB error in halt_process() @{[$DBI::errstr]}."
	if $@;
    return $rows;
}

# ......................................................................
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
    eval {
	$rows = $sth->execute( $self->node_table_id )
	    if $self->dbh->ping;

	if ( 0 < $rows ) {
	    $self->dbh()->commit()
		if $self->dbh->ping;
	}
	else {
	    $self->dbh()->rollback
		if $self->dbh->ping;
	}
    };
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
    eval {
	$rows = $sth->execute( $self->node_table_id )
	    if $self->dbh->ping;

	if ( 0 < $rows ) {
	    $self->dbh()->commit()
		if $self->dbh->ping;
	}
	else {
	    $self->dbh()->rollback
		if $self->dbh->ping;
	}
    };
    warn "DB error in start_process() @{[$DBI::errstr]}."
	if $@;
    return $rows;
}

# ......................................................................
# Private Methods
#
sub startup {
    my $self = shift;
    my ( $args ) = @_;
    
    $self->sth({});
    $self->connect_dbs();
    if (  $self->dbh ) { 
	$self->register_start( )
    }
    return;
}

sub connect_dbs {
    my $self = shift;

    $self->dbh( $self->connect_db( $self->dbconf ) );
    return;
}

sub connect_db {
    my $self = shift;
    my ( $args ) = @_;

    if ( ! 'HASH' eq ref $args
	 || !  exists $args->{host} ) {
	carp  "In ", __PACKAGE__, "::connect_db() arg is: ",
	      Data::Dumper::Dumper( [$args] ),

	return;
    }

    my $dsn = ( $args->{host} eq 'localhost'
                ? sprintf( $DSN_SHORT_FMT, $args->{name} )
                : sprintf( $DSN_FMT,       @{$args}{qw(name host port)} ) );
    my %args = %DB_CONNECT_ARGS;    # need to copy to avoid readonly error.

    my $dbh
	= eval { DBI->connect_cached( $dsn, $args->{user}, $args->{password},
				      \%args )};

    return $dbh;
}

sub register_start {
    my $self = shift;

    my $hostname = AN::Unix::hostname '-short';

    my ( $target_name, $target_ip, $target_type
	) = ( 'ARRAY' eq ref $self->node_args
	      ? @{$self->node_args}
	      : ( '', '', '' ) );
    $self->node_table_id( $self->log_new_process(
                              $PROG,            $hostname,         $PID,
                              $PROC_STATUS_NEW, $SCANNER_USER_NUM, $target_name,
                              $target_ip,       $target_type
                                                ) );
    $self->start_process();
}

# ......................................................................
# Methods
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
    } else {
        $newsql = $sql;
	$newsql =~ s{(\)\nVALUES)}{, timestamp $1}xms;
	$newsql =~ s{(\)\n)\z}
	{, timestamp with time zone 'epoch' + ? * interval '1 second'$1}xms;
	$cache{$sql} = $newsql;
    }
    push @$fields, 'timestamp';
    $args->{timestamp} = $timestamp;
    $args->{node_id} = $self->node_table_id;

    return $newsql;
}

sub fail_write {
    my $self = shift;
    my ( $sql, $fields, $args, $timestamp ) = @_;

    my ($pkg, $file, $line) = caller();
    $line--;

    say $DB_ERR, __PACKAGE__, "::failwrite() invoked due to error: \n",
    $DB_ERR, "'@{[$DBI::errstr]}' \n", $DB_ERR, "at line $line in $file."; 
    $self->startup();

    if ( $self->dbh() ) {
	$self->save_to_db( $sql, $fields, $args, $timestamp );
	return 1;
    }
    elsif ( $timestamp ) {
	$self->save_to_file( $sql, $fields, $args, $timestamp );
	return;
    }
}

sub save_to_db {
    my $self = shift;
    my ( $sql, $fields, $args, $timestamp ) = @_;

    $sql = $self->manual_timestamp( $sql, $fields, $args, $timestamp )
	if $timestamp;

    my $sth = $self->get_sth($sql);
    my ($ok, $id) = (1, undef);

    if ( !$sth ) {
	eval {
	    $sth = $self->dbh->prepare($sql)
		if $self->dbh->ping;
	    $self->set_sth( $sql, $sth );
	};
	$ok = $@ ? $self->fail_write( $sql, $fields, $args, $timestamp )
	    :      1;
	return unless $ok;
    }

    say Dumper ( [$sql, $fields, $args] )
	if grep { /\binsert_raw_record\b/ } ($ENV{VERBOSE} || '');

    # extract the hash values in the order specified by the array of
    # key names.
    my $rows = eval { $sth->execute( @{$args}{@$fields} ) }
	    if $self->dbh->ping;
    $ok = $self->fail_write( $sql, $fields, $args, $timestamp )
	if $@;
    return unless $ok;
    return 1 if $timestamp;	# Don't commit during bulkload

    eval {
	if ( $rows ) {
	    $self->dbh->commit()
		if $self->dbh->ping;
	    $id = $self->dbh->last_insert_id( undef, undef,
					      $DB_PROCESS_TABLE, undef )
		if $self->dbh->ping;
	}
	else {
	    $self->dbh->rollback
	    if $self->dbh->ping;
	}
    };
    $ok = $self->fail_write( $sql, $fields, $args, $timestamp )
	if $@;
    return unless $ok;
    return $id;
}

# Note, to convert epoch into Pg timestamp, use "SELECT TIMESTAMP WITH
# TIME ZONE 'epoch' + 982384720 * INTERVAL '1 second';" from section
# 9.9.1 of
# http://www.postgresql.org/docs/8.0/interactive/functions-datetime.html
#
sub save_to_file {
    my $self = shift;
    my ( $sql, $fields, $args ) = @_;

    my $str = YAML::Dump { sql    => $sql,
			   fields => $fields,
			   args   => $args,
			   epoch  => time(),
    };
    open my $fh, '>>', $self->filename
	or die( 'Could not open for append DB-alternate file ',
		"'@{[$self->filename]}'.\n$!" );
    say $fh $str;
    close $fh;

    return 1;
}
# Load data into DB, archive the file.
#
sub load_db_from_file {
    my $self = shift;

    return unless ref $self->dbh;     # no DBI:db to talk to.
    return unless -e $self->filename; # no file to load from.

    say "Loading DB @{[$self->dbconf()->{host}]} from @{[$self->filename]}."
	if $self->owner->verbose;
    

    my $load_succeeded = 1;
    eval {$self->save_to_db( @{$_}{qw( sql fields args epoch )} )
	      for YAML::LoadFile( $self->filename );
    };
    $load_succeeded = 0 if $@;	# error occured

    eval {
	if ( $load_succeeded ) {
	    $self->dbh->commit()
		if $self->dbh->ping;
	    rename $self->filename,
                $self->filename . '_@_' . strftime '%F_%T', localtime;
	    $self->filename(undef);
	}
	else {
	    $self->dbh->rollback()
		if $self->dbh->ping;
	    return if $@;
	}
    };
    return;
}

# If node table id is not pre-defined, it is specificed dynamically
# for each DB. In that case, delete the field from the args hash so it
# is similarly undefined for the other DBes.
#
sub insert_raw_record {
    my $self = shift;
    my ( $db_args ) = @_;

    if ( ! $self->dbh() ) {	# See if DB has come back.
	$self->startup();
	$self->load_db_from_file()
	    if $self->dbh();
    }

    my $node_table_name = $db_args->{with_node_table_id};
    my $dynamic_node_id = ! defined $db_args->{args}{$node_table_name};

    my ( $sql, $fields, $args ) = $self->generate_insert_sql($db_args);

    my $id = (  $self->dbh
		? $self->save_to_db( $sql, $fields, $args )
		: $self->save_to_file( $sql, $fields, $args )
	);
    # re-enable dynamic node_table_id
    #
    delete $db_args->{args}{$node_table_name}
        if $dynamic_node_id;

    return $id;
}

sub fail_read {
    my $self = shift;

    $self->owner()->switch_next_db;
}

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
and timestamp > now() - interval '2 minute'
ORDER BY timestamp asc

EOSQL

    return ( $sql, $node_table_id );
}

sub fetch_alert_data {
    my $self = shift;

    my ( $sql, $node_table_id ) = $self->generate_fetch_sql(@_);
    my ( $sth, $id )            = ( $self->get_sth($sql) );

    say Dumper ( [$sql, $node_table_id] )
        if grep { /\bfetch_alert_records\b/ } ($ENV{VERBOSE} || '');

    # prepare and archive sth unless it has already been done.
    #
    if ( ! $sth ) {
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

sub fetch_node_entries {
    my $self = shift;
    my ( $pids,  ) = @_;

    my ($nodes, @retval, $u );	# $u is undef

    if ( $self->dbh->ping ) {
	eval {
	    my $sql = $SQL{Node_Entries};
	    say $sql if $self->owner->verbose;
	    $nodes = $self->dbh->selectall_hashref( $sql, 'node_id', $u, $pids,
		AN::Unix::hostname('-short'));
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

sub fetch_alert_listeners {
    my $self = shift;

    my $sql = <<"EOSQL";

SELECT  *
FROM    alert_listeners

EOSQL

    my $records = eval {$self->dbh()->selectall_hashref( $sql, 'id' ) }
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

     Scanner.pm - System monitoring loop

=head1 VERSION

This document describes Scanner.pm version 0.0.1

=head1 SYNOPSIS

    use AN::Scanner;
    my $scanner = AN::Scanner->new();


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

=item B<agentdir>

The directory that is scanned for scanning plug-ins.

=item B<rate>

How often the loop should scan.

=back


=back

=head1 DEPENDENCIES

=over 4

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<version> I<core since 5.9.0>

Parses version strings.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<FileHandle> I<code>

Provides access to FileHandle / IO::* attributes.

=item B<FindBin> I<core>

Determine which directory contains the current program.

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
