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

use AN::IPMI::Temp;

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


  open my $conf, '>', getcwd() . '/' .   $dbfile;
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
  unlink  getcwd() . '/' .  $dbfile;
}

# ----------------------------------------------------------------------
$ENV{VERBOSE} = '';

sub test_constructor {

    my $snmp = AN::IPMI::Temp->new( { rate      => 50000,
				      run_until => '23:59:59',
				      ipmiconf  => 'Config/ipmi.conf',
				      dbconf    => $dbfile,
				    } );
  $snmp->connect_dbs();
  return $snmp;
}

# ----------------------------------------------------------------------

sub test_rising_ok {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = { ok_min => 1, ok_max => 10,
		   warn_min => 10, warn_max => 20,
		   crisis_min => 20, crisis_max => 30,
		   hysteresis => 1,
		 };

  my $val = 1;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'OK', undef, $meta);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[0],
	     [ 'rising', '', '', 'OK', 'test', '', $val, 1 ],
	     "eval rising /$val/ raw data OK" );

  $val = 10.5;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'OK', undef, $meta);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[1],
	     [ 'rising', '', '', 'OK', 'test', '', $val, 1 ],
	     "eval rising /$val prev OK/ raw data OK" );

  # ......................................................................

  $val = 9.5;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'WARN', undef, $meta);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[2],
	     [ 'rising', '', '', 'OK', 'test', '', $val, 1 ],
	     "eval rising /$val prev NOK/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[0],
	     [ 'rising', "", '', 1, 'OK', 'ip',
	       'test', 'test', '', $val ],
	     "eval rising /$val from OK/ alert data OK" );

  return;
}

sub test_rising_warn {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = { ok_min => 1, ok_max => 10,
		   warn_min => 10, warn_max => 20,
		   crisis_min => 20, crisis_max => 30,
		   hysteresis => 1,
		 };

  my $val = 10.6;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'OK', undef, $meta);
  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[3],
	     [ 'rising', "value=$val", 'Value warning', 'WARNING', 'test', '', $val, 1 ],
	     "eval rising /$val from OK/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[1],
	     [ 'rising', "value=$val", 'Value warning', 1, 'WARNING', 'ip',
	       'test', 'test', '', $val ],
	     "eval rising /$val from OK/ alert data OK" );

  $val = 9.55;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'WARNING', undef, $meta);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[4],
	     [ 'rising', "value=$val", 'Value warning', 'WARNING',
	       'test', '', $val, 1 ],
	     "eval rising /$val from WARNING/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[2],
	     [ 'rising', "value=$val", 'Value warning', 1, 'WARNING',
	       'ip', 'test', 'test', '', $val ],
	     "eval rising /$val from WARNING/ alert data OK" );

  # ......................................................................

  # rising from WARNING, but not yet CRISIS
  #
  $val = 20.50;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'WARNING',
			     undef, $meta);
  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[5],
	     [ 'rising', "value=$val", 'Value warning', 'WARNING',
	       'test', '', $val, 1 ],
	     "eval rising /$val from WARNING/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[3],
	     [ 'rising', "value=$val", 'Value warning', 1, 
	       'WARNING', 'ip', 'test', 'test', '', $val ],
	     "eval rising /$val from WARNING/ alert data OK" );

  # Dropping from CRISIS into WARNING range.
  #
  $val = 19.45;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'CRISIS', undef, $meta);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[6],
	     [ 'rising', "value=$val", 'Value warning', 'WARNING',
	       'test', '', $val, 1 ],
	     "eval rising /$val from WARNING/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[4],
	     [ 'rising', "value=$val", 'Value warning', 1,
	       'WARNING', 'ip', 'test', 'test', '', $val ],
	     "eval rising /$val from WARNING/ alert data OK" );

  # ......................................................................

  return;
}


sub test_rising_crisis {
  my $self = shift;

  my $meta = { name => 'test', type => 'test', ip => 'ip' };
  my $rec_meta = { ok_min => 1, ok_max => 10,
		   warn_min => 10, warn_max => 20,
		   crisis_min => 20, crisis_max => 30,
		   hysteresis => 1,
		 };

  my $val = 20.51;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'WARNING', undef, $meta);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[7],
	     [ 'rising', "value=$val", 'Value crisis', 'CRISIS', 'test', '', $val, 1 ],
	     "eval rising /$val from WARNING/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[5],
	     [ 'rising', "value=$val", 'Value crisis', 1,
	       'CRISIS', 'ip', 'test', 'test', '', $val ],
	     "eval rising /$val from WARNING/ alert data OK" );

  $val = 19.501;
  $self->eval_rising_status( 'rising', $val, $rec_meta, 'CRISIS', undef, $meta);

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[8],
	     [ 'rising', "value=$val", 'Value crisis', 'CRISIS',
	       'test', '', $val, 1 ],
	     "eval rising /$val from CRISIS/ raw data OK" );

  is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[6],
	     [ 'rising', "value=$val", 'Value crisis', 1,
	       'CRISIS', 'ip', 'test', 'test', '', $val ],
	     "eval rising /$val from CRISIS/ alert data OK" );


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
    my $rec_meta = { ok_min => 30, ok_max => 40,
		     warn_min => 20, warn_max => 30,
		     crisis_min => 10, crisis_max => 20,
		     hysteresis => 1,
		 };

    my $val = 35;
    $self->eval_falling_status( 'falling', $val, $rec_meta, 'OK', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[9],
	       [ 'falling', '', '', 'OK', 'test', '', $val, 1 ],
	       "eval falling /$val/ raw data OK" );

    $val = 29.51;
    $self->eval_falling_status( 'falling', $val, $rec_meta, 'OK', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[10],
	       [ 'falling', '', '', 'OK', 'test', '', $val, 1 ],
	       "eval falling /$val prev OK/ raw data OK" );

    # ......................................................................

    $val = 30.5;
    $self->eval_falling_status( 'falling', $val, $rec_meta, 'WARNING', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[11],
	       [ 'falling', '', '', 'OK', 'test', '', $val, 1 ],
	       "eval falling /$val prev NOK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[7],
	       [ 'falling', "", '', 1, 'OK', 'ip', 'test', 'test',
		 '', $val ],
	       "eval falling /$val from OK/ alert data OK" );

    return;
}

sub test_falling_warn {
    my $self = shift;

    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok_min => 30, ok_max => 40,
		     warn_min => 20, warn_max => 30,
		     crisis_min => 10, crisis_max => 20,
		     hysteresis => 1,
    };
    
    my $val = 29.49;
    $self->eval_falling_status( 'falling', $val, $rec_meta, 'OK', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[12],
	       [ 'falling', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval falling /$val from OK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[8],
	       [ 'falling', "value=$val", 'Value warning', 1,
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval falling /$val from OK/ alert data OK" );

    $val = 30.4999;
    $self->eval_falling_status( 'falling', $val, $rec_meta, 'WARNING',
				undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[13],
	       [ 'falling', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval falling /$val from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[9],
	       [ 'falling', "value=$val", 'Value warning', 1,
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval falling /$val from WARNING/ alert data OK" );

  # ......................................................................

    $val = 19.5;
    $self->eval_falling_status( 'falling', $val, $rec_meta, 'WARNING',
				undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[14],
	       [ 'falling', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval falling /$val from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[10],
	       [ 'falling', "value=$val", 'Value warning', 1, 
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval falling /$val from WARNING/ alert data OK" );

    $val = 20.5;
    $self->eval_falling_status( 'falling', $val, $rec_meta, 'CRISIS',
				undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[15],
	       [ 'falling', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval falling /$val from CRISIS/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[11],
	       [ 'falling', "value=$val", 'Value warning', 1,
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval falling /$val from CRISIS/ alert data OK" );

    # ......................................................................

    return;
}

sub test_falling_crisis {
    my $self = shift;

    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok_min => 30, ok_max => 40,
		     warn_min => 20, warn_max => 30,
		     crisis_min => 10, crisis_max => 20,
		     hysteresis => 1,
    };

    my $val = 19.49;

    $self->eval_falling_status( 'falling', $val, $rec_meta, 'WARNING',
				undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[16],
	       [ 'falling', "value=$val", 'Value crisis', 'CRISIS', 
		 'test', '', $val, 1 ],
	       "eval falling /$val from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[12],
	       [ 'falling', "value=$val", 'Value crisis', 1,
		 'CRISIS', 'ip', 'test', 'test', '', $val ],
	       "eval falling /$val from WARNING/ alert data OK" );

    $val = 20.49;
    $self->eval_falling_status( 'falling', $val, $rec_meta, 'CRISIS',
				undef, $meta);
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[17],
	       [ 'falling', "value=$val", 'Value crisis', 'CRISIS',
		 'test', '', $val, 1 ],
	       "eval falling /$val from CRISIS/ raw data OK" );
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[13],
	       [ 'falling', "value=$val", 'Value crisis', 1,
		 'CRISIS', 'ip', 'test', 'test', '', $val ],
	       "eval falling /$val from CRISIS/ alert data OK" );


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

    # expanded low and high values for OK prev state
    #
    my $val = 39.5;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'OK', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[18],
	       [ 'nested', '', '', 'OK', 'test', '', $val, 1 ],
	       "eval nested /$val/ raw data OK" );

    $val = 60.5;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'OK', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[19],
	       [ 'nested', '', '', 'OK', 'test', '', $val, 1 ],
	       "eval nested /$val prev OK/ raw data OK" );

    # ......................................................................

    # diminished low and high values for NOK prev state
    $val = 40.5;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'WARNING', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[20],
	       [ 'nested', '', '', 'OK', 'test', '', $val, 1 ],
	       "eval nested /$val prev NOK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[14],
	       [ 'nested', "", '', 1, 
		 'OK', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from OK/ alert data OK" );

    $val = 59.5;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'WARNING', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[21],
	       [ 'nested', '', '', 'OK', 'test', '', $val, 1 ],
	       "eval nested /$val prev NOK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[15],
	       [ 'nested', "", '', 1, 
		 'OK', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from OK/ alert data OK" );

    return;
}

sub test_nested_warn {
    my $self =shift;
    
    my $meta = { name => 'test', type => 'test', ip => 'ip' };
    my $rec_meta = { ok_min => 40,     ok_max => 60,
		     warn_min => 30,   warn_max => 70,
		     crisis_min => 20, crisis_max => 80,
		     hysteresis => 1,
    };

    # expanding from OK into WARNING
    #
    my $val = 39.499;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'OK', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[22],
	       [ 'nested', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval nested /$val from OK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[16],
	       [ 'nested', "value=$val", 'Value warning', 1, 
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from OK/ alert data OK" );

    $val = 60.501;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'OK', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[23],
	       [ 'nested', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval nested /$val from OK/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[17],
	       [ 'nested', "value=$val", 'Value warning', 1,
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from OK/ alert data OK" );

    # ......................................................................

    # shrinking from WARNING toward OK
    #
    $val = 40.499;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'WARNING', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[24],
	       [ 'nested', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval nested /$val from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[18],
	       [ 'nested', "value=$val", 'Value warning', 1, 
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from WARNING/ alert data OK" );

    $val = 59.501;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'WARNING', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[25],
	       [ 'nested', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval nested /$val from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[19],
	       [ 'nested', "value=$val", 'Value warning', 1,
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from WARNING/ alert data OK" );

    # ......................................................................

    # Shrinking from CRISIS into WARNING
    #
    $val = 30.5;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'CRISIS', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[26],
	       [ 'nested', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval nested /$val from CRISIS/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[20],
	       [ 'nested', "value=$val", 'Value warning', 1, 
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from CRISIS/ alert data OK" );

    $val = 69.5;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'CRISIS', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[27],
	       [ 'nested', "value=$val", 'Value warning', 'WARNING',
		 'test', '', $val, 1 ],
	       "eval nested /$val from CRISIS/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[21],
	       [ 'nested', "value=$val", 'Value warning', 1,
		 'WARNING', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from CRISIS/ alert data OK" );

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

    # expand from WARNING into CRISIS
    #
    my $val = 29.499;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'WARNING',
			       undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[28],
	       [ 'nested', "value=$val", 'Value crisis', 'CRISIS',
		 'test', '', $val, 1 ],
	       "eval nested /$val from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[22],
	       [ 'nested', "value=$val", 'Value crisis', 1,
		 'CRISIS', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from WARNING/ alert data OK" );

    $val = 70.501;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'WARNING', undef, $meta);

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[29],
	       [ 'nested', "value=$val", 'Value crisis', 'CRISIS',
		 'test', '', $val, 1 ],
	       "eval nested /$val from WARNING/ raw data OK" );

    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[23],
	       [ 'nested', "value=$val", 'Value crisis', 1,
		 'CRISIS', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from WARNING/ alert data OK" );

    # ......................................................................

    # Shrinking CRISIS remains a CRISIS
    #
    $val = 30.49;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'CRISIS',
			       undef, $meta);
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[30],
	       [ 'nested', "value=$val", 'Value crisis', 'CRISIS',
		 'test', '', $val, 1 ],
	       "eval nested /$val from CRISIS/ raw data OK" );
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[24],
	       [ 'nested', "value=$val", 'Value crisis', 1,
		 'CRISIS', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from CRISIS/ alert data OK" );

    $val = 69.501;
    $self->eval_nested_status( 'nested', $val, $rec_meta, 'CRISIS',
			       undef, $meta);
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[2]{execute}[31],
	       [ 'nested', "value=$val", 'Value crisis', 'CRISIS',
		 'test', '', $val, 1 ],
	       "eval nested /$val from CRISIS/ raw data OK" );
    
    is_deeply( $self->dbs->{dbs}[0]{dbh}{prepare}[3]{execute}[25],
	       [ 'nested', "value=$val", 'Value crisis', 1,
		 'CRISIS', 'ip', 'test', 'test', '', $val ],
	       "eval nested /$val from CRISIS/ alert data OK" );


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
