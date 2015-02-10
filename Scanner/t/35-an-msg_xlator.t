#!/usr/bin/env perl

package owner;
   sub new {
     return bless { class => 'owner' }, 'owner';
   }

   sub max_retries {
     return 10;
   }

package main;

# _Perl_
use warnings;
use strict;
use 5.010;

use File::Spec::Functions 'catdir';
use FindBin '$Bin';
use lib "$Bin/../lib";
use lib "$Bin/../cgi-bin/lib";
use Test::More;
use English '-no_match_vars';

use AN::Alerts;
use AN::Unix;
use AN::Msg_xlator;
use Const::Fast;

# ----------------------------------------------------------------------
# Utility routines
#
sub init_args {

    my $args = { pid     => $$,
                 program => '20-an-msg_xlator',
		 owner   => owner->new(),
                 msg_dir => $Bin . q{/}, };

    my $file = $args->{msg_dir} . $args->{program} . '.xml';
    unlink $file if -e $file;
    open my $testfile, '>', $file;

    print $testfile <<"EODATA";

i<?xml version="1.0" encoding="UTF-8"?>
<string>
    <!-- Canadian English -->
    <lang name="en_CA" long_name="English (Canadian)">
        <key name="song">Humpty Dumpty</key>
    </lang>

    <lang name="fr" long_name="Français">
        <key name="song">Frere Jacques</key>
    </lang>
</string>
EODATA

    return $args;
}

sub clean_up_temp_file {

    my ($args) = init_args();
    my $file = $args->{msg_dir} . $args->{program} . '.xml';

    unlink $file if -e $file;
}

sub std_attributes {

    return [qw(agents language msg_dir pid program string strings)];
}

# ----------------------------------------------------------------------
# Tests
#

sub test_constructor {
    my $args = init_args();

    my $alert = AN::Alerts->new(
        {  agents => { pid      => $PID,
                       program  => '20-an-msg_xlator',
                       hostname => AN::Unix::hostname(),
                       msg_dir  => $Bin,
                     },

	   owner => owner->new(),
        } );

    my $xlator = $alert->xlator;
    isa_ok( $xlator, 'AN::Msg_xlator', 'object ISA Msg_xlator' );

    is_deeply( [ sort keys %$xlator ],
               [qw( agents pid sys ) ],
               'object has expected attributes' );

    return ( $alert, $xlator );
}

sub strings_table_loaded_pre_load {
    my $xlator = shift;

    ok( !$xlator->strings_table_loaded($PID),
        'Initially, Strings table not loaded' );
}

sub load_strings_table {
    my $xlator = shift;

    my $args = { msg_dir => catdir( $Bin, '../Messages/' ),
                 program => 'scanner', };
    $xlator->load_strings_table($args);

    is_deeply( $xlator->language(),
               {  'en_CA' => 'English (Canadian)',
                  'fr'    => 'Français',
                  'ja'    => '日本語'
               },
               'languages populated OK' );
    is( ref $xlator->string(), 'HASH', 'string attribute is a hash' );
    is( ref $xlator->string()->{lang}{en_CA},
        'HASH', 'string en_CA sub-component is a hash' );
    is_deeply( [ sort keys %{ $xlator->string->{lang}{en_CA}{key} } ],
               [  'NODE_SERVER_DYING',        'OLD_PROCESS_CRASH',
		  'OLD_PROCESS_RECENT_CRASH', 'OLD_PROCESS_STALLED',
		  'brand_0001',               'comment',
		  'legal_0001',               'legal_0002', 
		  'legal_0003'
               ],
               'string attribute tags OK' );
    is_deeply( $xlator->string->{lang}{en_CA}{key}{OLD_PROCESS_CRASH},
               { 'content' => 'Old process crashed.' },
               'OLD_PROCESS_CRASH string OK' );
    is_deeply( $xlator->strings(),
               {  'encoding'    => 'UTF-8',
                  'xml_version' => '1.0'
               },
               'strings populated OK' );
    return;
}

sub strings_table_loaded_post_load {
    my $xlator = shift;

    ok( $xlator->strings_table_loaded($PID),
        'Strings table present after load' );
}

sub std_language {

    return { 'en_CA' => 'English (Canadian)', 'fr' => 'Français' };
}

sub lookup_msg {
    my $xlator = shift;

    my $tag = { key      => 'song',
                language => 'en_CA', };

    is( $xlator->lookup_msg( $$, $tag ),
        'Humpty Dumpty',
        'lookup_msg() OK in en_CA' );

    $tag->{language} = 'fr',

        is( $xlator->lookup_msg( $$, $tag ),
            'Frere Jacques',
            'lookup_msg() OK in fr, too' );

    return;
}

# ----------------------------------------------------------------------
# main
#
sub main {
    my ( $alert, $xlator ) = test_constructor();

    strings_table_loaded_pre_load($xlator);
    load_strings_table($xlator);
    strings_table_loaded_post_load($xlator);
    lookup_msg($xlator);

    clean_up_temp_file();
}

main();

done_testing();

# ----------------------------------------------------------------------
# End of file.
