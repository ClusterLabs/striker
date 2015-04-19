package AN::Listener;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Const::Fast;
use English '-no_match_vars';
use File::Basename;
use Module::Load qw(load);

# ======================================================================
# Class Attributes
#
use Class::Tiny qw( id language level mode name updated added_by
    contact_info db db_type dispatcher owner);

# ======================================================================
# CONSTANTS
#

const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

const my $AGENT_KEY  => 'agents';
const my $PID_SUBKEY => 'PID';
const my $OWNER_KEY  => 'owner';

const my %LEVEL => ( DEBUG   => 'DEBUG',
                     WARNING => 'WARNING',
                     CRISIS  => 'CRISIS' );

const my $ALERT_MSG_FORMAT_STR => '%s: %s->%s (%s); %s: %s';

const my $LISTENS_TO => {
                  CRISIS  => { OK => 0, DEBUG => 0, WARNING => 0, CRISIS => 1 },
                  WARNING => { OK => 0, DEBUG => 0, WARNING => 1, CRISIS => 1 },
                  DEBUG   => { OK => 0, DEBUG => 1, WARNING => 1, CRISIS => 1 },
                        };

# ======================================================================
# Methods
#

# ----------------------------------------------------------------------
# Has the dispatcher been created yet for this Listener?
#
sub has_dispatcher {
    my $self = shift;

    return $self->dispatcher();
}

# ======================================================================
# Load the dispatcher for this listener.
#
sub add_dispatcher {
    my $self = shift;

    my $module = 'AN::' . $self->mode;
    load $module;
    die "Couldn't load module to handle @{[$self->mode()]}." if $@;
    $self->dispatcher( $module->new( { owner => $self->owner } ) );
    return;
}

# ======================================================================
# Delegate to the dispatcher to handle alert messages.
#
sub dispatch_msg {
    my $self = shift;
    my ( $msgs, $sumweight ) = @_;

    $self->add_dispatcher() unless $self->has_dispatcher();

    $self->dispatcher()->dispatch( $msgs, $self, $sumweight );
    return;
}

# ======================================================================
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     Listener.pm - package to handle a single alert listener

=head1 VERSION

This document describes Listener.pm version 1.0.0

=head1 SYNOPSIS

    use AN::Listener;
    my $listener = AN::Listener->new($args);
    $listener->dispatch_msg( \@msgs, $sum );

=head1 DESCRIPTION

This module defines a class to handle alert messages addressed to a
single recipient. Recipients are listed in the alert_listeners table,
each record defining a single recipient. Each record lists a single
dispatch mode, which is the mechanism to actually deliver the message.

=head1 METHODS

An object of this class delivers messages to a single listener using a
single transmission mechanism..

=over 4

=item B<dispatch_msg msgs sum>

Deliver a set of message with specified weighted sum to the recipient.

=back


=back

=head1 DEPENDENCIES

=over 4

=item B<Const::Fast>

Provide fast constants.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<Module::Load> I<core>

Install modules at run-time, based on dynamic requirements.

=item B<version> I<core>

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
