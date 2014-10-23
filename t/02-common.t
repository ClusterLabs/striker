#!/usr/bin/env perl

use Test::More;
use Test::Output;
use Cwd;
use lib '../cgi-bin/lib/';
use AN::Common;

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
    is( $std, $result, "netmask '$netmask' result '$result' matches'$std" );
  }
}

# ========================================
sub test__create_rsync_wrapper {

  my $conf = {cgi => {cluster => 'test'},
	      clusters => {'test' => {root_pw => 'XXX' }},
	      path => {log => getcwd() . '/test_logfile'},
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

  is( $std, $wrapper, 'rsync wrapper created properly');
  unlink $wrapper_file;
}

# ========================================
sub test__test_ssh_fingerprint {

=pod	#disable chunk 
  my $conf = {cgi => {cluster => 'test'},
	      clusters => {'test' => {root_pw => 'XXX' }},
	      path => {log => getcwd() . '/test_logfile'},
	     };

  my $result = AN::Common::test_ssh_fingerprint( $conf, '127.0.0.1');
=cut
}

# ========================================
sub test__get_current_directory {

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
  is_deeply( \@std_l1, \@l1, '$conf has right  top-level keys');

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
  is( $std, 
      AN::Common::insert_variables_into_string( $conf, $string, $variables),
      'insert_variables_into_string'
      );
}

# ========================================
sub test__read_configuration_file {

}

# ========================================
sub test__to_log {

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
