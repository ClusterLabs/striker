#!/usr/bin/env perl

# _Perl_
use warnings;
use strict;
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";
use lib "$Bin/../cgi-bin/lib";
use Test::More;
use English '-no_match_vars';

use AN::OneAlert;


# ----------------------------------------------------------------------
# Utility routines
#
sub init_args {

    return { 'level' => 'DEBUG',
	     'msg_args' => undef,
	     'msg_tag' => 'OLD_PROCESS_CRASH',
	     'other' => [],
	     'pid' => 13991,
	     'timestamp' => 'Sat Dec 13 19:11:11 2014',
    };

}
# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {
    my $args = init_args();
    my $onealert = AN::OneAlert->new($args);
    isa_ok( $onealert, 'AN::OneAlert', 'object ISA OneAlert object' );

    return $onealert;
}

sub  test_levels {
    my $onealert = shift;
    
    is( $onealert->OK,      'OK',      'OK string OK' );
    is( $onealert->DEBUG,   'DEBUG',   'DEBUG string OK' );
    is( $onealert->WARNING, 'WARNING', 'WARNING string OK' );
    is( $onealert->CRISIS,  'CRISIS',  'CRISIS string OK' );
}

sub test_listening_at_this_level {
    my $onealert = shift;

    my $std = {
        CRISIS  => { OK => 0, DEBUG => 0, WARNING => 0, CRISIS => 1 },
        WARNING => { OK => 0, DEBUG => 0, WARNING => 1, CRISIS => 1 },
        DEBUG   => { OK => 0, DEBUG => 1, WARNING => 1, CRISIS => 1 },
        OK      => { OK => 1, DEBUG => 1, WARNING => 1, CRISIS => 1 },

              };

    my $listener = { level => '' };
    for ( 'OK', 'DEBUG', 'WARNING', 'CRISIS' ){
	$onealert->status($_);
        for ( 'OK', 'DEBUG', 'WARNING', 'CRISIS' ) {
	    $listener->{level} = $_;
            my $accept = $std->{ $listener->{level} }{ $onealert->status() };
            is( $onealert->listening_at_this_level($listener), $accept,
                      "Listener level $listener->{level}\t"
                    . ( $accept ? 'accepts ' : 'ignores ' )
                    . "alert at level @{[$onealert->status()]}." );
        }
    }
}
sub test_has_this_alert_been_reported_yet {
    my $onealert = shift;
    my ($pass) = @_;

    my @expected = ( undef, 0, 1, 0 );
    my @string = ( undef,
                   'Object initially unreported.',
                   'Object reported. after set()',
                   'Object unreported after clear().', );
    is( $onealert->has_this_alert_been_reported_yet() || 0,
        $expected[$pass], $string[$pass] );
}
    
sub test_set_handled {
    my $onealert = shift;

    $onealert->set_handled();
}
    
sub test_clear_handled {
    my $onealert = shift;

    $onealert->clear_handled();
}
    


# ----------------------------------------------------------------------
# main
#
sub main {
    my $onealert = test_constructor();

    test_levels( $onealert );
    test_has_this_alert_been_reported_yet( $onealert, 1 );
    test_set_handled( $onealert );
    test_has_this_alert_been_reported_yet( $onealert, 2 );
    test_clear_handled( $onealert );
    test_has_this_alert_been_reported_yet( $onealert, 3 );
    test_listening_at_this_level( $onealert );

}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
