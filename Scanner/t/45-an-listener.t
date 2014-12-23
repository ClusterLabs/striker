#!/usr/bin/env perl

# _Perl_
use warnings;
use strict;
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;
use Test::Output;
use English '-no_match_vars';
use AN::Listener;


# ----------------------------------------------------------------------
# Utility routines
#
sub init_args {

    return { id           => 2,
             name         => 'screen',
             mode         => 'SCREEN',
             level        => 'DEBUG',
             contact_info => '',
             language     => 'en_CA',
             added_by     => 0,
             updated      => '2014-12-11 14:42:13.273057-05', };

}
# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {

    my $args = init_args();
    
    my $listener = AN::Listener->new($args);
    isa_ok( $listener, 'AN::Listener', 'object ISA Listener object' );

    is_deeply( $listener, $args, 'Object has right attributes.' );
    
    return $listener;
}

sub test_has_dispatcher {
    my ( $ listener ) = @_;

    is( !! $listener->has_dispatcher(), '', 'No dispatcher at start.')
}

sub test_add_dispatcher {
    my ( $listener ) = @_;

    $listener->add_dispatcher();

    my $dispatcher = $listener->has_dispatcher();
    
    isa_ok( $dispatcher, 'AN::Screen',
	'Dispatcher present after add_dispatcher.')
}

sub test_dispatch_msg {
    my ( $listener ) = @_;

    my @msgs = ( 'Line 1', 'This is line 2', 'Some stuff on line 3' );
    stdout_is( sub { $listener->dispatch_msg(\@msgs) },
               join( "\n",  @msgs ) . "\n",
               'Listener::dispatch_msg() works OK.' );
    return;


}

# ----------------------------------------------------------------------
# main
#
sub main {
    my $listener = test_constructor();

    test_has_dispatcher( $listener );
    test_add_dispatcher( $listener );
    test_dispatch_msg( $listener );
}


main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
