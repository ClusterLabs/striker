package AN::Alerts;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use Clone 'clone';
use File::Basename;
use FileHandle;
use IO::Select;
use Time::Local;
use FindBin qw($Bin);
use Module::Load;
use POSIX 'strftime';

use AN::Msg_xlator;
use AN::OneAlert;
use Const::Fast;
use Data::Dumper;

const my $AGENT_KEY  => 'agents';
const my $PID_SUBKEY => 'pid';
const my $OWNER_KEY  => 'owner';

use Class::Tiny qw( xlator owner listeners),
    { alerts  => sub { return {} },
      agents  => sub { return {} },
      handled => sub { return {} }, };

sub BUILD {
    my $self = shift;

    for my $arg (@_) {
        my ( $pid, $agent, $owner )
            = (is_hash_ref($arg) && has_agents_key($arg) && has_pid_subkey($arg)
               ? ( $arg->{$AGENT_KEY}{$PID_SUBKEY}, clone( $arg->{$AGENT_KEY} ),
                   $arg->{$OWNER_KEY} )
               : ( undef, undef ) );

        if ( $pid && $agent ) {
            $self->agents( { $pid => $agent } );

            my $xlator_args = {
                        pid    => $pid,
                        agents => { $pid => $agent },
                        sys => { error_limit => $self->owner()->max_retries() },
            };
            $self->xlator( AN::Msg_xlator->new($xlator_args) );

            $self->owner($owner);
            return;
        }
    }
    carp "Did not extract pid, agent, owner in Alerts::BUILD";
}

# ======================================================================
# CONSTANTS
#

const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

const my $ALERT_MSG_FORMAT_STR => 'id %s | %s: %s->%s (%s);%s %s: %s';
const my $TARGET_INFO_FMT => ' ( %s %s %s )';    # leading space is needed.

const my %LEVEL => ( DEBUG   => 'DEBUG',
                     WARNING => 'WARNING',
                     CRISIS  => 'CRISIS' );

const my $LISTENS_TO => {
                  CRISIS  => { OK => 0, DEBUG => 0, WARNING => 0, CRISIS => 1 },
                  WARNING => { OK => 0, DEBUG => 0, WARNING => 1, CRISIS => 1 },
                  DEBUG   => { OK => 0, DEBUG => 1, WARNING => 1, CRISIS => 1 },
                        };

# ======================================================================
# Subroutines
#
# ......................................................................
# Standard constructor. In subclasses, 'inherit' this constructor, but
# write a new _init()
#

# ......................................................................
#
sub is_hash_ref {

    return 'HASH' eq ref $_[0];
}

sub has_agents_key {

    return exists $_[0]->{$AGENT_KEY};
}

sub has_pid_subkey {

    return exists $_[0]->{$AGENT_KEY}{$PID_SUBKEY};
}

sub handled_alert {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    return (    exists $self->handled()->{$key1}
             && exists $self->handled()->{$key1}{$key2}
             && $self->handled()->{$key1}{$key2} );
}

sub set_alert_handled {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    $self->handled()->{$key1}{$key2} = 1;
    return;
}

sub clear_alert_handled {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    $self->handled()->{$key1}{$key2} = 0;
    return;
}

{
    no warnings;
    sub DEBUG   { return $LEVEL{DEBUG}; }
    sub WARNING { return $LEVEL{WARNING}; }
    sub CRISIS  { return $LEVEL{CRISIS}; }
}

# ======================================================================
# Methods
#

# ......................................................................
#

sub add_alert {
    my $self = shift;
    my ( $key1, $key2, $value ) = @_;

    $key2 ||= '+';

    die(" => key1 = $key1, key2 = $key2, value = $value, caller = @{[caller]}")
        unless defined $key1 && defined $value;

    my $old = $self->alerts()->{$key1}{$key2};

    return
        if ( $old                                      # return if duplicate.
             && $value->timestamp eq $old->timestamp );
    return
        if ($old                                          # return if no change.
            && $value->status eq $old->status
            && $value->message_tag eq $old->message_tag )
            && $value->target_extra != 'override';
    $self->alerts()->{$key1}{$key2} = $value;
    $self->clear_alert_handled( $key1, $key2 );
    return 1;
}

sub add_agent {
    my $self = shift;
    my ( $pid, $value ) = @_;

    die("pid = $pid, value = $value, caller = @{[caller]}")
        unless $pid && $value;
    $self->agents()->{$pid} = $value;
    return;
}

sub fetch_agent {
    my $self = shift;
    my ($key) = @_;

    return unless $self->agents()->{$key};
    return $self->agents()->{$key};
}

sub delete_alert {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    if ($key2) {
        delete $self->alerts()->{$key1}{$key2};
        delete $self->alerts()->{$key1}
            unless scalar keys %{ $self->alerts()->{$key1} };    # last element
    }
    else {
        delete $self->alerts()->{$key1};
    }

    return;
}

sub alert_exists {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    return unless $key1;    # Can't query if no key1

    $key2 ||= '+';

    my $alerts = $self->alerts;

    return unless keys %$alerts;              # No alerts have been set
    return unless exists $alerts->{$key1};    # Alerts exist, any for key1?
    return exists $alerts->{$key1}{$key2};    # Figure out if any for key2
}

# ......................................................................
#
sub extract_time_and_modify_array {
    my ($array) = @_;

    my $timestamp;
    for my $idx ( 0 .. @$array - 1 ) {
        my $tsh = $array->[$idx];
        if ( $tsh && 'HASH' eq ref $tsh && exists $tsh->{timestamp} ) {
            $timestamp = $tsh->{timestamp};
            delete $tsh->{timestamp};

            # If $tsh only contained a timestamp, remove entire element
            # from array.
            splice( @$array, $idx ) unless scalar keys %$tsh;
        }
    }
    return $timestamp || strftime '%F %T%z', localtime;
}

sub set_alert {
    my $self = shift;
    my ( $id,          $src,         $field,        $value,
         $units,       $level,       $message_tag,  $message_arguments,
         $target_name, $target_type, $target_extra, @others )
        = @_;

    my $timestamp = extract_time_and_modify_array( \@others );

    my $args = { id                => $id,
                 pid               => $src,
                 timestamp         => $timestamp,
                 field             => $field,
                 value             => $value,
                 units             => $units,
                 status            => $level,
                 message_tag       => $message_tag,
                 message_arguments => $message_arguments,
                 target_name       => $target_name,
                 target_type       => $target_type,
                 target_extra      => $target_extra,
                 other             => ( @others ? \@others : [] ), };
    $self->add_alert( $src, $field, AN::OneAlert->new($args) );
    return;
}

# ......................................................................
#
sub clear_alert {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    $key2 ||= '+';
    return unless $self->alert_exists( $key1, $key2 );
    $self->delete_alert( $key1, $key2 );
    return;
}

# ......................................................................
#

sub has_dispatcher {
    my ($listener) = @_;

    die( "Alerts::has_dispatcher() was invoked by " . caller() );
    return $listener->dispatcher;
}

sub add_dispatcher {
    my ($listener) = @_;

    die( "Alerts::add_dispatcher() was invoked by " . caller() );
    $listener->dispatcher('asd');
    return;
}

sub dispatch {
    my ( $listener, $msgs ) = @_;

    die( "Alerts::dispatch() was invoked by " . caller() );
    $listener->{dispatcher}->dispatch($msgs);
}

sub dispatch_msg {
    my $self = shift;
    my ( $listener, $msgs, $sumweight ) = @_;

    $listener->add_dispatcher() unless $listener->has_dispatcher();
    $listener->dispatch_msg( $msgs, $sumweight );
    return;
}

sub format_msg {
    my $self = shift;
    my ( $alert, $msg ) = @_;

    my $agent = $self->agents()->{ $alert->pid };

    my $other_array
        = 'ARRAY' eq ref $alert->other
        ? @{ $alert->other }
        : q{};
    my $other = join ' : ',
        grep {/\S/} $other_array, @{$alert}{qw(field value units)};

    my $target_info = (
             $alert->{target_type}
             ? sprintf( $TARGET_INFO_FMT,
                       ( @{$alert}{qw(target_type target_name target_extra)} ) )
             : '' );
    my $formatted = sprintf( $ALERT_MSG_FORMAT_STR,
                             $alert->{id} || 'na', $alert->timestamp,
                             $agent->{hostname}, $agent->{program},
                             $agent->{pid},      $target_info,
                             $alert->status,     $msg );
    $formatted .= "; ($other)" if $other;
    return $formatted;
}

sub mark_alerts_as_reported {
    my $self = shift;

    my $alerts = $self->alerts;
    for my $key1 ( keys %$alerts ) {
        for my $key2 ( keys %{ $alerts->{$key1} } ) {
            $alerts->{$key1}{$key2}->set_handled();
            $self->set_alert_handled( $key1, $key2 );
        }
    }
    return;
}

sub handle_alerts {
    my $self = shift;

    my $alerts     = $self->alerts;
    my @alert_keys = sort keys %{$alerts};
    return unless @alert_keys;

    $self->listeners( $self->owner()->fetch_alert_listeners() )
        unless $self->listeners();
    die("No listeners found") unless $self->listeners;

    my $all_listeners = $self->listeners();
    for my $listener (@$all_listeners) {
        my @msgs;
        my $lookup = { language => $listener->{language} };
    ALERT:
        for my $key (@alert_keys) {
            for my $subkey ( keys %{ $alerts->{$key} } ) {
                my $alert = $alerts->{$key}{$subkey};
                next ALERT if $alert->has_this_alert_been_reported_yet();
                if ( ! $alert->override ) {
                    next ALERT if $self->handled_alert( $key, $subkey ); 
                    next ALERT unless $alert->listening_at_this_level($listener);
                }
                $lookup->{key} = $alert->message_tag();
                if ( $alert->message_arguments()
                     && length $alert->message_arguments() ) {
                    map {
                        my ( $k, $v ) = split '=';
                        $lookup->{variables}{$k} = $v;
                    } split ';', $alert->message_arguments();
                }

                my $msg = $self->xlator()
                    ->lookup_msg( $key, $lookup, $self->agents->{$key} );
                push @msgs, $self->format_msg( $alert, $msg );
            }
        }
        $self->dispatch_msg( $listener, \@msgs, $self->owner->sumweight )
            if @msgs || $listener->mode eq 'HealthMonitor';
    }
    $self->mark_alerts_as_reported();
    return;
}

# ======================================================================
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     Alerts.pm - package to handle alerts

=head1 VERSION

This document describes Alerts.pm version 0.0.1

=head1 SYNOPSIS

    use AN::Alerts;
    my $scanner = AN::Scanner->new({agents => $agents_data });


=head1 DESCRIPTION

This module provides the Alerts handling system. It is intended for a
time-based loop system.  Various subsystems ( packages, subroutines )
report problems of various severity during a single loop. At the end,
a single report email is sent to report all new errors. Errors are
reported once, continued existence of the problem is taken for granted
until the problem goes away. When an alert ceases to be a problem, a
new message is sent, but other problems continue to be monitored.

=head1 METHODS

An object of this class represents an alert tracking system.

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

=item B<Module::Load> I<core>

Install modules at run-time, based on dynamic requirements.

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
