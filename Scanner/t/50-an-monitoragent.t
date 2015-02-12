#!/usr/bin/env perl

# _Perl_
use warnings;
use strict;
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;
#use Test::Output;
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

# ----------------------------------------------------------------------
# main
#
sub main {
    my $screen = test_constructor();

}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
