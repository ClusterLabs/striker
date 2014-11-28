#!/usr/bin/env perl

# _Perl_
use warnings;
use strict;
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;
use English '-no_match_vars';

use AN::FlagFile;
use Const::Fast;

const my $SECS_PER_DAY => 24 * 60 * 60;

# ----------------------------------------------------------------------
# Utility routines
#
sub init_args {

    my $host = `/bin/hostname`;
    chomp $host;
    my $args = { dir     => '/tmp',
                 pidfile => 'some_random_file_name',
                 data    => "data to put\nin the file\n", };
    return $args;
}

# ----------------------------------------------------------------------
# Tests
#
sub test_constructor {
    my ($args) = @_;

    my $obj = AN::FlagFile->new($args);

    isa_ok( $obj, 'AN::FlagFile', 'right type of obj' );

    return $obj;
}

sub test_accessors {
    my $ff = shift;
    my ($args) = @_;

    my $new_val = 'String with which to test set accessors';
    is( $ff->pidfile(), $args->{pidfile}, 'pidfile get accessor' );
    $ff->pidfile($new_val);
    is( $ff->pidfile(), $new_val, 'pidfile set accessor' );
    $ff->pidfile( $args->{pidfile} );

    is( $ff->data(), $args->{data}, 'data get accessor' );
    $ff->data($new_val);
    is( $ff->data(), $new_val, 'data set accessor' );
    $ff->data( $args->{data} );

    is( $ff->dir(), $args->{dir}, 'dir get accessor' );
    $ff->dir($new_val);
    is( $ff->dir(), $new_val, 'dir set accessor' );
    $ff->dir( $args->{dir} );
}

sub test_create_pid_file {
    my $ff = shift;

    $ff->create_pid_file();

    my $filename = $ff->full_file_path('pidfile');

    ok( -e $filename, 'pid file exists' );

    open my $pidfile, '<', $filename
        or die "Could not open pidfile '$filename', $!.";
    my $contents = join '', <$pidfile>;
    is_deeply( $contents, $ff->data(), 'pid file contents OK' );
    close $pidfile
        or die "Could not close pidfile '$filename', $!.";
}

sub test_touch_pid_file {
    my $ff = shift;

    my $now = time;

    my $filename = $ff->full_file_path('pidfile');

    my $before = $SECS_PER_DAY * ( -M $filename );

    my $delay = 60;
    say "Sleeping $delay seconds.";
    for ( 1 .. $delay ) { print q{.}; print q{ } if 0 == $_ % 10; sleep 1; }
    say '';
    $ff->touch_pid_file;

    my $after = $SECS_PER_DAY * ( -M $filename );

    my $delta = abs( $after - $before );
    ok( $delta >= ( $delay * 0.90 ),
        "file has been touched; mtime changed $delta after delay of $delay" );
}

sub test_delete_pid_file {
    my $ff = shift;

    my $num = $ff->delete_pid_file();

    is( $num, 1, 'deleted one file' );
    ok( !-e ( $ff->full_file_path('pidfile') ), 'pid file deleted' );
}

sub test_create_marker_file {
    my $ff = shift;

    $ff->create_marker_file('some_marker');

    ok( -e $ff->full_file_path('some_marker'), 'marker file exists' );
}

sub test_delete_marker_file {
    my $ff = shift;

    my $num = $ff->delete_pid_file('some_marker');

    is( $num, 1, 'deleted one file' );

    ok( !-e $ff->full_file_path('some_marker'), 'pid file deleted' );
}

sub test_read_pid_file {
    my $ff = shift;

    my $fileinfo = $ff->read_pid_file();
    ok( scalar keys %$fileinfo, 'read_pid_file returned a hash' );

    is( $fileinfo->{status}, 'file status ok', 'pid file contents status ok' );
    ok( $fileinfo->{age} <= 0, 'pid file is recent' );
    is_deeply( $fileinfo->{data}, $ff->data, 'pif file contents are correct' );
}

# ----------------------------------------------------------------------
# main
#
sub main {

    my $args = init_args();

    my $ff = test_constructor($args);
    test_accessors( $ff, $args );

    test_create_pid_file($ff);
    test_read_pid_file($ff);
    test_touch_pid_file($ff) if @ARGV;
    test_delete_pid_file($ff);

    test_create_marker_file($ff);

    say "
Run the test with any command line arg, to run the 'touch' command.
It sleeps 60 seconds so you don't want to run it, most of the time.
" unless @ARGV;
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
