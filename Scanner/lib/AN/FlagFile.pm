package AN::FlagFile;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;
use File::Basename;

use Const::Fast;

# ======================================================================
# Attribures
#
const my @ATTRIBUTES => (qw( pidfile dir data ));

# ======================================================================
# CONSTANTS
#
const my $COMMA    => q{,};
const my $DOT      => q{.};
const my $DOTSLASH => q{./};
const my $PROG     => ( fileparse($PROGRAM_NAME) )[0];
const my $SLASH    => q{/};

const my $PIDFILE_TAG => 'pidfile';

## use critic ( ProhibitMagicNumbers )
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

sub create_file {
    my $self = shift;
    my ($args) = @_;

    my $filename = $self->full_file_path( $args->{tag} || '' );

    open my $pidfile, '>', $filename
        or die "Could not create pidfile '$filename', $!";
    print $pidfile $args->{data}
        if $args->{data};
    close $pidfile
        or die "Could not close pidfile '$filename', $!";
    return;
}

sub create_pid_file {
    my $self = shift;

    $self->create_file( { data => $self->data, tag => $PIDFILE_TAG } );
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

    $self->create_file( { tag => $tag } );
}

# Returns true on success, false on 'could not delete';
# Does not check for file existence, but will return false.
#
sub delete_marker_file {
    my $self = shift;
    my ($tag) = @_;

    return unlink $self->full_file_path($tag);
}

# ----------------------------------------------------------------------
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

    AN::FlagFile - use files to identify running processes, critical events;

=head1 VERSION

This document describes AN::FlagFile.pm version 0.0.1

=head1 SYNOPSIS

    use English '-no_match_var';
    use AN::FlagFile;

    my $flagfile = AN::FlagFile->new({ dir      => $dir,
                                       hostname => $hostname,
                                       pid      => $PID
                                     });


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

=item B<hostname>

The hostname on which the process is running

=item B<pid>

The process ID.

=back

=back

=head1 DEPENDENCIES

=over 4

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<version> I<core since 5.9.0>

Parses version strings.

=item B<Carp> I<core since perl 5>

Complain about user errors as if they occur at call point, not in the module.

=item B<Const::Fast>

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
230:	final indentation level: 1

Final nesting depth of '{'s is 1
The most recent un-matched '{' is on line 49
49: sub _init {
              ^
230:	To save a full .LOG file rerun with -g
