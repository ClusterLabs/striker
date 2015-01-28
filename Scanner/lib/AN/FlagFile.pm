package AN::FlagFile;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;
use File::Spec::Functions 'catdir';
use Const::Fast;

use Class::Tiny qw( pidfile dir ), { data      => sub { default_data() },
                                     old_files => sub { {} }
                                   };

# ======================================================================
# CONSTANTS
#
const my $DOT  => q{.};
const my $STAR => q{*};

const my $SECONDS_IN_A_DAY => 24 * 60 * 60;

const my $NO_SUCH_FILE      => 'no such file';
const my $FILE_NOT_READABLE => 'file not readable';
const my $FILE_STATUS_OK    => 'file status ok';

my %TAG = ( PIDFILE   => 'pidfile',
            MIGRATING => 'migrating',
            METADATA  => 'metadata',
            CRISIS    => 'crisis' );

# ======================================================================
# Subroutines
#

sub default_data {
    my $now = time;
    return <<"EODATA";
pid:$PID
starttime:$now
EODATA
}

# ......................................................................
# Methods
#
# Merge path, and the specified prefix tag and filename into a full
# path.
#
sub full_file_path {
    my $self = shift;
    my ( $tag, $name ) = @_;

    my $name_part = $name || $self->pidfile;
    my $filename = catdir( $self->dir(), $tag . $DOT . $name_part );

    return $filename;
}

# ......................................................................
# Create a file using the object's path and filename with specified tag,
# and write out specified data.
#
sub create_file {
    my $self = shift;
    my ($args) = @_;

    my $filename = $self->full_file_path( $args->{tag} );

    no warnings;    # ignore msg re. use of $filename in END block
    open my $pidfile, '>', $filename
        or die "Could not create pidfile '$filename', $OS_ERROR";
    print {$pidfile} $args->{data}
        if $args->{data};
    close $pidfile
        or die "Could not close pidfile '$filename', $OS_ERROR";

    END { unlink $filename };    # delete file at program exit.
    return;
}

# ......................................................................
# Report all available tags, or the test for a single tag.
#
# Can be invoked as $obj->get_tag($tag) ( with args $self and $tag )
# or as AN::FlagFile->get_tag($tag) (with arg $tag). Also accept
# AN::FlagFile->get_tag() as shorthand for AN::FlagFile::get_tag(*NAMES*)
#
sub get_tag {
    my ($key) = shift;
    $key = shift if ref $key eq __PACKAGE__;
    $key ||= '*NAMES*';

    if ( $key eq '*NAMES*' ) {
        return [ sort keys %TAG ];
    }
    elsif ( exists $TAG{$key} ) {
        return $TAG{$key};
    }
    else {
        return;
    }
}

sub add_tag {
    shift if @_ && scalar @_ && ref $_[0] eq __PACKAGE__;

    croak( __PACKAGE__ . "::add_tag() requires 2 args, key & value." )
        unless 2 == scalar @_;
    my ( $tag, $value ) = @_;

    $TAG{$tag} = $value;
    return;
}

sub find_marker_files {
    my $self = shift;
    my (@markers) = @_;

    if ( !scalar @markers ) {
        push @markers, AN::FlagFile::get_tag($_)
            for @{ AN::FlagFile::get_tag() };
    }

    my $found = {};
    for my $tag (@markers) {
        my $filename = $self->full_file_path( $tag, $STAR );
        $found->{$tag} = [ glob($filename) ];

        #        $found->{$tag} = $filename if -e $filename;
    }
    return unless scalar keys %$found;
    return $found;
}

# ......................................................................
# Create a pid file and write out data.
#
sub create_pid_file {
    my $self = shift;

    $self->create_file( { data => $self->data, tag => $TAG{PIDFILE} } );
    return;
}

# ......................................................................
# create a non-pid file, using argument to specify tag.
#
sub create_marker_file {
    my $self = shift;
    my ( $tag, $data ) = @_;

    my $args = { tag => $tag };
    $args->{data} = $data if defined $data;

    $self->create_file($args);
    return;
}

# ......................................................................
# Update atime and mtime of the pid file.
#
# utime() sets the atime and mtime of a file to the specified times;
# Using undef arguments uses the current timestamp value.
#
sub touch_pid_file {
    my $self = shift;

    utime undef, undef, $self->full_file_path( $TAG{PIDFILE} );
    return;
}

sub touch_marker_file {
    my $self = shift;

    utime undef, undef, $self->full_file_path( $TAG{METADATA} );
    return;
}

# ......................................................................
# Delete the pid file.
#
# Returns true on success, false on 'could not delete'; Does not check
# for file existence, but will return false if file did not exist.
#
sub delete_pid_file {
    my $self = shift;

    return unlink $self->full_file_path( $TAG{PIDFILE} );
}

# ......................................................................
# Delete non-pid file
#
# Returns true on success, false on 'could not delete'; Does not check
# for file existence, but will return false if file did not exist.
#
sub delete_marker_file {
    my $self = shift;
    my ($tag) = @_;

    return unlink $self->full_file_path($tag);
}

# ......................................................................
# Check for existence of the pid file. Return a hashref with fields:
#
# status - FILE_STATUS_OK if file exists and is readable
#        - FILE_NOT_READABLE if file exists but not readable.
#        - NO_SUCH_FILE if file does not exist.
#
# age    - age of the file in seconds.
#
# data   - the contents of the file.
#
sub read_pid_file {
    my $self = shift;

    local $INPUT_RECORD_SEPARATOR;    # enable SLURP reading

    my $filename = $self->full_file_path( $TAG{PIDFILE} );
    my $retval   = {};

    $retval->{status} = (   !-e $filename ? $NO_SUCH_FILE
                          : !-r $filename ? $FILE_NOT_READABLE
                          :                 $FILE_STATUS_OK );

    # stop here if no file
    #
    return $retval if $retval->{status} eq $NO_SUCH_FILE;

    $retval->{age} = $SECONDS_IN_A_DAY * -M $filename;

    # stop here if file not readable
    #
    return $retval if $retval->{status} eq $FILE_NOT_READABLE;

    open my $pidfile, '<', $filename
        or die "Could not create pidfile '$filename', $OS_ERROR";
    $retval->{data} = <$pidfile>;    # slurp
    close $pidfile;

    return $retval;
}

# ......................................................................
# Determine whether pid file exists.
#
# A status of NO_SUCH_FILE leads to return value of false,
# otherwise the pid file does exist.
#
sub old_pid_file_exists {
    my $self = shift;
    my ($refresh) = @_;

    if ( $refresh
         || !$self->old_files()->{ $TAG{PIDFILE} } ) {
        $self->old_files()->{ $TAG{PIDFILE} } = $self->read_pid_file();
    }
    return $self->old_files()->{ $TAG{PIDFILE} }{status} ne $NO_SUCH_FILE;
}

# ......................................................................
# When was the pid file last refreshed?
#
# Only makes sense if invoked when a file does exist. If no 'age' key
# is found in the hash, undef is returned.
#
sub old_pid_file_age {
    my $self = shift;
    my ($refresh) = @_;

    if ( $refresh
         || !$self->old_files()->{ $TAG{PIDFILE} } ) {
        $self->old_files()->{ $TAG{PIDFILE} } = $self->read_pid_file();
    }
    return $self->old_files()->{ $TAG{PIDFILE} }{age} || undef;
}

# ......................................................................
# What are the contents of the old pid file?
#
# Only makes sense if invoked when a file does exist. If no 'data' key
# is found in the hash, undef is returned.
#
sub old_pid_file_data {
    my $self = shift;
    my ($refresh) = @_;

    if ( $refresh
         || !$self->old_files()->{ $TAG{PIDFILE} } ) {
        $self->old_files()->{ $TAG{PIDFILE} } = $self->read_pid_file();
    }
    return $self->old_files()->{ $TAG{PIDFILE} }{data} || undef;
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

Create the file specified by full_file_path( $TAG{PIDFILE} ) and
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
