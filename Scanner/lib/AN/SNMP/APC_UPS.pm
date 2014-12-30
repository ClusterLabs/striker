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
    # Additionally accumulate list of oids for use in get_bulk_request.
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
    my $tag = __PACKAGE__ . "eval_non_range_status() not implemented yet.";

    say $tag;
    return ( 'DEBUG', $tag);
}
sub eval_rising_status {
    my ( $tag,  $value, $rec_meta, $prev_status ) = @_;

    my $h = ($rec_meta->{hysteresis} || 0) /2;
    
    my ( $status, $msg_args );
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
    my ( $tag,  $value, $rec_meta, $prev_status ) = @_;

    my $h = ($rec_meta->{hysteresis} || 0) /2;
    
    $value =~ s{(\d+).*}{$1};	# convert '43 minutes' => '43'

    my ( $status, $msg_args );
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
    return ( $status, $msg_args );

}

sub eval_nested_status {
    my ( $tag,  $value, $rec_meta, $prev_status ) = @_;

    my $h = ($rec_meta->{hysteresis} || 0) /2;
    
    my ( $status, $msg_args );
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
    my ( $tag,  $value, $rec_meta, $prev_status ) = @_;

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

sub query_target {
    my $self = shift;

    
    my %results;
    my $info = $self->snmp;
    my $prev = $self->prev;
  TARGET:
    for my $target ( keys %$info ) {
	my $metadata = $info->{$target};
	@{$results{$target}}{metadata}{qw( name ip pw)}
	    = @{$metadata}{qw(name ip community )};
	
	my ($session, $error) = Net::SNMP->session(
	    -hostname    => $results{$target}{ip},
	    -community   => $results{$target}{pw},
	    -version     => 'snmpv2c',
	    );
	if (!defined $session) {
	    say 'ERROR: ', $error, '.';
	    $results{$target}{data}{status} = 'CRISIS';
	    $results{$target}{data}{args}   = 'Could not create Net::SNMP session';
	    next TARGET;
	}

	my $received = $session->get_request(
	    -varbindlist => $metadata->{oids},
	    );

	if (defined $received) {
	    for my $oid ( keys %$received ) {
		my $value = $received->{$oid};
		my $tag = $metadata->{roid}{$oid};
		my $rec_meta = $metadata->{$tag};
		my $prev_value = $prev->{$target}{$tag}{value} || $value;
		my $prev_status = $prev->{$target}{$tag}{status} || 'OK';
		my $label = $rec_meta->{value} || $tag;

		$results{$target}{data}{$label}{value} = $value;

		my ( $status, $msg_args ) 
		    = eval_status( $tag, $value, $rec_meta, $prev_status );
		
		$results{$target}{data}{$label}{status} = $status;
		$results{$target}{data}{$label}{msg_args} = $msg_args;

		$prev->{$target}{$tag}{value} = $value;
		$prev->{$target}{$tag}{status} = $status;


#		elsif ( $tag eq 'battery replace' ) {
#		    if ( $rec_meta->{values}{$value} eq 'needed' ) {
#			$results{$target}{data}{$label}{status} = 'DEBUG';
#			$results{$target}{data}{$label}{msg_tag} = 'replace battery';
#			$results{$target}{data}{$label}{msg_args}
#			= sprintf "UPS '%s' at IP %s", $results{$target}{data}{name},
#			                               $results{$target}{data}{ip};
#		    }
#		    else {
#			$results{$target}{data}{$label}{status} = 'OK';
#		    }
	    }
	}
	else {
	    say 'ERROR: ', $session->error, '.';
	    $results{$target}{data}{status} = 'CRISIS';
	    $results{$target}{data}{args}
	        = 'Net::SNMP->get_bulk_request() failed: ' . $session->error;
	    next TARGET;
	}
	$session->close;

	say "Processes results here";
    }
	
    return;
	
}

sub loop_core {
    my $self = shift;

    $self->query_target();

    return;
}

1;
# ======================================================================
# End of File.
