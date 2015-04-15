#!/usr/bin/perl -Tw
#
# This is the test script for the AN::Tools family of modules.
# 

use AN::Tools 0.0.001;
my $an = AN::Tools->new();

# Make sure that $parent matches $an.
my $parent = $an->Get->parent();
is($an, $parent, "Internal 'parent' method returns same blessed reference as is in \$an.");

# Make sure that all methods are available.
my @methods=(
	"parent", 
	"say_am", 
	"say_pm",
	"date_seperator",
	"time_seperator",
	"use_24h",
	"date_and_time"
);
can_ok("AN::Tools::Get", @methods);

# Test that the default "say_am" value is 'am'.
my $say_am = $an->Get->say_am();
is($say_am, "am", "say_am(); Make sure the default value is 'am'.");
# Set and check a change to say_am().
$say_am = $an->Get->say_am("a");
is($say_am, "a", "say_am(); Change value to 'a'.");

# Test that the default "say_pm" value is 'pm'.
my $say_pm = $an->Get->say_pm();
is($say_pm, "pm", "say_pm(); Make sure the default value is 'pm'.");
# Set and check a change to say_pm().
$say_pm = $an->Get->say_pm("p");
is($say_pm, "p", "say_pm(); Change value to 'p'.");

# Test that the default "date_seperator" value is '-'.
my $say_pm = $an->Get->date_seperator();
is($say_pm, "-", "date_seperator(); Make sure the default value is '-'.");
# Set and check a change to say_pm().
$say_pm = $an->Get->date_seperator("/");
is($say_pm, "/", "date_seperator(); Change value to '/'.");

# Test that the default "date_seperator" value is '-'.
my $say_pm = $an->Get->date_seperator();
is($say_pm, "-", "date_seperator(); Make sure the default value is '-'.");
# Set and check a change to say_pm().
$say_pm = $an->Get->date_seperator("/");
is($say_pm, "/", "date_seperator(); Change value to '/'.");
