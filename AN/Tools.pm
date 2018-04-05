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
	
	# Set some system paths and system default variables
	$an->_set_paths;
	$an->_set_defaults;
	
	# Check the operating system and set any OS-specific values.
	$an->Check->_os;
	
	# This checks the environment this program is running in.
	$an->Check->_environment;
	
	# Before I do anything, read in values from the 'DEFAULT::CONFIG_FILE' configuration file.
	$self->{DEFAULT}{CONFIG_FILE} = $an->Storage->find({file => $self->{DEFAULT}{CONFIG_FILE}, fatal => 1});
	$an->Storage->read_conf({file => $an->{DEFAULT}{CONFIG_FILE} });
	
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
		# Try to find the location of this module (I can't use Dir::Self' because it is not provided
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
		print "Failed to read the core words file: [".$an->{DEFAULT}{STRINGS}."]\n";
		$an->nice_exit({exit_code => 255});
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
	
	my $an       = $self;
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
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__ });
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

# Makes my handle to AN::Tools::Alert clearer when using this module to access its methods.
sub Alert
{
	my $self = shift;
	
	return ($self->{HANDLE}{ALERT});
}

# Makes my handle to AN::Tools::Check clearer when using this module to access its methods.
sub Check
{
	my $self = shift;
	
	return ($self->{HANDLE}{CHECK});
}

# Makes my handle to AN::Tools::Cman clearer when using this module to access its methods.
sub Cman
{
	my $self = shift;
	
	return ($self->{HANDLE}{CMAN});
}

# Makes my handle to AN::Tools::Convert clearer when using this module to access its methods.
sub Convert
{
	my $self = shift;
	
	return ($self->{HANDLE}{CONVERT});
}

# Makes my handle to AN::Tools::DB clearer when using this module to access its methods.
sub DB
{
	my $self = shift;
	
	return ($self->{HANDLE}{DB});
}

# Makes my handle to AN::Tools::Get clearer when using this module to access its methods.
sub Get
{
	my $self = shift;
	
	return ($self->{HANDLE}{GET});
}

# Makes my handle to AN::Tools::HardwareLSI clearer when using this module to access its methods.
sub HardwareLSI
{
	my $self = shift;
	
	return ($self->{HANDLE}{HARDWARELSI});
}

# Makes my handle to AN::Tools::InstallManifest clearer when using this module to access its methods.
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

# Makes my handle to AN::Tools::Log clearer when using this module to access its methods.
sub Log
{
	my $self = shift;
	
	return ($self->{HANDLE}{LOG});
}

# Makes my handle to AN::Tools::Math clearer when using this module to access its methods.
sub Math
{
	my $self = shift;
	
	return ($self->{HANDLE}{MATH});
}

# Makes my handle to AN::Tools::MediaLibrary clearer when using this module to access its methods.
sub MediaLibrary
{
	my $self = shift;
	
	return ($self->{HANDLE}{MEDIALIBRARY});
}

# Makes my handle to AN::Tools::Readable clearer when using this module to access its methods.
sub Readable
{
	my $self = shift;
	
	return ($self->{HANDLE}{READABLE});
}

# Makes my handle to AN::Tools::Remote clearer when using this module to access its methods.
sub Remote
{
	my $self = shift;
	
	return ($self->{HANDLE}{REMOTE});
}

# Makes my handle to AN::Tools::Storage clearer when using this module to access its methods.
sub Storage
{
	my $self = shift;
	
	return ($self->{HANDLE}{STORAGE});
}

# Makes my handle to AN::Tools::Striker clearer when using this module to access its methods.
sub Striker
{
	my $self = shift;
	
	return ($self->{HANDLE}{STRIKER});
}

# Makes my handle to AN::Tools::String clearer when using this module to access its methods.
sub String
{
	my $self = shift;
	
	return ($self->{HANDLE}{STRING});
}

# Makes my handle to AN::Tools::Validate clearer when using this module to access its methods.
sub Validate
{
	my $self = shift;
	
	return ($self->{HANDLE}{VALIDATE});
}

# Makes my handle to AN::Tools::Web clearer when using this module to access its methods.
sub Web
{
	my $self = shift;
	
	return ($self->{HANDLE}{WEB});
}

# Makes my handle to AN::Tools::ScanCore clearer when using this module to access its methods.
sub ScanCore
{
	my $self = shift;
	
	return ($self->{HANDLE}{SCANCORE});
}

# Makes my handle to AN::Tools::System clearer when using this module to access its methods.
sub System
{
	my $self = shift;
	
	return ($self->{HANDLE}{SYSTEM});
}

### This will be expanded later when the DB module is done. For now, it is not used.
sub nice_exit
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self;
	
	my $exit_code = defined $parameter->{exit_code} ? $parameter->{exit_code} : 999;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "nice_exit" }, message_key => "tools_log_0003", message_variables => { name1 => "exit_code", value1 => $exit_code}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file}});
	
	# Close database connections (if any).
	$an->DB->disconnect_from_databases();
	
	# If this is a browser calling us, print the footer so that the loading pinwheel goes away.
	if (($ENV{'HTTP_REFERER'}) && (not $an->data->{sys}{footer_printed}))
	{
		$an->Striker->_footer();
	}
	
	exit($exit_code);
}

# This sets a bunch of default values used in several callers. All can be overriden in config files later.
sub _set_defaults
{
	my ($self) = shift;
	my $an     = $self;
	
	# This is a consolidation of the '_initialize_an()' function that used to be called by CGI scripts.
	$an->data->{args}{check_dvd}  = "--dvd --no-cddb --no-device-info --no-disc-mode --no-vcd";
	$an->data->{args}{rsync}      = "-av --partial";
	$an->data->{check_using_node} = "";
	$an->data->{online_nodes}     = [];
	$an->data->{handles}{'log'}   = "";
	$an->data->{'log'}{file}      = "/var/log/striker.log";
	$an->data->{'log'}{language}  = "en_CA";
	$an->data->{'log'}{level}     = 1;
	$an->data->{sys}{log_level}   = 1;
	$an->data->{online_nodes}     = [];
	
	### TODO: Phase all this out...
	# These are files on nodes, not on the dashboard machin itself.
	$an->data->{path}{nodes}{'anvil-adjust-vnet'}     = "/sbin/striker/anvil-adjust-vnet";
	$an->data->{path}{nodes}{'anvil-kick-apc-ups'}    = "/sbin/striker/anvil-kick-apc-ups";
	$an->data->{path}{nodes}{'anvil-safe-start'}      = "/sbin/striker/anvil-safe-start";
	# This is the actual DRBD wait script
	$an->data->{path}{nodes}{'anvil-wait-for-drbd'}   = "/sbin/striker/anvil-wait-for-drbd";
	$an->data->{path}{nodes}{backups}                 = "/root/backups";
	$an->data->{path}{nodes}{bcn_bond1_config}        = "/etc/sysconfig/network-scripts/ifcfg-bcn_bond1";
	$an->data->{path}{nodes}{bcn_link1_config}        = "/etc/sysconfig/network-scripts/ifcfg-bcn_link1";
	$an->data->{path}{nodes}{bcn_link2_config}        = "/etc/sysconfig/network-scripts/ifcfg-bcn_link2";
	$an->data->{path}{nodes}{cat}                     = "/bin/cat";
	$an->data->{path}{nodes}{cluster_conf}            = "/etc/cluster/cluster.conf";
	$an->data->{path}{nodes}{cron_root}               = "/var/spool/cron/root";
	$an->data->{path}{nodes}{drbd}                    = "/etc/drbd.d";
	$an->data->{path}{nodes}{drbd_global_common}      = "/etc/drbd.d/global_common.conf";
	$an->data->{path}{nodes}{drbd_r0}                 = "/etc/drbd.d/r0.res";
	$an->data->{path}{nodes}{drbd_r1}                 = "/etc/drbd.d/r1.res";
	$an->data->{path}{nodes}{drbdadm}                 = "/sbin/drbdadm";
	$an->data->{path}{nodes}{fstab}                   = "/etc/fstab";
	$an->data->{path}{nodes}{getsebool}               = "/usr/sbin/getsebool";
	$an->data->{path}{nodes}{'grep'}                  = "/bin/grep";
	# This stores this node's UUID. It is used to track all our sensor data in the
	# database. If you change this here, change it in the ScanCore, too.
	$an->data->{path}{nodes}{host_uuid}               = "/etc/striker/host.uuid";
	$an->data->{path}{nodes}{hostname}                = "/etc/sysconfig/network";
	$an->data->{path}{nodes}{hosts}                   = "/etc/hosts";
	$an->data->{path}{nodes}{ifcfg_directory}         = "/etc/sysconfig/network-scripts/";
	$an->data->{path}{nodes}{ifn_bond1_config}        = "/etc/sysconfig/network-scripts/ifcfg-ifn_bond1";
	$an->data->{path}{nodes}{ifn_bridge1_config}      = "/etc/sysconfig/network-scripts/ifcfg-ifn_bridge1";
	$an->data->{path}{nodes}{ifn_link1_config}        = "/etc/sysconfig/network-scripts/ifcfg-ifn_link1";
	$an->data->{path}{nodes}{ifn_link2_config}        = "/etc/sysconfig/network-scripts/ifcfg-ifn_link2";
	$an->data->{path}{nodes}{iptables}                = "/etc/sysconfig/iptables";
	$an->data->{path}{nodes}{lvm_conf}                = "/etc/lvm/lvm.conf";
	$an->data->{path}{nodes}{MegaCli64}               = "/opt/MegaRAID/MegaCli/MegaCli64";
	$an->data->{path}{nodes}{network_scripts}         = "/etc/sysconfig/network-scripts";
	$an->data->{path}{nodes}{ntp_conf}                = "/etc/ntp.conf";
	$an->data->{path}{nodes}{perl_library}            = "/usr/share/perl5";
	$an->data->{path}{nodes}{post_install}            = "/root/post_install";
	$an->data->{path}{nodes}{'anvil-safe-start'}      = "/sbin/striker/anvil-safe-start";
	# Used to verify it was enabled properly.
	$an->data->{path}{nodes}{'anvil-safe-start_link'} = "/etc/rc3.d/S99_anvil-safe-start";
	$an->data->{path}{nodes}{scancore}                = "/sbin/striker/ScanCore/ScanCore";
	$an->data->{path}{nodes}{sed}                     = "/bin/sed";
	$an->data->{path}{nodes}{setsebool}               = "/usr/sbin/setsebool";
	$an->data->{path}{nodes}{shadow}                  = "/etc/shadow";
	$an->data->{path}{nodes}{shared_subdirectories}   = ["definitions", "provision", "archive", "files", "status"];
	$an->data->{path}{nodes}{sn_bond1_config}         = "/etc/sysconfig/network-scripts/ifcfg-sn_bond1";
	$an->data->{path}{nodes}{sn_link1_config}         = "/etc/sysconfig/network-scripts/ifcfg-sn_link1";
	$an->data->{path}{nodes}{sn_link2_config}         = "/etc/sysconfig/network-scripts/ifcfg-sn_link2";
	$an->data->{path}{nodes}{storcli64}               = "/opt/MegaRAID/storcli/storcli64";
	$an->data->{path}{nodes}{striker_config}          = "/etc/striker/striker.conf";
	$an->data->{path}{nodes}{striker_tarball}         = "/sbin/striker/striker_tools.tar.bz2";
	$an->data->{path}{nodes}{tar}                     = "/bin/tar";
	$an->data->{path}{nodes}{udev_net_rules}          = "/etc/udev/rules.d/70-persistent-net.rules";
	$an->data->{path}{nodes}{udev_vnet_rules}         = "/etc/udev/rules.d/99-anvil-adjust-vnet.rules";
	# This is the LSB wrapper.
	$an->data->{path}{nodes}{'wait-for-drbd'}         = "/sbin/striker/wait-for-drbd";
	$an->data->{path}{nodes}{'wait-for-drbd_initd'}   = "/etc/init.d/wait-for-drbd";
	
	# ScanCore things set here are meant to be overwritable by the user in striker.conf.
	$an->data->{scancore}{archive}{save_to_disk}           = 0;
	$an->data->{scancore}{archive}{directory}              = "/var/ScanCore/archives/";
	$an->data->{scancore}{archive}{trigger}                = 100000;
	$an->data->{scancore}{archive}{count}                  = 50000;
	$an->data->{scancore}{dashboard}{dlm_hung_timeout}     = 300;
	$an->data->{scancore}{archive}{division}               = 60000;
	$an->data->{scancore}{disable}{boot_nodes}             = 0;
	$an->data->{scancore}{disable}{load_shedding}          = 0;
	$an->data->{scancore}{disable}{power_shutdown}         = 0;
	$an->data->{scancore}{disable}{preventative_migration} = 0;
	$an->data->{scancore}{disable}{thermal_shutdown}       = 0;
	$an->data->{scancore}{enabled}                         = 1;
	$an->data->{scancore}{language}                        = "en_CA";
	$an->data->{scancore}{locking}{reap_age}               = 300;
	$an->data->{scancore}{log_db_transactions}             = 0;
	$an->data->{scancore}{log_file}                        = "/var/log/ScanCore.log";
	$an->data->{scancore}{log_level}                       = 2;
	$an->data->{scancore}{log_language}                    = "en_CA";
	$an->data->{scancore}{maximum_ram}                     = 1073741824;
	$an->data->{scancore}{minimum_ups_runtime}             = 600;
	$an->data->{scancore}{minimum_safe_charge}             = 45;
	$an->data->{scancore}{health}{migration_delay}         = 120;
	$an->data->{scancore}{power}{load_shed_delay}          = 300;
	$an->data->{scancore}{sleep_time}                      = 60;
	$an->data->{scancore}{temperature}{load_shed_delay}    = 120;
	$an->data->{scancore}{temperature}{shutdown_limit}     = 5;
	$an->data->{scancore}{thermal_reboot_delay}{'1'}       = 600;
	$an->data->{scancore}{thermal_reboot_delay}{'2'}       = 1800;
	$an->data->{scancore}{thermal_reboot_delay}{'3'}       = 3600;
	$an->data->{scancore}{thermal_reboot_delay}{'4'}       = 7200;
	$an->data->{scancore}{thermal_reboot_delay}{more}      = 21600;
	$an->data->{scancore}{update_age_limit}                = 1200;
	
	# Generic scan agent stuff
	$an->data->{'scan-ipmitool'}{offline_sensor_list}      = "Ambient,Systemboard";
	
	# Striker stuff
	$an->data->{striker}{log_db_transactions}              = 0;
	$an->data->{striker}{email}{use_server}                = "";
	$an->data->{striker}{email}{notify}                    = "";
	
	# Remote USB stuff
	$an->data->{'remote-usb'}{enable_remote_usb_mount}     = 0;
	$an->data->{'remote-usb'}{'local'}{host}               = "#!short_hostname!#";
	$an->data->{'remote-usb'}{'local'}{user}               = "root";
	$an->data->{'remote-usb'}{'local'}{password}           = "";
	$an->data->{'remote-usb'}{'local'}{mount}              = "/mnt/remote";
	$an->data->{'remote-usb'}{'local'}{export_options}     = "-i -o rw,sync,no_root_squash";
	$an->data->{'remote-usb'}{remote}{host}                = "";
	$an->data->{'remote-usb'}{remote}{user}                = "root";
	$an->data->{'remote-usb'}{remote}{password}            = "";
	$an->data->{'remote-usb'}{remote}{mount}               = "/mnt/remote";
	$an->data->{'remote-usb'}{remote}{mount_options}       = "-t nfs -o sync";
	$an->data->{'remote-usb'}{luks}{passphrase}            = "";
	$an->data->{'remote-usb'}{luks}{force_initialize}      = 0;
	$an->data->{'remote-usb'}{luks}{use_filesystem}        = "ext4";
	$an->data->{'remote-usb'}{luks}{fs_label}              = "anvil";
	$an->data->{'remote-usb'}{luks}{fs_options}            = "-L #!variable!fs_label!#";
	$an->data->{'remote-usb'}{luks}{protected_label}       = "protect";
	
	# The actual strings hash
	$an->data->{string}               = {};
	# Config values needed to managing strings
	$an->data->{strings}{encoding}    = "";
	$an->data->{strings}{force_utf8}  = 1;
	$an->data->{strings}{xml_version} = "";
	
	### General system stuff
	# Some actions, like powering off servers and nodes, have a timeout set so that later, reloading the
	# page doesn't reload a previous confirmation URL and reinitiate the power off when it wasn't 
	# desired. This defines that timeout in seconds.
	$an->data->{sys}{expire_timeout}                   = 180;
	# These two options are used when a manual "power cycle system" is requested. They override the 
	# default power-off delay and sleep time.
	$an->data->{sys}{apc}{reboot}{power_off_delay}     = 60;
	$an->data->{sys}{apc}{reboot}{sleep_time}          = 60;
	$an->data->{sys}{apc}{'shutdown'}{power_off_delay} = 60;
	# If you enable 'anvil-kick-apc-ups', this will control how often the UPSes are "kicked".
	$an->data->{sys}{apc}{ups}{kick_frequency}         = 60;
	# This will control how far in the future to tell the UPS to shut off. 
	$an->data->{sys}{apc}{ups}{power_off_delay}        = 600;
	# If the timer runs out and the UPS shuts down, this controls how long the UPS "sleeps" for before 
	# turning back on.
	$an->data->{sys}{apc}{ups}{sleep_time}             = 60;
	$an->data->{sys}{auto_populate_ssh_users}          = "";
	$an->data->{sys}{backup_url}                       = "/striker-backup_#!hostname!#_#!date!#.txt";
	$an->data->{sys}{clustat_timeout}                  = 120;
	$an->data->{sys}{cluster_conf}                     = "";
	$an->data->{sys}{config_read}                      = 0;
	$an->data->{sys}{daemons}{enable}                  = [
		"gpm",		# LSB compliant
		"ipmi",		# NOT LSB compliant! 0 == running, 6 == stopped
		"iptables",	# LSB compliant
		"irqbalance",	# LSB compliant
		"ktune",	# LSB compliant
		"modclusterd",	# LSB compliant
		"network",	# Does NOT appear to be LSB compliant; returns '0' for 'stopped'
		"ntpd",		# LSB compliant
		"ntpdate",
		"ricci",	# LSB compliant
		"snmpd",
		"tuned",	# LSB compliant
	];
	$an->data->{sys}{daemons}{disable}                 = [
		"acpid",
		"clvmd",	# Appears to be LSB compliant
		"cman",		#
		"drbd",		#
		"gfs2",		#
		"ip6tables",	#
		"ipmidetectd",	# Not needed on the Anvil!
		"libvirt-guests",
		"numad",	# LSB compliant
		"rgmanager",	#
		"snmptrapd",	#
		"systemtap",	#
	];
	$an->data->{sys}{date_seperator}                   = "-",	# Should put these in the strings.xml file
	$an->data->{sys}{db}{maximum_batch_size}           = 25000;
	$an->data->{sys}{dd_block_size}                    = "1M";
	$an->data->{sys}{debug}                            = 1;
	$an->data->{sys}{'default'}{migration_type}        = "live";
	# When set to '1', (almost) all external links will be disabled. Useful for sites without an Internet
	# connection.
	$an->data->{sys}{disable_links}                    = 0;
	$an->data->{sys}{error_limit}                      = 10000;
	# This will significantly cut down on the text shown on the screen to make information more 
	# digestable for experts.
	$an->data->{sys}{expert_ui}                        = 0;
	$an->data->{sys}{footer_printed}                   = 0;
	$an->data->{sys}{html_lang}                        = "en";
	$an->data->{sys}{ignore_missing_vm}                = 0;
	
	# These options control some of the Install Manifest options. They can be overwritten by adding 
	# matching entries is striker.conf.
	$an->data->{sys}{install_manifest}{'default'}{bcn_ethtool_opts}                = "";
	$an->data->{sys}{install_manifest}{'default'}{bcn_network}                     = "10.20.0.0";
	$an->data->{sys}{install_manifest}{'default'}{bcn_subnet}                      = "255.255.0.0";
	$an->data->{sys}{install_manifest}{'default'}{bcn_defroute}                    = "no";
	$an->data->{sys}{install_manifest}{'default'}{cluster_name}                    = "anvil";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-barrier'}  = "false";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-flushes'}  = "false";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_md-flushes'}    = "false";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_c-plan-ahead'}  = "7";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_c-max-rate'}    = "110M";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_c-min-rate'}    = "30M";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_c-fill-target'} = "1M";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_options_cpu-mask'}   = "";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_max-buffers'}    = "";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_sndbuf-size'}    = "";
	$an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_rcvbuf-size'}    = "";
	$an->data->{sys}{install_manifest}{'default'}{dns1}                            = "8.8.8.8";
	$an->data->{sys}{install_manifest}{'default'}{dns2}                            = "8.8.4.4";
	$an->data->{sys}{install_manifest}{'default'}{domain}                          = "";
	$an->data->{sys}{install_manifest}{'default'}{ifn_ethtool_opts}                = "";
	$an->data->{sys}{install_manifest}{'default'}{ifn_gateway}                     = "";
	$an->data->{sys}{install_manifest}{'default'}{ifn_network}                     = "10.255.0.0";
	$an->data->{sys}{install_manifest}{'default'}{ifn_subnet}                      = "255.255.0.0";
	$an->data->{sys}{install_manifest}{'default'}{ifn_defroute}                    = "yes";
	$an->data->{sys}{install_manifest}{'default'}{'immediate-uptodate'}            = 0;
	$an->data->{sys}{install_manifest}{'default'}{library_size}                    = "40";
	$an->data->{sys}{install_manifest}{'default'}{library_unit}                    = "GiB";
	$an->data->{sys}{install_manifest}{'default'}{mtu_size}                        = 1500;
	$an->data->{sys}{install_manifest}{'default'}{name}                            = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_bcn_ip}                    = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_ifn_ip}                    = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_ipmi_ip}                   = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_ipmi_user}                 = "admin";
	$an->data->{sys}{install_manifest}{'default'}{node1_ipmi_lanplus}              = 0;
	$an->data->{sys}{install_manifest}{'default'}{node1_ipmi_privlvl}              = "USER";
	$an->data->{sys}{install_manifest}{'default'}{node1_name}                      = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_sn_ip}                     = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_bcn_ip}                    = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_ifn_ip}                    = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_ipmi_ip}                   = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_ipmi_user}                 = "admin";
	$an->data->{sys}{install_manifest}{'default'}{node2_ipmi_lanplus}              = 0;
	$an->data->{sys}{install_manifest}{'default'}{node2_ipmi_privlvl}              = "USER";
	$an->data->{sys}{install_manifest}{'default'}{node2_name}                      = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_sn_ip}                     = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_pdu1_outlet}               = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_pdu2_outlet}               = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_pdu3_outlet}               = "";
	$an->data->{sys}{install_manifest}{'default'}{node1_pdu4_outlet}               = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_pdu1_outlet}               = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_pdu2_outlet}               = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_pdu3_outlet}               = "";
	$an->data->{sys}{install_manifest}{'default'}{node2_pdu4_outlet}               = "";
	$an->data->{sys}{install_manifest}{'default'}{ntp1}                            = "";
	$an->data->{sys}{install_manifest}{'default'}{ntp2}                            = "";
	$an->data->{sys}{install_manifest}{'default'}{open_vnc_ports}                  = 100;
	$an->data->{sys}{install_manifest}{'default'}{password}                        = "Initial1";
	$an->data->{sys}{install_manifest}{'default'}{pdu1_name}                       = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu1_ip}                         = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu1_agent}                      = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu2_name}                       = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu2_ip}                         = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu2_agent}                      = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu3_name}                       = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu3_ip}                         = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu3_agent}                      = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu4_name}                       = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu4_ip}                         = "";
	$an->data->{sys}{install_manifest}{'default'}{pdu4_agent}                      = "";
	$an->data->{sys}{install_manifest}{'default'}{pool1_size}                      = "100";
	$an->data->{sys}{install_manifest}{'default'}{pool1_unit}                      = "%";
	$an->data->{sys}{install_manifest}{'default'}{prefix}                          = "";
	$an->data->{sys}{install_manifest}{'default'}{repositories}                    = "";
	$an->data->{sys}{install_manifest}{'default'}{sequence}                        = "01";
	$an->data->{sys}{install_manifest}{'default'}{ssh_keysize}                     = 8191;
	$an->data->{sys}{install_manifest}{'default'}{sn_ethtool_opts}                 = "";
	$an->data->{sys}{install_manifest}{'default'}{sn_network}                      = "10.10.0.0";
	$an->data->{sys}{install_manifest}{'default'}{sn_subnet}                       = "255.255.0.0";
	$an->data->{sys}{install_manifest}{'default'}{sn_defroute}                     = "no";
	$an->data->{sys}{install_manifest}{'default'}{striker_database}                = "scancore";
	$an->data->{sys}{install_manifest}{'default'}{striker_user}                    = "striker";
	$an->data->{sys}{install_manifest}{'default'}{striker1_bcn_ip}                 = "";
	$an->data->{sys}{install_manifest}{'default'}{striker1_ifn_ip}                 = "";
	$an->data->{sys}{install_manifest}{'default'}{striker1_name}                   = "";
	$an->data->{sys}{install_manifest}{'default'}{striker1_user}                   = "",	# Defaults to 'striker_user' if not set
	$an->data->{sys}{install_manifest}{'default'}{striker2_bcn_ip}                 = "";
	$an->data->{sys}{install_manifest}{'default'}{striker2_ifn_ip}                 = "";
	$an->data->{sys}{install_manifest}{'default'}{striker2_name}                   = "";
	$an->data->{sys}{install_manifest}{'default'}{striker2_user}                   = "",	# Defaults to 'striker_user' if not set
	$an->data->{sys}{install_manifest}{'default'}{switch1_ip}                      = "";
	$an->data->{sys}{install_manifest}{'default'}{switch1_name}                    = "";
	$an->data->{sys}{install_manifest}{'default'}{switch2_ip}                      = "";
	$an->data->{sys}{install_manifest}{'default'}{switch2_name}                    = "";
	$an->data->{sys}{install_manifest}{'default'}{update_os}                       = 1;
	$an->data->{sys}{install_manifest}{'default'}{ups1_ip}                         = "";
	$an->data->{sys}{install_manifest}{'default'}{ups1_name}                       = "";
	$an->data->{sys}{install_manifest}{'default'}{ups2_ip}                         = "";
	$an->data->{sys}{install_manifest}{'default'}{ups2_name}                       = "";
	$an->data->{sys}{install_manifest}{'default'}{'use_anvil-kick-apc-ups'}        = 0;
	$an->data->{sys}{install_manifest}{'default'}{'use_anvil-safe-start'}          = 1;
	$an->data->{sys}{install_manifest}{'default'}{use_scancore}                    = 0;
	# If the user wants to build install manifests for environments with 4 PDUs, this will be set to '4'.
	$an->data->{sys}{install_manifest}{pdu_count}                                  = 2;
	# This sets the default fence agent to use for the PDUs.
	$an->data->{sys}{install_manifest}{pdu_fence_agent}                            = "fence_apc_snmp";
	# These variables control whether certain fields are displayed or not when generating Install 
	# Manifests. If you set any of these to '0', please be sure to have an appropriate default set above.
	### Primary
	$an->data->{sys}{install_manifest}{show}{prefix_field}                         = 1;
	$an->data->{sys}{install_manifest}{show}{sequence_field}                       = 1;
	$an->data->{sys}{install_manifest}{show}{domain_field}                         = 1;
	$an->data->{sys}{install_manifest}{show}{password_field}                       = 1;
	$an->data->{sys}{install_manifest}{show}{bcn_network_fields}                   = 1;
	$an->data->{sys}{install_manifest}{show}{sn_network_fields}                    = 1;
	$an->data->{sys}{install_manifest}{show}{ifn_network_fields}                   = 1;
	$an->data->{sys}{install_manifest}{show}{library_fields}                       = 1;
	$an->data->{sys}{install_manifest}{show}{pool1_fields}                         = 1;
	$an->data->{sys}{install_manifest}{show}{repository_field}                     = 1;
	### Shared
	$an->data->{sys}{install_manifest}{show}{name_field}                           = 1;
	$an->data->{sys}{install_manifest}{show}{dns_fields}                           = 1;
	$an->data->{sys}{install_manifest}{show}{ntp_fields}                           = 1;
	### Foundation pack
	$an->data->{sys}{install_manifest}{show}{switch_fields}                        = 1;
	$an->data->{sys}{install_manifest}{show}{ups_fields}                           = 1;
	$an->data->{sys}{install_manifest}{show}{pdu_fields}                           = 1;
	$an->data->{sys}{install_manifest}{show}{pts_fields}                           = 1;
	$an->data->{sys}{install_manifest}{show}{dashboard_fields}                     = 1;
	### Nodes
	$an->data->{sys}{install_manifest}{show}{nodes_name_field}                     = 1;
	$an->data->{sys}{install_manifest}{show}{nodes_bcn_field}                      = 1;
	$an->data->{sys}{install_manifest}{show}{nodes_ipmi_field}                     = 1;
	$an->data->{sys}{install_manifest}{show}{nodes_ipmi_user_field}                = 1;
	$an->data->{sys}{install_manifest}{show}{nodes_ipmi_lanplus_field}             = 1;
	$an->data->{sys}{install_manifest}{show}{nodes_sn_field}                       = 1;
	$an->data->{sys}{install_manifest}{show}{nodes_ifn_field}                      = 1;
	$an->data->{sys}{install_manifest}{show}{nodes_pdu_fields}                     = 1;
	# Control tests/output shown when the install runs. Mainly useful when a site will never have 
	# Internet access.
	$an->data->{sys}{install_manifest}{show}{internet_check}                       = 1;
	$an->data->{sys}{install_manifest}{show}{rhn_checks}                           = 1;
	# This sets anvil-kick-apc-ups to start on boot
	$an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'}                   = 0;
	# This controls whether anvil-safe-start is enabled or not.
	$an->data->{sys}{install_manifest}{'use_anvil-safe-start'}                     = 1;
	# This controls whether ScanCore will run on boot or not (now required, never disable).
	$an->data->{sys}{install_manifest}{use_scancore}                               = 1;
	# Set to '1' to not ask for confirmation when enabling the install target feature
	$an->data->{sys}{install_target}{no_warning}                                   = 0;

	
	### Back to our regularly scheduled system stuff...
	$an->data->{sys}{language}                             = "en_CA";
	# Set to '1' to include the PID in log entries
	$an->data->{sys}{'log'}{log_pid}                       = 0;
	$an->data->{sys}{log_language}                         = "en_CA";
	$an->data->{sys}{log_level}                            = 2;
	$an->data->{sys}{logrotate}{'striker.log'}{count}      = 5,		# Backups made before deletion.
	$an->data->{sys}{logrotate}{'striker.log'}{frequency}  = "weekly",	# daily, weekly, monthly, yearly
	$an->data->{sys}{logrotate}{'striker.log'}{maxsize}    = "100M",		# Rotates if bigger than this, regardless of frequency
	$an->data->{sys}{logrotate}{'ScanCore.log'}{count}     = 5,		# Backups made before deletion.
	$an->data->{sys}{logrotate}{'ScanCore.log'}{frequency} = "weekly",	# daily, weekly, monthly, yearly
	$an->data->{sys}{logrotate}{'ScanCore.log'}{maxsize}   = "100M",		# Rotates if bigger than this, regardless of frequency
	$an->data->{sys}{lvm_conf}                             = "";
	$an->data->{sys}{lvm_filter}                           = "filter = [ \"a|/dev/drbd*|\", \"r/.*/\" ]";
	# This allows for custom MTU sizes in an Install Manifest
	$an->data->{sys}{mtu_size}                             = 1500;
	$an->data->{sys}{network}{internet_test_ip}            = "8.8.8.8";
	# This tells the install manifest generator how many ports to open on the IFN for incoming VNC 
	# connections.
	$an->data->{sys}{node_names}                           = [];
	$an->data->{sys}{online_nodes}                         = 0;
	$an->data->{sys}{os_variant}                           = [
		"rhel7#!#Red Hat Enterprise Linux 7",
		"rhel6#!#Red Hat Enterprise Linux 6",
		"rhel5.4#!#Red Hat Enterprise Linux 5.4 or later",
		"rhel5#!#Red Hat Enterprise Linux 5",
		"rhel4#!#Red Hat Enterprise Linux 4",
		"rhel3#!#Red Hat Enterprise Linux 3",
		"rhel2.1#!#Red Hat Enterprise Linux 2.1",
		"win2O16#!#Microsoft Windows Server 2016",# NOTE: the 'O' is a capital letter 'o', not a '0', so that it sorts properly.
		"win2k8#!#Microsoft Windows Server 2012 (R2)",
		"win2k8#!#Microsoft Windows Server 2008 (R2)",
		"win2k3#!#Microsoft Windows Server 2003",
		"win7#!#Microsoft Windows 10",
		"win7#!#Microsoft Windows 8",
		"win7#!#Microsoft Windows 7",
		"vista#!#Microsoft Windows Vista",
		"winxp#!#Microsoft Windows XP",
		"winxp64#!#Microsoft Windows XP (x86_64)",
		"win2k#!#Microsoft Windows 2000",
		"msdos#!#MS-DOS",
		"sles11#!#Suse Linux Enterprise Server 12",
		"sles11#!#Suse Linux Enterprise Server 11",
		"sles10#!#Suse Linux Enterprise Server",
		"opensuse12#!#openSuse 13",
		"opensuse12#!#openSuse 12",
		"opensuse11#!#openSuse 11",
		"fedora18#!#Fedora Rawhide",
		"fedora18#!#Fedora 27",
		"fedora18#!#Fedora 26",
		"fedora18#!#Fedora 25",
		"fedora18#!#Fedora 24",
		"fedora18#!#Fedora 23",
		"fedora18#!#Fedora 22",
		"fedora18#!#Fedora 21",
		"fedora18#!#Fedora 20",
		"fedora18#!#Fedora 19",
		"fedora18#!#Fedora 18",
		"fedora17#!#Fedora 17",
		"fedora16#!#Fedora 16",
		"fedora15#!#Fedora 15",
		"fedora14#!#Fedora 14",
		"fedora13#!#Fedora 13",
		"fedora12#!#Fedora 12",
		"fedora11#!#Fedora 11",
		"fedora10#!#Fedora 10",
		"fedora9#!#Fedora 9",
		"fedora8#!#Fedora 8",
		"fedora7#!#Fedora 7",
		"fedora6#!#Fedora Core 6",
		"fedora5#!#Fedora Core 5",
		"ubuntuquantal#!#Ubuntu 18.04 (Bionic Beaver)",
		"ubuntuquantal#!#Ubuntu 17.10 (Artful Aardvark)",
		"ubuntuquantal#!#Ubuntu 17.04 (Zesty Zapus)",
		"ubuntuquantal#!#Ubuntu 16.10 (Yakkety Yak)",
		"ubuntuquantal#!#Ubuntu 16.04 LTS (Xenial Xerus)",
		"ubuntuquantal#!#Ubuntu 15.10 (Wily Werewolf)",
		"ubuntuquantal#!#Ubuntu 15.04 (Vivid Vervet)",
		"ubuntuquantal#!#Ubuntu 14.10 (Utopic Unicorn)",
		"ubuntuquantal#!#Ubuntu 14.04 LTS (Trusty Tahr)",
		"ubuntuquantal#!#Ubuntu 13.10 (Saucy Salamander)",
		"ubuntuquantal#!#Ubuntu 13.04 (Raring Ringtail)",
		"ubuntuquantal#!#Ubuntu 12.10 (Quantal Quetzal)",
		"ubuntuprecise#!#Ubuntu 12.04 LTS (Precise Pangolin)",
		"ubuntuoneiric#!#Ubuntu 11.10 (Oneiric Ocelot)",
		"ubuntunatty#!#Ubuntu 11.04 (Natty Narwhal)",
		"ubuntumaverick#!#Ubuntu 10.10 (Maverick Meerkat)",
		"ubuntulucid#!#Ubuntu 10.04 LTS (Lucid Lynx)",
		"ubuntukarmic#!#Ubuntu 9.10 (Karmic Koala)",
		"ubuntujaunty#!#Ubuntu 9.04 (Jaunty Jackalope)",
		"ubuntuintrepid#!#Ubuntu 8.10 (Intrepid Ibex)",
		"ubuntuhardy#!#Ubuntu 8.04 LTS (Hardy Heron)",
		"freebsd8#!#FreeBSD 11.x",
		"freebsd8#!#FreeBSD 10.x",
		"freebsd8#!#FreeBSD 9.x",
		"freebsd8#!#FreeBSD 8.x",
		"freebsd7#!#FreeBSD 7.x",
		"freebsd6#!#FreeBSD 6.x",
		"openbsd4#!#OpenBSD 4.x",
		"netware6#!#Novell Netware 6",
		"netware5#!#Novell Netware 5",
		"netware4#!#Novell Netware 4",
		"debianjessie#!#Debian 11 (Bullseye)",
		"debianjessie#!#Debian 10 (Buster)",
		"debianjessie#!#Debian 9 (Stretch)",
		"debianjessie#!#Debian 8 (Jessie)",
		"debianwheezy#!#Debian 7 (Wheezy)",
		"debiansqueeze#!#Debian 6 (Squeeze)",
		"debianlenny#!#Debian 5 (Lenny)",
		"debianetch#!#Debian 4 (Etch)",
		"mageia1#!#Mageia 1 and later",
		"mes5.1#!#Mandriva Enterprise Server 5.1 and later",
		"mes5#!#Mandriva Enterprise Server 5.0",
		"mandriva2010#!#Mandriva Linux 2010 and later",
		"mandriva2009#!#Mandriva Linux 2009 and earlier",
		"virtio26#!#Generic 2.6.25 or later kernel with virtio",
	];
	$an->data->{sys}{output}                               = "web";
	$an->data->{sys}{pool1_shrunk}                         = 0;
	# When shutting down the nodes prior to power-cycling or powering off the entire rack, instead of the
	# nodes being marked 'clean' off (which would leave them off until a human turned them on), the 
	# 'host_stop_reason' is set to unix-time + this number of seconds. When the dashboard sees this time 
	# set, it will not boot the nodes until time > host_stop_reason. This way, the nodes will not be 
	# powered on before the UPS shuts off.
	# NOTE: Be sure that this time is greater than the UPS shutdown delay!
	$an->data->{sys}{power_off_delay}                      = 300;
	$an->data->{sys}{reboot_timeout}                       = 600;
	$an->data->{sys}{root_password}                        = "";
	# Set this to an integer to have the main Striker page and the hardware status pages automatically 
	# reload.
	$an->data->{sys}{reload_page_timer}                    = 0;
	# These options allow customization of newly provisioned servers.
	### If you change these, change the matching values in striker-installer so that it stays in sync.
	$an->data->{sys}{scancore_database}                    = "scancore";
	$an->data->{sys}{striker_user}                         = "admin";
	$an->data->{sys}{server}{nic_count}                    = 1;
	$an->data->{sys}{server}{alternate_nic_model}          = "e1000";
	$an->data->{sys}{server}{minimum_ram}                  = 67108864;
	$an->data->{sys}{server}{bcn_nic_driver}               = "";
	$an->data->{sys}{server}{sn_nic_driver}                = "";
	$an->data->{sys}{server}{ifn_nic_driver}               = "";
	$an->data->{sys}{shared_fs_uuid}                       = "";
	$an->data->{sys}{show_nodes}                           = 0;
	$an->data->{sys}{show_refresh}                         = 1;
	
	$an->data->{sys}{single_node_start}{enabled}           = 0;
	$an->data->{sys}{single_node_start}{boot_frequency}    = 86400;
	$an->data->{sys}{single_node_start}{boot_delay}        = 300;
	
	$an->data->{sys}{skin}                                 = "alteeve";
	$an->data->{sys}{striker_uid}                          = $<;
	$an->data->{sys}{system_timezone}                      = "America/Toronto";
	$an->data->{sys}{time_seperator}                       = ":";
	# ~3 GiB, but in practice more because it will round down the available RAM before subtracting this 
	# to leave the user with an even number of GiB of RAM to allocate to servers.
	$an->data->{sys}{unusable_ram}                         = (3 * (1024 ** 3));
	$an->data->{sys}{up_nodes}                             = 0;
	$an->data->{sys}{update_os}                            = 1;
	$an->data->{sys}{use_24h}                              = 1,			# Set to 0 for am/pm time, 1 for 24h time
	$an->data->{sys}{username}                             = getpwuid( $< );
	# If a user wants to use spice + qxl for video in VMs, set this to '1'. NOTE: This disables web-based VNC!
	$an->data->{sys}{use_spice_graphics}                   = 1;
	$an->data->{sys}{version}                              = "2.0.7";
	# Adds: [--disablerepo='*' --enablerepo='striker*'] if
	# no internet connection found.
	$an->data->{sys}{yum_switches}                         = "-y";
	
	### Tools default valies
	$an->data->{tools}{'anvil-kick-apc-ups'}{enabled}      = 0;
	
	 # If 'tools::striker-push-ssh::enabled' is enabled, this will control whether changed RSA 
	 # fingerprints will automatically be updated. Setting this to '0' improves security.
	$an->data->{tools}{'auto-update-ssh-fingerprints'}{enabled} = 1;
	
	### TODO: prefix the anvil-safe-start::drbd::* stuff with 'tools::', make sure to handle this in 
	###       updates
	# These control whether we boost resync speed during anvil-safe-start and, if so, to what degree. 
	$an->data->{tools}{'anvil-safe-start'}{enabled}        = 1;
	# Set to '0' to disable entirely
	$an->data->{'anvil-safe-start'}{drbd}{always_boost}    = 0;
	# How fast (MiB/sec) to boost to
	$an->data->{'anvil-safe-start'}{drbd}{boost_speed}     = 80;
	# If the boosted sync speed still requires more than this number of seconds, the boost will abort and
	# the node will join while still Inconsistent. Setting 'wait' means it will wait forever.
	$an->data->{'anvil-safe-start'}{drbd}{max_wait_time}   = "wait";
	# After boosting, how long do we wait before checking the resync ETA
	$an->data->{'anvil-safe-start'}{drbd}{resync_delay}    = 15;
	
	# This sets a minimum password length. Default is '6'.
	$an->data->{tools}{'anvil-self-destruct'}{minimum_length} = 6;
	$an->data->{tools}{'anvil-self-destruct'}{hash}           = "vSsar3708Jvp9Szi2NWZZ02Bqp1qRCFpbcTZPdBhnWgs5WtNZKnvCXdhztmeD2cmW192CF5bDufKRpayrW/isg";

	$an->data->{tools}{disaster_recovery}{cache_signature} = ".dr_cache";
	$an->data->{tools}{'striker-push-ssh'}{enabled}        = 1;
	
	# Set this to '1' to have Striker automatically configure Virtual Machine Manager when new Anvil! 
	# systems are added to Striker.
	$an->data->{tools}{'striker-configure-vmm'}{enabled}   = 1;
	$an->data->{tools}{striker}{'auto-sync'}               = 1;

	
	$an->data->{up_nodes}                                  = [];
	$an->data->{url}{skins}                                = "/skins";
	$an->data->{url}{cgi}                                  = "/cgi-bin";

	return(0);
}

# This sets a bunch of default paths to executables and a few system files.
sub _set_paths
{
	my ($self) = shift;
	my $an     = $self;
	
	### TODO: Use '$an->Storage->find()' to locate these in case they aren't found at the set location
	###       below.
	# Executables
	$an->data->{path}{awk}                    = "/bin/awk";
	$an->data->{path}{blkid}                  = "/sbin/blkid";
	$an->data->{path}{brctl}                  = "/usr/sbin/brctl";
	$an->data->{path}{bzip2}                  = "/usr/bin/bzip2";
	$an->data->{path}{cat}                    = "/bin/cat";
	$an->data->{path}{ccs}                    = "/usr/sbin/ccs";
	$an->data->{path}{ccs_config_validate}    = "/usr/sbin/ccs_config_validate";
	$an->data->{path}{'chmod'}                = "/bin/chmod";
	$an->data->{path}{chkconfig}              = "/sbin/chkconfig";
	$an->data->{path}{'chown'}                = "/bin/chown";
	$an->data->{path}{clustat}                = "/usr/sbin/clustat";
	$an->data->{path}{clusvcadm}              = "/usr/sbin/clusvcadm";
	$an->data->{path}{cp}                     = "/bin/cp";
	$an->data->{path}{createrepo}             = "/usr/bin/createrepo";
	$an->data->{path}{curl}                   = "/usr/bin/curl";
	$an->data->{path}{df}                     = "/bin/df";
	$an->data->{path}{dmesg}                  = "/bin/dmesage";
	$an->data->{path}{dmidecode}              = "/usr/sbin/dmidecode";
	$an->data->{path}{'drbd-overview'}        = "/usr/sbin/drbd-overview";
	$an->data->{path}{drbdadm}                = "/sbin/drbdadm";
	$an->data->{path}{drbdmeta}               = "/sbin/drbdmeta";
	$an->data->{path}{echo}                   = "/bin/echo";
	$an->data->{path}{expect}                 = "/usr/bin/expect";
	$an->data->{path}{fence_check}            = "/usr/sbin/fence_check";
	$an->data->{path}{fence_node}             = "/usr/sbin/fence_node";
	$an->data->{path}{fence_tool}             = "/usr/sbin/fence_tool";
	$an->data->{path}{find}                   = "/bin/find";
	$an->data->{path}{free}                   = "/usr/bin/free";
	$an->data->{path}{gcc}                    = "/usr/bin/gcc";
	$an->data->{path}{'grep'}                 = "/bin/grep";
	$an->data->{path}{gethostip}              = "/usr/bin/gethostip";
	$an->data->{path}{gfs2_tool}              = "/usr/sbin/gfs2_tool";
	$an->data->{path}{hostname}               = "/bin/hostname";
	$an->data->{path}{hpacucli}               = "/usr/sbin/hpacucli",
	$an->data->{path}{htpasswd}               = "/usr/bin/htpasswd";
	$an->data->{path}{ifconfig}               = "/sbin/ifconfig";
	$an->data->{path}{ip}                     = "/sbin/ip";
	$an->data->{path}{ipmitool}               = "/usr/bin/ipmitool";
	$an->data->{path}{'iptables-save'}        = "/sbin/iptables-save";
	$an->data->{path}{'kill'}                 = "/bin/kill";
	$an->data->{path}{'less'}                 = "/usr/bin/less";
	$an->data->{path}{ln}                     = "/bin/ln";
	$an->data->{path}{ls}                     = "/bin/ls";
	$an->data->{path}{lsblk}                  = "/bin/lsblk";
	$an->data->{path}{lsmod}                  = "/sbin/lsmod";
	$an->data->{path}{lvchange}               = "/sbin/lvchange";
	$an->data->{path}{lvcreate}               = "/sbin/lvcreate";
	$an->data->{path}{lvdisplay}              = "/sbin/lvdisplay";
	$an->data->{path}{lvextend}               = "/sbin/lvextend";
	$an->data->{path}{lvremove}               = "/sbin/lvremove";
	$an->data->{path}{lvs}                    = "/sbin/lvs";
	$an->data->{path}{lvscan}                 = "/sbin/lvscan";
	$an->data->{path}{mailx}                  = "/bin/mailx";
	$an->data->{path}{md5sum}                 = "/usr/bin/md5sum";
	$an->data->{path}{megacli64}              = "/sbin/MegaCli64";
	$an->data->{path}{'mkfs.gfs2'}            = "/sbin/mkfs.gfs2";
	$an->data->{path}{modprobe}               = "/sbin/modprobe";
	$an->data->{path}{mount}                  = "/bin/mount";
	$an->data->{path}{'mkdir'}                = "/bin/mkdir";
	$an->data->{path}{mv}                     = "/bin/mv";
	$an->data->{path}{parted}                 = "/sbin/parted";
	$an->data->{path}{passwd}                 = "/usr/bin/passwd";
	$an->data->{path}{perl}                   = "/usr/bin/perl";
	$an->data->{path}{pg_dump}                = "/usr/bin/pg_dump";
	$an->data->{path}{'ping'}                 = "/bin/ping";
	$an->data->{path}{pkill}                  = "/usr/bin/pkill";
	$an->data->{path}{postfix_main}           = "/etc/postfix/main.cf";
	$an->data->{path}{postfix_relay_file}     = "/etc/postfix/relay_password";
	$an->data->{path}{postmap}                = "/usr/sbin/postmap";
	$an->data->{path}{pgrep}                  = "/usr/bin/pgrep";
	$an->data->{path}{pmap}                   = "/usr/bin/pmap";
	$an->data->{path}{poweroff}               = "/sbin/poweroff";
	$an->data->{path}{ps}                     = "/bin/ps";
	$an->data->{path}{psql}                   = "/usr/bin/psql";
	$an->data->{path}{pvchange}               = "/sbin/pvchange";
	$an->data->{path}{pvcreate}               = "/sbin/pvcreate";
	$an->data->{path}{pvdisplay}              = "/sbin/pvdisplay";
	$an->data->{path}{pvscan}                 = "/sbin/pvscan";
	$an->data->{path}{pvs}                    = "/sbin/pvs";
	$an->data->{path}{reboot}                 = "/sbin/reboot";
	$an->data->{path}{restorecon}             = "/sbin/restorecon";
	$an->data->{path}{rhn_check}              = "/usr/sbin/rhn_check";
	$an->data->{path}{'rhn-channel'}          = "/usr/sbin/rhn-channel";
	$an->data->{path}{rhnreg_ks}              = "/usr/sbin/rhnreg_ks";
	$an->data->{path}{rm}                     = "/bin/rm";
	$an->data->{path}{semanage}               = "/usr/sbin/semanage";
	$an->data->{path}{'subscription-manager'} = "/usr/sbin/subscription-manager";
	$an->data->{path}{route}                  = "/sbin/route";
	$an->data->{path}{rsync}                  = "/usr/bin/rsync";
	$an->data->{path}{sed}                    = "/bin/sed";
	$an->data->{path}{'sleep'}                = "/bin/sleep";	# Used in bash calls
	$an->data->{path}{ssh}                    = "/usr/bin/ssh";
	$an->data->{path}{'ssh-keygen'}           = "/usr/bin/ssh-keygen";
	$an->data->{path}{'ssh-keyscan'}          = "/usr/bin/ssh-keyscan";
	$an->data->{path}{'ssh-copy-id'}          = "/usr/bin/ssh-copy-id";
	$an->data->{path}{storcli64}              = "/sbin/storcli64";
	$an->data->{path}{perccli64}              = "/opt/MegaRAID/perccli/perccli64";
	$an->data->{path}{su}                     = "/bin/su";
	$an->data->{path}{timeout}                = "/usr/bin/timeout";
	$an->data->{path}{tput}                   = "/usr/bin/tput";
	$an->data->{path}{unzip}                  = "/usr/bin/unzip";
	$an->data->{path}{umount}                 = "/bin/umount";
	$an->data->{path}{uuidgen}                = "/usr/bin/uuidgen";
	$an->data->{path}{touch}                  = "/bin/touch";
	$an->data->{path}{'virt-manager'}         = "/usr/bin/virt-manager";
	$an->data->{path}{vgchange}               = "/sbin/vgchange";
	$an->data->{path}{vgcreate}               = "/sbin/vgcreate";
	$an->data->{path}{vgdisplay}              = "/sbin/vgdisplay";
	$an->data->{path}{vgscan}                 = "/sbin/vgscan";
	$an->data->{path}{vgs}                    = "/sbin/vgs";
	$an->data->{path}{virsh}                  = "/usr/bin/virsh";
	$an->data->{path}{wc}                     = "/usr/bin/wc";
	$an->data->{path}{wget}                   = "/usr/bin/wget";
	$an->data->{path}{whereis}                = "/usr/bin/whereis";
	$an->data->{path}{yum}                    = "/usr/bin/yum";
	
	# Text files
	$an->data->{path}{htpasswd_access}  = "/var/www/home/htpasswd";
	$an->data->{path}{cluster_conf}     = "/etc/cluster/cluster.conf";
	$an->data->{path}{cman_config}      = "/etc/cluster/cluster.conf";	# TODO: Phase this out
	$an->data->{path}{common_strings}   = "Data/common.xml";		# Relative to the install path
	$an->data->{path}{dhcpd_conf}       = "/etc/dhcp/dhcpd.conf";
	$an->data->{path}{etc_fstab}        = "/etc/fstab";
	$an->data->{path}{etc_hosts}        = "/etc/hosts";
	$an->data->{path}{etc_passwd}       = "/etc/passwd";
	$an->data->{path}{etc_virbr0}       = "/etc/libvirt/qemu/networks/default.xml";
	$an->data->{path}{gdm_presession}   = "/etc/gdm/PreSession/Default";
	$an->data->{path}{host_uuid}        = "/etc/striker/host.uuid";
	$an->data->{path}{hosts}            = "/etc/hosts";
	$an->data->{path}{logrotate_config} = "/etc/logrotate.d/anvil";
	$an->data->{path}{'redhat-release'} = "/etc/redhat-release";
	$an->data->{path}{scancore_strings} = "/sbin/striker/ScanCore/ScanCore.xml";
	$an->data->{path}{scancore_sql}     = "/sbin/striker/ScanCore/ScanCore.sql";
	$an->data->{path}{ssh_config}       = "/etc/ssh/ssh_config";
	$an->data->{path}{striker_config}   = "/etc/striker/striker.conf";
	$an->data->{path}{striker_strings}  = "/sbin/striker/Data/strings.xml";
	$an->data->{path}{root_crontab}     = "/var/spool/cron/root";
	
	# init.d stuff
	$an->data->{path}{initd_libvirtd} = "/etc/init.d/libvirtd";
	
	# Log files
	$an->data->{path}{log_file} = "/var/log/striker.log";
	
	# This is a text file with '#!token!#' replaced with a job's UUID token when running Anvil! jobs from 'anvil-run-jobs'
	$an->data->{path}{'anvil-jobs-output'} = "/tmp/anvil-job.#!token!#.txt";
	
	# /proc stuff
	$an->data->{path}{proc_bonding} = "/proc/net/bonding";
	$an->data->{path}{proc_drbd}    = "/proc/drbd";
	$an->data->{path}{proc_meminfo} = "/proc/meminfo";
	$an->data->{path}{proc_mounts}  = "/proc/self/mounts";
	$an->data->{path}{proc_sysrq}   = "/proc/sysrq-trigger";
	$an->data->{path}{proc_uptime}  = "/proc/uptime";
	$an->data->{path}{proc_virbr0}  = "/proc/sys/net/ipv4/conf/virbr0";
	
	# /sys stuff
	$an->data->{path}{sysfs_block} = "/sys/block";

	# Directories
	$an->data->{path}{agents_directory}   = "/sbin/striker/ScanCore/agents";
	$an->data->{path}{alert_emails}       = "/var/log/alert_emails";
	$an->data->{path}{alert_files}        = "/var/log";
	$an->data->{path}{fence_agents}       = "/usr/sbin";
	$an->data->{path}{initd}              = "/etc/init.d";
	$an->data->{path}{media}              = "/var/www/home/media/";
	$an->data->{path}{repo_centos}        = "/var/www/html/centos6/x86_64/img/repodata";
	$an->data->{path}{repo_generic}       = "/var/www/html/repo/repodata";
	$an->data->{path}{repo_rhel}          = "/var/www/html/rhel6/x86_64/img/repodata";
	$an->data->{path}{scancore_archive}   = "/var/ScanCore/archives/";	# The user can override this with 'scancore::archive::directory'
	$an->data->{path}{shared}             = "/shared";
	$an->data->{path}{shared_archive}     = "/shared/archive";
	$an->data->{path}{shared_definitions} = "/shared/definitions";
	$an->data->{path}{shared_files}       = "/shared/files";
	$an->data->{path}{shared_privision}   = "/shared/provision";
	$an->data->{path}{skins}              = "/var/www/html/skins";
	$an->data->{path}{striker_backups}    = "/root/anvil";
	$an->data->{path}{striker_cache}      = "/var/www/home/cache";
	$an->data->{path}{striker_tools}      = "/sbin/striker";
	$an->data->{path}{update_cache}       = "/var/striker/cache";
	$an->data->{path}{yum_cache}          = "/var/cache/yum";
	$an->data->{path}{yum_repos}          = "/etc/yum.repos.d";
	
	# Tools
	$an->data->{path}{'anvil-boot-server'}             = "/sbin/striker/anvil-boot-server";
	$an->data->{path}{'anvil-download-file'}           = "/sbin/striker/anvil-download-file";
	$an->data->{path}{'anvil-kick-apc-ups'}            = "/sbin/striker/anvil-kick-apc-ups";
	$an->data->{path}{'anvil-run-jobs'}                = "/sbin/striker/anvil-run-jobs";
	$an->data->{path}{'anvil-map-network'}             = "/sbin/striker/anvil-map-network";
	$an->data->{path}{'anvil-migrate-server'}          = "/sbin/striker/anvil-migrate-server";
	$an->data->{path}{'anvil-report-ipmi-details'}     = "/sbin/striker/anvil-report-ipmi-details";	# Deprecated, will be deleted soon
	$an->data->{path}{'anvil-report-memory'}           = "/sbin/striker/anvil-report-memory";
	$an->data->{path}{'anvil-report-state'}            = "/sbin/striker/anvil-report-state";
	$an->data->{path}{'anvil-safe-start'}              = "/sbin/striker/anvil-safe-start";
	$an->data->{path}{'anvil-safe-start_link'}         = "/etc/rc3.d/S99_anvil-safe-start";
	$an->data->{path}{'anvil-safe-stop'}               = "/sbin/striker/anvil-safe-stop";
	$an->data->{path}{'anvil-stop-server'}             = "/sbin/striker/anvil-stop-server";
	$an->data->{path}{'call_anvil-kick-apc-ups'}       = "/sbin/striker/call_anvil-kick-apc-ups";
	$an->data->{path}{'call_gather-system-info'}       = "/sbin/striker/call_gather-system-info";
	$an->data->{path}{'call_striker-push-ssh'}         = "/sbin/striker/call_striker-push-ssh";
	$an->data->{path}{'call_striker-configure-vmm'}    = "/sbin/striker/call_striker-configure-vmm";
	$an->data->{path}{'call_striker-delete-anvil'}     = "/sbin/striker/call_striker-delete-anvil";
	$an->data->{path}{'call_striker-merge-dashboards'} = "/sbin/striker/call_striker-merge-dashboards";
	$an->data->{path}{check_dvd}                       = "/sbin/striker/check_dvd";
	$an->data->{path}{control_dhcpd}                   = "/sbin/striker/control_dhcpd";
	$an->data->{path}{control_iptables}                = "/sbin/striker/control_iptables";
	$an->data->{path}{control_libvirtd}                = "/sbin/striker/control_libvirtd";
	$an->data->{path}{control_shorewall}               = "/sbin/striker/control_shorewall";
	$an->data->{path}{do_dd}                           = "/sbin/striker/do_dd";
	$an->data->{path}{'striker-configure-vmm'}         = "/sbin/striker/striker-configure-vmm";
	$an->data->{path}{'striker-delete-anvil'}          = "/sbin/striker/striker-delete-anvil";
	$an->data->{path}{'striker-merge-dashboards'}      = "/sbin/striker/striker-merge-dashboards";
	$an->data->{path}{'striker-change-password'}       = "/sbin/striker/striker-change-password";
	$an->data->{path}{'striker-push-ssh'}              = "/sbin/striker/striker-push-ssh";
	$an->data->{path}{ScanCore}                        = "/sbin/striker/ScanCore/ScanCore";
	$an->data->{path}{'touch_striker.log'}             = "/sbin/striker/touch_striker.log";
	
	# Temporary/progress files
	$an->data->{path}{'anvil-jobs'}        = "/tmp/anvil.jobs";
	$an->data->{path}{'downloading-files'} = "/tmp/anvil-download-file.status";
	
	# setuid tools
	$an->data->{path}{'call_striker-manage-install-target'} = "/sbin/striker/call_striker-manage-install-target";
	
	# Lock files
	$an->data->{path}{gfs2_lock}     = "/var/lock/subsys/gfs2";
	$an->data->{path}{scancore_lock} = "/tmp/ScanCore.lock";
	
	# PID files
	$an->data->{path}{libvirtd_pid} = "/var/rune/libvirtd.pid";
	
	# Sockets
	$an->data->{path}{libvirtd_socket} = "/var/run/libvirt/libvirt-sock";
	
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

# This is called when I need to parse a double-colon separated string into two or more elements which 
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
		$self->Alert->error({title_key => "error_title_0013", title_variables => { module => "Fcntl" }, message_key => "error_message_0021", message_variables => { 
			module	=>	"Fcntl",
			error	=>	$@,
		}, code => 31, file => $THIS_FILE, line => __LINE__});
		return (undef);
	}
	else
	{
		# Good, record it as loaded.
		$self->_fcntl_loaded(1);
	}
	
	return (0);
}

# This loads the 'IO::Handle' module.
sub _load_io_handle
{
	my $self = shift;
	
	eval 'use IO::Handle;';
	if ($@)
	{
		$self->Alert->error({title_key => "error_title_0013", title_variables => { module => "IO::Handle" }, message_key => "error_message_0021", message_variables => {
			module	=>	"IO::Handle",
			error	=>	$@,
		}, code => 13, file => $THIS_FILE, line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
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
		$self->Alert->error({title_key => "error_title_0013", title_variables => { module => "Math::BigInt" }, message_key => "error_message_0021", message_variables => {
			module	=>	"Math::BigInt",
			error	=>	$@,
		}, code => 13, file => $THIS_FILE, line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
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
