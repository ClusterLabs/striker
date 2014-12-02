package AN::Unix;

# _Perl_
use warnings;
use strict;
use 5.014;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;

use FindBin qw($Bin);
use Proc::Background;
use Const::Fast;

# ======================================================================
# CONSTANTS
#
const my $COMMA => q{,};
const my $SLASH => q{/};
const my $PROG  => ( fileparse($PROGRAM_NAME) )[0];

const my $HOSTNAME          => '/bin/hostname';
const my $HOSTNAME_SHORT    => '/bin/hostname --short';
const my $PID2PROC_NAME     => '/bin/ps -p %s -o comm=';
const my $TERMINATE_AT_EXIT => { die_upon_destroy => 1 };

# ======================================================================
# Subroutines
#
sub hostname {

    my $cmd = (   @_ && $_[0] eq '-short'
                ? $HOSTNAME_SHORT
                : $HOSTNAME );

    my $hn = `$cmd`;
    chomp $hn;
    return $hn;
}

sub pid2process {
    my ($pid) = @_;

    my $cmd = sprintf $PID2PROC_NAME, $pid;

    my $name = `$cmd`;
    chomp $name;
    return $name;
}

sub new_bg_process {
    my ($process) = @_;

    my $bg_obj = Proc::Background->new( $TERMINATE_AT_EXIT, $process );
    my $bg_pid = $bg_obj->pid;
    return { process => $bg_obj, pid => $bg_pid };
}

# ----------------------------------------------------------------------
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     Unix.pm - Access to Unix system commands.

=head1 VERSION

This document describes Scanner.pm version 0.0.1

=head1 SYNOPSIS

    use AN::Scanner;
    my $scanner = AN::Scanner->new();


=head1 DESCRIPTION

This module provides the Scanner program implementation. It monitors a
HA system to ensure the system is working properly.

=head1 METHODS

An object of this class represents a scanner object.

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
