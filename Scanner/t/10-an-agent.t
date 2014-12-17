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

use AN::Agent;


# ----------------------------------------------------------------------
# Utility routines
#
sub init_args {

    return {
	'dbini' => 'Config/db.ini',
	'filepath' => '/tmp/agents',
	'msg_file' => 'MESSAGES/random-agent',
	'rate' => 30,
	'run_until' => '23:59:59',
    };
}

# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {
    my $args = init_args();
    my $agent = AN::Agent->new($args);
    isa_ok( $agent, 'AN::Agent', 'object ISA Agent object' );

    return $agent;
}

sub  non_blank_lines {
    my $agent = shift;
    
}

sub  dump_metadata {
    my $agent = shift;
    
}

sub  create_db_table {
    my $agent = shift;
    
}

sub  insert_raw_record {
    my $agent = shift;
    
}

sub  generate_random_record {
    my $agent = shift;
    
}

sub  loop_core {
    my $agent = shift;
    
}

sub  run {
    my $agent = shift;
    
}


# ----------------------------------------------------------------------
# main
#
sub main {
    my $screen = test_constructor();

    create_db_table( $screen );
    dump_metadata( $screen );
    non_blank_lines( $screen );
    loop_core( $screen );
    generate_random_record( $screen );
    insert_raw_record( $screen );
    run( $screen );
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
