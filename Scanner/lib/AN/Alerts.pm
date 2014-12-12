package AN::Alerts;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;
use FileHandle;
use IO::Select;
use Time::Local;
use FindBin qw($Bin);

use AN::Msg_xlator;

use Const::Fast;

# ======================================================================
# Object attributes.
#
const my @ATTRIBUTES => (
    qw( agents alerts xlator owner listeners)
);

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
const my $COLON    => q{:};
const my $COMMA    => q{,};
const my $DOTSLASH => q{./};
const my $DOUBLE_QUOTE => q{"};
const my $NEWLINE  => qq{\n};
const my $SLASH    => q{/};
const my $SPACE    => q{ };
const my $PIPE     => q{|};

const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];

const my $AGENT_KEY  => 'agents';
const my $PID_SUBKEY => 'PID';
const my $OWNER_KEY  => 'owner';

const my %LEVEL => ( DEBUG   => 'DEBUG',
                     WARNING => 'WARNING',
                     CRISIS  => 'CRISIS' );

const my $PID_FIELD_IDX   => 0;
const my $LEVEL_FIELD_IDX => 1;
const my $TAG_FIELD_IDX   => 2;

const my $NO_MSG_TAG       => 'set_alert() invoked with no message tag';
const my $INTRO_OTHER_ARGS => 'set_alert() invoked with additional args: ';

const my $LISTENS_TO 
    => { CRISIS  => { OK => 0, DEBUG => 0, WARNING => 0, CRISIS => 1},
	 WARNING => { OK => 0, DEBUG => 0, WARNING => 1, CRISIS => 1},
	 DEBUG   => { OK => 0, DEBUG => 1, WARNING => 1, CRISIS => 1},	 
};
			  
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
sub is_hash_ref {

    return 'HASH' eq ref $_[0];
}

sub has_agents_key {

    return exists $_[0]->{$AGENT_KEY}
}

sub has_pid_subkey {

    return exists $_[0]->{$AGENT_KEY}{$PID_SUBKEY}
}

sub _init {
    my $self = shift;

    # default value;
    $self->alerts( {} );
    $self->agents( {} );

    for my $arg (@_) {
        my ( $pid, $agent, $owner )
            = (is_hash_ref($arg) && has_agents_key($arg) && has_pid_subkey($arg)
               ? ( $arg->{$AGENT_KEY}{$PID_SUBKEY}, $arg->{$AGENT_KEY},
                   $arg->{$OWNER_KEY} )
               : ( undef, undef ) );

        if ( $pid && $agent ) {
            $self->agents()->{$pid} = $agent;
            $self->xlator( AN::Msg_xlator->new( $pid, $agent ) );
            $self->owner($owner);
        }
    }
    
#    $self->copy_from_args_to_self(@_);

    return;
}

sub DEBUG   {return $LEVEL{DEBUG};}
sub WARNING {return $LEVEL{WARNING};}
sub CRISIS  {return $LEVEL{CRISIS};}

# ======================================================================
# Methods
#

# ......................................................................
#
sub new_alert_loop {
    my $self = shift;

    say "Alerts::new_alert_loop() not implemented yet.";
    return;
}


# ......................................................................
#
    # my $msg_fmt = $self->xlator()->lookup_msg( $src, $tag );

    # my $formatted
    #     = $args
    #     ? sprintf $msg_fmt, @$args
    #     : $msg_fmt;
    # $formatted .= $NEWLINE . $INTRO_OTHER_ARGS . (@others)
    #     if @others;

sub set_alert {
    my $self = shift;
    my ($src, $level, $tag, $args, @others) = @_;

    $self->alerts()->{$src} = \@_;
    
    return;
}

# ......................................................................
#
sub clear_alert {
    my $self = shift;
    my ( $pid ) = @_;
    
    my @keys = keys %{ $self->alerts };
    return unless @keys;	          # No alerts have been set 
    return unless grep { /$pid/ } @keys;  # Alerts exist, but none for $pid
    
    delete $self->alerts()->{$pid};
    return;
}
 
# ......................................................................
#
sub listening_at_this_level {
    my ( $listener, $alert ) = @_;

    return unless exists $LISTENS_TO->{$listener->{level}};
    return unless exists $LISTENS_TO->{$listener->{level}}{$alert->[1]};
    return $LISTENS_TO->{$listener->{level}}{$alert->[1]};
}

sub has_dispatcher {
    my ( $listener ) = @_;
    return unless $listener and 'HASH' eq ref $listener;
    return exists $listener->{dispatcher};
}

sub add_dispatcher {
    my $self = shift;
    my ( $listener ) = @_;

    my $module = 'AN::' . ucfirst lc $listener->{mode};
    eval "use $module;";
    die "Couldn't load module to handle @{[$listener->{mode}]}." if $@;
    $listener->{dispatcher} = $module->new();
    return;
}

sub dispatch {
    my ( $listener, $msgs ) = @_;

    $listener->{dispatcher}->dispatch( $msgs );
}

sub dispatch_msg {
    my $self = shift;
    my ( $listener, $msgs ) = @_;

    $self->add_dispatcher( $listener ) unless has_dispatcher( $listener );
    dispatch( $listener, $msgs );
    return;
}
sub handle_alerts {
    my $self = shift;

    my $alerts = $self->alerts;
    my @alert_keys = keys %{ $alerts };
    return unless @alert_keys;
	
    $self->listeners( $self->owner()->fetch_alert_listeners())
	unless $self->listeners();
    die( "No listeners found" ) unless $self->listeners;

    my $listener_records = $self->listeners()->{data};
    for my $listener_id ( sort keys %$listener_records ) {
	my @msgs;
	my $listener = $listener_records->{$listener_id};
	my $lookup = { language => $listener->{language} };
      ALERT:
	for my $key ( @alert_keys ) {
	    my $alert = $alerts->{$key};
	    next ALERT unless listening_at_this_level( $listener, $alert );
	    $lookup->{key} = $alert->[2];
	    my $msg = $self->xlator()->lookup_msg( $key, $lookup );
	    push @msgs, $msg;   
	}
	$self->dispatch_msg( $listener, \@msgs )
    }
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
