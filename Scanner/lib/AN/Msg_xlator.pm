package AN::Msg_xlator;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;
use File::Spec::Functions 'catdir';

use FindBin qw($Bin);
use Clone 'clone';
use Const::Fast;

use AN::Common;

use Class::Tiny qw(agents msg_dir language pid program string strings sys );

# ======================================================================
# CONSTANTS
#
const my $COMMA => q{,};

const my $XML_SUFFIX => q{.xml};

const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

# ======================================================================
# Subroutines
#

# ======================================================================
# Methods
#

sub strings_table_loaded {
    my ( $self, $pid ) = @_;

    my $exists = exists $self->agents->{$pid}->{strings};

    $self->agents->{$pid}->{strings} ||= {};
    $self->agents->{$pid}->{string}  ||= {};

    $self->strings( $self->agents->{$pid}->{strings} );
    $self->string( $self->agents->{$pid}->{string} );
    return $exists;
}

sub load_strings_table {
    my $self = shift;
    my ($metadata) = @_;

    my $filename = catdir( $metadata->{msg_dir},
                           ( $metadata->{program} . $XML_SUFFIX ) );

    AN::Common::read_strings( $self, $filename );
    $self->language( {} );
    for my $lang ( @{ AN::Common::get_languages($self) } ) {
        my ( $tag, $value ) = split $COMMA, $lang;
        $self->language()->{$tag} = $value;
    }

    return;
}

sub lookup_msg {
    my $self = shift;
    my ( $src, $tag, $agent ) = @_;

    $self->agents()->{$src} = $agent
        unless $src and exists $self->agents()->{$src};
    my $metadata = $self->agents()->{$src};

    $self->load_strings_table($metadata)
        unless $self->strings_table_loaded( $metadata, $PID );
    my $xlated = AN::Common::get_string( $self, $tag );
    return $xlated;
}

# ......................................................................
#

# ======================================================================
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

    Mdg_xlator.pm - Fetch messages by tag in appropriate language

=head1 VERSION

    This document describes Msg_xlator.pm version 0.0.1

=head1 SYNOPSIS

    use AN::Msg_xlator;
    use English 'no_match_vars';
    use File::Basename;

    my $pid = $PID;
    my $agent = { PID      => $PID,
                  filename => basename $PROGRAM_NAME,
                  msg_dir  => '/path/to/messages/xml/files/',
                };
    my $msg_xlator = AN::Msg_xlator->new($pid, $agent);
    my $fmt_str = $msg_xlator->lookup_msg($PID, 'POWER SUPPLY INPUT VOLTAGE LOW MSG')

=head1 DESCRIPTION

This module implements the message lookup subsystem. It reads the xml
file for a program or component, and then looks up string identifying
tags and returns the corresponding message string in the specified
language.


=head1 METHODS

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<PID =E<gt> N>

This is a unique identifying number or string. Since the process id of
a running program is guaranteed to be unique on a given system, this
is the natural value to use.

=item B<msg_dir =E<gt> '/path/to/dir/containing/message/files/'>

The directory where message files will be found. 

=item B<filename =E<gt> string>

The name of a particular subsystem. Message strings for this program /
subsystem will be found in the msg_dir directory in a file whose name
is "filename" with a ".xml" suffix.

=back

=item B<lookup_msg( $id, $tag [, $language] )>

Look up the message corresponding to the speciefied message tag for process $id
in the specified language. If no lannguage is specified, use some default language.

=back

=head1 DEPENDENCIES

=over 4

=item B<Carp> I<core>

Complain about arguments from the caller, not the callee.

=item B<Clone>

Make deep copies of data structures.

=item B<Const::Fast>

Make constants that run faster than Readonly, and are more flexible and more useable than C<use constant>.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<FileHandle> I<code>

Provides access to FileHandle / IO::* attributes.

=item B<FindBin> I<core>

Determine which directory contains the current program.

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

    Alteeve's Niche!  
    -  https://alteeve.ca

    Tom Legrady           December 2014
    - tom@alteeve.ca	
    - tom@tomlegrady.com
=cut

# End of File
# ======================================================================

