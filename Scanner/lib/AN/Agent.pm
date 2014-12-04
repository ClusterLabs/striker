package AN::Agent;

use base 'AN::Scanner';		# inherit from AN::Scanner

# _Perl_
use warnings;
use strict;
use 5.014;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

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
const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];
const my $UNASSIGNED => 'not yet specified';

# ......................................................................
#

sub _init {
    my $self = shift;
    my (@args) = @_;
    
    $self->datatable_name( $UNASSIGNED );
    $self->datatable_schema( $UNASSIGNED );

    if ( scalar @args > 1 ) {
        for my $i ( 0 .. $#args ) {
            my ( $k, $v ) = ( $args[$i], $args[ $i + 1 ] );
            $self->{$k} = $v;
        }
    }
    elsif ( 'HASH' eq ref $args[0] ) {
        @{$self}{ keys %{ $args[0] } } = values %{ $args[0] };
    }
    croak(q{Missing Scanner constructor arg 'rate'.})
        unless $self->rate();

    return;
}

sub dump_metadata {
    my $self = shift;

    my $dbs_dump = $self->dbs()->dump_metadata;
    my $metadata = <<"EODUMP";
name=$PROG
$dbs_dump
datatable_name:@{[$self->datatable_name]}
datatable_schema:@{[$self->datatable_schema]}

EODUMP

    return $metadata;
}

sub run {
    my $self = shift;

    # initialize.
    #
    $self->connect_dbs();
    $self->create_marker_file( AN::FlagFile::get_tag('METADATA'),
                               $self->dump_metadata );

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
