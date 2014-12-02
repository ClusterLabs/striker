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
const my $COMMA    => q{,};
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

# ----------------------------------------------------------------------
# SQL
#
const my %SQL => (
    New_Process => <<"EOSQL",

INSERT INTO node
( node_name, node_description, status, modified_user )
values
( ?, ?, ?, $< )

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

# ......................................................................
# run a loop once every $options->{rate} seconds, to check $options->{agentdir}
# for new files, ignoring files with a suffix listed in $options->{ignore}
#

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
