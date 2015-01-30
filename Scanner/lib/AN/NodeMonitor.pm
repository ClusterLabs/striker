package AN::NodeMonitor;

use parent 'AN::SNMP::APC_UPS';    # inherit from AN::SNMP_APC_UPS

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION            = '0.0.1';

use Const::Fast;
use English '-no_match_vars';
use Carp;
use Data::Dumper;
use File::Basename;

use AN::Cluster;

use Class::Tiny qw( healthfile host status first_ping_at sent_last_timeout_at
                    elapsed),
                  {cache => sub {$_[0]->read_cache_file();},
                  };

# ======================================================================
# CONSTANTS
#
const my $PROG       => ( fileparse($PROGRAM_NAME) )[0];
const my $SLASH      => q{/};
const my %STATUS2MSG => ( on  => 'host has power',
                          off => 'host down'
                        );

# ......................................................................
#
sub insert_raw_record {
    my $self = shift;
    my ($args) = @_;

    $self->dbs->insert_raw_record( $args );
    return;
}

# ......................................................................
#
sub healthfile_status_shows_ok {
    my $self            = shift;

    state $file         = $self->healthfile();

    return unless -r $file;

    open my $hf, '<', $file
        or carp "Could not open healthfile '$file'.";
    my (@line)          = grep { /health/ } split "\n", <$hf>;
    my $status          = (split ' = ', $line[0])[1];
    close $hf;

    return $status eq 'ok';
}
# ......................................................................
#
sub read_cache_file {
    my $self            = shift;

    say "Reading cache file";
    my $args            = { cgi  => {cluster       => $self->confdata->{cluster}},
                 path   => {striker_cache => $self->confdata->{striker_cache},
                            log => '/dev/null',
                 },};
    AN::Cluster::read_node_cache( $args, $self->host );
    delete $args->{cgi}; delete $args->{path}; delete $args->{handles};

    $self->cache( $args );
    
    return $args;
}
# ......................................................................
#
sub get_ip {
    my $self = shift;

    my $ipmi_host = $self->host() . '.ipmi';
    my $ip = $self->cache()->{node}{$self->host}{hosts}{$ipmi_host};
    die( "Host @{[$self->host()]} not found in cache file ",
         Data::Dumper::Dumper([$self->cache()]), "\n"
        ) unless $ip;

    return $ip->{ip};
}
# ......................................................................
#
sub ipmi_power_utility {
    my $self    = shift;
    my ( $cmd ) = @_;

    my $shell = join ' ', ($self->bindir . $SLASH . $self->confdata->{ipmitool},
                           '-h', $self->get_ip, '-c', $cmd);

    say "Running : $shell" if $self->verbose;
    my $lines = `$shell 2>&1`;
    say join "\nIPMITOOL ==> ", split "\n", $lines
        if $self->verbose;
    return $lines
}
# ......................................................................
#
sub fetch_host_power_status {
    my $self = shift;

    my $lines = $self->ipmi_power_utility( 'status' );
    my ($status) = $lines =~ m{Chassis  \s Power \s is \s (\w+)}xms;
    return $status;
}
# ......................................................................
#
sub verify_host_down {
    my $self = shift;

    my $status = $self->fetch_host_power_status;
    my $msg = exists $STATUS2MSG{$status} && $STATUS2MSG{$status};

    $self->status($msg)
        if $msg;
    return;
}
# ......................................................................
#
sub relaunch_host {
    my $self            = shift;

    my $lines = $self->ipmi_power_utility( 'on' );
    my $status = ($lines =~ m{Chassis Power Control: ([\w+\\]+)\z}xms);

    $self->status( 'host  has power')
        if $status eq 'Up/On';
    return;
}
# ......................................................................
#
# When we're trying to ping the host, if we haven't reached
# max_seconds_for_reboot ( let's call it MAX) yet, then keep looping
# around and trying every MAX seconds. 
#
# If we have timed out, save the current_time in sent_last_timeout_at,
# and send an alert saying how long the reboot been going on. In the
# future, use the time since sent_last_timeout_at to determine when to
# timeout again. Every MAX seconds, send a new alert.
#
sub has_timed_out {
    my $self = shift;

    state $max = $self->confdata->{max_seconds_for_reboot};
    my $elapsed = time - $self->first_ping_at;

    if (  $elapsed > $max ) {
        if ( (! $self->sent_last_timeout_at ) 
             || time - $self->sent_last_timeout_at > $max ) {
            $self->sent_last_timeout_at( time );
            $self->elapsed($elapsed);
            return;    # timed out, return total elapsed time.
        }
        else {
            $self->elapsed(0);
            return;             # false, keep running
        }
    }
}
# ......................................................................
#
sub ping_host {
    my $self = shift;

    my $shell = $self->confdata->{ping} . " -c 1 " . $self->get_ip;

    say "Running : $shell" if $self->verbose;
    my @lines = split "\n", `$shell`;
   
    say join "\nPing -> ", @lines if $self->verbose;
    my ($num) = ($lines[4] =~ m{([\d.]+)% \s packet \s loss}xms);

    return $num == 0;
}
# ......................................................................
#
# There are three possibilities:
#     1) The host is still coming up. In this case, loop around for
#     another 30 seconds and try again.
#     2) The host is pingable. Report success. Yippee!
#     3) We've run out of time, and the host isn't up. Boo! Hiss!
#     Report failure. but keep trying, send message every N minutes.
#
sub ping_host_until_OK_or_timeout {
    my $self            = shift;

    
    $self->first_ping_at( time ) unless $self->first_ping_at;

    my $pingable        = $self->ping_host;

    if ( $pingable ) {
        $self->status('host is pingable');
    }
    else {
        $self->status( 'reboot timed out' )
            if $self->has_timed_out;
    }
    return;
}
# ......................................................................
#
sub report_host_status_to_boss {
    my $self = shift;


    my $host = $self->host;
    my $status
        = ( $self->status_host_is_pingable ? 'OK'
            : $self->status_host_timed_out ? 'TIMEOUT'
            :                                'unknown'
        );
    if ( $status eq 'unknown' ) {
        carp "unknown status '$status'.";
        $status = 'DEAD';
    }

    my $msg_args = "host=$host";
    $msg_args .= "elapsed=" . $self->elapsed
        if $self->elapsed;
    my $record = { table => $self->confdata->{db}{table}{alerts},
                   with_node_table_id => 'node_id',
                   args               => {
                       value             => $self->host,
                       field             => 'node server',
                       status            => $status,
                       message_tag       => 'NODE_SERVER_STATUS',
                       message_arguments => $msg_args,
                       target_name       => 'node monitor',
                       target_type       => $host,
                   },
    };
    $self->insert_raw_record($record);

    say "set alert ", Data::Dumper::Dumper([$record]);
    return;
}
# ......................................................................
#
sub status_host_is_down {
    my $self            = shift;
    return $self->status eq 'host down';
}
# ......................................................................
#
sub status_host_has_power {
    my $self            = shift;
    return $self->status eq 'host has power';
}
# ......................................................................
#
sub status_host_is_pingable {
    my $self            = shift;
    return $self->status eq 'host is pingable';
}
# ......................................................................
#
sub status_host_timed_out {
    my $self            = shift;
    return $self->status eq 'reboot timed out';
}
# ......................................................................
#

sub loop_core {
    my $self = shift;

    if ( $self->healthfile_status_shows_ok ) {
        $self->verify_host_down
            unless $self->status;
        $self->relaunch_host
	    if $self->status_host_is_down;
	$self->ping_host_until_OK_or_timeout
	    if $self->status_host_has_power;
    
        if ($self->status_host_is_pingable 
            || $self->status_host_timed_out  ) {
            $self->report_host_status_to_boss;
            exit;               # All done, either success or failure!
        }
    }
    return;
}

1;

# ======================================================================
# End of File.
