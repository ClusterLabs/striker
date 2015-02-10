package AN::Agent;

use parent 'AN::Scanner';    # inherit from AN::Scanner

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';      # Update POD to match

use Carp;
use Const::Fast;
use Cwd;
use English '-no_match_vars';
use File::Basename;
use File::Spec::Functions 'catdir';
use FindBin qw($Bin);
use Time::HiRes qw(time alarm sleep);

use AN::Common;
use AN::MonitorAgent;
use AN::FlagFile;
use AN::Unix;
use AN::DBS;

# ======================================================================
# CLASS ATTRIBUTES
#
use Class::Tiny qw( datatable_name alerts_table_name dbconf );

# ======================================================================
# CONSTANTS
#
const my $DUMP_PREFIX => q{db::};
const my $SEPARATOR   => q{::};
const my $NEWLINE     => qq{\n};

const my $PROG              => ( fileparse($PROGRAM_NAME) )[0];
const my $DATATABLE_NAME    => 'agent_data';
const my $ALERTS_TABLE_NAME => 'alerts';
const my $HOSTNAME          => AN::Unix::hostname('-short');
const my $NOT_WORDCHAR      => qr{\W};
const my $UNDERSCORE        => q{_};

# ......................................................................
# CONSTRUCTOR
#
sub BUILD {
    my $self = shift;

    $ENV{VERBOSE} ||= '';    # set default to avoid undef variable.

    $self->datatable_name($DATATABLE_NAME) unless $self->datatable_name;
    $self->alerts_table_name($ALERTS_TABLE_NAME)
        unless $self->alerts_table_name;

    croak(q{Missing Scanner constructor arg 'rate'.})
        unless $self->rate();

    return;
}
# ----------------------------------------------------------------------
# API - Generate contents for metadata file defining this process's
# output. Used unchanged by subclasses.
#
sub dump_metadata {
    my $self = shift;

    my @node_ids = $self->dbs()->node_id( $DUMP_PREFIX, $SEPARATOR );
    my $node_ids_str = join "\n", @node_ids;

    my $metadata = <<"EODUMP";
${DUMP_PREFIX}name=$PROG
${DUMP_PREFIX}pid=$PID
${DUMP_PREFIX}hostname=$HOSTNAME
${DUMP_PREFIX}datatable_name=@{[$self->alerts_table_name]}
$node_ids_str
EODUMP

    return $metadata;
}
# ----------------------------------------------------------------------
# API - delegate database storage to DBS object.
#
sub insert_raw_record {
    my $self = shift;
    my ($args) = @_;

    $self->dbs()->insert_raw_record($args);
}
# ----------------------------------------------------------------------
# Generate randomly varying value to explore OK/WARNING/CRISIS range.
#
sub generate_random_record {
    my $self = shift;

    state $first = 1;
    my $value = ( int rand(1000) ) / 10;
    my $status = (   $first || rand(100) > 66.0 ? 'DEBUG'
                   : $value > 90 ? 'CRISIS'
                   : $value > 80 ? 'WARNING'
                   :               'OK' );
    my $message_tag = (   $first == 1          ? "$PROG first record"
                        : $status eq 'DEBUG'   ? "$PROG debug msg"
                        : $status eq 'WARNING' ? "$PROG warning msg"
                        : $status eq 'CRISIS'  ? "$PROG crisis msg"
                        :                        '' );
    my $message_arguments = '';

    say scalar localtime(), ": $PROG -> $status, $message_tag"
        if $self->verbose;

    my $args = { value             => $value,
                 units             => 'a num',
                 field             => 'random values',
                 status            => $status,
                 message_tag       => $message_tag,
                 message_arguments => $message_arguments, };
    $self->insert_raw_record(
                              { table              => $self->datatable_name,
                                with_node_table_id => 'node_id',
                                args               => $args
                              } );

    $self->insert_raw_record(
                              { table              => $self->alerts_table_name,
                                with_node_table_id => 'node_id',
                                args               => $args,
                              } )
        if $status ne 'OK';

    $first = 0;
    return;
}
# ----------------------------------------------------------------------
# API - class-specific behaviour within timed infinite loop.
#
sub loop_core {
    my $self = shift;

    $self->generate_random_record();
}
# ----------------------------------------------------------------------
# API - placeholder for subclasses ... initialioze prior to infinite
# loop.
#
sub prep_for_loop { }    

# ----------------------------------------------------------------------
# Prepare for and clean up after main infinite loop. Used unchanged by
# subclasses; uses some characteristics of AN::Scanner parent class.
#
sub run {
    my $self = shift;

    my ($node_args) = @_;

    # initialize.
    #
    $self->connect_dbs($node_args);
    $self->create_marker_file( AN::FlagFile::get_tag('METADATA'),
                               $self->dump_metadata );

    # process until quitting time
    #
    $self->prep_for_loop;
    $self->run_timed_loop_forever();

    # clean up and exit.
    #
    $self->clean_up_running_agents();
    $self->disconnect_dbs();
    $self->delete_marker_file( AN::FlagFile::get_tag('METADATA') );
}

1;
__END__

# ======================================================================
# POD

=head1 NAME

     An::Agent.pm - A simple demo scanner agent

=head1 VERSION

This document describes An::Agent.pm version 1.0.0

=head1 SYNOPSIS

    use AN::Agent;

    my $agent = AN::Agent->new( {datatable_name => $dbname,
                                 alerts_table_name => $alertdb,
                                 dbconf            => '/Config/db.conf',
                                 rate              => 30,
                                 run_until         => '23:59:59'
                                 });
    $agent->run();

=head1 DESCRIPTION

This module implements the AN::Agent class, a simple scanner agent
which generates random numbers.

=head1 METHODS

The AN::Agent class provides a number of methods that are essential 
to subclasses which generate data and store it into the database.

=over 4

=item API B<dump_metadata> => multi-line string

Generate contents for metadata file defining this process's
output. Used unchanged by subclasses

=item API B<insert_raw_record $args>

Delegate database storage to DBS object.

=item API B<generate_random_record>

Demonstration functionality: Generate randomly varying value to
explore OK/WARNING/CRISIS range.

=item API B<loop_core>

Class-specific behaviour within timed infinite loop.

=item API B<prep_for_loop>

Placeholder for subclasses ... initialioze prior to infinite loop.

=item API B<run>

Prepare for and clean up after main infinite loop. Used unchanged by
subclasses; uses some characteristics of AN::Scanner parent class.

The only routine called from the main program is C<run> which prepares
for and runs a loop which runs every B<rate> seconds until
B<run_until>.

=back

=head1 DEPENDENCIES

=over 4

=item B<AN::Scanner>

base class - provides time-limited repeating loop

=item B<AN::Common>

=item B<AN::MonitorAgent>

=item B<AN::FlagFile>

=item B<AN::Unix>

=item B<AN::DBS>

Utilities and components.

=item B<Carp> I<core>

Report errors as if they occur at call site.

=item B<Class::Tiny>

A simple OO framework. "Boilerplate is the root of all evil"

=item B<Const::Fast>

Provides fast constants.

=item B<Cwd> I<core>

Determine the current workind directory.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<File::Spec::Functions>

Provides B<catdir> to concatenate file paths in a reliable manner.

=item B<FindBin> I<core>

Determine which directory contains the current program.

=item B<Time::HiRes> I<core>

Provides sub-millisecond precise versions of time(), alarm() and sleep().

=item B<version> I<core since 5.9.0>

Parses version strings.

=back

=head1 LICENSE AND COPYRIGHT

This program is part of Aleeve's Anvil! system, and is released under
the GNU GPL v2+ license.

=head1 BUGS AND LIMITATIONS

We don't yet know of any bugs or limitations. Report problems to 

    Alteeve's Niche!  -  https://alteeve.ca

No warranty is provided. Do not use this software unless you are
willing and able to take full liability for its use. The authors take
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

    Tom Legrady          December 2014
    -  tom@alteeve.ca
    -  tom@tomlegrady.com
=cut

# End of File
# ======================================================================

