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
const my $ASSIGN   => q{=};
const my $COMMA    => q{,};
const my $COLON    => q{:};
const my $DOTSLASH => q{./};

const my $DB_NAME => 'Pg';
const my %DB_CONNECT_ARGS => ( AutoCommit         => 0,
                               RaiseError         => 1,
                               PrintError         => 0,
                               dbi_connect_method => undef );

const my $DSN_SHORT_FMT       => 'dbi:Pg:dbname=%s';
const my $DSN_FMT             => 'dbi:Pg:dbname=%s:host=%s:port=%s';
const my $DATASOURCES_ARG_FMT => 'port=%s;host=%s';
const my $DEFAULT_PW          => 'alteeve';

const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];
const my $READ_PROC  => q{-|};
const my $WRITE_PROC => q{|-};
const my $SLASH      => q{/};
const my $EP_TIME_FMT => '%8.3f:%8.3f mSec';    # elapsed:pending time format

const my $DB_PROCESS_TABLE => 'node';

const my $PROC_STATUS_NEW     => 'pre_run';
const my $PROC_STATUS_RUNNING => 'running';
const my $PROC_STATUS_HALTED  => 'halted';

const my $EXTRACT_NUMBER_FROM_SELF => qr{			# regex to extrac hex number from
				# a "$self" string
          .*                    # any string,
	  \( 			# literal opening parenthesis
          0x                    # 0x to indicate hex value
          (                     # capture the hex  value
          \w+			# any digits, letters or underscore, but really
                                # will only see hex digits here.
          )                     # stop capturing
          \).*                  # closing paren, possible additional junk
         }xms;

# ----------------------------------------------------------------------
# SQL
#
const my %SQL => (
    New_Process => <<"EOSQL",

INSERT INTO node
( node_name, node_description, status, modified_user )
values
(  ?, ?, ?, $< )

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
sub _init {
    my ( $self, @args ) = @_;

    if ( scalar @args > 1 ) {
        for my $i ( 0 .. $#args ) {
            my ( $k, $v ) = ( $args[$i], $args[ $i + 1 ] );
            $self->{$k} = $v;
        }
    }
    elsif ( 'HASH' eq ref $args[0] ) {
        @{$self}{ keys %{ $args[0] } } = values %{ $args[0] };
    }
    $self->sth( {} );    # init hash
    $self->connect_dbs();
    $self->_register_start();

    return;

}

sub DESTROY {
    my $self = shift;

    $self->_halt_process();
}

sub get_sth {
    my $self = shift;
    my ($key) = @_;

    return $self->sth->{$key} || undef;
}

sub set_sth {
    my $self = shift;
    my ( $key, $value ) = @_;

    $self->sth->{$key} = $value;
    return $value;
}

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
# Private Accessors
#

sub connect_dbs {
    my $self = shift;

    $self->dbh( _connect_db( $self->dbini ) );
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
                $self->_log_new_process( $PROG, $hostname, $PROC_STATUS_NEW ) );
    $self->_start_process();
}

# ......................................................................
# Methods
#

sub uniq_ident {
    my $self = shift;

    my $uniq = "$self";
    $uniq =~ s{$EXTRACT_NUMBER_FROM_SELF}{$1};
    return $uniq;
}

sub dump_metadata {
    my $self = shift;
    my ($prefix) = @_;

    my $metadata = <<"EODUMP";
${prefix}::node_table_id=@{[$self->node_table_id]}
EODUMP

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

sub schema_matches {
    my $self = shift;
    my ( $name, $ref_schema ) = @_;

    # skip empty lines.
    my @ref_schema = grep {/\w/} split "\n", $ref_schema;

    my $schema =
        $self->dbh()
        ->selectall_hashref( $SQL{Get_Schema}, 'ordinal_position', undef,
                             $name )
        or die "Failed to fetch schema for table '$name';", $DBI::errstr;

    for my $position ( sort keys %$schema ) {
	my $field_spec = $schema->{$position};

	# clean away commas, split into fields, and store as arrayref
	#
	my ($record) = $ref_schema[$position - 1];
	$record =~  s{,}{};
	my ($ref_spec) = [ split /\s+/, $record ];
			   
	
	my $namematch = $ref_spec->[0] eq $field_spec->{column_name};
	if ( ! $namematch ) {
	    carp __PACKAGE__ . "::schema_matches($name), field # $position is '$field_spec->{column_name}', should be '$ref_spec->[0]'.\n";
	    return;
	}
	my $typematch = ($ref_spec->[1] eq $field_spec->{data_type}
			 or ($ref_spec->[1] eq 'serial'
			     and $field_spec->{data_type} eq 'integer'
			     and 0 == index $field_spec->{column_default}, 'nextval')
			 or ($ref_spec->[1] eq 'status'
			     and $field_spec->{udt_name} eq 'status'
			 )
			 or ($ref_spec->[1] eq 'timestamp'
			     and $field_spec->{data_type} = 'timestamp with time zone'
			 )
	    );
	if ( ! $typematch ) {
	    carp __PACKAGE__ . "::schema_matches($name), field # $position '$field_spec->{column_name}' has type '$field_spec->{data_type}/$field_spec->{udt_name}/$field_spec->{column_default}' should be '@{$ref_spec}[1..-1]'.";
		return;
	}
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
    my ( $options ) = @_;

    my $tablename    = $options->{table};
    my $node_table_id_ref = $options->{with_node_table_id} || '';
    my $args         = $options->{args};
    my @fields       = sort keys %$args;
    if ( $node_table_id_ref ) {
	push @fields, $node_table_id_ref;
	$args->{$node_table_id_ref} = $self->node_table_id;
    }
    my $fieldlist    = join ', ', @fields;
    my $placeholders = join ', ', ('?') x scalar @fields;

    my $sql = <<"EOSQL";
INSERT INTO $tablename
($fieldlist)
VALUES
($placeholders)
EOSQL

    return ($sql, \@fields, $args);
}    
sub insert_raw_record {
    my $self = shift;

    my ( $sql, $fields, $args ) = $self->generate_insert_sql( @_ );
    my ( $sth, $id ) = ( $self->get_sth($sql) );

    if ( !$sth ) {
        $sth = $self->set_sth( $sql, $self->dbh->prepare($sql) );
    }

    # extract the hash values in the order specified by the array of
    # key names.
    my $rows = $sth->execute(@{$args}{@$fields});

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
