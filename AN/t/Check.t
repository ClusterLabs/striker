#!/usr/bin/perl -Tw
#
# This is the test script for the AN::Tools family of modules.
# 

use AN::Tools 0.0.001;
my $an = AN::Tools->new();

# Make sure that $parent matches $an.
my $parent = $an->Check->parent();
is($an, $parent, "Internal 'parent' method returns same blessed reference as is in \$an.");

# Make sure that all methods are available.
my @methods = ("parent", "parent", "_os");
can_ok("AN::Tools::Check", @methods);

# Make sure that I can turn fatal errors off.
is($an->Alert->no_fatal_errors(), 0, "no_fatal_errors(); fatal errors are enabled by default.");
is($an->Alert->no_fatal_errors({set => 1}), 1, "no_fatal_errors(); fatal errors were turned off.");
is($an->Alert->no_fatal_errors(), 1, "no_fatal_errors(); fatal errors stayed off.");
is($an->Alert->no_fatal_errors({set => 0}), 0, "no_fatal_errors(); fatal errors were turned back on.");
is($an->Alert->no_fatal_errors(), 0, "no_fatal_errors(); fatal errors stayed on.");

# I can't trigger a real error at this time (a real one will be triggered in
# 't/Math.t'). For now, I will test the internal methods directly.
is($an->Alert->_error_string(), "", "Internal method '_error_string' is blank to start.");
is($an->Alert->_set_error("Test Error"), "Test Error", "Internal method '_set_error' manually set to 'Test Error'.");
is($an->Alert->_error_string(), "Test Error", "Internal method '_error_string' is now 'Test Error'.");
is($an->Alert->_set_error(), "", "Internal method '_set_error' manually cleared.");
is($an->Alert->_set_error(), "", "Internal method '_set_error' is still clear.");
