package AN::SystemCheck;
use parent 'AN::Scanner';

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Carp;
use Const::Fast;
use English '-no_match_vars';
use File::Basename;
use File::Spec::Functions 'catdir';
use File::Temp 'tempfile';
use POSIX 'strftime';
use Time::HiRes qw( time alarm sleep);
use Time::Local;

use AN::Alerts;
use AN::Common;
use AN::DBS;
use AN::FlagFile;
use AN::Listener;
use AN::MonitorAgent;
use AN::Unix;

# ======================================================================
# CLASS ATTRIBUTES
#

const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

use Class::Tiny qw( check index reference ssh ipmi names root tmpfiles
                    cluster_conf etc_hosts
                  ), {tmpdir => sub {'/var/tmp/systemcheck'},
};


# ======================================================================
# CONSTANTS
#

const my $COLON => q{:};
const my $COMMA => q{,};
const my $COMMASPACE => q{, };
const my $SPACE => q{ };
const my $STAR  => q{*};
const my $PIPE  => q{|};

const my $READ_PROC  => q{-|};
const my $WRITE_PROC => q{|-};

const my $CMD 
    => {
	# --------------------------------------------------
	# Cluster test commands.
	#
	CLUSTAT          => '"clustat"',
	HOSTNAME         =>  '"uname -n"',
	JOIN_CLUSTER     => '"/etc/init.d/cman start && /etc/init.d/rgmanager start"',
	PANIC_CRASH_HOST => '"echo c > /proc/sysrq-trigger"',
	TAIL_MSGS_FILE   => 'ssh -o ServerAliveInterval=2 host "tail -f /var/log/messages"',
	# --------------------------------------------------
	# PDU test commands.
	#
	GET_CLUSTER_CONF => 'cat /etc/cluster/cluster.conf',
	GET_ETC_HOSTS    => 'cat /etc/hosts',
};
const my $FILE => { CRASHLOG =>   'crashlog_IP_XXXX',
		    MSGTAILLOG => 'msgtaillog_IP_XXXX',
};
# ======================================================================
# GLOBAL
#
local $LIST_SEPARATOR = $COMMASPACE;

# ======================================================================
# METHODS
#
sub separator { my $self = shift; say "\n", '-' x72, "\n"; };
# ----------------------------------------------------------------------
#
sub prepare_for_tests {
    my $self = shift;
    
    $self->ssh( [ split $COMMA, $self->confdata->{servers}{ssh} ]);
    $self->ipmi( [ split $COMMA, $self->confdata->{servers}{ipmi} ]);

    mkdir $self->tmpdir
	unless -d $self->tmpdir;

}
# ----------------------------------------------------------------------
#
sub generic_ssh_test {
    my $self = shift;
    my ( $hosts, $remote_cmd ) = @_;

    my (%results, @failed);
    for my $host ( @$hosts ) {
     	my @cmd = ( '/usr/bin/ssh', $host, $remote_cmd );
     	say "Running '@cmd'" if $self->verbose;
     	my $response = `@cmd`;
     	chomp $response;
     	say "Got response '$response'" if $self->verbose;
     	if ( length $response ) {
     	    $results{$host} = $response;
     	} else {
     	    push @failed, $host;
     	}
     	say '' if $self->verbose;;
    }
    return (\%results, \@failed );;
}
# ----------------------------------------------------------------------
#
sub test_ssh_to_hosts {
    my $self = shift;

    my ( $results, $failed )
    	= $self->generic_ssh_test( $self->ssh, $CMD->{HOSTNAME});

    $self->names( $results );
    return unless @$failed;

    my $plural = @$failed > 1 ? 'hosts' : 'host';
    die "Failed to connect to $plural @$failed.\n";
}
# ----------------------------------------------------------------------
#
sub test_host_clustat {
    my $self = shift;

    my ( $results, $failed )
     	= $self->generic_ssh_test( $self->ssh, $CMD->{CLUSTAT});

    return unless @$failed;

    ( $results, $failed )
     	= $self->generic_ssh_test( $failed, $CMD->{JOIN_CLUSTER});
    return unless @$failed;
    
    my $plural = @$failed > 1 ? 'Hosts' : 'Host';
    die "$plural not running sman /sgmanager: @$failed.\n";
}
# ----------------------------------------------------------------------
#
sub launch_msg_tail_on_host {
    my $self = shift;
    my ( $host ) = @_;

    my $logfile = $self->logdir . '/messages.' . $host;
#    my $logfile = $self->logdir . '/tmp/messages.' . $host;
    my $cmd = '(/usr/bin/ssh root@'
	. $host
	. ' "tail -f /var/log/messages" ) > '
	. $logfile;
    say "Running '$cmd'" if $self->verbose;
    my $bg = AN::Unix::new_bg_process( $cmd );
    
    return ( $bg, $logfile );
}
# ----------------------------------------------------------------------
sub crash_host {
    my $self = shift;
    my ( $host ) = @_;

    my $cmd = qq{ssh  -o ServerAliveInterval=2 root\@$host "echo c > /proc/sysrq-trigger" };
    say "Running '$cmd'" if $self->verbose;
    system( $cmd );

    return;
}
# ----------------------------------------------------------------------
#
sub check_log_file_for_fenced_host {
    my $self = shift;
    my ( $logfile ) = @_;

    my $crashed_at = time;
    my (@lines, $has_crashed, $is_fenced);

  LINE:
    while ( time() - $crashed_at < 300 ) {
	@lines = split "\n", `cat $logfile`;
	$has_crashed = grep {/Connection closed/} @lines;

	$is_fenced = grep { /rgmanager/ && /Restricted domain unavailable/
	                  } @lines;
	last LINE if $is_fenced;
    }
    return ($has_crashed, $is_fenced, @lines );
}
# ----------------------------------------------------------------------
#
sub wait_for_pingable {
    my $self = shift;
    my ( $host ) = @_;

    my ( $start, $host_is_pingable, $i ) = (time(), 0, 0);
    say "Pinging $host -> ", scalar localtime;
  PING:
    while ( time() - $start < 600 ) {
	$host_is_pingable = $self->ping_host_once($host);
	last PING if $host_is_pingable;
	sleep 10;
	$i++;
	say "Pinging $host -> ", scalar localtime
	    if 0 == $i % 4;	# approx 1 minute, including ping timeout
    }
    return $host_is_pingable;
}
# ----------------------------------------------------------------------
#
sub ping_host_once {
    my $self = shift;
    my ( $host ) = @_;

    my $cmd = "/bin/ping -c 1 $host";
    say "Running '$cmd'." if $self->verbose >= 2;
    my $response = `$cmd`;

    my ( $loss ) = ($response =~ m{\s (\d+)% \s packet \s loss}xms);
    return $loss == 0;
}
# ----------------------------------------------------------------------
#
sub test_panic_crash {
    my $self = shift;

    my ($i, $N) = (1, scalar @{$self->ssh} )
;
    for my $host ( @{$self->ssh} ) {
	# monitor /var/log/messages on other host
	#
	my ($otherhost) = grep { $_ ne $host } @{$self->ssh};
	my ($bg_task, $logfile) = $self->launch_msg_tail_on_host( $otherhost );

	# crash the selected hosts
	#
	say "Crashing host $host at ", scalar localtime;
	$self->crash_host( $host );
	say "Job done at ", scalar localtime;

	my ( $has_crashed, $is_fenced, @lines )
	    = $self->check_log_file_for_fenced_host( $logfile );

	if ( $is_fenced ) {
	    say "$otherhost /var/log/messages reports $host fenced.";
	    say "\n", join( "\n", @lines), "\n";
	    say "Waiting for reboot, at ", scalar localtime;
	    $bg_task = undef;   # kill bg task
	} else {
	    say "Timed out (5 min) waiting for $otherhost to detect $host crash.";
	    say "\n", join( "\n", @lines), "\n";
	    say "shutting down";
	    exit 1;
	}
	my ( $host_is_back ) = $self->wait_for_pingable( $host );
	if ( $host_is_back ) {
	    say "Host $host is pingable again, at ", scalar localtime;
	    say "Waiting 15 seconds, then restarting cman & rgmanager."
	} else {
	    die "Timed out (10 min) waiting for $host to become pingable.";
	    say "shutting down";
	    exit 1;
	}
	sleep 15;
	my ( $results, $failed )
	    = $self->generic_ssh_test( [$host], $CMD->{JOIN_CLUSTER});

	die "Host $host not running cman / rgmanager '@$failed'.\n"
	    if 'ARRAY' eq ref $failed
	    && @$failed;

	if ( $i++ < $N ) {	# Don't bother on last time around.
	    say "Waiting 15 seconds for rcman and rgmanager to settle in";
	    sleep 15;
	    say "\n", ':' x 72, "\n";
	}
    }
    return;
}
# ......................................................................
sub run_cluster_tests() {
    my $self = shift;
    
    say "Starting Cluster tests.";

    $self->test_ssh_to_hosts; $self->separator;
    $self->test_host_clustat; $self->separator;
    $self->test_panic_crash; $self->separator;

    say "Cluster tests complete.";
    return;
}
sub init_cfg_for_parse_cluster_conf {
    my $self = shift;

    my $cfg = {cgi => {cluster => 'this_cluster'},
               clusters => {'this_cluster' => {nodes => [sort values %{$self->names}]}}};
    $cfg->{node}{$self->names->{$_}}{get_host_from_cluster_conf} = 1
	for  @{$self->ssh};

    return $cfg;
}
# ----------------------------------------------------------------------
#
sub load_cluster_conf_file {
    my $self = shift;

    my ( $results, $failed )
	= $self->generic_ssh_test( $self->ssh, $CMD->{GET_CLUSTER_CONF});

    die "Failed to read cluster.conf file: @$failed."
	if @$failed;

    my $cfg = $self->init_cfg_for_parse_cluster_conf;

  CONF:
    for my $host ( @{$self->ssh} ) {
	my @conf_lines = split "\n", $results->{$host};
	my $name = $self->names->{$host};
	AN::Cluster::parse_cluster_conf( $cfg, $name, \@conf_lines);
	if ( exists $cfg->{failoverdomain}
	     && exists $cfg->{fence}
	     && exists $cfg->{node}
	     && exists $cfg->{vm}
	    ) {
	    $self->cluster_conf($cfg);
	    last CONF;
	}
    }
    return;
}
# ----------------------------------------------------------------------
#
sub load_etc_hosts {
    my $self = shift;

    my ( $results, $failed )
	= $self->generic_ssh_test( $self->ssh, $CMD->{GET_ETC_HOSTS});

    die "Failed to read /etc/hosts file: @$failed."
	if @$failed;

    my $lines = $results->{$self->ssh->[0]};
    $lines =~ s{\t}{ }xmsg;
    my %etc_hosts;
  LINE:
    for my $line ( split "\n", $lines ) {
	next LINE unless $line;

	$line = (split /#/, $line)[0]; # Discard comments
	next LINE unless $line =~ m{\w};

	my @words = split /\s+/, $line;
	my $ip = shift @words;

	if ( exists $etc_hosts{$ip} ) {
	    push @{$etc_hosts{$ip}}, @words;
	} else {
	    $etc_hosts{$ip} = \@words;
	}
	for my $word ( @words ) {
	    $etc_hosts{$word} ||= $ip; # Don't overwrite existswing values
	}
    }
    $self->etc_hosts(\%etc_hosts);

    return;
}
# ----------------------------------------------------------------------
# 
sub run_pdu_tests {
    my $self = shift;

    say "Starting PDU tests.";
    $self->test_ssh_to_hosts
	unless $self->names;

    $self->load_cluster_conf_file;
    $self->load_etc_hosts;
    $self->separator;
    for my $host ( @{$self->ssh} ) {
	my $name = $self->names->{$host};
	my @cmd = $self->cluster_conf->{node}{$name}{fence_method}{'1:pdu'}{device};
	for my $cmd ( @cmds ) {
	    my $pdu= ( $cmd =~ m{-a \s (\S+) \s -n}xms );
	    my $ip = $self->etc_hosts->{$pdu};
	    $cmd =~ s{$pdu}{$ip};
	    say "Turning off PDU for $name: '$cmd'."
		if $self->verbose;
	}
	say "hello";
    }
    say "PDU tests complete.";
    return;
}

# ----------------------------------------------------------------------
# There won't be scanAgents appearing and disappearing during the
# system check. So instead of running the scan once each loop, just do
# it once, beforehand. Then enter the timed loop until all the tests
# are complete, at which point the shutdown flag is set.
#
sub run {
    my $self = shift;

    $self->connect_dbs();
    
#    my $changes = $self->scan_for_agents();
#    $self->handle_changes($changes) if $changes;

    $self->prepare_for_tests();
#    $self->run_cluster_tests();
    $self->run_pdu_tests();

    $self->finalize_node_table_status();

    return;
}

# ----------------------------------------------------------------------
# Run a loop once every $options->{rate} seconds, to check
# $options->{agentdir} for new files, ignoring files with a suffix
# listed in $options->{ignore}
#
sub run_timed_loop_forever {
    my $self = shift;

    local $LIST_SEPARATOR = $COMMA;

    my ( $start_time, $end_time ) = ( time, $self->calculate_end_epoch );
    my ($now) = time;

    # loop until this time tomorrow
    #
    while ( $now < $end_time
            && !$self->shutdown() ) {
        $self->loop_core();
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
        (   $now > $end_time                    ? 'reached end time'
          : 'restart' eq $self->shutdown()      ? 'shutdown flag set'
          : 'end of tests' eq $self->shutdown() ? 'Finished testing!'
          :                                       'unknown reason' );
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
    $scanner->run();

=head1 DESCRIPTION

This module provides the Scanner program implementation. It monitors a
HA system to ensure the system is working properly.

=head1 METHODS

An object of this class represents a scanner object. Once an instance
is created, the run() method is invoked. Subclasses can define their
own interpretation of loop_core to define it's own interpretation of
what should happen once each loop iteration.

=head1 DEPENDENCIES

=over 4

=item B<Carp>

Complain about user errors as if they occur in caller, rather than in
the module.

=item B<Const::Fast>

Provides fast constants.

=item B<English>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename>

Parses paths and file suffixes.

=item B<File::Spec::Functions>

Portably perform operations on file names.

=item B<POSIX> 

Provide date-time formatting routine C<strftime>.

=item B<Time::HiRes>

sub-second precision version of time, alarm & sleep,

=item B<Time::Local>

Parse hours, minutes, seconds to an epoch value. 

=item B<version> I<core>

Parses version strings.


=item B<AN::Alerts>
=item B<AN::Common>
=item B<AN::DBS>
=item B<AN::FlagFile>
=item B<AN::Listener>
=item B<AN::MonitorAgent>
=item B<AN::Unix>

Utilites and components for scanCore system.

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
