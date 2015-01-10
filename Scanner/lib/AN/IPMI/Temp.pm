package AN::IPMI::Temp;

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

use Class::Tiny qw( ipmiconf ipmi prev );

# ======================================================================
# CONSTANTS
#
const my $DATATABLE_NAME => 'ipmi';
const my $PARENTDIR      => q{/../};
   
# ......................................................................
#

sub read_configuration_file {
    my $self = shift;

    $self->ipmiconf( catdir( $self->path_to_configuration_files(),
			     $self->ipmiconf ) );

    my %cfg = ( path => { config_file => $self->ipmiconf } );
    AN::Common::read_configuration_file( \%cfg );

    $self->ipmi( $cfg{ipmi} );    
}

sub BUILD {
    my $self = shift;

    return unless ref $self eq __PACKAGE__;

    $ENV{VERBOSE} ||= '';	# set default to avoid undef variable.

    $self->read_configuration_file;
    return;
}

sub eval_discrete_status {
    my $self = shift;
    my ( $tag, $value, $rec_meta, $prev_status, $prev_value, $metadata, $rawstatus ) = @_;

    say 'eval_discrete_status() invoked for unknown sensor: ', Dumper( [\@_] );
}

sub eval_rising_status {
    my $self = shift;
    my ( $tag, $value, $rec_meta, $prev_status, $prev_value, $metadata, $rawstatus ) = @_;

    my $units = $rec_meta->{units} || '';
    my $h = ( $rec_meta->{hysteresis} || 0 ) / 2;

    my ( $msg_tag, $msg_args, $status ) = ( '', '' );

    # 1) Previous status was OK, allow small overage before not OK
    #
    if (    $prev_status eq 'OK'
         && $value <= $rec_meta->{ok_max} + $h ) {
        $status = 'OK';
    }

    # 2) Previous status was not OK, require low value before OK.
    #
    elsif (    $prev_status ne 'OK'
            && $value <= $rec_meta->{ok_max} - $h ) {
        $status = 'OK';
    }

    # 3) Previous status was WARN, allow small overage before CRISIS
    #
    elsif ( ( $prev_status eq 'OK' || $prev_status eq 'WARNING' )
            && $value > $rec_meta->{warn_max} + $h ) {
        $status   = 'WARNING';
        $msg_tag  = "Value warning";
        $msg_args = "value=$value";
    }

    # 4) Previous status was CRISIS, require low value before WARN.
    #
    elsif (    $prev_status eq 'CRISIS'
            && $value <= $rec_meta->{warn_max} - $h ) {
        $status   = 'WARNING';
        $msg_tag  = "Value crisis";
        $msg_args = "value=$value";
    }

    # 5) Previous status was CRISIS, keep in CRISIS
    #
    elsif (    $prev_status eq 'CRISIS'
            && $value > $rec_meta->{crisis_min} - $h ) {
        $status   = 'CRISIS';
        $msg_tag  = "Value crisis";
        $msg_args = "value=$value";
    }
    else {
        $status   = 'DEBUG';
        $msg_tag  = "Unexpected value";
        $msg_args = "value=$value";
    }
    my $args = { table              => $self->datatable_name,
		 with_node_table_id => 'node_id',
		 args               => {
		     target   => $metadata->{name},
		     value    => $value,
		     units    => $units,
		     field    => $tag,
		     status   => $status,
		     msg_tag  => $msg_tag,
		     msg_args => $msg_args,
		 }, };

    $self->insert_raw_record( $args );

    if ( $status ne 'OK'
	|| ( $status eq 'OK'
	     && $prev_status ne 'OK' )) {
	delete $args->{args}{target};
	$args->{table} = $self->alerts_table_name;
	$args->{args}{target_name} = $metadata->{name};
	$args->{args}{target_type} = $metadata->{type};
	$args->{args}{target_extra} = $metadata->{ip};
	$self->insert_raw_record( $args );
    }

    return ($status);
}

sub eval_falling_status {
    my $self = shift;
    my ( $tag, $value, $rec_meta, $prev_status, $prev_value, $metadata, $rawstatus ) = @_;

    my $units = $rec_meta->{units} || '';
    my $h = ( $rec_meta->{hysteresis} || 0 ) / 2;

    $value =~ s{(\d+).*}{$1};    # convert '43 minutes' => '43'

    my ( $msg_tag, $msg_args, $status ) = ( '', '' );

    # 1) Previous status was OK, allow small underaage before not OK
    #
    if (    $prev_status eq 'OK'
         && $value >= $rec_meta->{ok_min} - $h ) {
        $status = 'OK';
    }

    # 2) Previous status was not OK, require high value before OK.
    #
    elsif (    $prev_status ne 'OK'
            && $value >= $rec_meta->{ok_min} + $h ) {
        $status = 'OK';
    }

    # 3) Previous status was WARN, allow small underage before CRISIS
    #
    elsif ( ( $prev_status eq 'OK' || $prev_status eq 'WARNING' )
            && $value >= $rec_meta->{warn_min} - $h ) {
        $status   = 'WARNING';
        $msg_tag  = "Value warning";
        $msg_args = "value=$value";
    }

    # 4) Previous status was CRISIS, require high value before WARN.
    #
    elsif (    $prev_status eq 'CRISIS'
            && $value >= $rec_meta->{warn_min} + $h ) {
        $status   = 'WARNING';
        $msg_tag  = "Value warning";
        $msg_args = "value=$value";
    }

    # 5) Previous status was CRISIS, keep in CRISIS
    #
    elsif (    $prev_status eq 'CRISIS'
            && $value < $rec_meta->{crisis_max} + $h ) {
        $status   = 'CRISIS';
        $msg_tag  = "Value crisis";
        $msg_args = "value=$value";
    }
    else {
        $status   = 'DEBUG';
        $msg_tag  = "Unexpected value";
        $msg_args = "value=$value";

    }
    my $args = { table              => $self->datatable_name,
		 with_node_table_id => 'node_id',
		 args               => {
		     target   => $metadata->{name},
		     value    => $value,
		     units    => $units,
		     field    => $tag,
		     status   => $status,
		     msg_tag  => $msg_tag,
		     msg_args => $msg_args,
		 }, };

    $self->insert_raw_record( $args );

    if ( $status ne 'OK'
	|| ( $status eq 'OK'
	     && $prev_status ne 'OK' )) {
	$args->{table} = $self->alerts_table_name;
	delete $args->{args}{target};
	$args->{args}{target_name} = $metadata->{name};
	$args->{args}{target_type} = $metadata->{type};
	$args->{args}{target_extra} = $metadata->{ip};
	$self->insert_raw_record( $args );
    }
    return ( $status, $value );
}

sub eval_nested_status {
    my $self = shift;
    my ( $tag, $value, $rec_meta, $prev_status, $prev_value, $metadata, $rawstatus ) = @_;

    my $units = $rec_meta->{units} || '';
    my $h = ( $rec_meta->{hysteresis} || 0 ) / 2;

    my ( $msg_tag, $msg_args, $status ) = ( '', '' );

    # 1) Previous status was OK, allow small overage before not OK
    #
    if (    $prev_status eq 'OK'
         && $value >= $rec_meta->{ok_min} - $h
         && $value <= $rec_meta->{ok_max} + $h ) {
        $status = 'OK';
    }

    # 2) Previous status was not OK, require low value before OK.
    #
    elsif (    $prev_status ne 'OK'
            && $value >= $rec_meta->{ok_min} + $h
            && $value <= $rec_meta->{ok_max} - $h ) {
        $status = 'OK';
    }

    # 3) Previous status was WARN, allow small overage before CRISIS
    #
    elsif (    ( $prev_status eq 'OK' || $prev_status eq 'WARNING' )
            && $value >= $rec_meta->{warn_min} - $h
            && $value <= $rec_meta->{warn_max} + $h ) {
        $status   = 'WARNING';
        $msg_tag  = "Value warning";
        $msg_args = "value=$value";
    }

    # 4) Previous status was CRISIS, require low value before WARN.
    #
    elsif (    $prev_status eq 'CRISIS'
            && $value >= $rec_meta->{warn_min} - $h
            && $value <= $rec_meta->{warn_max} + $h ) {
        $status   = 'WARNING';
        $msg_tag  = "Value warning";
        $msg_args = "value=$value";
    }

    # 5) Previous status was CRISIS, keep in CRISIS
    #
    elsif (    $prev_status eq 'CRISIS'
            && $value > $rec_meta->{warn_min} - $h
            && $value < $rec_meta->{warn_min} + $h ) {
        $status   = 'CRISIS';
        $msg_tag  = "Value crisis";
        $msg_args = "value=$value";
    }
    else {
        $status   = 'DEBUG';
        $msg_tag  = "Unexpected value";
        $msg_args = "value=$value";
    }
    my $args = { table              => $self->datatable_name,
		 with_node_table_id => 'node_id',
		 args               => {
		     target   => $metadata->{name},
		     value    => $value,
		     units    => $units,
		     field    => $tag,
		     status   => $status,
		     msg_tag  => $msg_tag,
		     msg_args => $msg_args,
		 }, };

    $self->insert_raw_record( $args );

    if ( $status ne 'OK'
	|| ( $status eq 'OK'
	     && $prev_status ne 'OK' )) {
	$args->{table} = $self->alerts_table_name;
	delete $args->{args}{target};
	$args->{args}{target_name} = $metadata->{name};
	$args->{args}{target_type} = $metadata->{type};
	$args->{args}{target_extra} = $metadata->{ip};
	$self->insert_raw_record( $args );
    }
    return ($status);
}

sub eval_status {
#    my ( $self, $tag, $value, $rec_meta, 
#         $prev_status, $prev_value, $metadata, $rawstatus ) = @_;

    my ( $rec_meta ) = $_[3];
	
    return &eval_discrete_status
        unless ( exists $rec_meta->{ok_min} );    # not range data.

    return &eval_rising_status
        if (    $rec_meta->{warn_min} == $rec_meta->{ok_max}
             && $rec_meta->{warn_max} > $rec_meta->{ok_max} );

    return &eval_falling_status
        if (    $rec_meta->{warn_max} == $rec_meta->{ok_min}
             && $rec_meta->{warn_min} < $rec_meta->{ok_min} );

    return &eval_nested_status
        if (    $rec_meta->{warn_max} >= $rec_meta->{ok_max}
             && $rec_meta->{warn_min} <= $rec_meta->{ok_min} );
    return;
}

sub init_prev {
    my $self = shift;
    my ( $received ) = @_;

    my $prev = {};

  RECORD:
    for my $record ( @$received ) {
	my ( $tag, $value, $status ) = @{$record}[0,4,2];

	# Multiple records for 'Ambient', only care about first.
	#
	next RECORD if defined $prev->{$tag};

	# Extract numeric part if any.  Ambient temperature will be
	# greater than 20 C and other temps greater than ambient.
	#
	$value =~ s{([\d.]+).*}{$1};
	next RECORD unless $value > 20;

	@{$prev->{$tag}}{qw(value status)} = ($value, uc $status);
    }
    return $prev;
}

sub process_all_ipmi {
    my $self = shift;
    my ( $received ) = @_;

    state $i       = 1;
    state $verbose = ( ($self->verbose && $self->verbose >= 2)
		       || grep {/process_all_ipmi/} $ENV{VERBOSE}
	             );

    my ( $info, $prev ) = ( $self->ipmi, $self->prev );

    state $meta = { name => $info->{host},
		    ip   => $info->{ip},
		    type   => $info->{type},
    };

    $prev ||= $self->init_prev( $received );
    for my $record ( @$received ) {
	my ( $tag, $value, $rawstatus ) = @{$record}[0,4,2];
	my $rec_meta = $info->{$tag};

	$value =~ s{([\d.]+)\s*.*}{$1}; # Discard text following a number

        my $prev_value = $prev->{$tag}{value};
        my $prev_status = $prev->{$tag}{status} ;

        # Calculate status and message.
        #
        say Data::Dumper->Dump([ $i++, $tag, $value, $rec_meta,
				 $prev_status, $prev_value, uc $rawstatus ] )
	    if grep {/process_all_ipmi/ } ($ENV{VERBOSE} || 0);

	my ( $status, $newvalue ) = $self->eval_status( $tag, $value, $rec_meta,
							$prev_status, $prev_value,
							$meta, $rawstatus );

        $prev->{$tag}{$tag}{value} = $newvalue || $value;
        $prev->{$tag}{$tag}{status} = $status;
    }
}
sub ipmi_request {
    my $self = shift;

 
    state $cmd = $Bin . $PARENTDIR . $self->ipmi()->{query};
    say "ipmi cmd is $cmd" if grep {/ipmi_query/} $ENV{VERBOSE};

    # read bottom to top ...
    #
    my @data = (map { [ split '\s*\|\s*' ] }    # split line into space-trimmed fields
		grep { $_ !~ /Device Present/ }     # Ignore text 'Ambient' messages.

		grep { $_ !~ /Limit Not Exceeded/ }
		grep {  -1 == index $_, '| ns'} # ignore lines w/ 'ns' for no sensor 
		split "\n",			# split paragraph into lines
		`$cmd`                          # invoke ipmit tool for sdr temperatures
		);

    # less than 5 lines is an error message rather than real data
    #
    if ( not @data 
	 || 5 >= @data ) {

	my $info = $self->ipmi;
	my $args = { table              => $self->datatable_name,
		     with_node_table_id => 'node_id',
		     args               => {
			 target_name => $info->{host},
			 target_type => $info->{type},
			 target_extra => $info->{ip},
			 value    => $info->{host},
			 units    => '',
			 field    => 'IPMI fetch data',
			 status   => 'CRISIS',
			 msg_tag  => __PACKAGE__ . '::ipmi_request() failed',
			 msg_args => "errormsg=" . join "\n", @data,
		     }, };
	    
	$self->insert_raw_record( $args );
	    
	$args->{table} = $self->alerts_table_name;
	$self->insert_raw_record( $args );
    }
	
    return \@data;
}

sub query_target {
    my $self = shift;

    my $received = $self->ipmi_request();
    $self->process_all_ipmi( $received ) if @$received;

    return;
}

1;

# ======================================================================
# End of File.
