package AN::Dashboard;

use parent 'AN::Scanner';

# _Perl_
use warnings;
use strict;
use 5.010;

use Carp;
use Const::Fast;
use Data::Dumper;
use English qw( -no_match_vars );
use File::Basename;

const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

use Class::Tiny qw(host ), {launched_monitor => sub{ {}; }};

# DB sample record ...
#  1 | 1 | node monitor | an-a07n01 | | node server | an-a07n01 | | TIMEOUT |
#  NODE_SERVER_STATUS | host=an-a07n01 | 2015-01-29 21:39:31.774518-05
#
sub set_server_timeout_alert {
    my $self = shift;

    my @args = ( 0,             # id
                 $PID,          # pid
                 'NODE_SERVER_STATUS', # field
                 'TIMEOUT',            # value
                 '',                   # units
                 'CRISIS',             # status
                 'NODE_SERVER_STATUS', # message_tag
                 "host=@{[$self->host]}",     # message_arguments
                 AN::Unix::hostname('-short'),# target_name
                 'dashboard',                 # target_type
                 'override',                  #target_extra
                 'override existing alert'
        );





    $self->set_alert(@args)
}
sub set_server_ok_alert {
    my $self = shift;
    my ( $override ) = @_;

    $override ||= '';
    my $long_override = $override ? 'override existing alert' : ''; 
    my @args = ( 0,             # id
                 $PID,          # pid
                 'NODE_SERVER_STATUS', # field
                 'OK',                 # value
                 '',                   # units
                 'OK',                 # status
                 'NODE_SERVER_STATUS_OK', # message_tag
                 "host=@{[$self->host]}",     # message_arguments
                 AN::Unix::hostname('-short'),# target_name
                 'dashboard',                 # target_type
                 $override,                   #target_extra
                 $long_override,
        );

    $self->set_alert(@args)
}
sub set_server_dead_alert {
    my $self = shift;

    my @args = ( 0,             # id
                 $PID,          # pid
                 'NODE_SERVER_STATUS', # field
                 'DEAD',               # value
                 '',                   # units
                 'CRISIS',             # status
                 'NODE_SERVER_STATUS', # message_tag
                 "host=@{[$self->host]}", # message_arguments
                 AN::Unix::hostname('-short'),# target_name
                 'dashboard',          # target_type
                 '',                   #target_extra
        );





    $self->set_alert(@args)
}

sub parse_node_server_status {
    my $self = shift;

    my $records = $self->dbs()->check_node_server_status($self->host);
    my ( $dead_or_alive, $autoboot, $aok );
    for my $record (@$records) {
        if ( $record->{message_tag} eq 'NODE_SERVER_STATUS' ) {
            $dead_or_alive
                = $record->{status} eq 'DEAD'    ? 'dead'
                : $record->{status} eq 'TIMEOUT' ? 'timeout'
                : $record->{status} eq 'OK'      ? 'alive'
                :                                  undef;
            $aok = defined $dead_or_alive;
        }
        elsif ( $record->{message_tag} eq 'AUTO_BOOT' ) {
            $autoboot
                = $record->{status} eq 'FALSE' ? 'disabled by user'
                : $record->{status} eq 'TRUE'  ? 'should be running'
                :                                undef;
            $aok = defined $autoboot;
        }

        carp( "Something's wrong with records received for ",
              " check_node_server_status--Wrong message tag or status\n",
              Dumper( [
                          { should_be => [
                                { message_tag => 'NODE_SERVER_STATUS',
                                  status      => [ 'DEAD', 'TIEMOUT', 'OK' ],
                                },
                                { message_tag => 'AUTO_BOOT',
                                  status      => [ 'TRUE', 'FALSE' ],
                                },
                                ],
                             actual_record => $record,
                          },
                      ],
              ), )
            unless $aok;
    }
    return ( $dead_or_alive, $autoboot );
}

sub check_node_server_status {
    my $self = shift;

    state $ns_keys = [ keys %{ $self->confdata()->{node_server} } ];
  KEY:
    for my $key (@$ns_keys) {
        $self->host( $self->confdata()->{node_server}{$key} );
        my ( $dead_or_alive, $autoboot ) = $self->parse_node_server_status;

        if ( $dead_or_alive  # node server on host is running OK
             && $dead_or_alive eq 'alive' ) {
            if ( $self->launched_monitor->{$self->host} ) {
                $self->set_server_ok_alert( 'override' );
                delete $self->launched_monitor->{$self->host};
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
            $self->launched_monitor->{$self->host} = 1;
            $self->set_server_dead_alert;
            my $agent = $self->confdata->{node_server_down_agent};
            my $args = { ignore_ignorefile => { $agent => 1 },
                         args => [-host       => $self->host,
                                  -healthfile => $self->confdata()->{healthfile}],};
            $self->launch_new_agents( [$agent], $args );
        }
        else {
            carp "Unknown dead_or_alive value '$dead_or_alive.";
        }
    }
    return;
}

# The dashboard version of process_agent_data() does not pass on
# ordinary alerts to be display dispatchers.
sub process_agent_data {
    my $self = shift;

    state $dump = grep {/dump alerts/} $ENV{VERBOSE} || '';
    say "${PROG}::process_agent_data()." if $self->verbose;

PROCESS:
    for my $process ( @{ $self->processes } ) {
        my $alerts = $self->fetch_alert_data($process);

        next PROCESS
            unless 'ARRAY' eq ref $alerts
            && @$alerts;

        my $allN = scalar @$alerts;
        my $newN = 0;
        say Data::Dumper::Dumper( [$alerts] )
            if $dump;
        my $seen_summary = 0;
    ALERT:
        for my $alert (@$alerts) {
            if ( $alert->{field} eq 'summary' ) {
                last ALERT
                    if $seen_summary++;    # this is from an earlier loop

                $self->sumweight( $self->sumweight + $alert->{value} );
            }
            $newN++;
        }
        say scalar localtime(), " Received $allN alerts for process ",
            "$process->{name}, $newN of them new; weight is @{[$self->sumweight]}."
            if $self->verbose || grep {/\balertcount\b/} $ENV{VERBOSE} || '';
    }

    return;
}

# Things to do in the core for a $PROG core object
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
