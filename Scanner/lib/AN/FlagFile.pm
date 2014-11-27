package AN::FlagFile;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use Const::Fast;

# ======================================================================
# Attribures
#
const my @ATTRIBUTES => (qw( pidfile dir data ));

# ======================================================================
# CONSTANTS
#
const my $COMMA        => q{,};
const my $DOT          => q{.};
const my $DOTSLASH     => q{./};
const my $SLASH        => q{/};
const my $EMPTY_STRING => q{};

const my $SECONDS_IN_A_DAY => 24 * 60 * 60;

const my $PIDFILE_TAG => 'pidfile';

const my $NO_SUCH_FILE   => 'no such file';
const my $FILE_STATUS_OK => 'file status ok';

# ======================================================================
# Subroutines
#
# ......................................................................
# Standard constructor. In subclasses, 'inherit' this constructor, but
# write a new _init()
#
sub new {
    my ( $class, @args ) = @_;

    my $obj = bless {}, $class;
    $obj->_init(@args);

    return $obj;
}

# ......................................................................
#
sub _init {
    my ( $self, @args ) = @_;

    if ( scalar @args > 1 ) {
        for my $i ( 0 .. $#args ) {
            my ( $k, $v ) = ( $args[$i], $args[ $i + 1 ] );
            $self->{$k} = $v;
        }
    }
    elsif ( 'HASH' eq ref $args[0] ) {
        my $h = $args[0];
        for my $attr ( keys %$h ) {
            $self->$attr( $h->{$attr} );
        }
    }
    return;
}

# ......................................................................
# accessor
#
for my $attr (@ATTRIBUTES) {
    eval " 
        sub $attr {
            my \$self = shift;
	    if ( \@_ ) {\$self->{$attr} = shift;}
	    return \$self->{$attr};
	}";
}

# ......................................................................
# Private Accessors
#

# ......................................................................
# Private Methods
#

# ......................................................................
# Methods
#
# Merge path and filename into a full path.
# If a 'marker file' tag has been provided, prefix it to the name,
# otherwise use the string specified in $PIDFILE_TAG as the tag;

sub full_file_path {
    my $self = shift;
    my ($tag) = @_;

    my $filename = $self->dir() . $SLASH . $tag . $DOT . $self->pidfile;

    return $filename;
}

sub _create_file {
    my $self = shift;
    my ($args) = @_;

    my $filename = $self->full_file_path( $args->{tag} || $EMPTY_STRING );

    open my $pidfile, '>', $filename
        or die "Could not create pidfile '$filename', $OS_ERROR";
    print {$pidfile} $args->{data}
        if $args->{data};
    close $pidfile
        or die "Could not close pidfile '$filename', $OS_ERROR";
    return;
}

sub create_pid_file {
    my $self = shift;

    $self->_create_file( { data => $self->data, tag => $PIDFILE_TAG } );
    return;
}

# utime() sets the atime and mtime of a file to the specified times;
# using undef times uses the value of now.
#
sub touch_pid_file {
    my $self = shift;

    utime undef, undef, $self->full_file_path($PIDFILE_TAG);
    return;
}

# Returns true on success, false on 'could not delete';
# Does not check for file existence, but will return false.
#
sub delete_pid_file {
    my $self = shift;

    return unlink $self->full_file_path($PIDFILE_TAG);
}

sub create_marker_file {
    my $self = shift;
    my ($tag) = @_;

    $self->_create_file( { tag => $tag } );
    return;
}

# Returns true on success, false on 'could not delete';
# Does not check for file existence, but will return false.
#
sub delete_marker_file {
    my $self = shift;
    my ($tag) = @_;

    return unlink $self->full_file_path($tag);
}

sub read_pid_file {
    my $self = shift;

    my $filename = $self->full_file_path($PIDFILE_TAG);
    my $retval   = {};

    $retval->{status} = (
        -e $filename
        ? $FILE_STATUS_OK
        : $NO_SUCH_FILE
    );
    $retval->{age} = $SECONDS_IN_A_DAY * -M $filename;
    
    open my $pidfile, '<', $filename
	or die "Could not create pidfile '$filename', $OS_ERROR";
    $retval->{data} = join '', <$pidfile>;
    close $pidfile;

    return $retval;
}

# ----------------------------------------------------------------------
# end of code
1;
__END__



# ======================================================================
=pod

=head1 NAME

    AN::FlagFile - use files to report running processes, critical events;

=head1 VERSION

This document describes AN::FlagFile.pm version 0.0.1

=head1 SYNOPSIS

    use English '-no_match_var';
    use AN::FlagFile;

    my $flagfile = AN::FlagFile->new({ dir      => $dir,
                                       pidfile  => $filename,
                                       data     => $data_to_store_in_pidfile,
                                     });

    $flagfile->full_file_path();

    $flagfile->create_pid_file();
    $flagfile->touch_pid_file();
    $flagfile->read_pid_file();
    $flagfile->delete_pid_file();

    $flagfile->create_marker_file();
    $flagfile->delete_marker_file();


=head1 DESCRIPTION

This module implements the AN::FlagFile system. It stores a file
containing specified data about a running process, as well as files to
identify key events. it also cleans up these files when instructed.

=head1 SUBROUTINES/METHODS

An object of this class represents a scanner object.

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<dir>

The directory that is to contain the files.

=item B<pidfile>

The common component of all files created. This component is prefixed
by 'pidfile.' or by some other user-specified tag, again with a dot
joining it to the common component.

=item B<data>

The data to store in the pidfile.

=back

=item B<full_file_path [$tag]>

Generate the full file name and path for a file, including prefixing
the filename with the specified tag.

=item B<create_pid_file>

Create the file specified by full_file_path( $PIDFILE_TAG ) and
populate it with the data passed to the constructor.

=item B<touch_pid_file>

Modify the mtime and atime values for the pidfile, to demonstrate the
program is running currently.

=item B<read_pid_file>

Verify the file exists, and report its mtime and contents. Essential
for cross-peer communication.

=item B<delete_pid_file>

Delete the file to indicate a clean shutdown.

=item B<create_marker_file>

Similar to creating a pidfile, except with an alternate marker
tag. Intended for cross-peer communication.

=item B<delete_marker_file>

Delete the specified marker file.

=back

=head1 DEPENDENCIES

=over 4

=item B<Perl 5.10>

Versions prior to Perl 5.10 are not supported. In particular, the
'say' and 'state' features are utilized. Anything before 5.10 belongs
in a museum, anyway.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<version> I<core since 5.9.0>

Parses version strings.

=item B<Carp> I<core since perl 5>

Complain about user errors as if they occur in caller, rather than in
the module.

=item B<Const::Fast>

Store magic values. More powerful than the module B<constant>, much
faster than B<Readonly>.

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

=head1 TODO

=over 4

=item Allow data in marker files.

=item Merge pid file and marker file implementation.

=back

=head1 AUTHOR

Alteeve's Niche!  -  https://alteeve.ca

Tom Legrady       -  tom@alteeve.ca	November 2014

=cut

# End of File
# ======================================================================
