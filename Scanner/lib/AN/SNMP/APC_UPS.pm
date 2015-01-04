package AN::SNMP::APC_UPS;

use base 'AN::Agent';    # inherit from AN::Agent

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

use Class::Tiny qw( snmpconf snmp prev );

# ======================================================================
# CONSTANTS
#

# ......................................................................
#

sub BUILD {
    my $self = shift;

    $self->snmpconf( catdir( $self->path_to_configuration_files(),
			     $self->snmpconf ) );

    my %cfg = ( path => { config_file => $self->snmpconf } );
    AN::Common::read_configuration_file( \%cfg );

    $self->snmp( $cfg{snmp} );

    # Reverse cache, look up mib label by oid number
    # Override with specified labels, when provided.
    # Accumulate list of oids for use in get_bulk_request.
    # Allocate blank entries for storage of previous values.
    #
    my %prev;
    for my $target ( keys %{ $self->snmp() } ) {
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
    my $self = shift;
    my ( $tag, $value, $rec_meta, $prev_status, $prev_value ) = @_;
    my $units = $rec_meta->{units} || '';
    my ( $msg_tag, $msg_args, $label, $status, $newvalue ) = ( '', '', '' );

    if ( $tag eq 'battery replace' ) {
        $newvalue = $rec_meta->{values}{$value};
        if ( $newvalue eq 'unneeded' ) {
            $status = 'OK';
        }
        elsif ( $newvalue eq 'needed' ) {
            $status  = 'DEBUG';
            $msg_tag = 'Replace battery';
        }
        else {
            $status   = 'DEBUG';
            $msg_tag  = "Unrecognized value";
            $msg_args = "value=$value";
        }
    }
    elsif ( $tag eq 'comms' ) {
        $newvalue = $rec_meta->{values}{$value};
        $label    = $rec_meta->{label};
        if ( $newvalue eq 'yes' ) {
            $status = 'OK';
        }
        elsif ( $newvalue eq 'no' ) {
            $status  = 'DEBUG';
            $msg_tag = "Communication disconnected";
        }
        else {
            $status   = 'DEBUG';
            $msg_tag  = "Unrecognized value";
            $msg_args = "value=$value";
        }
    }
    elsif ( $tag eq 'reason for last transfer' ) {
        $newvalue = $rec_meta->{values}{$value};
        if (    $prev_value
             && $prev_value ne $newvalue ) {
            $status   = 'DEBUG';
            $msg_tag  = "value changed";
            $msg_args = "prevvalue=$prev_value;value=$newvalue";
        }
        else {
            $status = 'OK';
        }
    }
    elsif ( $tag eq 'last self test date' ) {
        if (    $prev_value
             && $prev_value ne $value ) {
            $status   = 'DEBUG';
            $msg_tag  = "value changed";
            $msg_args = join( ';', "prevvalue=$rec_meta->{values}{$prev_value}",
			      "value=$rec_meta->{values}{$value}");
        }
        else {
            $status = 'OK';
        }
    }
    elsif ( $tag eq 'last self test result' ) {
        if ( $value == 1 || $value == 4 ) {
            $status = 'OK';
        }
        else {
            $status   = 'DEBUG';
            $msg_tag  = 'Self-test not OK: ';
            $msg_args = ( [ undef, '', 'failed', 'invalid test' ] )[$value];
        }
    }
    my $args = { table              => $self->datatable_name,
		 with_node_table_id => 'node_id',
		 args               => {
		     value    => $newvalue || $value,
		     units    => $units,
		     field    => $label || $tag,
		     status   => $status,
		     msg_tag  => $msg_tag,
		     msg_args => $msg_args,
		 }, };

    $self->insert_raw_record( $args );

    if ( $status ne 'OK' ) {
	$args->{table} = $self->alerts_table_name;
	$self->insert_raw_record( $args );
    }
    return ( $status, $newvalue || $value );
}

sub eval_rising_status {
    my $self = shift;
    my ( $tag, $value, $rec_meta, $prev_status, $prev_value ) = @_;

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
		     value    => $value,
		     units    => $units,
		     field    => $tag,
		     status   => $status,
		     msg_tag  => $msg_tag,
		     msg_args => $msg_args,
		 }, };

    $self->insert_raw_record( $args );

    if ( $status ne 'OK' ) {
	$args->{table} = $self->alerts_table_name;
	$self->insert_raw_record( $args );
    }

    return ($status);
}

sub eval_falling_status {
    my $self = shift;
    my ( $tag, $value, $rec_meta, $prev_status, $prev_value ) = @_;

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
		     value    => $value,
		     units    => $units,
		     field    => $tag,
		     status   => $status,
		     msg_tag  => $msg_tag,
		     msg_args => $msg_args,
		 }, };

    $self->insert_raw_record( $args );

    if ( $status ne 'OK' ) {
	$args->{table} = $self->alerts_table_name;
	$self->insert_raw_record( $args );
    }
    return ( $status, $value );
}

sub eval_nested_status {
    my $self = shift;
    my ( $tag, $value, $rec_meta, $prev_status, $prev_value ) = @_;

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
		     value    => $value,
		     units    => $units,
		     field    => $tag,
		     status   => $status,
		     msg_tag  => $msg_tag,
		     msg_args => $msg_args,
		 }, };

    $self->insert_raw_record( $args );

    if ( $status ne 'OK' ) {
	$args->{table} = $self->alerts_table_name;
	$self->insert_raw_record( $args );
    }
    return ($status);
}

sub eval_status {
#    my ( $self, $tag, $value, $rec_meta, $prev_status, $prev_value ) = @_;

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

sub process_all_oids {
    my $self = shift;
    my ( $received, $target, $metadata ) = @_;

    my ( $info, $prev ) = ( $self->snmp, $self->prev );

    for my $oid ( keys %$received ) {
        my ( $value, $tag ) = ( $received->{$oid}, $metadata->{roid}{$oid} );
        my $rec_meta = $metadata->{$tag};
        my $label = $rec_meta->{label} || $tag;

        my $prev_value = $prev->{$target}{$tag}{value};
        my $prev_status = $prev->{$target}{$tag}{status} || 'OK';

        # Calculate status and message; convert numeric codes to strings.
        #
        state $i = 1;
        say Data::Dumper->Dump(
                    [ $i, $tag, $value, $rec_meta, $prev_status, $prev_value ] )
            if $self->verbose && $self->verbose >= 2;
        $i++;
        my ( $status, $newvalue )
            = $self->eval_status( $tag, $value, $rec_meta,
                                  $prev_status, $prev_value );

        $prev->{$target}{$tag}{value} = $newvalue || $value;
        $prev->{$target}{$tag}{status} = $status;
    }
}

sub snmp_connect {
    my $self = shift;
    my ($metadata) = @_;

    my $meta;

    @{$meta}{qw(name ip pw)} = @{$metadata}{qw(name ip community )};

    my ( $session, $error )
        = Net::SNMP->session( -hostname  => $meta->{ip},
                              -community => $meta->{pw},
                              -version   => 'snmpv2c', );
    if ( !defined $session ) {
	my $args = { table              => $self->datatable_name,
		     with_node_table_id => 'node_id',
		     args               => {
			 value    => $meta->{name},
			 units    => '',
			 field    => 'Net::SNMP connect',
			 status   => 'CRISIS',
			 msg_tag  => 'Net-SNMP connect failed',
			 msg_args => "errormsg=" . $error,
		     }, };

	$self->insert_raw_record( $args );

	$args->{table} = $self->alerts_table_name;
	$self->insert_raw_record( $args );
    }
    
    return ( $meta, $session );
}

sub query_target {
    my $self = shift;

    my $info = $self->snmp;
TARGET:    # For each snmp target (1, 2, ... ) in the config file
    for my $target ( keys %$info ) {
        my $metadata = $info->{$target};

        # Connect to the target, if possible.
        #
        my ( $meta_out, $session ) = $self->snmp_connect($metadata);
        next TARGET unless $session;

        # Fetch list of data
        #
        my $received
            = $session->get_request( -varbindlist => $metadata->{oids}, );

        if ( not defined $received ) {
	    my $args = { table              => $self->datatable_name,
			 with_node_table_id => 'node_id',
			 args               => {
			     value    => $meta_out->{name},
			     units    => '',
			     field    => 'Net::SNMP fetch data',
			     status   => 'CRISIS',
			     msg_tag  => 'Net-SNMP->get_request() failed',
			     msg_args => "errormsg=" . $session->error,
			 }, };
	    
	    $self->insert_raw_record( $args );
	    
	    $args->{table} = $self->alerts_table_name;
	    $self->insert_raw_record( $args );

            next TARGET;
        }
        $session->close;

        # Evaluate and classify data
        #
        $self->process_all_oids( $received, $target, $metadata );
    }
    return;
}

sub loop_core {
    my $self = shift;

    $self->query_target;

    return;
}

1;

# ======================================================================
# End of File.
