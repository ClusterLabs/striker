package AN::Email;

use base 'AN::Screen';

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;
use File::Temp 'tempfile';
use FileHandle;
use IO::Select;
use Time::Local;
use FindBin qw($Bin);

use Const::Fast;

use Class::Tiny qw( owner );

sub BUILD {

    $MAIL::Sendmail::mailcfg{from} = 'tom@alteeve.ca';
}

# ======================================================================
# CONSTANTS
#
const my $PROG   => ( fileparse($PROGRAM_NAME) )[0];
const my $USRBIN => '/usr/bin/mailx';
const my $BIN    => '/bin/mailx';

# ======================================================================
# Subroutines
#

# ......................................................................
#
sub write_to_temp {
    my ($msgs) = @_;

    my ( $fh, $file ) = tempfile();
    say $fh join "\n", @$msgs;
    close $fh;

    return $file;
}

sub send_msg {
    my ( $file, $to, $subject ) = @_;

    state $MAILX = (   -e $USRBIN && -x _ ? $USRBIN
                     : -e $BIN    && -x _ ? $BIN
                     :   die __PACKAGE__ . q{can't find 'mailx'.} );

    #    my $cmd = "$MAILX -A gmail -s '$subject' $to < $file";
    my $cmd = "$MAILX -s '$subject' $to < $file";
    say "Emailing: $cmd";

    return system $cmd;
}

sub dispatch {
    my $self = shift;
    my ( $msgs, $listener, $sumweight ) = @_;

    my $to      = $listener->contact_info;
    my $subject = $sumweight ? "$sumweight CRISIS events on HA scanner"
                :              scalar @$msgs . " Messages from HA scanner";

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
## Please see file perltidy.ERR
