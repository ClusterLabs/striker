package AN::DBS;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;

use FindBin qw($Bin);
use Const::Fast;
use DBI;

use AN::Common;
use AN::OneDB;
use AN::OneAlert;
use AN::Listener;

use Class::Tiny qw( path dbini dbs);

sub BUILD {
    my $self = shift; 
    $self->connect_dbs();
}

# ======================================================================
# CONSTANTS
#
const my $ASSIGN      => q{=};
const my $DOUBLECOLON => q{::};
const my $DB          => q{db};

# ======================================================================
# Subroutines
#

# ......................................................................
# Private Methods
#
sub is_pw_field {
    return 1 <= scalar @_ 
	&& $_[0] eq 'password';
}

sub add_db {
    my $self = shift;
    my ($db) = @_;

    push @{ $self->dbs() }, $db;
    return;
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
	
        my $prefix   = $DB . $DOUBLECOLON . $set . $DOUBLECOLON;
    KEY:
        for my $key ( sort keys %$onedbini ) {
            next KEY
                if is_pw_field($key);
            push @dump, $prefix . $key . $ASSIGN . $onedbini->{$key};
        }

        # 0-based array de-reference, but 1-based output
        #
        my $oneDB_prefix = $DB . $DOUBLECOLON . ( $idx + 1 );
        push @dump, $self->dbs->[$idx]->dump_metadata($oneDB_prefix);
        $idx++;
    }

    return join "\n", @dump;
}

sub insert_raw_record {
    my $self = shift;
    my ($args) = @_;

    for my $db ( @{ $self->dbs() } ) {
        $db->insert_raw_record($args)
            or carp "Problem inserting record @$args into ";
    }
    return;
}

sub fetch_alert_data {
    my $self = shift;
    my ($proc_info) = @_;

    my $alerts = [];
    for my $db ( @{ $self->dbs() } ) {
	my $db_data = $db->fetch_alert_data($proc_info);
	for my $idx ( keys %$db_data ) {
	    my $record = $db_data->{$idx};
	    @{$record}{qw(db db_type)} = ($db->dbini()->{host},
				       $db->dbini()->{db_type},
		);
	    push @$alerts,  AN::OneAlert->new($record);
	}
    }
    return $alerts;
}

sub fetch_alert_listeners {
    my $self = shift;
    my ( $owner ) = @_;
    
    for my $db ( @{ $self->dbs() } ) {
        my $hlisteners = $db->fetch_alert_listeners();

        my $listeners = [];
        for my $idx ( sort keys %$hlisteners ) {
            my $data         = $hlisteners->{$idx};
            $data->{db}      = $db->dbini()->{host};
            $data->{db_type} = $db->dbini()->{db_type};
	    $data->{owner}   = $owner;
	    push @{$listeners}, AN::Listener->new($data);
        }
        return $listeners if @$listeners;
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
