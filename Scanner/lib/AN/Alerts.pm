package AN::Alerts;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Carp;
use Clone 'clone';
use English '-no_match_vars';
use File::Basename;
use FileHandle;
use FindBin qw($Bin);
use Module::Load;
use POSIX 'strftime';

use AN::Msg_xlator;
use AN::OneAlert;
use Const::Fast;
use Data::Dumper;

# ======================================================================
# CLASS ATTRIBUTES
#
# Constants used in constructor
#
const my $AGENT_KEY  => 'agents';
const my $PID_SUBKEY => 'pid';
const my $OWNER_KEY  => 'owner';

# CLASS ATTRIBUTES
#
use Class::Tiny qw( xlator owner listeners),
    { alerts  => sub { return {} },
      agents  => sub { return {} },
      handled => sub { return {} }, };

# ......................................................................
#
sub is_hash_ref {

    return 'HASH' eq ref $_[0];
}

# ......................................................................
#
sub has_agents_key {

    return exists $_[0]->{$AGENT_KEY};
}

# ......................................................................
#
sub has_pid_subkey {

    return exists $_[0]->{$AGENT_KEY}{$PID_SUBKEY};
}

# ......................................................................
# CONSTRUCTOR
#
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
{
    no warnings;
    sub DEBUG   { return $LEVEL{DEBUG}; }
    sub WARNING { return $LEVEL{WARNING}; }
    sub CRISIS  { return $LEVEL{CRISIS}; }
}

# ======================================================================
# Methods
#
# ----------------------------------------------------------------------
# Internal utility; Has this key combination been handled?
#
sub handled_alert {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    return (    exists $self->handled()->{$key1}
             && exists $self->handled()->{$key1}{$key2}
             && $self->handled()->{$key1}{$key2} );
}

# ----------------------------------------------------------------------
# Internal utility; Set this key combination as having been handled.
#
sub set_alert_handled {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    $self->handled()->{$key1}{$key2} = 1;
    return;
}

# ----------------------------------------------------------------------
# Internal utility; Set this key combination as not handled.
#
sub clear_alert_handled {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    $self->handled()->{$key1}{$key2} = 0;
    return;
}

# ----------------------------------------------------------------------
# Add an alert ( AN::OneAlert ) to the current set of alerts, based on
# the process id ($key1) and field ($key2), i.e., the variable being
# described. If there already exists an alert with this ID
# combination, identical timestamps indicates the arrival of an
# already-seen message. A message with the same status and same
# message tag similarly is a new alert for an existing condition.
#
# An exception occurs with the dashboard system, which generates
# alerts with message tag NODE_SERVER_STATUS, which may represent an
# out-of-service server, a timeout attempting to restore the server,
# or success restoring it.
#
# When an alert is added, it is 'cleared' to indicate the alert is new
# and needs to be handled.
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
        && $value->target_extra ne 'override';
    $self->alerts()->{$key1}{$key2} = $value;
    $self->clear_alert_handled( $key1, $key2 );
    return 1;
}

# ----------------------------------------------------------------------
# Remove any alert associated with key1 & key2. If key2 is not provided,
# remove all alerts associated with key1.
#
# In a sense, the 'alert_handled' structure for key1/key2 should be
# deleted, but it will be taken care of when the replacement alerts
# are assigned. Until then, it will be simply surplus crud hanging
# around.
#
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

# ......................................................................
# A higher-level method utilizing delete_alert(). This clear_alert()
# sets key2 to '+' if it hasn't been defined, corresponding to the way
# add_alert() works.
#
sub clear_alert {
    my $self = shift;
    my ( $key1, $key2 ) = @_;

    $key2 ||= '+';
    return unless $self->alert_exists( $key1, $key2 );
    $self->delete_alert( $key1, $key2 );
    return;
}

# ----------------------------------------------------------------------
# Is any alert associated with key1 / key2? Use a default value of '+'
# for key2, if it hasn't been set.
#
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
# If the set_alert 'other' array contains a hash including a
# timestamp, extract and return the timestamp. Remove the entire hash
# if there's nothing left.
#
# If no timestamp was provided, use the current time.
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

# ----------------------------------------------------------------------
# Receive a list of fields, and turn it into a hash to pass to the
# AN::OneAlert constructor.
#
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

# ----------------------------------------------------------------------
# Invoked from An::Scanner::handle_additions(), to archive information
# concerning launched agent processes. The value being stored consists
# of the process 'pid', 'program' name, 'hostname', and 'msg_dir'.
#
sub add_agent {
    my $self = shift;
    my ( $pid, $value ) = @_;

    die("pid = $pid, value = $value, caller = @{[caller]}")
        unless $pid && $value;
    $self->agents()->{$pid} = $value;
    return;
}

# ----------------------------------------------------------------------
# Lookup the process information for the agent with the specified pid.
#
sub fetch_agent {
    my $self = shift;
    my ($key) = @_;

    return unless $self->agents()->{$key};
    return $self->agents()->{$key};
}

# ----------------------------------------------------------------------
# Used by handle_alerts() - Pass on the current alert messages to a
# single listener to be delivered or displayed.
#
sub dispatch_msg {
    my $self = shift;
    my ( $listener, $msgs, $sumweight ) = @_;

    $listener->add_dispatcher() unless $listener->has_dispatcher();
    $listener->dispatch_msg( $msgs, $sumweight );
    return;
}

# ----------------------------------------------------------------------
# Used by handle_alerts() - Format a single message for delivery.
#
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

# ----------------------------------------------------------------------
# Used by handle_alerts() - Mark all stored alerts as hanving been
# handled.
#
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

# ----------------------------------------------------------------------
# API - Back-end infrastructure implementing AN::Scanner:set_alert().
# When invoked at end of each processing loop, it collects all the
# current alerts and all the current listeners. For each listener, it
# goes through alerts, skips over old ones, I18N's and formats the
# messages, and sends them to be delivered. Finnally, all alerts are
# marked as handled.
#
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
                if ( !$alert->override ) {
                    next ALERT if $self->handled_alert( $key, $subkey );
                    next ALERT
                        unless $alert->listening_at_this_level($listener);
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

This document describes Alerts.pm version 1.0.0

=head1 SYNOPSIS

    use AN::Alerts;
    my $alerts = AN::Alerts( { agents => { pid      => $PID,
                                           program  => $PROG,
                                           hostname => AN::UNix::hostname(),
                                           msg_dir  => $self->msg_dir,
                                         },
                               owner => $self,
                             } );
    $alerts->add_agent( $cfg{db}{pid},
                        {  pid      => $cfg{db}{pid},
                           program  => $cfg{db}{name},
                           hostname => $cfg{db}{hostname},
                           msg_dir  => $self->msg_dir,
                        } );
    $alerts->set_alert(@alert_args);
    $alerts->handle_alerts();


=head1 DESCRIPTION

This module provides the Alerts handling system. It is intended for a
time-based loop system.  Various subsystems ( packages, subroutines )
report problems of various severity during a single loop. At the end,
a single report email is sent to report all new errors. Errors are
reported once, continued existence of the problem is taken for granted
until the problem goes away. When an alert ceases to be a problem, a
new message is sent, but other problems continue to be monitored.

=head1 METHODS

An object of this class represents an alert tracking and reporting system.

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<agents>

The agents attribute will keep track of the alert sources. Since the
mainline program can generate alerts on its own, the program provides
information about itself when constructing the AN::Alerts object, in
the form of a hash:

        { pid      => $PID,
          program  => $PROG,
          hostname => AN::Unix::hostname(),
          msg_dir  => $self->msg_dir,
        }

In the constructor, this hash is stored as the value associated with
the process id, or PID. Since program and its agents are all running
on the same computer, they must by definition have distinct Process
ids.

The C<msg_dir> is the path to the directory containing an XML file
with the same name as the program name specified, with the suffix,
C<.xml>. The top-level C<scanner> program has a file associated with
it, C<scanner.xml>, which expands message 'tags' into longer messages
in a number of languages.

=item B<owner>

This is a link back to the top-level program. It is used to provide
the Alerts object with a list of C<Listeners>; Alerts has no means of
looking up that information on its own, it asks the owner for it. The
owner also provides the weighted sum of all the alerts, used in
dispatching alerts.

=back

=item B<add_agent( $pid, $agent_hashref )>

When the top-level program launches agents which may send alerts, it
informs the AN::Alerts object, which archives the information. The
program name and msg_dir are passed to a message translator, to
convert C<tags> into messages.

=item B<set_alert( @alert_args )>

Takes a list of arguments, creates a corresponding AN::OneAlert
object, and archives it based on the source program / agent process
id, and the data field involved. The fields involved are:

=over 4

=item B<id>

Normally the record id in the C<alerts> table.

=item B<pid>

The process id of the generating program.

=item B<field>

The identification of the data value being stored, eg. C<battery temperature>

=item B<value>

The value associated with the field, eg. C<28>.

=item B<units>

Units defining the stored value, eg. C<degrees C>.

=item B<status aka level>

The scanCore and agents use one of C<OK>, C<WARNING>, C<CRISIS>. The
dashboard can also generate different values, when dealing with a
server that has gone down, C<OK>, C<DEAD> or C<TIMEOUT>,
i.e. message_tag of NODE_SERVER_STATUS.  As well, there may be records
with a message_tag of C<AUTO_BOOT> with status values of C<TRUE> or
C<FALSE>. These indicate whether a down server should be automatically
rebooted. Obviously a server that is down for service should not be
rebooted.

=item B<message_tag>

The tag to be looked up in the message file.

=item B<message_arguments>

A semi-colon separated list of C<key>=C<value> pairs. These are
substituted into the message string looked up from the message file.

Example: B<value=76;controller=0>

=item B<target_name>

Generally, the host or software system  reporting the problem.

=item B<target_type>

The hardware system experiencing the problem, eg. C<RAID subsystem>,
C<APC UPS>.

=item B<tartget_extra>

Additional information about the system experiencing the problem,
typically the IP number.  Example: C<10.255.4.251>, C<10.20.3.251>.

=back

=item B<handle_alerts>

When invoked at end of each processing loop, this method collects all
the current alerts and all the current listeners. For each listener,
it goes through alerts, skips over old ones, I18N's and formats the
messages, and sends them to be delivered. Finnally, all alerts are
marked as handled.


=back

=head1 DEPENDENCIES

=over 4
=item B<Carp> I<core>

Report errors as originating at the call site.

=item B<Clone>

Recursively copy Perl data structures

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<FileHandle> I<code>

Provides access to FileHandle / IO::* attributes.

=item B<FindBin> I<core>

Determine which directory contains the current program.

=item B<Module::Load> I<core>

Install modules at run-time, based on dynamic requirements.

=item B<POSIX> I<core>

provides C<strftime> for string representations of date-times.

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

Tom Legrady       -  tom@alteeve.ca	November 2014

=cut

# End of File
# ======================================================================
