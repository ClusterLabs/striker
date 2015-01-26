package AN::OneAlert;

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
use Module::Load;

use Const::Fast;

use Class::Tiny qw( id      message_tag      node_id      field         value
    units   status       timestamp    db            db_type         age
    pid     target_name  target_type  target_extra
    ),
    { message_arguements => sub { [] },
      other    => sub { [] },
      handled  => sub {0}, };

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
# Subroutines
#
# ......................................................................

sub OK      { return $LEVEL{OK}; }
sub DEBUG   { return $LEVEL{DEBUG}; }
sub WARNING { return $LEVEL{WARNING}; }
sub CRISIS  { return $LEVEL{CRISIS}; }

# ======================================================================
# Methods
#

# ......................................................................
#
sub listening_at_this_level {
    my $self = shift;
    my ($listener) = @_;

    return unless exists $LISTENS_TO->{ $listener->{level} };
    return unless exists $LISTENS_TO->{ $listener->{level} }{ $self->status };
    return $LISTENS_TO->{ $listener->{level} }{ $self->status };
}

sub has_this_alert_been_reported_yet {
    my $self = shift;

    return $self->handled;
}

sub set_handled {
    my $self = shift;

    $self->handled(1);
}

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

This document describes oneAlerts.pm version 0.0.1

=head1 SYNOPSIS

    use AN::OneAlert;
    my $alert = AN::OneAlert->new();


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
