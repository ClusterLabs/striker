package AN::SNMP::APC_UPS;

use base 'AN::Agent';		# inherit from AN::Agent

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
use Net::SNMP ':snmp';

use AN::Common;
use AN::MonitorAgent;
use AN::FlagFile;
use AN::Unix;
use AN::DBS;

use Class::Tiny qw( snmp snmpini prev );

# ======================================================================
# CONSTANTS
#
const my $DUMP_PREFIX => q{db::};
const my $NEWLINE => qq{\n};

const my $PROG    => ( fileparse($PROGRAM_NAME) )[0];
const my $DATATABLE_NAME   => 'agent_data';
const my $DATATABLE_SCHEMA => <<"EOSCHEMA";

id        serial primary key,
node_id   bigint references node(node_id),
value     integer,
status    status,
msg_tag   text,
msg_args  text,
timestamp timestamp with time zone    not null    default now()

EOSCHEMA

const my $NOT_WORDCHAR => qr{\W};
const my $UNDERSCORE   => q{_};

# ......................................................................
#

sub BUILD {
    my $self = shift;

    $self->snmpini( catdir( getcwd(), $self->snmpini ));

    my %cfg = ( path => { config_file => $self->snmpini });
    AN::Common::read_configuration_file( \%cfg );

    $self->snmp( $cfg{snmp} );

    # Reverse cache, look up mib label by oid number
    # Override with specified labels, when provided.
    # Accumulate list of oids for use in get_bulk_request.
    # Allocate blank entries for storage of previous values.
    #
    my %prev;
    for my $target ( keys %{ $self->snmp()} ) {
	my $dataset = $self->snmp()->{$target};
	my @oids;
	for my $mib ( keys %{ $dataset->{oid} } ) {
	    my $oid = $dataset->{oid}{$mib};
	    push @oids, $oid;
	    $dataset->{roid}{$oid} = $mib;
	    $prev{$target}{$mib} = undef;
	}
	$dataset->{oids} = \@oids;
    }
    $self->prev( \%prev );
    return;
}

sub eval_discrete_status {
    my ( $tag,  $value, $rec_meta, $prev_status, $prev_value ) = @_;

    my ( $msg_args, $status, $newvalue ) = ( '' );
    if ( $tag eq 'battery replace' ) {
	$newvalue = $rec_meta->{values}{$value};
	if ( $newvalue eq 'unneeded' ) {
	    $status = 'OK';
	}
	elsif ( $newvalue eq 'needed' ) {
	    $status = 'DEBUG';
	    $msg_args = 'Battery requires replacement';
	}
	else {
	    $status = 'DEBUG';
	    $msg_args = "Unrecognized 'battery replace' value '$value'";
	}
    }
    elsif ( $tag eq 'comms' ) {
	$newvalue = $rec_meta->{values}{$value};
	if ( $newvalue eq 'yes' ) {
	    $status = 'OK';
	}
	elsif ( $newvalue eq 'no' ) {
	    $status = 'DEBUG';
	    $msg_args = 'Battery requires replacement';
	}
	else {
	    $status = 'DEBUG';
	    $msg_args = "Unrecognized 'battery replace' value '$value'";
	}	
    }
    elsif ( $tag eq 'reason for last transfer' ) {
	$newvalue = $rec_meta->{values}{$value};
	if ( $prev_value
	     && $prev_value ne $newvalue ) {
	    $status = 'DEBUG';
	    $msg_args = sprintf "reason for last transfer changed from '%s' => '%s'",
                            $prev_value, $newvalue;
	}
	else {
	    $status = 'OK';
	}
    }	
    elsif ( $tag eq 'last self test date' ) {
	if ( $prev_value
	     && $prev_value ne $value ) {
	    $status = 'DEBUG';
	    $msg_args = sprintf "last self test date changed from  '%s' => '%s'",
	    $rec_meta->{values}{$prev_value},
	    $rec_meta->{values}{$value};
	}
	else {
	    $status = 'OK'
	}	
    }
    elsif ( $tag eq 'last self test result' ) {
	if ( $value == 1 || $value == 4 ) {
	    $status = 'OK';
	}
	else {
	    $status = 'DEBUG';
	    $msg_args = 'Last self-test result was not OK: ' . 
                ([ undef, '', 'failed', 'invalid test' ])[$value];
	}	
    }
   
    return ( $status, $msg_args, $newvalue);
}
sub eval_rising_status {
    my ( $tag,  $value, $rec_meta, $prev_status, $prev_value ) = @_;

    my $h = ($rec_meta->{hysteresis} || 0) /2;
    
    my ( $msg_args, $status ) = ( '' );

    # 1) Previous status was OK, allow small overage before not OK
    #
    if ( $prev_status eq 'OK'
	 && $value <= $rec_meta->{ok_max} + $h ) {
	$status = 'OK';
    }
    # 2) Previous status was not OK, require low value before OK.
    #    
    elsif ( $prev_status ne 'OK'
	 && $value <= $rec_meta->{ok_max} - $h) {
	$status = 'OK';
    }
    # 3) Previous status was WARN, allow small overage before CRISIS
    #
    elsif ( ($prev_status eq 'OK' || $prev_status eq 'WARNING') 
	    && $value > $rec_meta->{warn_max} + $h ) {
	$status = 'WARNING';
	$msg_args = "'$tag' value '$value' in Warning range";
	
    }
    # 4) Previous status was CRISIS, require low value before WARN.
    #
    elsif ( $prev_status eq 'CRISIS'
	    && $value <= $rec_meta->{warn_max} - $h ) {
	$status = 'WARNING';
	$msg_args = "'$tag' value '$value' in Warning range";
    }
    # 5) Previous status was CRISIS, keep in CRISIS
    #
    elsif ( $prev_status eq 'CRISIS'
	    && $value > $rec_meta->{crisis_min} - $h) {
	$status = 'CRISIS';
	$msg_args = "'$tag' value '$value' in Crisis range";
    }
    else {
	$status = 'DEBUG';
	$msg_args = "'$tag' value '$value' outside expected ranges";
    }
    return ( $status, $msg_args );
}

sub eval_falling_status {
    my ( $tag,  $value, $rec_meta, $prev_status, $prev_value ) = @_;

    my $h = ($rec_meta->{hysteresis} || 0) /2;
    
    $value =~ s{(\d+).*}{$1};	# convert '43 minutes' => '43'

    my ( $msg_args, $status ) = ( '' );

    # 1) Previous status was OK, allow small underaage before not OK
    #
    if ( $prev_status eq 'OK'
	 && $value >= $rec_meta->{ok_min} - $h ) {
	$status = 'OK';
    }
    # 2) Previous status was not OK, require high value before OK.
    #    
    elsif ( $prev_status ne 'OK'
	 && $value >= $rec_meta->{ok_min} + $h) {
	$status = 'OK';
    }
    # 3) Previous status was WARN, allow small underage before CRISIS
    #
    elsif ( ($prev_status eq 'OK' || $prev_status eq 'WARNING') 
	    && $value >= $rec_meta->{warn_min} - $h ) {
	$status = 'WARNING';
	$msg_args = "'$tag' value '$value' in Warning range";
	
    }
    # 4) Previous status was CRISIS, require high value before WARN.
    #
    elsif ( $prev_status eq 'CRISIS'
	    && $value >= $rec_meta->{warn_min} + $h ) {
	$status = 'WARNING';
	$msg_args = "'$tag' value '$value' in Warning range";
    }
    # 5) Previous status was CRISIS, keep in CRISIS
    #
    elsif ( $prev_status eq 'CRISIS'
	    && $value < $rec_meta->{crisis_max} + $h) {
	$status = 'CRISIS';
	$msg_args = "'$tag' value '$value' in Crisis range";
    }
    else {
	$status = 'DEBUG';
	$msg_args = "'$tag' value '$value' outside expected ranges";
    }
    return ( $status, $msg_args, $value ); # store edited runtime remaining w/o 'minutes'
}

sub eval_nested_status {
    my ( $tag,  $value, $rec_meta, $prev_status, $prev_value ) = @_;

    my $h = ($rec_meta->{hysteresis} || 0) /2;
    
    my ( $msg_args, $status ) = ( '' );

    # 1) Previous status was OK, allow small overage before not OK
    #
    if ( $prev_status eq 'OK'
	 && $value >= $rec_meta->{ok_min} - $h 
	 && $value <= $rec_meta->{ok_max} + $h 
	) {
	$status = 'OK';
    }
    # 2) Previous status was not OK, require low value before OK.
    #    
    elsif ( $prev_status ne 'OK'
	    && $value >= $rec_meta->{ok_min} + $h 
	    && $value <= $rec_meta->{ok_max} - $h) {
	$status = 'OK';
    }
    # 3) Previous status was WARN, allow small overage before CRISIS
    #
    elsif ( ($prev_status eq 'OK' || $prev_status eq 'WARNING') 
	    && $value >= $rec_meta->{warn_min} - $h 
	    && $value <= $rec_meta->{warn_max} + $h ) {
	$status = 'WARNING';
	$msg_args = "'$tag' value '$value' in Warning range";
	
    }
    # 4) Previous status was CRISIS, require low value before WARN.
    #
    elsif ( $prev_status eq 'CRISIS'
	    && $value >= $rec_meta->{warn_min} - $h 
	    && $value <= $rec_meta->{warn_max} + $h ) {
	$status = 'WARNING';
	$msg_args = "'$tag' value '$value' in Warning range";
    }
    # 5) Previous status was CRISIS, keep in CRISIS
    #
    elsif ( $prev_status eq 'CRISIS'
	    && $value > $rec_meta->{warn_min} - $h 
	    && $value < $rec_meta->{warn_min} + $h) {
	$status = 'CRISIS';
	$msg_args = "'$tag' value '$value' in Crisis range";
    }
    else {
	$status = 'DEBUG';
	$msg_args = "'$tag' value '$value' outside expected ranges";
    }
    return ( $status, $msg_args );
}

sub eval_status {
    my ( $tag,  $value, $rec_meta, $prev_status, $prev_value ) = @_;

    return &eval_discrete_status
	unless ( exists $rec_meta->{ok_min} ); # not range data.

    return &eval_rising_status
	if ( $rec_meta->{warn_min} == $rec_meta->{ok_max}
	     && $rec_meta->{warn_max} > $rec_meta->{ok_max} );

    return &eval_falling_status
	if ( $rec_meta->{warn_max} == $rec_meta->{ok_min}
	     && $rec_meta->{warn_min} < $rec_meta->{ok_min} );

    return &eval_nested_status
	if ( $rec_meta->{warn_max} >= $rec_meta->{ok_max}
	     && $rec_meta->{warn_min} <= $rec_meta->{ok_min} );
}

sub process_all_oids {
    my $self = shift;
    my ( $received, $target, $metadata ) = @_;

    my ( $info, $prev, $results ) = ( $self->snmp, $self->prev );

    for my $oid ( keys %$received ) {
	my $value    = $received->{$oid};
	my $tag      = $metadata->{roid}{$oid};
	my $rec_meta = $metadata->{$tag};
	my $label    = $rec_meta->{label} || $tag;

	my $prev_value  = $prev->{$target}{$tag}{value} || $value;
	my $prev_status = $prev->{$target}{$tag}{status} || 'OK';

	# Calculate status and message; convert numeric codes to strings.
	#
	my ( $status, $msg_args, $newvalue ) = eval_status( $tag, $value, $rec_meta,
							    $prev_status, $prev_value );
		
	$results->{data}{$label}{value} = $newvalue || $value;
	$results->{data}{$label}{status} = $status;
	$results->{data}{$label}{msg_args} = $msg_args;

	$prev->{$target}{$tag}{value} = $newvalue || $value;
	$prev->{$target}{$tag}{status} = $status;
    }
    return $results;
}

sub snmp_connect {
    my ( $metadata ) = @_;

    my $meta;

    @{$meta}{qw(name ip pw)} = @{$metadata}{qw(name ip community )};
	
      my ($session, $error) = Net::SNMP->session(
	  -hostname  => $meta->{ip},
	  -community => $meta->{pw},
	  -version   => 'snmpv2c',
	  );
      if (!defined $session) {
	  $meta->{status} = 'CRISIS';
	  $meta->{msg_args} = 'Could not connect to Net::SNMP session: ' . $error;
      }
      return ($meta, $session);
}

sub query_target {
    my $self = shift;

    my ($results, $session);
    my $info = $self->snmp;
  TARGET:			# For each snmp target (1, 2, ... ) in the ini file
    for my $target ( keys %$info ) {
	my $metadata = $info->{$target};

	# Connect to the target, if possible.
	#
	( $results->{metadata}, $session ) = snmp_connect( $metadata );
	next TARGET unless $session;

	# Fetch list of data
	#
	my $received = $session->get_request(-varbindlist => $metadata->{oids},);
	$session->close;
	
	if ( not defined $received) {
	    $results->{$target}{data}{status} = 'CRISIS';
	    $results->{$target}{data}{args}
                = 'Net::SNMP->get_bulk_request() failed: ' . $session->error;
	    next TARGET;
	}

	# Evaluate and classify data
	#
	$results->{$target} = $self->process_all_oids( $received, $target, $metadata );
    }
    return $results;
}

sub store_records {
    my $self = shift;

    my ( $records ) = @_;

    say "store_records";
}

sub loop_core {
    my $self = shift;

    my $results = $self->query_target;
    $self->store_records( $results );

    return;
}

1;
# ======================================================================
# End of File.
