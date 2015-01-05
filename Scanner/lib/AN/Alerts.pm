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

            my $xlator_args = { pid    => $pid,
				agents => { $pid => $agent } ,
				sys    => { error_limit => $self->owner()->max_retries() },
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

const my %LEVEL => ( DEBUG   => 'DEBUG',
                     WARNING => 'WARNING',
                     CRISIS  => 'CRISIS' );

const my $ALERT_MSG_FORMAT_STR => 'id %s | %s: %s->%s (%s); %s: %s';

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
sub new_alert_loop {
    my $self = shift;

    say strftime( '%F %T%z', localtime );
    return;
}

sub add_alert {
    my $self = shift;
    my ( $key1, $key2, $value ) = @_;

    $key2 ||= '+';

    die("key1 = $key1, key2 = $key2, value = $value, caller = @{[caller]}")
        unless $key1 && $value;

    my $old = $self->alerts()->{$key1}{$key2};

    return
        if ( $old                                      # return if duplicate.
             && $value->timestamp eq $old->timestamp );
    return
        if ( $old                                      # return if no change.
             && $value->status eq $old->status
             && $value->msg_tag eq $old->msg_tag );
    $self->alerts()->{$key1}{$key2} = $value;
    $self->clear_alert_handled( $key1, $key2 );
    return;
}

sub add_agent {
    my $self = shift;
    my ( $pid, $value ) = @_;

    die("pid = $pid, value = $value, caller = @{[caller]}")
        unless $pid && $value;
    $self->agents()->{$pid} = $value;
    return;
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

    my @keys = keys %{ $self->alerts };
    return unless @keys;    # No alerts have been set
    my @for_key1 = grep {/$key1/} @keys;    # Alerts exist
    return unless @for_key1;                # But none for key1
    return grep {/$key2/} @for_key1;        # Figure out if any for key2
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
        }

        # If $tsh only contained a timestamp, remove entire element
        # from array.
        splice( @$array, $idx ) unless scalar keys %$tsh;
    }
    return $timestamp || strftime '%F %T%z', localtime;
}

sub set_alert {
    my $self = shift;
    my ( $id,    $src,     $field,    $value, $units,
         $level, $msg_tag, $msg_args, @others )
        = @_;

    my $timestamp = extract_time_and_modify_array( \@others );
    my $args = { id        => $id,
                 pid       => $src,
                 timestamp => $timestamp,
                 field     => $field,
                 value     => $value,
                 units     => $units,
                 status    => $level,
                 msg_tag   => $msg_tag,
                 msg_args  => $msg_args,
                 other     => \@others || '', };
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

    return $listener->dispatcher;
}

sub add_dispatcher {
    my ($listener) = @_;

    $listener->dispatcher('asd');
    return;
}

sub dispatch {
    my ( $listener, $msgs ) = @_;

    $listener->{dispatcher}->dispatch($msgs);
}

sub dispatch_msg {
    my $self = shift;
    my ( $listener, $msgs ) = @_;

    $listener->add_dispatcher() unless $listener->has_dispatcher();
    $listener->dispatch_msg($msgs);
    return;
}

sub format_msg {
    my $self = shift;
    my ( $alert, $msg ) = @_;

    my $agent = $self->agents()->{ $alert->pid };
    my $msg_w_args
        = $alert->msg_args
        ? sprintf $msg, split ';', $alert->msg_args
        : $msg;
    my $other = join ' : ', @{ $alert->other },
        @{$alert}{qw(field value units)};

    my $formatted = sprintf( $ALERT_MSG_FORMAT_STR,
                             $alert->{id} || 'na', $alert->timestamp,
                             $agent->{hostname}, $agent->{program},
                             $agent->{pid},      $alert->status,
                             $msg_w_args );
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
                next ALERT if $self->handled_alert( $key, $subkey );
                next ALERT unless $alert->listening_at_this_level($listener);

                $lookup->{key} = $alert->msg_tag();
		if ( $alert->msg_args() && length $alert->msg_args() ) {
		    map { my ($k, $v) = split '=';
			  $lookup->{variables}{$k} = $v;
		        } split ';', $alert->msg_args();
		}
		
                my $msg = $self->xlator()
                    ->lookup_msg( $key, $lookup, $self->agents->{$key} );
		push @msgs, $self->format_msg( $alert, $msg );
            }
        }
        $self->dispatch_msg( $listener, \@msgs ) if @msgs;
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
