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

use AN::Screen;


# ----------------------------------------------------------------------
# Utility routines
#

# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {

    my $screen = AN::Screen->new();
    isa_ok( $screen, 'AN::Screen', 'object ISA Screen object' );

    return $screen;
}

sub test_dispatch {
    my $screen = shift;

    my @msgs = ( 'Line 1', 'This is line 2', 'Some stuff on line 3' );

    stdout_is( sub { $screen->dispatch(\@msgs) },
               join( "\n", @msgs ) . "\n",
               'Screen::dispatch() works OK.' );
    return;
}

# ----------------------------------------------------------------------
# main
#
sub main {
    my $screen = test_constructor();

    test_dispatch($screen);
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
