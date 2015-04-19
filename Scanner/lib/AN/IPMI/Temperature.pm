package AN::IPMI::Temperature;

use parent 'AN::SNMP::APC_UPS';    # inherit from AN::SNMP_APC_UPS

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use Const::Fast;
use Data::Dumper;

# ======================================================================
# CLASS ATTRIBUTES
#
use Class::Tiny qw( confpath confdata prev );

# ======================================================================
# CONSTANTS
#
const my $SLASH => q{/};

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Initialize set of 'previous' values.
#
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

# ----------------------------------------------------------------------
# Process the records retrieved from the IPMI system. Prepare the
# records for analysis and then pass them on to
# AN::SNMP::APC_UPS::eval_status().
#
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

# ----------------------------------------------------------------------
# Fetch data from IPMI system and pass it on for processing.
#
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

# ----------------------------------------------------------------------
# Top-level program, invoked from loop_core().
#
sub query_target {
    my $self = shift;

    $self->clear_summary();
    my $received = $self->ipmi_request();
    $self->process_all_ipmi($received) if @$received;
    $self->process_summary();

    return;
}

# ======================================================================
1;
__END__

# ======================================================================
# POD

=head1 NAME

     AN::IPMI::Temperature.pm - package to handle IPMI temperature values

=head1 VERSION

This document describes AN::IPMI::Temperature.pm version 1.0.0

=head1 SYNOPSIS

    use AN::IPMI::Temperature;
    my $agent = AN::IPMI::Temperature->new( );
    $agent->run();

=head1 DESCRIPTION

This module implements the AN::IPMI::Temperature class which runs an agent
to query IPMI Controllers using the ipmi program.

=head1 METHODS

There are no API methods exported by the system

=head1 DEPENDENCIES

=over 4

=item B<Const::Fast>

Provide fast constants.

=item B<Data::Dumper> I<core>

Display data structures in debug messages.

=item B<version> I<core>

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

Tom Legrady       -  tom@alteeve.ca     November 2014

=cut

# End of File
# ======================================================================

