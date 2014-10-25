#!/usr/bin/env perl

use Test::More;
use Test::Output;
use Cwd;

use lib '../cgi-bin/lib/';
use AN::Common;

# ----------------------------------------------------------------------
# Override inconvenient routines with predictable values.
#

package AN::Common;

# ....................
sub hard_die {

  print "die hard";

}
# ....................
sub get_date_and_time{

  return ('Friday 13 October, 2014', '13:13:13');
}

package main;

# ----------------------------------------------------------------------
# Constants
#
# I would use Const::Fast but it isn't part of Perl::Core, so it would
# need to be an additional import. Just use var 'constants' for now.
#
my $LOGFILE = 'test_log_file.log';

# ----------------------------------------------------------------------
# Test Subroutines
#

# ========================================
sub test__convert_cidr_to_dotted_decimal {

  my $INVALID = 0;
  my @std = ('#!INVALID!#',
	     '128.0.0.0', '192.0.0.0',
	     '224.0.0.0', '240.0.0.0',
	     '248.0.0.0', '252.0.0.0',
	     '254.0.0.0', '255.0.0.0',
	     '255.128.0.0', '255.192.0.0',
	     '255.224.0.0', '255.240.0.0',
	     '255.248.0.0', '255.252.0.0',
	     '255.254.0.0', '255.255.0.0',
	     '255.255.128.0', '255.255.192.0',
	     '255.255.224.0', '255.255.240.0',
	     '255.255.248.0', '255.255.252.0',
	     '255.255.254.0', '255.255.255.0',
	     '255.255.255.128', '255.255.255.192',
	     '255.255.255.224', '255.255.255.240',
	     '255.255.255.248', '255.255.255.252',
	     '#!INVALID!#', '255.255.255.255',
	     );

  for my $netmask ( -1 .. 33 ) {
    my $std = ( $netmask < 0          ? $netmask
	      : exists $std[$netmask] ? $std[$netmask]
	      :                         $std[$INVALID]
	      );
    my $result = AN::Common::convert_cidr_to_dotted_decimal(undef, $netmask );
    is( $result, $std, "netmask '$netmask' result '$result' matches'$std" );
  }
}

# ========================================
sub test__create_rsync_wrapper {

  my $conf = {cgi => {cluster => 'test'},
	      clusters => {'test' => {root_pw => 'XXX' }},
	      path => {log => getcwd() . $LOGFILE},
	     };
  my $wrapper_suffix = 'node.123';
  AN::Common::create_rsync_wrapper( $conf, $wrapper_suffix );

  my$wrapper_file = "~/rsync.$wrapper_suffix";
  my $wrapper = `cat $wrapper_file`;

  my $std = <<'EOSTD';
#!/usr/bin/expect
set timeout 3600
eval spawn rsync $argv
expect  "*?assword:" { send "XXX\n" }
expect eof
EOSTD

  is( $wrapper, $std, 'rsync wrapper created properly');
  unlink $wrapper_file;
}

# ========================================
sub test__test_ssh_fingerprint {

=pod	#disable chunk 
  my $conf = {cgi => {cluster => 'test'},
	      clusters => {'test' => {root_pw => 'XXX' }},
	      path => {log => getcwd() . $LOGFILE},
	     };

  my $result = AN::Common::test_ssh_fingerprint( $conf, '127.0.0.1');
=cut
}

# ========================================
sub test__get_current_directory {

    my $result =  AN::Common::get_current_directory();

    is( $result, getcwd(), 'finds correct directory.');
}

# ========================================
sub test__get_date_and_time {

}

# ========================================
sub test__get_languages {

}

# ========================================
sub test__get_string {

}

# ========================================
sub test__get_wrapped_string {

}

# ========================================
sub test__hard_die {

}

# ========================================
sub test__initialize {

}

# ========================================
sub test__initialize_conf {

  my $conf = AN::Common::initialize_conf();

  my (@l1) = sort keys %$conf;
  my (@std_l1) = qw(args     check_using_node    handles
		    nodes    online_nodes        path
		    string   strings             sys
		    system   up_nodes            url
		 );
  is_deeply( \@l1, \@std_l1, '$conf has right  top-level keys');

}

# ========================================
sub test__initialize_http {

  my $std = "Content-Type: text/html; charset=utf-8\r\n\r\n";
  stdout_is( sub {AN::Common::initialize_http()}, $std, 'initialize_http');
}

# ========================================
sub test__insert_variables_into_string {

  my $string = "This #!variable!s!# contains #!variable!n!# variables.";
  my $variables = {s => 'sentence', n => 2};
  my $std = 'This sentence contains 2 variables.';
  my $conf = {sys => {error_limit => 3}};
  is( AN::Common::insert_variables_into_string( $conf, $string, $variables),
      $std, 
      'insert_variables_into_string'
      );

  $conf = {sys => {error_limit => 1}};
  $string .=" Here's another #!variable!damn!# variable.";
  $std .= "Here's another  variable.";

  stdout_is( sub{AN::Common::insert_variables_into_string( $conf, $string,
							   $variables)},
	     'die hard', 'Detects too many iterations'
	     );
}

# ========================================
sub test__read_configuration_file {

}

# ========================================
sub test__to_log {

  my $conf = 
    {path => {log_file => $LOGFILE,
	     },
     string => {lang => 
		{English => 
		 { key => {log_0001 => 
		   {content => 'date: #!variable!date!#  time: #!variable!time!#'},
		 }}}},
     sys => {error_limit => 3,
	     language => 'English',
	     log_level => 3,
	     log_language => 'English',
	    },
    };
  my $logvar = { line => __LINE__,
		 file => __FILE__,
		 level => 3,
		 message => 'logging at level 3',
		 };
  unlink $conf->{path}{log_file};
  AN::Common::to_log( $conf, $logvar);
  my @output = split "\n",`cat $LOGFILE`;
  my $std_header = '-=] date: Friday 13 October, 2014  time: 13:13:13';
  my $std_msg = ' logging at level 3';

  is( $output[0], $std_header, 'log header is correct');

  my ($path, $msg) = split ';', $output[1]; # The part after the semicolon.
  like( $path, qr{t/02-common.t \d+\Z}, 'path part is correct');
  is( $std_msg, $msg, 'log message is correct');

}

# ========================================
sub test__template {

}

# ========================================
sub test__process_string {

}

# ========================================
sub test__process_string_insert_strings {

}

# ========================================
sub test__process_string_conf_escape_variables {

}

# ========================================
sub test__process_string_protect_escape_variables {

}

# ========================================
sub test__process_string_replace {

}

# ========================================
sub test__process_string_restore_escape_variables {

}

# ========================================
sub test__read_strings {

}

# ========================================
sub test__wrap_string {

}

# ========================================
sub test__get_screen_width {

}

# ========================================
sub test___add_hash_reference {

}

# ========================================
sub test___get_hash_value_from_string {

}

# ========================================
sub test___make_hash_reference {

}

# ----------------------------------------------------------------------
# main()
#
# ========================================
sub main {
    test__convert_cidr_to_dotted_decimal();
    test__create_rsync_wrapper();
    test__test_ssh_fingerprint();
    test__get_current_directory();
    test__get_date_and_time();
    test__get_languages();
    test__get_string();
    test__get_wrapped_string();
    test__hard_die();
    test__initialize();
    test__initialize_conf();
    test__initialize_http();
    test__insert_variables_into_string();
    test__read_configuration_file();
    test__to_log();
    test__template();
    test__process_string();
    test__process_string_insert_strings();
    test__process_string_conf_escape_variables();
    test__process_string_protect_escape_variables();
    test__process_string_replace();
    test__process_string_restore_escape_variables();
    test__read_strings();
    test__wrap_string();
    test__get_screen_width();
    test___add_hash_reference();
    test___get_hash_value_from_string();
    test___make_hash_reference();
}

main();

done_testing();
