#!/usr/bin/perl -Tw
#
# This is the test script for the AN::Tools family of modules.
# 

use AN::Tools 0.0.001;
my $an = AN::Tools->new();

# Make sure that $parent matches $an.
my $parent = $an->String->parent();
is($an, $parent, "Internal 'parent' method returns same blessed reference as is in \$an.");

# use Data::Dumper;
# print Dumper $an->data;

# Make sure that all methods are available.
my @methods=(
	"parent", 
	"force_utf8", 
	"read_words",
	"get",
	"_insert_variables_into_string",
	"_process_string",
	"_process_string_insert_strings",
	"_protect",
	"_restore_protected",
	"_format_mode"
);
can_ok("AN::Tools::String", @methods);

### This is String testing stuff, feel free to ignore for now.
is($an->String->get("t_0000"), "Test", "get(); key only, array type call.");
is($an->String->get({
	key		=>	"t_0000"
}), "Test", "get(); key only, hash reference-type call.");
is($an->String->get("t_0001", {
	test		=>	'A'
}), "Test replace: {test => 'A'}.", "get(); key and one variable, array type call.");
is($an->String->get({
	key		=>	"t_0001", 
	variable	=>	{
		test		=>	"A"
	}
}), "Test replace: [A].", "get(); key and one variable, hash reference type call.");
is($an->String->get({
	key		=>	"t_0002",
	variable	=>	{
		first		=>	"A",
		second		=>	"B"
	}
}), "Test Out of order: [B] replace: [A].", "get(); key and two variables, out of order injection.");
is($an->String->get({
	key		=>	"t_0002",
	variable	=>	{
		first		=>	"あ",
		second		=>	"い"
	}, 
	language => "jp"
}), "テスト、 整理: [い]/[あ]。", "get(); key and two variables, out of order injection, alternate language.");

my $test = {};	# Alternate hash reference test
is($an->Storage->read_words("./test.xml", $test), 1, "read_words(); Read in 'test.xml' into a new hash reference, array type call.");
is($an->String->get({
	key		=>	"ta_0000",
	variable	=>	{
		test		=>	'A'
	},
	hash		=>	$test
}), "Alternate Test: [A].", "get(); key and one variable, alternate words hash.");
$test = {};	# Blank to test reload.
is($an->Storage->read_words({
	file		=>	"./test.xml",
	hash		=>	$test
}), 1, "read_words(); Read in 'test.xml' into cleared hash reference for next set of tests, hash reference type call.");
is($an->Storage->read_words("./test.xml", $test), 1, "read_words(); Read in 'test.xml' into a new hash reference for next set of tests.");
is($an->String->get({
	key		=>	"ta_0000",
	variable	=>	{
		test		=>	"あ"
	},
	language	=>	"jp",
	hash		=>	$test
}), "代りのテスト: [あ]。", "get(); key and one variable, alternate words hash and alternate language.");
is($an->String->get("ta_0000",{test => "あ"}, "jp", $test), "代りのテスト: [あ]。", "get(); key and one variable, alternate words hash and alternate language, array-type arguments.");
is($an->Alert->no_fatal_errors({set => 1}), 1, "Disabled fatal errors for next test.");
is($an->Storage->read_words("./t/test.xml", $hash), undef, "read_words(); Test failure when asked to read in a non-existant file.");
like($an->error(), qr/^-=] 11 - .* \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 11, "error_code(); set to '11' after last error.");
is($an->String->get("t_0000"), "Test", "get(); Known-good call the check in error is cleared.");
is($an->error(), "", "error(); Error cleared after last test.");
is($an->error_code(), 0, "error_code(); Set back to '0' after last error.");
is($an->Storage->read_words("./unreadable.xml", $hash), undef, "read_words(); Test unreadable file error. if this test fails, chmod 'unreadable.xml' back to 0200 and try again.");
like($an->error(), qr/^-=] 12 - .* \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 12, "error_code(); set to '12' after last error.");
is($an->String->get({
	key		=>	"an_0000",
	hash		=>	'foo'
}), undef, "get(); Test bad hash reference error.");
like($an->error(), qr/^-=] 15 - .* \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 15, "error_code(); set to '15' after last error.");
is($an->String->get({
	key		=>	"t_0001",
	variable	=>	'a'
}), undef, "get(); Test bad variable array error.");
like($an->error(), qr/^-=] 16 - .* \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 16, "error_code(); set to '16' after last error.");
is($an->String->get({
	key		=>	"t_0000",
	language	=>	'foo'
}), undef, "get(); Test language error.");
like($an->error(), qr/^-=] 17 - .* \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 17, "error_code(); set to '17' after last error.");
is($an->String->get({
	key		=>	"t_0003"
}), undef, "get(); Test bad words key error.");
like($an->error(), qr/^-=] 18 - .* \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 18, "error_code(); set to '18' after last error.");
is($an->Alert->no_fatal_errors({
	set		=>	0
}), 0, "Re-enabled fatal errors.");
is($an->String->get("t_0000"), "Test", "get(); Known-good call the check in error is cleared.");
is($an->error(), "", "error(); Error cleared after last test.");
is($an->error_code(), 0, "error_code(); Set back to '0' after last error.");



### Failure tests.
# is($an->Storage->read_words("./test.xml", $hash), 1, "read_words(); Read in 'test.xml' into a new hash reference for next set of tests.");

# my $conf=$an->data()->{strings}{lang}{en_CA}{key}{an_0000}{content};
# my $confj=$an->data()->{strings}{lang}{jp}{key}{an_0000}{content};
# print "Data: [$conf] ($confj)\n";
# use IO::Handle;
# my $test=IO::Handle->new();
# open ($test, ">test.txt") or die "Failed to open 'test.txt' for writting. error was: $!\n";
# print $test "Data: [$conf] ($confj)\n";
# $test->close();
# foreach my $key (keys %{$conf})
# {
# 	print "key: [$key] = [$conf->{$key}]\n";
# }
# 
# use Data::Dumper;
# print Dumper $an->data();
