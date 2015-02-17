package AN::Screen;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

# ======================================================================
# CLASS ATTRIBUTES
#
use Class::Tiny qw( attr );

# ======================================================================
# METHODS
#
# ----------------------------------------------------------------------
# display alert messages on the screen.
#
sub dispatch {
    my $self = shift;
    my ( $msgs, $owner, $sumweight ) = @_;

    say "Total crisis weight is $sumweight." if $sumweight;
    say for @$msgs;
}

# ======================================================================
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     AN::Screen.pm - Display alert messages on the screen

=head1 VERSION

This document describes AN::Screen.pm version 1.0.0

=head1 SYNOPSIS

    use AN::Screen;
    my $screen = AN::Screen->new();
    $screen->dispatch( \@msgs, $listener, $weight );

=head1 DESCRIPTION

This module provides a mechanism for displaying alert messages on the
screen.

=head1 METHODS

The module provides a single method, B<dispatch>, which takes three
arguments:

=over 4

=item B<msgs array_ref>

An array of strings, aka paragraphs, to send to the recipient.

=item B<listener recipient>

The email address defining a recipient.

=item B<weighted sum>

Weighted sum of all alerts.

=back


=back

=head1 DEPENDENCIES

=over 4

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
