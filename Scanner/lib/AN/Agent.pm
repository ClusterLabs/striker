package AN::Agent;

use base 'AN::Scanner';    # inherit from AN::Scanner

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;
use Cwd;

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

use Class::Tiny qw( datatable_name alerts_table_name dbconf );

# ======================================================================
# CONSTANTS
#
const my $DUMP_PREFIX => q{db::};
const my $SEPARATOR   => q{::};
const my $NEWLINE     => qq{\n};

const my $PROG              => ( fileparse($PROGRAM_NAME) )[0];
const my $DATATABLE_NAME    => 'agent_data';
const my $ALERTS_TABLE_NAME => 'alerts';
const my $HOSTNAME          => AN::Unix::hostname('-short');
const my $NOT_WORDCHAR      => qr{\W};
const my $UNDERSCORE        => q{_};

# ......................................................................
#

sub path_to_configuration_files {

    return getcwd();
}

sub BUILD {
    my $self = shift;

    $self->datatable_name($DATATABLE_NAME) unless $self->datatable_name;
    $self->alerts_table_name($ALERTS_TABLE_NAME)
        unless $self->alerts_table_name;

    croak(q{Missing Scanner constructor arg 'rate'.})
        unless $self->rate();

    $self->dbconf( catdir( path_to_configuration_files(), $self->dbconf ) );
    return;
}

sub non_blank_lines {
    my ($str) = @_;

    # Split the string into lines, Accept any lines which have
    # non-blank characters.  Join lines back together into a
    # single 'paragraph'.
    #
    return join q{ }, grep {/\S/} split $NEWLINE, $str;
}

sub dump_metadata {
    my $self = shift;

    my @node_ids = $self->dbs()->node_id( $DUMP_PREFIX, $SEPARATOR );
    my $node_ids_str = join "\n", @node_ids;

    my $metadata = <<"EODUMP";
${DUMP_PREFIX}name=$PROG
${DUMP_PREFIX}pid=$PID
${DUMP_PREFIX}hostname=$HOSTNAME
${DUMP_PREFIX}datatable_name=@{[$self->alerts_table_name]}
$node_ids_str
EODUMP

    return $metadata;
}

sub insert_raw_record {
    my $self = shift;
    my ( $args ) = @_;

    $self->dbs()->insert_raw_record($args);
}

sub generate_random_record {
    my $self = shift;

    state $first = 1;
    my $value = ( int rand(1000) ) / 10;
    my $status = (   $first || rand(100) > 66.0 ? 'DEBUG'
                   : $value > 90 ? 'CRISIS'
                   : $value > 80 ? 'WARNING'
                   :               'OK' );
    my $msg_tag = (   $first == 1          ? "$PROG first record"
                    : $status eq 'DEBUG'   ? "$PROG debug msg"
                    : $status eq 'WARNING' ? "$PROG warning msg"
                    : $status eq 'CRISIS'  ? "$PROG crisis msg"
                    :                        '' );
    my $msg_args = '';

    say scalar localtime(), ": $PROG -> $status, $msg_tag"
        if $self->verbose;

    my $args = {value    => $value,
		units    => 'a num',
		field    => 'random values',
		status   => $status,
		msg_tag  => $msg_tag,
		msg_args => $msg_args,
    };
    $self->insert_raw_record( { table              => $self->datatable_name,
				with_node_table_id => 'node_id',
				args               => $args });
			      
    $self->insert_raw_record( { table              => $self->alerts_table_name,
				with_node_table_id => 'node_id',
				args               => $args,
			      }
	) if $status ne 'OK';
			      
    $first = 0;
    return;
}

sub loop_core {
    my $self = shift;

    $self->generate_random_record();
}

sub run {
    my $self = shift;

    my ($node_args) = @_;

    # initialize.
    #
    $self->connect_dbs($node_args);
    $self->create_marker_file( AN::FlagFile::get_tag('METADATA'),
                               $self->dump_metadata );

    # process until quitting time
    #
    $self->run_timed_loop_forever();

    # clean up and exit.
    #
    $self->clean_up_running_agents();
    $self->disconnect_dbs();
    $self->delete_marker_file( AN::FlagFile::get_tag('METADATA') );
}

1;

# ======================================================================
# End of File.
