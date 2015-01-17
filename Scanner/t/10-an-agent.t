#!/usr/bin/env perl
# _Perl_
use warnings;
use strict;
use 5.010;

use File::Basename;
use FindBin '$Bin';
use lib "$Bin/../lib";
use lib "$Bin/../cgi-bin/lib";
use Cwd;
use Test::More;
use English '-no_match_vars';

use AN::Agent;

# ----------------------------------------------------------------------
$ENV{VERBOSE} = '';

my $SCHEMA = { 1 => { column_name => 'node_id', data_type => 'serial' },
               2 => { column_name => 'name',    data_type => 'text' } };

my $LISTENERS = { 2 => { id           => 2,
                         db_type      => 'Pg',
                         name         => 'screen',
                         mode         => 'SCREEN',
                         contact_info => '',
                         language     => 'en_CA',
                         added_by     => 0,
                         updated      => '2014-02-14 12:00:00.000000-05'
		  }, };

my $AGENT_RECORD = { 1 => { id        => 1234,
                            value     => 100,
                            status    => 'OK',
                            node_id   => 13,
                            msg_tag   => '',
                            msg_args  => '',
                            timestamp => '2014-02-14 12:00:00.000000-05'
		     }, };


# ----------------------------------------------------------------------
package DBI::sth;

sub new {
    my $class = shift;
    my ($sql) = @_;

    return bless { sql => $sql }, $class;
}

sub execute {
    my $self = shift;
    push @{ $self->{execute} }, \@_;
    return 1 if 0 <= index $self->{sql}, 'INSERT INTO';
    return 1 if 0 <= index $self->{sql}, 'SELECT *,';

}

sub fetchall_hashref {
    my $self = shift;

    push @{ $self->{fetch_all_hashref} }, \@_;
    return $AGENT_RECORD
        if 0 <= index $self->{sql}, 'SELECT *,'
        and 70 == index $self->{sql}, 'FROM agent_data';

    return $SCHEMA;
}
1;

# End of package DBI::sth

package DBI;

{
    no warnings;

    sub connect_cached {
        my $class = shift;
        my (@args) = @_;

        return bless { args => \@args }, $class;
    }
}

sub prepare {
    my $self = shift;
    my ($sql) = @_;

    my $sth = DBI::sth->new($sql);
    push @{ $self->{prepare} }, $sth;
    return $sth;
}

sub commit { say "commit"; return 1; }
sub rollback { say "rollback", return 1 }

sub last_insert_id {
    state $id = 1;
    return $id++;
}

sub selectall_arrayref {
    my $self = shift;

    $self->{selectall_arrayref} = \@_;
    return [ [1] ];
}

sub selectall_hashref {
    my $self = shift;

    $self->{selectall_hashref} = \@_;
    return $LISTENERS if 0 < index $_[0], 'alert_listeners';
    return $SCHEMA;
}

1;

package main;


# ----------------------------------------------------------------------
# Utility routines
#
sub init_args {

    my $parent = dirname $Bin;
    return { 'dbconf'    => "$parent/Config/db.conf",
             'filepath'  => '/tmp/agents',
             'msg_file'  => "$parent/MESSAGES/random-agent.xml",
             'rate'      => 30,
             'run_until' => '23:59:59', };
}

# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {
    my $args  = init_args();

    my $agent = AN::Agent->new($args);
    isa_ok( $agent, 'AN::Agent', 'object ISA Agent object' );

    return $agent;
}

sub test_connect_dbs {
    my $agent = shift;

    $agent->connect_dbs();

    is_deeply( [sort keys %$agent],
		 [qw( alerts_table_name datatable_name dbconf dbs rate run_until ) ],
		 'connect_dbs() generates right fields');

    my $dbs = $agent->dbs();

    isa_ok( $dbs, 'AN::DBS', 'dbs obj is right sort of object');

    is_deeply( [sort keys %$dbs],
	       [qw( dbconf dbs path )],
	       'dbs obj has right fields' );

    my $db = $dbs->{dbs}[0]; 
    isa_ok( $db, 'AN::OneDB', 'dbs db is an AN::OneDB');

    return;
}

sub test_non_blank_lines {
    my $agent = shift;

    my $args = <<"ARGS";
line 1

line 3
ARGS

    my $std = 'line 1 line 3';
    is( AN::Agent::non_blank_lines( $args ), $std, 
	'non_blank_lines OK' );
}

sub test_dump_metadata {
    my $agent = shift;

    my $dump = $agent->dump_metadata();
    $dump =~ s{(db::pid=).*}{$1};
    $dump =~ s{(db::hostname=).*}{$1};

    my $std = <<"EOSTD";
db::name=10-an-agent.t
db::pid=
db::hostname=
db::datatable_name=alerts
db::1::node_table_id=1
EOSTD

    $std =~ s{\A\n}{};
    is( $dump, $std, 'metadata dump is OK' );

}


sub test_path_to_configuration_files {
    my $agent = shift;

    is( $agent->path_to_configuration_files(), getcwd(),
	'path to config files' );
}

sub test_insert_raw_record {
    my $agent = shift;

}

sub test_generate_random_record {
    my $agent = shift;

    $agent->generate_random_record();

    my $sql = <<"EOSQL";
INSERT INTO agent_data
(field, msg_args, msg_tag, status, units, value, node_id)
VALUES
(?, ?, ?, ?, ?, ?, ?)
EOSQL

    is( $agent->dbs()->{dbs}[0]{dbh}{prepare}[2]{sql}, $sql,
	'generate new record inserted raw record sql OK');

    my $args = $agent->dbs()->{dbs}[0]{dbh}{prepare}[2]{execute}[0];
    $args->[5] = undef;

    my $args_std = ['random values', '', '10-an-agent.t first record',
		    'DEBUG', 'a num', undef, 1];

    is_deeply($args, $args_std, 'new record values OK');
}


# ----------------------------------------------------------------------
# main
#
sub main {
    my $agent = test_constructor();

    test_connect_dbs( $agent );
    test_dump_metadata($agent);
    test_path_to_configuration_files( $agent);
    test_non_blank_lines($agent);
    test_generate_random_record($agent);
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
