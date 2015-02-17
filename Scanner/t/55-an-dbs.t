#!/usr/bin/env perl

# _Perl_
use warnings;
use strict;
use 5.010;

use File::Spec::Functions 'catdir';
use FindBin '$Bin';
use lib "$Bin/../lib";
use lib "$Bin/../cgi-bin/lib";
use Test::More;
#use Test::Output;
use English '-no_match_vars';

use AN::DBS;

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
                            message_tag   => '',
                            message_arguments  => '',
                            timestamp => '2014-02-14 12:00:00.000000-05'
                          }, };

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

sub ping { return 1; }

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

# End of package DBI

package main;

# ----------------------------------------------------------------------
# Utility routines
#

sub std_dbconf {

    return { 1 => { 'db_type'  => 'Pg',
                    'name'     => 'scanner',
                    'password' => 'alteeve',
                    'port'     => 5432,
                    'user'     => 'alteeve',
                  },
	     2 => { 'db_type'  => 'Pg',
		    'host'     => '10.255.4.252',
		    'name'     => 'scanner',
		    'password' => 'alteeve',
		    'port'     => 5432,
		    'user'     => 'alteeve',
	     },
    };
}

sub alert_args {

    return { name    => 'some scanner agent',
             db_data => { 1 => { db_type       => 'Pg',
                                 host          => '10.255.4.251',
                                 name          => 'some scanner agent',
                                 port          => 5432,
                                 user          => 'alteeve',
                                 node_table_id => 13,
                               },
                          datatable_name => 'agent_data',
                        } };
}

# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {

    my $config_file = { config_file => catdir( $Bin, '../Config/db.conf' ) };
    my $args = { path   => $config_file,
		 logdir => '/tmp',
    };
    my $dbs = AN::DBS->new( $args  );
    isa_ok( $dbs, 'AN::DBS', 'DBS object' );

    is_deeply( $dbs->path,   $config_file, 'DBS obj has right config path.' );
    my $conf = $dbs->dbconf;
    delete $conf->{1}{host};
    is_deeply( $conf, std_dbconf(), 'DBS obj has right config data.' );

    my $onedb = $dbs->dbs->[0];
    isa_ok( $onedb, 'AN::OneDB', q{DBS object's dbs attribute'} );

    return $dbs;
}

sub test_is_pw_field {
    my $dbs = shift;

    is( AN::DBS::is_pw_field('password'), 1,
        q{is_pw_field matches 'password'} );

    isnt( AN::DBS::is_pw_field('wrong'), 1, q{is_pw_field detects mismatch} );

    isnt( AN::DBS::is_pw_field(''),
          1, q{is_pw_field detects erronous empty string} );

    isnt( AN::DBS::is_pw_field(), 1, q{is_pw_field detects erronous no args} );

    return;
}

sub test_add_db {
    my $dbs = shift;

    # tested implicitly by constructor
}

sub test_connect_dbs {
    my $dbs = shift;

    # tested implicitly by constructor
}

sub test_insert_raw_record {
    my $dbs = shift;

    my $args = { table              => 'node',
                 with_node_table_id => 'node_table_id',
                 args               => {
                           node_name        => 'testing',
                           node_description => 'server',
                           pid              => 123,
                         } };
    $dbs->insert_raw_record($args);

SQL:
    for my $sql ( keys %{ $dbs->dbs->[0]->sth } ) {
        next SQL unless 0 <= index $sql, 'INSERT INTO';
        next SQL unless 0 <= index $sql, 'node_table_id';

        my $sth = $dbs->dbs->[0]->sth->{$sql};

        my $std = [ 'server', 'testing', 123, 1 ];
        is_deeply( $sth->{execute}[0], $std, 'sth has right execute args' );
    }
    return;
}

sub test_fetch_alert_data {
    my $dbs = shift;

    my $args = alert_args();
    $dbs->current(0);
    my $records = $dbs->fetch_alert_data($args);

    my $record = $records->[0];
    isa_ok( $record, 'AN::OneAlert',
            'fetch_alert_data() returns array of OneAlerts' );

    my $std = $AGENT_RECORD->{1};
    $std->{db_type} =  'Pg';
    delete $record->{db};
    delete $std->{db};
    $std->{other} = [];
    is_deeply( $record, $std, 'fetch_alert_data() OK' );

    return;
}

sub test_fetch_alert_listeners {
    my $dbs = shift;

    my $listener = $dbs->fetch_alert_listeners();

    isa_ok( $listener->[0], 'AN::Listener',
            'fetch_alert_listeners() returns object' );

    my $std = bless $LISTENERS->{2}, 'AN::Listener';

    is_deeply( $listener->[0], $std, 'fetch_alert_listeners() attributes OK' );

    return;
}

# ----------------------------------------------------------------------
# main
#
sub main {
    my $dbs = test_constructor();

    # Tested implicitly by the constructor, no need to run separately.
    #
    # test_add_db( $dbs );
    # test_connect_dbs( $dbs );

#    No longer used
#
#    test_is_pw_field($dbs);
    test_insert_raw_record($dbs);
    test_fetch_alert_data($dbs);
    test_fetch_alert_listeners($dbs);

}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
