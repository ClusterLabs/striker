package AN::HealthMonitor;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Const::Fast;
use English '-no_match_vars';
use File::Basename;
use File::Path 'make_path';

# ======================================================================
# CLASS ATTRIBUTES
#
use Class::Tiny qw(owner), { firsttime => sub {1}
                           };

# ======================================================================
# CONSTANTS
#
const my @HEALTH => ( 'ok', 'warning', 'critical' );

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Convert a weighted sum of alerts to an overal status, 'OK',
# 'WARNING' or 'CRISIS', based on ranges defined in the configuration
# file.
#
sub weight2health {
    my $self = shift;
    my ( $sumweight, $warn, $crisis ) = @_;

    return
          $sumweight < $warn   ? $HEALTH[0]
        : $sumweight < $crisis ? $HEALTH[1]
        :                        $HEALTH[2];
}

# ----------------------------------------------------------------------
# Determine the overall health of the system. Generate a health file
# and update it every time the health changes; touch the file every
# loop, so it should never be 'older' than 30 seconds.
#
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
    if ( $sumweight >= $crisis
      && $self->program ne 'dashboard'  ) {
        say "****    CRISIS    *****    CRISIS    *****    CRISIS   ******",
            "\nInvoking shutdown script $shutdown\n"
            if $verbose;

        $self->owner->tell_db_Im_dying();
        $listener->owner->shutdown(1);
        system($shutdown );
    }
    return;
}

# ----------------------------------------------------------------------
# Create a file path hierarchy.
#
sub create_parent_dirs {
    my $self = shift;
    my ($path) = @_;

    my $dir = dirname $path;
    make_path $dir
        unless -e $dir;
}

# ======================================================================
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     HealthMonitor.pm - Dispatcher module to monitor overall server health

=head1 VERSION

This document describes HealthMonitor.pm version 1.0.0

=head1 SYNOPSIS

    use HealthMonitor;
    my $hm = HealthMonitor->new({owner => $owner });
    $hm->dispatch( \@msgs, $listener, $healthweight );

=head1 DESCRIPTION

This module implements the HealthMonitor.

=head1 METHODS

This class provides a single method, B<dispatch>, which is invoked one
a loop to handle the aggregated alert messages. Unlike other
dispatchers, HealthMonitor looks at the weighted sum, rather than the
individual messages, and shuts down the system, when the value exceeds
a specified limit.

=over 4

=item B<dispatch msgs, recipient, sum>

Determine the overall health of the system. Generate a health file and
update it every time the health changes; touch the file every loop, so
it should never be 'older' than 30 seconds.

=back

=head1 DEPENDENCIES

=over 4

=item B<Const::Fast>

Provide fast constants.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parse file paths into directory, filename and suffix.

=item B<File::Path> I<core>

Create or remove directory trees.

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
