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
use Time::HiRes qw(time alarm sleep);

use AN::Common;
use AN::MonitorAgent;
use AN::FlagFile;
use AN::Unix;
use AN::DBS;

use Class::Tiny qw( snmpconf snmp prev );

# ======================================================================
# CONSTANTS
#
const my $DATATABLE_NAME => 'snmp_apc_ups';

# ......................................................................
#

sub read_configuration_file {
    my $self = shift;

    $self->snmpconf(
              catdir( $self->path_to_configuration_files(), $self->snmpconf ) );

    my %cfg = ( path => { config_file => $self->snmpconf } );
    AN::Common::read_configuration_file( \%cfg );

    $self->snmp( $cfg{snmp} );
}

sub deep_copy {
    my $self = shift;
    my ( $source, @targets ) = @_;

    for my $key ( sort keys %$source ) {
    TARGET:
        for my $target (@targets) {
            if ( exists $target->{$key} ) {
                if ( !ref $target->{$key} ) {    # it's a scalar leaf
                    next TARGET;                 # ignore global value
                }
                elsif ( 'HASH' eq ref $target->{$key} ) {
                    $self->deep_copy( $source->{$key},
                                      map { $_->{$key} } @targets );
                }
            }
            else {
                $target->{$key} = $source->{$key};
            }
        }
    }
    return;
}

sub normalize_global_and_local_config_data {
    my $self = shift;

    my $snmp = $self->snmp;
    return unless (    exists $snmp->{global}
                    || exists $snmp->{default} );
    my @targets = grep {/\A\d+\z/} keys %$snmp;

    # Recursively copy global / default values to local
    # areas, unless they are already specified.
    #
    for my $tag (qw( global local )) {
        $self->deep_copy( $snmp->{$tag}, @{$snmp}{@targets} );
        delete $snmp->{$tag};
    }
}

# Reverse cache, look up mib label by oid number Override with
# specified labels, when provided.  Accumulate list of oids for use in
# get_bulk_request.  Allocate blank entries for storage of previous
# values.
#
sub prep_reverse_cache_and_prev_values {
    my $self = shift;

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

}

sub BUILD {
    my $self = shift;

    # Don't run for sub-classes.
    #
    return unless ref $self eq __PACKAGE__;

    $self->read_configuration_file;
    $self->normalize_global_and_local_config_data;
    $self->prep_reverse_cache_and_prev_values;

    return;
}

sub insert_agent_record {
    my $self = shift;
    my ( $args, $msg ) = @_;

    $self->insert_raw_record(
                              { table              => $self->datatable_name,
                                with_node_table_id => 'node_id',
                                args               => {
                                      value => $msg->{newval} || $args->{value},
                                      units => $args->{rec_meta}{units} || '',
                                      field => $msg->{label} || $args->{tag},
                                      status   => $msg->{status},
                                      msg_tag  => $msg->{tag},
                                      msg_args => $msg->{args},
                                },
                              } );
    return;
}

sub insert_alert_record {
    my $self = shift;
    my ( $args, $msg ) = @_;

    $self->insert_raw_record(
                              { table              => $self->alerts_table_name,
                                with_node_table_id => 'node_id',
                                args               => {
                                      value => $msg->{newval} || $args->{value},
                                      units => $args->{rec_meta}{units} || '',
                                      field => $msg->{label} || $args->{tag},
                                      status   => $msg->{status},
                                      msg_tag  => $msg->{tag},
                                      msg_args => $msg->{args},
				      target_name  => $args->{metadata}{name},
				      target_type  => $args->{metadata}{type},
				      target_extra => $args->{metadata}{ip},
  
                               },
                              } );
    return;
}

sub eval_discrete_status {
    my $self = shift;
    my ($args) = @_;

    my  $msg = {args => '', tag => '', label => '', newval => '', status => '' };

    if ( $args->{tag} eq 'battery replace' ) {
        $msg->{newval} = $args->{rec_meta}{values}{ $args->{value} } || '';
        if ( $msg->{newval} eq 'unneeded' ) {
            $msg->{status} = 'OK';
        }
        elsif ( $msg->{newval} eq 'needed' ) {
            $msg->{status} = 'DEBUG';
            $msg->{tag}    = 'Replace battery';
        }
        else {
            $msg->{status} = 'DEBUG';
            $msg->{tag}    = "Unrecognized value";
            $msg->{args}   = "value=$args->{value}";
        }
    }
    elsif ( $args->{tag} eq 'comms' ) {
        $msg->{newval} = $args->{rec_meta}{values}{ $args->{value} } || '';
        $msg->{label} = $args->{rec_meta}{label} || '';
        if ( $msg->{newval} eq 'yes' ) {
            $msg->{status} = 'OK';
        }
        elsif ( $msg->{newval} eq 'no' ) {
            $msg->{status} = 'DEBUG';
            $msg->{tag}    = "Communication disconnected";
        }
        else {
            $msg->{status} = 'DEBUG';
            $msg->{tag}    = "Unrecognized value";
            $msg->{args}   = "value=$args->{value}";
        }
    }
    elsif ( $args->{tag} eq 'reason for last transfer' ) {
        $msg->{newval} = $args->{rec_meta}{values}{ $args->{value} } || '';
        if (    $args->{prev_value}
             && $args->{prev_value} ne $msg->{newval} ) {
            $msg->{status} = 'DEBUG';
            $msg->{tag}    = "value changed";
            $msg->{args}   = "prevvalue=$args->{prev_value};value=$msg->{newval}";
        }
        else {
            $msg->{status} = 'OK';
        }
    }
    elsif ( $args->{tag} eq 'last self test date' ) {
        if (    $args->{prev_value}
             && $args->{prev_value} ne $args->{value} ) {
            $msg->{status} = 'DEBUG';
            $msg->{tag}    = "value changed";
            $msg->{args} = "prevvalue=$args->{prev_value};value=$args->{value}";
        }
        else {
            $msg->{status} = 'OK';
        }
    }
    elsif ( $args->{tag} eq 'last self test result' ) {
        if ( $args->{value} == 1 || $args->{value} == 4 ) {
            $msg->{status} = 'OK';
        }
        else {
            $msg->{status} = 'DEBUG';
            $msg->{tag}    = 'Self-test not OK: ';
            $msg->{args}
                = ( [ undef, '', 'failed', 'invalid test' ] )[ $args->{value} ];
        }
    }
    $args->{prev_status} ||= '';

    $self->insert_agent_record( $args, $msg );
    $self->insert_alert_record( $args, $msg )	
	if  $msg->{status} ne 'OK'
	|| (    $msg->{status} eq 'OK' && $args->{prev_status} ne 'OK' )
        ;
    
    return ( $msg->{status}, $msg->{newval} || $args->{value} );
}

sub eval_rising_status {
    my $self = shift;
    my ($args) = @_;

    my $h = ( $args->{rec_meta}{hysteresis} || 0 ) / 2;

    my $msg = {args => '', tag => ''};

    # 1) Previous status was OK, allow small overage before not OK
    #
    if (    $args->{prev_status} eq 'OK'
         && $args->{value} <= $args->{rec_meta}{ok_max} + $h ) {
        $msg->{status} = 'OK';
    }

    # 2) Previous status was not OK, require low value before OK.
    #
    elsif (    $args->{prev_status} ne 'OK'
            && $args->{value} <= $args->{rec_meta}{ok_max} - $h ) {
        $msg->{status} = 'OK';
    }

    # 3) Previous status was OK or WARN, allow small overage before CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} <= $args->{rec_meta}{warn_max} + $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 4) Previous status was OK or WARN, now changed to CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} > $args->{rec_meta}{warn_max} + $h ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }

    # 5) Previous status was CRISIS, require low value before WARN.
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} <= $args->{rec_meta}{warn_max} - $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 6) Previous status was CRISIS, keep in CRISIS
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} > $args->{rec_meta}{crisis_min} - $h ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }
    else {
        $msg->{status} = 'DEBUG';
        $msg->{tag}    = "Unexpected value";
        $msg->{args}   = "value=$args->{value}";
    }

    $self->insert_agent_record( $args, $msg );
    $self->insert_alert_record( $args, $msg )	
	if  $msg->{status} ne 'OK'
	|| (    $msg->{status} eq 'OK' && $args->{prev_status} ne 'OK' );
    
    return ( $msg->{status} );
}

sub eval_falling_status {
    my $self = shift;
    my ($args) = @_;

    my $h = ( $args->{rec_meta}{hysteresis} || 0 ) / 2;

    $args->{value} =~ s{([\d+.]+).*}{$1};    # convert '43 minutes' => '43'

    my $msg = {args => '', tag => ''};

    # 1) Previous status was OK, allow small underaage before not OK
    #
    if (    $args->{prev_status} eq 'OK'
         && $args->{value} >= $args->{rec_meta}{ok_min} - $h ) {
        $msg->{status} = 'OK';
    }

    # 2) Previous status was not OK, require high value before OK.
    #
    elsif (    $args->{prev_status} ne 'OK'
            && $args->{value} >= $args->{rec_meta}{ok_min} + $h ) {
        $msg->{status} = 'OK';
    }

    # 3) Previous status was OK or WARN, allow small underage before CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} >= $args->{rec_meta}{warn_min} - $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 4) Previous status was OK or WARN, go to CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} < $args->{rec_meta}{warn_min} - $h ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }

    # 4) Previous status was CRISIS, require high value before WARN.
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} >= $args->{rec_meta}{warn_min} + $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 5) Previous status was CRISIS, keep in CRISIS
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} < $args->{rec_meta}{crisis_max} + $h ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }
    else {
        $msg->{status} = 'DEBUG';
        $msg->{tag}    = "Unexpected value";
        $msg->{args}   = "value=$args->{value}";

    }

    $self->insert_agent_record( $args, $msg );
    $self->insert_alert_record( $args, $msg )
	if  $msg->{status} ne 'OK'
	|| (    $msg->{status} eq 'OK' && $args->{prev_status} ne 'OK' )
        ;

    return ( $msg->{status}, $args->{value} );
}

sub eval_nested_status {
    my $self = shift;
    my ($args) = @_;

    my $h = ( $args->{rec_meta}{hysteresis} || 0 ) / 2;

    my $msg = {args => '', tag => ''};

    # 1) Previous status was OK, allow small overage before not OK
    #
    if (    $args->{prev_status} eq 'OK'
         && $args->{value} >= $args->{rec_meta}{ok_min} - $h
         && $args->{value} <= $args->{rec_meta}{ok_max} + $h ) {
        $msg->{status} = 'OK';
    }

    # 2) Previous status was not OK, require low value before OK.
    #
    elsif (    $args->{prev_status} ne 'OK'
            && $args->{value} >= $args->{rec_meta}{ok_min} + $h
            && $args->{value} <= $args->{rec_meta}{ok_max} - $h ) {
        $msg->{status} = 'OK';
    }

    # 3) Previous status was WARN, allow small overage before CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} >= $args->{rec_meta}{warn_min} - $h
           && $args->{value} <= $args->{rec_meta}{warn_max} + $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 4) Previous status was WARN, now CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && (    $args->{value} < $args->{rec_meta}{warn_min} - $h
                || $args->{value} > $args->{rec_meta}{warn_max} + $h )
        ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }

    # 5) Previous status was CRISIS, require strong move before WARN.
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} >= $args->{rec_meta}{warn_min} + $h
            && $args->{value} <= $args->{rec_meta}{warn_max} - $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 6) Previous status was CRISIS, keep in CRISIS
    #
    elsif ( $args->{prev_status} eq 'CRISIS'
            && (    $args->{value} < $args->{rec_meta}{warn_min} + $h
                 || $args->{value} > $args->{rec_meta}{warn_max} - $h )
        ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }
    else {
        $msg->{status} = 'DEBUG';
        $msg->{tag}    = "Unexpected value";
        $msg->{args}   = "value=$args->{value}";
    }
    $self->insert_agent_record( $args, $msg );
    $self->insert_alert_record( $args, $msg )	
	if  $msg->{status} ne 'OK'
	|| (    $msg->{status} eq 'OK' && $args->{prev_status} ne 'OK' );

    return ( $msg->{status} );
}

sub eval_status {
    my ($self, $args) = @_;

    return &eval_discrete_status
        unless ( exists $args->{rec_meta}{ok_min} );    # not range data.

    return &eval_rising_status
        if (    $args->{rec_meta}{warn_min} == $args->{rec_meta}{ok_max}
             && $args->{rec_meta}{warn_max} > $args->{rec_meta}{ok_max} );

    return &eval_falling_status
        if (    $args->{rec_meta}{warn_max} == $args->{rec_meta}{ok_min}
             && $args->{rec_meta}{warn_min} < $args->{rec_meta}{ok_min} );

    return &eval_nested_status
        if (    $args->{rec_meta}{warn_max} >= $args->{rec_meta}{ok_max}
             && $args->{rec_meta}{warn_min} <= $args->{rec_meta}{ok_min} );
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
            if grep {/grocess_all_opids/} ( $ENV{VERBOSE} || 0 );
        $i++;

        my $args = { tag         => $tag,
		     value       => $value,
                     rec_meta    => $rec_meta,
                     prev_status => $prev_status,
                     prev_value  => $prev_value,
                     metadata    => $metadata };
        my ( $status, $newvalue ) = $self->eval_status($args);

        $prev->{$target}{$tag}{value} = $newvalue || $value;
        $prev->{$target}{$tag}{status} = $status;
    }
}

sub snmp_connect {
    my $self = shift;
    my ($metadata) = @_;

    my $meta;

    @{$meta}{qw(name ip pw type)} = @{$metadata}{qw(name ip community type)};

    my ( $session, $error )
        = Net::SNMP->session( -hostname  => $meta->{ip},
                              -community => $meta->{pw},
                              -version   => 'snmpv2c', );
    if ( !defined $session ) {
        my $args = { table              => $self->datatable_name,
                     with_node_table_id => 'node_id',
                     args               => {
                               target_name  => $meta->{name},
                               target_type  => $meta->{type},
                               target_extra => $meta->{ip},
                               value        => $meta->{name},
                               units        => '',
                               field        => 'Net::SNMP connect',
                               status       => 'CRISIS',
                               msg_tag      => 'Net-SNMP connect failed',
                               msg_args     => "errormsg=" . $error,
                             }, };

        $self->insert_raw_record($args);

        $args->{table} = $self->alerts_table_name;
        $self->insert_raw_record($args);
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
                                   target_name  => $meta_out->{name},
                                   target_type  => $meta_out->{type},
                                   target_extra => $meta_out->{ip},
                                   value        => $meta_out->{name},
                                   units        => '',
                                   field        => 'Net::SNMP fetch data',
                                   status       => 'CRISIS',
                                   msg_tag  => 'Net-SNMP->get_request() failed',
                                   msg_args => "errormsg=" . $session->error,
                                 }, };

            $self->insert_raw_record($args);

            $args->{table} = $self->alerts_table_name;
            $self->insert_raw_record($args);

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
