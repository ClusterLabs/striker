package AN::Agent;

use base 'AN::Scanner';		# inherit from AN::Scanner

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

use FindBin qw($Bin);
use Const::Fast;

use lib 'cgi-bin/lib';
use AN::Common;
use AN::MonitorAgent;
use AN::FlagFile;
use AN::Unix;
use AN::DBS;

# ======================================================================
# Object attributes. - Already has attributes of a scanner, plus folling
#
const my @ATTRIBUTES => (qw( datatable_name datatable_schema ) );

# Create an accessor routine for each attribute. The creation of the
# accessor is simply magic, no need to understand.
#
# 1 - Without 'no strict refs', perl would complain about modifying
# namespace.
#
# 2 - Update the namespace for this module by creating a subroutine
# with the name of the attribute.
#
# 3 - 'set attribute' functionality: When the accessor is called,
# extract the 'self' object. If there is an additional argument - the
# accessor was invoked as $obj->attr($value) - then assign the
# argument to the object attribute.
#
# 4 - 'get attribute' functionality: Return the value of the attribute.
#
for my $attr (@ATTRIBUTES) {
    no strict 'refs';    # Only within this loop, allow creating subs
    *{ __PACKAGE__ . '::' . $attr } = sub {
	my $self = shift;
	if (@_) { $self->{$attr} = shift; }
	return $self->{$attr};
    }
}
# ======================================================================
# CONSTANTS
#
const my $DUMP_PREFIX => q{db::};
const my $NEWLINE => qq{\n};
const my $SLASH   => q{/};

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

sub _init {
    my $self = shift;
    my (@args) = @_;
    
    # avoid characters that DB dislikes in table name
    #
    my $name = $DATATABLE_NAME;
    $name =~ s{$NOT_WORDCHAR}{$UNDERSCORE};
    $self->datatable_name( $name );
    
    $self->datatable_schema( $DATATABLE_SCHEMA );

    $self->copy_from_args_to_self( @_ );

    croak(q{Missing Scanner constructor arg 'rate'.})
        unless $self->rate();

    $self->dbini( getcwd() . $SLASH . $self->dbini );
    return;
}
sub non_blank_lines {
    my ( $str ) = @_;

    # split the string into lines
    # accept any lines which have non-blank characters
    # join lines back together into a 'paragraph'
    #
    return join q{ }, grep {/\S/} split $NEWLINE, $str;
}
sub dump_metadata {
    my $self = shift;

    my $dbs_dump = $self->dbs()->dump_metadata;
    my ($schema) = non_blank_lines $self->datatable_schema;

    my $metadata = <<"EODUMP";
${DUMP_PREFIX}name=$PROG
$dbs_dump
${DUMP_PREFIX}datatable_name=@{[$self->datatable_name]}
${DUMP_PREFIX}datatable_schema="$schema"
EODUMP

    return $metadata;
}

# delegate to DBS object
#
sub create_db_table {
    my $self = shift;

    $self->dbs()->create_db_table( $self->datatable_name, $self->datatable_schema );
}

sub insert_raw_record {
    my $self = shift;
    my ( $value, $status ) = @_;

    $self->dbs()->insert_raw_record(
                                     { table => $self->datatable_name,
                                       with_node_table_id => 'node_id',
                                       args               => {
                                                 value  => int $value,
                                                 status => $status,
                                               },
                                     } );
}

sub generate_random_record {
    my $self = shift;
    
    state $first = 1;
    my $value = (int rand(1000)) / 10;
    my $status = ( $first || rand(100) > 99.0 ? 'DEBUG'
		   : $value == 99.9           ? 'CRISIS'
		   : $value > 99.0            ? 'WARNING'
		   :                            'OK'
	);

    $self->insert_raw_record( $value, $status );
    $first = 0;
    return;
}

sub loop_core {
    my $self = shift;

    $self->generate_random_record();
}

sub run {
    my $self = shift;

    # initialize.
    #
    $self->connect_dbs();
    $self->create_marker_file( AN::FlagFile::get_tag('METADATA'),
                               $self->dump_metadata );
    
    die "$PROG has problems creating/using table $self->datatable_name.\n"
	unless $self->create_db_table();
    # process until quitting time
    #
    $self->run_timed_loop_forever();

    # clean up and exit.
    #
    $self->clean_up_running_agents();
    $self->disconnect_dbs();
    $self->delete_marker_file(AN::FlagFile::get_tag('METADATA'));
}

1;
# ======================================================================
# End of File.
