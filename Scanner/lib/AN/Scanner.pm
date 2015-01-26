package AN::Scanner;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use Const::Fast;
use Cwd;
use File::Basename;
use File::Spec::Functions 'catdir';
use FileHandle;
use FindBin qw($Bin);
use IO::Select;
use POSIX 'strftime';
use List::MoreUtils;
use Time::HiRes qw( time alarm sleep);
use Time::Local;

use AN::Alerts;
use AN::Common;
use AN::DBS;
use AN::FlagFile;
use AN::Listener;
use AN::MonitorAgent;
use AN::Unix;

const my $PROG                  => ( fileparse($PROGRAM_NAME) )[0];

# is_recent == 0              is_running == 0       is_running == 1
const my @OLD_PROC_MSG => ( [ 'OLD_PROCESS_CRASH',  'OLD_PROCESS_STALLED'],
# is_recent == 1              is_running == 0       is_running == 1
			    [  'OLD_PROCESS_RECENT_CRASH', undef],
    );

use subs 'alert_num';    # manually define accessor.

use Class::Tiny qw( 
    agentdir commandlineargs confdata    confpath     db_name  db_type
    dbconf   dbs         duration     flagfile from
    ignore
    logdir   max_retries monitoragent msg_dir  port
    rate     run_until   smtp     verbose
    ), {
    agents => sub { [] },
    max_loops_unrefreshed => sub { 10 },
    shutdown => sub { 0 },
    alerts => sub {
        my $self = shift;
        AN::Alerts->new(
                         { agents => { pid      => $PID,
                                       program  => $PROG,
                                       hostname => AN::Unix::hostname(),
                                       msg_dir  => $self->msg_dir,
                                     },
                           owner => $self
                         } );
    },
    alert_num             => sub {'a'},
    processes             => sub { [] },
    seen                  => sub { return {}; },
    sumweight             => sub {0}
       };

# ----------------------------------------------------------------------
# METHODS
#
sub interactive {
    my $self = shift;
    return -t STDIN && -t STDOUT;
}

sub begin_logging {
    my $self= shift;
    close STDOUT;
    my $today = strftime '%F_%T', localtime;
    my $filename = $self->logdir . '/log.' . $PROG . '.' . $today;
    open STDOUT, '>', $filename;
    open STDERR, '>&STDOUT';		# '>&', is followed by a file handle.
}

sub restart {
    my $self = shift;

    $self->shutdown( 'restart' );
    return;
}

sub restart_scanCore_now {
    my $self = shift;

    my @cmd = ($PROGRAM_NAME, @{$self->commandlineargs});
    say "Restarting with cmd '@cmd'.";
    exec @cmd 
	or die "Failed: $!.\n";
}

sub read_configuration_file {
    my $self = shift;

    return unless $self->confpath;
    my %cfg = ( path => { config_file => $self->confpath } );
    AN::Common::read_configuration_file( \%cfg );

    $self->confdata( $cfg{ $cfg{name} } );
    return;
}

sub BUILD {
    my $self = shift;
    my ($args) = @_;

    $ENV{VERBOSE} ||= '';    # set default to avoid undef variable.
    $self->read_configuration_file;

    return unless ref $self eq __PACKAGE__;    # skip BUILD for descendents

    croak(q{Missing Scanner constructor arg 'agentdir'.})
        unless $self->agentdir();
    croak(q{Missing Scanner constructor arg 'rate'.})
        unless $self->rate();

    if ( $args->{ignorelist} ) {
	$self->ignore({});
	$self->ignore->{$_} = 1 for @{$args->{ignorelist}};
    }
    my @files = split ' ', $self->confdata->{ignorefile}
        if exists $self->confdata->{ignorefile};


    $self->monitoragent(
        AN::MonitorAgent->new(
            {  core       => $self,
               rate       => $self->rate(),
               agentdir   => $self->agentdir(),
               duration   => $self->duration,
               verbose    => $self->verbose(),
	       ignorefile => \@files,
            } ) );
    return;
}

sub alert_num {    # Return current value, increment to new value.
    my $self = shift;

    return $self->{alert_id}++;
}

# ======================================================================
# CONSTANTS
#
const my $COLON => q{:};
const my $COMMA => q{,};
const my $SPACE => q{ };
const my $STAR  => q{*};
const my $PIPE  => q{|};

const my $READ_PROC  => q{-|};
const my $WRITE_PROC => q{|-};

const my $EP_TIME_FMT => '%8.3f ms elapsed;  %8.3f ms pending';

const my $DB_NODE_TABLE       => 'node';
const my $PROC_STATUS_NEW     => 'pre_run';
const my $PROC_STATUS_RUNNING => 'running';
const my $PROC_STATUS_HALTED  => 'halted';

const my $HOURS_IN_A_DAY      => 24;
const my $MINUTES_IN_AN_HOUR  => 60;
const my $SECONDS_IN_A_MINUTE => 60;
const my $SECONDS_IN_A_DAY =>
    ( $HOURS_IN_A_DAY * $MINUTES_IN_AN_HOUR * $SECONDS_IN_A_MINUTE );

const my $RUN     => 'run';
const my $EXIT_OK => 'ok to exit';

const my @NEW_AGENT_ARGS =>
    qw( -o meta-data -f xlogdirx --dbconf xdbconfx -log --verbose );

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

sub add_agents {
    my $self = shift;
    my (@values) = @_;

    push @{ $self->agents }, @values;
    return;
}

sub drop_agents {
    my $self = shift;
    my (@values) = @_;

    my $re = join '|', map { '\b' . $_ . '\b' } @values;
    $self->agents( [ grep { $_->{filename} !~ $re } @{ $self->agents() } ] );
    return;
}

sub process_id {
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

    my $args = { dir     => $self->logdir,
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
    return $file_age
        && $file_age < $self->rate * $self->max_loops_unrefreshed;
}

sub create_marker_file {
    my $self = shift;
    my ( $tag, $data ) = @_;

    $self->flagfile()->create_marker_file( $tag, $data );
}

sub touch_marker_file {
    my $self = shift;

    $self->flagfile()->touch_marker_file();
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

sub tell_db_Im_dying {
    my $self = shift;

    $self->dbs()->tell_db_Im_dying();
    return;
}

sub fetch_alert_listeners {
    my $self = shift;

    return $self->dbs()->fetch_alert_listeners($self);
}

sub ok_to_exit {
    my $self = shift;
    my ($status) = @_;

    return $status eq $EXIT_OK;
}

sub set_alert {
    my $self = shift;

    $self->alerts()->set_alert(@_);
}

sub clear_alert {
    my $self = shift;

    $self->alerts()->clear_alert(@_);
    return;
}

sub handle_alerts {
    my $self = shift;

    $self->alerts()->handle_alerts(@_);
    $self->reset_summary_weight;
    return;
}

sub check_for_previous_instance {
    my $self = shift;

    $self->create_flagfile();

    # Old process exited cleanly, take over. Return early.
    if ( !$self->old_pid_file_exists() ) {
	say "Previous scanner exited cleanly; taking over.";
	return $RUN;
    }

    my ( $is_recent, $is_running ) = ( $self->pid_file_is_recent || 0,
				       $self->pid_file_process_is_running || 0);

    # Old process is running and updating pid file. Return early.
    if ($is_recent && $is_running) {
	say "A scanner process is already running; exiting";
	return $EXIT_OK;
    }


    # Old process exited recently without proper cleanup

    my $tag = $OLD_PROC_MSG[$is_recent][$is_running];
    $self->set_alert( $self->alert_num(), $PID, 'pidfile check',
                      '', '', AN::Alerts::DEBUG(), $tag, '' )
        if $is_recent && !$is_running;

    # Old process has stalled; running but not updating.
    $self->set_alert( $self->alert_num(), $PID, 'pidfile check',
                      '', '', AN::Alerts::DEBUG(), $tag, '' )
        if !$is_recent && $is_running;

    # old process exited some time ago without proper cleanup
    $self->set_alert( $self->alert_num(), $PID, 'pidfile check',
                      '', '', AN::Alerts::DEBUG(), $tag, '' )
        if !$is_recent && !$is_running;

    say "Replacing defective previous scanner: ", $tag;

    return $RUN;
}

sub connect_dbs {
    my $self = shift;
    my ($node_args) = @_;

    my $args = { path    => { config_file => $self->dbconf },
		 logdir  => $self->logdir,
		 verbose => $self->verbose,
		 owner   => $self,
               };
    $args->{current} = 0	# In scanner, activate only one DB at a time
	if __PACKAGE__ eq ref $self;
    $args->{node_args} = $node_args if $node_args;

    $self->dbs( AN::DBS->new($args) );
    return;
}

sub finalize_node_table_status {
    my $self = shift;

    $self->dbs()->finalize_node_table_status();
    return
}

sub process {
    my $self = shift;
    my ($fh) = @_;

    my ($text) = <$fh>;
    print "Read '$text'.\n";
    return;
}

sub launch_new_agents {
    my $self = shift;
    my ($new) = @_;

    local $LIST_SEPARATOR = $SPACE;
    state $args
        = [ map { $_ eq 'xdbconfx' ? $self->dbconf 
		: $_ eq 'xlogdirx'      ? $self->logdir 
		:                     $_;
	        } @NEW_AGENT_ARGS ];

    my @new_agents;
  AGENT:
    for my $agent (@$new) {
	next AGENT
	    if exists $self->ignore()->{$agent};
        my @args = ( catdir( $self->agentdir(), $agent ), @$args );
        say "launching: @args." if $self->verbose;
        my $pid = AN::Unix::new_bg_process(@args);
        $pid->{filename} = $agent;
        push @new_agents, $pid;
    }
    $self->add_agents(@new_agents);

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
    # 'deleted' data still ends up in $retval->[1]
    #
    push @$retval,
        (   @$new
          ? $self->launch_new_agents($new)
          : undef );

    if (@$deleted) {
        push @$retval, $self->drop_agents(@$new);
    }

    sleep 1;

    return $retval;
}

sub clean_up_metadata_files {
    my $self = shift;

    my $prefix = AN::FlagFile::get_tag('METADATA');
    my $dir    = $self->flagfile()->dir();

    for ( glob( catdir( $dir, ( $prefix . $STAR ) ) ) ) {
        say "deleting old file $_." if $self->verbose;
        unlink $_;
    }

    return;
}

sub run {
    my $self = shift;

    # initialize.
    #
    $self->clean_up_metadata_files();
    $self->connect_dbs();
    $self->create_pid_file();

    #    $self->handle_alerts();	# process any alerts from initialization stage

    # process until quitting time
    #
    $self->run_timed_loop_forever();

    # clean up and exit.
    #

    $self->finalize_node_table_status();
    $self->delete_pid_file();

    return;
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

    $end_epoch -= $self->rate;

    return $end_epoch;
}

sub print_loop_msg {
    my $self = shift;
    my ( $elapsed, $pending ) = @_;

    state $loop = 1;

    my $now = strftime '%T', localtime;
    my $extra_arg = sprintf $EP_TIME_FMT, 1000 * $elapsed, 1000 * $pending;
    say "$PROG loop $loop at @{[$now]} -> $extra_arg.";
    $loop++;

    say "\n" . '-' x 70 . "\n" if $self->verbose;

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

sub fetch_node_entries {
    my $self = shift;
    my ( $pids ) = shift;

    return unless $pids;
    my $nodes = $self->dbs->fetch_node_entries($pids);
    return $nodes;
}

sub wait_for_all_metadata_files {
    my $self = shift;
    my ( $additions, $tag ) = @_;

    my $N   = scalar @$additions;
    my $idx = 0;

    while ( $idx++ < 15 ) {
        my $files = $self->find_marker_files($tag);
        if (    'HASH' eq ref $files
             && $files->{$tag}
             && scalar @{ $files->{$tag} } ) {

            my $N_found = 0;
            for my $newfile ( @{ $files->{metadata} } ) {
                for my $addition (@$additions) {
                    $N_found++ if 0 < index $newfile, $addition->{filename};
                }
            }
            return $files if $N_found == $N;
        }
        sleep 1;
    }
    return;
}

sub update_process_node_id_entries {
    my $self = shift;

    state $verbose = grep { /debug node_id update/ } $ENV{VERBOSE};

    my @pids = sort {$a <=> $b }
                   map { $_->{db_data}->{pid}} @{$self->processes};
    my $nodes;
    do {
	$nodes = $self->fetch_node_entries( \@pids );
	say "update_process_node_id_entries got:\n",
            Data::Dumper::Dumper $nodes
	    if $verbose;;
    } until scalar keys %$nodes == scalar @pids;

    my $db_idx = $self->dbs->current + 1;

    for my $process ( @{$self->processes} ) {
	my $name = $process->{name};
	$process->{db_data}{$db_idx}{node_table_id} = $nodes->{$name}{node_id};
    }
}

sub handle_additions {
    my $self = shift;
    my ($additions) = @_;
    
    my $new_file_regex = join $PIPE, map {"$_->{filename}"} @{$additions};
    my $tag            = AN::FlagFile::get_tag('METADATA');
    my $files          = $self->wait_for_all_metadata_files( $additions, $tag );
    my $N              = 0;

FILEPATH:
    for my $filepath ( @{ $files->{$tag} } ) {
        next FILEPATH unless $filepath =~ m{($new_file_regex)};
        my $filename = $1;
        my %cfg = ( path => { config_file => $filepath } );
        AN::Common::read_configuration_file( \%cfg );

        my $process = { name => $filename, db_data => $cfg{db} };
        $self->add_processes($process);
        $self->alerts()->add_agent( $cfg{db}{pid},
                                    {  pid      => $cfg{db}{pid},
                                       program  => $cfg{db}{name},
                                       hostname => $cfg{db}{hostname},
                                       msg_dir  => $self->msg_dir,
                                    } );
	$N++;
    }
    $self->update_process_node_id_entries( scalar @$additions );
    return $N;
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

sub fetch_alert_data {
    my $self = shift;
    my ($proc_info) = @_;

    return $self->dbs()->fetch_alert_data($proc_info);
}

sub lookup_process {
    my $self = shift;
    my ($node_id) = @_;

    for my $process ( $self->processes ) {

    }
}

sub detect_status {
    my $self = shift;
    my ( $process, $db_record, ) = @_;

    say "Got a db_record with status @{[$db_record->{status}]}."
	 if $self->verbose;
    if ( $db_record->{status} eq 'OK' ) {
        say "Clearing @{[$process->{db_data}{pid}]}." if $self->verbose;
        $self->clear_alert( $process->{db_data}{pid} );
    }
    else {
        my @args = ( $db_record->id,
                     $process->{db_data}{pid},
                     $db_record->field,
                     $db_record->value,
                     $db_record->units,
                     $db_record->status,
                     $db_record->message_tag,
                     $db_record->message_arguements,
                     $db_record->target_name,
                     $db_record->target_type,
                     $db_record->target_extra,
                     { timestamp => $db_record->timestamp }, );
        say "Setting alert '"
            . $db_record->message_tag
            . "' in '"
            . $db_record->field
            . "' from $process->{db_data}{pid}."
            if $self->verbose;
        $self->set_alert(@args);
    }

    return;
}

sub process_summary_record {
    my $self = shift;
    my ( $process, $alert ) = @_;

    my $weighted
        = $self->confdata->{weight}{ $process->{name} }
        * ( $alert->{value} || 0 );
    $self->sumweight( $self->sumweight() + $weighted )
        if $weighted;
}

sub reset_summary_weight {
    my $self = shift;

    $self->sumweight(0);
}

sub check_if_process_needs_replacement {
    my $self = shift;
    my ( $replacement_processes, $process, $idx ) = @_;

    my $proc = AN::Unix::pid2process $process->{db_data}{pid};
    return;
}	

sub get_latest_user_intervention {
    my $self = shift;
    my ( $host ) = @_;

    my $intervention = $self->dbs->get_latest_user_intervention;
    return $intervention;
}

sub handle_dead_server {
    my $self = shift;
    my ( $alert ) = @_;

    my $intervention = $self->get_latest_user_intervention( $alert->value );

    
}

sub process_agent_data {
    my $self = shift;

    say "Scanner::process_agent_data()." if $self->verbose;
    my ($idx, %replacement_processes) = (0);

  PROCESS:
    for my $process ( @{ $self->processes } ) {
	my ($weight, $count);
        my $alerts = $self->fetch_alert_data($process);
	if ( ! 'ARRAY' eq ref $alerts ) {
	    $self->check_if_process_needs_replacement( \%replacement_processes,
						       $process, $idx );
	    next PROCESS;
	}
	my $allN   = scalar @$alerts;
        my $newN   = 0;

    ALERT:
        for my $alert (@$alerts) {
	    if ( $alert->{status} eq 'DEAD' ) {
		$self->handle_dead_server( $alert );
		next ALERT;
	    }

	    $weight += $alert->{value}
  	        if $alert->{field} eq 'summary'
		    and $alert->{age} < 1.5 * $self->rate;

	    $count++;
            $newN++;
            if ( $alert->{field} eq 'summary' ) {
		# prevent health from wobbling back and forth, make it
		# take a while to clear up to OK.
		#
		if ( 0 == $count ) {
		    say "Adding $weight to existing ", $self->sumweight
			if $self->verbose;
		    $self->sumweight( $self->sumweight + $weight )
		}
		next ALERT
		    if $self->seen->{ $alert->{id} }++;
                $self->process_summary_record( $process, $alert );
            }
            else {
                $self->detect_status( $process, $alert );
            }
	    $idx++;
        }
        say scalar localtime()
            . " Received $allN alerts for process $process->{name}, $newN of them new."
            if $self->verbose || grep {/\balertcount\b/} $ENV{VERBOSE} || '';
    }
    
    return;
}

# Things to do in the core for a scanner core object
#
sub loop_core {
    my $self = shift;

    state $verbose = grep {/seencount/} $ENV{VERBOSE} || '';

    my $changes = $self->scan_for_agents();
    $self->handle_changes($changes) if $changes;
    $self->process_agent_data( );
    $self->handle_alerts();

    if ($verbose) {
        say "Total number of distinct alerts seen: " . scalar length
            keys %{ $self->seen };
    }
    return;
}

# ......................................................................
# run a loop once every $options->{rate} seconds, to check $options->{agentdir}
# for new files, ignoring files with a suffix listed in $options->{ignore}
#
sub run_timed_loop_forever {
    my $self = shift;

    state $touch_file = ( __PACKAGE__ eq ref $self 
			      ? 'touch_pid_file'
			      : 'touch_marker_file'
	);
    local $LIST_SEPARATOR = $COMMA;

    my ( $start_time, $end_time ) = ( time, $self->calculate_end_epoch );
    my ($now) = time;

    # loop until this time tomorrow
    #
    while ( $now < $end_time
            && !$self->shutdown() ) {
        $self->loop_core();
        $self->$touch_file();
        my ($elapsed) = time() - $now;
        my $pending = $self->rate - $elapsed;
	say "Processing took a long time: $elapsed seconds is more than ",
	    "expected loop rate of @{[$self->rate]} seconds."
		if $pending < 0;

	$pending = 1 if $pending <= 0;

	$self->print_loop_msg( $elapsed, $pending )
            if $self->verbose;

        sleep $pending;

        $now = time;
    }
    say '$self->shutdown is ', $self->shutdown();
    say "At @{[strftime '%F_%T', localtime]} exiting run_timed_loop_forever() ", 
        (   $now > $end_time               ? 'reached end time'
	  : 'restart' eq $self->shutdown() ? 'shutdown flag set'
	  :                     'unknown reason'
	);
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
