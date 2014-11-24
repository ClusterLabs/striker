package AN::DB;

# _Perl_
use warnings;
use strict;
use 5.014;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;
use FileHandle;
use IO::Select;

use FindBin qw($Bin);

use Const::Fast;

## no critic ( ControlStructures::ProhibitPostfixControls )
## no critic ( ProhibitMagicNumbers )
# ======================================================================
# CONSTANTS
#
const my $COMMA    => q{,};
const my $DOTSLASH => q{./};

const my $DB_NAME         => 'Pg';
const my $DB_CONNECT_ARGS => {
    AutoCommit         => 0,
    RaiseError         => 1,
    PrintError         => 0,
    dbi_connect_method => undef
};

const my $DB_CONNECT_FMT      => 'dbi:Pg:dbname=%s';
const my $DATASOURCES_ARG_FMT => 'port=%s;host=%s';
const my $DEFAULT_PW          => 'alteeve';

const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];
const my $READ_PROC  => q{-|};
const my $WRITE_PROC => q{|-};
const my $SLASH      => q{/};
const my $EP_TIME_FMT => '%8.3f:%8.3f mSec';    # elapsed:pending time format

const my $DB_PROCESS_TABLE => 'processes';

const my $PROC_STATUS_NEW     => 'pre_run';
const my $PROC_STATUS_RUNNING => 'running';
const my $PROC_STATUS_HALTED  => 'halted';

# ----------------------------------------------------------------------
# SQL
#
const my %SQL => (
    New_Process => <<"EOSQL",

INSERT INTO processes
( process, host, pid, status )
values
( ?, ?, ?, '$PROC_STATUS_NEW' )

EOSQL

    Start_Process => <<"EOSQL",

UPDATE processes
SET    status    = '$PROC_STATUS_RUNNING',
       starttime = now()
WHERE  id = ?

EOSQL

    Halt_Process => <<"EOSQL",

UPDATE processes
SET    status  = '$PROC_STATUS_HALTED',
       stoptime = now()
WHERE  id = ?

EOSQL
);

## use critic ( ProhibitMagicNumbers )
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
    $self->{dbhs} = [];    # store all dbs to notify.
    $self->_register_with_db();

    return;

}

sub DESTROY {
    my $self = shift;

    for my $dbh ( $self->_all_dbhs ) {
        _halt_process( $dbh, $self->_process_id( $dbh ));
    }
}

sub _log_new_process {
    my ( $dbh, @args ) = @_;

    my $sql = $SQL{New_Process};
    my $id;

    my $rows = $dbh->do( $sql, undef, @args );

    if ( 0 < $rows ) {
        $dbh->commit();
        $id = $dbh->last_insert_id( undef, undef, $DB_PROCESS_TABLE, undef );
    }
    else {
        $dbh->rollback;
    }
    return $id;
}

sub _halt_process {
    my ( $dbh, $process_id ) = @_;

    my $sql = $SQL{Halt_Process};
    my $rows = $dbh->do( $sql, undef, $process_id );

    if ( 0 < $rows ) {
        $dbh->commit();
    }
    else {
        $dbh->rollback;
    }
    return $rows;
}

sub _start_process {
    my ( $dbh, $process_id ) = @_;

    my $sql = $SQL{Start_Process};
    my $rows = $dbh->do( $sql, undef, $process_id );

    if ( 0 < $rows ) {
        $dbh->commit();
    }
    else {
        $dbh->rollback;
    }
    return $rows;
}

# ......................................................................
# accessor
#
sub db_name {
    my ( $self, $new_value ) = @_;

    return $self->{db_name} if not defined $new_value;

    $self->{db_name} = $new_value;
    return;
}

sub port {
    my ( $self, $new_value ) = @_;

    return $self->{port} if not defined $new_value;

    $self->{port} = $new_value;
    return;
}


# ......................................................................
# Private Accessors
#
sub _dbhs {
    my ($self) = @_;

    return $self->{dbhs};
}

sub _dbhs_populated {
    my ($self) = @_;

    return scalar @{ $self->{dbhs} };
}

sub _add_dbh {
    my ( $self, $value ) = @_;

    push @{ $self->{dbhs} }, $value;
}

sub _all_dbhs {
    my ($self) = @_;

    return @{ $self->{dbhs} };

}

sub _process_id {
    my ( $self, $dbh, $new_value ) = @_;

    die( __PACKAGE__ . " method _process_id( \$dbh, \$id ) not enough args." )
      if scalar @_ <= 1;
    die( __PACKAGE__ . " method _process_id( \$dbh, \$id ) too many args." )
      if scalar @_ > 3;

    return $self->{process_id}{$dbh} if not defined $new_value;

    $self->{process_id}{$dbh} = $new_value;
    return;
}

# ......................................................................
# Private Methods
#

sub _connect_db {
    my ($self) = @_;

    return if $self->_dbhs_populated;
    my $dsn = sprintf $DB_CONNECT_FMT, $self->db_name;
    for my $host ( $self->hosts ) {
        my $dbh =
          DBI->connect( $dsn, $ENV{USER}, $DEFAULT_PW, $DB_CONNECT_ARGS )
          || die(
            sprintf(
                "Could not connect to DB %s on host %s: %s\n",
                $self->db_name, $host, $DBI::errstr
            )
          );
        $self->_add_dbh($dbh);
    }
    return;
}

sub _register_start {
    my ($self) = @_;

    my $hostname = `/bin/hostname`;
    chomp $hostname;

    for my $dbh ( $self->_all_dbhs ) {
        my $process_id = _log_new_process( $dbh, $PROG, $hostname, $PID );
        $self->_process_id( $dbh, $process_id );
        _start_process( $dbh, $process_id );
    }
}

sub _register_with_db {
    my ($self) = @_;

    $self->_connect_db();
    $self->_register_start();

}

# ......................................................................
# Methods
#

sub launch {
    my ( $self, $scanner ) = @_;

    # my $fullpath = $self->agentdir() . $SLASH . $scanner;
    # croak "scanner '$fullpath' not found.\n"
    #   unless -e $fullpath;
    # croak "scanner '$fullpath' not executable.\n"
    #   unless -x _;

    # #    open my $fh, $READ_PROC, $fullpath
    # open my $fh, '|-', "$fullpath --verbose --rate 3"
    #   or croak "Could not AN::Scanner::launch( '$scanner' )";
    # my $status = $self->_add_fh_to_list($fh);
    return;
}

sub process {
    my ( $self, $fh ) = @_;

    my ($text) = <$fh>;
    print "Read '$text'.\n";
    return;
}

# ......................................................................
# run a loop once every $options->{rate} seconds, to check $options->{agentdir}
# for new files, ignoring files with a suffix listed in $options->{ignore}
#

sub run_timed_loop_forever {
    my ($self) = @_;

    my ($start_time) = time;
    my ($end_time)   = $start_time + $self->{duration};
    my ($now)        = $start_time;

    my $loop = 1;

    while ( $now < $end_time ) {    # loop until this time tomorrow
                                    #        $self->read_process_all_agents();

        my ($elapsed) = time() - $now;
        my $pending = $self->rate - $elapsed;

        my $extra_arg = sprintf $EP_TIME_FMT, 1000 * $elapsed, 1000 * $pending;
        say "$PROG loop $loop at @{[time]} $extra_arg.";
        $loop++;

        sleep $pending;
        $now = time;
    }
    return;
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
