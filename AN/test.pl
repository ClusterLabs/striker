#!/usr/bin/perl -Tw
#
# This is the test script for the AN::Tools family of modules.
# 

# This just sets perl to be strict about how it runs.
use strict;
use warnings;
our $VERSION = "0.0.001";

# Setup for UTF-8 mode.
# use utf8;
# binmode STDOUT, ":utf8:";
# $ENV{'PERL_UNICODE'} = 1;

# Call in the test module
# use Test::More tests => 65;
use Test::More 'no_plan';

# Load my module via 'use_ok' test.
BEGIN
{
	push @INC, "/var/www/";
	print "Will now test AN::Tools on $^O.\n";
	use_ok('AN::Tools', 0.0.001);
}

# Test the main module object.
# my $an = AN::Tools->new({String => {force_utf8 => 1}});
my $an = AN::Tools->new();
like($an, qr/^AN::Tools=HASH\(0x\w+\)$/, "AN::Tools object appears valid.");
my @methods = (
	"default_language",
	"error", 
	"error_code", 
	"Alert", 
	"Check",
	"data", 
	"Log", 
	"Math", 
	"Readable", 
	"String", 
	"_add_hash_reference",
	"_directory_delimiter", 
	"_error_limit",
	"_fcntl_loaded", 
	"_get_hash_reference", 
	"_io_handle_loaded", 
	"_load_fcntl",
	"_load_io_handle", 
	"_load_math_bigint", 
	"_make_hash_reference", 
	"_math_bigint_loaded", 
);
can_ok("AN::Tools", @methods);
is($an->error(), "", "error() is initially set to an empty string.");
is($an->error_code(), 0, "error_code() is initially set to '0'.");
is($an->_math_bigint_loaded, 0, "_math_bigint_loaded() is initially set to '0'.");

### test AN::Tools::Alert
print "Testing AN::Tools::Alert\n";
require_ok("AN/t/Alert.t");

### test AN::Tools::Check
print "Testing AN::Tools::Check\n";
require_ok("AN/t/Check.t");

### Test AN::Tools::Math
print "Testing AN::Tools::Math\n";
require_ok("AN/t/Math.t");

### Test AN::Tools::Readable
print "Testing AN::Tools::Readable\n";
require_ok("AN/t/Readable.t");

### Test AN::Tools::String
print "Testing AN::Tools::String\n";
require_ok("AN/t/String.t");

### Test AN::Tools::Log
print "Testing AN::Tools::Log\n";
require_ok("AN/t/Log.t");

### test AN::Tools::Get
print "Testing AN::Tools::Get\n";
require_ok("AN/t/Get.t");

exit 0;
