package AN::Bonding;

use parent 'AN::SNMP::APC_UPS';    # inherit from AN::SNMP_APC_UPS

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
use English '-no_match_vars';
use File::Basename;
our $VERSION = '1.0.0';

use Data::Dumper;
use Const::Fast;

# ======================================================================
# CLASS ATTRIBUTES & CONSTRUCTOR

use Class::Tiny qw( ), {prev => sub { {} },
			hw_addr => sub { {} },
                       } ;

sub BUILD {
    my $self = shift;

    return unless ref $self eq __PACKAGE__;
    

    return;
}

# ======================================================================
# CONSTANTS
#

const my $SLASH => q{/};
const my $SPACE => q{ };

const my $TAG => { current_slave => 'Currently Active Slave',
		   combined_mii  => 'Combined MII Status',
		   single_mii    => 'Single MII_Status',
		   speed         => 'Single Side Speed',
		   duplex        => 'duplex',
		   hw_address    => 'permament hw address'
                 };
# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Compare variables with specific values, such as 'battery replace',
# which may be 'needed' or 'unneeded'. This routine is specific to
# known agents.
#
sub eval_discrete_status {
    my $self = shift;
    my ($args) = @_;

    my $msg
        = { args => '', tag => '', label => '', newval => '', status => '' };

    if ( $args->{tag} eq $TAG->{current_slave} ) {
	$msg->{status} = 'OK';
    }
    elsif ( $args->{tag} eq $TAG->{combined_mii}
	    || $args->{tag} eq $TAG->{single_mii}
	) {
	$msg->{status} = $args->{value} eq 'up' ? 'OK' : 'WARN';
    }
    elsif ( $args->{tag} eq $TAG->{speed}
	    || $args->{tag} eq $TAG->{duplex}
	    || $args->{tag} eq $TAG->{hw_address}
	) {
	if ( $args->{value} eq 'sides differ' ) {
	    $msg->{status} = 'WARNING';
	    $msg->{args} = $args->{rec_meta}{values};
	}
	else {
	    $msg->{status} =  'OK';
	}
    }

    $msg->{label}  = $args->{metadata}{file};
    $msg->{tag}    = $args->{tag};
    $args->{prev_status} ||= $msg->{status};
    $msg->{args} = "link=$args->{metadata}{ident}"
        if exists $args->{metadata}{ident};


    $self->compare_sides_or_report_record( $args, $msg );

    return ( $msg->{status}, $msg->{newval} || $args->{value} );
}

# ----------------------------------------------------------------------
# 
sub process_header {
    my $self = shift;
    my ( $name, $fh ) = @_;

  HEADER:
    while ( my $line = <$fh> ) {
	last HEADER if $line !~ m{\w};
    }
    return;
}

# ----------------------------------------------------------------------
# 
sub process_combined_section {
    my $self = shift;
    my ( $name, $fh ) = @_;

    my $args = { rec_meta    => {},
		 prev_status => '',
		 prev_value  => '',
		 metadata    => {name => $self->confdata()->{host},
				 file => $name,
				 ip => $self->confdata->{ip},
				 type => $self->confdata->{type},
		 }};

  COMBINED:
    while ( my $line = <$fh> ) {
	last COMBINED if $line !~ m{\w};
	if ( $line =~ m{Currently Active Slave: (\S+)}) {
	    $args->{value} = $1;
	    $args->{tag} = $TAG->{current_slave};
	}
	elsif ( $line =~ m{MII Status: (\S+)}) {
	    $args->{value} = $1;
	    $args->{tag} = $TAG->{combined_mii};

	}
	if ( exists $args->{value} ) { # If line has data to report .... 
	    my ( $status, $newvalue ) = $self->eval_status($args);
	    $self->prev->{$name}{$TAG->{current_slave}}{value} = $newvalue;
	    $self->prev->{$name}{$TAG->{current_slave}}{status} = $status;
	}
    }
    return;
}
# ----------------------------------------------------------------------
# 
sub process_section {
    my $self = shift;
    my ( $name, $fh ) = @_;

    my $args = { rec_meta    => {},
		 prev_status => '',
		 prev_value  => '',
		 metadata    => {name => $self->confdata()->{host},
				 file => $name,
				 ip => $self->confdata->{ip},
				 type => $self->confdata->{type},
		 }};

    my $side_info = {};
    my $ident;
  SECTION_ONE:
    while ( my $line = <$fh> ) {
	last SECTION_ONE if $line !~ m{\w};
	if ( $line =~ m{Slave Interface: (\S+)}) {
	    $args->{metadata}->{ident} = $1;
	    $side_info->{ident} = $1;
	}
	elsif ( $line =~ m{MII Status: (\S+)}) {
	    $args->{value} = $1;
	    $args->{tag} = $TAG->{single_mii};
	}
	elsif ( $line =~ m{Speed: (\S+)\s(\S+)}) {
	    $args->{value} = $1;
	    $side_info->{speed} = $1;
	    $args->{rec_meta}{units} = $2;
	    $args->{tag} = $TAG->{speed};
	}
	elsif ( $line =~ m{Duplex: (\S+)}) {
	    $args->{value} = $1;
	    $side_info->{speed} = $1;
	    $args->{tag} = $TAG->{duplex};
	}
	elsif ( $line =~ m{Permanent HW addr: (\S+)}) {
	    my $tmp = $1;
	    my ( $sec, $min ) = localtime;
	    if ( $min == 4 ) {	# report hw addr at start of hour
		$args->{value} = $tmp;
		$args->{tag} = $TAG->{hw_address};
	    }
	}
	if ( exists $args->{value} ) { # If line has data to report .... 
	    $side_info->{$args->{tag}} = $args->{value};
	    my ( $status, $newvalue ) = $self->eval_status($args);
	    $self->prev->{$name}{$args->{tag}}{value} = $newvalue;
	    $self->prev->{$name}{$args->{tag}}{status} = $status;
	    delete $args->{value};
	}
    }
    return $side_info;
}
# ----------------------------------------------------------------------
#
sub compare_sides {
    my $self = shift;
    my ( $name, $side_one, $side_two ) = @_;

    my $args = { rec_meta    => {},
		 prev_status => '',
		 prev_value  => '',
		 metadata    => {name => $self->confdata()->{host},
				 file => $name,
				 ip => $self->confdata->{ip},
				 type => $self->confdata->{type},
		 }};

    my @names = ( $side_one->{ident}, $side_two->{ident} );
  KEY:
    for my $key ( keys %$side_one ) {
	next KEY if $key eq 'ident';

	if ($side_one->{$key} ne $side_two->{$key}) {
	    $args->{tag} = $key;
	    $args->{value} = 'sides differ';
	    $args->{rec_meta}{values}
	    = "$names[0]=$side_one->{$key};$names[1]=$side_two->{$key}";
	    my ( $status, $newvalue ) = $self->eval_status($args);	    
	}
    }
    return;
}
# ----------------------------------------------------------------------
# 
sub parse_bond_status {
    my $self = shift;
    my ( $file ) = @_;

    open my $fh, '<', $file
	or die "COuld not open file '$file': $!.\n";

    my $name = basename $file;
    $self->process_header( $name, $fh );
    $self->process_combined_section( $name, $fh );
    my $side_one = $self->process_section( $name, $fh );
    my $side_two = $self->process_section( $name, $fh );
    $self->compare_sides( $name, $side_one, $side_two );
    return;
}
# ----------------------------------------------------------------------
# Top-level program, invoked from loop_core().
#
sub query_target {
    my $self = shift;

    state $files  = [glob( $self->confdata->{dir} . '/*-bond1' )];
    
    for my $file ( @$files ) {
	$self->parse_bond_status( $file );
    }
    return;
}
# ======================================================================
1;
__END__

# ======================================================================
# POD

=head1 NAME

     AN::RAID::Temperature.pm - package to handle RAID temperature values

=head1 VERSION

This document describes AN::RAID::Temperature.pm version 1.0.0

=head1 SYNOPSIS

    use AN::RAID::Temperature;
    my $agent = AN::RAID::Temperature->new( );
    $agent->run();

=head1 DESCRIPTION

This module implements the AN::RAID::Temperature class which runs an agent
to query RAID Controllers using the storcli program.

=head1 METHODS

There are no API methods exported by the system

=head1 DEPENDENCIES

=over 4

=item B<Const::Fast>

Provide fast constants.

=item B<Data::Dumper> I<core>

Display data structures in debug messages.

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

Alteeve's Niche!  -  https://alteeve.ca

Tom Legrady       -  tom@alteeve.ca	November 2014

=cut

# End of File
# ======================================================================

