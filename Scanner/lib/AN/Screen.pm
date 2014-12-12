package AN::Screen;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;
use FileHandle;
use IO::Select;
use Time::Local;
use FindBin qw($Bin);

use AN::Msg_xlator;

use Const::Fast;

# ======================================================================
# Object attributes.
#
const my @ATTRIBUTES => (
    qw( )
);

# Create an accessor routine for each attribute. The creation of the
# accessor is simply magic, no need to understand.
#
# 1 - Without 'no strict refs', perl would complain about modifying
# namespace.
#
# 2 - Update the namespace for this module by creating a subroutine
# with the name of the attribute.
#
# 3 - 'set attribute' functionality: When the accessor is called,
# extract the 'self' object. If there is an additional argument - the
# accessor was invoked as $obj->attr($value) - then assign the
# argument to the object attribute.
#
# 4 - 'get attribute' functionality: Return the value of the attribute.
#
for my $attr (@ATTRIBUTES) {
    no strict 'refs';    # Only within this loop, allow creating subs
    *{ __PACKAGE__ . '::' . $attr } = sub {
        my $self = shift;
        if (@_) { $self->{$attr} = shift; }
        return $self->{$attr};
        }
}

# ======================================================================
# CONSTANTS
#
const my $COLON    => q{:};
const my $COMMA    => q{,};
const my $DOTSLASH => q{./};
const my $DOUBLE_QUOTE => q{"};
const my $NEWLINE  => qq{\n};
const my $SLASH    => q{/};
const my $SPACE    => q{ };
const my $PIPE     => q{|};

const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];
			  
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
sub copy_from_args_to_self {
    my $self = shift;
    my (@args) = @_;

    if ( scalar @args > 1 ) {
        for my $i ( 0 .. $#args ) {
            my ( $k, $v ) = ( $args[$i], $args[ $i + 1 ] );
            $self->{$k} = $v;
        }
    }
    elsif ( 'HASH' eq ref $args[0] ) {
        @{$self}{ keys %{ $args[0] } } = values %{ $args[0] };
    }
    return;
}

sub _init {
    my $self = shift;


    $self->copy_from_args_to_self(@_);
    return;
}

# ......................................................................
#
sub dispatch {
    my $self = shift;
    my ( $dispatchee ) = @_;

    say for @$dispatchee;
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
