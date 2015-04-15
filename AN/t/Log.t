#!/usr/bin/perl -Tw
#
# This is the test script for the AN::Tools family of modules.
# 

use AN::Tools 0.0.001;
my $an = AN::Tools->new();

# Make sure that $parent matches $an.
my $parent = $an->Log->parent();
is($an, $parent, "Internal 'parent' method returns same blessed reference as is in \$an.");

# Make sure that all methods are available.
my @methods=(
	"parent", 
	"entry", 
	"level", 
);
can_ok("AN::Tools::Log", @methods);

