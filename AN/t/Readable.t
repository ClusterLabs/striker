#!/usr/bin/perl -Tw
#
# This is the test script for the AN::Tools family of modules.
# 

use AN::Tools 0.0.001;
my $an=AN::Tools->new();

# Make sure that $parent matches $an.
my $parent = $an->Readable->parent();
is($an, $parent, "Internal 'parent' method returns same blessed reference as is in \$an.");

# Make sure that all methods are available.
my @methods=("parent", "base2", "comma", "bytes_to_hr", "hr_to_bytes");
can_ok("AN::Tools::Readable", @methods);

# Test the 'comma()' method.
is($an->Readable->comma("1234567890"), "1,234,567,890", "comma(); Basic test of commas being inserted into a long integer.");
is($an->Readable->comma("1234567890.0987654321"), "1,234,567,890.0987654321", "comma(); Ensure commas applied to left of decimal only.");
is($an->Readable->comma(), undef, "comma(); Passing nothing returns nothing.");
is($an->Readable->comma(".0987654321"), ".0987654321", "comma(); Handle a fractional number.");
is($an->Readable->comma("321"), "321", "comma(); Handle an integer too small to insert commas into.");
is($an->Alert->no_fatal_errors({set => 1}), 1, "Disabled fatal errors for next test.");
is($an->Readable->comma("321abc"), undef, "comma(); Fatal on a non-integer string.");
like($an->error(), qr/^-=] 4 - .* \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 4, "error_code(); set to '4' after last error.");
is($an->Alert->no_fatal_errors({set => 0}), 0, "Re-enabled fatal errors.");
is($an->Readable->comma("4321"), "4,321", "comma(); Testing method after re-enabling fatal errors.");
is($an->error(), "", "error(); Error cleared after last test.");
is($an->error_code(), 0, "error_code(); Set back to '0' after last error.");

# Test the 'time()' method
is($an->Readable->time("1234567890.09876"), "2,041w 1d 23h 31m 30.09876s", "time(); Tested against a very large real number, array argument type.");
is($an->Readable->time({'time' => "1234567890.09876"}), "2,041w 1d 23h 31m 30.09876s", "time(); Tested against a very large real number, hash-ref argument type.");
is($an->Readable->time(), undef, "time(); Tested with no passed arguments.");
is($an->Readable->time(""), "0s", "time(); Tested with an empty string argument, array-type argument.");
is($an->Readable->time({'time' => ""}), "0s", "time(); Tested with an empty string argument, hashref-type argument.");
is($an->Readable->time(0), "0s", "time(); Tested with a 0 argument, array-type argument.");
is($an->Readable->time({'time' => 0}), "0s", "time(); Tested with the 0 argument, hashref-type argument.");
is($an->Readable->time({'time' => 1}), "1s", "time(); Tested with the 1 argument.");
is($an->Readable->time({'time' => -1}), "-1s", "time(); Tested with the -1 argument.");
is($an->Readable->time({'time' => 61}), "1m 1s", "time(); Tested with the 61 argument.");
is($an->Readable->time({'time' => -61}), "-1m 1s", "time(); Tested with the 61 argument.");
is($an->Readable->time({'time' => 3660}), "1h 1m 0s", "time(); Tested with the 3660 argument.");
is($an->Readable->time({'time' => -3660}), "-1h 1m 0s", "time(); Tested with the 3660 argument.");
is($an->Alert->no_fatal_errors({set => 1}), 1, "Disabled fatal errors for next test.");
is($an->Readable->time({'time' => "3,66o.02"}), undef, "time(); Tested with an invalid argument.");
like($an->error(), qr/^-=] 5 - .* \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 5, "error_code(); set to '5' after last error.");
is($an->Alert->no_fatal_errors({set => 0}), 0, "Re-enabled fatal errors.");
is($an->Readable->time({'time' => "86,400.02"}), "1d 0h 0m 0.02s", "time(); Tested with the '86,400.02' argument.");
is($an->error(), "", "error(); Error cleared after last test.");
is($an->error_code(), 0, "error_code(); Set back to '0' after last error.");

# Test the 'base2' method.
is($an->Readable->base2(), 1, "base2; Confirmed that base2 is enabled by default.");
is($an->Readable->base2(0), 0, "base2; Set to base10.");
is($an->Readable->base2(), 0, "base2; Is still set to base10.");
is($an->Readable->base2(1), 1, "base2; Set back to base2.");
is($an->Readable->base2(), 1, "base2; Is still set to base2.");

# Test the 'bytes_to_hr()' method
is($an->Readable->bytes_to_hr(8), "8b", "bytes_to_hr(); Tested against '8', array argument type.");
is($an->Readable->bytes_to_hr({'bytes' => 8}), "8b", "bytes_to_hr(); Tested against '8', hash-ref argument type.");
is($an->Readable->bytes_to_hr(1000), "1,000b", "bytes_to_hr(); Tested against '1000' with 'base2()'.");
is($an->Readable->bytes_to_hr(1024), "1.0kib", "bytes_to_hr(); Tested against '1024' with 'base2()'.");
is($an->Readable->bytes_to_hr(1000000), "976.6kib", "bytes_to_hr(); Tested against '1000000' with 'base2()'.");
is($an->Readable->bytes_to_hr(1000000000), "953.67mib", "bytes_to_hr(); Tested against '1000000000' with 'base2()'.");
is($an->Readable->bytes_to_hr(1000000000000), "931.32gib", "bytes_to_hr(); Tested against '1000000000000' with 'base2()'.");
is($an->Readable->bytes_to_hr(1000000000000000), "909.49tib", "bytes_to_hr(); Tested against '1000000000000000' with 'base2()'.");
is($an->Readable->bytes_to_hr(1000000000000000000), "888.178pib", "bytes_to_hr(); Tested against '1000000000000000000' with 'base2()'.");
is($an->Readable->bytes_to_hr(1000000000000000000000), "867.362eib", "bytes_to_hr(); Tested against '1000000000000000000000' with 'base2()', exponentional expansion of raw integer.");
is($an->Readable->bytes_to_hr("1000000000000000000000"), "867.362eib", "bytes_to_hr(); Tested against '1000000000000000000000' with 'base2()', quoted string version.");
is($an->Readable->bytes_to_hr("1000000000000000000000000"), "847.033zib", "bytes_to_hr(); Tested against '1000000000000000000000000' with 'base2()'.");
is($an->Readable->bytes_to_hr("1000000000000000000000000000"), "827.181yib", "bytes_to_hr(); Tested against '1000000000000000000000000000' with 'base2()'.");
is($an->Readable->bytes_to_hr("1000000000000000000000000000000"), "827,180.613yib", "bytes_to_hr(); Tested against '1000000000000000000000000000000' with 'base2()', beyond last round size.");
is($an->Readable->base2(0), 0, "base2; Set to base10 notation.");
is($an->Readable->bytes_to_hr(1000), "1.0kb", "bytes_to_hr(); Tested against '1000' with 'base10()'.");
is($an->Readable->bytes_to_hr(1024), "1.0kb", "bytes_to_hr(); Tested against '1024' with 'base10()'.");
is($an->Readable->base2(1), 1, "base2; Set back to base2.");
is($an->Readable->base2(0), 0, "base2; Set back to base10 for next test set.");
is($an->Readable->bytes_to_hr(1000000), "1.00mb", "bytes_to_hr(); Tested against '1000000' with 'base10()'.");
is($an->Readable->bytes_to_hr(1000000000), "1.00gb", "bytes_to_hr(); Tested against '1000000000' with 'base10()'.");
is($an->Readable->bytes_to_hr(1000000000000), "1.00tb", "bytes_to_hr(); Tested against '1000000000000' with 'base10()'.");
is($an->Readable->bytes_to_hr(1000000000000000), "1.000pb", "bytes_to_hr(); Tested against '1000000000000000' with 'base10()'.");
is($an->Readable->bytes_to_hr(1000000000000000000), "1.000eb", "bytes_to_hr(); Tested against '1000000000000000000' with 'base10()'.");
is($an->Readable->bytes_to_hr(1000000000000000000000), "1.000zb", "bytes_to_hr(); Tested against '1000000000000000000000' with 'base10()', exponentional expansion of raw integer.");
is($an->Readable->bytes_to_hr("1000000000000000000000"), "1.000zb", "bytes_to_hr(); Tested against '1000000000000000000000' with 'base10()', quoted string version.");
is($an->Readable->bytes_to_hr("1000000000000000000000000"), "1.000yb", "bytes_to_hr(); Tested against '1000000000000000000000000' with 'base10()'.");
is($an->Readable->bytes_to_hr("1000000000000000000000000000"), "1,000.000yb", "bytes_to_hr(); Tested against '1000000000000000000000000000' with 'base10()', beyond last round size.");
is($an->Readable->base2(1), 1, "base2; Set back to base2.");
is($an->Alert->no_fatal_errors({set => 1}), 1, "Disabled fatal errors for next test.");
is($an->Readable->bytes_to_hr("100000o"), undef, "bytes_to_hr(); Tested with an invalid argument.");
like($an->error(), qr/^-=] 6 - .*? \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 6, "\$an->error_code() set to '6' after last error.");
is($an->Alert->no_fatal_errors({set => 0}), 0, "Re-enabled fatal errors.");
is($an->Readable->bytes_to_hr(1000000), "976.6kib", "bytes_to_hr(); Tested against '1000000' with 'base2()' to test 'error()' clearing.");
is($an->error(), "", "error(); Error cleared after last test.");
is($an->error_code(), 0, "error_code(); Set back to '0' after last error.");

# Test the 'hr_to_bytes' method
is($an->Readable->hr_to_bytes("1k"), 1024, "hr_to_bytes(); Passed '1k' as array type argument, base2 in use.");
is($an->Readable->hr_to_bytes("1", "kb"), 1000, "hr_to_bytes(); Passed '1', 'kb' as array type arguments, base2 in use but base10 should be forced.");
is($an->Readable->hr_to_bytes("1", "k"), 1024, "hr_to_bytes(); Passed '1', 'k' as multiple array type argument, base2 in use.");
is($an->Readable->hr_to_bytes({size=>"1k"}), 1024, "hr_to_bytes(); Passed '1k' as hash-ref type argument, base2 in use.");
is($an->Readable->hr_to_bytes({size=>"1 kb"}), 1000, "hr_to_bytes(); Passed size=>'1 kb' as hash-ref type argument, base2 in use but base10 should be forced.");
is($an->Readable->hr_to_bytes({size=>"1",type=>"k"}), 1024, "hr_to_bytes(); Passed size=>'1', type=>'k' as multi-key hash-ref type argument, base2 in use.");
is($an->Readable->hr_to_bytes("1.5k"), 1536, "hr_to_bytes(); Passed '1.5k', real number test.");
is($an->Readable->hr_to_bytes("-1.5k"), "-1536", "hr_to_bytes(); Passed '-1.5k', negative real number test.");
is($an->Readable->hr_to_bytes("1.525k"), 1562, "hr_to_bytes(); Passed '1.525k', real number test.");
is($an->Readable->hr_to_bytes("1kb"), 1000, "hr_to_bytes(); Passed '1kb', base2 set but base10 should be used.");
is($an->Readable->hr_to_bytes("1k"), 1024, "hr_to_bytes(); Passed '1k', base2 should be used again.");
is($an->Readable->hr_to_bytes("1kib"), 1024, "hr_to_bytes(); Passed '1kib', base2 set and should be used.");
is($an->Readable->hr_to_bytes("1k"), 1024, "hr_to_bytes(); Passed '1k', base2 should be used again.");
is($an->Readable->hr_to_bytes("1m"), 1048576, "hr_to_bytes(); Passed '1m', base2 in use.");
is($an->Readable->hr_to_bytes("1mb"), 1000000, "hr_to_bytes(); Passed '1mb', should force base10.");
is($an->Readable->hr_to_bytes("1mib"), 1048576, "hr_to_bytes(); Passed '1mib', should force base2.");
is($an->Readable->hr_to_bytes("1g"), 1073741824, "hr_to_bytes(); Passed '1g', base2 in use.");
is($an->Readable->hr_to_bytes("1gb"), 1000000000, "hr_to_bytes(); Passed '1gb', should force base10.");
is($an->Readable->hr_to_bytes("1gib"), 1073741824, "hr_to_bytes(); Passed '1gib', should force base2.");
is($an->Readable->hr_to_bytes("1t"), 1099511627776, "hr_to_bytes(); Passed '1t', base2 in use.");
is($an->Readable->hr_to_bytes("1tb"), 1000000000000, "hr_to_bytes(); Passed '1tb', should force base10.");
is($an->Readable->hr_to_bytes("1tib"), 1099511627776, "hr_to_bytes(); Passed '1tib', should force base2.");
is($an->Readable->hr_to_bytes("2p"), "2251799813685248", "hr_to_bytes(); Passed '2p', base2 in use, verifying proper use of Math::BigInt.");
is($an->Readable->hr_to_bytes("2pb"), "2000000000000000", "hr_to_bytes(); Passed '2pb', should force base10.");
is($an->Readable->hr_to_bytes("2pib"), "2251799813685248", "hr_to_bytes(); Passed '2pib', should force base2.");
is($an->Readable->hr_to_bytes("2e"), "2305843009213693952", "hr_to_bytes(); Passed '2e', base2 in use.");
is($an->Readable->hr_to_bytes("2eb"), "2000000000000000000", "hr_to_bytes(); Passed '2eb', should force base10.");
is($an->Readable->hr_to_bytes("2eib"), "2305843009213693952", "hr_to_bytes(); Passed '2eib', should force base2.");
is($an->Readable->hr_to_bytes("2z"), "2361183241434822606848", "hr_to_bytes(); Passed '2z, base2 in use.");
is($an->Readable->hr_to_bytes("2zb"), "2000000000000000000000", "hr_to_bytes(); Passed '2zb', should force base10.");
is($an->Readable->hr_to_bytes("2zib"), "2361183241434822606848", "hr_to_bytes(); Passed '2zib', should force base2.");
is($an->Readable->hr_to_bytes("2y"), "2417851639229258349412352", "hr_to_bytes(); Passed '2y, base2 in use.");
is($an->Readable->hr_to_bytes("2yb"), "2000000000000000000000000", "hr_to_bytes(); Passed '2yb', should force base10.");
is($an->Readable->hr_to_bytes("2yib"), "2417851639229258349412352", "hr_to_bytes(); Passed '2yib', should force base2.");

is($an->Alert->no_fatal_errors({set => 1}), 1, "Disabled fatal errors for next test.");
is($an->Readable->hr_to_bytes("1l"), undef, "hr_to_bytes(); Tested with an invalid argument.");
like($an->error(), qr/^-=] 10 - .*? \[=-/, "error(); Error raised after last test.");
is($an->error_code(), 10, "\$an->error_code() set to '10' after last error.");
is($an->Alert->no_fatal_errors({set => 0}), 0, "Re-enabled fatal errors.");
is($an->Readable->hr_to_bytes("1024"), 1024, "hr_to_bytes(); Passed '1024', the same should be returned.");
is($an->error(), "", "error(); Error cleared after last test.");
is($an->error_code(), 0, "error_code(); Set back to '0' after last error.");

