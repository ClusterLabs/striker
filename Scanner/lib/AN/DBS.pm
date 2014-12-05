package AN::DBS;

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
use Const::Fast;

use AN::OneDB;

# ======================================================================
# Object attributes.
#
const my @ATTRIBUTES => (qw( dbs path dbini));

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
const my $ASSIGN      => q{=};
const my $COMMA       => q{,};
const my $DOTSLASH    => q{./};
const my $SLASH       => q{/};
const my $DOUBLECOLON => q{::};

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
        @{$self}{ keys %{ $args[0] } } = values %{ $args[0] };
    }
    $self->connect_dbs();

    return;

}

sub DESTROY {
    my $self = shift;

    for my $dbh ( $self->_all_dbhs ) {
        $self->_halt_process( $dbh, $self->_process_id($dbh) );
    }
}

sub add_db {
    my $self = shift;
    my ($db) = @_;

    push @{ $self->dbs() }, $db;
    return;
}

# ......................................................................
# Private Accessors
#

sub x_process_id {
    my $self = shift;
    my ( $dbh, $new_value ) = @_;

    die( __PACKAGE__ . " method _process_id( \$dbh, \$id ) not enough args." )
        if scalar @_ <= 1;
    die( __PACKAGE__ . " method _process_id( \$dbh, \$id ) too many args." )
        if scalar @_ > 3;

    return $self->{process_id}{$dbh} if not defined $new_value;

    $self->{process_id}{$dbh} = $new_value;
    return;
}

# ......................................................................
# Private Methods
#
sub is_pw_field {
    return $_[0] eq 'password';
}

# ......................................................................
# Methods
#

sub connect_dbs {
    my $self = shift;

    my %cfg = ( path => $self->path );
    AN::Common::read_configuration_file( \%cfg );

    $self->dbini( $cfg{db} );

    $self->dbs( [] );
    for my $tag ( sort keys %{ $self->dbini } ) {
        $self->add_db( AN::OneDB->new( { dbini => $self->dbini->{$tag} } ) );
    }

}

sub dump_metadata {
    my $self = shift;

    my @dump;

    my $dbini = $self->dbini;
    my $idx   = 0;
    for my $set ( sort keys %$dbini ) {
        my $onedbini = $dbini->{$set};
    KEY:
        for my $key ( sort keys %$onedbini ) {
            next KEY
                if is_pw_field($key);
            push @dump,
                $set . $DOUBLECOLON . $key . $ASSIGN . $onedbini->{$key};
        }
	# 0-based array de-reference, but 1-based output
	#
        push @dump, $self->dbs->[$idx]->dump_metadata( $idx + 1 );
        $idx++;
    }

    return join "\n", @dump;
}

sub create_db_table {
    my $self = shift;
    my ( $name, $schema ) = @_;

    for my $db ( @{ $self->dbs() } ) {
	my $exists = $db->table_exists( $name );
	if ( $exists ) {
	    die "Table '$name' exists with schema differing from '\n$schema'"
		unless $db->schema_matches( $name, $schema );
	}
	else {
	    $db->create_table( $name, $schema );
	}
    }
    return 1;
}

sub insert_raw_record {
    my $self = shift;
    my ( $args ) = @_;

    for my $db ( @{ $self->dbs() } ) {
	$db->insert_raw_record( $args )
	    or carp "Problem inserting record @$args into ";
    }
    return;
}
# ----------------------------------------------------------------------
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     Scanner.pm - System monitoring loop

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
