package AN::Scanner;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;
use FileHandle;
use IO::Select;
use Time::Local;
use FindBin qw($Bin);

use Const::Fast;
use lib 'cgi-bin/lib';
use AN::Common;
use AN::MonitorAgent;
use AN::FlagFile;
use AN::Unix;
use AN::DBS;

# ======================================================================
# Object attributes.
#
const my @ATTRIBUTES => (
    qw( agentdir duration dbini db_type db_name port rate verbose 
        monitoragent flagfile _agents dbs max_loops_unrefreshed 
        run_until processes )
);

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
const my $COLON    => q{:};
const my $COMMA    => q{,};
const my $DOTSLASH => q{./};
const my $DOUBLE_QUOTE => q{"};
const my $NEWLINE  => qq{\n};
const my $SLASH    => q{/};
const my $SPACE    => q{ };
const my $PIPE     => q{|};

const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];
const my $READ_PROC  => q{-|};
const my $WRITE_PROC => q{|-};

const my $EP_TIME_FMT => '%8.3f:%8.3f mSec';    # elapsed:pending time format

const my $DB_NODE_TABLE       => 'node';
const my $PROC_STATUS_NEW     => 'pre_run';
const my $PROC_STATUS_RUNNING => 'running';
const my $PROC_STATUS_HALTED  => 'halted';

const my $MAX_LOOPS_UNREFRESHED => 10;
const my $HOURS_IN_A_DAY        => 24;
const my $MINUTES_IN_AN_HOUR    => 60;
const my $SECONDS_IN_A_MINUTE   => 60;
const my $SECONDS_IN_A_DAY =>
    ( $HOURS_IN_A_DAY * $MINUTES_IN_AN_HOUR * $SECONDS_IN_A_MINUTE );

const my $RUN     => 'run';
const my $EXIT_OK => 'ok to exit';

const my $NO_MSG_TAG       => 'set_alert() invoked with no message tag';
const my $INTRO_OTHER_ARGS => 'set_alert() invoked with additional args: ';

const my $OLD_PROCESS_RECENT_CRASH => 'old process crashed recently';
const my $OLD_PROCESS_STALLED      => 'old process stalled';
const my $OLD_PROCESS_CRASH        => 'old process crash';

const my $METADATA_DIR => '/tmp';
const my @NEW_AGENT_ARGS =>
    ( '-o', 'meta-data', '-f', $METADATA_DIR, '--dbini', 'xdbinix' );

const my $RUN_UNTIL_FMT_RE => qr{           # regex for 'run_until' data format
                                 \A         # beginning of string
                                 (\d{1,2})  # 1 or 2 digits for hours 0-23
                                 :	    # Literal colon
                                 (\d{2})    # 2 digits for minutes 0-59
                                 :	    # Literal colon
                                 (\d{2})    # 2 digits for seconds 0-59
                                 \z         # end of string
                                 }xms;

# ======================================================================
# Subroutines
#
# ......................................................................
# Standard constructor. In subclasses, 'inherit' this constructor, but
# write a new _init()
#
sub new {
    my ( $class, @args ) = @_;

    my $obj = bless {}, $class;
    $obj->_init(@args);

    return $obj;
}

# ......................................................................
#
sub copy_from_args_to_self {
    my $self = shift;
    my (@args) = @_;

    if ( scalar @args > 1 ) {
        for my $i ( 0 .. $#args ) {
            my ( $k, $v ) = ( $args[$i], $args[ $i + 1 ] );
            $self->{$k} = $v;
        }
    }
    elsif ( 'HASH' eq ref $args[0] ) {
        @{$self}{ keys %{ $args[0] } } = values %{ $args[0] };
    }
    return;
}

sub _init {
    my $self = shift;

    # default value;
    $self->max_loops_unrefreshed($MAX_LOOPS_UNREFRESHED);
    $self->_agents(   [] );
    $self->processes( [] );

    $self->copy_from_args_to_self(@_);

    croak(q{Missing Scanner constructor arg 'agentdir'.})
        unless $self->agentdir();
    croak(q{Missing Scanner constructor arg 'rate'.})
        unless $self->rate();

    $self->monitoragent(
        AN::MonitorAgent->new(
            {  core     => $self,
               rate     => $self->rate(),
               agentdir => $self->agentdir(),
               duration => $self->duration,
               verbose  => $self->verbose(),

            } ) );

    return;

}

sub DESTROY {
    my $self = shift;

    $self->dbs()->_halt_process();
}

sub run_until_data_is_valid {
    my ($value) = @_;

    # string must match regular expression and
    # numbers must fit ranges.
    return unless $value =~ m{$RUN_UNTIL_FMT_RE};

    return (    $1 >= 0
             && $1 < $HOURS_IN_A_DAY
             && $2 >= 0
             && $2 < $MINUTES_IN_AN_HOUR
             && $3 >= 0
             && $3 < $SECONDS_IN_A_MINUTE );
}

# ......................................................................
# Private Accessors
#
sub add_processes {
    my $self = shift;
    my (@value) = @_;

    push @{ $self->processes }, @value;
    return;
}

sub drop_processes {
    my $self = shift;
    my (@value) = @_;

    my $re = join '|', map { '\b' . $_ . '\b' } @value;
    $self->processes(
                     [ grep { ( keys %$_ ) !~ $re } @{ $self->processes() } ] );
    return;
}

sub _add_agents {
    my $self = shift;
    my (@values) = @_;

    push @{ $self->_agents }, @values;
    return;
}

sub _drop_agents {
    my $self = shift;
    my (@values) = @_;

    my $re = join '|', map { '\b' . $_ . '\b' } @values;
    $self->_agents( [ grep { $_->{filename} !~ $re } @{ $self->_agents() } ] );
    return;
}

sub _process_id {
    my $self = shift;
    my ( $dbh, $new_value ) = @_;

    die( __PACKAGE__ . " method _process_id( \$dbh, \$id ) not enough args." )
        if scalar @_ <= 1;
    die( __PACKAGE__ . " method _process_id( \$dbh, \$id ) too many args." )
        if scalar @_ > 3;

    return $self->{process_id}{$dbh} if not defined $new_value;

    $self->{process_id}{$dbh} = $new_value;
    return;
}

# ......................................................................
# Private Methods
#
sub create_flagfile {
    my $self = shift;
    my ($data) = @_;

    my $hostname = AN::Unix::hostname('-short');

    my $args = { dir     => $METADATA_DIR,
                 pidfile => "${hostname}-${PROG}", };
    $args->{data} = $data if $data;    # otherwise use default.

    $self->flagfile( AN::FlagFile->new($args) );
}

sub create_pid_file {
    my $self = shift;

    $self->flagfile()->create_pid_file();
}

sub delete_pid_file {
    my $self = shift;

    $self->flagfile()->delete_pid_file();
}

sub touch_pid_file {
    my $self = shift;

    $self->flagfile()->touch_pid_file();
}

sub old_pid_file_exists {
    my $self = shift;

    return $self->flagfile()->old_pid_file_exists();
}

sub pid_file_is_recent {
    my $self = shift;

    my $file_age = $self->flagfile()->old_pid_file_age();
    return $file_age < $self->rate * $self->max_loops_unrefreshed;
}

sub create_marker_file {
    my $self = shift;
    my ( $tag, $data ) = @_;

    $self->flagfile()->create_marker_file( $tag, $data );
}

# Look up whether the process id specified in the pidfile refers to
# a running process, make sure it's the same name as we are. Otherwise
# could be another process re-using that pid.
#
sub pid_file_process_is_running {
    my $self = shift;

    my (%old_pid_data) = map { my ( $k, $v ) = split ':'; $k => $v }
        split "\n", $self->flagfile()->old_pid_file_data();

    # look up by pid, output only the command file, no header line.
    my $previous = AN::Unix::pid2process( $old_pid_data{pid} );

    # If a process with the specified pid is found, it's name is in $previous.
    # Make sure it has the right name.
    return $previous && $previous eq $PROG;
}

# return true if less than 5 minutes until midnight, otherwise return
# false.  In fact, the 'true' value is an arrayref containing the
# current hour, minute and second time, to avoid a second call to
# localtime.
sub almost_quitting_time {
    my $self = shift;

    my ( $sec, $min, $hr ) = (localtime)[ 0, 1, 2 ];

    return [ $hr, $min, $sec ]
        if $hr == $self->quit_hr && $min > ( $self->quit_min - 5 );
    return;
}

# Given the current seconds, minutes, hour, time remaining until
# midnight is (60 - current minute) minutes plus (60 - current
# seconds) seconds. Multiple the minutes by 60 to convert to seconds.
# But we want to wake up 30 seconds beforehand, to tell old job to go
# away. So subtract 30 from the calculation.
sub sleep_until_quitting_time {
    my ($now) = @_;

    my $remaining = ( 60 - $now->[0] ) + ( 60 * ( 60 - $now->[1] ) ) - 30;
    sleep $remaining;
    return;
}

sub tell_old_job_to_quit {
    my $self = shift;
    my ($old_pid) = @_;

    kill 'USR1', $old_pid;

    $self->monitor_old_pid_for_exit($old_pid);
    return;
}

# ......................................................................
# Methods
#

sub ok_to_exit {
    my $self = shift;
    my ($status) = @_;

    return $status eq $EXIT_OK;
}

sub new_alert_loop {
    say "Scanner->new_alert_loop() not implemented yet.";
}

sub set_alert {
    my $self = shift;
    my ($tag, $arg, @others) = @_;

    my $msg_fmt = $tag || $NO_MSG_TAG;

    # splitting 'undef' generates warning, so use empty string if necessary.
    #
    $arg = '' unless defined $arg;
    my @args = grep {/\w/} split $DOUBLE_QUOTE, $arg || '';

    my $formatted  = @args ? sprintf $msg_fmt, @args
	: $msg_fmt;
    $formatted .= $NEWLINE . $INTRO_OTHER_ARGS . (@others)
	if @others;

    carp "SET ALERT: $formatted";
}

sub clear_alert {

    carp 'clear_alert not yet implemented.';
}

sub handle_alerts {

    carp 'handle_alerts not yet implemented';
}

sub check_for_previous_instance {
    my $self = shift;

    $self->create_flagfile();

    # Old process exited cleanly, take over. Return early.
    return $RUN if !$self->old_pid_file_exists();

    my ( $is_recent, $is_running )
        = ( $self->pid_file_is_recent, $self->pid_file_process_is_running );

    # Old process is running and updating pid file. Return early.
    return $EXIT_OK
        if $is_recent && $is_running;

    # Old process exited recently without proper cleanup
    $self->set_alert($OLD_PROCESS_RECENT_CRASH)
        if $is_recent && !$is_running;

    # Old process has stalled; running but not updating.
    $self->set_alert($OLD_PROCESS_STALLED)
        if !$is_recent && $is_running;

    # old process exited some time ago without proper cleanup
    $self->set_alert($OLD_PROCESS_CRASH)
        if !$is_recent && !$is_running;

    return $RUN;
}

sub connect_dbs {
    my $self = shift;

    $self->dbs( AN::DBS->new( { path => { config_file => $self->dbini } } ) );
    return;
}

sub disconnect_dbs {
    die "scanner::disconnect_dbs() not implemented yet.";
}

sub launch {
    my $self = shift;
    my ($scanner) = @_;

    # my $fullpath = $self->agentdir() . $SLASH . $scanner;
    # croak "scanner '$fullpath' not found.\n"
    #   unless -e $fullpath;
    # croak "scanner '$fullpath' not executable.\n"
    #   unless -x _;

    # #    open my $fh, $READ_PROC, $fullpath
    # open my $fh, '|-', "$fullpath --verbose --rate 3"
    #   or croak "Could not AN::Scanner::launch( '$scanner' )";
    # my $status = $self->_add_fh_to_list($fh);
    return;
}

sub process {
    my $self = shift;
    my ($fh) = @_;

    my ($text) = <$fh>;
    print "Read '$text'.\n";
    return;
}

sub _launch_new_agents {
    my $self = shift;
    my ($new) = @_;

    local $LIST_SEPARATOR = $SPACE;
    state $args
        = [ map { $_ eq 'xdbinix' ? $self->dbini : $_; } @NEW_AGENT_ARGS ];

    my @new_agents;
    for my $agent (@$new) {
        my @args = ( $self->agentdir() . '/' . $agent, @$args );
        say "launching: @args." if $self->verbose;
        my $pid = AN::Unix::new_bg_process(@args);
        $pid->{filename} = $agent;
        push @new_agents, $pid;
    }
    $self->_add_agents(@new_agents);

    return \@new_agents;
}

sub scan_for_agents {
    my $self = shift;

    my ( $new, $deleted ) = $self->monitoragent()->scan_files();

    say "scan @{[time]} [@{$new}], [@{$deleted}]."
        if $self->verbose()
        or @{$new}
        or @{$deleted};

    my $retval = [];

    # If there are new agents, store its data in $retval->[0]
    # otherwise fill $retval->[0] with a false value, so that the
    # 'deleted' data still ends up in $retval->[1]/
    #
    push @$retval,
        (   @$new
          ? $self->_launch_new_agents($new)
          : undef );

    if (@$deleted) {
        push @$retval, $self->_drop_agents(@$new);
    }
    return $retval;
}

sub clean_up_running_agents {
    die "scanner::clean_up_running_agents() not implemented yet.";
}

sub run {
    my $self = shift;

    # initialize.
    #
    $self->connect_dbs();
    $self->create_pid_file();

    # process until quitting time
    #
    $self->run_timed_loop_forever();

    # clean up and exit.
    #
    $self->clean_up_running_agents();
    $self->disconnect_dbs();
    $self->delete_pid_file();
}

# ......................................................................
# If the current time is between 00:00:00 and the specified quitting
# time, quitting time is today; between quitting time and 23:59:59 + 1
# second, quitting time is tomorrow.
#
# Adding 24 hours worth of seconds to the current time will result in
# some time tomorrow. Use the day, month year from today or tomorrow,
# as appropriate, with the quitting time hour, minute and second to
# determine the future quitting.
#
# Subtract 1 loop duration and shut down at the end of the loop.
#
sub calculate_end_epoch {
    my $self = shift;

    my ( $sec, $min, $hour, $day, $mon, $year ) = localtime;
    my ( $quit_hr, $quit_min, $quit_sec ) = split $COLON, $self->run_until();

    my $tomorrow = (        $hour > $quit_hr
                         || ( $hour == $quit_hr && $min > $quit_min )
                         || (    $hour == $quit_hr
                              && $min == $quit_min
                              && $sec > $quit_sec ) );

    ( $day, $mon, $year )
        = ( localtime( time() + $SECONDS_IN_A_DAY ) )[ 3, 4, 5 ]
        if $tomorrow;

    my $end_epoch
        = timelocal( $quit_sec, $quit_min, $quit_hr, $day, $mon, $year );

    $end_epoch -= $self->rate * $MAX_LOOPS_UNREFRESHED;

    return $end_epoch;
}

sub print_loop_msg {
    my ( $elapsed, $pending ) = @_;

    state $loop = 1;
    my $extra_arg = sprintf $EP_TIME_FMT, 1000 * $elapsed, 1000 * $pending;
    say "$PROG loop $loop at @{[time]} $extra_arg.";
    $loop++;

    return;
}

sub find_marker_files {
    my $self = shift;

    return $self->flagfile()->find_marker_files(@_);
}

sub handle_deletions {
    my $self = shift;
    my ($deletions) = @_;

    $self->drop_processes(@$deletions)
        if $deletions;
    return;
}

sub parse_schema_into_hash {
    my ( $process, $filename ) = @_;

    my @lines = split $COMMA, $process->{$filename}{datatable_schema};
    my @fields;
    for my $line (@lines) {
        my @words = split $SPACE, $line;
        my %field = ( name => $words[0],
                      type => $words[1],
                      rest => join ' ',
                      @words[ 2 .. $#words ] );
        push @fields, \%field;
    }
    $process->{schema} = [@fields];
    return;
}

sub handle_additions {
    my $self = shift;
    my ($additions) = @_;

    my $new_file_regex = join $PIPE, map {"$_->{filename}"} @{$additions};
    my $tag            = AN::FlagFile::get_tag('METADATA');
    my $files          = $self->find_marker_files($tag);

FILEPATH:
    for my $filepath ( @{ $files->{$tag} } ) {
        next FILEPATH unless $filepath =~ m{($new_file_regex)};
        my $filename = $1;
        my %cfg = ( path => { config_file => $filepath } );
        AN::Common::read_configuration_file( \%cfg );

        my $process = { $filename => $cfg{db} };
        parse_schema_into_hash( $process, $filename );
        $self->add_processes($process);
    }
    return;
}

sub handle_changes {
    my $self = shift;
    my ($changes) = @_;

    $self->handle_additions( $changes->[0] )
        if $changes->[0];

    $self->handle_deletions( $changes->[1] )
        if $changes->[1];

    return;
}

sub fetch_agent_data {
    my $self = shift;
    my ($proc_info) = @_;

    return $self->dbs()->fetch_agent_data($proc_info);
}

sub detect_status {
    my $self = shift;
    my ( $process, $db_data ) = @_;

    my $db_records = $db_data->{data};
    my $first = 1;
    my $can_clear_alert;
  RECORD:
    for my $idx ( sort {$b <=> $a } keys %$db_records ) {
	if ( $first ) {
	    $first = 0;
	    if( $db_records->{$idx}{status} eq 'OK' ) {
		# Check previous record to see if there was an alert
		# condition.
		#
		$can_clear_alert = 1;
	    }
	    else {
		# set DEBUG / WARNING / CRISIS alert to send alerts.
		#
		my ( $alert_msg_tag, $alert_msg_args)
		    = ( @{$db_records->{$idx}}{qw(msg_tag msg_args)});
		$self->set_alert( $alert_msg_tag, $alert_msg_args );
		last RECORD;
	    }
	}

	if( $db_records->{$idx}{status} ne 'OK' ) {
	    $self->clear_alert( {process => $process,
				 record => $db_records->{$idx},
				});
	}

    }
    return;
}

sub process_agent_data {
    my $self = shift;

    my $status = [];
    for my $process ( @{ $self->processes } ) {
        my $agent_data = $self->fetch_agent_data($process);
	for my $db_data ( @{ $agent_data } ) {
		push $status, $self->detect_status( $process, $db_data );
	}
    }
    return $status;
}


# Things to do in the core for a scanner core object
#
sub loop_core {
    my $self = shift;

    $self->new_alert_loop();
    my $changes = $self->scan_for_agents();
    $self->handle_changes($changes) if $changes;
    $self->process_agent_data();
    $self->handle_alerts();

    $self->touch_pid_file;

}

# ......................................................................
# run a loop once every $options->{rate} seconds, to check $options->{agentdir}
# for new files, ignoring files with a suffix listed in $options->{ignore}
#
sub run_timed_loop_forever {
    my $self = shift;

    local $LIST_SEPARATOR = $COMMA;

    my ( $start_time, $end_time ) = ( time, $self->calculate_end_epoch );
    my ($now) = $start_time;

    while ( $now < $end_time ) {    # loop until this time tomorrow
                                    #        $self->read_process_all_agents();

        $self->loop_core();

        my ($elapsed) = time() - $now;
        my $pending = $self->rate - $elapsed;
        $pending = 1 if $pending < 0;    # dont wait negative duration.

        print_loop_msg( $elapsed, $pending )
            if $self->verbose;

        return
            if $now + $elapsed > $end_time;  # exit before sleep if out of time.

        sleep $pending;
        $now = time;
    }
    return;
}

# ----------------------------------------------------------------------
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     Scanner.pm - System monitoring loop

=head1 VERSION

This document describes Scanner.pm version 0.0.1

=head1 SYNOPSIS

    use AN::Scanner;
    my $scanner = AN::Scanner->new();


=head1 DESCRIPTION

This module provides the Scanner program implementation. It monitors a
HA system to ensure the system is working properly.

=head1 METHODS

An object of this class represents a scanner object.

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<agentdir>

The directory that is scanned for scanning plug-ins.

=item B<rate>

How often the loop should scan.

=back


=back

=head1 DEPENDENCIES

=over 4

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<version> I<core since 5.9.0>

Parses version strings.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<FileHandle> I<code>

Provides access to FileHandle / IO::* attributes.

=item B<FindBin> I<core>

Determine which directory contains the current program.

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
## Please see file perltidy.ERR
## Please see file perltidy.ERR
