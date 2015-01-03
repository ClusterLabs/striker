#!/usr/bin/env perl

# _Perl_
use warnings;
use strict;
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";
use lib "$Bin/../cgi-bin/lib";
use Test::More;
use Test::Output;
use English '-no_match_vars';

use AN::OneDB;

my $SCHEMA = { 1 => { column_name => 'node_id', data_type => 'serial' },
               2 => { column_name => 'name',    data_type => 'text' } };

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
    return $SCHEMA;
}

1;

# End of package DBI

package main;

# ----------------------------------------------------------------------
# Utility routines
#
sub init_args {

    my $dbconf = { dbconf => { 'db_type'  => 'Pg',
                               'host'     => 'localhost',
                               'name'     => 'scanner',
                               'password' => 'alteeve',
                               'port'     => 5432,
                               'user'     => 'alteeve',
                             }, };

    return ($dbconf);
}

# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {

    my $args  = init_args();
    my $onedb = AN::OneDB->new($args);
    isa_ok( $onedb,        'AN::OneDB', 'object ISA OneDB object' );
    isa_ok( $onedb->{dbh}, 'DBI',       'dbh ISA DBI object' );
    is_deeply( $onedb->{dbconf}, $args->{dbconf}, 'dbconf attributes OK' );
    for my $sql ( keys %{ $onedb->sth } ) {

        # skip initial blank line
        #
        my $line_one = ( split "\n", $sql )[1];
        isa_ok( $onedb->sth()->{$sql},
                'DBI::sth', "'$line_one' sth ISA DBI::sth object" );
    }

    my $dbh_args = $onedb->dbh()->{args};
    is( $dbh_args->[0], 'dbi:Pg:dbname=scanner', 'dbh dsn OK' );
    is( $dbh_args->[1], 'alteeve',               'dbh username OK' );
    is( $dbh_args->[2], 'alteeve',               'dbh password OK' );
    is_deeply( $dbh_args->[3],
               {  'AutoCommit'         => 0,
                  'PrintError'         => 0,
                  'RaiseError'         => 1,
                  'dbi_connect_method' => undef
               },
               'dbh extra args OK' );

    return $onedb;
}

sub test_dump_metada {
    my $onedb = shift;

    is( $onedb->dump_metadata('test'),
        "test::node_table_id=1", 'dump_metadata output OK' );

    return;
}

sub test_generate_insert_sql {
    my $onedb = shift;

    my $args = { table         => 'tablename',
                 node_table_id => 1,
                 args          => {
                           field   => 'value',
                           another => 'more'
                         }, };
    my ( $sql, $fields, $values ) = $onedb->generate_insert_sql($args);

    my $std_sql = <<"EOSQL";
INSERT INTO tablename
(another, field)
VALUES
(?, ?)
EOSQL

    $sql =~ s{\s+}{ }g;
    $std_sql =~ s{\s+}{ }g;

    my $std_fields = [qw(another field)];
    my $std_values = { 'another' => 'more',
                       'field'   => 'value', };
    is( $sql, $std_sql, 'generate_insert_sql() sql OK' );
    is_deeply( $fields, $std_fields, 'generate_insert_sql() fields OK' );
    is_deeply( $values, $std_values, 'generate_insert_sql() args OK' );

    return;
}

sub test_insert_raw_record {
    my $onedb = shift;

    my $args = { table         => 'tablename',
                 node_table_id => 1,
                 args          => {
                           field   => 'value',
                           another => 'more'
                         }, };

    my $status = $onedb->insert_raw_record($args);
    is( $status, 2, 'insert_raw_record() OK' );
    return;
}

sub test_generate_fetch_sql {
    my $onedb = shift;

    my $args = { db_data => { 1              => { node_table_id => 1, },
                              datatable_name => 'tablename',
                            }, };

    my ( $sql, $id ) = $onedb->generate_fetch_sql($args);
    $sql =~ s{\s+}{ }g;
    $sql =~ s{\s\z}{};
    my $std_sql
        = q{SELECT *, round( extract( epoch from age( now(), timestamp ))) as age FROM tablename WHERE node_id = ? and timestamp > now() - interval '1 minute' ORDER BY timestamp asc};

    is( $sql, $std_sql, 'generate_fetch_sql() sql OK' );
    is( $id,  1,        'generate_fetch_sql() node_table_id OK' );
    return;
}

sub test_fetch_alert_data {
    my $onedb = shift;

    my $args = { db_data => { 1              => { node_table_id => 1, },
                              datatable_name => 'tablename',
                            }, };
    my $records = $onedb->fetch_alert_data($args);
    is_deeply( $records, $SCHEMA, 'fetch_alert_data() OK' );
    return;
}

sub test_fetch_alert_listeners {
    my $onedb = shift;

    my $records = $onedb->fetch_alert_listeners();

    is_deeply( $records, $SCHEMA, 'fetch_alert_listeners() OK' );

    return;
}

# ----------------------------------------------------------------------
# main
#
sub main {
    my $onedb = test_constructor();

    test_dump_metada($onedb);

    test_generate_insert_sql($onedb);
    test_insert_raw_record($onedb);
    test_generate_fetch_sql($onedb);
    test_fetch_alert_data($onedb);
    test_fetch_alert_listeners($onedb);

}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
