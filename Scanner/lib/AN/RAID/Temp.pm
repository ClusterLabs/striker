package AN::RAID::Temp;

use base 'AN::SNMP::APC_UPS';    # inherit from AN::SNMP_APC_UPS

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;
use Cwd;
use Data::Dumper;
use File::Basename;

use File::Spec::Functions 'catdir';
use FindBin qw($Bin);
use Const::Fast;
use Time::HiRes qw(time alarm sleep);

use AN::Common;
use AN::MonitorAgent;
use AN::FlagFile;
use AN::Unix;
use AN::DBS;

use Class::Tiny qw( confpath confdata prev controller_count );

# ======================================================================
# CONSTANTS
#
const my $DATATABLE_NAME => 'raid';
const my $PARENTDIR      => q{/../};

const my $SLASH => q{/};
const my $SPACE => q{ };

# ......................................................................
#

sub get_controller_count {
    my $self = shift;

    my $response = $self->raid_request;
    return unless scalar @$response;

    # Get the line with Number of Controllers = N;
    # Extract the part following  ' = ' and store as count;
    #
    my ($line) = (grep {/Number of Controllers/} @$response);
    return 0 unless $line;

    my $count = (split ' = ', $line )[1];
    chomp $count;

    return 0 unless $count;
    return $count;
}

sub BUILD {
    my $self = shift;

    return unless ref $self eq __PACKAGE__;
    $self->confdata()->{controller_count} = $self->get_controller_count();

    return;
}


sub parse_dev {
    my $self = shift;
    my ( $dev ) = @_;

    my ( $controller, $drive );
    $controller = $1
	if $dev =~ m{controller=(\d)};

    $drive     = $1
	if $dev =~ m{drive=(\d)};

    return( $controller, $drive );
}

sub init_prev {
    my $self = shift;
    my ($received) = @_;

    my $prev = {};

RECORD:
    for my $record (@$received) {
        my ( $tag, $value ) = @{$record}{qw(field value )};

	my ( $controller, $drive ) = $self->parse_dev( $record->{dev});
	
        # Ambient temperature will be greater than 20 C and other
        # temps greater than ambient.
        #
        next RECORD unless $value > 20;

	if ( $tag eq 'ROC temperature' ) {
	    $prev->{$tag}[$controller] = {value => $value, status => 'OK' };
	} elsif ( $tag = 'Drive Temperature' ) {
	    $prev->{$tag}[$controller][$drive]
	        = {value => $value, status => 'OK' };
	} else {
	    warn( "Unexpected tag '$tag' in " . __PACKAGE__ . "::init_prev()\n");
	}
    }
    $prev->{summary}{status} = 'OK';
    $prev->{summary}{value} = 0;
    
    return $prev;
}

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

	my ( $controller, $drive ) = $self->parse_dev( $record->{dev});
	my ($prev_value, $prev_status)
	    = defined $drive 
	    ? @{$prev->{$tag}[$controller][$drive]}{qw(value status)}
	    : @{$prev->{$tag}[$controller]}{qw(value status)} ;

        # Calculate status and message.
        #
        say Data::Dumper->Dump(
                                [ $i++, $tag, $value, $rec_meta,
                                  $prev_status, $prev_value
                                ] )
            if $verbose;

        my $args = { tag         => $tag,
                     value       => $value,
                     rec_meta    => $rec_meta,
                     prev_status => $prev_status,
                     prev_value  => $prev_value,
                     metadata    => $meta,
		     dev         => $record->{dev},
	};

        my ( $status, $newvalue ) = $self->eval_status($args);

	if ( defined $drive ) {
	    @{$prev->{$tag}[$controller][$drive]}{qw(value status)}
                = ($newvalue || $value, $status);
	}
	else {
	    @{$prev->{$tag}[$controller]}{qw(value status)} 
                = ($newvalue || $value, $status);
	    
	}
    }
    $self->prev( $prev );
    return;
}

sub raid_request {
    my $self = shift;

    my (@args) = @_;

    my $cmd = getcwd() . $SLASH . $self->confdata()->{query};
    local $LIST_SEPARATOR = $SPACE;
    $cmd .= " @args" if @args;
    say "raid cmd is $cmd" if grep {/raid_query/} $ENV{VERBOSE};

    my @data = `$cmd`;

    # less than 10 lines is an error message rather than real data
    #
    if ( not @data
         || 10 >= @data ) {

        my $info = $self->confdata;
        my $args = { table              => $self->datatable_name,
                     with_node_table_id => 'node_id',
                     args               => {
                             target_name  => $info->{host},
                             target_type  => $info->{type},
                             target_extra => $info->{ip},
                             value        => $info->{host},
                             units        => '',
                             field        => 'RAID fetch data',
                             status       => 'CRISIS',
                             msg_tag      =>  'AN-RAID-Temp raid_request() failed',
                             msg_args => "errormsg=" . join "\n",
                             @data,
                     }, };

        $self->insert_raw_record($args);

        $args->{table} = $self->alerts_table_name;
        $self->insert_raw_record($args);
    }

    return \@data;
}

sub extract_controller_metadata {
    my $self = shift;

    my ( $response, $N ) = @_;

    my ($roc_sensor)   = grep {/Temperature Sensor for ROC = /}
        @$response;
    my $value = (split ' = ', $roc_sensor)[1];
    chomp $value;
    $self->confdata()->{controller}{$N}{sensor} = $value;


    my ($drive_counts) = grep {/Physical Drives = (\d+)/}
    @$response;
    $value = (split ' = ', $drive_counts)[1];
    chomp $value;
    $self->confdata()->{controller}{$N}{drives} = $value;
}

sub get_controller_temp {
    my $self = shift;

    state $maxN = $self->confdata()->{controller_count} - 1;

    my $received;
    for my $N ( 0 .. $maxN ) {
	my $response = $self->raid_request( 'controller', $N);

	$self->extract_controller_metadata( $response, $N )
	    unless  exists $self->confdata()->{controller}{$N};
	    
	my ($roc_temp)     = grep {/ROC temperature\(Degree /}  @$response;
	my $delimiters = qr{
                             \s=\s # equal sign embedded in spaces
                              |	   # OR
                              [()] # opening or closing partheses
                           }xms;
	my @temp = grep {/\S/} split /$delimiters/, $roc_temp;
	chomp @temp;
	push @$received, { field => $temp[0],
			   units => $temp[1],
			   value => $temp[2],
			   dev => "controller=$N"
	};
    }
    return $received;
}

sub extract_drive_metadata {
    my $self = shift;

    my ( $response, $N ) = @_;

    my @names = grep {/Drive.*State :/} @$response;

    for my $drive ( @names ) {
	my $dev = (split /\s/, $drive)[1];
	push @{$self->confdata()->{controller}{$N}{drive}}, {name => $dev};
    }
    return;
}
sub get_drive_temp {
    my $self = shift;

    state $maxN = $self->confdata()->{controller_count} - 1;

    my $received;
    for my $N ( 0 .. $maxN ) {
	my $response = $self->raid_request( 'drives', $N);
	$self->extract_drive_metadata( $response, $N )
	    unless  exists $self->confdata()->{controller}{$N}{drive};
	    
	my (@drive_temps)     = grep {/Drive Temperature = /}  @$response;
	my $delimiters = qr{
                             \s=\s # equal sign embedded in spaces
                              |	   # OR
                              [()] # opening or closing partheses
                           }xms;
	my $idx = 0;
	for my $drive ( @drive_temps ) {
	    my @temp = grep {/\S/} split /$delimiters/, $drive;
	    $temp[1] =~ m{(\d+)(\w)};
	    
	    push @$received, { field => $temp[0],
			       units => $2,
			       value => $1,
	                       dev => "controller=$N;drive=$idx"};
	    $idx++
	}
    }
    return $received;
}

sub query_target {
    my $self = shift;

    $self->clear_summary();

    # make sure $controllers & $drives can be de-referenced as arrays.
    #
    my $controllers = $self->get_controller_temp();
    $controllers ||= [];
    my $drives      = $self->get_drive_temp();
    $drives      ||= [];

    $self->process_all_raid( [ @$controllers, @$drives ] );
    $self->process_summary();

    return;
}

1;

# ======================================================================
# End of File.
