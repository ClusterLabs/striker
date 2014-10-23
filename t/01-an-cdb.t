#!/usr/bin/env perl

use Test::More;

use lib '../cgi-bin/lib/';
use AN::Cdb;

sub test__get_peer_node {
  my $conf = {cgi => { cluster => 'test_cluster' },
	      clusters => {test_cluster => {nodes => ['abc','xyz'] }}
	     };

  is( 'xyz', AN::Cdb::get_peer_node( $conf, 'abc' ),
      qq{finds peer for 'abc'});
  is( 'abc', AN::Cdb::get_peer_node( $conf, 'xyz' ),
      qq{finds peer for 'xyz'});
 TODO: {
    local $TODO = 'seeking missing node should fail.';
    is( 'abc', AN::Cdb::get_peer_node( $conf, 'Tom' ),
	qq{Seek missing node 'Tom'});
  }
 TODO: {
    todo_skip 'Testing error conditions results in hard_die()', 1;

  $conf->{clusters}{test_cluster}{nodes} = undef;
    my $result = eval{AN::Cdb::get_peer_node( $conf, 'abc' )};
    is( 'error msg', $result, qq{finds peer for 'abc'});
  }
}




sub main {
    test__get_peer_node();

}

main();

done_testing();
