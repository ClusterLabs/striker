package AN::OneAlert;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Const::Fast;
use English '-no_match_vars';
use File::Basename;

# ======================================================================
# CLASS ATTRIBUTES & CONTRUCTOR
#
use Class::Tiny qw( id message_tag node_id field value
    units status timestamp db db_type age
    pid target_name target_type target_extra override
    ),
    { message_arguments => sub { [] },
      other             => sub { [] },
      handled           => sub {0}, };

sub BUILD {
    my $self = shift;

    for my $elem ( @{ $self->other } ) {
        if ( $elem eq 'override existing alert' ) {
            $self->override(1);
        }
    }
    return;
}

# ======================================================================
# CONSTANTS
#
const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

const my %LEVEL => ( OK      => 'OK',
                     DEBUG   => 'DEBUG',
                     WARNING => 'WARNING',
                     CRISIS  => 'CRISIS' );

const my $LISTENS_TO => {
                  CRISIS  => { OK => 0, DEBUG => 0, WARNING => 0, CRISIS => 1 },
                  WARNING => { OK => 0, DEBUG => 0, WARNING => 1, CRISIS => 1 },
                  DEBUG   => { OK => 0, DEBUG => 1, WARNING => 1, CRISIS => 1 },
                  OK      => { OK => 1, DEBUG => 1, WARNING => 1, CRISIS => 1 },
                        };

# ======================================================================
# SUBROUTINES
#

sub OK      { return $LEVEL{OK}; }
sub DEBUG   { return $LEVEL{DEBUG}; }
sub WARNING { return $LEVEL{WARNING}; }
sub CRISIS  { return $LEVEL{CRISIS}; }

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Listeners that have registered for a particular level of message
# want to receive only messages at or above that level. But everyone
# receives an override alert.
#
sub listening_at_this_level {
    my $self = shift;
    my ($listener) = @_;

    return 1 if $self->override;
    return unless exists $LISTENS_TO->{ $listener->{level} };
    return unless exists $LISTENS_TO->{ $listener->{level} }{ $self->status };
    return $LISTENS_TO->{ $listener->{level} }{ $self->status };
}

# ----------------------------------------------------------------------
# Keep track of whether this alert has been reported.
#
sub has_this_alert_been_reported_yet {
    my $self = shift;

    return $self->handled;
}

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
sub set_handled {
    my $self = shift;

    $self->handled(1);
}

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
sub clear_handled {
    my $self = shift;

    $self->handled(0);
}

# ======================================================================
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

 OneAlerts.pm - Represents a single Alert

=head1 VERSION

This document describes oneAlerts.pm version 1.0.0

=head1 SYNOPSIS

    use AN::OneAlert;
    my @alerts;
    my $records = $onedb->fetch_alert_data();
    push @alerts, AN::OneAlert->new()
        for @$records;
    # do things based on OneAlert fields.

=head1 DESCRIPTION

This module provides the An::OneAlert class. Instances of this class
represent a single record from the alerts database table. Besides the
raw daata storage, instances calculate whether particular alert
listeners are interested in this particular alert, and keep track of
whether the alert has been reported, or needs to be reported again.

=head1 SUBROUTINES

=over 4

=item B<OK>

=item B<DEBUG>

=item B<WARNING>

=item B<CRISIS>

Class routines to provide the specific string corresponding to a
status level.

=back

=head1 METHODS

An object of this class represents a single alert record.

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<id>

The record id of the particular record.

Sample: 238865

=item B<node_id>

Foreign key into the node table, identifying the process which
generated this recoord.

Sample: 287

=item B<target_name>

Generally, the host or software system  reporting the problem.

Sample: an-c07n01.alteeve.ca

=item B<target_type>

The hardware system experiencing the problem.

Sample: RAID subsystem

=item B<target_extra>

Additional information about the system experiencing the problem,
typically the IP number. 

Sample: 10.255.4.251

=item B<field>

The identification of the data value being stored.

Sample: summary

=item B<value>

The value associated with the field.

Sample: 1

=item B<units>

Units defining the stored value.

Sample: Volts or Amps or degrees C,

=item B<status>

The scanCore and agents use one of C<OK>, C<WARNING>, C<CRISIS>. The
dashboard can also generate different values, when dealing with a
server that has gone down, C<OK>, C<DEAD> or C<TIMEOUT>,
i.e. message_tag of NODE_SERVER_STATUS.  As well, there may be records
with a message_tag of C<AUTO_BOOT> with status values of C<TRUE> or
C<FALSE>. These indicate whether a down server should be automatically
rebooted. Obviously a server that is down for service should not be
rebooted.

=item B<message_tag>

A short string identifying the nature of the record. The tag can be
expanded to a lengthier string and translated to specific languages
using a message XML file.

Sample: Value warning

=item B<message_arguments>

A semi-colon separated list of C<key>=C<value> pairs. These are
substituted into the message string looked up from the message file.

Sample: value=1

=item B<timestamp>

The date-time when a record was created.

Sample: 2015-02-10 11:40:34.388828-05

=back

=item B<listening_at_this_level listener>

Compares the status levels a listener is interested in with the level
for this alert, to determine whether it is interested in this
message. Alerts marked as 'override' ignore the listening component.

=item B<has_this_alert_been_reported_yet>

=item B<set_handled>

=item B<clear_handled>

Keep track of whether this alert has been reported.

=back

=head1 DEPENDENCIES

=over 4

=item B<Const::Fast>

Provides fast constants.

=item B<Class::Tiny>

A simple OO framework. "Boilerplate is the root of all evil"

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

 Alteeve's Niche! - https://alteeve.ca

No warranty is provided. Do not use this software unless you are
willing and able to take full liability for it's use. The authors take
care to prevent unexpected side effects when using this
program. However, no software is perfect and bugs may exist which
could lead to hangs or crashes in the program, in your cluster and
possibly even data loss.

=begin unused

=head1 INCOMPATIBILITIES

There are no current incompatabilities.


=head1 CONFIGURATION

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 REQUIRED ARGUMENTS

=head1 USAGE

=end unused

=head1 AUTHOR

Alteeve's Niche! - https://alteeve.ca

Tom Legrady - tom@alteeve.ca	November 2014

=cut

# End of File
# ======================================================================
