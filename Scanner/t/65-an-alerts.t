#!/usr/bin/env perl

package owner;
   sub new {
     return bless { class => 'owner' }, 'owner';
   }

   sub max_retries {
     return 10;
   }

   sub timestamp {
     my $self = shift;
     $self->{timestamp} = $_[0] if @_;

     return $self->{timestamp};
   }
   sub status {
     my $self = shift;
     $self->{status} = $_[0] if @_;

     return $self->{status};
   }
   sub message_tag {
     my $self = shift;
     $self->{message_tag} = $_[0] if @_;

     return $self->{message_tag};
   }

package main;

# _Perl_
use warnings;
use strict;
use 5.010;

use Clone 'clone';
use Data::Dumper;
use File::Basename;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;
#use Test::Output;
use English '-no_match_vars';
use Sys::Hostname;

use AN::Alerts;
use AN::Unix;

# ----------------------------------------------------------------------
# Utility routines
#

# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {

    my $alerts = AN::Alerts->new(
	{ agents => { pid      => $PID,
		      program  => '65-an-alert.t',
		      hostname => AN::Unix::hostname(),
		      msg_dir  => 'Config/ipmi.conf',
	  },
	  owner => owner->new(),
	} );


    isa_ok( $alerts, 'AN::Alerts', 'obj' );
    return $alerts;
}

sub test_is_hash_ref {
    my $self = shift;

    is( AN::Alerts::is_hash_ref( {} ),      1, 'is_hash_ref() detects hashref');
    is( AN::Alerts::is_hash_ref( [] ),     '', 'is_hash_ref() avoids arrayref');
    is( AN::Alerts::is_hash_ref( '' ),     '', 'is_hash_ref() avoids string');
    is( AN::Alerts::is_hash_ref( 1 ),      '', 'is_hash_ref() avoids number');
    is( AN::Alerts::is_hash_ref( sub {} ), '', 'is_hash_ref() avoids coderef');
}

sub test_has_agents_key {
    my $self = shift;

    is( AN::Alerts::has_agents_key( {agents => 1} ), 1,
	'has_agents_key() detects rightkey');
    is( AN::Alerts::has_agents_key( {agent => 1} ), '',
	'has_agents_key() avoids wrong key');
}

sub test_has_pid_subkey {
    my $self = shift;

    is( AN::Alerts::has_pid_subkey( {agents => {pid => 1}} ), 1,
	'has_pid_subkey() detects rightkey');
    is( AN::Alerts::has_pid_subkey( {agents => {dip => 0}} ), '',
	'has_pid_subkey() avoids wrong key');

}

sub test_handled_set_clear_alert {
    my $self = shift;

    ok( ! $self->handled_alert( 'key', 'subkey' ),
	'handle_alert handles key, subkey not found' );

    $self->set_alert_handled( 'key', 'subkey' );

    ok( ! $self->handled_alert( 'key', 'wrong' ),
	'handle_alert handles key found, subkey not found' );
	
    ok( $self->handled_alert( 'key', 'subkey' ),
	'handle_alert handles key, subkey found' );

    $self->clear_alert_handled( 'key', 'subkey' );

    ok( ! $self->handled_alert( 'key', 'subkey' ),
	'handle_alert handles key, subkey not found' );
}


sub test_status {

    is( AN::Alerts::DEBUG(),   'DEBUG', 'status DEBUG string' );
    is( AN::Alerts::WARNING(), 'WARNING', 'status WARNING string' );
    is( AN::Alerts::CRISIS(),  'CRISIS', 'status CRISIS string' );
}


sub test_add_alert {
    my $self = shift;


    my $old = owner->new();
    $old->timestamp( 'ts');
    $old->status( 'stat');
    $old->message_tag( 'tag');

    my $new = clone $old;

    $self->add_alert( 'key', 'subkey', $old );
    is_deeply( $self->alerts()->{key}{subkey}, $old, 'add_alert OK');

    is( $self->add_alert( 'key', 'subkey', $new ), undef,
	'adding duplicate timestatmp  detected');

    $new->timestamp( 'new ts' );
    is( $self->add_alert( 'key', 'subkey', $new ), undef,
	'adding duplicate status & message_tag detected');

    $new->status( 'new status' );
    is( $self->add_alert( 'key', 'subkey', $new ), 1,
	'adding new ts, new status succeeds');
    is_deeply( $self->alerts()->{key}{subkey}, $new,
	       'add_alert replacement OK');

    return $new;
}

sub test_alert_exists {
    my $self = shift;
    my ( $new ) = @_;

    is( $self->alert_exists( ), undef, 'no args => undef');
    is( $self->alert_exists( 'asdf' ), undef, 'wrong key => undef');
    is( $self->alert_exists( 'key' ),  '', 'wrong (default) subkey => undef');
    is( $self->alert_exists( 'key', 'asdf' ), '', 'wrong subkey => undef');
    is( $self->alert_exists( 'key', 'subkey' ), 1, 'key subkey => subkey');

    $self->delete_alert( 'key', 'subkey' );
    is( $self->alert_exists( 'key', 'subkey' ), undef, 'key subkey => undef after delete');

    $self->add_alert( 'key', 'subkey', $new );
}

sub test_delete_alert {
    my $self = shift;
    my ( $new ) = @_;

    is_deeply( $self->alerts()->{key}{subkey}, $new, 'alert exists initially');

    $self->delete_alert( 'key', 'subkey' );

    ok( ! exists $self->alerts()->{key}, 'delete_alert OK');
}

sub test_extract_time_and_modify_array {
    my $self = shift;

    my $input = [ 'string',
		  [ 1, 2, 3 ],
		  { key => 'value' },
		  { timestamp => 'ts1', another => 'field' },
		  { timestamp => 'ts2' },
	];

    my $std = clone $input;

    splice @$std, 4;
    delete $std->[3]{timestamp};

    my $output =  AN::Alerts::extract_time_and_modify_array $input;

    is( $output, 'ts2', 'routine returns last timestamp found');
    is_deeply( $input, $std, 'routine removes timestamp hash fields');

}


sub test_add_agent {
    my $self = shift;

    my $key = 123;
    my $args = {  pid => $key,
		  program  => 'program',
		  hostname => 'hostname',
		  msg_dir  => 'msg_dir',
    };
    $self->add_agent( $key, $args );

    is_deeply( $self->fetch_agent( $key ), $args,
	       'add_agent and fetch_agent OK');
}

sub test_set_alert {
    my $self = shift;

    my $args = [ 'id', 'pid',  'field', 'value', 'units', 'level', 'message_tag',
		 'message_arguements', 'target_name', 'target_type', 'target_extra',
		 { timestamp => '1234-56-78 12:34:56' }
	];

    is( $self->alert_exists($args->[1], $args->[2]), undef,
	'initially no alert');
    $self->set_alert( @$args );
    is( $self->alert_exists($args->[1], $args->[2]), 1,
	'alert found after insert');
}

sub test_clear_alert {
    my $self = shift;

    is( $self->alert_exists( 'pid', 'field'), 1,
	'alert found before delete');
    $self->delete_alert( 'pid', 'field' );
    is( $self->alert_exists( 'pid', 'field'), undef,
	'alert gone after delete');

}

sub test_dispatch_msg {
    my $self = shift;

    my $listener = eval { 
                         package listener;
                         sub new {
                            return bless {}, 'listener';
                         }
			 sub has_dispatcher {
			     my $self = shift;
			     push @{$self->{called}{has_dispatcher}}, [caller()];
			     return;
			 }
                         sub add_dispatcher {
			     my $self = shift;
			     push @{$self->{called}{add_dispatcher}}, [caller()];
			     return;
			 }
			 sub dispatch_msg {
			     my $self = shift;
			     push @{$self->{called}{dispatch_msg}},
			         [caller(), @_];
			    return;
			 }
			 new();
    };
			 
    package main;
    my $msgs = ['message 1', 'another message'];

    $self->dispatch_msg( $listener, $msgs );

    my $callfile = 'Striker/Scanner/t/../lib/AN/Alerts.pm';
    for my $routine ( sort keys %{$listener->{called}} ) {
	for my $call (  @{ $listener->{called}{$routine}  } ) {
	    is( $call->[0],   'AN::Alerts', "${routine}() call  class");
        my $file = $call->[1];
	    $file =~ s{.*/(?=Striker)}{};
	    is( $file,   $callfile,    "${routine}() call file");
	    like( $call->[2], qr{\A\d+\z},  "${routine}() call line number");
	    if ( $routine eq 'dispatch_msg' ) {
		is_deeply( $call->[3], $msgs, "${routine}() call args");
	    }
	}
    }
    return;
}

sub test_format_msg {
    my $self = shift;

    my $alert = AN::OneAlert->new( { id => 'id', message_tag => 'message_tag',
				     node_id => 'node_id', field => 'field', 
				     value => 'value', units => 'units', 
				     status => 'status', timestamp => 'timestamp',
				     target_name => 'target_name',
				     target_type => 'target_type', 
				     target_extra => 'target_extra',
				     pid => 123,
				   });
    my $msg = $self->format_msg( $alert, 'The medium is the message' );

    my $std = join '', ('id id | timestamp: hostname->program (123); ',
			'( target_type target_name target_extra ) status: ',
			'The medium is the message; (0 : field : value : units)'
			);
    is( $msg, $std, 'format_msg OK');

    return $alert;
}

sub test_mark_alerts_as_reported {
    my $self = shift;
    my ( $alert ) = @_;

    $self->add_alert( $alert->id, $alert->field, $alert );
    $self->mark_alerts_as_reported();

    my $std = { id => {field => 1 },
		key => {subkey => 0},
		pid => {field =>0},
    };
    is_deeply( $self->handled(), $std, 'self-handled OK');
    is( $self->alerts()->{id}{field}{handled}, 1, 
	'alert->handled OK');
    
    return;
}

sub test_handle_alerts {
    my $self = shift;

}

# ----------------------------------------------------------------------
# main
#
sub main {

    my $alerts = test_constructor();

    test_is_hash_ref($alerts);
    test_has_agents_key($alerts);
    test_has_pid_subkey($alerts);
    test_handled_set_clear_alert($alerts);

    test_status();

    my $new = test_add_alert($alerts);
    test_alert_exists($alerts, $new);
    test_delete_alert($alerts, $new);

    test_add_agent($alerts);


    test_extract_time_and_modify_array($alerts);
    test_set_alert($alerts);
    test_clear_alert($alerts);

    test_dispatch_msg($alerts);

    my $alert = test_format_msg($alerts);
    test_mark_alerts_as_reported($alerts, $alert);
#    test_handle_alerts($alerts);
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
