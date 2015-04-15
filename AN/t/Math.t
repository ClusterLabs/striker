#!/usr/bin/perl -Tw
#
# This is the test script for the AN::Tools family of modules.
# 

use AN::Tools 0.0.001;
my $an=AN::Tools->new();

# Make sure that $parent matches $an.
my $parent = $an->Math->parent();
is($an, $parent, "Internal 'parent' method returns same blessed reference as is in \$an.");

# Make sure that all methods are available.
my @methods = (
	"parent", 
	"round"
);
can_ok("AN::Tools::Math", @methods);

# Test 'round'
my $to_round = 10.245;
my $to_places = 2;
my $rounded = $an->Math->round($to_round, $to_places);
is($rounded, "10.25", "round(); Two places using array-type args.");
$rounded = $an->Math->round({
	number	=>	$to_round,
	places	=>	$to_places
});
is($rounded, "10.25", "round(); to two places using hashref-type args.");

# This inadvertantly tests Alert early, but is needed to disable fatal errors.
my $invalid_arg = "10.004f67";
is($an->Alert->no_fatal_errors({set => 1}), 1, "Fatal errors disabled for next test.");
$rounded = $an->Math->round({
	number	=>	$invalid_arg,
	places	=>	$to_places
});
is($rounded, undef, "round(); Passed invalid arg caused failure returning undef.");
is($an->error_code(), 2, "\$an->error_code() set to '2' after last error.");
like($an->error(), qr/^-=] 2 - .* \[=-/, "\$an->error() contains an error message after last test.");
is($an->Alert->no_fatal_errors({set=>0}), 0, "Fatal errors re-enabled.");
$rounded = $an->Math->round($to_round, $to_places);
is($an->error(), "", "error(); Cleared after re-enabling fatal errors.");
is($an->error_code(), 0, "error_code(); Set back to '0' after last error.");

# This time set the passed value to have fewer that the number of digits to
# round and ensure that the resulting value is padded.
$to_round = 10.2;
$to_places = 2;
$rounded = $an->Math->round({
	number	=>	$to_round,
	places	=>	$to_places
});
is($rounded, "10.20", "round(); Padded 0s to the right of the decimal place.");

# Test a string that has no digit before the decimal place.
$to_round = .2;
$to_places = 2;
$rounded = $an->Math->round({
	number	=>	$to_round,
	places	=>	$to_places
});
is($rounded, "0.20", "round(); Put a 0 to the left of the decimal place where none existed.");

# Test a string that has no digit after the decimal place.
$to_round = 2.;
$to_places = 2;
$rounded = $an->Math->round({
	number	=>	$to_round,
	places	=>	$to_places
});
is($rounded, "2.00", "round(); Handled a number with no digits after the decimal place.");

# Test that I get a mathmatically accurate rounding.
$to_round = 2.444445;
$to_places = 0;
$rounded = $an->Math->round({
	number	=>	$to_round,
	places	=>	$to_places
});
is($rounded, "3", "round(); Financial rounding to a whole number.");

# Test that I get a mathmatically accurate rounding.
$to_round = 2.444445;
$to_places = 2;
$expect = "2.45";
$rounded = $an->Math->round({
	number	=>	$to_round,
	places	=>	$to_places
});
is($rounded, "2.45", "round(); Financial rounding to two places after the decimal place.");

# Test that I get a mathmatically accurate rounding.
$to_round = 2.444445;
$rounded = $an->Math->round({
	number	=>	$to_round,
});
is($rounded, "3", "round(); Financial rounding to a whole number with no places defined.");
