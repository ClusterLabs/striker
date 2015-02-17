package AN::RAID::Temperature;

use parent 'AN::SNMP::APC_UPS';    # inherit from AN::SNMP_APC_UPS

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
use English '-no_match_vars';
our $VERSION = '1.0.0';

use Data::Dumper;
use Const::Fast;

# ======================================================================
# CLASS ATTRIBUTES & CONSTRUCTOR

use Class::Tiny qw( prev controller_count );

sub BUILD {
    my $self = shift;

    return unless ref $self eq __PACKAGE__;
    $self->confdata()->{controller_count} = $self->get_controller_count();

    return;
}

# ======================================================================
# CONSTANTS
#

const my $SLASH => q{/};
const my $SPACE => q{ };

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
#  Determine how many raid controllers are installed on the system.
#
sub get_controller_count {
    my $self = shift;

    my $response = $self->raid_request;
    return unless scalar @$response;

    # Get the line with Number of Controllers = N;
    # Extract the part following  ' = ' and store as count;
    #
    my ($line) = ( grep {/Number of Controllers/} @$response );
    return 0 unless $line;

    my $count = ( split ' = ', $line )[1];
    chomp $count;

    return 0 unless $count;
    return $count;
}
# ----------------------------------------------------------------------
# Parse raid response lines to determine which drive & which
# controller is being reported.
#
sub parse_dev {
    my $self = shift;
    my ($dev) = @_;

    my ( $controller, $drive );
    $controller = $1
        if $dev =~ m{controller=(\d)};

    $drive = $1
        if $dev =~ m{drive=(\d)};

    return ( $controller, $drive );
}
# ----------------------------------------------------------------------
# Initialize the set of 'previous' values.
#
sub init_prev {
    my $self = shift;
    my ($received) = @_;

    my $prev = {};

RECORD:
    for my $record (@$received) {
        my ( $tag, $value ) = @{$record}{qw(field value )};

        my ( $controller, $drive ) = $self->parse_dev( $record->{dev} );

        # Ambient temperature will be greater than 20 C and other
        # temps can only be greater than ambient.
        #
        next RECORD unless $value > 20;

        if ( $tag eq 'ROC temperature' ) {
            $prev->{$tag}[$controller] = { value => $value, status => 'OK' };
        }
        elsif ( $tag = 'Drive Temperature' ) {
            $prev->{$tag}[$controller][$drive]
                = { value => $value, status => 'OK' };
        }
        else {
            warn(
                "Unexpected tag '$tag' in " . __PACKAGE__ . "::init_prev()\n" );
        }
    }
    $prev->{summary}{status} = 'OK';
    $prev->{summary}{value}  = 0;

    return $prev;
}
# ----------------------------------------------------------------------
# Process the records retrieved from the RAID system. Prepare the
# records for analysis and then pass them on to
# AN::SNMP::APC_UPS::eval_status().
#
sub process_all_raid {
    my $self = shift;
    my ($received) = @_;

    state $i = 1;
    state $verbose = ( ( $self->verbose && $self->verbose >= 2 )
                       || grep {/process_all_raid/} $ENV{VERBOSE} );

    my ( $info, $prev ) = ( $self->confdata, $self->prev );
    $prev ||= $self->init_prev($received);

    state $meta = { name => $info->{host},
                    ip   => $info->{ip},
                    type => $info->{type}, };

    for my $record (@$received) {
        my ( $tag, $value ) = @{$record}{qw( field value )};
        my $rec_meta = $info->{$tag};

        my ( $controller, $drive ) = $self->parse_dev( $record->{dev} );
        my ( $prev_value, $prev_status )
            = defined $drive
            ? @{ $prev->{$tag}[$controller][$drive] }{qw(value status)}
            : @{ $prev->{$tag}[$controller] }{qw(value status)};

        # Calculate status and message.
        #
        say Data::Dumper->Dump(
                  [ $i++, $tag, $value, $rec_meta, $prev_status, $prev_value ] )
            if $verbose;

        my $args = { tag         => $tag,
                     value       => $value,
                     rec_meta    => $rec_meta,
                     prev_status => $prev_status,
                     prev_value  => $prev_value,
                     metadata    => $meta,
                     dev         => $record->{dev}, };

        my ( $status, $newvalue ) = $self->eval_status($args);

        if ( defined $drive ) {
            @{ $prev->{$tag}[$controller][$drive] }{qw(value status)}
                = ( $newvalue || $value, $status );
        }
        else {
            @{ $prev->{$tag}[$controller] }{qw(value status)}
                = ( $newvalue || $value, $status );

        }
    }
    $self->prev($prev);
    return;
}
# ----------------------------------------------------------------------
# Fetch data from RAID system and pass it on for processing.
#
sub raid_request {
    my $self = shift;

    my (@args) = @_;

    my $cmd = $self->bindir . $SLASH . $self->confdata()->{query};
    local $LIST_SEPARATOR = $SPACE;
    $cmd .= " @args" if @args;
    say "raid cmd is $cmd" if grep {/raid_query/} $ENV{VERBOSE};

    my @data = `$cmd`;

    # less than 10 lines is an error message rather than real data
    #
    if ( not @data
         || 10 >= @data ) {

        my $info = $self->confdata;
        my $args = { table              => $info->{db}{table}{other},
                     with_node_table_id => 'node_id',
                     args               => {
                            target_name  => $info->{host},
                            target_type  => $info->{type},
                            target_extra => $info->{ip},
                            value        => $info->{host},
                            units        => '',
                            field        => 'RAID fetch data',
                            status       => 'CRISIS',
                            message_tag => 'AN-RAID-Temp raid_request() failed',
                            message_arguments => "errormsg=" . join "\n",
                            @data,
                     }, };

        $self->insert_raw_record($args);

        $args->{table} = $info->{db}{table}{alerts};
        $self->insert_raw_record($args);
    }

    return \@data;
}
# ----------------------------------------------------------------------
# Does the controller have a temperature sensor? How many drives does
# the controller handle?
#
sub extract_controller_metadata {
    my $self = shift;

    my ( $response, $N ) = @_;

    my ($roc_sensor) = grep {/Temperature Sensor for ROC = /} @$response;
    my $value = ( split ' = ', $roc_sensor )[1];
    chomp $value;
    $self->confdata()->{controller}{$N}{sensor} = $value;

    my ($drive_counts) = grep {/Physical Drives = (\d+)/} @$response;
    $value = ( split ' = ', $drive_counts )[1];
    chomp $value;
    $self->confdata()->{controller}{$N}{drives} = $value;
}
# ----------------------------------------------------------------------
# Fetch temperature for each controller card.
#
sub get_controller_temp {
    my $self = shift;

    state $maxN = $self->confdata()->{controller_count} - 1;

    my $received;
    for my $N ( 0 .. $maxN ) {
        my $response = $self->raid_request( 'controller', $N );

        $self->extract_controller_metadata( $response, $N )
            unless exists $self->confdata()->{controller}{$N};

        my ($roc_temp) = grep {/ROC temperature\(Degree /} @$response;
        my $delimiters = qr{
                             \s=\s # equal sign embedded in spaces
                              |	   # OR
                              [()] # opening or closing partheses
                           }xms;
        my @temp = grep {/\S/} split /$delimiters/, $roc_temp;
        chomp @temp;
        push @$received,
            { field => $temp[0],
              units => $temp[1],
              value => $temp[2],
              dev   => "controller=$N" };
    }
    return $received;
}
# ----------------------------------------------------------------------
# Extract the drive names from the RAID query response.
#
sub extract_drive_metadata {
    my $self = shift;

    my ( $response, $N ) = @_;

    my @names = grep {/Drive.*State :/} @$response;

    for my $drive (@names) {
        my $dev = ( split /\s/, $drive )[1];
        push @{ $self->confdata()->{controller}{$N}{drive} }, { name => $dev };
    }
    return;
}
# ----------------------------------------------------------------------
# For each controller, fetch RAID data for each drive.
#
sub get_drive_temp {
    my $self = shift;

    state $maxN = $self->confdata()->{controller_count} - 1;

    my $received;
    for my $N ( 0 .. $maxN ) {
        my $response = $self->raid_request( 'drives', $N );
        $self->extract_drive_metadata( $response, $N )
            unless exists $self->confdata()->{controller}{$N}{drive};

        my (@drive_temps) = grep {/Drive Temperature = /} @$response;
        my $delimiters = qr{
                             \s=\s # equal sign embedded in spaces
                              |	   # OR
                              [()] # opening or closing partheses
                           }xms;
        my $idx = 0;
        for my $drive (@drive_temps) {
            my @temp = grep {/\S/} split /$delimiters/, $drive;
            $temp[1] =~ m{(\d+)(\w)};

            push @$received,
                { field => $temp[0],
                  units => $2,
                  value => $1,
                  dev   => "controller=$N;drive=$idx" };
            $idx++;
        }
    }
    return $received;
}
# ----------------------------------------------------------------------
# Top-level program, invoked from loop_core().
#
sub query_target {
    my $self = shift;

    $self->clear_summary();

    # make sure $controllers & $drives can be de-referenced as arrays.
    #
    my $controllers = $self->get_controller_temp();
    $controllers ||= [];
    my $drives = $self->get_drive_temp();
    $drives ||= [];

    $self->process_all_raid( [ @$controllers, @$drives ] );
    $self->process_summary();

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

