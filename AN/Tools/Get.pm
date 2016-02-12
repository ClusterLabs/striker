package AN::Tools::Get;

use strict;
use warnings;
use IO::Handle;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Get.pm";


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
		#my $user       = (split/:/, $line)[0];
		#my $users_home = (split/:/, $line)[5];
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

# This gets the note associated with a given server name,
sub server_note
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $return = {
		note	=>	"",
		uuid	=>	"",
	};
	my $server = $parameter->{server};
	my $anvil  = $parameter->{anvil}  ? $parameter->{anvil} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server", value1 => $server, 
		name2 => "anvil",  value2 => $anvil, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $server)
	{
		# No server? pur quois?!
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0051", code => 51, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# Get the server's UUID.
	my $server_uuid = $an->Get->server_uuid({
		server => $server, 
		anvil  => $anvil, 
	});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_uuid", value1 => $server_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Check the server table now.
	if ($server_uuid)
	{
		my $query = "
SELECT 
    server_uuid, 
    server_note 
FROM 
    server 
WHERE 
    server_name = ".$an->data->{sys}{use_db_fh}->quote($server)." 
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query});
		my $count   = @{$results};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			my $server_uuid = $row->[0];
			my $server_data = $row->[1] ? $row->[1] : "";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "server_uuid", value1 => $server_uuid, 
				name2 => "server_data", value2 => $server_data, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$return->{uuid} = $server_uuid;
			$return->{note} = $server_data;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "uuid", value1 => $return->{uuid}, 
				name2 => "note", value2 => $return->{note}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return($return);
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server", value1 => $server, 
		name2 => "anvil",  value2 => $anvil, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $server)
	{
		# No server? pur quois?!
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0049", code => 49, file => "$THIS_FILE", line => __LINE__});
		return("");
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
			config_file	=>	$an->data->{path}{cluster_conf},
		});
		   $node1           = $return->{local_node};
		   $node2           = $return->{peer_node};
		   $node1_is_remote = 0;
		   $anvil           = $return->{anvil_name};
		   $anvil_password  = $return->{anvil_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "length(xml)",         value1 => length($xml), 
		name2 => "sys::db_connections", value2 => $an->data->{sys}{db_connections}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $xml) && ($an->data->{sys}{db_connections}))
	{
		my $query = "
SELECT 
    server_definition 
FROM 
    server 
WHERE 
    server_name = ".$an->data->{sys}{use_db_fh}->quote($server)." 
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$xml = $an->DB->do_db_query({query => $query})->[0]->[0];
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "length(xml)", value1 => length($xml), 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I still don't have XML, then I am out of ideas...
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
			while(<$file_handle>)
			{
				chomp;
				my $line =  $_;
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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

# This reads /etc/password to figure out the requested user's home directory.
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
	
	return($users_home);
}

# Get the local user's RSA public key.
sub rsa_public_key
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $user     = $parameter->{user};
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
		open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		$ip = $_;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1", value1 => $return->{node1}, 
		name2 => "node2", value2 => $return->{node2}, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_password", value1 => $return->{anvil_password}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return ($return);
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
	
	# If now host name is passed in, use this machine's host name.
	my $hostname_full  = $parameter->{hostname_full}  ? $parameter->{hostname_full}  : $an->hostname;
	my $hostname_short = $parameter->{hostname_short} ? $parameter->{hostname_short} : $an->short_hostname;
	my $config_file    = $parameter->{config_file}    ? $parameter->{config_file}    : $an->data->{path}{cluster_conf};
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
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "local_node", value1 => $return->{local_node}, 
		name2 => "peer_node",  value2 => $return->{peer_node}, 
		name3 => "anvil_name", value3 => $return->{anvil_name}, 
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "i_am_long",  value1 => $i_am_long, 
		name2 => "i_am_short", value2 => $i_am_short, 
		name3 => "local_id",   value3 => $local_id, 
		name4 => "db_count",   value4 => $db_count, 
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		   $db_count++;
		my $this_host = $an->data->{scancore}{db}{$id}{host};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "this_host", value1 => $this_host, 
			name2 => "db_count",  value2 => $db_count, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($this_host eq $i_am_long) or ($this_host eq $i_am_short))
		{
			$local_id = $id;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "peer_name",     value1 => $peer_name, 
				name2 => "peer_password", value2 => $peer_password, 
			}, file => $THIS_FILE, line => __LINE__});
			push @{$peers}, {name => $peer_name, password => $peer_password};
		}
	}
	
	return($peers);
}

1;
