#!/usr/bin/env perl

# _Perl_
use warnings;
use strict;
use 5.010;

use autodie qw(open close);
use File::Basename;
use FindBin '$Bin';
use lib "$Bin/../lib";
use lib "$Bin/../cgi-bin/lib";
use Cwd;
use Test::More;
use English '-no_match_vars';

use AN::SNMP::APC_UPS;

# ----------------------------------------------------------------------
my $SCHEMA = { 1 => { column_name => 'node_id', data_type => 'serial' },
               2 => { column_name => 'name',    data_type => 'text' } };

package DBI::sth;
# _Perl_
use warnings;
use strict;
use 5.010;

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

# ----------------------------------------------------------------------
package DBI;
# _Perl_
use warnings;
use strict;
use 5.010;

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

sub commit {
    #say "commit";
    return 1;
}
sub rollback {
    #say "rollback",
    return 1
}

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

my $dbfile = '/t/db.conf';

sub create_db_file {

    my $parent = dirname $Bin;
    open my $conf, '>', "${parent}/${dbfile}";;
    print $conf <<"EOCONF";
db::1::name      = scanner
db::1::db_type   = Pg
db::1::host      = localhost
#db::1::host      = an-m01
db::1::port      = 5432
db::1::user      = alteeve
db::1::password  = alteeve
EOCONF
    close $conf
}

sub delete_db_file {
    my $parent = dirname $Bin;
    unlink "${parent}/${dbfile}";
}

# ----------------------------------------------------------------------
$ENV{VERBOSE} = '';

sub test_constructor {

    my $parent = dirname $Bin;
    my $snmp = AN::SNMP::APC_UPS->new(
	{ rate      => 50000,
	  run_until => '23:59:59',
	  confpath  => "$parent/Config/snmp_apc_ups.conf",
	  dbconf    => "$parent/$dbfile",
	  logdir    => '/tmp'
	} );
    $snmp->connect_dbs();
    return $snmp;
}

# ----------------------------------------------------------------------
sub test_battery_replace {
    my $self = shift;

    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = {values => {1 => 'unneeded', 2 => 'needed'}};

    my $data = { tag         => 'battery replace',
                 value       => 1,
                 rec_meta    => $rec_meta,
                 prev_status => 'OK',
                 prev_value  => 1,
                 metadata    => $meta };

    $self->eval_discrete_status( $data );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[0],
	       [ 'battery replace', '', '', 'OK', 'test', '', 'unneeded', 1 ],
	       'eval battery replace /unneeded/ raw data OK' );

    my $std_sql = <<"EOSQL";
INSERT INTO snmp_apc_ups
(field, message_arguments, message_tag, status, target, units, value, node_id)
VALUES
(?, ?, ?, ?, ?, ?, ?, ?)
EOSQL

    is( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{sql}, $std_sql,
	'eval battery replace /unneeded/ raw sql OK' );

    # ......................................................................

    $data->{value} = 2;
    $self->eval_discrete_status( $data );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[1],
	       [ 'battery replace', '', 'Replace battery', 'DEBUG',
		 'test', '', 'needed', 1 ],
	       'eval battery replace /needed/ raw data OK' );

    $std_sql = <<"EOSQL";
INSERT INTO alerts
(field, message_arguments, message_tag, status, target_extra, target_name, target_type, units, value, node_id)
VALUES
(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
EOSQL

    is( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{sql}, $std_sql,
	'eval battery replace /needed/ alert sql OK' );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[0],
	   [ 'battery replace', '', 'Replace battery',
	     'DEBUG', 'ip', 'test', 'test', '', 'needed', 1 ],
	   'eval battery replace /needed/ alert data OK' );

    # ......................................................................

    $data->{value} = 1;
    $data->{prev_status} = 'WARNING';
    $data->{prev_value} = 2;
    $self->eval_discrete_status( $data );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[2],
	   [ 'battery replace', '', '', 'OK', 'test', '', 'unneeded', 1 ],
	   'eval battery replace /prev status NOK/ raw data OK' );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[1],
	   [ 'battery replace', '', '',  'OK', 'ip', 'test',
	     'test', '', 'unneeded', '1' ],
	   'eval battery replace /prev status NOK/ alert data OK' );

    # ......................................................................

    $data->{value} = 3;
    $data->{prev_value} = 1;
    $data->{prev_status} = 'OK';
    $self->eval_discrete_status( $data );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[3],
	   [ 'battery replace', 'value=3', 'Unrecognized value',
	     'DEBUG', 'test', '', '3', 1 ],
	   'eval battery replace /invalid value/ raw data OK' );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[2],
	   [ 'battery replace', 'value=3', 'Unrecognized value',
	     'DEBUG', 'ip', 'test', 'test', '', '3', 1 ],
	       'eval battery replace /invalid value/ alert data OK' );
    # ......................................................................
    return;
  }

sub test_comms {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = {values => {1 => 'yes', 2 => 'no'},
		  label   => 'Communications'};
  my $data = {tag => 'comms',
	      value => 1,
	      rec_meta => $rec_meta,
	      prev_status => 'OK',
	      prev_value => 1,
	      metadata => $meta
  };

  $self->eval_discrete_status( $data );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[4],
	     [ 'Communications', '', '', 'OK', 'test', '', 'yes', 1 ],
	     'eval comms /yes/ raw data OK' );

  # ......................................................................

  $data->{value} = 2;
  $self->eval_discrete_status( $data );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[5],
	     [ 'Communications', '', 'Communication disconnected',
	       'DEBUG', 'test', '', 'no', 1 ],
	     'eval comms /no/ raw data OK' );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[3],
	     [ 'Communications', '', 'Communication disconnected',
	       'DEBUG', 'ip', 'test', 'test', '', 'no', 1 ],
	     'eval comms no /no/ alert data OK' );

  # ......................................................................
  $data->{value} = 1;
  $data->{prev_status} = 'WARNING';
  $data->{prev_value} = 2;
  $self->eval_discrete_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[6],
	     [ 'Communications', '', '', 'OK', 'test', '', 'yes', 1 ],
	     'eval comms /prev status NOK/ raw data OK' );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[4],
	     [ 'Communications', '', '', 
	       'OK', 'ip', 'test', 'test', '', 'yes', 1 ],
	     'eval comms /prev status NOK/ alert data OK' );

  # ......................................................................

  $data->{value} = 3;
  $data->{prev_status} = 'OK';
  $data->{prev_value} = 1;
  $self->eval_discrete_status( $data );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[7],
	     [ 'Communications', 'value=3', 'Unrecognized value',
	       'DEBUG', 'test', '', '3', 1 ],
	     'eval comms /invalid value/ raw data OK' );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[5],
	     [ 'Communications', 'value=3', 'Unrecognized value',
	       'DEBUG', 'ip', 'test', 'test', '', '3', 1 ],
	     'eval comms /invalid value/ alert data OK' );

  # ......................................................................
  return;
}

sub test_last_transfer_reason {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = {values => {1 => 'one thing', 2 => 'another'}};

  my $data = {tag => 'reason for last transfer',
		value => 1,
		rec_meta => $rec_meta,
		prev_status => 'OK',
		prev_value => 'one thing',
		metadata => $meta
      };

  $self->eval_discrete_status( $data );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[8],
	     [ 'reason for last transfer', '', '', 'OK', 'test',
	       '', 'one thing', 1 ],
	     'eval reason for last transfer /one thing/ raw data OK' );

  # ......................................................................

  $data->{value} = 2;
  $self->eval_discrete_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[9],
	     [ 'reason for last transfer', 'prevvalue=one thing;value=another',
	       'value changed', 'DEBUG', 'test', '', 'another', 1 ],
	     'eval reason for last transfer /changed from prev/ raw data OK' );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[6],
	     [ 'reason for last transfer', 'prevvalue=one thing;value=another',
	       'value changed', 'DEBUG', 'ip', 'test', 'test', '', 'another', 1 ],
	     'eval reason for last transfer /changed from prev/ alert data OK' );

  # ......................................................................
  return;
}

sub test_self_test_date {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = {};

  my $date = '2014-12-28 01:23:45';
  my $data = {tag => 'last self test date',
	      value => $date,
	      rec_meta => $rec_meta,
	      prev_status => 'OK',
	      prev_value => $date,
	      metadata => $meta
  };


  $self->eval_discrete_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[10],
	     [ 'last self test date', '', '', 'OK', 'test', '', $date, 1 ],
	     'eval last self test date /same date/ raw data OK' );

  # ......................................................................

  my $date2 = $date;
  $date =~ s{45\z}{56};
  $data->{value} = $date;
  $self->eval_discrete_status( $data );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[11],
	     [ 'last self test date', "prevvalue=$date2;value=$date",
	       'value changed', 'DEBUG', 'test', '', $date, 1 ],
	     'eval last self test date /changed from prev/ raw data OK' );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[7],
	     [ 'last self test date', "prevvalue=$date2;value=$date",
	       'value changed', 'DEBUG', 'ip', 'test', 'test', '', $date, 1 ],
	     'eval last self test date /changed from prev/ alert data OK' );

  # ......................................................................
  return;
}

sub test_self_test_result {
  my  $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = {};

  my $data = {tag => 'last self test result',
		value => 1,
		rec_meta => $rec_meta,
		prev_status => 'OK',
		metadata => $meta
      };

  $self->eval_discrete_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[12],
	     [ 'last self test result', '', '', 'OK', 'test',
	       '', 1, 1 ],
	     'eval last self test result /1/ raw data OK' );

  $data->{value} = 4;
  $self->eval_discrete_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[13],
	     [ 'last self test result', '', '', 'OK', 'test',
	       '', 4, 1 ],
	     'eval last self test result /4/ raw data OK' );

  # ......................................................................

  $data->{value} = 2;
  $self->eval_discrete_status( $data );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[14],
	     [ 'last self test result', '', 'Self-test not OK: ',
	       'DEBUG', 'test', '', 2, 1 ],
	     'eval last self test result /2/ raw data OK' );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[8],
	     [ 'last self test result', undef, 'Self-test not OK: ',
	       'DEBUG', 'ip', 'test', 'test', '', 2, 1 ],
	     'eval last self test result /2/ alert data OK' );

  $data->{value} = 3;
  $self->eval_discrete_status( $data );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[15],
	     [ 'last self test result', '', 'Self-test not OK: ',
	       'DEBUG', 'test', '', 3, 1 ],
	     'eval last self test result /3/ raw data OK' );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[9],
	     [ 'last self test result', undef, 'Self-test not OK: ',
	       'DEBUG', 'ip', 'test', 'test', '', 3, 1 ],
	     'eval last self test result /3/ alert data OK' );

  # ......................................................................
  return;

}

sub test_eval_discrete_status {
    my $self = shift;

    test_battery_replace( $self );
    test_comms( $self );
    test_last_transfer_reason( $self );
    test_self_test_date( $self );
    test_self_test_result( $self );
    return;
}

# ----------------------------------------------------------------------

sub test_rising_ok {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = { ok => 10,
		   warn => 20,
		   hysteresis => 1,
		 };
  my $data = {tag => 'rising',
	      value => 5,
	      rec_meta => $rec_meta,
	      prev_status => 'OK',
	      metadata => $meta
  };


  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[16],
	     [ 'rising', '', '', 'OK', 'test', '',
	       $data->{value}, 1 ],
	     "eval rising /$data->{value}/ raw data OK" );

  $data->{value} = 10.5;
  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[17],
	     [ 'rising', '', '', 'OK', 'test', '',
	       $data->{value}, 1 ],
	     "eval rising /$data->{value} prev OK/ raw data OK" );

  # ......................................................................

  $data->{value} = 9.5;
  $data->{prev_status} = 'WARNING';
  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[18],
	     [ 'rising', '', '', 'OK', 'test', '',
	       $data->{value}, 1 ],
	     "eval rising /$data->{value} prev NOK/ raw data OK" );

  return;
}

sub test_rising_warn {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = { ok => 10,
		   warn => 20,
		   hysteresis => 1,
		 };
    my $data = {tag => 'rising',
		value => 10.6,
		rec_meta => $rec_meta,
		prev_status => 'OK',
		prev_value => 1,
		metadata => $meta
    };

  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[19],
	     [ 'rising', "value=$data->{value}", 'Value warning',
	       'WARNING', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from OK/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[11],
	     [ 'rising', "value=$data->{value}", 'Value warning',
	       'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from OK/ alert data OK" );

  $data->{value} = 9.55;
  $data->{prev_status} = 'WARNING';
  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[20],
	     [ 'rising', "value=$data->{value}", 'Value warning',
	       'WARNING', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from WARNING/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[12],
	     [ 'rising', "value=$data->{value}", 'Value warning',
	       'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from WARNING/ alert data OK" );

  # ......................................................................

  $data->{value} = 20.50;
  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[21],
	     [ 'rising', "value=$data->{value}", 'Value warning',
	       'WARNING', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from WARNING/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[13],
	     [ 'rising', "value=$data->{value}", 'Value warning',
	        'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from WARNING/ alert data OK" );

  $data->{value} = 19.45;
  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[22],
	     [ 'rising', "value=$data->{value}", 'Value warning',
	       'WARNING', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from WARNING/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[14],
	     [ 'rising', "value=$data->{value}", 'Value warning',
	        'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from WARNING/ alert data OK" );

  # ......................................................................

  return;
}


sub test_rising_crisis {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = { ok => 10,
		   warn => 20,
		   hysteresis => 1,
		 };
    my $data = {tag => 'rising',
		value => 20.51,
		rec_meta => $rec_meta,
		prev_status => 'WARNING',
		metadata => $meta
    };

  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[23],
	     [ 'rising', "value=$data->{value}", 'Value crisis',
	       'CRISIS', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from WARNING/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[15],
	     [ 'rising', "value=$data->{value}", 'Value crisis',
	        'CRISIS', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from WARNING/ alert data OK" );

  $data->{value} = 19.501;
  $data->{prev_status} = 'CRISIS';
  $self->eval_rising_status( $data);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[24],
	     [ 'rising', "value=$data->{value}", 'Value crisis',
	       'CRISIS', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from CRISIS/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[16],
	     [ 'rising', "value=$data->{value}", 'Value crisis',
	        'CRISIS', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	     "eval rising /$data->{value} from CRISIS/ alert data OK" );


  # ......................................................................

  return;
}

sub test_eval_rising_status {
  my $self = shift;

  test_rising_ok( $self );
  test_rising_warn( $self );
  test_rising_crisis( $self );

  return;
}

# ----------------------------------------------------------------------

sub test_falling_ok {
    my $self = shift;

    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok => 30,
		     warn => 20,
		     hysteresis => 1,
		 };
    my $data = {tag => 'falling',
		value => 35,
		rec_meta => $rec_meta,
		prev_status => 'OK',
		metadata => $meta
    };

    $self->eval_falling_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[25],
	       [ 'falling', '', '', 'OK', 'test', '',
		 $data->{value}, 1 ],
	       "eval falling /$data->{value}/ raw data OK" );

    $data->{value} = 29.51;
    $self->eval_falling_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[26],
	       [ 'falling', '', '', 'OK', 'test', '',
		 $data->{value}, 1 ],
	       "eval falling /$data->{value} prev OK/ raw data OK" );

    # ......................................................................

    $data->{value} = 30.5;
    $data->{prev_status} = 'WARNING';
    $self->eval_falling_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[27],
	       [ 'falling', '', '', 'OK', 'test', '',
		 $data->{value}, 1 ],
	       "eval falling /$data->{value} prev NOK/ raw data OK" );

    return;
}

sub test_falling_warn {
    my $self = shift;

    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok   => 30,
		     warn => 20,
		     hysteresis => 1,
    };
    my $data = {tag => 'falling',
		value => 29.499,
		rec_meta => $rec_meta,
		prev_status => 'OK',
		metadata => $meta
	};

    $self->eval_falling_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[28],
	       [ 'falling', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from OK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[18],
	       [ 'falling', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from OK/ alert data OK" );

    $data->{value} = 30.4999;
    $data->{prev_status} = 'WARNING';
    $self->eval_falling_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[29],
	       [ 'falling', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[19],
	       [ 'falling', "value=$data->{value}", 'Value warning',
		 'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from WARNING/ alert data OK" );

  # ......................................................................

    $data->{value} = 19.5;
    $self->eval_falling_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[30],
	       [ 'falling', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[20],
	       [ 'falling', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from WARNING/ alert data OK" );

    $data->{value} = 20.5;
    $data->{prev_status} = 'CRISIS';
    $self->eval_falling_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[31],
	       [ 'falling', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from CRISIS/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[21],
	       [ 'falling', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from CRISIS/ alert data OK" );

    # ......................................................................

    return;
}

sub test_falling_crisis {
    my $self = shift;

    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok   => 30,
		     warn => 20,
		     hysteresis => 1,
    };

    my $data = {tag => 'falling',
		value => 19.499,
		rec_meta => $rec_meta,
		prev_status => 'WARNING',
		metadata => $meta
	};

    $self->eval_falling_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[32],
	       [ 'falling', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[22],
	       [ 'falling', "value=$data->{value}", 'Value crisis',
		  'CRISIS', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from WARNING/ alert data OK" );

    $data->{value} = 20.499;
    $data->{prev_status} = 'CRISIS';
    $self->eval_falling_status( $data);
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[33],
	       [ 'falling', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from CRISIS/ raw data OK" );
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[23],
	       [ 'falling', "value=$data->{value}", 'Value crisis',
		  'CRISIS', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval falling /$data->{value} from CRISIS/ alert data OK" );


  # ......................................................................

  return;
}

sub test_eval_falling_status {
    my $self = shift;

    test_falling_ok( $self );
    test_falling_warn( $self );
    test_falling_crisis( $self );

    return;
}

# ----------------------------------------------------------------------

sub test_nested_ok {
    my $self = shift;
    
    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok_min => 40,     ok_max => 60,
		     warn_min => 30,   warn_max => 70,
		     crisis_min => 20, crisis_max => 80,
		     hysteresis => 1,
    };
    my $data = {tag => 'nested',
		value => 39.5,
		rec_meta => $rec_meta,
		prev_status => 'OK',
		metadata => $meta
    };

    # expanded low and high values for OK prev state
    #
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[34],
	       [ 'nested', '', '', 'OK', 'test', '',
		 $data->{value}, 1 ],
	       "eval nested /$data->{value}/ raw data OK" );

    $data->{value} = 60.5;
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[35],
	       [ 'nested', '', '', 'OK', 'test', '',
		 $data->{value}, 1 ],
	       "eval nested /$data->{value} prev OK/ raw data OK" );

    # ......................................................................

    # diminished low and high values for NOK prev state
    $data->{value} = 40.5;
    $data->{prev_status} = 'WARNING';
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[36],
	       [ 'nested', '', '', 'OK', 'test', '',
		 $data->{value}, 1 ],
	       "eval nested /$data->{value} prev NOK/ raw data OK" );

    $data->{value} = 59.5;
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[37],
	       [ 'nested', '', '', 'OK', 'test', '',
		 $data->{value}, 1 ],
	       "eval nested /$data->{value} prev NOK/ raw data OK" );

}

sub test_nested_warn {
    my $self =shift;
    
    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok_min => 40,     ok_max => 60,
		     warn_min => 30,   warn_max => 70,
		     crisis_min => 20, crisis_max => 80,
		     hysteresis => 1,
    };
    my $data = {tag => 'nested',
		value => 39.499,
		rec_meta => $rec_meta,
		prev_status => 'OK',
		metadata => $meta
    };

    # expanding from OK into WARNING
    #
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[38],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from OK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[26],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from OK/ alert data OK" );

    $data->{value} = 60.501;
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[39],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from OK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[27],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from OK/ alert data OK" );

    # ......................................................................

    # shrinking from WARNING toward OK
    #
    $data->{value} = 40.499;
    $data->{prev_status} = 'WARNING';
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[40],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[28],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from WARNING/ alert data OK" );

    $data->{value} = 59.501;
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[41],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[29],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from WARNING/ alert data OK" );

    # ......................................................................

    # Shrinking from CRISIS into WARNING
    #
    $data->{value} = 30.5;
    $data->{prev_vaalue} = 'CRISIS';
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[42],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from CRISIS/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[30],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from CRISIS/ alert data OK" );

    $data->{value} = 69.5;
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[43],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		 'WARNING', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from CRISIS/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[31],
	       [ 'nested', "value=$data->{value}", 'Value warning',
		  'WARNING', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from CRISIS/ alert data OK" );

    # ......................................................................

}

sub test_nested_crisis {
    my $self = shift;

    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok_min => 40,     ok_max => 60,
		     warn_min => 30,   warn_max => 70,
		     crisis_min => 20, crisis_max => 80,
		     hysteresis => 1,
    };
    my $data = {tag => 'nested',
		value => 29.499,
		rec_meta => $rec_meta,
		prev_status => 'WARNING',
		metadata => $meta
    };

    # expand from WARNING into CRISIS
    #
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[44],
	       [ 'nested', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[32],
	       [ 'nested', "value=$data->{value}", 'Value crisis',
		  'CRISIS', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from WARNING/ alert data OK" );

    $data->{value} = 70.501;
    $self->eval_nested_status( $data);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[45],
	       [ 'nested', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[33],
	       [ 'nested', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from WARNING/ alert data OK" );

    # ......................................................................

    # Shrinking CRISIS remains a CRISIS
    #
    $data->{value} = 30.49;
    $data->{prev_status} = 'CRISIS';
    $self->eval_nested_status( $data);
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[46],
	       [ 'nested', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from CRISIS/ raw data OK" );
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[34],
	       [ 'nested', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from CRISIS/ alert data OK" );

    $data->{value} = 69.501;
    $self->eval_nested_status( $data);
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[47],
	       [ 'nested', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from CRISIS/ raw data OK" );
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[35],
	       [ 'nested', "value=$data->{value}", 'Value crisis',
		 'CRISIS', 'ip', 'test', 'test', '', $data->{value}, 1 ],
	       "eval nested /$data->{value} from CRISIS/ alert data OK" );


  # ......................................................................

  return;
}


sub test_eval_nested_status {
    my $self = shift;

    test_nested_ok( $self );
    test_nested_warn( $self );
    test_nested_crisis( $self );

    return;
}

# ----------------------------------------------------------------------
# main
#
sub main {
  chdir '..' if 't' eq basename getcwd();
  create_db_file();

  my $agent = test_constructor();

  test_eval_discrete_status( $agent );
  test_eval_rising_status( $agent );
  test_eval_falling_status( $agent );
  test_eval_nested_status( $agent );
#  test_eval_status( $agent );
#  test_process_all_oids( $agent );
#  test_snmp_connect( $agent );
#  test_query_target( $agent );
#  test_loop_core( $agent );

  delete_db_file();
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
