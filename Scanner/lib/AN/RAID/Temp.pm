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

use Class::Tiny qw( raidconf raid prev controller_count );

# ======================================================================
# CONSTANTS
#
const my $DATATABLE_NAME => 'raid';
const my $PARENTDIR      => q{/../};

const my $SLASH => q{/};

# ......................................................................
#

sub read_configuration_file {
    my $self = shift;

    $self->raidconf(
              catdir( $self->path_to_configuration_files(), $self->raidconf ) );

    my %cfg = ( path => { config_file => $self->raidconf } );
    AN::Common::read_configuration_file( \%cfg );

    $self->raid( $cfg{raid} );
}

sub get_controller_count {
    my $self = shift;

    my $response = $self->raid_request;
    $response =~ m{Number of Controllers\s+=\s(\d)};

    return $1;
}

sub BUILD {
    my $self = shift;

    return unless ref $self eq __PACKAGE__;

    $ENV{VERBOSE} ||= '';    # set default to avoid undef variable.

    $self->read_configuration_file;
    $self->controller_count( $self->get_controller_count() );

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
                                      target   => $args->{metadata}{name},
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
                                      status       => $msg->{status},
                                      msg_tag      => $msg->{tag},
                                      msg_args     => $msg->{args},
                                      target_name  => $args->{metadata}{name},
                                      target_type  => $args->{metadata}{type},
                                      target_extra => $args->{metadata}{ip},
                                },
                              } );
    return;
}

sub init_prev {
    my $self = shift;
    my ($received) = @_;

    my $prev = {};

RECORD:
    for my $record (@$received) {
        my ( $tag, $value, $status ) = @{$record}[ 0, 4, 2 ];

        # Multiple records for 'Ambient', only care about first.
        #
        next RECORD if defined $prev->{$tag};

        # Extract numeric part if any.  Ambient temperature will be
        # greater than 20 C and other temps greater than ambient.
        #
        $value =~ s{([\d.]+).*}{$1};
        next RECORD unless $value > 20;

        @{ $prev->{$tag} }{qw(value status)} = ( $value, uc $status );
    }
    return $prev;
}

sub process_all_raid {
    my $self = shift;
    my ($received) = @_;

    state $i = 1;
    state $verbose = ( ( $self->verbose && $self->verbose >= 2 )
                       || grep {/process_all_raid/} $ENV{VERBOSE} );

    my ( $info, $prev ) = ( $self->raid, $self->prev );

    state $meta = { name => $info->{host},
                    ip   => $info->{ip},
                    type => $info->{type}, };

    $prev ||= $self->init_prev($received);
    for my $record (@$received) {
        my ( $tag, $value, $rawstatus ) = @{$record}[ 0, 4, 2 ];
        my $rec_meta = $info->{$tag};

        $value =~ s{([\d.]+)\s*.*}{$1};    # Discard text following a number

        my $prev_value  = $prev->{$tag}{value};
        my $prev_status = $prev->{$tag}{status};

        # Calculate status and message.
        #
        say Data::Dumper->Dump(
                                [ $i++, $tag, $value, $rec_meta,
                                  $prev_status, $prev_value, uc $rawstatus
                                ] )
            if grep {/process_all_raid/} ( $ENV{VERBOSE} || 0 );

        my $args = { tag         => $tag,
                     value       => $value,
                     rec_meta    => $rec_meta,
                     prev_status => $prev_status,
                     prev_value  => $prev_value,
                     metadata    => $meta };

        my ( $status, $newvalue ) = $self->eval_status($args);

        $prev->{$tag}{$tag}{value} = $newvalue || $value;
        $prev->{$tag}{$tag}{status} = $status;
    }
}

sub raid_request {
    my $self = shift;

    my (@args) = @_;

    my $cmd = getcwd() . $SLASH . $self->raid()->{query};
    $cmd .= " @args" if @args;
    say "raid cmd is $cmd" if grep {/raid_query/} $ENV{VERBOSE};

    my @data = `$cmd`;

    # less than 10 lines is an error message rather than real data
    #
    if ( not @data
         || 10 >= @data ) {

        my $info = $self->raid;
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
                             msg_tag => __PACKAGE__ . '::raid_request() failed',
                             msg_args => "errormsg=" . join "\n",
                             @data,
                     }, };

        $self->insert_raw_record($args);

        $args->{table} = $self->alerts_table_name;
        $self->insert_raw_record($args);
    }

    return \@data;
}

sub query_target {
    my $self = shift;

    my $received = $self->raid_request();
    $self->process_all_raid($received) if @$received;

    return;
}

1;

# ======================================================================
# End of File.
