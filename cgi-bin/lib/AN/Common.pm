package AN::Common;
#
# This will store general purpose functions.
# 
# 
# NOTE: The '$an' file handle has been added to all functions to enable the transition to using AN::Tools.
# 

use strict;
use warnings;
use IO::Handle;
use Encode;
use CGI;
use utf8;
use Term::ReadKey;
use XML::Simple qw(:strict);
use AN::Cluster;

# Set static variables.
my $THIS_FILE = 'AN::Common.pm';


# This funtion does not try to parse anything, use templates or what have you. It's very close to a simple
# 'die'. This should be used as rarely as possible as translations can't be used.
sub hard_die
{
	my ($an, $file, $line, $exit_code, $message) = @_;
	
	$file      = "--" if not defined $file;
	$line      = 0    if not defined $line;
	$exit_code = 999  if not defined $exit_code;
	$message   = "?"  if not defined $message;
	
	# This can't be skinned or translated. :(
	print "
	<div name=\"hard_die\">
	Fatal error: [<span class=\"code\">$exit_code</span>] in file: [<span class=\"code\">$file</span>] at line: [<span class=\"code\">$line</span>]!<br />
	$message<br />
	Exiting.<br />
	</div>
	";
	
	exit ($exit_code);
}

1;
