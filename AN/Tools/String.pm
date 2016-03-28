package AN::Tools::String;

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "String.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Storage->new()\n";
	my $class = shift;
	
	my $self  = {
		CORE_WORDS	=>	"AN::tools.xml",
		FORCE_UTF8	=>	0,
	};
	
	bless $self, $class;
	
	return ($self);
}

# Get a handle on the AN::Tools object. I know that technically that is a sibling module, but it makes more 
# sense in this case to think of it as a parent.
sub parent
{
	my $self   = shift;
	my $parent = shift;
	
	$self->{HANDLE}{TOOLS} = $parent if $parent;
	
	return ($self->{HANDLE}{TOOLS});
}

# This forces UTF8 mode when reading a words file. This should not be used normally as the words file should
# already be UTF8 encoded.
sub force_utf8
{
	my $self = shift;
	my $set  = defined $_[0] ? shift : undef;
	
	if (defined $set)
	{
		if (($set == 0) || ($set == 1))
		{
			$self->{FORCE_UTF8} = $set;
		}
		else
		{
			my $an = $self->parent;
			$an->Alert->error({fatal => 1, title_key => "error_title_0001", message_key => "error_message_0004", message_variables => { set => $set }, code => 14, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return ($self->{FORCE_UTF8});
}

# This returns the long language name for a given ISO language code (as available in the read-in words).
sub get_language_name
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	my $language  = $parameter->{language} if $parameter->{language};
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	die "$THIS_FILE ".__LINE__."; [ Error ] - No language code passed into AN::String::get_language_name().\n" if not $language;
	
	my $hash = $an->data;
	my $language_name = $hash->{strings}{lang}{$language}{lang}{long_name};
	
	return($language_name);
}

# This takes a word key and, optionally, a hash reference, a language and/or an variables array reference. It
# returns the corresponding string from the hash reference data containing the data from a 'read_words()' 
# call.
sub get
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Catch infinite loops
	my $i     = 0;
	my $limit = $an->_error_limit;
	
	# Make sure we got a key.
	if (not $parameter->{key})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0001", message_key => "error_message_0001", code => 20, file => $THIS_FILE, line => __LINE__});
		return (undef);
	}
	
	my $key       = $parameter->{key};
	my $variables = $parameter->{variables} ? $parameter->{variables} : {};
	my $language  = $parameter->{language}  ? $parameter->{language}  : $an->default_language;
	my $hash      = $parameter->{hash}      ? $parameter->{hash}      : $an->data;
	
	# Make sure that 'hash' is a hash reference
	if (ref($hash) ne "HASH")
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0001", message_key => "error_message_0005", message_variables => { hash => $hash }, code => 15, file => $THIS_FILE, line => __LINE__});
		return (undef);
	}

	# Make sure that 'variables' is an array reference, if set.
	if (($variables) && (ref($variables) ne "HASH"))
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0001", message_key => "error_message_0006", message_variables => { variables => $variables }, code => 16, file => $THIS_FILE, line => __LINE__});
		return (undef);
	}
	
	# Make sure that the request language exists in the hash.
	if (ref($hash->{strings}{lang}{$language}) ne "HASH")
	{
		# If not, I have to just 'die' because calling Alert->error() would trigger an infite loop.
		print "$THIS_FILE ".__LINE__."; [ ERROR ] Invalid Language!<br />\n";
		print "$THIS_FILE ".__LINE__."; [ ERROR ] The 'AN::Tools::String' module's 'get' method was passed an invalid 'language' argument: [$language]. This must match one of the languages in the words file's <langs>...</langs> block.<br />\n",
		print "$THIS_FILE ".__LINE__."; [ ERROR ] Exiting in file: [$THIS_FILE] at line: [".__LINE__."]<br />\n";
		use Data::Dumper;
		print "<pre>\n";
		print Dumper $hash."\n";
		print "</pre>\n";
		exit(17);
	}
	
	# Make sure that the request key is in the language hash.
	if (not exists $hash->{strings}{lang}{$language}{key}{$key}{content})
	{
		print "$THIS_FILE ".__LINE__."; language: [$language], key: [$key], no string key.\n";
		$an->Alert->error({fatal => 1, title_key => "error_title_0004", message_key => "error_message_0007", message_variables => {
			key		=>	$key,
			language	=>	$language,
		}, code => 18, file => $THIS_FILE, line => __LINE__});
		return (undef);
	}
	
	# Now pick out my actual string.
	my $string =  $hash->{strings}{lang}{$language}{key}{$key}{content};
	   $string =~ s/^\n//;
	
	# This clears off the new-line and trailing white-spaces caused by the indenting of the '</key>' 
	# field in the words XML file when printing to the command line.
	$string =~ s/\n(\s+)$//;
	
	# Make sure that if the string has '#!variable!x!#', that 'variables' is a hash reference. If it 
	# isn't, it would trigger an infinite loop later. The one exception is '#!variable!*!#' which is used
	# to explain things to the user, and is explicitely escaped as needed.
	if (($string =~ /#!variable!(.*?)!#/) && (ref($variables) ne "HASH"))
	{
		if ($string =~ /#!variable!\*!#/)
		{
			#print "$THIS_FILE ".__LINE__."; Passed: '#!variable!\*!#'\n";
		}
		else
		{
			# Other variable key, so this is fatal.
			print "$THIS_FILE ".__LINE__."; String key: [$key], containing: [$string] has a variable substitution, but no variables were passed in.\n";
			$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0008", code => 36, file => $THIS_FILE, line => __LINE__});
			return (undef);
		}
	}
	
	# Substitute in any variables if needed.
	if (ref($variables) eq "HASH")
	{
		$string = $an->String->_insert_variables_into_string({
			string		=>	$string,
			variables	=>	$variables,
		});
	}
	
	# Process the just-read string.
	$string = $an->String->_process_string({
		  string	=>	$string,
		  language	=>	$language,
		  hash		=>	$hash,
		  variables	=>	$variables,
	});
	
	return ($string);
}

# This takes a string and substitutes out the various replacement keys as needed until the string is ready 
# for display. The only thing it doesn't handle is substituting '#!variable!x!#' keys into a string. For 
# that, call the 'get' method with it's given variable array reference and store the results in a string. 
# This is requried because there is currently no way for any of the called methods within here to know which
# string the variables in the array reference belong in.
sub _process_string
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Start looping through the passed string until all the replacement keys are gone.
	my $i     = 0;
	my $limit = $an->_error_limit;
	   
	$parameter->{string} = $an->String->_insert_variables_into_string({
			string		=>	$parameter->{string},
			variables	=>	$parameter->{variables},
		});
	
	while ($parameter->{string} =~ /#!([^\s]+?)!#/)
	{
		# Substitute 'word' keys, but without 'variables'. This has to be first! 'protect' will catch
		# 'word' keys, because no where else are they allowed.
		$parameter->{string} = $an->String->_process_string_insert_strings({
				string		=>	$parameter->{string},
				language	=>	$parameter->{language},
				hash		=>	$parameter->{hash},
			});
		
		# Protect unmatchable keys.
		$parameter->{string} = $an->String->_protect({
				string	=>	$parameter->{string},
			});
		
		# Inject any 'data' values.
		$parameter->{string} = $an->String->_insert_data({
				string	=>	$parameter->{string},
			});
		
		die "$THIS_FILE ".__LINE__."; Infinite loop detected while processing the string: [$parameter->{string}], exiting.\n" if $i > $limit;
		$i++;
	}
	
	# Restore and unrecognized substitution values.
	$parameter->{string} = $an->String->_restore_protected({
			string		=>	$parameter->{string},
		});
	
	# Do any output mode specific formatting.
	$parameter->{string} = $an->String->_format_mode({
			string		=>	$parameter->{string},
		});
	
	return ($parameter->{string});
}

# Do any output mode specific formatting.
sub _format_mode
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# I don't think I need this now as I only wrap the string after it's been processed by 
	# 'print_template'. It may have future use though.
	return ($parameter->{string});
}

# This restores the original key format for keys that were protected by the '_protect' method.
sub _restore_protected
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Restore and unrecognized substitution values.
	my $i = 0;
	while ($parameter->{string} =~ /!#[^\s]+?#!/)
	{
		$parameter->{string} =~ s/!#([^\s]+?)#!/#!$1!#/g;
		
		if ($i > $an->_error_limit)
		{
			print "$THIS_FILE ".__LINE__."; Infinite loop detected while restoring protected replacement keys in the string:\n";
			print "----------\n";
			print "$parameter->{string}\n";
			print "----------\n";
			die "exiting.\n";
		}
		$i++;
	}
	
	return ($parameter->{string});
}

# This does the actual work of substituting 'data' keys.
sub _insert_data
{
	my $self  = shift;
	my $parameter = shift;
	
	my $an    = $self->parent;
	
	my $i = 0;
	while ($parameter->{string} =~ /#!data!(.+?)!#/)
	{
		my $id = $1;
		if ($id =~ /::/)
		{
			# Multi-dimensional hash.
			my $value = $an->_get_hash_reference({
				key	=>	$id,
			});
			if (not defined $value)
			{
				$parameter->{string} =~ s/#!data!$id!#/!!a[$id]!!/;
			}
			else
			{
				$parameter->{string} =~ s/#!data!$id!#/$value/;
			}
		}
		else
		{
			# One dimension
			if (not defined $an->data->{$id})
			{
				$parameter->{string} =~ s/#!data!$id!#/!!b[$id]!!/;
			}
			else
			{
				my $value            =  $an->data->{$id};
				$parameter->{string} =~ s/#!data!$id!#/$value/;
			}
		}
		
		die "Infinite loop detected while replacing data keys in the string: [$parameter->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	
	### TODO: Phase this out. All #!conf!x!# need to be replaced with #!data!x!# in strings and 
	###       templates.
	while ($parameter->{string} =~ /#!conf!(.+?)!#/)
	{
		my $id = $1;
		if ($id =~ /::/)
		{
			# Multi-dimensional hash.
			my $value = $an->_get_hash_reference({
				key	=>	$id,
			});
			if (not defined $value)
			{
				$parameter->{string} =~ s/#!conf!$id!#/!!a[$id]!!/;
			}
			else
			{
				$parameter->{string} =~ s/#!conf!$id!#/$value/;
			}
		}
		else
		{
			# One dimension
			if (not defined $an->data->{$id})
			{
				$parameter->{string} =~ s/#!conf!$id!#/!!b[$id]!!/;
			}
			else
			{
				my $value            =  $an->data->{$id};
				$parameter->{string} =~ s/#!conf!$id!#/$value/;
			}
		}
		
		die "Infinite loop detected while replacing data keys in the string: [$parameter->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	
	return ($parameter->{string});
}

# Protect unrecognized or unused replacement keys. I do this to protect strings
# possibly set or created by a user.
sub _protect
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	my $i         = 0;
	foreach my $check ($parameter->{string} =~ /#!([^\s]+?)!#/)
	{
		if (($check !~ /^free/) &&
		    ($check !~ /^replace/) &&
		    ($check !~ /^data/) &&
		    ($check !~ /^conf/) &&
		    ($check !~ /^word/) &&
		    ($check !~ /^var/))
		{
			# Simply invert the '#!...!#' to '!#...#!'.
			$parameter->{string} =~ s/#!($check)!#/!#$1#!/g;
		}
		
		die "Infinite loop detected while protecting replacement keys in the string: [$parameter->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	
	return ($parameter->{string});
}

# This is called to process '#!string!...!#' keys in string. It DOES NOT support substituting 
# '#!variable!x!#' keys found in imported word strings! This is meant to insert simple word strings into 
# template files.
sub _process_string_insert_strings
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Loop through the string until all '#!string!...!#' keys are gone.
	my $i     = 0;
	while ($parameter->{string} =~ /#!string!(.+?)!#/)
	{
		my $key      = $1;
		my $say_word = $an->String->get({
				key		=>	$key,
				language	=>	$parameter->{language},
				hash		=>	$parameter->{hash},
				variables	=>	undef,
			});
		if ($say_word)
		{
			$parameter->{string} =~ s/#!string!$key!#/$say_word/;
		}
		else
		{
			$parameter->{string} =~ s/#!string!$key!#/!!e[$key]!!/;
		}
		
		die "Infinite loop detected while replacing #!string!...!# keys in the string: [$parameter->{string}], exiting.\n" if $i > $an->_error_limit;
		$i++;
	}
	return ($parameter->{string});
}

# This takes a string with '#!variable!*!#' keys, where '*' is a hash key matching an entry in the passed 
# hash reference and uses the data from the hash to replace the matching '#!variable!*!#' entry.
sub _insert_variables_into_string
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	my $i         = 0;
	
	while ($parameter->{string} =~ /#!variable!(.+?)!#/s)
	{
		my $variable = $1;
		
		# Sometimes, #!variable!*!# is used in explaining things to users. So we need to escape it. 
		# It will be restored later in '_restore_protected()'.
		if ($variable eq "*")
		{
			$parameter->{string} =~ s/#!variable!\*!#/!#variable!*#!/;
			next;
		}
		
		if (not defined $parameter->{variables}{$variable})
		{
			# I can't expect there to always be a defined value in the variables array at any 
			# given position so if it's blank I blank the key.
			$parameter->{string} =~ s/#!variable!$variable!#//;
		}
		else
		{
			my $value = $parameter->{variables}{$variable};
			chomp $value;
			$parameter->{string} =~ s/#!variable!$variable!#/$value/;
		}
		
		# Die if I've looped too many times.
		if ($i > $an->_error_limit)
		{
			die "$THIS_FILE ".__LINE__."; Infitie loop detected will inserting variables into the string: [$parameter->{string}].\n";
		}
		$i++;
	}
	
	return($parameter->{string});
}

# This is used by the 'template()' function to insert '#!replace!...!#' replacement variables in templates.
sub _process_string_replace
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $string   = $parameter->{string};
	my $replace  = $parameter->{replace};
	my $file     = $parameter->{file};
	my $template = $parameter->{template};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "string",   value1 => $string, 
		name2 => "replace",  value2 => $replace, 
		name3 => "file",     value3 => $file, 
		name4 => "template", value4 => $template, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_string_replace" }, message_key => "an_variables_0004", message_variables => { 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $i = 0;
	while ($string =~ /#!replace!(.+?)!#/)
	{
		my $key   =  $1;
		my $value =  defined $replace->{$key} ? $replace->{$key} : "!! Undefined replacement key: [$key] !!\n";
		$string   =~ s/#!replace!$key!#/$value/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Die if I've looped too many times.
		if ($i > $an->data->{sys}{error_limit})
		{
			$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0076", message_variables => {
				file     => $file, 
				template => $template, 
			}, code => 76, file => "$THIS_FILE", line => __LINE__});
		}
		$i++;
	}
	
	return($string);
}

1;
