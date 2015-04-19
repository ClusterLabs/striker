package AN::Dashboard;

use parent 'AN::Scanner';

# _Perl_
use warnings;
use strict;
use 5.010;
use version;
our $VERSION = '1.0.0';

use Carp;
use Const::Fast;
use Data::Dumper;
use English qw( -no_match_vars );
use File::Basename;

# ======================================================================
# CLASS ATTRIBUTES
#

use Class::Tiny qw(host ), { launched_monitor => sub { {}; }
                           };

# ======================================================================
# CONSTANTS
#
const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

const my $STD_NODE_SERVER_RECORD => [
                                      {  message_tag => 'NODE_SERVER_STATUS',
                                         status => [ 'DEAD', 'TIEMOUT', 'OK' ],
                                      },
                                      {  message_tag => 'AUTO_BOOT',
                                         status      => [ 'TRUE', 'FALSE' ],
                                      }, ];

const my $MSG_BAD_NODE_SERVER_RECORD =>
    "Something's wrong with records received for check_node_server_status\n"
    . "\t-- Wrong message tag or status:\n";

# ======================================================================
# Generate alert records for NODE_SERVER_STATUS for server 'DEAD' or
# 'OK', or TIMEOUT trying to restart the server.
#
sub set_server_generic_alert {
    my $self = shift;
    my ( $value, $status, $override ) = @_;

    $override ||= '';    # printable version of 'false'
    my $long_override = $override ? 'override existing alert' : '';

    my @args = ( 0,                               # id
                 $PID,                            # pid
                 'NODE_SERVER_STATUS',            # field
                 $value,                          # value
                 '',                              # units
                 $status,                         # status
                 'NODE_SERVER_STATUS',            # message_tag
                 "host=@{[$self->host]}",         # message_arguments
                 AN::Unix::hostname('-short'),    # target_name
                 'dashboard',                     # target_type
                 $override,                       #target_extra
                 $long_override, );

    $self->set_alert(@args);
    return;
}

# ......................................................................
sub set_server_timeout_alert {
    my $self = shift;

    $self->set_server_generic_alert( 'TIMEOUT', 'CRISIS', 'override' );
    return;
}

# ......................................................................
sub set_server_ok_alert {
    my $self = shift;
    my ($override) = @_;

    $self->set_server_generic_alert( 'OK', 'OK', $override );
    return;
}

# ......................................................................
sub set_server_dead_alert {
    my $self = shift;

    $self->set_server_generic_alert( 'DEAD', 'CRISIS' );
    return;
}

# ......................................................................
# Utility - Is the record a NODE_SERVER_STATUS record?
#
sub isa_node_server_record {
    my $self = shift;
    my ($tag) = @_;

    return $tag eq 'NODE_SERVER_STATUS';
}

# ......................................................................
#  Utility - Is the record a AUTO_BOOT record?
#
sub isa_auto_boot_record {
    my $self = shift;
    my ($tag) = @_;

    return $tag eq 'AUTO_BOOT';
}

# ......................................................................
# Utility - Map status to string for downstream processing of node
# server record.
#
sub map_node_server_status2string {
    my $self = shift;
    my ($status) = @_;

    return
          $status eq 'DEAD'    ? 'dead'
        : $status eq 'TIMEOUT' ? 'timeout'
        : $status eq 'OK'      ? 'alive'
        :                        undef;
}

# ......................................................................
# Utility - Map status to string for downstream processing of auto
# boot record.
#
sub map_auto_boot_status2string {
    my $self = shift;
    my ($status) = @_;

    return
          $status eq 'FALSE' ? 'disabled by user'
        : $status eq 'TRUE'  ? 'should be running'
        :                      undef;
}

# ----------------------------------------------------------------------
# Determine whether the server is running. Query the databases for
# records announcing the failure of a server, or disabling/enabling
# autboot.
#
sub parse_node_server_status {
    my $self = shift;

    my $shorthost = (split /\./, $self->host() )[0];
    my $records = $self->dbs()->check_node_server_status( $shorthost );

    my ( $dead_or_alive, $autoboot, $aok );
    for my $record (@$records) {
        if ( $self->isa_node_server_record( $record->{message_tag} ) ) {
            $dead_or_alive
                = $self->map_node_server_status2string( $record->{status} );
            $aok = defined $dead_or_alive;
        }
        elsif ( $self->isa_auto_boot_record( $record->{message_tag} ) ) {
            $autoboot = $self->map_auto_boot_status2string( $record->{status} );
            $aok      = defined $autoboot;
        }

        carp( $MSG_BAD_NODE_SERVER_RECORD,
              Dumper( [
                         {  should_be     => $STD_NODE_SERVER_RECORD,
                            actual_record => $record,
                         },
                      ],
                    ) )
            unless $aok;
    }
    return ( $dead_or_alive, $autoboot );
}

# ----------------------------------------------------------------------
# Determine whether node servers are running. If a server IS running,
# as the result of launching a node_monitor, halt the node_monitor,
# and set an alert to notify the return of the server.
#
# If 'autoboot' has been turned off, ignore servers that are not running.
#
# If server is dead, launch a node_monitor agent and set a 'DEAD'
# alert. If node_monitor has timed out waiting for server to restart,
# set a 'TIMEOUT' alert.
#
sub check_node_server_status {
    my $self = shift;

    state $ns_keys = [ keys %{ $self->confdata()->{node_server} } ];
KEY:
    for my $key (@$ns_keys) {
        $self->host( $self->confdata()->{node_server}{$key} );

        my ( $dead_or_alive, $autoboot ) = $self->parse_node_server_status;
        #say "dead_or_alive: [$dead_or_alive], autoboot: [$autoboot]\n";

        if (    $dead_or_alive
             && $dead_or_alive eq 'alive' ) {
            if ( $self->launched_monitor->{ $self->host } ) {
                $self->set_server_ok_alert('override');
                delete $self->launched_monitor->{ $self->host };
            }
            next KEY;
        }

        next KEY
            if $autoboot
            && $autoboot eq 'disabled by user';    # Not running, but OK

        if ( $dead_or_alive eq 'timeout' ) {
            $self->set_server_timeout_alert;
        }
        elsif ( $dead_or_alive eq 'dead' ) {

            # Not running, but it should be.
            $self->launched_monitor->{ $self->host } = 1;
            $self->set_server_dead_alert;
            my $agent = $self->confdata->{node_server_down_agent};
            my $args = { ignore_ignorefile => { $agent => 1 },
                         args              => [
                                  -host       => $self->host,
                                  -healthfile => $self->confdata()->{healthfile}
                                 ], };
            $self->launch_new_agents( [$agent], $args );
        }
        else {
            carp "Unknown dead_or_alive value '$dead_or_alive.";
        }
    }
    return;
}

# ----------------------------------------------------------------------
# ignore individial alerts, in dashboard; use only the weights.
#
sub detect_status { }

# ----------------------------------------------------------------------
# Things to do in the core for a $PROG core object. Besides the usual
# tasks of launching agents and processing the alerts they generate,
# check_node_server_status() verifies the listed node servers are
# running and re-starts them if they are not.
#
sub loop_core {
    my $self = shift;

    state $verbose = grep {/seencount/} $ENV{VERBOSE} || '';

    $self->check_node_server_status();
    my $changes = $self->scan_for_agents();
    $self->handle_changes($changes) if $changes;

    $self->process_agent_data();
    $self->handle_alerts();

    if ($verbose) {
        say "Total number of distinct alerts seen: " . scalar length
            keys %{ $self->seen };
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

     Dashboard.pm - System monitoring loop for dashboard platforms

=head1 VERSION

This document describes Dashboard.pm version 1.0.0

=head1 SYNOPSIS

    use AN::Dashboard;
    my $dashboard = AN::Dashboard->new();
    $dashboard->run();

=head1 DESCRIPTION

This module provides the Dashboard program implementation. It monitors
a HA system to ensure the servers are running, and restarts them if
they are down.

=head1 METHODS

An object of this class represents a dashboard object. Most behaviour is
inherited from the AN::Scanner parent class.

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<agentdir>

The directory that is scanned for scanning plug-ins.

=item B<rate>

How often the loop should scan.

=item B<run_until>

hh::mm::ss defining a stop time. Cron jobs verify the program is
running, so halting the program just before one of the cron checks
will replace the instance with a new one, once a day.

=item B<dbconf>

The full path to the file defining the databases to access.

=item B<confpath>

The full path to the file configuring this program.

=item B<msg_dir>

The path to the directory containing the message file. THe message
file for each program is generated by combining the name of the
program with a C".xml" suffix.

=item B<from>
=item B<smtp>

The email sender and SMTP interface host.

=item B<max_retries>

How many times AN::Common should attempt to look up a string, before giving up.

=item B<bindir>

Directory where system-interface binary programs are located.

=item B<logdir>

Directory where marker files and log files are stored.

=back

Additionally, the C<log> element may be set to C<1> if the program
should keep a log file. The C<commandlineargs> element can store the
command line arguments which would relaunch the program with the same
configuration. If databases come and go, rather than trying
complicated processing to maintain integrity, the program relaunches
itself, and integral database connections are achieved during
initialization.

=back

=head1 DEPENDENCIES

=over 4

=item B<Carp> I<core>

Report errors as if they occur at call site.

=item B<Class::Tiny>

A simple OO framework. "Boilerplate is the root of all evil"

=item B<Const::Fast>

Provides fast constants.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

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

Tom Legrady       -  tom@alteeve.ca	January 2015

=cut

# End of File
# ======================================================================
