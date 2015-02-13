package AN::Msg_xlator;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use English '-no_match_vars';
use File::Basename;
use File::Spec::Functions 'catdir';
use Const::Fast;
use AN::Common;

# ======================================================================
# CLASS ATTRIBUTES
#
use Class::Tiny qw(agents msg_dir language pid program string strings sys );

# ======================================================================
# CONSTANTS
#
const my $COMMA      => q{,};
const my $XML_SUFFIX => q{.xml};
const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Report whether or not, the strings table for a particular process
# (pid) has been loaded. If not, initalize the 'string' and 'strings'
# hashes, and make them availablke as attributes of the object.
#
sub strings_table_loaded {
    my $self = shift;
    my ($pid) = @_;

    my $exists = exists $self->agents->{$pid}->{strings};

    $self->agents->{$pid}->{strings} ||= {};
    $self->agents->{$pid}->{string}  ||= {};

    $self->strings( $self->agents->{$pid}->{strings} );
    $self->string( $self->agents->{$pid}->{string} );
    return $exists;
}

# ----------------------------------------------------------------------
# Read the message file, and create a hash listing all languages
# defined in the file.
#
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

# ----------------------------------------------------------------------
# Look up a string in a specified language. Load the message file if
# necessary.
#
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

    Msg_xlator.pm - Fetch messages by tag in appropriate language

=head1 VERSION

    This document describes Msg_xlator.pm version 1.0.0

=head1 SYNOPSIS

    use AN::Msg_xlator;

    my $agent = { PID      => $PID,
                  filename => basename $PROGRAM_NAME,
                  sys => { error_limit => $max_retries },
                };
    my $msg_xlator = AN::Msg_xlator->new($pid, $agent);
    my $fmt_str = $msg_xlator->lookup_msg($PID, 'POWER SUPPLY INPUT VOLTAGE LOW MSG')

=head1 DESCRIPTION

This module implements the message lookup subsystem. It reads the xml
file for a program or component, and then looks up string identifying
tags and returns the corresponding message string in the specified
language.


=head1 METHODS

Objects of this class take succint message tags and look them up in a
message file, extracting a lengthier message string in the specified
language.

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<PID N>

This is a unique identifying number or string. Since the process id of
a running program is guaranteed to be unique on a given system, this
is the natural value to use.

=item B<agents { pid_num =E<gt> $agent_hash }>

The agent_hash contains the name of the program which originated the
message tag we are looking up, and the directory in which the
program's message xml file is located. 

=item B<sys =E<gt> { error_limit =E<gt> number } >

The number of times the AN::Common routines should attemp to look up the
string, before giving up.

=back

=item B<lookup_msg( $id, $tag [, $language] )>

Look up the message corresponding to the speciefied message tag for process $id
in the specified language. If no lannguage is specified, use some default language.

=back

=head1 DEPENDENCIES

=over 4

=item B<AN::Common>

Predefined packages containing routines to read message files and look
up strings.

=item B<Const::Fast>

Make constants that run faster than Readonly, and are more flexible
and more useable than C<use constant>.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<File::Spec::Functions> I<code>

Portably perform operations on file names.

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

    Alteeve's Niche!  
    -  https://alteeve.ca

    Tom Legrady           December 2014
    - tom@alteeve.ca	
    - tom@tomlegrady.com
=cut

# End of File
# ======================================================================

