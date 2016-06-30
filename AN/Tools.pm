package AN::Tools;
# 
# This is the "root" package that manages the sub modules and controls access to their methods.
# 
# Dedicated to Leah Kubik who helped me back in the early days of TLE-BU.
# 

BEGIN
{
	our $VERSION = "0.1.001";
	# This suppresses the 'could not find ParserDetails.ini in /PerlApp/XML/SAX' warning message in 
	# XML::Simple calls.
	$ENV{HARNESS_ACTIVE} = 1;
}

use strict;
use warnings;
use IO::Handle;
use XML::Simple;
my $THIS_FILE = "Tools.pm";

# Setup for UTF-8 mode.
use utf8;
$ENV{'PERL_UNICODE'} = 1;

# I intentionally don't use EXPORT, @ISA and the like because I want my "subclass"es to be accessed in a
# somewhat more OO style. I know some may wish to strike me down for this, but I like the idea of accessing
# methods via their containing module's name. (A La: $an->Module->method rather than $an->method).
use AN::Tools::Alert;
use AN::Tools::Check;
use AN::Tools::Cman;
use AN::Tools::Convert;
use AN::Tools::DB;
use AN::Tools::Get;
use AN::Tools::HardwareLSI;
use AN::Tools::InstallManifest;
use AN::Tools::Log;
use AN::Tools::Math;
use AN::Tools::MediaLibrary;
use AN::Tools::Readable;
use AN::Tools::Remote;
use AN::Tools::ScanCore;
use AN::Tools::Storage;
use AN::Tools::Striker;
use AN::Tools::String;
use AN::Tools::System;
use AN::Tools::Validate;
use AN::Tools::Web;

# The constructor through which all other module's methods will be accessed.
sub new
{
	my $class     = shift;
	my $parameter = shift;
	my $self      = {
		HANDLE				=>	{
			ALERT				=>	AN::Tools::Alert->new(),
			CHECK				=>	AN::Tools::Check->new(),
			CMAN				=>	AN::Tools::Cman->new(),
			CONVERT				=>	AN::Tools::Convert->new(),
			DB				=>	AN::Tools::DB->new(),
			GET				=>	AN::Tools::Get->new(),
			HARDWARELSI			=>	AN::Tools::HardwareLSI->new(),
			INSTALLMANIFEST			=>	AN::Tools::InstallManifest->new(),
			LOG				=>	AN::Tools::Log->new(),
			MATH				=>	AN::Tools::Math->new(),
			MEDIALIBRARY			=>	AN::Tools::MediaLibrary->new(),
			READABLE			=>	AN::Tools::Readable->new(),
			REMOTE				=>	AN::Tools::Remote->new(),
			SCANCORE			=>	AN::Tools::ScanCore->new(),
			STORAGE				=>	AN::Tools::Storage->new(),
			STRIKER				=>	AN::Tools::Striker->new(),
			STRING				=>	AN::Tools::String->new(),
			SYSTEM				=>	AN::Tools::System->new(),
			VALIDATE			=>	AN::Tools::Validate->new(),
			WEB				=>	AN::Tools::Web->new(),
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
			STRINGS				=>	'AN::tools.xml',
			CONFIG_FILE			=>	'AN::an.conf',
			LANGUAGE			=>	'en_CA',
			LOG_FILE			=>	'',
			SEARCH_DIR			=>	\@INC,
			UUIDGEN_PATH			=>	'/usr/bin/uuidgen',
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
	
	# This isn't needed, but it makes the code below more consistent with and portable to other modules.
	my $an = $self;

	# This gets handles to my other modules that the child modules will use to talk to other sibling 
	# modules.
	$an->Alert->parent($an);
	$an->Check->parent($an);
	$an->Cman->parent($an);
	$an->Convert->parent($an);
	$an->DB->parent($an);
	$an->Get->parent($an);
	$an->HardwareLSI->parent($an);
	$an->InstallManifest->parent($an);
	$an->Log->parent($an);
	$an->Math->parent($an);
	$an->MediaLibrary->parent($an);
	$an->Readable->parent($an);
	$an->Remote->parent($an);
	$an->ScanCore->parent($an);
	$an->Storage->parent($an);
	$an->Striker->parent($an);
	$an->String->parent($an);
	$an->System->parent($an);
	$an->Validate->parent($an);
	$an->Web->parent($an);
	
	# Set some system paths
	$an->_set_paths;
	
	# Check the operating system and set any OS-specific values.
	$an->Check->_os;
	
	# This checks the environment this program is running in.
	$an->Check->_environment;
	
	# Before I do anything, read in values from the 'DEFAULT::CONFIG_FILE' configuration file.
	$self->{DEFAULT}{CONFIG_FILE} = $an->Storage->find({file => $self->{DEFAULT}{CONFIG_FILE}, fatal => 1});
	$an->Storage->read_conf($an->{DEFAULT}{CONFIG_FILE});
	
	# Setup my '$an->data' hash right away so that I have a place to store the strings hash.
	$an->data($parameter->{data}) if $parameter->{data};
	
	# I need to read the initial words early.
	$self->{DEFAULT}{STRINGS} = $an->Storage->find({file => $self->{DEFAULT}{STRINGS}, fatal => 1});
	$an->Storage->read_words({file  => $self->{DEFAULT}{STRINGS}});
	
	# Set the directory delimiter
	my $directory_delimiter = $an->_directory_delimiter();
	
	# Set passed parameters if needed.
	if (ref($parameter) eq "HASH")
	{
		### Local parameters
		# Reset the paths
		$an->_set_paths;
		
		# Set the default languages.
		$an->default_language		($parameter->{default_language}) 	if $parameter->{default_language};
		$an->default_log_language	($parameter->{default_log_language}) 	if $parameter->{default_log_language};
		$an->default_log_file		($parameter->{default_log_file}) 	if $parameter->{default_log_file};	# TODO: Phase this out
		
		### AN::Tools::Readable parameters
		# Readable needs to be set before Log so that changes to 'base2' are made before the default
		# log cycle size is interpreted.
		$an->Readable->base2		($parameter->{Readable}{base2}) 	if defined $parameter->{Readable}{base2};
		
		### AN::Tools::Log parameters
		# Set the log file.
		$an->Log->level			($parameter->{'Log'}{level}) 		if defined $parameter->{'Log'}{level};
		$an->Log->db_transactions	($parameter->{'Log'}{db_transactions}) 	if defined $parameter->{'Log'}{db_transactions};
		
		### AN::Tools::String parameters
		# Force UTF-8.
		$an->String->force_utf8		($parameter->{String}{force_utf8}) 	if defined $parameter->{String}{force_utf8};
		# Read in the user's words.
		$an->Storage->read_words({file => $parameter->{String}{read_words}{file}}) if defined $parameter->{String}{read_words}{file};
		
		### AN::Tools::Get parameters
		$an->Get->use_24h		($parameter->{'Get'}{use_24h})		if defined $parameter->{'Get'}{use_24h};
		$an->Get->say_am		($parameter->{'Get'}{say_am})		if defined $parameter->{'Get'}{say_am};
		$an->Get->say_pm		($parameter->{'Get'}{say_pm})		if defined $parameter->{'Get'}{say_pm};
		$an->Get->date_seperator	($parameter->{'Get'}{date_seperator})	if defined $parameter->{'Get'}{date_seperator};
		$an->Get->time_seperator	($parameter->{'Get'}{time_seperator})	if defined $parameter->{'Get'}{time_seperator};
	}
	
	# Call methods that need to be loaded at invocation of the module.
	if (($an->{DEFAULT}{STRINGS} =~ /^\.\//) && (not -e $an->{DEFAULT}{STRINGS}))
	{
		# Try to find the location of this module (I can't use Dir::Self' because it's not provided
		# by RHEL 6)
		my $root = ($INC{'AN/Tools.pm'} =~ /^(.*?)\/AN\/Tools.pm/)[0];
		my $file = ($an->{DEFAULT}{STRINGS} =~ /^\.\/(.*)/)[0];
		my $path = "$root/$file";
		if (-e $path)
		{
			# Found the words file.
			$an->{DEFAULT}{STRINGS} = $path;
		}
	}
	if (not -e $an->{DEFAULT}{STRINGS})
	{
		print "Failed to read the core words file: [$an->{DEFAULT}{STRINGS}]\n";
		exit(255);
	}
	$an->Storage->read_words({file => $an->{DEFAULT}{STRINGS}});

	return ($self);
}

### WARNING: DO NOT CALL $an->Log->entry() in this method! It will loop because that method calls this one.
# This sets or returns the default language the various modules use when processing word strings.
sub default_language
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	# This could be set before any word files are read, so no checks are done here.
	$self->{DEFAULT}{LANGUAGE} = $set if $set;
	
	return ($self->{DEFAULT}{LANGUAGE});
}

### WARNING: DO NOT CALL $an->Log->entry() in this method! It will loop because that method calls this one.
# This sets or returns the default language the various modules use when processing word strings.
sub default_log_language
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	# This could be set before any word files are read, so no checks are done here.
	$self->{DEFAULT}{LOG_LANGUAGE} = $set if $set;
	
	return ($self->{DEFAULT}{LOG_LANGUAGE});
}

### WARNING: DO NOT CALL $an->Log->entry() in this method! It will loop because that method calls this one.
# This sets or returns the default log file.
sub default_log_file
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	# This could be set before any word files are read, so no checks are done here.
	$self->{DEFAULT}{LOG_FILE} = $set if $set;
	
	return ($self->{DEFAULT}{LOG_FILE});
}

# This is a shortcut to the '$an->Alert->_error_string' method allowing for '$an->error' to be called, saving
# the caller typing.
sub error
{
	my $self = shift;
	return ($self->Alert->_error_string);
}

# This is a shortcut to the '$an->Alert->_error_code' method allowing for '$an->error_code' to be called, 
# saving the caller typing.
sub error_code
{
	my $self = shift;
	return ($self->Alert->_error_code);
}

# This returns the hostname for the machine this is running on.
sub hostname
{
	my $self = shift;
	
	my $an = $self;
	my $hostname = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ENV{HOSTNAME}", value1 => $ENV{HOSTNAME},
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
	if ($ENV{HOSTNAME})
	{
		# We have an environment variable, so use it.
		$hostname = $ENV{HOSTNAME};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "hostname", value1 => $hostname,
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
	}
	else
	{
		# The environment variable isn't set. Can we read the host name from the network file?
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "path::hostname", value1 => $an->data->{path}{hostname},
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		if (-r $an->data->{path}{hostname})
		{
			my $shell_call = $an->data->{path}{hostname};
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__ });
			while(<$file_handle>)
			{
				chomp;
				$hostname = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "hostname", value1 => $hostname,
				}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
				last;
			}
			close $file_handle;
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "hostname", value1 => $hostname,
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
	return($hostname);
}

# This returns the domain name portion of this machine's host name (if available)
sub domain_name
{
	my $self = shift;
	
	my $an          =  $self;
	my $domain_name =  $an->hostname;
	   $domain_name =~ s/^.*?\.//;
	   $domain_name =  "" if not $domain_name;
	
	return($domain_name);
}

# This returns the short hostname for the machine this is running on. That is to say, the hostname up to the 
# first '.'.
sub short_hostname
{
	my $self = shift;
	
	my $an              =  $self;
	my $short_host_name =  $an->hostname;
	   $short_host_name =~ s/\..*$//;
	
	return($short_host_name);
}

# Makes my handle to AN::Tools::Alert clearer when using this module to access it's methods.
sub Alert
{
	my $self = shift;
	
	return ($self->{HANDLE}{ALERT});
}

# Makes my handle to AN::Tools::Check clearer when using this module to access it's methods.
sub Check
{
	my $self = shift;
	
	return ($self->{HANDLE}{CHECK});
}

# Makes my handle to AN::Tools::Cman clearer when using this module to access it's methods.
sub Cman
{
	my $self = shift;
	
	return ($self->{HANDLE}{CMAN});
}

# Makes my handle to AN::Tools::Convert clearer when using this module to access it's methods.
sub Convert
{
	my $self = shift;
	
	return ($self->{HANDLE}{CONVERT});
}

# Makes my handle to AN::Tools::DB clearer when using this module to access it's methods.
sub DB
{
	my $self = shift;
	
	return ($self->{HANDLE}{DB});
}

# Makes my handle to AN::Tools::Get clearer when using this module to access it's methods.
sub Get
{
	my $self = shift;
	
	return ($self->{HANDLE}{GET});
}

# Makes my handle to AN::Tools::HardwareLSI clearer when using this module to access it's methods.
sub HardwareLSI
{
	my $self = shift;
	
	return ($self->{HANDLE}{HARDWARELSI});
}

# Makes my handle to AN::Tools::InstallManifest clearer when using this module to access it's methods.
sub InstallManifest
{
	my $self = shift;
	
	return ($self->{HANDLE}{INSTALLMANIFEST});
}

# This is the method used to access the main hash reference that all user-accessible values are stored in. 
# This includes words, configuration file variables and so forth.
sub data
{
	my ($self) = shift;
	
	# Pick up the passed in hash, if any.
	$self->{DATA} = shift if $_[0];
	
	return ($self->{DATA});
}

# This sets or receives the environment the program is running in. Current valid values are 'cli' and 'html'.
sub environment
{
	my ($self) = shift;
	
	# Pick up the passed in delimiter, if any.
	$self->{ENV_VALUES}{ENVIRONMENT} = shift if $_[0];
	
	return ($self->{ENV_VALUES}{ENVIRONMENT});
}

# Makes my handle to AN::Tools::Log clearer when using this module to access it's methods.
sub Log
{
	my $self = shift;
	
	return ($self->{HANDLE}{LOG});
}

# Makes my handle to AN::Tools::Math clearer when using this module to access it's methods.
sub Math
{
	my $self = shift;
	
	return ($self->{HANDLE}{MATH});
}

# Makes my handle to AN::Tools::MediaLibrary clearer when using this module to access it's methods.
sub MediaLibrary
{
	my $self = shift;
	
	return ($self->{HANDLE}{MEDIALIBRARY});
}

# Makes my handle to AN::Tools::Readable clearer when using this module to access it's methods.
sub Readable
{
	my $self = shift;
	
	return ($self->{HANDLE}{READABLE});
}

# Makes my handle to AN::Tools::Remote clearer when using this module to access it's methods.
sub Remote
{
	my $self = shift;
	
	return ($self->{HANDLE}{REMOTE});
}

# Makes my handle to AN::Tools::Storage clearer when using this module to access it's methods.
sub Storage
{
	my $self = shift;
	
	return ($self->{HANDLE}{STORAGE});
}

# Makes my handle to AN::Tools::Striker clearer when using this module to access it's methods.
sub Striker
{
	my $self = shift;
	
	return ($self->{HANDLE}{STRIKER});
}

# Makes my handle to AN::Tools::String clearer when using this module to access it's methods.
sub String
{
	my $self = shift;
	
	return ($self->{HANDLE}{STRING});
}

# Makes my handle to AN::Tools::Validate clearer when using this module to access it's methods.
sub Validate
{
	my $self = shift;
	
	return ($self->{HANDLE}{VALIDATE});
}

# Makes my handle to AN::Tools::Web clearer when using this module to access it's methods.
sub Web
{
	my $self = shift;
	
	return ($self->{HANDLE}{WEB});
}

# Makes my handle to AN::Tools::ScanCore clearer when using this module to access it's methods.
sub ScanCore
{
	my $self = shift;
	
	return ($self->{HANDLE}{SCANCORE});
}

# Makes my handle to AN::Tools::System clearer when using this module to access it's methods.
sub System
{
	my $self = shift;
	
	return ($self->{HANDLE}{SYSTEM});
}

### This will be expanded later when the DB module is done. For now, it is not used.
sub nice_exit
{
	my $self      = shift;
	my $exit_code = defined $_[0] ? shift : 99;
	
	my $an = $self;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "nice_exit", }, message_key => "tools_log_0003", message_variables => { name1 => "exit_code", value1 => "$exit_code"}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file}});
	$exit_code = 99 if not $exit_code;
	
	# Close database connections
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		$an->data->{dbh}{$id}->disconnect;
	}
	
	exit($exit_code);
}

# This sets a bunch of default paths to executables and a few system files.
sub _set_paths
{
	my ($self) = shift;
	my $an = $self;
	
	### TODO: Use '$an->Storage->find()' to locate these in case they aren't found at the set location
	###       below.
	# Executables
	$an->data->{path}{awk}                 = "/bin/awk";
	$an->data->{path}{blkid}               = "/sbin/blkid";
	$an->data->{path}{brctl}               = "/usr/sbin/brctl";
	$an->data->{path}{cat}                 = "/bin/cat";
	$an->data->{path}{ccs}                 = "/usr/sbin/ccs";
	$an->data->{path}{ccs_config_validate} = "/usr/sbin/ccs_config_validate";
	$an->data->{path}{'chmod'}             = "/bin/chmod";
	$an->data->{path}{chkconfig}           = "/sbin/chkconfig";
	$an->data->{path}{'chown'}             = "/bin/chown";
	$an->data->{path}{cp}                  = "/bin/cp";
	$an->data->{path}{clustat}             = "/usr/sbin/clustat";
	$an->data->{path}{clusvcadm}           = "/usr/sbin/clusvcadm";
	$an->data->{path}{df}                  = "/bin/df";
	$an->data->{path}{dmesg}               = "/bin/dmesage";
	$an->data->{path}{dmidecode}           = "/usr/sbin/dmidecode";
	$an->data->{path}{'drbd-overview'}     = "/usr/sbin/drbd-overview";
	$an->data->{path}{drbdadm}             = "/sbin/drbdadm";
	$an->data->{path}{drbdmeta}            = "/sbin/drbdmeta";
	$an->data->{path}{echo}                = "/bin/echo";
	$an->data->{path}{expect}              = "/usr/bin/expect";
	$an->data->{path}{fence_check}         = "/usr/sbin/fence_check";
	$an->data->{path}{fence_node}          = "/usr/sbin/fence_node";
	$an->data->{path}{'grep'}              = "/bin/grep";
	$an->data->{path}{gethostip}           = "/usr/bin/gethostip";
	$an->data->{path}{gfs2_tool}           = "/usr/sbin/gfs2_tool";
	$an->data->{path}{hostname}            = "/bin/hostname";
	$an->data->{path}{ip}                  = "/sbin/ip";
	$an->data->{path}{ipmitool}            = "/usr/bin/ipmitool";
	$an->data->{path}{'iptables-save'}     = "/sbin/iptables-save";
	$an->data->{path}{'less'}              = "/usr/bin/less";
	$an->data->{path}{ln}                  = "/bin/ln";
	$an->data->{path}{ls}                  = "/bin/ls";
	$an->data->{path}{lsblk}               = "/bin/lsblk";
	$an->data->{path}{lsmod}               = "/sbin/lsmod";
	$an->data->{path}{lvchange}            = "/sbin/lvchange";
	$an->data->{path}{lvcreate}            = "/sbin/lvcreate";
	$an->data->{path}{lvremove}            = "/sbin/lvremove";
	$an->data->{path}{lvs}                 = "/sbin/lvs";
	$an->data->{path}{lvscan}              = "/sbin/lvscan";
	$an->data->{path}{mailx}               = "/bin/mailx";
	$an->data->{path}{megacli64}           = "/sbin/MegaCli64";
	$an->data->{path}{'mkfs.gfs2'}         = "/sbin/mkfs.gfs2";
	$an->data->{path}{modprobe}            = "/sbin/modprobe";
	$an->data->{path}{mount}               = "/bin/mount";
	$an->data->{path}{'mkdir'}             = "/bin/mkdir";
	$an->data->{path}{mv}                  = "/bin/mv";
	$an->data->{path}{parted}              = "/sbin/parted";
	$an->data->{path}{passwd}              = "/usr/bin/passwd";
	$an->data->{path}{perl}                = "/usr/bin/perl";
	$an->data->{path}{pg_dump}             = "/usr/bin/pg_dump";
	$an->data->{path}{'ping'}              = "/bin/ping";
	$an->data->{path}{pkill}               = "/usr/bin/pkill";
	$an->data->{path}{postfix_main}        = "/etc/postfix/main.cf";
	$an->data->{path}{postfix_relay_file}  = "/etc/postfix/relay_password";
	$an->data->{path}{postmap}             = "/usr/sbin/postmap";
	$an->data->{path}{pgrep}               = "/usr/bin/pgrep";
	$an->data->{path}{psql}                = "/usr/bin/psql";
	$an->data->{path}{pmap}                = "/usr/bin/pmap";
	$an->data->{path}{poweroff}            = "/sbin/poweroff";
	$an->data->{path}{ps}                  = "/bin/ps";
	$an->data->{path}{pvchange}            = "/sbin/pvchange";
	$an->data->{path}{pvcreate}            = "/sbin/pvcreate";
	$an->data->{path}{pvscan}              = "/sbin/pvscan";
	$an->data->{path}{pvs}                 = "/sbin/pvs";
	$an->data->{path}{reboot}              = "/sbin/reboot";
	$an->data->{path}{restorecon}          = "/sbin/restorecon";
	$an->data->{path}{rhn_check}           = "/usr/sbin/rhn_check";
	$an->data->{path}{'rhn-channel'}       = "/usr/sbin/rhn-channel";
	$an->data->{path}{rhnreg_ks}           = "/usr/sbin/rhnreg_ks";
	$an->data->{path}{rm}                  = "/bin/rm";
	$an->data->{path}{semanage}            = "/usr/sbin/semanage";
	$an->data->{path}{route}               = "/sbin/route";
	$an->data->{path}{rsync}               = "/usr/bin/rsync";
	$an->data->{path}{sed}                 = "/bin/sed";
	$an->data->{path}{'sleep'}             = "/bin/sleep";	# Used in bash calls
	$an->data->{path}{ssh}                 = "/usr/bin/ssh";
	$an->data->{path}{'ssh-keygen'}        = "/usr/bin/ssh-keygen";
	$an->data->{path}{'ssh-keyscan'}       = "/usr/bin/ssh-keyscan";
	$an->data->{path}{'ssh-copy-id'}       = "/usr/bin/ssh-copy-id";
	$an->data->{path}{storcli64}           = "/sbin/storcli64";
	$an->data->{path}{timeout}             = "/usr/bin/timeout";
	$an->data->{path}{uuidgen}             = "/usr/bin/uuidgen";
	$an->data->{path}{touch}               = "/bin/touch";
	$an->data->{path}{'virt-manager'}      = "/usr/bin/virt-manager";
	$an->data->{path}{vgchange}            = "/sbin/vgchange";
	$an->data->{path}{vgcreate}            = "/sbin/vgcreate";
	$an->data->{path}{vgscan}              = "/sbin/vgscan";
	$an->data->{path}{vgs}                 = "/sbin/vgs";
	$an->data->{path}{virsh}               = "/usr/bin/virsh";
	$an->data->{path}{wc}                  = "/usr/bin/wc";
	$an->data->{path}{wget}                = "/usr/bin/wget";
	$an->data->{path}{whereis}             = "/usr/bin/whereis";
	$an->data->{path}{yum}                 = "/usr/bin/yum";
	
	# Text files
	$an->data->{path}{'anvil-jobs'}     = "/tmp/anvil.jobs";
	$an->data->{path}{cman_config}      = "/etc/cluster/cluster.conf";
	$an->data->{path}{dhcpd_conf}       = "/etc/dhcp/dhcpd.conf";
	$an->data->{path}{etc_fstab}        = "/etc/fstab";
	$an->data->{path}{etc_hosts}        = "/etc/hosts";
	$an->data->{path}{etc_passwd}       = "/etc/passwd";
	$an->data->{path}{etc_virbr0}       = "/etc/libvirt/qemu/networks/default.xml";
	$an->data->{path}{gdm_presession}   = "/etc/gdm/PreSession/Default";
	$an->data->{path}{host_uuid}        = "/etc/striker/host.uuid";
	$an->data->{path}{logrotate_config} = "/etc/logrotate.d/anvil";
	$an->data->{path}{ssh_config}       = "/etc/ssh/ssh_config";
	$an->data->{path}{root_crontab}     = "/var/spool/cron/root";
	
	# This is a text file with '#!token!#' replaced with a job's UUID token when running Anvil! jobs from 'anvil-run-jobs'
	$an->data->{path}{'anvil-jobs-output'} = "/tmp/anvil-job.#!token!#.txt";
	
	# /proc stuff
	$an->data->{path}{proc_bonding} = "/proc/net/bonding";
	$an->data->{path}{proc_drbd}    = "/proc/drbd";
	$an->data->{path}{proc_meminfo} = "/proc/meminfo";
	$an->data->{path}{proc_sysrq}   = "/proc/sysrq-trigger";
	$an->data->{path}{proc_uptime}  = "/proc/uptime";
	$an->data->{path}{proc_virbr0}  = "/proc/sys/net/ipv4/conf/virbr0";

	# Directories
	$an->data->{path}{alert_emails}       = "/var/log/alert_emails";
	$an->data->{path}{alert_files}        = "/var/log";
	$an->data->{path}{fence_agents}       = "/usr/sbin";
	$an->data->{path}{initd}              = "/etc/init.d";
	$an->data->{path}{shared}             = "/shared";
	$an->data->{path}{shared_archive}     = "/shared/archive";
	$an->data->{path}{shared_definitions} = "/shared/definitions";
	$an->data->{path}{shared_files}       = "/shared/files";
	$an->data->{path}{shared_privision}   = "/shared/provision";
	$an->data->{path}{skins}              = "/var/www/html/skins";
	$an->data->{path}{striker_backups}    = "/root/anvil";
	$an->data->{path}{striker_tools}      = "/sbin/striker";
	$an->data->{path}{yum_repos}          = "/etc/yum.repos.d";
	
	# Tools
	$an->data->{path}{'anvil-boot-server'}         = "/sbin/striker/anvil-boot-server";
	$an->data->{path}{'anvil-kick-apc-ups'}        = "/sbin/striker/anvil-kick-apc-ups";
	$an->data->{path}{'anvil-run-jobs'}            = "/sbin/striker/anvil-run-jobs";
	$an->data->{path}{'anvil-map-network'}         = "/sbin/striker/anvil-map-network";
	$an->data->{path}{'anvil-migrate-server'}      = "/sbin/striker/anvil-migrate-server";
	$an->data->{path}{'anvil-report-ipmi-details'} = "/sbin/striker/anvil-report-ipmi-details";	# Deprecated, will be deleted soon
	$an->data->{path}{'anvil-report-memory'}       = "/sbin/striker/anvil-report-memory";
	$an->data->{path}{'anvil-safe-start'}          = "/sbin/striker/anvil-safe-start";
	$an->data->{path}{'anvil-safe-start_link'}     = "/etc/rc3.d/S99_anvil-safe-start";
	$an->data->{path}{'anvil-safe-stop'}           = "/sbin/striker/anvil-safe-stop";
	$an->data->{path}{'anvil-stop-server'}         = "/sbin/striker/anvil-stop-server";
	$an->data->{path}{'striker-push-ssh'}          = "/sbin/striker/striker-push-ssh";
	$an->data->{path}{ScanCore}                    = "/sbin/striker/ScanCore/ScanCore";
	
	# setuid tools
	$an->data->{path}{'call_striker-manage-install-target'} = "/sbin/striker/call_striker-manage-install-target";
	
	# Lock files
	$an->data->{path}{gfs2_lock} = "/var/lock/subsys/gfs2";
	
	return(0);
}

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This is a helper to the above '_add_href' method. It is called each time a new string is to be created as a
# new hash key in the passed hash reference.
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

# This returns an array reference stored in 'self' that is used to hold an array of directories to search 
# for.
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

# This sets or receives the path to the 'uuidgen' program
sub _uuidgen_path
{
	my ($self) = shift;
	
	# Pick up the passed path, if any.
	$self->{DEFAULT}{UUIDGEN_PATH} = shift if $_[0];
	
	return ($self->{DEFAULT}{UUIDGEN_PATH});
}

# This sets or receives the path to the 'uuidgen' program
sub _log_db_transactions
{
	my ($self) = shift;
	
	# Pick up the passed path, if any.
	$self->{DEFAULT}{LOG_DB_TRANSACTIONS} = shift if $_[0];
	
	return ($self->{DEFAULT}{LOG_DB_TRANSACTIONS});
}

# This stores the error count.
sub _error_count
{
	my ($self) = shift;
	
	# Pick up the passed path, if any.
	$self->{ERROR_COUNT} = shift if $_[0];
	
	return ($self->{ERROR_COUNT});
}

# When a method may possibly loop indefinately, it checks an internal counter against the value returned here
# and kills the program when reached.
sub _error_limit
{
	my $self = shift;
	
	return ($self->{ERROR_LIMIT});
}

# This simply sets and/or returns the internal variable that records when the Fcntl module has been loaded.
sub _fcntl_loaded
{
	my $self = shift;
	my $set  = $_[0] ? shift : undef;
	
	$self->{LOADED}{Fcntl} = $set if defined $set;
	
	return ($self->{LOADED}{Fcntl});
}

# This is called when I need to parse a double-colon seperated string into two or more elements which 
# represent keys in the 'conf' hash. Once suitably split up, the 'value' is read. For example, passing
# ('conf', 'foo::bar') will return the previously-set value 'baz'.
sub _get_hash_reference
{
	# 'href' is the hash reference I am working on.
	my $self  = shift;
	my $parameter = shift;
	my $an    = $self;
	
	#print "$THIS_FILE ".__LINE__."; hash: [".$an."], key: [$parameter->{key}]\n";
	die "$THIS_FILE ".__LINE__."; The hash key string: [$parameter->{key}] doesn't seem to be valid. It should be a string in the format 'foo::bar::baz'.\n" if $parameter->{key} !~ /::/;
	
	# Split up the keys.
	my @keys     = split /::/, $parameter->{key};
	my $last_key = pop @keys;
	
	# Re-order the array.
	my $_chref   = $an->data;
	foreach my $key (@keys)
	{
		$_chref = $_chref->{$key};
	}
	
	return ($_chref->{$last_key});
}

# This simply sets and/or returns the internal variable that records when the IO::Handle module has been
# loaded.
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
			fatal			=>	1,
			title_key		=>	"error_title_0013",
			title_variables		=>	{
				module			=>	"Fcntl",
			},
			message_key		=>	"error_message_0021",
			message_variables	=>	{
				module			=>	"Fcntl",
				error			=>	$@,
			},
			code			=>	31,
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
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
			fatal			=>	1,
			title_key		=>	"error_title_0013",
			title_variables		=>	{
				module			=>	"IO::Handle",
			},
			message_key		=>	"error_message_0021",
			message_variables	=>	{
				module			=>	"IO::Handle",
				error			=>	$@,
			},
			code			=>	13,
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
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
			fatal			=>	1,
			title_key		=>	"error_title_0013",
			title_variables		=>	{
				module			=>	"Math::BigInt",
			},
			message_key		=>	"error_message_0021",
			message_variables	=>	{
				module			=>	"Math::BigInt",
				error			=>	$@,
			},
			code			=>	9,
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
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
# This takes a string with double-colon seperators and divides on those double-colons to create a hash
# reference where each element is a hash key.
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

# This simply sets and/or returns the internal variable that records when the Math::BigInt module has been 
# loaded.
sub _math_bigint_loaded
{
	my $self = shift;
	my $set  = $_[0] ? shift : undef;
	
	$self->{LOADED}{'Math::BigInt'} = $set if defined $set;
	
	return ($self->{LOADED}{'Math::BigInt'});
}

1;
