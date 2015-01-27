package AN::HealthMonitor;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use autodie qw(open close);
use English '-no_match_vars';
use Carp;

use File::Basename;
use FileHandle;
use File::Path 'make_path';
use IO::Select;
use Time::Local;
use FindBin qw($Bin);

use Const::Fast;

use Class::Tiny qw(owner), { firsttime => sub {1}
                };

const my @HEALTH => ( 'ok', 'warning', 'critical' );

# ......................................................................
#
sub weight2health {
    my $self = shift;
    my ( $sumweight, $warn, $crisis ) = @_;

    return
          $sumweight < $warn   ? $HEALTH[0]
        : $sumweight < $crisis ? $HEALTH[1]
        :                        $HEALTH[2];
}

sub dispatch {
    my $self = shift;
    my ( $msgs, $listener, $sumweight ) = @_;

    state $healthfile = $listener->owner->confdata->{healthfile};
    state $shutdown   = $listener->owner->confdata->{shutdown};
    state $warn       = $listener->owner->confdata->{summary}{ok};
    state $crisis     = $listener->owner->confdata->{summary}{warn};
    state $old_health = 'ok';
    state $verbose
        = $listener->owner->verbose
        || grep {/HealthMonitor/} $ENV{VERBOSE}
        || '';

    my $health = $self->weight2health( $sumweight, $warn, $crisis );

    # create file on first pass and whenever health changes
    #
    say scalar localtime()
        . " HealthMonitor: weight '$sumweight'; "
        . "old_health: $old_health; health: $health"
        if $verbose;

    $self->create_parent_dirs($healthfile)
        if $self->firsttime;

    if (    $health ne $old_health
         || $self->firsttime ) {
        say "Changing health file status from $old_health to $health"
            if $verbose;

        open my $fh, '>' . $healthfile;
        say $fh "health = $health";

        $old_health = $health;
        $self->firsttime(0);

    }
    else {
        system( '/bin/touch', $healthfile );
    }
    if ( $sumweight >= $crisis ) {

        say "****    CRISIS    *****    CRISIS    *****    CRISIS   ******",
            "\nInvoking shutdown script $shutdown\n"
            if $verbose;

	$self->owner->tell_db_Im_dying();
        $listener->owner->shutdown(1);
        system($shutdown );
    }

    return;
}

sub create_parent_dirs {
    my $self = shift;
    my ($path) = @_;

    make_path dirname $path;
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
