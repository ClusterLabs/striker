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


# ----------------------------------------------------------------------
# main
#
sub main {
  chdir '..' if 't' eq basename getcwd();
  create_db_file();

  my $agent = test_constructor();

  delete_db_file();
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
