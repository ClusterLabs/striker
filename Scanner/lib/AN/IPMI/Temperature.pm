package AN::IPMI::Temperature;

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
use Time::HiRes qw(time alarm sleep);

use AN::Common;
use AN::MonitorAgent;
use AN::FlagFile;
use AN::Unix;
use AN::DBS;

use Class::Tiny qw( confpath confdata prev );

# ======================================================================
# CONSTANTS
#
const my $SLASH => q{/};

# ......................................................................
#

sub BUILD {
    my $self = shift;

    return unless ref $self eq __PACKAGE__;
    return;
}

sub init_prev {
    my $self = shift;
    my ($received) = @_;

    my $prev = {};

RECOD:
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
    $prev->{summary}{status} = 'OK';
    $prev->{summary}{value}  = 0;

    return $prev;
}

sub process_all_ipmi {
    my $self = shift;
    my ($received) = @_;

    state $i = 1;
    state $verbose = ( ( $self->verbose && $self->verbose >= 2 )
                       || grep {/process_all_ipmi/} $ENV{VERBOSE} );

    my ( $info, $prev ) = ( $self->confdata, $self->prev );

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
            if grep {/process_all_ipmi/} ( $ENV{VERBOSE} || 0 );

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
    $self->prev($prev);
    return;
}

sub ipmi_request {
    my $self = shift;

    state $cmd = $self->bindir . $SLASH . $self->confdata()->{query};
    say "ipmi cmd is $cmd" if grep {/ipmi_query/} $ENV{VERBOSE};

    # read bottom to top ...
    #
    my @data = (
        map { [ split '\s*\|\s*' ] }    # split line into space-trimmed fields
            grep { $_ !~ /Device Present/ }    # Ignore text 'Ambient' messages.

            grep { $_ !~ /Limit Not Exceeded/ }
            grep { -1 == index $_, '| ns' } # ignore lines w/ 'ns' for no sensor
            split "\n",    # split paragraph into lines
        `$cmd`             # invoke ipmit tool for sdr temperatures
               );

    # less than 5 lines is an error message rather than real data
    #
    if ( not @data
         || 5 >= @data ) {

        my $info = $self->confdata;
        my $args = { table              => $info->{db}{table}{other},
                     with_node_table_id => 'node_id',
                     args               => {
                            target_name  => $info->{host},
                            target_type  => $info->{type},
                            target_extra => $info->{ip},
                            value        => $info->{host},
                            units        => '',
                            field        => 'IPMI fetch data',
                            status       => 'CRISIS',
                            message_tag => 'AN-IPMI-Temp ipmi_request() failed',
                            message_arguments => "errormsg=" . join "\n",
                            @data,
                     }, };

        $self->insert_raw_record($args);

        $args->{table} = $info->{db}{table}{Alerts};
        $self->insert_raw_record($args);
    }

    return \@data;
}

sub query_target {
    my $self = shift;

    $self->clear_summary();
    my $received = $self->ipmi_request();
    $self->process_all_ipmi($received) if @$received;
    $self->process_summary();

    return;
}

1;

# ======================================================================
# End of File.
