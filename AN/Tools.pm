package AN::Tools;
# This is the "root" package that manages the sub modules and controls access
# to their methods.
# 
# Dedicated to Leah Kubik who helped me back in the early days of TLE-BU.
# 

# Search engine that assigns a "word" to a given page that best defines that word.
# Then give each page a "rank" based on the "words" pages that link to and from that page.
# (weighted, outbound links worth ~1/10th an inbound link)

BEGIN
{
	our $VERSION = "0.1.001";
}

use strict;
use warnings;
my $THIS_FILE = "Tools.pm";

# Setup for UTF-8 mode.
use utf8;
$ENV{'PERL_UNICODE'} = 1;

# I intentionally don't use EXPORT, @ISA and the like because I want my
# "subclass"es to be accessed in a somewhat more OO style. I know some may
# wish to strike me down for this, but I like the idea of accessing methods
# via their containing module's name. (A La: $an->Module->method rather than
# $an->method).
use AN::Tools::Alert;
use AN::Tools::Check;
use AN::Tools::Convert;
use AN::Tools::DB;
use AN::Tools::Get;
use AN::Tools::Log;
use AN::Tools::Math;
use AN::Tools::Readable;
use AN::Tools::Storage;
use AN::Tools::String;

# The constructor through which all other module's methods will be accessed.
sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Tools->new()\n";
	my $class = shift;
	my $param = shift;
	my $self  = {
		HANDLE				=>	{
			ALERT				=>	AN::Tools::Alert->new(),
			CHECK				=>	AN::Tools::Check->new(),
			CONVERT				=>	AN::Tools::Convert->new(),
			DB				=>	AN::Tools::DB->new(),
			GET				=>	AN::Tools::Get->new(),
			LOG				=>	AN::Tools::Log->new(),
			MATH				=>	AN::Tools::Math->new(),
			READABLE			=>	AN::Tools::Readable->new(),
			STORAGE				=>	AN::Tools::Storage->new(),
			STRING				=>	AN::Tools::String->new(),
		},
		LOADED				=>	{
			'Math::BigInt'			=>	0,
			'IO::Handle'			=>	0,
			Fcntl				=>	0,
		},
		DATA				=>	{},
		ERROR_COUNT			=>	0,
		ERROR_LIMIT			=>	10000,
		DEFAULT				=>	{
			CONFIG_FILE			=>	'AN::Tools/an.conf',
			LANGUAGE			=>	'en_CA',
			SEARCH_DIR			=>	\@INC,
		},
		ENV_VALUES			=>	{
			ENVIRONMENT			=>	'cli',
		},
		OS_VALUES			=>	{
			DIRECTORY_DELIMITER		=>	'/',
		},
	};
	
	# Bless you!
	bless $self, $class;
	
	#print "$THIS_FILE ".__LINE__."<br />\n";
	
	# This isn't needed, but it makes the code below more consistent with
	# and portable to other modules.
	my $an = $self;
	
	# This gets handles to my other modules that the child modules will use
	# to talk to other sibling modules.
	$self->Alert->parent($self);
	$self->Check->parent($self);
	$self->Convert->parent($self);
	$self->DB->parent($self);
	$self->Get->parent($self);
	$self->Log->parent($self);
	$self->Math->parent($self);
	$self->Readable->parent($self);
	$self->Storage->parent($self);
	$self->String->parent($self);
	#print "$THIS_FILE ".__LINE__."<br />\n";
	
	# Check the operating system and set any OS-specific values.
	$self->Check->_os;
	#print "$THIS_FILE ".__LINE__."<br />\n";
	
	# This checks the environment this program is running in.
	$self->Check->_environment;
	
	# Before I do anything, read in values from the 'DEFAULT::CONFIG_FILE'
	# configuration file.
	$an->Storage->read_conf($self->{DEFAULT}{CONFIG_FILE});
	#print "$THIS_FILE ".__LINE__."<br />\n";
	
	# I need to read the initial words early.
	$self->String->read_words();
	#print "$THIS_FILE ".__LINE__."<br />\n";
	
	# 
	my $directory_delimiter = $an->_directory_delimiter();
	#print "$THIS_FILE ".__LINE__."<br />\n";
	
	# Set passed parameters if needed.
	if (ref($param) eq "HASH")
	{
		### Local parameters
		# Set the data hash
		$self->data			($param->{data}) 			if $param->{data};
		
		# Set the default language.
		$self->default_language		($param->{default_language}) 		if $param->{default_language};
		
		### AN::Tools::Readable parameters
		# Readable needs to be set before Log so that changes to
		# 'base2' are made before the default log cycle size is
		# interpreted.
		$self->Readable->base2		($param->{Readable}{base2}) 		if defined $param->{Readable}{base2};
		
		### AN::Tools::Log parameters
		# Set the log file.
		$self->Log->level		($param->{'Log'}{level}) 		if defined $param->{'Log'}{level};
		
		### AN::Tools::String parameters
		# Force UTF-8.
		$self->String->force_utf8	($param->{String}{force_utf8}) 		if defined $param->{String}{force_utf8};
		# Read in the user's words.
		$self->String->read_words({file => $param->{String}{read_words}{file}}) if defined $param->{String}{read_words}{file};
		
		### AN::Tools::Get parameters
		$an->Get->use_24h		($param->{'Get'}{use_24h})		if defined $param->{'Get'}{use_24h};
		$an->Get->say_am		($param->{'Get'}{say_am})		if defined $param->{'Get'}{say_am};
		$an->Get->say_pm		($param->{'Get'}{say_pm})		if defined $param->{'Get'}{say_pm};
		$an->Get->date_seperator	($param->{'Get'}{date_seperator})	if defined $param->{'Get'}{date_seperator};
		$an->Get->time_seperator	($param->{'Get'}{time_seperator})	if defined $param->{'Get'}{time_seperator};
	}
	
	# Call methods that need to be loaded at invocation of the module.
	#$self->String->read_words();
	
	return ($self);
}

# This sets or returns the default language the various modules use when
# processing word strings.
sub default_language
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	# This could be set before any word files are read, so no checks are
	# done here.
	$self->{DEFAULT}{LANGUAGE} = $set if $set;
	
	return ($self->{DEFAULT}{LANGUAGE});
}

# This is a shortcut to the '$an->Alert->_error_string' method allowing for
# '$an->error' to be called, saving the caller typing.
sub error
{
	my $self = shift;
	return ($self->Alert->_error_string);
}

# This is a shortcut to the '$an->Alert->_error_code' method allowing for
# '$an->error_code' to be called, saving the caller typing.
sub error_code
{
	my $self = shift;
	return ($self->Alert->_error_code);
}

# Makes my handle to AN::Tools::Alert clearer when using this module to access
# it's methods.
sub Alert
{
	my $self = shift;
	
	return ($self->{HANDLE}{ALERT});
}

# Makes my handle to AN::Tools::Check clearer when using this module to access
# it's methods.
sub Check
{
	my $self = shift;
	
	return ($self->{HANDLE}{CHECK});
}

# Makes my handle to AN::Tools::Convert clearer when using this module to access
# it's methods.
sub Convert
{
	my $self = shift;
	
	return ($self->{HANDLE}{CONVERT});
}

# Makes my handle to AN::Tools::DB clearer when using this module to access
# it's methods.
sub DB
{
	my $self = shift;
	
	return ($self->{HANDLE}{DB});
}

# Makes my handle to AN::Tools::Get clearer when using this module to access
# it's methods.
sub Get
{
	my $self = shift;
	
	return ($self->{HANDLE}{GET});
}

# This is the method used to access the main hash reference that all
# user-accessible values are stored in. This includes words, configuration file
# variables and so forth.
sub data
{
	my ($self) = shift;
	
	# Pick up the passed in hash, if any.
	$self->{DATA} = shift if $_[0];
	
	return ($self->{DATA});
}

# This sets or receives the environment the program is running in. Current
# valid values are 'cli' and 'html'.
sub environment
{
	my ($self) = shift;
	
	# Pick up the passed in delimiter, if any.
	$self->{ENV_VALUES}{ENVIRONMENT} = shift if $_[0];
	
	return ($self->{ENV_VALUES}{ENVIRONMENT});
}

# Makes my handle to AN::Tools::Log clearer when using this module to access
# it's methods.
sub Log
{
	my $self = shift;
	
	return ($self->{HANDLE}{LOG});
}

# Makes my handle to AN::Tools::Math clearer when using this module to access
# it's methods.
sub Math
{
	my $self = shift;
	
	return ($self->{HANDLE}{MATH});
}

# Makes my handle to AN::Tools::Readable clearer when using this module to
# access it's methods.
sub Readable
{
	my $self = shift;
	
	return ($self->{HANDLE}{READABLE});
}

# Makes my handle to AN::Tools::Storage clearer when using this module to
# access it's methods.
sub Storage
{
	my $self = shift;
	
	return ($self->{HANDLE}{STORAGE});
}

# Makes my handle to AN::Tools::String clearer when using this module to
# access it's methods.
sub String
{
	my $self = shift;
	
	return ($self->{HANDLE}{STRING});
}

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This is a helper to the above '_add_href' method. It is called each time a
# new string is to be created as a new hash key in the passed hash reference.
sub _add_hash_reference
{
	my $self  = shift;
	my $href1 = shift;
	my $href2 = shift;
	
	for my $key (keys %$href2)
	{
		if (ref $href1->{$key} eq 'HASH')
		{
			$self->_add_hash_reference( $href1->{$key}, $href2->{$key} );
		}
		else
		{
			$href1->{$key} = $href2->{$key};
		}
	}
}

# This returns an array reference stored in 'self' that is used to hold an
# array of directories to search for.
sub _defaut_search_dirs
{
	my $self = shift;
	
	return ($self->{DEFAULT}{SEARCH_DIR});
}

# This sets or receives the underlying operating system's directory delimiter.
sub _directory_delimiter
{
	my ($self) = shift;
	
	# Pick up the passed in delimiter, if any.
	$self->{OS_VALUES}{DIRECTORY_DELIMITER} = shift if $_[0];
	
	return ($self->{OS_VALUES}{DIRECTORY_DELIMITER});
}

# This is used to set system-wide error count, used to catch possible run-away
# loops that span functions
sub _error_count
{
	my $self = shift;
	
	$self->{ERROR_COUNT} = shift if $_[0];
	
	return ($self->{ERROR_COUNT});
}


# When a method may possibly loop indefinately, it checks an internal counter
# against the value returned here and kills the program when reached.
sub _error_limit
{
	my $self = shift;
	
	return ($self->{ERROR_LIMIT});
}

# This simply sets and/or returns the internal variable that records when the
# Fcntl module has been loaded.
sub _fcntl_loaded
{
	my $self = shift;
	my $set  = $_[0] ? shift : undef;
	
	$self->{LOADED}{Fcntl} = $set if defined $set;
	
	return ($self->{LOADED}{Fcntl});
}

# This is called when I need to parse a double-colon seperated string into two
# or more elements which represent keys in the 'conf' hash. Once suitably split
# up, the 'value' is read. For example, passing ('conf', 'foo::bar') will
# return the previously-set value 'baz'.
sub _get_hash_reference
{
	# 'href' is the hash reference I am working on.
	my $self  = shift;
	my $param = shift;
	
	die "I didn't get a hash key string, so I can't pull hash reference pointer.\n" if ref($param->{key}) ne "HASH";
	die "The hash key string: [$param->{key}] doesn't seem to be valid. It should be a string in the format 'foo::bar::baz'.\n" if $param->{key} !~ /::/;
	
	# Split up the keys.
	my @keys     = split /::/, $param->{key};
	my $last_key = pop @keys;
	
	# Re-order the array.
	my $_chref   = $self->data;
	foreach my $key (@keys)
	{
		$_chref = $_chref->{$key};
	}
	
	return ($_chref->{$last_key});
}

# This simply sets and/or returns the internal variable that records when the
# IO::Handle module has been loaded.
sub _io_handle_loaded
{
	my $self = shift;
	my $set  = $_[0] ? shift : undef;
	
	$self->{LOADED}{'IO::Handle'} = $set if defined $set;
	
	return ($self->{LOADED}{'IO::Handle'});
}

# This loads in 'Fcntl's 'flock' functions on call.
sub _load_fcntl
{
	my $self = shift;
	
	print "'eval'ing Fcntl\n";
	eval 'use Fcntl \':flock\';';
# 	eval 'use Fcntl;';
	if ($@)
	{
		$self->Alert->error({
			fatal		=>	1,
			title_key	=>	"error_title_0013",
			title_vars	=>	{
				module		=>	"Fcntl",
			},
			message_key	=>	"error_message_0021",
			message_vars	=>	{
				module		=>	"Fcntl",
				error		=>	$@,
			},
			code		=>	31,
			file		=>	"$THIS_FILE",
			line		=>	__LINE__
		});
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_fcntl_loaded(1);
	}
	
	return (0);
}

# This loads the 'Math::BigInt' module.
sub _load_io_handle
{
	my $self = shift;
	
	eval 'use IO::Handle;';
	if ($@)
	{
		$self->Alert->error({
			fatal		=>	1,
			title_key	=>	"error_title_0013",
			title_vars	=>	{
				module		=>	"IO::Handle",
			},
			message_key	=>	"error_message_0021",
			message_vars	=>	{
				module		=>	"IO::Handle",
				error		=>	$@,
			},
			code		=>	13,
			file		=>	"$THIS_FILE",
			line		=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_io_handle_loaded(1);
	}
	
	return(0);
}

# This loads the 'Math::BigInt' module.
sub _load_math_bigint
{
	my $self = shift;
	
	eval 'use Math::BigInt;';
	if ($@)
	{
		$self->Alert->error({
			fatal		=>	1,
			title_key	=>	"error_title_0013",
			title_vars	=>	{
				module		=>	"Math::BigInt",
			},
			message_key	=>	"error_message_0021",
			message_vars	=>	{
				module		=>	"Math::BigInt",
				error		=>	$@,
			},
			code		=>	9,
			file		=>	"$THIS_FILE",
			line		=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_math_bigint_loaded(1);
	}
	
	return(0);
}

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This takes a string with double-colon seperators and divides on those
# double-colons to create a hash reference where each element is a hash key.
sub _make_hash_reference
{
	my $self       = shift;
	my $href       = shift;
	my $key_string = shift;
	my $value      = shift;
	
	if ($self->{CHOMP_ROOT})
	{
		$key_string=~s/\w+:://;
	}
	
	my @keys            = split /::/, $key_string;
	my $last_key        = pop @keys;
	my $_href           = {};
	$_href->{$last_key} = $value;
	while (my $key = pop @keys)
	{
		my $elem      = {};
		$elem->{$key} = $_href;
		$_href        = $elem;
	}
	$self->_add_hash_reference($href, $_href);
}

# This simply sets and/or returns the internal variable that records when the
# Math::BigInt module has been loaded.
sub _math_bigint_loaded
{
	my $self = shift;
	my $set  = $_[0] ? shift : undef;
	
	$self->{LOADED}{'Math::BigInt'} = $set if defined $set;
	
	return ($self->{LOADED}{'Math::BigInt'});
}

1;
