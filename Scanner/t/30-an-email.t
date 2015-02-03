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

use AN::Email;

# ----------------------------------------------------------------------
# Utility routines
#

# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {
    my $email = AN::Email->new();
    isa_ok( $email, 'AN::Email', 'object ISA Email object' );

    return $email;
}

sub test_dispatch {
    my $email = shift;

    my @msgs = ( 'Line 1', 'This is line 2', 'Some stuff on line 3' );

    stdout_is( sub { $email->dispatch( \@msgs ) },
               join( '', map {"Email: $_\n"} @msgs ),
               'Email::dispatch() works OK.' );
    return;
}

# ----------------------------------------------------------------------
# main
#
sub main {
    my $email = test_constructor();

SKIP: {
        skip "Figure out a way to mock up 'mailx'", 1;

        test_dispatch($email);
    }
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
