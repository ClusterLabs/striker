package AN::Email;

use parent 'AN::Screen';

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use Carp;
use Const::Fast;
use English '-no_match_vars';
use File::Basename;
use File::Temp 'tempfile';

# ======================================================================
# CLASS ATTRIBUTES
#
use Class::Tiny qw( owner );

# ======================================================================
# CONSTANTS
#
const my $PROG   => ( fileparse($PROGRAM_NAME) )[0];
const my $USRBIN => '/usr/bin/mailx';
const my $BIN    => '/bin/mailx';

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Save the body of the email to a file.
#
sub write_to_temp {
    my ($msgs) = @_;

    my ( $fh, $file ) = tempfile();
    say $fh join "\n", @$msgs;
    close $fh;

    return $file;
}

# ----------------------------------------------------------------------
# The mailx program is either in /usr/bin/mailx or in /bin/mailx. Find
# the one that exists, and use it to send an email.
#
sub send_msg {
    my ( $file, $to, $subject ) = @_;

    state $verbose = grep {/email/} $ENV{VERBOSE};
    state $MAILX = (   -e $USRBIN && -x _ ? $USRBIN
                     : -e $BIN    && -x _ ? $BIN
                     :   die __PACKAGE__ . q{can't find 'mailx'.} );

    #    my $cmd = "$MAILX -A gmail -s '$subject' $to < $file";
    my $cmd = "$MAILX -s '$subject' $to < $file";
    say "Emailing: $cmd"
        if $verbose;

    return system $cmd;
}

# ----------------------------------------------------------------------
# Generate a message, save it to a file, send off the email, and finally
# delete the file.
#
sub dispatch {
    my $self = shift;
    my ( $msgs, $listener, $sumweight ) = @_;

    my $to = $listener->contact_info;
    my $subject
        = $sumweight
        ? "$sumweight CRISIS events on HA scanner"
        : scalar @$msgs . " Messages from HA scanner";

    my $file = write_to_temp $msgs;

    if ( send_msg $file, $to, $subject ) {    # Had an error?
        carp "ERROR sending email '$file' to '$to' containing\n'@$msgs'";
    }
    else {
        unlink $file;
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

     Email.pm - package to handle email messages.

=head1 VERSION

This document describes Email.pm version 1.0.0

=head1 SYNOPSIS

    use AN::Email;
    my $email = AN::Email->new();
    $email->dispatch( \@msgs, $listener, $weight );

=head1 DESCRIPTION

This module provides a mechanism for sending email messages.

=head1 METHODS

The module provides a single method, B<dispatch>, which takes three arguments:

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

=item B<Carp> I<core>

Report errors as occuring at caller site.

=item B<Const::Fast>

Provides fast constants.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.



=item B<version> I<core since 5.9.0>

Parses version strings.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<FileHandle> I<code>

Provides access to FileHandle / IO::* attributes.

=item B<File::Temp> I<core>

Return name and handle of a temporary file safely.

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
