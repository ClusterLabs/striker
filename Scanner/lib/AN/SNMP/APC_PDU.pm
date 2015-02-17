package AN::SNMP::APC_PDU;

use parent 'AN::SNMP::APC_UPS';    # inherit from AN::SNMP_APC_UPS

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

use Class::Tiny qw( outlet_names );

# ======================================================================
# CONSTANTS
#

# ......................................................................
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

sub BUILD {
    my $self = shift;

    # Don't run for sub-classes.
    #
    return unless ref $self eq __PACKAGE__;

    $self->normalize_global_and_local_config_data;
    $self->prep_reverse_cache_and_prev_values;

    return;
}
# ----------------------------------------------------------------------
# 
sub eval_discrete_status {
    my $self = shift;
    my ($args) = @_;

    state $is_digit = { 0 => 1, 1 => 1, 2 => 1, 3 => 1, 4 => 1,
                        5 => 1, 6 => 1, 7 => 1, 8 => 1, 9 => 1 };
    my $msg = { args => '', tag => '', label => '', newval => '',
                status => '' };
    $args->{prev_status} ||= '';


    if ( $args->{tag} =~ m{\Aoutlet_is_on_(\d)} ) {
        my $num = $1;
        $msg->{newval} = $args->{rec_meta}{values}{ $args->{value} } || '';
        my $unchanged = ( $is_digit->{ $args->{value} }
                          && $is_digit->{ $args->{prev_value}}
                          ? $args->{value} == $args->{prev_value}
                          : $msg->{newval} eq $args->{prev_value}
            );
        if ( $unchanged ) {
            $msg->{status} = 'OK'
        }
        else {
            $msg->{status} = 'WARNING';
            $msg->{tag} = 'PDU Outlet status changed';
            my $from = ( $is_digit->{ $args->{prev_value} }
                         ? $args->{rec_meta}{values}{ $args->{prev_value} }
                         : $args->{prev_value}
                );
	    my $pdu = $args->{metadata}{name};
            $msg->{args} = "pdu=$pdu;outlet=$num;from=$from;to=$msg->{newval}";
        }
    }

    $self->compare_sides_or_report_record( $args, $msg );

    return ( $msg->{status}, $msg->{newval} || $args->{value} );
}

# ----------------------------------------------------------------------
#
sub process_all_oids {
    my $self = shift;
    my ( $received, $target, $metadata ) = @_;

    my ( $info, $prev ) = ( $self->confdata, $self->prev );
    state $first = 1;

    for my $oid ( keys %$received ) {
        my ( $value, $tag ) = ( $received->{$oid}, $metadata->{roid}{$oid} );
        my $rec_meta = $metadata->{$tag};
        my $label = $rec_meta->{label} || $tag;

        my $prev_value  = $prev->{$target}{$tag}{value}  || $value;
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
    $first = 0;
}

1;

# ======================================================================
# End of File.
