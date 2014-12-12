package AN::OneDB;

# _Perl_
use warnings;
use strict;
use 5.014;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;

use FindBin qw($Bin);
use Const::Fast;

use AN::Unix;

# ======================================================================
# Object attributes.
#
const my @ATTRIBUTES => (qw( dbh path dbini sth node_table_id));

# Create an accessor routine for each attribute. The creation of the
# accessor is simply magic, no need to understand.
#
# 1 - Without 'no strict refs', perl would complain about modifying
# namespace.
#
# 2 - Update the namespace for this module by creating a subroutine
# with the name of the attribute.
#
# 3 - 'set attribute' functionality: When the accessor is called,
# extract the 'self' object. If there is an additional argument - the
# accessor was invoked as $obj->attr($value) - then assign the
# argument to the object attribute.
#
# 4 - 'get attribute' functionality: Return the value of the attribute.
#
for my $attr (@ATTRIBUTES) {
    no strict 'refs';    # Only within this loop, allow creating subs
    *{ __PACKAGE__ . '::' . $attr } = sub {
        my $self = shift;
        if (@_) { $self->{$attr} = shift; }
        return $self->{$attr};
        }
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

const my $DSN_SHORT_FMT       => 'dbi:Pg:dbname=%s';
const my $DSN_FMT             => 'dbi:Pg:dbname=%s:host=%s:port=%s';

const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];

const my $DB_PROCESS_TABLE => 'node';

const my $PROC_STATUS_NEW     => 'pre_run';
const my $PROC_STATUS_RUNNING => 'running';
const my $PROC_STATUS_HALTED  => 'halted';

# ======================================================================
# SQL
#
const my %SQL => (
    New_Process => <<"EOSQL",

INSERT INTO node
( node_name, node_description, pid, status, modified_user )
values
(  ?, ?, ?, ?, ? )

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
# Standard constructor. In subclasses, 'inherit' this constructor, but
# write a new _init()
#
sub new {
    my ( $class, @args ) = @_;

    my $obj = bless {}, $class;
    $obj->_init(@args);

    return $obj;
}

# ......................................................................
#
sub copy_from_args_to_self {
    my $self = shift;
    my (@args) = @_;

    if ( scalar @args > 1 ) {
        for my $i ( 0 .. $#args ) {
            my ( $k, $v ) = ( $args[$i], $args[ $i + 1 ] );
            $self->{$k} = $v;
        }
    }
    elsif ( 'HASH' eq ref $args[0] ) {
        @{$self}{ keys %{ $args[0] } } = values %{ $args[0] };
    }
    return;
}

# ......................................................................
#
sub _init {
    my $self = shift;

    $self->copy_from_args_to_self(@_);

    $self->sth( {} );    # init hash
    $self->connect_dbs();
    $self->_register_start();

    return;

}

sub DESTROY {
    my $self = shift;

    $self->_halt_process();
}

# ......................................................................
# Extend simple accessor to set & fetch a specific DBI sth
# corresponding to specified key.
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

# ......................................................................
# create new node table entry for this process.
#
sub _log_new_process {
    my $self = shift;
    my (@args) = @_;

    my $sql = $SQL{New_Process};
    my ( $sth, $id ) = ( $self->get_sth($sql) );

    if ( !$sth ) {
        $sth = $self->set_sth( $sql, $self->dbh->prepare($sql) );
    }
    my $rows = $sth->execute(@args);

    if ( 0 < $rows ) {
        $self->dbh->commit();
        $id = $self->dbh->last_insert_id( undef, undef, $DB_PROCESS_TABLE,
                                          undef );
    }
    else {
        $self->dbh->rollback;
    }
    return $id;
}

# ......................................................................
# Mark this process's node table entry as no longer running .
#
sub _halt_process {
    my $self = shift;

    my $sql = $SQL{Halt_Process};
    my ($sth) = $self->get_sth($sql);

    if ( !$sth ) {
        $sth = $self->set_sth( $sql, $self->dbh->prepare($sql) );
    }
    my $rows = $sth->execute( $self->node_table_id );

    if ( 0 < $rows ) {
        $self->dbh->commit();
    }
    else {
        $self->dbh->rollback;
    }
    return $rows;
}

# ......................................................................
# mark this process's node table entry as running.
#
sub _start_process {
    my $self = shift;

    my $sql = $SQL{Start_Process};
    my ($sth) = $self->get_sth($sql);

    if ( !$sth ) {
        $sth = $self->set_sth( $sql, $self->dbh()->prepare($sql) );
    }
    my $rows = $sth->execute( $self->node_table_id );

    if ( 0 < $rows ) {
        $self->dbh()->commit();
    }
    else {
        $self->dbh()->rollback;
    }
    return $rows;
}

# ......................................................................
# Private Methods
#
sub _connect_db {
    my ($args) = @_;

    my $dsn = ( $args->{host} eq 'localhost'
                ? sprintf( $DSN_SHORT_FMT, $args->{name} )
                : sprintf( $DSN_FMT,       @{$args}{qw(name host port)} ) );
    my %args = %DB_CONNECT_ARGS;    # need copy to avoid readonly error.

    my $dbh
        = DBI->connect_cached( $dsn, $args->{user}, $args->{password}, \%args )
        || die( sprintf( "Could not connect to DB %s on host %s: %s\n",
                         $args->db_name, $args->{host}, $DBI::errstr
                       ) );

    return $dbh;
}

sub _register_start {
    my ($self) = @_;

    my $hostname = AN::Unix::hostname '-short';

    $self->node_table_id(
                $self->_log_new_process( $PROG, $hostname, $PID, $PROC_STATUS_NEW, $SCANNER_USER_NUM ) );
    $self->_start_process();
}

# ......................................................................
# Methods
#
sub connect_dbs {
    my $self = shift;

    $self->dbh( _connect_db( $self->dbini ) );
}

sub dump_metadata {
    my $self = shift;
    my ($prefix) = @_;

    my $metadata = <<"EODUMP";
${prefix}::node_table_id=@{[$self->node_table_id]}
EODUMP

    chomp $metadata;		# discard final newline.
    return $metadata;
}

sub table_exists {
    my $self = shift;
    my ($name) = @_;

    my $exists
        = $self->dbh()->selectall_arrayref( $SQL{Table_Exists}, undef, $name )
        or die "Failed table_exist query for table '$name';", $DBI::errstr;
    return $exists && $exists->[0] && $exists->[0][0];
}

sub split_schema_row {
    my ( $record ) = @_;

    $record =~ s{,}{};
    my ($ref_spec) = [ split /\s+/, $record ];

    return $ref_spec;
}

sub field_name_matches {
    my ( $ref, $field ) = @_;
    
    return $ref->[0] eq $field->{column_name};
}

sub carp_field_name_mismatch {
    my ( $name, $position, $ref, $field) = @_;    

    carp __PACKAGE__
	. "::schema_matches($name), field # $position is '$field->{column_name}', should be '$ref->[0]'.\n";

    return;
}

sub field_type_matches {
    my ( $ref, $field ) = @_;

    my $matchesP = (
	$ref->[1] eq $field->{data_type}
	or (     $ref->[1] eq 'serial'
		 and $field->{data_type} eq 'integer'
		 and 0 == index $field->{column_default},
		 'nextval'
	)
	or (     $ref->[1] eq 'status'
		 and $field->{udt_name} eq 'status' )
	or ($ref->[1] eq 'timestamp'
	    and $field->{data_type} = 'timestamp with time zone' )
        );
    
    return $matchesP;
}
sub carp_field_type_mismatch {
    my ( $name, $position, $ref, $field) = @_;
    
            carp __PACKAGE__
                . "::schema_matches($name), field # $position '$field->{column_name}' has type '$field->{data_type}/$field->{udt_name}/$field->{column_default}' should be '@{$ref}[1..-1]'.";

    return;
}

sub fetch_schema {
    my $self = shift;
    my ( $name ) = @_;

    my $schema = $self->dbh()
        ->selectall_hashref( $SQL{Get_Schema}, 'ordinal_position', undef,
                             $name )
        or die "Failed to fetch schema for table '$name';", $DBI::errstr;

    return $schema;
}

sub schema_matches {
    my $self = shift;
    my ( $name, $ref_schema ) = @_;

    # skip empty lines.
    my @ref_schema = grep {/\w/} split "\n", $ref_schema;

    my $schema = $self->fetch_schema( $name );

    for my $position ( sort keys %$schema ) {
        my $field_spec = $schema->{$position};
	my $ref_spec = split_schema_row $ref_schema[ $position -1 ];
	
        field_name_matches( $ref_spec, $field_spec )
	    or do{  carp_field_name_mismatch( $name, $position, $ref_spec, $field_spec ),
		    return; };
        field_type_matches( $ref_spec, $field_spec )
	    or do { carp_field_type_mismatch( $name, $position, $ref_spec, $field_spec ),
		    return; };
    }
    return 1;
}

sub create_table {
    my $self = shift;
    my ( $name, $schema ) = @_;

    my $sql = "CREATE TABLE $name (\n$schema\n)";
    my $ok  = $self->dbh->do($sql);

    if ($ok) {
        $self->dbh()->commit();
    }
    else {
        $self->dbh()->rollback;
        carp "Failed to create table '$name' with schema'\n$schema'\n",
            $DBI::errstr;
    }
    return $ok;
}

sub generate_insert_sql {
    my $self = shift;
    my ($options) = @_;

    my $tablename         = $options->{table};
    my $node_table_id_ref = $options->{with_node_table_id} || '';
    my $args              = $options->{args};
    my @fields            = sort keys %$args;
    if ($node_table_id_ref) {
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

sub insert_raw_record {
    my $self = shift;

    my ( $sql, $fields, $args ) = $self->generate_insert_sql(@_);
    my ( $sth, $id ) = ( $self->get_sth($sql) );

    if ( !$sth ) {
        $sth = $self->set_sth( $sql, $self->dbh->prepare($sql) );
    }

    # extract the hash values in the order specified by the array of
    # key names.
    my $rows = $sth->execute( @{$args}{@$fields} );

    if ( 0 < $rows ) {
        $self->dbh->commit();
        $id = $self->dbh->last_insert_id( undef, undef, $DB_PROCESS_TABLE,
                                          undef );
    }
    else {
        $self->dbh->rollback;
    }
    return $id;
}

sub generate_fetch_sql {
    my $self = shift;
    my ($options) = @_;

    my ($db_key)      = grep { $_ ne 'schema' } keys %$options;
    my ($db_ident)    = grep {/\b\d+\b/} keys %{ $options->{$db_key} };
    my $db_info       = $options->{$db_key}{$db_ident};

    my $tablename     = $options->{$db_key}{datatable_name};
    my $node_table_id = $db_info->{node_table_id};

    my $sql = <<"EOSQL";
SELECT *, round( extract( epoch from age( now(), timestamp ))) as age
FROM $tablename
WHERE node_id = ?
ORDER BY timestamp desc
limit 4;
EOSQL

    return ($sql, $node_table_id);
}

sub fetch_agent_data {
    my $self = shift;

    my ( $sql, $node_table_id ) = $self->generate_fetch_sql(@_);
    my ( $sth, $id )            = ( $self->get_sth($sql) );

    # prepare and archive sth unless it has already been done.
    #
    $sth ||= $self->set_sth( $sql, $self->dbh->prepare($sql) );

    # extract the hash values in the order specified by the array of
    # key names.
    my $rows = $sth->execute( $node_table_id )
	|| carp "No rows returns for query \n'$sql'\n";
    my $records  = $sth->fetchall_hashref( $ID_FIELD );

    if ( 0 < $rows ) {
        $self->dbh->commit();
    }
    else {
        $self->dbh->rollback;
    }
    return $records;

}

sub fetch_alert_listeners {
    my $self = shift;

    my $sql = <<"EOSQL";

SELECT  *
FROM    alert_listeners

EOSQL

    my $records = $self->dbh()->selectall_hashref( $sql, 'id' )
	or die "Failed to fetch alert listeners.";

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
## Please see file perltidy.ERR
## Please see file perltidy.ERR
