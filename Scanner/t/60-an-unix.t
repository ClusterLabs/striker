#!/usr/bin/env perl

# _Perl_
use warnings;
use strict;
use 5.010;

use Data::Dumper;
use File::Basename;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;
use Test::Output;
use English '-no_match_vars';
use Sys::Hostname;

use AN::Unix;

# ----------------------------------------------------------------------
# Utility routines
#

# ----------------------------------------------------------------------
# Tests
#

sub test_hostname {

    my $std = Sys::Hostname::hostname();

    is( AN::Unix::hostname(), $std, 'AN::Unix::hostname long version OK');
    is( AN::Unix::hostname( '-short' ), (split /[.]/, $std)[0],
	'AN::Unix::hostname short version OK');
}

sub test_pid2process {

  my $name = basename AN::Unix::pid2process( $$ );

  is( $name, 'perl', 'pid2process OK' );
}

sub test_new_bg_process {

  my $sleeper = AN::Unix::new_bg_process( '/bin/sleep', '10');

  isa_ok( $sleeper->{process}, 'Proc::Background' );
#  my $pid = $sleeper->{pid};
#  is( AN::Unix::pid2process( $pid ), '/bin/sleep',
#      'object ids right process' );
#  undef $sleeper;

#  say AN::Unix::pid2process( $pid );

}

# ----------------------------------------------------------------------
# main
#
sub main {
    test_hostname();
    test_pid2process();
    test_new_bg_process();
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
