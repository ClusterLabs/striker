package AN::SNMP::APC_UPS;

use parent 'AN::Agent';    # inherit from AN::Agent

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Carp;
use Data::Dumper;
use English '-no_match_vars';
use File::Basename;
use Net::SNMP ':snmp';

# ======================================================================
# CLASS ATTRIBUTES & CONSTRUCTOR
#
use Class::Tiny qw( confpath confdata prev summary sumweight bindir ),
    { compare => sub { {} }, };

sub BUILD {
    my $self = shift;

    $self->clear_summary();

    # Don't run for sub-classes.
    #
    return unless ref $self eq __PACKAGE__;

    $self->normalize_global_and_local_config_data;
    $self->prep_reverse_cache_and_prev_values;

    return;
}

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Copy a Perl data structure at every level.
#
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

# ----------------------------------------------------------------------
# Convert 'global' or 'default' config file records into each
# numerically-identified instances, but do not overwrite existing
# values. This allows default values to be specified, yet overridden
# for particular instances.
#
sub normalize_global_and_local_config_data {
    my $self = shift;

    my $confdata = $self->confdata;
    return unless (    exists $confdata->{global}
                    || exists $confdata->{default} );
    my @targets = grep {/\A\d+\z/} keys %$confdata;

    # Recursively copy global / default values to local
    # areas, unless they are already specified.
    #
TAG:
    for my $tag (qw( global local )) {
        next TAG if $tag eq 'summary';
        $self->deep_copy( $confdata->{$tag}, @{$confdata}{@targets} );
        delete $confdata->{$tag};
    }
}

# ----------------------------------------------------------------------
# Reverse cache, look up mib label by oid number Override with
# specified labels, when provided.  Accumulate list of oids for use in
# get_bulk_request.  Allocate blank entries for storage of previous
# values.
#
sub prep_reverse_cache_and_prev_values {
    my $self = shift;

    my %prev;
    for my $target ( keys %{ $self->confdata() } ) {
        my $dataset = $self->confdata()->{$target};
        my @oids;
        for my $mib ( keys %{ $dataset->{oid} } ) {
            my $oid = $dataset->{oid}{$mib};
            push @oids, $oid;
            $dataset->{roid}{$oid} = $mib;
            $prev{$target}{$mib} = undef;
        }
        $dataset->{oids} = \@oids;
    }
    $prev{summary}{status} = 'OK';
    $prev{summary}{value}  = 0;
    $self->prev( \%prev );

}

# ----------------------------------------------------------------------
# Reset sumweight to zero, empty the summary array.
#
sub clear_summary {
    my $self = shift;

    $self->summary( [] );
    $self->sumweight(0);
}

# ----------------------------------------------------------------------
# Add a record to the summary array, add its weighted value to the sum.
# Invoked for CRISIS events.
#
sub summarize_status {
    my $self = shift;
    my ( $status, $weight ) = @_;

    push @{ $self->summary() }, $status;
    $self->sumweight( $self->sumweight() + $weight );
}

# ----------------------------------------------------------------------
# Some variables are summarized for each instance that has a
# problem. Some, especially certain UPS characteristics, consider only
# the healthiest source. This routine adds the data from compared
# variables to the summary.
#
sub summarize_compared_sides {
    my $self = shift;

    my $compared = $self->compare();

COMPARISON:
    for my $tag ( sort keys %$compared ) {
        next COMPARISON
            unless $compared->{$tag}{status} eq 'CRISIS';
        $self->sumweight( $self->sumweight() + $compared->{$tag}{weight} );
    }
    return;
}

# ----------------------------------------------------------------------
# At end of loop, calculate summary record and insert it into alerts prior to
# alerts being handled.
#
# The global / local config data processing means there are multiple
# instances of 'summary' data ... use only version '1'.
#
sub process_summary {
    my $self = shift;

    $self->summarize_compared_sides();

    my $prev = $self->prev();

    my $prev_summary = (
            exists $prev->{summary} ? $prev->{summary}
            : (    exists $prev->{1}
                && exists $prev->{1}{summary} ) ? exists $prev->{1}{summary}
            : carp "Can't find prev->{summary} in process_summary()." );

    return
        if $self->sumweight() == 0 and $prev_summary->{status} eq 'OK';

    my $metadata = $self->confdata();
    $metadata = $metadata->{1} unless exists $metadata->{type};

    my $rec_meta = $metadata->{summary} || $metadata->{1}{summary};

    my $args = { tag         => 'summary',
                 value       => $self->sumweight(),
                 rec_meta    => $rec_meta,
                 prev_status => $prev_summary->{status},
                 prev_value  => $prev_summary->{value},
                 metadata    => $metadata };
    $self->eval_status($args);
}

# ----------------------------------------------------------------------
# Insert a record into the ordinary data table.
#
sub insert_agent_record {
    my $self = shift;
    my ( $args, $msg ) = @_;

    my $message_arguments = join q{;},
        grep { defined $_ && length $_ } ( $msg->{args}, $args->{dev} );
    my $name = $args->{metadata}{name} || $args->{metadata}{host};

    my $table = $self->confdata->{db}{table}{ $args->{tag} }
        || $self->confdata->{db}{table}{other};

    $self->insert_raw_record(
                              { table              => $table,
                                with_node_table_id => 'node_id',
                                args               => {
                                      value => $msg->{newval} || $args->{value},
                                      units => $args->{rec_meta}{units} || '',
                                      field => $msg->{label} || $args->{tag},
                                      status            => $msg->{status},
                                      message_tag       => $msg->{tag},
                                      message_arguments => $message_arguments,
                                      target            => $name,
                                },
                              } );
    return;
}

# ----------------------------------------------------------------------
# Add a record to the alerts table.
#
sub insert_alert_record {
    my $self = shift;
    my ( $args, $msg, $exclude_from_sumweight ) = @_;

    my $name = $args->{metadata}{name} || $args->{metadata}{host};

    $self->insert_raw_record(
        {  table              => $self->confdata->{db}{table}{alerts},
           with_node_table_id => 'node_id',
           args               => {
               value => $msg->{newval}           || $args->{value},
               units => $args->{rec_meta}{units} || '',
               field => $msg->{label}            || $args->{tag},
               status            => $msg->{status},
               message_tag       => $msg->{tag},
               message_arguments => $msg->{args},
               target_name       => $name,
               target_type       => $args->{metadata}{type},
               target_extra      => $args->{metadata}{ip},

                   },
        } );

    return if $exclude_from_sumweight;

    $self->summarize_status( $msg->{status}, 1 )
        if $msg->{status} eq 'CRISIS';
    return;
}

# ----------------------------------------------------------------------
# Config file field 'compare' declares that field should be compared
# between two sides. If the value associated with the field is
# 'greater', use the larger of the two values; if 'lesser', use the
# smaller value.  E.g. Time remaining should be larger of the two to
# reflect the healthier, while 'temperature' should be the lower
# value.
#
# If the tag exists, it was set by the other side, so do a comparison.
# If it doesn't exist, set it with this datum, and wait for the other
# side to show up.
#
sub compare_values {
    my ( $v1, $v2, $c ) = @_;

    my $result = (   $c eq 'greater' ? $v1 > $v2
                   : $c eq 'lesser'  ? $v2 < $v2
                   : 0 );
    return $result;
}

# ----------------------------------------------------------------------
# If the config file has a 'compare' value for this variable, compare
# values from each side, storing the 'healthier' value until the
# summary is read at the end of the loop. Whether or not the variable
# is a 'compare' instance, add the value to the ordinary raw table.
# If the status is not OK, or if it is the first OK record after a
# non-OK record, add the record to the alerts table.
#
# But do not add the weight to the summary if this is a 'compared'
# variable.
#
sub compare_sides_or_report_record {
    my $self = shift;
    my ( $args, $msg ) = @_;

    my $exclude_from_sumweight = 0;
    if ( exists $args->{rec_meta}->{compare} ) {
        $exclude_from_sumweight = 1;
        my ( $comparator, $weight )
            = @{ $args->{rec_meta} }{qw(compare weight)};
        my $side = $args->{metadata}{name};
        my $tag  = $args->{tag};
        my ( $new_value, $new_status ) = ( $args->{value}, $msg->{status} );

        # If tag not present in compare() hash, this is first side, so
        # store data and wait for other sides.
        #
        if ( !exists $self->compare()->{$tag} ) {
            @{ $self->compare()->{$tag} }{qw(value status side weight)}
                = ( $new_value, $new_status, $side, $weight );
        }

        # Process 2nd, 3rd, 4th sides ... if new value is 'better'
        # than old one, update archived value to the newer. If equal
        # or worse, leave unchanged.
        #
        else {
            my $other_value = $self->compare()->{$tag}{value};
            @{ $self->compare()->{$tag} }{qw(value status side weight)}
                = ( $new_value, $new_status, $side, $weight )
                if compare_values $new_value, $other_value, $comparator;
        }
    }
    $self->insert_agent_record( $args, $msg );
    $self->insert_alert_record( $args, $msg, $exclude_from_sumweight )
        if $msg->{status} ne 'OK'
        || ( $msg->{status} eq 'OK' && $args->{prev_status} ne 'OK' );

    return;
}

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
            $msg->{args} = "prevvalue=$args->{prev_value};value=$msg->{newval}";
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

    $self->compare_sides_or_report_record( $args, $msg );

    return ( $msg->{status}, $msg->{newval} || $args->{value} );
}

# ----------------------------------------------------------------------
# Compare variables with low values good, medium values a warning, and
# high values a problem. This can be inherited and used for any agent data.
#
sub eval_rising_status {
    my $self = shift;
    my ($args) = @_;

    my $h = ( $args->{rec_meta}{hysteresis} || 0 ) / 2;

    my $msg = { args => '', tag => '' };

    # 1) Previous status was OK, allow small overage before not OK
    #
    if (    $args->{prev_status} eq 'OK'
         && $args->{value} <= $args->{rec_meta}{ok} + $h ) {
        $msg->{status} = 'OK';
    }

    # 2) Previous status was not OK, require low value before OK.
    #
    elsif (    $args->{prev_status} ne 'OK'
            && $args->{value} <= $args->{rec_meta}{ok} - $h ) {
        $msg->{status} = 'OK';
    }

    # 3) Previous status was OK or WARN, allow small overage before CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} <= $args->{rec_meta}{warn} + $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 4) Previous status was OK or WARN, now changed to CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} > $args->{rec_meta}{warn} + $h ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }

    # 5) Previous status was CRISIS, require low value before WARN.
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} <= $args->{rec_meta}{warn} - $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 6) Previous status was CRISIS, keep in CRISIS
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} > $args->{rec_meta}{warn} - $h ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }
    else {
        $msg->{status} = 'DEBUG';
        $msg->{tag}    = "Unexpected value";
        $msg->{args}   = "value=$args->{value}";
    }

    $self->compare_sides_or_report_record( $args, $msg );

    return ( $msg->{status} );
}

# ----------------------------------------------------------------------
# Compare variables with high value good, medium values a warning, and
# low values a problem. This can be inherited and used for any agent data.
#
sub eval_falling_status {
    my $self = shift;
    my ($args) = @_;

    my $h = ( $args->{rec_meta}{hysteresis} || 0 ) / 2;

    $args->{value} =~ s{([\d+.]+).*}{$1};    # convert '43 minutes' => '43'

    my $msg = { args => '', tag => '' };

    # 1) Previous status was OK, allow small underaage before not OK
    #
    if (    $args->{prev_status} eq 'OK'
         && $args->{value} >= $args->{rec_meta}{ok} - $h ) {
        $msg->{status} = 'OK';
    }

    # 2) Previous status was not OK, require high value before OK.
    #
    elsif (    $args->{prev_status} ne 'OK'
            && $args->{value} >= $args->{rec_meta}{ok} + $h ) {
        $msg->{status} = 'OK';
    }

    # 3) Previous status was OK or WARN, allow small underage before CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} >= $args->{rec_meta}{warn} - $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 4) Previous status was OK or WARN, go to CRISIS
    #
    elsif (( $args->{prev_status} eq 'OK' || $args->{prev_status} eq 'WARNING' )
           && $args->{value} < $args->{rec_meta}{warn} - $h ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }

    # 4) Previous status was CRISIS, require high value before WARN.
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} >= $args->{rec_meta}{warn} + $h ) {
        $msg->{status} = 'WARNING';
        $msg->{tag}    = "Value warning";
        $msg->{args}   = "value=$args->{value}";
    }

    # 5) Previous status was CRISIS, keep in CRISIS
    #
    elsif (    $args->{prev_status} eq 'CRISIS'
            && $args->{value} < $args->{rec_meta}{warn} + $h ) {
        $msg->{status} = 'CRISIS';
        $msg->{tag}    = "Value crisis";
        $msg->{args}   = "value=$args->{value}";
    }
    else {
        $msg->{status} = 'DEBUG';
        $msg->{tag}    = "Unexpected value";
        $msg->{args}   = "value=$args->{value}";

    }

    $self->compare_sides_or_report_record( $args, $msg );

    return ( $msg->{status}, $args->{value} );
}

# Compare variables with midrange value good, higher or lower values a
# warning, and highest or lowest values a problem. Either the upper or
# lower portion can be a null range. This can be inherited and used
# for any agent data.
#
sub eval_nested_status {
    my $self = shift;
    my ($args) = @_;

    my $h = ( $args->{rec_meta}{hysteresis} || 0 ) / 2;

    my $msg = { args => '', tag => '' };

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
    $self->compare_sides_or_report_record( $args, $msg );
    return ( $msg->{status} );
}

# ----------------------------------------------------------------------
# Top-level method for evaluating variable status.
#
# * Variables with discrete values have neither an 'ok' nor an
# 'ok_min' value in the config file.
#
# * Variables with an 'ok_min' value must have nested ranges.
#
# * Variables with 'warn' greater than 'ok' must use a rising scale.
#
# * Variables with 'warn' less than 'ok' must use a falling scale.
#
sub eval_status {
    my ( $self, $args ) = @_;

    if ( 'HASH' eq ref $args->{rec_meta} && keys %{$args->{rec_meta}} ) {

        return $self->eval_discrete_status( $args )
            unless (    exists $args->{rec_meta}{ok}
                     or exists $args->{rec_meta}{ok_min} );    # not range data.

        return $self->eval_nested_status( $args)
            if exists $args->{rec_meta}{ok_min};

        return $self->eval_rising_status($args)
            if $args->{rec_meta}{warn} >= $args->{rec_meta}{ok};

        return $self->eval_falling_status($args)
            if $args->{rec_meta}{warn} <= $args->{rec_meta}{ok};
    }
    warn "Config file @{[$self->confpath()]}\n\tdoes not have an entry for '@{[$args->{tag}]}'.";
    return;
}

# ----------------------------------------------------------------------
# For each oid value, look up previous values and prepare other data
# to pass to the eval_status() routine for evaluation.
#
sub process_all_oids {
    my $self = shift;
    my ( $received, $target, $metadata ) = @_;

    my ( $info, $prev ) = ( $self->confdata, $self->prev );

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

# ----------------------------------------------------------------------
# Use SNMP to connect to a host.
#
sub snmp_connect {
    my $self = shift;
    my ( $metadata, $dbtables ) = @_;

    my $meta;

    @{$meta}{qw(name ip pw type)} = @{$metadata}{qw(name ip community type)};

    my ( $session, $error )
        = Net::SNMP->session( -hostname  => $meta->{ip},
                              -community => $meta->{pw},
                              -version   => 'snmpv2c', );
    if ( !defined $session ) {
        my $args = { table              => $dbtables->{other},
                     with_node_table_id => 'node_id',
                     args               => {
                               target            => $meta->{type},
                               value             => $meta->{name},
                               units             => '',
                               field             => 'Net::SNMP connect',
                               status            => 'CRISIS',
                               message_tag       => 'Net-SNMP connect failed',
                               message_arguments => "errormsg=" . $error,
                             }, };

        $self->insert_raw_record($args);

        $args->{target_type} = $args->{target};
        delete $args->{args}{target};

        $args->{target_name}  = $meta->{name};
        $args->{target_extra} = $meta->{ip};
        $args->{table}        = $dbtables->{alerts};
        $self->insert_raw_record($args);
        $self->summarize_status( 'CRISIS', 999 );
    }

    return ( $meta, $session );
}

# ----------------------------------------------------------------------
# For each target specified in the config file, connect using snmp and
# send out a query. Report failure to connect, or failure in the
# query. If query succeeds, pass the values to process_all_oids() for
# processing.
#
sub query_target {
    my $self = shift;

    $self->clear_summary();

    my $info = $self->confdata;
TARGET:    # For each snmp target (1, 2, ... ) in the config file
    for my $target ( grep {/\A\d+\z/} keys %$info ) {
        my $metadata = $info->{$target};
        my $dbtables = $info->{db}{table};

        # Connect to the target, if possible.
        #
        my ( $meta_out, $session )
            = $self->snmp_connect( $metadata, $dbtables );
        next TARGET unless $session;

        # Fetch list of data
        #
        my $received
            = $session->get_request( -varbindlist => $metadata->{oids}, );

        if ( not defined $received ) {
            my $args = { table              => $dbtables->{other},
                         with_node_table_id => 'node_id',
                         args               => {
                             target      => $meta_out->{type},
                             value       => $meta_out->{name},
                             units       => '',
                             field       => 'Net::SNMP fetch data',
                             status      => 'CRISIS',
                             message_tag => 'Net-SNMP->get_request() failed',
                             message_arguments => "errormsg=" . $session->error,
                         }, };

            $self->insert_raw_record($args);

            $args->{target_type} = $args->{target};
            delete $args->{args}{target};

            $args->{target_name}  = $meta_out->{name};
            $args->{target_extra} = $meta_out->{ip};
            $args->{table}        = $dbtables->{alerts};
            $self->insert_raw_record($args);

            $self->summarize_status( 'CRISIS', 999 );

            next TARGET;
        }
        $session->close;

        # Evaluate and classify data
        #
        $self->process_all_oids( $received, $target, $metadata );
    }
    $self->process_summary();
    return;
}

# ----------------------------------------------------------------------
# Prior to entering the main loop, if there exists a database
# alternate file, load the data into the database if possible.
#
sub prep_for_loop {
    my $self = shift;

    $self->dbs->load_db_from_files;
}

# ----------------------------------------------------------------------
# Once each loop, run the query_target method to read and process
# values.
#
sub loop_core {
    my $self = shift;

    $self->query_target;

    return;
}

# ======================================================================
1;
__END__

# ======================================================================
# POD

=head1 NAME

     AN::SNMP::APC_UPS.pm - package to handle SNMP queries to the APC_UPS
                          - base class for all agent processes

=head1 VERSION

This document describes AN::SNMP::APC_UPS.pm version 1.0.0

=head1 SYNOPSIS

    use AN::SNMP::APC_UPS;
    my $agent = AN::SNMP::APC_UPS(  );
    $agent->run();

=head1 DESCRIPTION

This module implements the AN::SNMP::APC_UPS class which runs an agent
to query American Power Corporation UPS power supplies through
SNMP. It acts as a base class for all agents, and particularly for any
that communicate via SNMP.

=head1 METHODS

The document B<Writing_an_agent_by_extending_existing_perl_classes> in
the Docs directory describes writing an agent based on this base class.

=head1 DEPENDENCIES

=over 4

=item B<Carp> I<core>

Report errors as originating at the call site.

=item B<Data::Dumper>

Display data structures in debug messages.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<Net::SNMP>

Provides access to SNMP data.

=item B<version> I<core since 5.9.0>

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
