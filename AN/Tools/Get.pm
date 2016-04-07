package AN::Tools::Get;

use strict;
use warnings;
use IO::Handle;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Get.pm";

### Methods;
# local_users
# drbd_data
# lvm_data
# server_data
# server_uuid
# server_xml
# users_home
# rsa_public_key
# uuid
# say_am
# say_pm
# date_seperator
# time_seperator
# use_24h
# date_and_time
# pids
# ram_used_by_program
# get_ram_used_by_pid
# switches
# ip
# remote_anvil_details
# local_anvil_details
# striker_peers


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Get->new()\n";
	my $class = shift;
	
	my $self  = {
		USE_24H		=>	1,
		SAY		=>	{
			AM		=>	"am",
			PM		=>	"pm",
		},
		SEPERATOR	=>	{
			DATE		=>	"-",
			TIME		=>	":",
		},
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

# This returns an array of local users on the system. Specifically, users with home directories under 
# '/home'. So not 'root' or system users accounts.
sub local_users
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $users = [];
	my $shell_call = "/etc/passwd";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		my ($user, $users_home) = (split/:/, $line)[0,5];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "user",       value1 => $user, 
			name2 => "users_home", value2 => $users_home, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($users_home =~ /^\/home\//)
		{
			push @{$users}, $user;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "user", value1 => $user, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	close $file_handle;
	
	# record how many users we read into the array.
	my $users_count = @{$users};
	my $message_key = $users_count == 1 ? "tools_log_0006" : "tools_log_0005";
	$an->Log->entry({log_level => 3, message_key => $message_key, message_variables => {
		array	=>	"users",
		count	=>	$users_count,
	}, file => $THIS_FILE, line => __LINE__});
	
	return($users);
}

# This gets the details (except the XML, use '$an->Get->server_xml()' for that) associated with a given 
# server name,
sub server_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $return = {};
	my $server_name = $parameter->{server} ? $parameter->{server} : "";
	my $server_uuid = $parameter->{uuid}   ? $parameter->{uuid}   : "";
	my $anvil       = $parameter->{anvil}  ? $parameter->{anvil}  : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "server_name", value1 => $server_name, 
		name2 => "server_uuid", value2 => $server_uuid, 
		name3 => "anvil",       value3 => $anvil, 
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $server_name) && (not $server_uuid))
	{
		# No server? pur quois?!
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0051", code => 51, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# Get the server's UUID.
	if ($server_uuid !~ /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/)
	{
		$server_uuid = $an->Get->server_uuid({
			server => $server_name, 
			anvil  => $anvil, 
		});
		if ($server_uuid !~ /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/)
		{
			# Bad or no UUID returned.
			$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0058", message_variables => { uuid => $server_uuid }, code => 58, file => "$THIS_FILE", line => __LINE__});
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "server_uuid", value1 => $server_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Check the server table now (if we have a database connection).
	if ($server_uuid)
	{
		if (not $an->data->{sys}{read_db_id})
		{
			# Pick up the XML read by $an->Get->server_uuid()
			$return->{definition} = $an->data->{server}{$server_name}{xml} ? $an->data->{server}{$server_name}{xml} : "";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return->definition", value1 => $return->{definition},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			my $query = "
SELECT 
    server_name, 
    server_stop_reason, 
    server_start_after, 
    server_start_delay, 
    server_note, 
    server_host, 
    server_state, 
    server_definition, 
    server_migration_type, 
    server_pre_migration_script, 
    server_pre_migration_arguments, 
    server_post_migration_script, 
    server_post_migration_arguments, 
    modified_date
FROM 
    server 
WHERE 
    server_uuid = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)." 
;";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query, 
			}, file => $THIS_FILE, line => __LINE__});
			
			my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
			my $count   = @{$results};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "results", value1 => $results, 
				name2 => "count",   value2 => $count
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $row (@{$results})
			{
				my $server_name                     = $row->[0];
				my $server_stop_reason              = $row->[1]  ? $row->[1]  : "";
				my $server_start_after              = $row->[2]  ? $row->[2]  : "";
				my $server_start_delay              = $row->[3];
				my $server_note                     = $row->[4]  ? $row->[4]  : "";
				my $server_host                     = $row->[5]  ? $row->[5]  : "";
				my $server_state                    = $row->[6]  ? $row->[6]  : "";
				my $server_definition               = $row->[7]  ? $row->[7]  : "";
				my $server_migration_type           = $row->[8];
				my $server_pre_migration_script     = $row->[9];
				my $server_pre_migration_arguments  = $row->[10] ? $row->[10] : "";
				my $server_post_migration_script    = $row->[11] ? $row->[11] : "";
				my $server_post_migration_arguments = $row->[12] ? $row->[12] : "";
				my $modified_date                   = $row->[13] ? $row->[13] : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0014", message_variables => {
					name1  => "server_name",                     value1  => $server_name, 
					name2  => "server_stop_reason",              value2  => $server_stop_reason, 
					name3  => "server_start_after",              value3  => $server_start_after, 
					name4  => "server_start_delay",              value4  => $server_start_delay, 
					name5  => "server_note",                     value5  => $server_note, 
					name6  => "server_host",                     value6  => $server_host, 
					name7  => "server_state",                    value7  => $server_state, 
					name8  => "server_definition",               value8  => $server_definition, 
					name9  => "server_migration_type",           value9  => $server_migration_type, 
					name10 => "server_pre_migration_script",     value10 => $server_pre_migration_script, 
					name11 => "server_pre_migration_arguments",  value11 => $server_pre_migration_arguments, 
					name12 => "server_post_migration_script",    value12 => $server_post_migration_script, 
					name13 => "server_post_migration_arguments", value13 => $server_post_migration_arguments, 
					name14 => "modified_date",                   value14 => $modified_date, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Push the values into the 'return' hash reference.
				$return->{uuid}                     = $server_uuid;
				$return->{name}                     = $server_name;
				$return->{stop_reason}              = $server_stop_reason;
				$return->{start_after}              = $server_start_after;
				$return->{start_delay}              = $server_start_delay;
				$return->{note}                     = $server_note;
				$return->{host}                     = $server_host;
				$return->{'state'}                  = $server_state;
				$return->{definition}               = $server_definition;
				$return->{migration_type}           = $server_migration_type;
				$return->{pre_migration_script}     = $server_pre_migration_script;
				$return->{pre_migration_arguments}  = $server_pre_migration_arguments;
				$return->{post_migration_script}    = $server_post_migration_script;
				$return->{post_migration_arguments} = $server_post_migration_arguments;
				$return->{modified_date}            = $modified_date;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0015", message_variables => {
					name1  => "uuid",                     value1  => $return->{uuid}, 
					name2  => "name",                     value2  => $return->{name}, 
					name3  => "stop_reason",              value3  => $return->{stop_reason}, 
					name4  => "start_after",              value4  => $return->{start_after}, 
					name5  => "start_delay",              value5  => $return->{start_delay}, 
					name6  => "note",                     value6  => $return->{note}, 
					name7  => "host",                     value7  => $return->{host}, 
					name8  => "state",                    value8  => $return->{'state'}, 
					name9  => "definition",               value9  => $return->{definition}, 
					name10 => "migration_type",           value10 => $return->{migration_type}, 
					name11 => "pre_migration_script",     value11 => $return->{pre_migration_script}, 
					name12 => "pre_migration_arguments",  value12 => $return->{pre_migration_arguments}, 
					name13 => "post_migration_script",    value13 => $return->{post_migration_script}, 
					name14 => "post_migration_arguments", value14 => $return->{post_migration_arguments}, 
					name15 => "modified_date",            value15 => $return->{modified_date}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	### TODO: This doesn't handle no XML well. Before calling XML::Simple, validate that 'defition' 
	###       contains XML.
	# Now dig out the storage and network details.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return->definition", value1 => $return->{definition}, 
	}, file => $THIS_FILE, line => __LINE__});
	my $xml  = XML::Simple->new();
	my $data = $xml->XMLin($return->{definition}, KeyAttr => {}, ForceArray => 1);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "data", value1 => $data, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# This array will store the boot devices in their boot priority.
	$return->{boot_devices} = [];
	foreach my $device (@{$data->{os}->[0]->{boot}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "device", value1 => $device->{dev}, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return->{boot_devices}}, $device->{dev};
	}
	
	# Pull out the RAM.
	$return->{current_ram} = $an->Readable->hr_to_bytes({size => $data->{currentMemory}->[0]->{content}, type => $data->{currentMemory}->[0]->{unit}});
	$return->{maximum_ram} = $an->Readable->hr_to_bytes({size => $data->{memory}->[0]->{content}, type => $data->{memory}->[0]->{unit}});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "return->current_ram", value1 => $return->{current_ram}, 
		name2 => "return->maximum_ram", value2 => $return->{maximum_ram}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Pull out the CPU info. The topology may not be set, in which case we return '0'.
	$return->{cpu}{total}   = $data->{vcpu}->[0]->{content};
# Example:
#  <vcpu>4</vcpu>
#  <cpu>
#      <topology sockets='1' cores='4' threads='1'/>
#  </cpu>
	$return->{cpu}{cores}   = $data->{cpu}->[0]->{cores}   ? $data->{cpu}->[0]->{cores}   : 0;
	$return->{cpu}{sockets} = $data->{cpu}->[0]->{sockets} ? $data->{cpu}->[0]->{sockets} : 0;
	$return->{cpu}{threads} = $data->{cpu}->[0]->{threads} ? $data->{cpu}->[0]->{threads} : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "return->cpu::total",   value1 => $return->{cpu}{total}, 
		name2 => "return->cpu::cores",   value2 => $return->{cpu}{cores}, 
		name3 => "return->cpu::sockets", value3 => $return->{cpu}{sockets}, 
		name4 => "return->cpu::threads", value4 => $return->{cpu}{threads}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Pull out the optical disks.
	foreach my $hash_ref (@{$data->{devices}->[0]->{disk}})
	{
		# Disk or cdrom?
		my $device_type = $hash_ref->{device};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "device_type", value1 => $device_type, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# The backing device (LV or path the the source file, usually) and cache policy, if set.
		my $backing_device = $hash_ref->{source}->[0]->{dev}   ? $hash_ref->{source}->[0]->{dev}   : $hash_ref->{source}->[0]->{file}; 
		my $cache_policy   = $hash_ref->{driver}->[0]->{cache} ? $hash_ref->{driver}->[0]->{cache} : "";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "backing_device", value1 => $backing_device, 
			name2 => "cache_policy",   value2 => $cache_policy, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# This is the device presented to the guest OS (vda, hdc, etc) and the bus type (virtio, IDE, etc)
		my $target_device = $hash_ref->{target}->[0]->{dev};
		my $target_bus    = $hash_ref->{target}->[0]->{bus};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "target_device", value1 => $target_device, 
			name2 => "target_bus",    value2 => $target_bus, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Store it all
		$return->{storage}{$device_type}{target_device}{$target_device} = {
			backing_device	=>	$backing_device, 
			cache_policy	=>	$cache_policy, 
			target_bus	=>	$target_bus, 
		};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "return->storage::${device_type}::target_device::${target_device}::backing_device", value1 => $return->{storage}{$device_type}{target_device}{$target_device}{backing_device}, 
			name2 => "return->storage::${device_type}::target_device::${target_device}::cache_policy",   value2 => $return->{storage}{$device_type}{target_device}{$target_device}{cache_policy}, 
			name3 => "return->storage::${device_type}::target_device::${target_device}::target_bus",     value3 => $return->{storage}{$device_type}{target_device}{$target_device}{target_bus}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Dig out the graphical connection information (the address is complicated for some reason...)
	$return->{graphics}{port}    = $data->{devices}->[0]->{graphics}->[0]->{port};
	$return->{graphics}{type}    = $data->{devices}->[0]->{graphics}->[0]->{type};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "return->graphics::port", value1 => $return->{graphics}{port}, 
		name2 => "return->graphics::type", value2 => $return->{graphics}{type}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$return->{graphics}{address} = "";
	foreach my $item (@{$data->{devices}->[0]->{graphics}->[0]->{'listen'}})
	{
		if (ref($item) eq "HASH")
		{
			$return->{graphics}{address} = $item->{address};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return->graphics::address", value1 => $return->{graphics}{address}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $return->{graphics}{address})
		{
			$return->{graphics}{address} = $item;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return->graphics::address", value1 => $return->{graphics}{address}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Record what happens in given shutdown events.
	$return->{on_poweroff} = $data->{on_poweroff}->[0];
	$return->{on_reboot}   = $data->{on_reboot}->[0];
	$return->{on_crash}    = $data->{on_crash}->[0];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "return->on_poweroff", value1 => $return->{on_poweroff}, 
		name2 => "return->on_reboot",   value2 => $return->{on_reboot}, 
		name3 => "return->on_crash",    value3 => $return->{on_crash}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Dig out the network details.
	foreach my $hash_ref (@{$data->{devices}->[0]->{interface}})
	{
		my $bridge      = $hash_ref->{source}->[0]->{bridge};
		my $vnet        = $hash_ref->{target}->[0]->{dev};
		my $model       = $hash_ref->{model}->[0]->{type};
		my $mac_address = $hash_ref->{mac}->[0]->{address};
		$return->{network}{mac_address}{$mac_address} = {
			bridge	=>	$bridge,
			model	=>	$model,
			vnet	=>	$vnet,
		};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "return->network::mac_address::${mac_address}::bridge", value1 => $return->{network}{mac_address}{$mac_address}{bridge}, 
			name2 => "return->network::mac_address::${mac_address}::model",  value2 => $return->{network}{mac_address}{$mac_address}{model}, 
			name3 => "return->network::mac_address::${mac_address}::vnet",   value3 => $return->{network}{mac_address}{$mac_address}{vnet}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return($return);
}

# This gets a list of shared files for the named anvil.
sub shared_files
{
	my $self      = shift;
	my $parameter = shift;
	
	# Clear any prior errors.
	my $an = $self->parent;
	$an->Alert->_set_error;
	
	# Pick up our parameters
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "target",   value1 => $target, 
		name2 => "port",     value2 => $port, 
		name3 => "password", value3 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# We use '-l' because we can't do normal file tests like checking for executable bits remotely and
	# it's a waste to parse the output in two different ways.
	my $ls_shell_call = $an->data->{path}{ls}." -l ".$an->data->{path}{shared_files};
	my $df_shell_call = $an->data->{path}{df}." -P";
	
	# This will store the list of files and the output of our 'ls' call that we'll parse to feed it.
	my $files     = {};
	my $partition = {};
	my $ls_return = [];
	my $df_return = [];
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote call
		# ls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "ls_shell_call", value1 => $ls_shell_call,
			name2 => "target",        value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $ls_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$ls_shell_call,
		});
		
		# df
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "df_shell_call", value1 => $df_shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $df_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$df_shell_call,
		});
	}
	else
	{
		### Local call
		# ls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "ls_shell_call", value1 => $ls_shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$ls_shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $ls_shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$ls_return}, $line;
		}
		close $file_handle;
		
		# df
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "df_shell_call", value1 => $df_shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open ($file_handle, "$df_shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $df_shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$df_return}, $line;
		}
		close $file_handle;
	}
	
	### Now parse out the data.
	# ls
	foreach my $line (@{$ls_return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /^(\S)(\S+)\s+\d+\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(.*)$/)
		{
			my $type   = $1;
			my $mode   = $2;
			my $user   = $3;
			my $group  = $4;
			my $size   = $5;
			my $month  = $6;
			my $day    = $7;
			my $time   = $8; # might be a year, look for '\d+:\d+'.
			my $file   = $9;
			my $target = "";
			if ($type eq "l")
			{
				# It's a symlink, strip off the destination.
				($file, $target) = ($file =~ /^(.*?) -> (.*)$/);
			}
			# These are so crude...
			my $is_iso = 0;
			if ($file =~ /\.iso/i)
			{
				$is_iso = 1;
			}
			my $is_executable = 0;
			if (($mode =~ /x/) or ($mode =~ /s/))
			{
				$is_executable = 1;
			}
			my $year = "";
			if ($time !~ /:/)
			{
				$year = $time;
				$time = "";
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0013", message_variables => {
				name1  => "type",          value1  => $type, 
				name2  => "mode",          value2  => $mode, 
				name3  => "user",          value3  => $user, 
				name4  => "group",         value4  => $group, 
				name5  => "size",          value5  => $size, 
				name6  => "month",         value6  => $month, 
				name7  => "day",           value7  => $day, 
				name8  => "time",          value8  => $time, 
				name9  => "year",          value9  => $year, 
				name10 => "file",          value10 => $file, 
				name11 => "target",        value11 => $target, 
				name12 => "is_iso",        value12 => $is_iso, 
				name13 => "is_executable", value13 => $is_executable, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$files->{$file}	= {
				type       => $type, 
				mode       => $mode, 
				user       => $user, 
				group      => $group, 
				size       => $size, 
				month      => $month, 
				day        => $day, 
				'time'     => $time,
				year       => $year,
				target     => $target, 
				optical    => $is_iso,
				executable => $is_executable,
			};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0013", message_variables => {
				name1  => "file",                value1  => $file,
				name2  => "${file}::type",       value2  => $files->{$file}{type},
				name3  => "${file}::mode",       value3  => $files->{$file}{mode},
				name4  => "${file}::owner",      value4  => $files->{$file}{user},
				name5  => "${file}::group",      value5  => $files->{$file}{group},
				name6  => "${file}::size",       value6  => $files->{$file}{size},
				name7  => "${file}::modified",   value7  => $files->{$file}{month},
				name8  => "${file}::day",        value8  => $files->{$file}{day},
				name9  => "${file}::time",       value9  => $files->{$file}{'time'},
				name10 => "${file}::year",       value10 => $files->{$file}{year},
				name11 => "${file}::target",     value11 => $files->{$file}{target},
				name12 => "${file}::optical",    value12 => $files->{$file}{optical},
				name13 => "${file}::executable", value13 => $files->{$file}{executable},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# df
	foreach my $line (@{$df_return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
	
		if ($line =~ /\s(\d+)-blocks\s/)
		{
			$partition->{block_size} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "block_size", value1 => $partition->{block_size},
			}, file => $THIS_FILE, line => __LINE__});
		}

		if ($line =~ /^\/.*?\s+(\d+)\s+(\d+)\s+(\d+)\s(\d+)%\s+\/shared/)
		{
			$partition->{total_space}  = $1;
			$partition->{used_space}   = $2;
			$partition->{free_space}   = $3;
			$partition->{used_percent} = $4;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "total_space",  value1 => $partition->{total_space},
				name2 => "used_space",   value2 => $partition->{used_space},
				name3 => "used_percent", value3 => $partition->{free_space},
				name4 => "free_space",   value4 => $partition->{used_percent},
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
	}
	
	return($files, $partition);
}

# This gathers DRBD data
sub drbd_data
{
	my $self      = shift;
	my $parameter = shift;
	
	# Clear any prior errors.
	my $an = $self->parent;
	$an->Alert->_set_error;
	
	# This will store the LVM data returned to the caller.
	my $return     = {};
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "target",   value1 => $target, 
		name2 => "port",     value2 => $port, 
		name3 => "password", value3 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# These will store the output from the 'drbdadm' call and /proc/drbd data.
	my $drbdadm_return   = [];
	my $proc_drbd_return = [];
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		# Is the module loaded?
		# 0 = Not loaded or not found
		# 1 = Loaded
		$return->{module_loaded} = $an->Check->kernel_module({
			module		=>	"drbd",
			target		=>	$target, 
			password	=>	$password,
			port		=>	$port,
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "module_loaded", value1 => $return->{module_loaded}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Read in drbdadm dump-xml regardless of whether the module is loaded.
		my $shell_call = $an->data->{path}{drbdadm}." dump-xml";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $drbdadm_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		
		# Now, read in /proc/drbd if the module was loaded.
		if ($return->{module_loaded})
		{
			my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "target",     value2 => $target,
			}, file => $THIS_FILE, line => __LINE__});
			(my $error, my $ssh_fh, $proc_drbd_return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
		}
	}
	else
	{
		### Local calls
		$return->{module_loaded} = $an->Check->kernel_module({module => "drbd"});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "module_loaded", value1 => $return->{module_loaded}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Read in drbdadm dump-xml regardless of whether the module is loaded.
		my $shell_call = $an->data->{path}{drbdadm}." dump-xml";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$drbdadm_return}, $line;
		}
		close $file_handle;
		
		# Now, read in /proc/drbd if the module was loaded.
		if ($return->{module_loaded})
		{
			my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line =  $_;
				push @{$proc_drbd_return}, $line;
			}
			close $file_handle;
		}
	}
	
	### Parsing the XML data is a little involved.
	# Convert the XML array into a string.
	my $xml_data = "";
	foreach my $line (@{$drbdadm_return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$xml_data .= "$line\n";
	}
	
	# Parse the data from XML::Simple
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "xml_data", value1 => $xml_data,
	}, file => $THIS_FILE, line => __LINE__});
	if ($xml_data)
	{
		my $xml  = XML::Simple->new();
		my $data = $xml->XMLin($xml_data, KeyAttr => {node => 'name'}, ForceArray => 1);
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "data", value1 => $data,
		}, file => $THIS_FILE, line => __LINE__});
		
		foreach my $a (keys %{$data})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "a", value1 => $a,
			}, file => $THIS_FILE, line => __LINE__});
			if ($a eq "file")
			{
				# This is just "/dev/drbd.conf", not needed.
			}
			elsif ($a eq "common")
			{
				foreach my $b (@{$data->{common}->[0]->{section}})
				{
					my $name = $b->{name};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "b",    value1 => $b,
						name2 => "name", value2 => $name,
					}, file => $THIS_FILE, line => __LINE__});
					if ($name eq "handlers")
					{
						$return->{fence}{handler}{name} = $b->{option}->[0]->{name};
						$return->{fence}{handler}{path} = $b->{option}->[0]->{value};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "fence::handler::name", value1 => $return->{fence}{handler}{name},
							name2 => "fence::handler::path", value2 => $return->{fence}{handler}{path},
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($name eq "disk")
					{
						$return->{fence}{policy} = $b->{option}->[0]->{value};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "fence::policy", value1 => $return->{fence}{policy},
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($name eq "syncer")
					{
						$return->{syncer}{rate} = $b->{option}->[0]->{value};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "syncer::rate", value1 => $return->{syncer}{rate},
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($name eq "startup")
					{
						foreach my $c (@{$b->{option}})
						{
							my $name  = $c->{name};
							my $value = $c->{value} ? $c->{value} : "--";
							$return->{startup}{$name} = $value;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "startup::$name", value1 => $return->{startup}{$name},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					elsif ($name eq "net")
					{
						foreach my $c (@{$b->{option}})
						{
							my $name  = $c->{name};
							my $value = $c->{value} ? $c->{value} : "--";
							$return->{net}{$name} = $value;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "net::$name", value1 => $return->{net}{$name},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					elsif ($name eq "options")
					{
						foreach my $c (@{$b->{option}})
						{
							my $name  = $c->{name};
							my $value = $c->{value} ? $c->{value} : "--";
							$return->{options}{$name} = $value;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "options::$name", value1 => $return->{options}{$name},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					else
					{
						# Unexpected element
						$an->Log->entry({log_level => 1, message_key => "tools_log_0008", message_variables => {
							element     => $b, 
							source_data => $an->data->{path}{drbdadm}." dump-xml", 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			elsif ($a eq "resource")
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "data->{resource}", value1 => $data->{resource},
				}, file => $THIS_FILE, line => __LINE__});
				foreach my $b (@{$data->{resource}})
				{
					my $resource = $b->{name};
					foreach my $c (@{$b->{host}})
					{
						my $ip_type        = $c->{address}->[0]->{family};
						my $ip_address     = $c->{address}->[0]->{content};
						my $tcp_port       = $c->{address}->[0]->{port};
						my $hostname       = $c->{name};
						my $metadisk       = "--";
						my $minor_number   = "--";
						my $drbd_device    = "--";
						my $backing_device = "--";
						if (defined $c->{device}->[0]->{minor})
						{
							### DRBD 8.3 data
							#print "DRBD 8.3\n";
							$metadisk       = $c->{'meta-disk'}->[0];
							$minor_number   = $c->{device}->[0]->{minor};
							$drbd_device    = $c->{device}->[0]->{content};
							$backing_device = $c->{disk}->[0];
						}
						else
						{
							### DRBD 8.4 data
							# TODO: This will have problems with multi-volume DRBD! Make it smarter.
							#print "DRBD 8.4\n";
							$metadisk       = $c->{volume}->[0]->{'meta-disk'}->[0];
							$minor_number   = $c->{volume}->[0]->{device}->[0]->{minor};
							$drbd_device    = $c->{volume}->[0]->{device}->[0]->{content};
							$backing_device = $c->{volume}->[0]->{disk}->[0];
						}
						
						# This is used for locating a resource by it's minor number
						$return->{minor_number}{$minor_number}{resource} = $resource;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "minor_number", value1 => $minor_number,
							name2 => "resource",     value2 => $return->{minor_number}{$minor_number}{resource},
						}, file => $THIS_FILE, line => __LINE__});
						
						# This is where the data itself is stored.
						$return->{resource}{$resource}{metadisk}       = $metadisk;
						$return->{resource}{$resource}{minor_number}   = $minor_number;
						$return->{resource}{$resource}{drbd_device}    = $drbd_device;
						$return->{resource}{$resource}{backing_device} = $backing_device;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
							name1 => "resource::${resource}::metadisk",       value1 => $return->{resource}{$resource}{metadisk},
							name2 => "resource::${resource}::minor_number",   value2 => $return->{resource}{$resource}{minor_number},
							name3 => "resource::${resource}::drbd_device",    value3 => $return->{resource}{$resource}{drbd_device},
							name4 => "resource::${resource}::backing_device", value4 => $return->{resource}{$resource}{backing_device},
						}, file => $THIS_FILE, line => __LINE__});
						
						# Make it easy to find the resource name and minor number by the given DRBD device path.
						$return->{device}{$drbd_device}{resource}     = $resource;
						$return->{device}{$drbd_device}{minor_number} = $minor_number;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "device::${drbd_device}::resource",     value1 => $return->{device}{$drbd_device}{resource},
							name2 => "device::${drbd_device}::minor_number", value2 => $return->{device}{$drbd_device}{minor_number},
						}, file => $THIS_FILE, line => __LINE__});
						
						# These entries are per-host.
						$return->{resource}{$resource}{hostname}{$hostname}{ip_address} = $ip_address;
						$return->{resource}{$resource}{hostname}{$hostname}{ip_type}    = $ip_type;
						$return->{resource}{$resource}{hostname}{$hostname}{tcp_port}   = $tcp_port;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "resource::${resource}::hostname::${hostname}::ip_address", value1 => $return->{resource}{$resource}{hostname}{$hostname}{ip_address},
							name2 => "resource::${resource}::hostname::${hostname}::ip_type",    value2 => $return->{resource}{$resource}{hostname}{$hostname}{ip_type},
							name3 => "resource::${resource}::hostname::${hostname}::tcp_port",   value3 => $return->{resource}{$resource}{hostname}{$hostname}{tcp_port},
						}, file => $THIS_FILE, line => __LINE__});
					}
					foreach my $c (@{$b->{section}})
					{
						my $name = $c->{name};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "c",    value1 => $c,
							name2 => "name", value2 => $name,
						}, file => $THIS_FILE, line => __LINE__});
						if ($name eq "disk")
						{
							foreach my $d (@{$c->{options}})
							{
								my $name  = $d->{name};
								my $value = $d->{value};
								$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
									name1 => "d",     value1 => $d,
									name2 => "name",  value2 => $name,
									name3 => "value", value3 => $value,
								}, file => $THIS_FILE, line => __LINE__});
								
								$return->{resource_file}{$resource}{disk}{$name} = $value;
								$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
									name1 => "resource_file::${resource}::disk::${name}", value1 => $return->{resource_file}{$resource}{disk}{$name},
								}, file => $THIS_FILE, line => __LINE__});
							}
						}
					}
				}
			}
			else
			{
				$an->Log->entry({log_level => 1, message_key => "tools_log_0008", message_variables => {
					element     => $a, 
					source_data => $an->data->{path}{drbdadm}." dump-xml", 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Now process /proc/drbd is the 'drbd' module was loaded.
	if ($return->{module_loaded})
	{
		my $resource     = "";
		my $minor_number = "";
		foreach my $line (@{$proc_drbd_return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /version: (.*?) \(/)
			{
				$return->{version} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "version", value1 => $return->{version},
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			elsif ($line =~ /GIT-hash: (.*?) build by (.*?), (\S+) (.*)$/)
			{
				$return->{git_hash}   = $1;
				$return->{builder}    = $2;
				$return->{build_date} = $3;
				$return->{build_time} = $4;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "git_hash",   value1 => $return->{git_hash},
					name2 => "builder",    value2 => $return->{builder},
					name3 => "build_date", value3 => $return->{build_date},
					name4 => "build_time", value4 => $return->{build_time},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# This is just for hash key consistency
				if ($line =~ /^(\d+): cs:(.*?) ro:(.*?)\/(.*?) ds:(.*?)\/(.*?) (.*?) (.*)$/)
				{
					   $minor_number     = $1;
					my $connection_state = $2;
					my $my_role          = $3;
					my $peer_role        = $4;
					my $my_disk_state    = $5;
					my $peer_disk_state  = $6;
					my $drbd_protocol    = $7;
					my $io_flags         = $8;	# See: http://www.drbd.org/users-guide/ch-admin.html#s-io-flags
					   $resource         = $return->{minor_number}{$minor_number}{resource};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "resource::${resource}::minor_number",     value1 => $return->{resource}{$resource}{minor_number},
						name2 => "resource::${resource}::connection_state", value2 => $return->{resource}{$resource}{connection_state},
					}, file => $THIS_FILE, line => __LINE__});
					
					$return->{resource}{$resource}{minor_number}     = $minor_number;
					$return->{resource}{$resource}{connection_state} = $connection_state;
					$return->{resource}{$resource}{my_role}          = $my_role;
					$return->{resource}{$resource}{peer_role}        = $peer_role;
					$return->{resource}{$resource}{my_disk_state}    = $my_disk_state;
					$return->{resource}{$resource}{peer_disk_state}  = $peer_disk_state;
					$return->{resource}{$resource}{drbd_protocol}    = $drbd_protocol;
					$return->{resource}{$resource}{io_flags}         = $io_flags;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
						name1 => "resource::${resource}::minor_number",     value1 => $return->{resource}{$resource}{minor_number},
						name2 => "resource::${resource}::connection_state", value2 => $return->{resource}{$resource}{connection_state},
						name3 => "resource::${resource}::my_role",          value3 => $return->{resource}{$resource}{my_role},
						name4 => "resource::${resource}::peer_role",        value4 => $return->{resource}{$resource}{peer_role},
						name5 => "resource::${resource}::my_disk_state",    value5 => $return->{resource}{$resource}{my_disk_state},
						name6 => "resource::${resource}::peer_disk_state",  value6 => $return->{resource}{$resource}{peer_disk_state},
						name7 => "resource::${resource}::drbd_protocol",    value7 => $return->{resource}{$resource}{drbd_protocol},
						name8 => "resource::${resource}::io_flags",         value8 => $return->{resource}{$resource}{io_flags},
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ /ns:(.*?) nr:(.*?) dw:(.*?) dr:(.*?) al:(.*?) bm:(.*?) lo:(.*?) pe:(.*?) ua:(.*?) ap:(.*?) ep:(.*?) wo:(.*?) oos:(.*)$/)
				{
					# Details: http://www.drbd.org/users-guide/ch-admin.html#s-performance-indicators
					my $network_sent            = $1;	# KiB send
					my $network_received        = $2;	# KiB received
					my $disk_write              = $3;	# KiB wrote
					my $disk_read               = $4;	# KiB read
					my $activity_log_updates    = $5;	# Number of updates of the activity log area of the meta data.
					my $bitmap_updates          = $6;	# Number of updates of the bitmap area of the meta data.
					my $local_count             = $7;	# Number of open requests to the local I/O sub-system issued by DRBD.
					my $pending_requests        = $8;	# Number of requests sent to the partner, but that have not yet been answered by the latter.
					my $unacknowledged_requests = $9;	# Number of requests received by the partner via the network connection, but that have not yet been answered.
					my $app_pending_requests    = $10;	# Number of block I/O requests forwarded to DRBD, but not yet answered by DRBD.
					my $epoch_objects           = $11;	# Number of epoch objects. Usually 1. Might increase under I/O load when using either the barrier or the none write ordering method.
					my $write_order             = $12;	# Currently used write ordering method: b(barrier), f(flush), d(drain) or n(none).
					my $out_of_sync             = $13;	# KiB that are out of sync
					
					# Make things easier 
					if    ($write_order eq "b") { $write_order = "barrier"; }
					elsif ($write_order eq "f") { $write_order = "flush";   }
					elsif ($write_order eq "d") { $write_order = "drain";   }
					elsif ($write_order eq "n") { $write_order = "none";    }
					
					$return->{resource}{$resource}{network_sent}            = $an->Readable->hr_to_bytes({size => $network_sent,     type => "KiB"});
					$return->{resource}{$resource}{network_received}        = $an->Readable->hr_to_bytes({size => $network_received, type => "KiB"});
					$return->{resource}{$resource}{disk_write}              = $an->Readable->hr_to_bytes({size => $disk_write,       type => "KiB"});
					$return->{resource}{$resource}{disk_read}               = $an->Readable->hr_to_bytes({size => $disk_read,        type => "KiB"});
					$return->{resource}{$resource}{activity_log_updates}    = $activity_log_updates;
					$return->{resource}{$resource}{bitmap_updates}          = $bitmap_updates;
					$return->{resource}{$resource}{local_count}             = $local_count;
					$return->{resource}{$resource}{pending_requests}        = $pending_requests;
					$return->{resource}{$resource}{unacknowledged_requests} = $unacknowledged_requests;
					$return->{resource}{$resource}{app_pending_requests}    = $app_pending_requests;
					$return->{resource}{$resource}{epoch_objects}           = $epoch_objects;
					$return->{resource}{$resource}{write_order}             = $write_order;
					$return->{resource}{$resource}{out_of_sync}             = $an->Readable->hr_to_bytes({size => $out_of_sync, type => "KiB"});
					
					$an->Log->entry({log_level => 3, message_key => "an_variables_0013", message_variables => {
						name1  => "resource::${resource}::network_sent",            value1  => $return->{resource}{$resource}{network_sent},
						name2  => "resource::${resource}::network_received",        value2  => $return->{resource}{$resource}{network_received},
						name3  => "resource::${resource}::disk_write",              value3  => $return->{resource}{$resource}{disk_write},
						name4  => "resource::${resource}::disk_read",               value4  => $return->{resource}{$resource}{disk_read},
						name5  => "resource::${resource}::activity_log_updates",    value5  => $return->{resource}{$resource}{activity_log_updates},
						name6  => "resource::${resource}::bitmap_updates",          value6  => $return->{resource}{$resource}{bitmap_updates},
						name7  => "resource::${resource}::local_count",             value7  => $return->{resource}{$resource}{local_count},
						name8  => "resource::${resource}::pending_requests",        value8  => $return->{resource}{$resource}{pending_requests},
						name9  => "resource::${resource}::unacknowledged_requests", value9  => $return->{resource}{$resource}{unacknowledged_requests},
						name10 => "resource::${resource}::app_pending_requests",    value10 => $return->{resource}{$resource}{app_pending_requests},
						name11 => "resource::${resource}::epoch_objects",           value11 => $return->{resource}{$resource}{epoch_objects},
						name12 => "resource::${resource}::write_order",             value12 => $return->{resource}{$resource}{write_order},
						name13 => "resource::${resource}::out_of_sync",             value13 => $return->{resource}{$resource}{out_of_sync},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# The resync lines aren't consistent, so I pull out data one piece at a time.
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
					if ($line =~ /sync'ed: (.*?)%/)
					{
						my $percent_synced = $1;
						$return->{resource}{$resource}{syncing}        = 1;
						$return->{resource}{$resource}{percent_synced} = $percent_synced;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "resource::${resource}::syncing",        value1 => $return->{resource}{$resource}{syncing},
							name2 => "resource::${resource}::percent_synced", value2 => $return->{resource}{$resource}{percent_synced},
						}, file => $THIS_FILE, line => __LINE__});
					}
					if ($line =~ /\((\d+)\/(\d+)\)M/)
					{
						# The 'M' is 'Mibibyte'
						my $left_to_sync  = $1;
						my $total_to_sync = $2;
						
						$return->{resource}{$resource}{left_to_sync}  = $an->Readable->hr_to_bytes({size => $left_to_sync,  type => "MiB"});
						$return->{resource}{$resource}{total_to_sync} = $an->Readable->hr_to_bytes({size => $total_to_sync, type => "MiB"});
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "resource::${resource}::left_to_sync",  value1 => $return->{resource}{$resource}{left_to_sync},
							name2 => "resource::${resource}::total_to_sync", value2 => $return->{resource}{$resource}{total_to_sync},
						}, file => $THIS_FILE, line => __LINE__});
					}
					if ($line =~ /finish: (\d+):(\d+):(\d+)/)
					{
						my $hours   = $1;
						my $minutes = $2;
						my $seconds = $3;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "hours",   value1 => $hours, 
							name2 => "minutes", value2 => $minutes, 
							name3 => "seconds", value3 => $seconds,
						}, file => $THIS_FILE, line => __LINE__});
						
						# Convert to raw seconds.
						$return->{resource}{$resource}{eta_to_sync} = ($hours * 3600) + ($minutes * 60) + $seconds;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name4 => "resource::${resource}::eta_to_sync", value4 => $return->{resource}{$resource}{eta_to_sync}, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					if ($line =~ /speed: (.*?) \((.*?)\)/)
					{
						my $current_speed =  $1;
						my $average_speed =  $2;
						   $current_speed =~ s/,//g;
						   $average_speed =~ s/,//g;
						
						$return->{resource}{$resource}{current_speed} = $an->Readable->hr_to_bytes({size => $current_speed, type => "KiB"});
						$return->{resource}{$resource}{average_speed} = $an->Readable->hr_to_bytes({size => $average_speed, type => "KiB"});
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "resource::${resource}::current_speed", value1 => $return->{resource}{$resource}{current_speed},
							name2 => "resource::${resource}::average_speed", value2 => $return->{resource}{$resource}{average_speed},
						}, file => $THIS_FILE, line => __LINE__});
					}
					if ($line =~ /want: (.*?) K/)
					{
						# The 'want' line is only calculated on the sync target
						my $want_speed =  $1;
						   $want_speed =~ s/,//g;
						
						$return->{resource}{$resource}{want_speed} = $an->Readable->hr_to_bytes({size => $want_speed, type => "KiB"});
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "resource::${resource}::want_speed", value1 => $return->{resource}{$resource}{want_speed},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
		}
	}
	
	return($return);
}

# This gathers the LVM data for a machine (local if no 'target' is defined).
sub lvm_data
{
	my $self      = shift;
	my $parameter = shift;
	
	# Clear any prior errors.
	my $an = $self->parent;
	$an->Alert->_set_error;
	
	# This will store the LVM data returned to the caller.
	my $data     = {};
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "target",   value1 => $target, 
		name2 => "port",     value2 => $port, 
		name3 => "password", value3 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# These will store the output from the 'pvs', 'vgs' and 'lvs' calls, respectively.
	my $pvscan_return = [];
	my $vgscan_return = [];
	my $lvscan_return = [];
	my $pvs_return    = [];
	my $vgs_return    = [];
	my $lvs_return    = [];
	
	### NOTE: At this time, I don't care about the pvscan, vgscan or lvscan data. I call them mainly to 
	###       make sure that the pvs, vgs and lvs output is current.
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Local calls
		# Get the PV scan data
		my $shell_call = $an->data->{path}{pvscan};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $pvscan_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		
		# Get the VG scan data
		$shell_call = $an->data->{path}{vgscan};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $vgscan_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		
		# Get the LV scan data
		$shell_call = $an->data->{path}{lvscan};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $lvscan_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		
		# Get the 'pvs' data
		$shell_call = $an->data->{path}{pvs}." --noheadings --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $pvs_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		
		# Get the 'vgs' data
		$shell_call = $an->data->{path}{vgs}." --noheadings --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $vgs_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		
		# Now the 'lvs' data.
		$shell_call = $an->data->{path}{lvs}." --noheadings --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $lvs_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		### Remote calls
		# Get the PV scan data
		my $shell_call = $an->data->{path}{pvscan};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$pvscan_return}, $line;
		}
		close $file_handle;
		
		# Get the VG scan data
		$shell_call = $an->data->{path}{vgscan};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open ($file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$vgscan_return}, $line;
		}
		close $file_handle;
		
		# Get the LV scan data
		$shell_call = $an->data->{path}{lvscan};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open ($file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$lvscan_return}, $line;
		}
		close $file_handle;
		
		# Get the 'pvs' data
		$shell_call = $an->data->{path}{pvs}." --noheadings --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open ($file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$pvs_return}, $line;
		}
		close $file_handle;
		
		# Get the 'vgs' data
		$shell_call = $an->data->{path}{vgs}." --noheadings --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open ($file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$vgs_return}, $line;
		}
		close $file_handle;
		
		# Now the 'lvs' data.
		$shell_call = $an->data->{path}{lvs}." --noheadings --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open ($file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$lvs_return}, $line;
		}
		close $file_handle;
	}
	
	### NOTE: At this time, I don't care about the pvscan, vgscan or lvscan data. I call them mainly to 
	###       make sure that the pvs, vgs and lvs output is current.
	
	### Now parse out the data.
	# 'pvscan' data
	foreach my $line (@{$pvscan_return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# 'vgscan' data
	foreach my $line (@{$vgscan_return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# 'lvscan' data
	foreach my $line (@{$lvscan_return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# 'pvs' data
	foreach my $line (@{$pvs_return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		#   pv_name,          vg_name,               pv_fmt,  pv_attr,     pv_size,     pv_free,    pv_used,    pv_uuid
		my ($physical_volume, $used_by_volume_group, $format, $attributes, $total_size, $free_size, $used_size, $uuid) = (split /#!#/, $line);
		$total_size =~ s/B$//;
		$free_size  =~ s/B$//;
		$used_size  =~ s/B$//;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
			name1 => "physical_volume",      value1 => $physical_volume,
			name2 => "used_by_volume_group", value2 => $used_by_volume_group,
			name3 => "format",               value3 => $format,
			name4 => "attributes",           value4 => $attributes,
			name5 => "total_size",           value5 => $total_size,
			name6 => "free_size",            value6 => $free_size,
			name7 => "used_size",            value7 => $used_size,
			name8 => "uuid",                 value8 => $uuid,
		}, file => $THIS_FILE, line => __LINE__});
		$data->{physical_volume}{$physical_volume}{used_by_volume_group} = $used_by_volume_group;
		$data->{physical_volume}{$physical_volume}{attributes}           = $attributes;
		$data->{physical_volume}{$physical_volume}{total_size}           = $total_size;
		$data->{physical_volume}{$physical_volume}{free_size}            = $free_size;
		$data->{physical_volume}{$physical_volume}{used_size}            = $used_size;
		$data->{physical_volume}{$physical_volume}{uuid}                 = $uuid;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
			name1 => "physical_volume::${physical_volume}::used_by_volume_group", value1 => $data->{physical_volume}{$physical_volume}{used_by_volume_group},
			name2 => "physical_volume::${physical_volume}::attributes",           value2 => $data->{physical_volume}{$physical_volume}{attributes},
			name3 => "physical_volume::${physical_volume}::total_size",           value3 => $data->{physical_volume}{$physical_volume}{total_size},
			name4 => "physical_volume::${physical_volume}::free_size",            value4 => $data->{physical_volume}{$physical_volume}{free_size},
			name5 => "physical_volume::${physical_volume}::used_size",            value5 => $data->{physical_volume}{$physical_volume}{used_size},
			name6 => "physical_volume::${physical_volume}::uuid",                 value6 => $data->{physical_volume}{$physical_volume}{uuid},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# 'vgs' data
	foreach my $line (@{$vgs_return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		#   vg_name,       vg_attr,     vg_extent_size,        vg_extent_count, vg_uuid, vg_size,            vg_free_count, vg_free,     pv_name
		my ($volume_group, $attributes, $physical_extent_size, $extent_count,   $uuid,   $volume_group_size, $free_extents, $free_space, $pv_name) = split /#!#/, $line;
		   $physical_extent_size =  "" if not defined $physical_extent_size;
		   $volume_group_size    =  "" if not defined $volume_group_size;
		   $free_space           =  "" if not defined $free_space;
		   $attributes           =  "" if not defined $attributes;
		   $physical_extent_size =~ s/B$//;
		   $volume_group_size    =~ s/B$//;
		   $free_space           =~ s/B$//;
		my $used_extents         =  $extent_count      - $free_extents if (($extent_count)      && ($free_extents));
		my $used_space           =  $volume_group_size - $free_space   if (($volume_group_size) && ($free_space));
		$an->Log->entry({log_level => 3, message_key => "an_variables_0011", message_variables => {
			name1  => "volume_group",         value1  => $volume_group,
			name2  => "attributes",           value2  => $attributes,
			name3  => "physical_extent_size", value3  => $physical_extent_size,
			name4  => "extent_count",         value4  => $extent_count,
			name5  => "uuid",                 value5  => $uuid,
			name6  => "volume_group_size",    value6  => $volume_group_size,
			name7  => "used_extents",         value7  => $used_extents,
			name8  => "used_space",           value8  => $used_space,
			name9  => "free_extents",         value9  => $free_extents,
			name10 => "free_space",           value10 => $free_space,
			name11 => "pv_name",              value11 => $pv_name,
		}, file => $THIS_FILE, line => __LINE__});
		$data->{volume_group}{$volume_group}{clustered}            = $attributes =~ /c$/ ? 1 : 0;
		$data->{volume_group}{$volume_group}{physical_extent_size} = $physical_extent_size;
		$data->{volume_group}{$volume_group}{extent_count}         = $extent_count;
		$data->{volume_group}{$volume_group}{uuid}                 = $uuid;
		$data->{volume_group}{$volume_group}{size}                 = $volume_group_size;
		$data->{volume_group}{$volume_group}{used_extents}         = $used_extents;
		$data->{volume_group}{$volume_group}{used_space}           = $used_space;
		$data->{volume_group}{$volume_group}{free_extents}         = $free_extents;
		$data->{volume_group}{$volume_group}{free_space}           = $free_space;
		$data->{volume_group}{$volume_group}{pv_name}              = $pv_name;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0010", message_variables => {
			name1  => "volume_group::${volume_group}::clustered",            value1  => $data->{volume_group}{$volume_group}{clustered},
			name2  => "volume_group::${volume_group}::physical_extent_size", value2  => $data->{volume_group}{$volume_group}{physical_extent_size},
			name3  => "volume_group::${volume_group}::extent_count",         value3  => $data->{volume_group}{$volume_group}{extent_count},
			name4  => "volume_group::${volume_group}::uuid",                 value4  => $data->{volume_group}{$volume_group}{uuid},
			name5  => "volume_group::${volume_group}::size",                 value5  => $data->{volume_group}{$volume_group}{size},
			name6  => "volume_group::${volume_group}::used_extents",         value6  => $data->{volume_group}{$volume_group}{used_extents},
			name7  => "volume_group::${volume_group}::used_space",           value7  => $data->{volume_group}{$volume_group}{used_space},
			name8  => "volume_group::${volume_group}::free_extents",         value8  => $data->{volume_group}{$volume_group}{free_extents},
			name9  => "volume_group::${volume_group}::free_space",           value9  => $data->{volume_group}{$volume_group}{free_space},
			name10 => "volume_group::${volume_group}::pv_name",              value10 => $data->{volume_group}{$volume_group}{pv_name},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# 'lvs' data
	foreach my $line (@{$lvs_return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		#   lv_name,         vg_name,           lv_attr,     lv_size,     lv_uuid, lv_path, devices
		my ($logical_volume, $on_volume_group,  $attributes, $total_size, $uuid,   $path,   $devices) = (split /#!#/, $line);
		$total_size =~ s/B$//;
		$devices    =~ s/\(\d+\)//g;	# Strip the starting PE number
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "logical_volume",  value1 => $logical_volume,
			name2 => "on_volume_group", value2 => $on_volume_group,
			name3 => "attributes",      value3 => $attributes,
			name4 => "total_size",      value4 => $total_size,
			name5 => "uuid",            value5 => $uuid,
			name6 => "path",            value6 => $path,
			name7 => "device(s)",       value7 => $devices,
		}, file => $THIS_FILE, line => __LINE__});
		$data->{logical_volume}{$path}{name}            = $logical_volume;
		$data->{logical_volume}{$path}{on_volume_group} = $on_volume_group;
		$data->{logical_volume}{$path}{active}          = ($attributes =~ /.{4}(.{1})/)[0] eq "a" ? 1 : 0;
		$data->{logical_volume}{$path}{attributes}      = $attributes;
		$data->{logical_volume}{$path}{total_size}      = $total_size;
		$data->{logical_volume}{$path}{uuid}            = $uuid;
		$data->{logical_volume}{$path}{on_devices}      = $devices;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "logical_volume::${path}::name",            value1 => $data->{logical_volume}{$path}{name},
			name2 => "logical_volume::${path}::on_volume_group", value2 => $data->{logical_volume}{$path}{on_volume_group},
			name3 => "logical_volume::${path}::active",          value3 => $data->{logical_volume}{$path}{active},
			name4 => "logical_volume::${path}::attribute",       value4 => $data->{logical_volume}{$path}{attributes},
			name5 => "logical_volume::${path}::total_size",      value5 => $data->{logical_volume}{$path}{total_size},
			name6 => "logical_volume::${path}::uuid",            value6 => $data->{logical_volume}{$path}{uuid},
			name7 => "logical_volume::${path}::on_devices",      value7 => $data->{logical_volume}{$path}{on_devices},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return($data);
}

# This looks for a server by name on both nodes. If it is not found on either, it looks for the server in
# /server/definitions/<server>.xml. Once found (if found), the UUID is pulled out and returned to the caller.
sub server_uuid
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $uuid = "";
	my $server = $parameter->{server};
	my $anvil  = $parameter->{anvil};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "server", value1 => $server, 
		name2 => "anvil",  value2 => $anvil, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $server)
	{
		# No server? pur quois?!
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0049", code => 49, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	# If an anvil wasn't specified, see if one was set by cgi.
	if ((not $anvil) && (($an->data->{cgi}{cluster}) or ($an->data->{cgi}{anvil})))
	{
		$anvil = $an->data->{cgi}{anvil} ? $an->data->{cgi}{anvil} : $an->data->{cgi}{cluster};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "anvil", value1 => $anvil, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	### TODO: Finish this, but remember that this is likely being called from Striker so we can't assume
	###       this hostname is part of an Anvil!. 
	# Now check to see if the server is running on one of the nodes.
	my $node1           = "";
	my $node2           = "";
	my $node1_is_remote = 0;
	my $anvil_password  = "";
	if ($anvil)
	{
		# Assume this machine is a striker dashboard.
		my $return          = $an->Get->remote_anvil_details({anvil => $anvil});
		   $node1           = $return->{node1};
		   $node2           = $return->{node2};
		   $node1_is_remote = 1;
		   $anvil_password  = $return->{anvil_password};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "node1",           value1 => $node1, 
			name2 => "node2",           value2 => $node2, 
			name3 => "node1_is_remote", value3 => $node1_is_remote, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil_password", value1 => $an->data->{sys}{anvil_password}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Assume this machine is in an Anvil! and find the peer.
		my $return = $an->Get->local_anvil_details({
			hostname_full	=>	$an->hostname,
			hostname_short	=>	$an->short_hostname,
			config_file	=>	$an->data->{path}{cman_config},
		});
		   $node1           = $return->{local_node};
		   $node2           = $return->{peer_node};
		   $node1_is_remote = 0;
		   $anvil           = $return->{anvil_name};
		   $anvil_password  = $return->{anvil_password};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "node1",           value1 => $node1, 
			name2 => "node2",           value2 => $node2, 
			name3 => "node1_is_remote", value3 => $node1_is_remote, 
			name4 => "anvil",           value4 => $anvil, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil_password", value1 => $an->data->{sys}{anvil_password}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Now look on each machine for the server.
	
	# How I make the call to node1 depends on whether it is local or not. Node 2 will always be a remote call.
	my $server_found = 0;
	
	# Try node 1. This will check for a running server first and, if it's not found, check 
	# /server/definitions/${server}.xml.
	my $xml = $an->Get->server_xml({
		remote   => $node1_is_remote, 
		server   => $server, 
		node     => $node1, 
		password => $anvil_password, 
	});
	
	# If I don't have XML yet, try node 2.
	if (not $xml)
	{
		$xml = $an->Get->server_xml({
			remote   => 1, 
			server   => $server, 
			node     => $node2, 
			password => $anvil_password, 
		});
	}
	
	# If I still don't have XML, try to see if we have it in the database.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "length(xml)",     value1 => length($xml), 
		name2 => "sys::read_db_id", value2 => $an->data->{sys}{read_db_id}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $xml) && ($an->data->{sys}{read_db_id}))
	{
		my $query = "
SELECT 
    server_definition 
FROM 
    server 
WHERE 
    server_name = ".$an->data->{sys}{use_db_fh}->quote($server)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$xml = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "length(xml)", value1 => length($xml), 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I still don't have XML, then I am out of ideas...
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "length(xml)", value1 => length($xml), 
	}, file => $THIS_FILE, line => __LINE__});
	if ($xml)
	{
		# Dig out the UUID.
		foreach my $line (split/\n/, $xml)
		{
			if ($line =~ /<uuid>([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})<\/uuid>/)
			{
				$uuid = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "uuid", value1 => $uuid, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Store the XML in a system variable.
		$an->data->{server}{$server}{uuid} = $uuid if not $an->data->{server}{$server}{uuid};
		$an->data->{server}{$server}{xml}  = $xml  if not $an->data->{server}{$server}{xml};
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "uuid", value1 => $uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	return($uuid);
}

# This looks for a running server on the node (or locally if 'remote => 0' and returns the XML and a single 
# string.
sub server_xml
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $remote   = $parameter->{remote};
	my $node     = $parameter->{node};
	my $server   = $parameter->{server};
	my $password = $parameter->{password};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "remote", value1 => $remote, 
		name2 => "node",   value2 => $node, 
		name3 => "server", value3 => $server, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $server_found = 0;
	my $xml          = "";
	my $shell_call   = $an->data->{path}{virsh}." list --all";
	if ($remote)
	{
		# It is remote. Note that the node might not be accessible.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^error:/)
			{
				# Not running
				last;
			}
			if ($line =~ /^\d+ (.*?) /)
			{
				my $this_server_name = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server",           value1 => $server, 
					name2 => "this_server_name", value2 => $this_server_name, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($server eq $this_server_name)
				{
					$server_found = 1;
				}
			}
		}
		
		# Is the server running here?
		if ($server_found)
		{
			# Found it here, read in it's XML.
			my $shell_call = "virsh dumpxml $server";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "target",     value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
				password	=>	$password,
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($line =~ /error: /)
				{
					# No good, bail out.
					$xml = "";
					last;
				}
				
				$xml .= "$line\n";
			}
		}
		
		# If I still don't have XML data, try to find the server's XML file in /shared/definitions.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "length(xml)", value1 => length($xml), 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $xml)
		{
			my $definitions_file = $an->data->{path}{definitions}."/${server}.xml";
			my $shell_call = "
if [ -e $definitions_file ];
then
    ".$an->data->{path}{cat}." $definitions_file;
fi
";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "target",     value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
				password	=>	$password,
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				$xml .= "$line\n";
			}
		}
	}
	else
	{
		# It is local.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			   $line =~ s/^\s+//;
			   $line =~ s/\s+$//;
			   $line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /^error:/)
			{
				# Not running
				last;
			}
			if ($line =~ /^\d+ (.*?) /)
			{
				my $this_server_name = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server",           value1 => $server, 
					name2 => "this_server_name", value2 => $this_server_name, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($server eq $this_server_name)
				{
					$server_found = 1;
				}
			}
		}
		close $file_handle;
		
		# Is the server running here?
		if ($server_found)
		{
			# Found it here, read in it's XML.
			my $shell_call = "virsh dumpxml $server";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line =  $_;
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /error: /)
				{
					# No good, bail out.
					$xml = "";
					last;
				}
				
				$xml .= "$line\n";
			}
			close $file_handle;
		}
		
		# If I still don't have XML data, try to find the server's XML file in /shared/definitions.
		my $definitions_file = $an->data->{path}{definitions}."/${server}.xml";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "length(xml)",      value1 => length($xml), 
			name2 => "definitions_file", value2 => $definitions_file, 
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $xml) && (-e $definitions_file))
		{
			my $shell_call = $definitions_file;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				$xml .= "$line\n";
			}
			close $file_handle;
		}
	}
	
	return($xml);
}

# This reads /etc/passwd to figure out the requested user's home directory.
sub users_home
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $user = $parameter->{user};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "user", value1 => $user, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $user)
	{
		# No user? No bueno...
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0041", message_variables => {
			user => $user, 
		}, code => 38, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	my $users_home = "";
	my $shell_call = $an->data->{path}{etc_passwd};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /$user:/)
		{
			$users_home = (split/:/, $line)[5];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "users_home", value1 => $users_home, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	close $file_handle;
	
	# Do I have the a user's $HOME now?
	if (not $users_home)
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0040", message_variables => {
			user => $user, 
		}, code => 34, file => "$THIS_FILE", line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "users_home", value1 => $users_home, 
	}, file => $THIS_FILE, line => __LINE__});
	return($users_home);
}

# Get the local user's RSA public key.
sub rsa_public_key
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $user = $parameter->{user};
	if (not $user)
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0039", code => 33, file => "$THIS_FILE", line => __LINE__});
	}
	
	my $key_size = $parameter->{key_size} ? $parameter->{key_size} : 8191;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_rsa_public_key" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "user",     value1 => $user, 
		name2 => "key_size", value2 => $key_size,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Find the public RSA key file for this user.
	my $users_home = $an->Get->users_home({user => $user});
	my $rsa_file   = "$users_home/.ssh/id_rsa.pub";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "rsa_file", value1 => $rsa_file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	#If it doesn't exit, create it,
	if (not -e $rsa_file)
	{
		# Generate it.
		my $ok = $an->Remote->generate_rsa_public_key({user => $user, key_size => $key_size});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "ok", value1 => $ok, 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $ok)
		{
			# Failed, return.
			return("", "");
		}
	}
	
	# Read it!
	my $key_owner  = "";
	my $key_string = "";
	my $shell_call = $rsa_file;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /^ssh-rsa (.*?) (.*?\@.*)$/)
		{
			$key_string = $1;
			$key_owner  = $2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "key_owner",  value1 => $key_owner, 
				name2 => "key_string", value2 => $key_string, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	close $file_handle;
	
	# If I failed to read the key, exit.
	if ((not $key_owner) or (not $key_string))
	{
		# Foo. Warn the user and return.
		$an->Alert->warning({message_key => "warning_title_0006", message_variables => {
			user	=>	$user,
			file	=>	$rsa_file,
		}, file => $THIS_FILE, line => __LINE__});
		return("", "");
	}
	else
	{
		# We're good!
		$an->Log->entry({log_level => 3, message_key => "notice_message_0008", message_variables => {
			owner	=>	$key_owner, 
			key	=>	$key_string, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "key_owner",  value1 => $key_owner, 
		name2 => "key_string", value2 => $key_string, 
	}, file => $THIS_FILE, line => __LINE__});
	return($key_owner, $key_string);
}

# Uses 'uuidgen' to generate a UUID and return it to the caller.
sub uuid
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	### TODO: Figure out why the heck I did this... Remove it, most likely.
	# Set the 'uuidgen' path if set by the user.
	$an->_uuidgen_path($parameter->{uuidgen_path}) if $parameter->{uuidgen_path};
	
	# If the user asked for the host UUID, read it in.
	my $uuid = "";
	if ((exists $parameter->{get}) && ($parameter->{get} eq "host_uuid"))
	{
		my $shell_call = $an->data->{path}{host_uuid};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			$uuid = lc($_);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "uuid", value1 => $uuid, 
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
		close $file_handle;
	}
	else
	{
		my $shell_call = $an->_uuidgen_path." -r";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			$uuid = lc($_);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "uuid", value1 => $uuid, 
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
		close $file_handle;
	}
	
	# Did we get a sane value?
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "uuid", value1 => $uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($uuid =~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)
	{
		# Yup. Set the host UUID if that's what we read.
		$an->data->{sys}{host_uuid} = $uuid if ((exists $parameter->{get}) && ($parameter->{get} eq "host_uuid"));
	}
	else
	{
		# derp
		$an->Log->entry({log_level => 0, message_key => "error_message_0023", message_variables => {
			bad_uuid => $uuid, 
		}, file => $THIS_FILE, line => __LINE__});
		$uuid = "";
	}
	
	return($uuid);
}

# Sets/returns the "am" suffix.
sub say_am
{
	my $self = shift;
	my $say  = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if ( defined $say )
	{
		$self->{SAY}->{AM} = $say;
	}
	
	return $self->{SAY}->{AM};
}

# Sets/returns the "pm" suffix.
sub say_pm
{
	my $self = shift;
	my $say  = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if ( defined $say )
	{
		$self->{SAY}->{PM} = $say;
	}
	
	return $self->{SAY}->{PM};
}

# Sets/returns the date separator.
sub date_seperator
{
	my $self=shift;
	my $symbol=shift;
	
	# This just makes the code more consistent.
	my $an=$self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if ( defined $symbol )
	{
		$self->{SEPERATOR}->{DATE}=$symbol;
	}
	
	return $self->{SEPERATOR}->{DATE};
}

# Sets/returns the time separator.
sub time_seperator
{
	my $self   = shift;
	my $symbol = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if ( defined $symbol )
	{
		$self->{SEPERATOR}->{TIME} = $symbol;
	}
	
	return $self->{SEPERATOR}->{TIME};
}

# This sets/returns whether to use 24-hour or 12-hour, am/pm notation.
sub use_24h
{
	my $self    = shift;
	my $use_24h = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if (defined $use_24h)
	{
		if (( $use_24h == 0 ) || ( $use_24h == 1 ))
		{
			$self->{USE_24H} = $use_24h;
		}
		else
		{
			die "The 'use_24h' method must be passed a '0' or '1' value only.\n";
		}
	}
	
	return $self->{USE_24H};
}

# This returns the date and time based on the given unix-time.
sub date_and_time
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Set default values then check for passed parameters to over-write
	# them with.
	my ($offset, $use_time, $require_weekday, $skip_weekends);
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	if (ref($parameter) eq "HASH")
	{
		# Values passed in a hash, good.
		$offset		 = $parameter->{offset}          ? $parameter->{offset}          : 0;
		$use_time	 = $parameter->{use_time}        ? $parameter->{use_time}        : time;
		$require_weekday = $parameter->{require_weekday} ? $parameter->{require_weekday} : 0;
		$skip_weekends	 = $parameter->{skip_weekends}   ? $parameter->{skip_weekends}   : 0;
	}
	else
	{
		# Values passed directly.
		$offset		 = defined $parameter ? $parameter : 0;
		$use_time	 = defined $_[0] ? $_[0] : time;
		$require_weekday = defined $_[1] ? $_[1] : "";
		$skip_weekends	 = defined $_[2] ? $_[2] : "";
	}
	
	# Do my initial calculation.
	my %time          = ();
	my $adjusted_time = $use_time+$offset;
	($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);

	# If I am set to skip weekends and I land on a weekend, simply add 48
	# hours. This is useful when you need to move X-weekdays.
	if (($skip_weekends) && ($offset))
	{
		# First thing I need to know is how many weekends pass between
		# now and the requested date. So to start, how many days are we
		# talking about?
		my $difference   = 0;			# Hold the accumulated days in seconds.
		my $local_offset = $offset;		# Local offset I can mess with.
		my $day          = 24 * 60 * 60;	# For clarity.
		my $week         = $day * 7;		# For clarity.
		
		# As I proceed, 'local_time' will be subtracted as I account
		# for time and 'difference' will increase to account for known
		# weekend days.
		if ($local_offset =~ /^-/)
		{
			### Go back in time...
			$local_offset =~ s/^-//;
			
			# First, how many seconds have passed today?
			my $seconds_passed_today = $time{sec} + ($time{min}*60) + ($time{hour}*60*60);
			
			# Now, get the number of seconds in the offset beyond
			# an even day. This is compared to the seconds passed
			# in this day. If greater, I count an extra day.
			my $local_offset_second_over_day =  $local_offset % $day;
			$local_offset                    -= $local_offset_second_over_day;
			my $local_offset_days            =  $local_offset / $day;
			$local_offset_days++ if $local_offset_second_over_day > $seconds_passed_today;
			
			# If the number of days is greater than one week, add
			# two days to the 'difference' for every seven days and
			# reduce 'local_offset_days' to the number of days
			# beyond the given number of weeks.
			my $local_offset_remaining_days = $local_offset_days;
			if ($local_offset_days > 7)
			{
				# Greater than a week, do the math.
				$local_offset_remaining_days =  $local_offset_days % 7;
				$local_offset_days           -= $local_offset_remaining_days;
				my $weeks_passed             =  $local_offset_days / 7;
				$difference                  += ($weeks_passed * (2 * $day));
			}
			
			# If I am currently in a weekend, add two days.
			if (($time{wday} == 6) || ($time{wday} == 0))
			{
				$difference += (2 * $day);
			}
			else
			{
				# Compare 'local_offset_remaining_days' to
				# today's day. If greater, I've passed a
				# weekend and need to add two days to
				# 'difference'.
				my $today_day = (localtime())[6];
				if ($local_offset_remaining_days > $today_day)
				{
					$difference+=(2 * $day);
				}
			}
			
			# If I have a difference, recalculate the offset date.
			if ($difference)
			{
				my $new_offset = ($offset - $difference);
				$adjusted_time = ($use_time + $new_offset);
				($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
			}
		}
		else
		{
			### Go forward in time...
			# First, how many seconds are left in today?
			my $left_hours            = 23 - $time{hour};
			my $left_minutes          = 59 - $time{min};
			my $left_seconds          = 59 - $time{sec};
			my $seconds_left_in_today = $left_seconds + ($left_minutes*60) + ($left_hours*60*60);
			
			# Now, get the number of seconds in the offset beyond
			# an even day. This is compared to the seconds left in
			# this day. If greater, I count an extra day.
			my $local_offset_second_over_day =  $local_offset % $day;
			$local_offset                    -= $local_offset_second_over_day;
			my $local_offset_days            =  $local_offset / $day;
			$local_offset_days++ if $local_offset_second_over_day > $seconds_left_in_today;
			
			# If the number of days is greater than one week, add
			# two days to the 'difference' for every seven days and
			# reduce 'local_offset_days' to the number of days
			# beyond the given number of weeks.
			my $local_offset_remaining_days = $local_offset_days;
			if ($local_offset_days > 7)
			{
				# Greater than a week, do the math.
				$local_offset_remaining_days =  $local_offset_days % 7;
				$local_offset_days           -= $local_offset_remaining_days;
				my $weeks_passed             =  $local_offset_days / 7;
				$difference                  += ($weeks_passed * (2 * $day));
			}
			
			# If I am currently in a weekend, add two days.
			if (($time{wday} == 6) || ($time{wday} == 0))
			{
				$difference += (2 * $day);
			}
			else
			{
				# Compare 'local_offset_remaining_days' to
				# 5 minus today's day to get the number of days
				# until the weekend. If greater, I've crossed a
				# weekend and need to add two days to
				# 'difference'.
				my $today_day=(localtime())[6];
				my $days_to_weekend=5 - $today_day;
				if ($local_offset_remaining_days > $days_to_weekend)
				{
					$difference+=(2 * $day);
				}
			}
			
			# If I have a difference, recalculate the offset date.
			if ($difference)
			{
				my $new_offset = ($offset + $difference);
				$adjusted_time = ($use_time + $new_offset);
				($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
			}
		}
	}

	# If the 'require_weekday' is set and if 'time{wday}' is 0 (Sunday) or
	# 6 (Saturday), set or increase the offset by 24 or 48 hours.
	if (($require_weekday) && (( $time{wday} == 0 ) || ( $time{wday} == 6 )))
	{
		# The resulting day is a weekend and the require weekday was
		# set.
		$adjusted_time = $use_time + ($offset + (24 * 60 * 60));
		($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
		
		# I don't check for the date and adjust automatically because I
		# don't know if I am going forward or backwards in the calander.
		if (( $time{wday} == 0 ) || ( $time{wday} == 6 ))
		{
			# Am I still ending on a weekday?
			$adjusted_time = $use_time + ($offset + (48 * 60 * 60));
			($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
		}
	}

	# Increment the month by one.
	$time{mon}++;
	
	# Parse the 12/24h time components.
	if ($self->use_24h)
	{
		# 24h time.
		$time{pad_hour} = sprintf("%02d", $time{hour});
		$time{suffix}   = "";
	}
	else
	{
		# 12h am/pm time.
		if ( $time{hour} == 0 )
		{
			$time{pad_hour} = 12;
			$time{suffix}   = " ".$self->say_am;
		}
		elsif ( $time{hour} < 12 )
		{
			$time{pad_hour} = $time{hour};
			$time{suffix}   = " ".$self->say_am;
		}
		else
		{
			$time{pad_hour} = ($time{hour}-12);
			$time{suffix}   = " ".$self->say_pm;
		}
		$time{pad_hour} = sprintf("%02d", $time{pad_hour});
	}
	
	# Now parse the global components.
	$time{pad_min}  = sprintf("%02d", $time{min});
	$time{pad_sec}  = sprintf("%02d", $time{sec});
	$time{year}     = ($time{year} + 1900);
	$time{pad_mon}  = sprintf("%02d", $time{mon});
	$time{pad_mday} = sprintf("%02d", $time{mday});
	$time{mon}++;
	
	my $date = $time{year}.$self->date_seperator.$time{pad_mon}.$self->date_seperator.$time{pad_mday};
	my $time = $time{pad_hour}.$self->time_seperator.$time{pad_min}.$self->time_seperator.$time{pad_sec}.$time{suffix};
	
	return ($date, $time);
}

# This returns the PIDs found in 'ps' for a given program name.
sub pids
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# What program?
	if (not $parameter->{program_name})
	{
		return(-1);
	}
	
	my $my_pid       = $$;
	my $program_name = $parameter->{program_name};
	my $target       = $parameter->{target}       ? $parameter->{target}   : "";
	my $port         = $parameter->{port}         ? $parameter->{port}     : "";
	my $password     = $parameter->{password}     ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "my_pid",       value1 => $my_pid,
		name2 => "program_name", value2 => $program_name, 
		name3 => "target",       value3 => $target, 
		name4 => "port",         value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0003", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If there is a target passed, we're checking a remote machine.
	my $pids       = [];
	my $return     = [];
	my $shell_call = $an->data->{path}{ps}." aux";
	if ($target)
	{
		# Remote call.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		# Local call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__ });
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
			
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		if ($line =~ /^\S+ \d+ /)
		{
			my ($user, $pid, $cpu, $memory, $virtual_memory_size, $resident_set_size, $control_terminal, $state_codes, $start_time, $time, $command) = ($line =~ /^(\S+) (\d+) (.*?) (.*?) (.*?) (.*?) (.*?) (.*?) (.*?) (.*?) (.*)$/);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0011", message_variables => {
				name1  => "user",                value1  => $user,
				name2  => "pid",                 value2  => $pid,
				name3  => "cpu",                 value3  => $cpu,
				name4  => "memory",              value4  => $memory,
				name5  => "virtual_memory_size", value5  => $virtual_memory_size,
				name6  => "resident_set_size",   value6  => $resident_set_size,
				name7  => "control_terminal",    value7  => $control_terminal,
				name8  => "state_codes",         value8  => $state_codes,
				name9  => "start_time",          value9  => $start_time,
				name10 => "time",                value10 => $time,
				name11 => "command",             value11 => $command,
			}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "command",      value1 => $command,
				name2 => "program_name", value2 => $program_name, 
			}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
			if ($command =~ /$program_name/)
			{
				# If we're calling locally and we see our own PID, skip it.
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "pid",    value1 => $pid,
					name2 => "my_pid", value2 => $my_pid, 
					name3 => "target", value3 => $target, 
				}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
				if (($pid eq $my_pid) && (not $target))
				{
					# This is us! :D
				}
				elsif (($command =~ /--status/) or ($command =~ /--state/))
				{
					# Ignore this, it's someone else also checking the state.
				}
				else
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pid", value1 => $pid,
					}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
					push @{$pids}, $pid;
				}
			}
		}
	}
	
	return($pids);
}

# This uses 'anvil-report-memory' to get the amount of RAM used by a given program name.
sub ram_used_by_program
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# What program?
	if (not $parameter->{program_name})
	{
		return(-1);
	}
	
	my $total_bytes = 0;
	my $shell_call  = $an->data->{path}{'anvil-report-memory'}." --program $parameter->{program_name}";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => "$shell_call"
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
	open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__ });
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => "$line"
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		
		if ($line =~ /^$parameter->{program_name} = (\d+)/)
		{
			$total_bytes = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "total_bytes", value1 => $total_bytes
			}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		}
	}
	close $file_handle;
	
	return($total_bytes);
}

# This returns the RAM used by the passed in PID. If not PID was passed, it returns the RAM used by the 
# parent process.
sub get_ram_used_by_pid
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# What PID?
	my $pid = $parameter->{pid} ? $parameter->{pid} : $$;
	
	my $total_bytes = 0;
	my $shell_call  = $an->data->{path}{pmap}." $pid 2>&1 |";
	open (my $file_handle, $shell_call) or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__ });
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => ">> line", value1 => "$line"
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		
		next if $line !~ /total/;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => "$line"
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		
		# Dig out the PID
		my $kilobytes   =  ($line =~ /total (\d+)K/i)[0];
		my $bytes       =  ($kilobytes * 1024);
		   $total_bytes += $bytes;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "kilobytes",   value1 => "$kilobytes", 
			name2 => "bytes",       value2 => "$bytes", 
			name3 => "total_bytes", value3 => "$total_bytes"
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
	}
	close $file_handle;
	
	return($total_bytes);
}

# This reads in command line switches.
sub switches
{
	my $self  = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $last_argument = "";
	foreach my $argument (@ARGV)
	{
		if ($last_argument eq "raw")
		{
			# Don't process anything.
			$an->data->{switches}{raw} .= " $argument";
		}
		elsif (($argument eq "start") or ($argument eq "stop") or ($argument eq "status"))
		{
			$an->data->{switches}{$argument} = 1;
		}
		elsif ($argument =~ /^-/)
		{
			# If the argument is just '--', appeand everything after it to 'raw'.
			$an->data->{sys}{switch_count}++;
			if ($argument eq "--")
			{
				$last_argument         = "raw";
				$an->data->{switches}{raw} = "";
			}
			else
			{
				($last_argument) = ($argument =~ /^-{1,2}(.*)/)[0];
				if ($last_argument =~ /=/)
				{
					# Break up the variable/value.
					($last_argument, my $value) = (split /=/, $last_argument, 2);
					$an->data->{switches}{$last_argument} = $value;
				}
				else
				{
					$an->data->{switches}{$last_argument} = "#!SET!#";
				}
			}
		}
		else
		{
			if ($last_argument)
			{
				$an->data->{switches}{$last_argument} = $argument;
				$last_argument                    = "";
			}
			else
			{
				# Got a value without an argument.
				$an->data->{switches}{error} = 1;
			}
		}
	}
	# Clean up the initial space added to 'raw'.
	if ($an->data->{switches}{raw})
	{
		$an->data->{switches}{raw} =~ s/^ //;
	}
	
	return(0);
}

# This returns the dotted-decimal IP address for the passed-in host name.
sub ip
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# What PID?
	my $host = $parameter->{host};
	
	# Error if not host given.
	if (not $host)
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0047", code => 47, file => "$THIS_FILE", line => __LINE__});
	}
	
	my $ip         = "";
	my $shell_call = $an->data->{path}{gethostip}." -d $host";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		$ip = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "ip", value1 => $ip, 
		}, file => $THIS_FILE, line => __LINE__});
		last;
	}
	close $file_handle;
	
	return ($ip);
}

# This returns the nodes and anvil password for a (remote) Anvil! as defined in the local striker.conf file.
sub remote_anvil_details
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;

	my $anvil = $parameter->{anvil};
	if (not $anvil)
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0050", code => 50, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# Look for the nodes that belong to this Anvil! and query them.
	my $return = {
		node1		=>	"",
		node2		=>	"",
		anvil_password	=>	"",
	};
	my $id = "";
	foreach my $this_id (sort {$a cmp $b} keys %{$an->data->{cluster}})
	{
		if ($an->data->{cluster}{$this_id}{name} eq $anvil)
		{
			# Got it.
			($return->{node1}, $return->{node2}) = (split/,/, $an->data->{cluster}{$this_id}{nodes});
			$return->{anvil_password}            = $an->data->{cluster}{$this_id}{root_pw} ? $an->data->{cluster}{$this_id}{root_pw} : $an->data->{cluster}{$this_id}{ricci_pw};
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1", value1 => $return->{node1}, 
		name2 => "node2", value2 => $return->{node2}, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_password", value1 => $return->{anvil_password}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return ($return);
}

# This directly gathers information about a node or dashboard from the target.
sub target_details
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# If no host name is passed in, use this machine's host name.
	my $target   = $parameter->{target}   ? $parameter->{target}   : $an->hostname;
	my $port     = $parameter->{port}     ? $parameter->{port}     : 22;
	my $password = $parameter->{password} ? $parameter->{password} : "";
	my $return   = {
		anvil_name	=>	"",
		network		=>	{
			bcn_address	=>	"",
			ifn_address	=>	"",
			sn_address	=>	"",
		},
		uuid		=>	"",
	};
	
	# Here are the calls we'll make
	my $uuid_shell_call = $an->data->{path}{cat}." ".$an->data->{path}{host_uuid};
	my $ip_shell_call   = $an->data->{path}{ip}." addr show";
	
	# Returned data from the shell calls will be stored in these arrays.
	my $uuid_return  = [];
	my $ip_return    = [];
	my $cluster_conf = "";
	
	# Now make the calls.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		# UUID
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "uuid_shell_call", value1 => $uuid_shell_call,
			name2 => "target",          value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $uuid_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$uuid_shell_call,
			'close'		=>	0,
		});
		
		# IP info
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "ip_shell_call", value1 => $ip_shell_call,
			name2 => "target",        value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $ip_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$ip_shell_call,
			'close'		=>	0,
		});
		
		# Get cluster.conf data
		$cluster_conf = $an->Cman->cluster_conf_data({
				target		=>	$target,
				port		=>	$port,
				password	=>	$password,
			});
	}
	else
	{
		### Local calls
		# NOTE: I know some of these could have been direct file reads, but it keeps the calls and 
		#       output processing consistent.
		# UUID
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "uuid_shell_call", value1 => $uuid_shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$uuid_shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $uuid_shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$uuid_return}, $line;
		}
		close $file_handle;
		
		# IP Info
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "ip_shell_call", value1 => $ip_shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open ($file_handle, "$ip_shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $ip_shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$ip_return}, $line;
		}
		close $file_handle;
		
		# Get cluster.conf data
		$cluster_conf = $an->Cman->cluster_conf_data();
	}
	
	### Parse it out!
	# UUID
	foreach my $line (@{$uuid_return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})/)
		{
			$return->{uuid} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "uuid", value1 => $return->{uuid}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	# IP information (very basic for now)
	my $in_device = "";
	foreach my $line (@{$ip_return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^\d+: (.*?):/)
		{
			$in_device = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "in_device", value1 => $in_device, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /inet (\d+\.\d+\.\d+\.\d+)\/(\d+) /)
		{
			$return->{network}{interface}{$in_device}{ip_address} = $1;
			$return->{network}{interface}{$in_device}{netmask}    = $2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "network::interface::${in_device}::ip_address", value1 => $return->{network}{interface}{$in_device}{ip_address}, 
				name2 => "network::interface::${in_device}::netmask",    value2 => $return->{network}{interface}{$in_device}{netmask}, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($in_device =~ /bcn/)
			{
				$return->{network}{bcn_address} = $return->{network}{interface}{$in_device}{ip_address};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "network::bcn_address", value1 => $return->{network}{bcn_address}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($in_device =~ /sn/)
			{
				$return->{network}{sn_address} = $return->{network}{interface}{$in_device}{ip_address};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "network::sn_address", value1 => $return->{network}{sn_address}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($in_device =~ /ifn/)
			{
				$return->{network}{ifn_address} = $return->{network}{interface}{$in_device}{ip_address};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "network::ifn_address", value1 => $return->{network}{ifn_address}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Pull out the anvil name from the cluster_name.
	$return->{anvil_name} = $cluster_conf->{cluster_name} ? $cluster_conf->{cluster_name} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_name", value1 => $return->{anvil_name}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Summarize
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "anvil_name",           value1 => $return->{anvil_name}, 
		name2 => "network::bcn_address", value2 => $return->{network}{bcn_address}, 
		name3 => "network::ifn_address", value3 => $return->{network}{ifn_address}, 
		name4 => "network::sn_address",  value4 => $return->{network}{sn_address}, 
		name5 => "uuid",                 value5 => $return->{uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return);
}

### TODO: Switch this to pull from ScanCore once the majority of striker.conf is deprecated.
# This gathers up information on a node, given the passed-in node name
sub node_info
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# If no host name is passed in, use this machine's host name.
	my $node = $parameter->{node} ? $parameter->{node} : $an->hostname;
	
	# First, run through the configured Anvil! systems from the striker.conf file.
	my $return = {};
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{cluster}})
	{
		my $company         =  $an->data->{cluster}{$id}{company};		#	=	Alteeve's Niche!
		my $description     =  $an->data->{cluster}{$id}{description};		#	=	Alteeve Development VM Anvil! (CentOS)
		my $name            =  $an->data->{cluster}{$id}{name};			#	=	an-anvil-03
		my ($node1, $node2) =  (split/,/, $an->data->{cluster}{$id}{nodes});	#	=	an-a03n01.alteeve.ca, an-a03n02.alteeve.ca
		my $password        =  $an->data->{cluster}{$id}{root_pw};
		   $password        =  $an->data->{cluster}{$id}{ricci_pw} if not $password;
		   $node1           =~ s/^\s+//;
		   $node1           =~ s/\s+$//;
		   $node2           =~ s/^\s+//;
		   $node2           =~ s/\s+$//;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "company",     value1 => $company, 
			name2 => "description", value2 => $description, 
			name3 => "name",        value3 => $name, 
			name4 => "node1",       value4 => $node1, 
			name5 => "node2",       value5 => $node2, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($node =~ /$node1/)
		{
			$return->{'local'}  = $node1;
			$return->{peer}     = $node2;
			$return->{anvil_id} = $id;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "local",    value1 => $return->{'local'}, 
				name2 => "peer",     value2 => $return->{peer}, 
				name3 => "anvil_id", value3 => $return->{anvil_id}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($node =~ /$node2/)
		{
			$return->{'local'}  = $node2;
			$return->{peer}     = $node1;
			$return->{anvil_id} = $id;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "local",    value1 => $return->{'local'}, 
				name2 => "peer",     value2 => $return->{peer}, 
				name3 => "anvil_id", value3 => $return->{anvil_id}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		if ($return->{anvil_id})
		{
			$return->{company}     = $company;
			$return->{description} = $description;
			$return->{anvil_name}  = $name;
			$return->{password}    = $password;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "company",     value1 => $return->{company}, 
				name2 => "description", value2 => $return->{description}, 
				name3 => "anvil_name",  value3 => $return->{anvil_name}, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $return->{password}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		last if $return->{anvil_id};
	}
	
	return($return);
}

# This returns the peer node and anvil! name depending on the passed-in host name. This is called by nodes 
# in an Anvil!.
sub local_anvil_details
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# If no host name is passed in, use this machine's host name.
	my $hostname_full  = $parameter->{hostname_full}  ? $parameter->{hostname_full}  : $an->hostname;
	my $hostname_short = $parameter->{hostname_short} ? $parameter->{hostname_short} : $an->short_hostname;
	my $config_file    = $parameter->{config_file}    ? $parameter->{config_file}    : $an->data->{path}{cman_config};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "hostname_full",  value1 => $hostname_full, 
		name2 => "hostname_short", value2 => $hostname_short, 
		name3 => "config_file",    value3 => $config_file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Error if no config file is passed in.
	# Read in cluster.conf.
	my $xml  = XML::Simple->new();
	my $data = $xml->XMLin($config_file, KeyAttr => {node => 'name'}, ForceArray => 1);
	
	### TODO: Detect whether this is reading in cluster.conf or cibadmin
	my $return = {
		local_node	=>	"",
		peer_node	=>	"",
		anvil_name	=>	$data->{name},
		anvil_password	=>	"",
	};
	foreach my $a (@{$data->{clusternodes}->[0]->{clusternode}})
	{
		my $node_name = $a->{name};
		my $alt_name  = $a->{altname}->[0]->{name} ? $a->{altname}->[0]->{name} : "";
		if (($hostname_full  eq $node_name) or 
		    ($hostname_full  eq $alt_name)  or 
		    ($hostname_short eq $node_name) or 
		    ($hostname_short eq $alt_name))
		{
			$return->{local_node} = $node_name;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "local_node", value1 => $return->{local_node}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$return->{peer_node} = $node_name;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "peer_node", value1 => $return->{peer_node}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Now see if this Anvil! was read in from striker.conf.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_name", value1 => $return->{anvil_name}, 
		name2 => "cluster",    value2 => ref($an->data->{cluster}), 
	}, file => $THIS_FILE, line => __LINE__});
	if (($return->{anvil_name}) && (ref($an->data->{cluster}) eq "HASH"))
	{
		foreach my $id (sort {$a cmp $b} keys %{$an->data->{cluster}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "id",                   value1 => $id, 
				name2 => "cluster::${id}::name", value2 => $an->data->{cluster}{$id}{name}, 
				name3 => "anvil_name",           value3 => $return->{anvil_name}, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{cluster}{$id}{name} eq $return->{anvil_name})
			{
				$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
					name1 => "cluster::${id}::root_pw",  value1 => $an->data->{cluster}{$id}{root_pw}, 
					name2 => "cluster::${id}::ricci_pw", value2 => $an->data->{cluster}{$id}{ricci_pw}, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->data->{cluster}{$id}{root_pw})
				{
					$return->{anvil_password} = $an->data->{cluster}{$id}{root_pw};
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "anvil_password", value1 => $return->{anvil_password}, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($an->data->{cluster}{$id}{ricci_pw})
				{
					$return->{anvil_password} = $an->data->{cluster}{$id}{root_pw};
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "anvil_password", value1 => $return->{anvil_password}, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				last;
			}
		}
	}
	
	# Read in the node health files, if I can access them.
	my $local_health_file = $an->data->{path}{status}."/.".$an->short_hostname;
	my $peer_health_file  = $an->data->{path}{status}."/.".$an->Cman->peer_short_hostname;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "local_health_file", value1 => $local_health_file, 
		name2 => "peer_health_file",  value2 => $peer_health_file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$return->{health}{'local'} = "--";
	$return->{health}{peer}    = "--";
	if (-e $local_health_file)
	{
		my $shell_call = $local_health_file;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /health = (.*)$/)
			{
				$return->{health}{'local'} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return->health::local", value1 => $return->{health}{'local'}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		close $file_handle;
	}
	else
	{
		# Local health file doesn't exist.
		$an->Log->entry({log_level => 3, message_key => "tools_log_0018", message_variables => {
			file => $local_health_file, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	if (-e $peer_health_file)
	{
		my $shell_call = $peer_health_file;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /health = (.*)$/)
			{
				$return->{health}{peer} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return->health::peer", value1 => $return->{health}{peer}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		close $file_handle;
	}
	else
	{
		# Peer's health file doesn't exist.
		$an->Log->entry({log_level => 3, message_key => "tools_log_0018", message_variables => {
			file => $peer_health_file, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
		name1 => "local_node",    value1 => $return->{local_node}, 
		name2 => "peer_node",     value2 => $return->{peer_node}, 
		name3 => "anvil_name",    value3 => $return->{anvil_name}, 
		name4 => "health::local", value4 => $return->{health}{'local'}, 
		name5 => "health::peer",  value5 => $return->{health}{peer}, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_password", value1 => $return->{anvil_password}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return ($return);
}

# This returns an array of hash references, each hash reference storing a peer node name and the scancore 
# password.
sub striker_peers
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# This array will store the hashes for the peer host names and their passwords.
	my $peers = [];
	
	my $i_am_long  = $an->hostname();
	my $i_am_short = $an->short_hostname();
	my $local_id   = "";
	my $db_count   = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "i_am_long",  value1 => $i_am_long, 
		name2 => "i_am_short", value2 => $i_am_short, 
		name3 => "local_id",   value3 => $local_id, 
		name4 => "db_count",   value4 => $db_count, 
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		   $db_count++;
		my $this_host = $an->data->{scancore}{db}{$id}{host};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "this_host", value1 => $this_host, 
			name2 => "db_count",  value2 => $db_count, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($this_host eq $i_am_long) or ($this_host eq $i_am_short))
		{
			$local_id = $id;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "local_id", value1 => $local_id, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Now I know who I am, find the peer.
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		if ($id ne $local_id)
		{
			my $peer_name     = $an->data->{scancore}{db}{$id}{host};
			my $peer_password = $an->data->{scancore}{db}{$id}{password};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "peer_name",     value1 => $peer_name, 
				name2 => "peer_password", value2 => $peer_password, 
			}, file => $THIS_FILE, line => __LINE__});
			push @{$peers}, {name => $peer_name, password => $peer_password};
		}
	}
	
	return($peers);
}

### TODO: Make this work on local and remote calls.
# This checks to see if dhcpd is configured to be an install target target and, if so, see if dhcpd is 
# running or not.
sub dhcpd_state
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# First, read the dhcpd.conf file, if it exists, and look for the 'next-server' option.
	my $dhcpd_state = 2;
	my $boot_target = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "path::dhcpd_conf", value1 => $an->data->{path}{dhcpd_conf},
	}, file => $THIS_FILE, line => __LINE__});
	if (-e $an->data->{path}{dhcpd_conf})
	{
		$an->Log->entry({log_level => 3, message_key => "log_0011", message_variables => {
			file => "dhcpd.conf", 
		}, file => $THIS_FILE, line => __LINE__});
		my $shell_call = $an->data->{path}{dhcpd_conf};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "<$shell_call") || die "Failed to read: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			   $line =~ s/^\s+//;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /next-server \d+\.\d+\.\d+\.\d+;/)
			{
				$boot_target = 1;
				$an->Log->entry({log_level => 3, message_key => "log_0012", file => $THIS_FILE, line => __LINE__});
				last;
			}
		}
		close $file_handle;
	}
	else
	{
		# DHCP daemon config file not found or not readable. Is '/etc/dhcp' readable by the current UID?
		$an->Log->entry({log_level => 3, message_key => "log_0013", message_variables => {
			file => $an->data->{path}{dhcpd_conf},
			uid  => $<, 
		}, file => $THIS_FILE, line => __LINE__});
		$dhcpd_state = 4;
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "boot_target", value1 => $boot_target,
	}, file => $THIS_FILE, line => __LINE__});
	if ($boot_target)
	{
		# See if dhcpd is running.
		my $shell_call = $an->data->{path}{initd}."/dhcpd status; ".$an->data->{path}{echo}." rc:\$?";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /rc:(\d+)/)
			{
				my $rc = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "rc", value1 => $rc,
				}, file => $THIS_FILE, line => __LINE__});
				if ($rc eq "3")
				{
					# Stopped
					$dhcpd_state = 1;
				}
				elsif ($rc eq "0")
				{
					# Running
					$dhcpd_state = 0;
				}
				else
				{
					# Unknown state.
					$dhcpd_state = 4;
				}
			}
		}
		close $file_handle;
	}
	# 0 == Running
	# 1 == Not running
	# 2 == Not a boot target
	# 3 == In an unknown state.
	# 4 == No access to /etc/dhcpd
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "dhcpd_state", value1 => $dhcpd_state,
	}, file => $THIS_FILE, line => __LINE__});
	return($dhcpd_state);
}

1;
