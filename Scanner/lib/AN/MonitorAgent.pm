package AN::MonitorAgent;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Const::Fast;
use English '-no_match_vars';

# ======================================================================
# CONSTANTS
#
const my $COMMA     => q{,};
const my $SUFFIX_QR => qr{         # regex to extract filename suffix
                           [.]     # starts with a literal dot 
                           [^.]+   # sequence of non-dot characters
                           \z      # continuing until end of string
                         }xms;

# ======================================================================
# CLASS ATTRIBUTES & CONTRUCTOR
#
use Class::Tiny qw(ignorefile agentdir),
    { verbose => sub { 0; },
      ignore  => sub { [qw( .conf .rc .init )] }, };

sub BUILD {
    my $self = shift;
    my ($args) = @_;

    # Separate CSV values into separate arg elements.
    #
    $self->ignore( [ split $COMMA, join $COMMA, @{ $self->ignore } ] );

    return;
}

# ======================================================================
# Methods
#

# ......................................................................
# Scan files in the directory, comparing against a persistent list
# return list of additions and deletions. Ignore specified suffixes,
# and explicitly excluded files.
#
sub scan_files {
    my $self = shift;

    # If any suffixes are specified in 'ignore', turn them
    # into keys in a persistent hash. Use '1' as the value for the key,
    # value is never used. only do the expansion the first time through.
    # Similarly create a hash of files to be ignored.
    #
    state $ignore;
    state $ignorefile = { map { $_ => 1 } @{ $self->ignorefile } };

    @{$ignore}{ @{ $self->ignore() } } = (1) x scalar @{ $self->ignore() }
        if ( not $ignore ) && scalar @{ $self->ignore() };

    # Persistent list of files. Reset associated values to zero. During
    # scan, update value to 1. At end, any file names with a value of
    # zero have been removed, and so hash value has not been updated.
    #
    state %files;
    @files{ keys %files } = (0) x scalar keys %files;

    my (@added);
FILE:
    for my $file ( glob $self->agentdir() . '/*' ) {
        my ( $name, $dir, $suffix ) = fileparse( $file, $SUFFIX_QR );
        next FILE
            if $suffix and exists $ignore->{$suffix};
        next FILE
            if $ignorefile->{$name};
        my $fullname = $suffix ? $name . $suffix : $name;
        push @added, $fullname
            unless exists $files{$fullname};
        $files{$fullname} = 1;    # mark as present
    }

    # detect and drop deleted files
    #
    my (@dropped) = sort grep { 0 == $files{$_} }
        keys %files;    # file keys with zero value.
    delete @files{@dropped};

    @added = sort @added;
    return ( \@added, \@dropped );
}

1;

__END__
# ======================================================================
# POD

__END__

=head1 NAME

     MonitorAgent - Check agents dir for added or removed files.

=head1 VERSION

This document describes AN::MonitorAgent.pm version 1.0.0

=head1 SYNOPSIS

    use AN::MonitorAgent

    my $ma = AN::MonitorAgent->new( { ignorefile => ['node_monitor'],
                                      agentdir   => '/usr/share/striker/Agents',
                                      verbose    => 1,
                                    } );
    my ($added, $removed) = $ma->$scan_files();

=head1 DESCRIPTION

This module implements the AN::MonitorAgent class, which monitors the
Agents directory to determine programs which have been added or
removed.

=head1 METHODS

An object of this class implements a constructor and a single method

=over 4

=item B<new>

The constructor takes a few arguments in the form of a single hash
reference, or else as pairs of arguments specifying key name and
value.

=over 4

=item B<agentdir path>

Path to the directory to be scanned for additions and removals.

=item B<ignore .conf,.rc,.init>

Ignore filenames with these suffixes. These additional files are meant
to provide configuration data for the code files. A CSV list can be
provided, or else multiple calls to the same command-line argument
invoked, in the more verbose format:

    ignore .conf  -ignore .rc  -ignore .init

By default, .conf, .rc and .init files are ignored. But the default
list is discarded if the user specifies any -ignore options. So if you
want to add to the default list, rather than replace it, you will need
to include '.conf,.rc,.init' in your ignore list.

=item B<ignorefile arrayref>

Ignore any of the filenames listed in the array ref.

=item B<verbose>

Output a message even if no files have been added or deleted.

=back

=item B<scan_files>

Scan files in the directory, comparing against a persistent list
return list of additions and deletions. Ignore specified suffixes,
and explicitly excluded files.

=back

=head1 DEPENDENCIES

=over 4

=item B<Class::Tiny>

A simple OO framework. "Boilerplate is the root of all evil"

=item B<Const::Fast>

Provides fast constants.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

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

