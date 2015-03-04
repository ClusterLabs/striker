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

use Class::Tiny qw( ),
    { prev    => sub { {} },
      hw_addr => sub { {} }, };

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
                   hw_address    => 'permament hw address' };

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Compare variables with specific values, to determine which slave
# link is the primary, what speed the links are providing, and whether
# they are full- or half-duplex.
#
sub eval_discrete_status {
    my $self = shift;
    my ($args) = @_;

    my $msg
        = { args => '', tag => '', label => '', newval => '', status => '' };

    if ( $args->{tag} eq $TAG->{current_slave} ) {
        $msg->{status} = 'OK';
    }
    elsif (    $args->{tag} eq $TAG->{combined_mii}
            || $args->{tag} eq $TAG->{single_mii} ) {
        $msg->{status} = $args->{value} eq 'up' ? 'OK' : 'WARN';
    }
    elsif (    $args->{tag} eq $TAG->{speed}
            || $args->{tag} eq $TAG->{duplex}
            || $args->{tag} eq $TAG->{hw_address} ) {
        if ( $args->{value} eq 'sides differ' ) {
            $msg->{status} = 'WARNING';
            $msg->{args}   = $args->{rec_meta}{values};
        }
        else {
            $msg->{status} = 'OK';
        }
    }

    $msg->{label} = $args->{metadata}{file};
    $msg->{tag}   = $args->{tag};
    $args->{prev_status} ||= $msg->{status};
    $msg->{args} = "link=$args->{metadata}{ident}"
        if exists $args->{metadata}{ident};

    $self->compare_sides_or_report_record( $args, $msg );

    return ( $msg->{status}, $msg->{newval} || $args->{value} );
}

# ----------------------------------------------------------------------
# The first line of the bonding file output just identifies the driver,
# nothing interesting. Ignore this line.
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
# The identifier line of the bonding file output is followed by
# information about the combined link. Extract the currently active
# slave and the MII status.
#
# Bonding Mode: fault-tolerance (active-backup)
# Primary Slave: sn-link1 (primary_reselect always)
# Currently Active Slave: sn-link1
# MII Status: up
# MII Polling Interval (ms): 100
# Up Delay (ms): 120000
# Down Delay (ms): 0
#    
sub process_combined_section {
    my $self = shift;
    my ( $name, $fh ) = @_;

    my $args = { rec_meta    => {},
                 prev_status => '',
                 prev_value  => '',
                 metadata    => {
                               name => $self->confdata()->{host},
                               file => $name,
                               ip   => $self->confdata->{ip},
                               type => $self->confdata->{type},
                             } };

COMBINED:
    while ( my $line = <$fh> ) {
        last COMBINED if $line !~ m{\w};
        if ( $line =~ m{Currently Active Slave: (\S+)} ) {
            $args->{value} = $1;
            $args->{tag}   = $TAG->{current_slave};
        }
        elsif ( $line =~ m{MII Status: (\S+)} ) {
            $args->{value} = $1;
            $args->{tag}   = $TAG->{combined_mii};

        }
        if ( exists $args->{value} ) {    # If line has data to report ....
            my ( $status, $newvalue ) = $self->eval_status($args);
            $self->prev->{$name}{ $TAG->{current_slave} }{value}  = $newvalue;
            $self->prev->{$name}{ $TAG->{current_slave} }{status} = $status;
        }
    }
    return;
}

# ----------------------------------------------------------------------
# The combined section of the bonding file output is followed by
# detailed information for each of xxx-link1 & xxx-link2. Extract the
# interface label as the name, then get the MII status, speed and
# duplex-ity. Finally, once an hour (actually twice, in the same
# minute), get the Permament HW addr .... Since it's permament, it
# never changes, but for convenience it's good to have a recent
# extraction of the value. On the other hand, extracting it twice a
# minute would be excessive.
#
# Besides saving the raw data, also save up and return the key data
# for one side.
#
# Slave Interface: sn-link1
# MII Status: up
# Speed: 10000 Mbps
# Duplex: full
# Link Failure Count: 7
# Permanent HW addr: 90:1b:0e:0d:04:4d
# Slave queue ID: 0
    
sub process_section {
    my $self = shift;
    my ( $name, $fh ) = @_;

    my $args = { rec_meta    => {},
                 prev_status => '',
                 prev_value  => '',
                 metadata    => {
                               name => $self->confdata()->{host},
                               file => $name,
                               ip   => $self->confdata->{ip},
                               type => $self->confdata->{type},
                             } };

    my $side_info = {};
    my $ident;
SECTION:
    while ( my $line = <$fh> ) {
        last SECTION if $line !~ m{\w};
        if ( $line =~ m{Slave Interface: (\S+)} ) {
            $args->{metadata}->{ident} = $1;
            $side_info->{ident} = $1;
        }
        elsif ( $line =~ m{MII Status: (\S+)} ) {
            $args->{value} = $1;
            $args->{tag}   = $TAG->{single_mii};
        }
        elsif ( $line =~ m{Speed: (\S+)\s(\S+)} ) {
            $args->{value}           = $1;
            $side_info->{speed}      = $1;
            $args->{rec_meta}{units} = $2;
            $args->{tag}             = $TAG->{speed};
        }
        elsif ( $line =~ m{Duplex: (\S+)} ) {
            $args->{value}      = $1;
            $side_info->{speed} = $1;
            $args->{tag}        = $TAG->{duplex};
        }
        elsif ( $line =~ m{Permanent HW addr: (\S+)} ) {
            my $tmp = $1;
            my ( $sec, $min ) = localtime;
            if ( $min == 4 ) {    # report hw addr at start of hour
                $args->{value} = $tmp;
                $args->{tag}   = $TAG->{hw_address};
            }
        }
        if ( exists $args->{value} ) {    # If line has data to report ....
            $side_info->{ $args->{tag} } = $args->{value};
                unless $args->{tag} eq $TAG->{hw_address};
            my ( $status, $newvalue ) = $self->eval_status($args);
            $self->prev->{$name}{ $args->{tag} }{value}  = $newvalue;
            $self->prev->{$name}{ $args->{tag} }{status} = $status;
            delete $args->{value};
        }
    }
    return $side_info;
}

# ----------------------------------------------------------------------
# Compare the MII status, speed and duplex-ity of the two core links.
#
sub compare_sides {
    my $self = shift;
    my ( $name, $side_one, $side_two ) = @_;

    my $args = { rec_meta    => {},
                 prev_status => '',
                 prev_value  => '',
                 metadata    => {
                               name => $self->confdata()->{host},
                               file => $name,
                               ip   => $self->confdata->{ip},
                               type => $self->confdata->{type},
                             } };

    my @names = ( $side_one->{ident}, $side_two->{ident} );
KEY:
    for my $key ( keys %$side_one ) {
        next KEY if $key eq 'ident';

        if ( $side_one->{$key} ne $side_two->{$key} ) {
            $args->{tag}   = $key;
            $args->{value} = 'sides differ';
            $args->{rec_meta}{values}
                = "$names[0]=$side_one->{$key};$names[1]=$side_two->{$key}";
            my ( $status, $newvalue ) = $self->eval_status($args);
        }
    }
    return;
}

# ----------------------------------------------------------------------
# Parse the data returned from a single bond file.
#
# Open the file, skip the header, parse the combined section, parse
# and save the two individual link sections. Compare the extracted
# data.
#
sub parse_bond_status {
    my $self = shift;
    my ($file) = @_;

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
# Compare the return values of all bonding files in the /proc/net/bonding/
# directory ( specified in config file ).
#
sub query_target {
    my $self = shift;

    state $files = [ glob( $self->confdata->{dir} . '/*-bond1' ) ];

    for my $file (@$files) {
        $self->parse_bond_status($file);
    }
    return;
}

# ======================================================================
1;
__END__

# ======================================================================
# POD

=head1 NAME

     AN::Bonding.pm - package to handle Ethernet Channel Bonding.

=head1 VERSION

This document describes AN::RAID::Temperature.pm version 1.0.0

=head1 SYNOPSIS

    use AN::Bonding
    my $agent = AN::Bonding->new( );
    $agent->run();

=head1 DESCRIPTION

This module implements the AN::Bonding class which runs an agent to
query the Ethernet Channel Bonding driver for each of the three
networks: internet-facing, back-channel, and storage.

=head1 METHODS

There are no API methods exported by the system

=head1 DEPENDENCIES

=over 4

=item B<Const::Fast>

Provide fast constants.

=item B<Data::Dumper> I<core>

Display data structures in debug messages.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

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

Tom Legrady       -  tom@alteeve.ca	February 2015
=cut

# End of File
# ======================================================================

