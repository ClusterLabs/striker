package AN::Tools::Striker;
# 
# This module will contain methods used specifically for Striker (WebUI) related tasks.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Striker.pm";

### Methods;
# configure
# load_anvil
# scan_anvil
# scan_node
# scan_servers
# _gather_node_details

#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
	my $class = shift;
	
	my $self  = {
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


#############################################################################################################
# Provided methods                                                                                          #
#############################################################################################################

# This presents and manages the 'configure' component of Striker.
sub configure
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	
	
	return(0);
}

# This uses the 'cgi::anvil_uuid' to load the anvil data into the active system variables.
sub load_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	if ($parameter->{anvil_uuid})
	{
		$anvil_uuid = $parameter->{anvil_uuid};
	}
	
	if (not $anvil_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0102", code => 102, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $anvil_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0103", message_variables => { uuid => $anvil_uuid }, code => 103, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->data->{anvils}{$anvil_uuid}{name})
	{
		# Valid UUID, but it doesn't match a known Anvil!.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0104", message_variables => { uuid => $anvil_uuid }, code => 104, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	
	# Variables
	$an->data->{sys}{anvil}{uuid}                 = $anvil_uuid;
	$an->data->{sys}{anvil}{name}                 = $an->data->{anvils}{$anvil_uuid}{name};
	$an->data->{sys}{anvil}{description}          = $an->data->{anvils}{$anvil_uuid}{description};
	$an->data->{sys}{anvil}{note}                 = $an->data->{anvils}{$anvil_uuid}{note};
	$an->data->{sys}{anvil}{owner}{name}          = $an->data->{anvils}{$anvil_uuid}{owner}{name};
	$an->data->{sys}{anvil}{owner}{note}          = $an->data->{anvils}{$anvil_uuid}{owner}{note};
	$an->data->{sys}{anvil}{smtp}{server}         = $an->data->{anvils}{$anvil_uuid}{smtp}{server};
	$an->data->{sys}{anvil}{smtp}{port}           = $an->data->{anvils}{$anvil_uuid}{smtp}{port};
	$an->data->{sys}{anvil}{smtp}{username}       = $an->data->{anvils}{$anvil_uuid}{smtp}{username};
	$an->data->{sys}{anvil}{smtp}{security}       = $an->data->{anvils}{$anvil_uuid}{smtp}{security};
	$an->data->{sys}{anvil}{smtp}{authentication} = $an->data->{anvils}{$anvil_uuid}{smtp}{authentication};
	$an->data->{sys}{anvil}{smtp}{helo_domain}    = $an->data->{anvils}{$anvil_uuid}{smtp}{helo_domain};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0012", message_variables => {
		name1  => "sys::anvil::uuid",                 value1  => $an->data->{sys}{anvil}{uuid}, 
		name2  => "sys::anvil::name",                 value2  => $an->data->{sys}{anvil}{name}, 
		name3  => "sys::anvil::description",          value3  => $an->data->{sys}{anvil}{description}, 
		name4  => "sys::anvil::note",                 value4  => $an->data->{sys}{anvil}{note}, 
		name5  => "sys::anvil::owner::name",          value5  => $an->data->{sys}{anvil}{owner}{name}, 
		name6  => "sys::anvil::owner::note",          value6  => $an->data->{sys}{anvil}{owner}{note}, 
		name7  => "sys::anvil::smtp::server",         value7  => $an->data->{sys}{anvil}{smtp}{server}, 
		name8  => "sys::anvil::smtp::port",           value8  => $an->data->{sys}{anvil}{smtp}{port}, 
		name9  => "sys::anvil::smtp::username",       value9  => $an->data->{sys}{anvil}{smtp}{username}, 
		name10 => "sys::anvil::smtp::security",       value10 => $an->data->{sys}{anvil}{smtp}{security}, 
		name11 => "sys::anvil::smtp::authentication", value11 => $an->data->{sys}{anvil}{smtp}{authentication}, 
		name12 => "sys::anvil::smtp::helo_domain",    value12 => $an->data->{sys}{anvil}{smtp}{helo_domain}, 
	}, file => $THIS_FILE, line => __LINE__});
		
	# Passwords
	$an->data->{sys}{anvil}{password}       = $an->data->{anvils}{$anvil_uuid}{password};
	$an->data->{sys}{anvil}{smtp}{password} = $an->data->{anvils}{$anvil_uuid}{smtp}{password};
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::anvil::password",       value1 => $an->data->{sys}{anvil}{password}, 
		name1 => "sys::anvil::smtp::password", value1 => $an->data->{sys}{anvil}{smtp}{password}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $node_key ("node1", "node2")
	{
		$an->data->{sys}{anvil}{$node_key}{uuid}           = $an->data->{anvils}{$anvil_uuid}{$node_key}{uuid};
		$an->data->{sys}{anvil}{$node_key}{name}           = $an->data->{anvils}{$anvil_uuid}{$node_key}{name};
		$an->data->{sys}{anvil}{$node_key}{remote_ip}      = $an->data->{anvils}{$anvil_uuid}{$node_key}{remote_ip};
		$an->data->{sys}{anvil}{$node_key}{remote_port}    = $an->data->{anvils}{$anvil_uuid}{$node_key}{remote_port};
		$an->data->{sys}{anvil}{$node_key}{note}           = $an->data->{anvils}{$anvil_uuid}{$node_key}{note};
		$an->data->{sys}{anvil}{$node_key}{bcn_ip}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{bcn_ip};
		$an->data->{sys}{anvil}{$node_key}{sn_ip}          = $an->data->{anvils}{$anvil_uuid}{$node_key}{sn_ip};
		$an->data->{sys}{anvil}{$node_key}{ifn_ip}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{ifn_ip};
		$an->data->{sys}{anvil}{$node_key}{type}           = $an->data->{anvils}{$anvil_uuid}{$node_key}{type};
		$an->data->{sys}{anvil}{$node_key}{health}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{health};
		$an->data->{sys}{anvil}{$node_key}{emergency_stop} = $an->data->{anvils}{$anvil_uuid}{$node_key}{emergency_stop};
		$an->data->{sys}{anvil}{$node_key}{stop_reason}    = $an->data->{anvils}{$anvil_uuid}{$node_key}{stop_reason};
		$an->data->{sys}{anvil}{$node_key}{use_ip}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{use_ip};
		$an->data->{sys}{anvil}{$node_key}{use_port}       = $an->data->{anvils}{$anvil_uuid}{$node_key}{use_port};
		$an->data->{sys}{anvil}{$node_key}{online}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{online};
		$an->data->{sys}{anvil}{$node_key}{power}          = $an->data->{anvils}{$anvil_uuid}{$node_key}{power};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0016", message_variables => {
			name1  => "sys::anvil::${node_key}::uuid",           value1  => $an->data->{sys}{anvil}{$node_key}{uuid}, 
			name2  => "sys::anvil::${node_key}::name",           value2  => $an->data->{sys}{anvil}{$node_key}{name}, 
			name3  => "sys::anvil::${node_key}::remote_ip",      value3  => $an->data->{sys}{anvil}{$node_key}{remote_ip}, 
			name4  => "sys::anvil::${node_key}::remote_port",    value4  => $an->data->{sys}{anvil}{$node_key}{remote_port}, 
			name5  => "sys::anvil::${node_key}::note",           value5  => $an->data->{sys}{anvil}{$node_key}{note}, 
			name6  => "sys::anvil::${node_key}::bcn_ip",         value6  => $an->data->{sys}{anvil}{$node_key}{bcn_ip}, 
			name7  => "sys::anvil::${node_key}::sn_ip",          value7  => $an->data->{sys}{anvil}{$node_key}{sn_ip}, 
			name8  => "sys::anvil::${node_key}::ifn_ip",         value8  => $an->data->{sys}{anvil}{$node_key}{ifn_ip}, 
			name9  => "sys::anvil::${node_key}::type",           value9  => $an->data->{sys}{anvil}{$node_key}{type}, 
			name10 => "sys::anvil::${node_key}::health",         value10 => $an->data->{sys}{anvil}{$node_key}{health}, 
			name11 => "sys::anvil::${node_key}::emergency_stop", value11 => $an->data->{sys}{anvil}{$node_key}{emergency_stop}, 
			name12 => "sys::anvil::${node_key}::stop_reason",    value12 => $an->data->{sys}{anvil}{$node_key}{stop_reason}, 
			name13 => "sys::anvil::${node_key}::use_ip",         value13 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
			name14 => "sys::anvil::${node_key}::use_port",       value14 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
			name15 => "sys::anvil::${node_key}::online",         value15 => $an->data->{sys}{anvil}{$node_key}{online}, 
			name16 => "sys::anvil::${node_key}::power",          value16 => $an->data->{sys}{anvil}{$node_key}{power}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Password
		$an->data->{sys}{anvil}{$node_key}{password} = $an->data->{anvils}{$anvil_uuid}{$node_key}{password};
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::${node_key}::password", value1 => $an->data->{sys}{anvil}{$node_key}{password}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This does a full manual scan of an Anvil! system.
sub scan_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Show the 'scanning in progress' table.
	print $an->Web->template({file => "common.html", template => "scanning-message", replace => {
		anvil_message	=>	$an->String->get({key => "message_0272", variables => { anvil => $an->data->{sys}{anvil}{name} }}),
	}});
	
	# Start your engines!
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node1}{uuid}});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node2}{uuid}});

	die "$THIS_FILE ".__LINE__."; testing...\n";
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "up nodes", value1 => $an->data->{sys}{up_nodes},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{up_nodes} > 0)
	{
		$an->Striker->scan_servers();
	}

	return(0);
}

# This attempts to gather all information about a node.
sub scan_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{uuid};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0105", code => 105, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $node_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0106", message_variables => { uuid => $node_uuid }, code => 106, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->data->{db}{nodes}{$node_uuid}{name})
	{
		# Valid UUID, but it doesn't match a known Anvil!.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0107", message_variables => { uuid => $node_uuid }, code => 107, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	
	# First, see how to access the node.
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $node_key  = $node_uuid eq $an->data->{sys}{anvil}{node1}{uuid} ? "node1" : "node2";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name", value1 => $node_name, 
		name2 => "node_key",  value2 => $node_key, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# See if I have a cached 'access' data.
	my $access = $an->ScanCore->read_cache({target => $node_uuid, type => "access"});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "access", value1 => $access, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($access)
	{
		# If this fails, we'll walk our various connections.
		my $target = $access;
		my $port   = 22;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target, 
			name2 => "port",   value2 => $port, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($target =~ /^(.*?):(\d+)$/)
		{
			$target = $1;
			$port   = $2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target", value1 => $target, 
				name2 => "port",   value2 => $port, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		my $access = $an->Check->access({
				target   => $target,
				port     => $port,
				password => $an->data->{sys}{anvil}{$node_key}{password},
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "access", value1 => $access, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($access)
		{
			$an->data->{sys}{anvil}{$node_key}{use_ip}   = $target;
			$an->data->{sys}{anvil}{$node_key}{use_port} = $port; 
			$an->data->{sys}{anvil}{$node_key}{online}   = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
				name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
				name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I don't have access (no cache or cache didn't work), walk through the networks.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online}, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{sys}{anvil}{$node_key}{online})
	{
		# BCN first.
		my $bcn_access = $an->Check->access({
				target   => $an->data->{sys}{anvil}{$node_key}{bcn_ip},
				port     => 22,
				password => $an->data->{sys}{anvil}{$node_key}{password},
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "bcn_access", value1 => $bcn_access, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($bcn_access)
		{
			# Woot
			$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{bcn_ip};
			$an->data->{sys}{anvil}{$node_key}{use_port} = 22; 
			$an->data->{sys}{anvil}{$node_key}{online}   = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
				name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
				name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Try the IFN
			my $ifn_access = $an->Check->access({
					target   => $an->data->{sys}{anvil}{$node_key}{ifn_ip},
					port     => 22,
					password => $an->data->{sys}{anvil}{$node_key}{password},
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "ifn_access", value1 => $ifn_access, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($ifn_access)
			{
				# Woot
				$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{ifn_ip};
				$an->data->{sys}{anvil}{$node_key}{use_port} = 22; 
				$an->data->{sys}{anvil}{$node_key}{online}   = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
					name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
					name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Try the remote IP/Port
				my $remote_access = $an->Check->access({
						target   => $an->data->{sys}{anvil}{$node_key}{remote_ip},
						port     => $an->data->{sys}{anvil}{$node_key}{remote_port},
						password => $an->data->{sys}{anvil}{$node_key}{password},
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "remote_access", value1 => $remote_access, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($remote_access)
				{
					# Woot
					$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{remote_ip};
					$an->data->{sys}{anvil}{$node_key}{use_port} = $an->data->{sys}{anvil}{$node_key}{remote_port}; 
					$an->data->{sys}{anvil}{$node_key}{online}   = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
						name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
						name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# No luck.
					$an->data->{sys}{anvil}{$node_key}{online} = 0;
					$an->data->{sys}{anvil}{$node_key}{power}  = $an->ScanCore->target_power({target => $node_uuid});
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "sys::anvil::${node_key}::power", value1 => $an->data->{sys}{anvil}{$node_key}{power}, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	# If I connected, cache the data.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{anvil}{$node_key}{online})
	{
		my $say_access = $an->data->{sys}{anvil}{$node_key}{use_ip};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "say_access",                      value1 => $say_access, 
			name2 => "sys::anvil::${node_key}::online", value2 => $an->data->{sys}{anvil}{$node_key}{online}, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{sys}{anvil}{$node_key}{use_port}) && ($an->data->{sys}{anvil}{$node_key}{use_port} ne 22))
		{
			$say_access = $an->data->{sys}{anvil}{$node_key}{use_ip}.":".$an->data->{sys}{anvil}{$node_key}{use_port};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "say_access", value1 => $say_access, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		$an->ScanCore->insert_or_update_nodes_cache({
			node_cache_host_uuid	=>	$an->data->{sys}{host_uuid},
			node_cache_node_uuid	=>	$node_uuid, 
			node_cache_name		=>	"access",
			node_cache_data		=>	$say_access,
		});
	}
	else
	{
		# Failed to connect, set some values.
		if ($an->data->{sys}{anvil}{$node_key}{power} eq "off")
		{
			$an->data->{sys}{online_nodes}                 = 1;
			$an->data->{node}{$node_name}{enable_poweron}  = 1;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->data->{node}{$node_name}{enable_fence}    = 0;
		}
		elsif ($an->data->{sys}{anvil}{$node_key}{power} eq "on")
		{
			# The node is on but unreachable.
			$an->data->{sys}{online_nodes}                 = 1;
			$an->data->{node}{$node_name}{enable_poweron}  = 0;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->data->{node}{$node_name}{enable_fence}    = 1;
			if (not $an->data->{node}{$node_name}{info}{'state'})
			{
				# No access
				$an->data->{node}{$node_name}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0033!#</span>";
			}
			if (not $an->data->{node}{$node_name}{info}{note})
			{
				# Unable to log into node.
				$an->data->{node}{$node_name}{info}{note} = $an->String->get({key => "message_0034", variables => { node => $node_name }});
			}
			$an->Log->entry({log_level => 2, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
			foreach my $daemon ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd")
			{
				$an->data->{node}{$node_name}{daemon}{$daemon}{status}    = "<span class=\"highlight_unavailable\">#!string!an_state_0001!#</span>";
				$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = "";
			}
		}
		else
		{
			# Unable to determine node state.
			$an->data->{node}{$node_name}{enable_poweron}  = 0;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->data->{node}{$node_name}{enable_fence}    = 0;
			if (not $an->data->{node}{$node_name}{info}{'state'})
			{
				# No access
				$an->data->{node}{$node_name}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0033!#</span>";
			}
			if (not $an->data->{node}{$node_name}{info}{note})
			{
				$an->data->{node}{$node_name}{info}{note} = $an->String->get({key => "message_0037", variables => { node => $node_name }});
			}
			$an->Log->entry({log_level => 2, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
			foreach my $daemon ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd")
			{
				$an->data->{node}{$node_name}{daemon}{$daemon}{status}    = "<span class=\"highlight_unavailable\">#!string!an_state_0001!#</span>";
				$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = "";
			}
		}
	}
	
	# set daemon states to 'Unknown'.
	$an->Log->entry({log_level => 3, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
	foreach my $daemon ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd")
	{
		$an->data->{node}{$node_name}{daemon}{$daemon}{status}    = "<span class=\"highlight_unavailable\">#!string!an_state_0001!#</span>";
		$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = "";
	}
	
	# Gather details on the node.
	$an->Log->entry({log_level => 3, message_key => "log_0018", message_variables => { node => $node_name }, file => $THIS_FILE, line => __LINE__});
	$an->data->{up_nodes} = [];
	if ($an->data->{sys}{anvil}{$node_key}{online})
	{
		$an->data->{sys}{online_nodes}    = 1;
		$an->data->{node}{$node_name}{up} = 1;
		push @{$an->data->{up_nodes}}, $node_name;
		$an->Striker->_gather_node_details({node => $node_uuid});
	}
	else
	{
		# Mark it as offline.
		$an->data->{node}{$node_name}{connected}      = 0;
		$an->data->{node}{$node_name}{info}{'state'}  = "<span class=\"highlight_unavailable\">#!string!row_0003!#</span>";
		$an->data->{node}{$node_name}{info}{note}     = "";
		$an->data->{node}{$node_name}{up}             = 0;
		$an->data->{node}{$node_name}{enable_poweron} = 0;
		
		# If I have confirmed the node is powered off, don't display this.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::anvil::${node_key}::power", value1 => $an->data->{sys}{anvil}{$node_key}{power},
			name2 => "cgi::task",                      value2 => $an->data->{cgi}{task},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{sys}{anvil}{$node_key}{power} eq "off") && (not $an->data->{cgi}{task}))
		{
			print $an->Web->template({file => "main-page.html", template => "node-state-table", replace => { 
				'state'	=>	$an->data->{node}{$node_name}{info}{'state'},
				note	=>	$an->data->{node}{$node_name}{info}{note},
			}});
		}
	}
	
# 	push @{$an->data->{online_nodes}}, $node if AN::Striker::check_node_daemons($an, $node);
# 	
# 	# If I have no nodes up, exit.
# 	$an->data->{sys}{up_nodes}     = @{$an->data->{up_nodes}};
# 	$an->data->{sys}{online_nodes} = @{$an->data->{online_nodes}};
# 	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 		name1 => "up nodes",     value1 => $an->data->{sys}{up_nodes},
# 		name2 => "online nodes", value2 => $an->data->{sys}{online_nodes},
# 	}, file => $THIS_FILE, line => __LINE__});
# 	if ($an->data->{sys}{up_nodes} < 1)
# 	{
# 		# Neither node is up. If I can power them on, then I will show
# 		# the node section to enable power up.
# 		if (not $an->data->{sys}{online_nodes})
# 		{
# 			if ($an->data->{clusters}{$anvil}{cache_exists})
# 			{
# 				print $an->Web->template({file => "main-page.html", template => "no-access-message", replace => { 
# 					anvil	=>	$an->data->{sys}{anvil}{name},
# 					message	=>	"#!string!message_0028!#",
# 				}});
# 			}
# 			else
# 			{
# 				print $an->Web->template({file => "main-page.html", template => "no-access-message", replace => { 
# 					anvil	=>	$an->data->{sys}{anvil}{name},
# 					message	=>	"#!string!message_0029!#",
# 				}});
# 			}
# 		}
# 	}
# 	else
# 	{
# 		post_scan_calculations($an);
# 	}
	
	return (0);
}

# Check the status of server on the active Anvil!.
sub scan_servers
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	
	# Make it a little easier to print the name of each node
# 	my $node1 = $an->data->{sys}{cluster}{node1_name};
# 	my $node2 = $an->data->{sys}{cluster}{node2_name};
# 	
# 	$an->data->{node}{$node1}{info}{short_host_name} = $an->data->{node}{$node1}{info}{host_name} if not $an->data->{node}{$node1}{info}{short_host_name};
# 	$an->data->{node}{$node2}{info}{short_host_name} = $an->data->{node}{$node2}{info}{host_name} if not $an->data->{node}{$node2}{info}{short_host_name};
# 	
# 	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
# 		name1 => "node1",                                 value1 => $node1,
# 		name2 => "node::${node1}::info::short_host_name", value2 => $an->data->{node}{$node1}{info}{short_host_name},
# 		name3 => "node::${node1}::info::host_name",       value3 => $an->data->{node}{$node1}{info}{host_name},
# 		name4 => "node2",                                 value4 => $node2,
# 		name5 => "node::${node2}::info::short_host_name", value5 => $an->data->{node}{$node2}{info}{short_host_name},
# 		name6 => "node::${node2}::info::host_name",       value6 => $an->data->{node}{$node2}{info}{host_name},
# 	}, file => $THIS_FILE, line => __LINE__});
# 	my $short_node1 = $an->data->{node}{$node1}{info}{short_host_name};
# 	my $short_node2 = $an->data->{node}{$node2}{info}{short_host_name};
# 	my $long_node1  = $an->data->{node}{$node1}{info}{host_name};
# 	my $long_node2  = $an->data->{node}{$node2}{info}{host_name};
# 	my $say_node1   = "<span class=\"fixed_width\">".$an->data->{node}{$node1}{info}{short_host_name}."</span>";
# 	my $say_node2   = "<span class=\"fixed_width\">".$an->data->{node}{$node2}{info}{short_host_name}."</span>";
# 	foreach my $vm (sort {$a cmp $b} keys %{$an->data->{vm}})
# 	{
# 		my $say_vm;
# 		if ($vm =~ /^vm:(.*)/)
# 		{
# 			$say_vm = $1;
# 		}
# 		else
# 		{
# 			AN::Cluster::error($an, "I was asked to check on a VM that didn't have the <span class=\"code\">vm:</span> prefix. I got the name: <span class=\"code\">$vm</span>. This is likely a programming error.\n");
# 		}
# 		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 			name1 => "vm",     value1 => $vm,
# 			name2 => "say_vm", value2 => $say_vm,
# 		}, file => $THIS_FILE, line => __LINE__});
# 		
# 		# This will control the buttons.
# 		$an->data->{vm}{$vm}{can_start}        = 0;
# 		$an->data->{vm}{$vm}{can_stop}         = 0;
# 		$an->data->{vm}{$vm}{can_migrate}      = 0;
# 		$an->data->{vm}{$vm}{current_host}     = 0;
# 		$an->data->{vm}{$vm}{migration_target} = "";
# 		
# 		# Find out who, if anyone, is running this VM and who *can* run
# 		# it. 2 == Running, 1 == Can run, 0 == Can't run.
# 		$an->data->{vm}{$vm}{say_node1}        = $an->data->{node}{$node1}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">#!string!state_0006!#</span>" : "<span class=\"code\">--</span>";
# 		$an->data->{vm}{$vm}{node1_ready}      = 0;
# 		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 			name1 => "vm::${vm}::say_node1",                    value1 => $an->data->{vm}{$vm}{say_node1},
# 			name2 => "node::${node1}::daemon::cman::exit_code", value2 => $an->data->{node}{$node1}{daemon}{cman}{exit_code},
# 		}, file => $THIS_FILE, line => __LINE__});
# 		$an->data->{vm}{$vm}{say_node2}        = $an->data->{node}{$node2}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">#!string!state_0006!#</span>" : "<span class=\"code\">--</span>";
# 		$an->data->{vm}{$vm}{node2_ready}      = 0;
# 		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 			name1 => "vm::${vm}::say_node2",                    value1 => $an->data->{vm}{$vm}{say_node2},
# 			name2 => "node::${node2}::daemon::cman::exit_code", value2 => $an->data->{node}{$node2}{daemon}{cman}{exit_code},
# 		}, file => $THIS_FILE, line => __LINE__});
# 		
# 		# If a VM's XML definition file is found but there is no host,
# 		# the user probably forgot to define it.
# 		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 			name1 => "vm",   value1 => $vm,
# 			name2 => "host", value2 => $an->data->{vm}{$vm}{host},
# 		}, file => $THIS_FILE, line => __LINE__});
# 		if ((not $an->data->{vm}{$vm}{host}) && (not $an->data->{sys}{ignore_missing_vm}))
# 		{
# 			# Pull the host node and current state out of the hash.
# 			my $host_node = "";
# 			my $vm_state  = "";
# 			foreach my $node (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{node}})
# 			{
# 				$host_node = $node;
# 				foreach my $key (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{node}{$node}{virsh}})
# 				{
# 					if ($key eq "state") 
# 					{
# 						$vm_state = $an->data->{vm}{$vm}{node}{$host_node}{virsh}{'state'};
# 					}
# 					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
# 						name1 => "vm",           value1 => $vm,
# 						name2 => "node",         value2 => $node,
# 						name3 => "virsh '$key'", value3 => $an->data->{vm}{$vm}{node}{$node}{virsh}{$key},
# 					}, file => $THIS_FILE, line => __LINE__});
# 				}
# 			}
# 			$an->data->{vm}{$vm}{say_node1} = "--";
# 			$an->data->{vm}{$vm}{say_node2} = "--";
# 			my $say_error = $an->String->get({key => "message_0271", variables => { 
# 					server	=>	$say_vm,
# 					url	=>	"?cluster=".$an->data->{sys}{anvil}{name}."&task=add_vm&name=$say_vm&node=$host_node&state=$vm_state",
# 				}});
# 			AN::Cluster::error($an, "$say_error", 0);
# 			next;
# 		}
# 		
# 		$an->data->{vm}{$vm}{host} = "" if not defined $an->data->{vm}{$vm}{host};
# 		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
# 			name1 => "vm",              value1 => $vm,
# 			name2 => "vm::${vm}::host", value2 => $an->data->{vm}{$vm}{host},
# 			name3 => "short_node1",     value3 => $short_node1,
# 			name4 => "short_node2",     value4 => $short_node2,
# 		}, file => $THIS_FILE, line => __LINE__});
# 		if ($an->data->{vm}{$vm}{host} =~ /$short_node1/)
# 		{
# 			# Even though I know the host is ready, this function
# 			# loads some data, like LV details, which I will need
# 			# later.
# 			check_node_readiness($an, $vm, $node1);
# 			$an->data->{vm}{$vm}{can_start}     = 0;
# 			$an->data->{vm}{$vm}{can_stop}      = 1;
# 			$an->data->{vm}{$vm}{current_host}  = $node1;
# 			$an->data->{vm}{$vm}{node1_ready}   = 2;
# 			($an->data->{vm}{$vm}{node2_ready}) = check_node_readiness($an, $vm, $node2);
# 			if ($an->data->{vm}{$vm}{node2_ready})
# 			{
# 				$an->data->{vm}{$vm}{migration_target} = $long_node2;
# 				$an->data->{vm}{$vm}{can_migrate}      = 1;
# 			}
# 			# Disable cluster withdrawl of this node.
# 			$an->data->{node}{$node1}{enable_withdraw} = 0;
# 			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
# 				name1 => "vm",               value1 => $vm,
# 				name2 => "node1",            value2 => $node1,
# 				name3 => "node2 ready",      value3 => $an->data->{vm}{$vm}{node2_ready},
# 				name4 => "can migrate",      value4 => $an->data->{vm}{$vm}{can_migrate},
# 				name5 => "migration target", value5 => $an->data->{vm}{$vm}{migration_target},
# 			}, file => $THIS_FILE, line => __LINE__});
# 		}
# 		elsif ($an->data->{vm}{$vm}{host} =~ /$short_node2/)
# 		{
# 			# Even though I know the host is ready, this function
# 			# loads some data, like LV details, which I will need
# 			# later.
# 			check_node_readiness($an, $vm, $node2);
# 			$an->data->{vm}{$vm}{can_start}     = 0;
# 			$an->data->{vm}{$vm}{can_stop}      = 1;
# 			$an->data->{vm}{$vm}{current_host}  = $node2;
# 			($an->data->{vm}{$vm}{node1_ready}) = check_node_readiness($an, $vm, $node1);
# 			$an->data->{vm}{$vm}{node2_ready}   = 2;
# 			if ($an->data->{vm}{$vm}{node1_ready})
# 			{
# 				$an->data->{vm}{$vm}{migration_target} = $long_node1;
# 				$an->data->{vm}{$vm}{can_migrate}      = 1;
# 			}
# 			# Disable withdrawl of this node.
# 			$an->data->{node}{$node2}{enable_withdraw} = 0;
# 			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
# 				name1 => "vm",               value1 => $vm,
# 				name2 => "node1",            value2 => $node1,
# 				name3 => "node2 ready",      value3 => $an->data->{vm}{$vm}{node2_ready},
# 				name4 => "can migrate",      value4 => $an->data->{vm}{$vm}{can_migrate},
# 				name5 => "migration target", value5 => $an->data->{vm}{$vm}{migration_target},
# 			}, file => $THIS_FILE, line => __LINE__});
# 		}
# 		else
# 		{
# 			$an->data->{vm}{$vm}{can_stop}      = 0;
# 			($an->data->{vm}{$vm}{node1_ready}) = check_node_readiness($an, $vm, $node1);
# 			($an->data->{vm}{$vm}{node2_ready}) = check_node_readiness($an, $vm, $node2);
# 			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
# 				name1 => "vm",          value1 => $vm,
# 				name2 => "node1_ready", value2 => $an->data->{vm}{$vm}{node1_ready},
# 				name3 => "node2_ready", value3 => $an->data->{vm}{$vm}{node2_ready},
# 			}, file => $THIS_FILE, line => __LINE__});
# 		}
# 		
# 		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 			name1 => "vm",           value1 => $vm,
# 			name2 => "current host", value2 => $an->data->{vm}{$vm}{current_host},
# 		}, file => $THIS_FILE, line => __LINE__});
# 		$an->data->{vm}{$vm}{boot_target} = "";
# 		if ($an->data->{vm}{$vm}{current_host})
# 		{
# 			# This is a bit expensive, but read the VM's running
# 			# definition.
# 			my $node       =  $an->data->{vm}{$vm}{current_host};
# 			my $say_vm     =  $vm;
# 			   $say_vm     =~ s/^vm://;
# 			my $shell_call =  $an->data->{path}{virsh}." dumpxml $say_vm";
# 			my $password   =  $an->data->{sys}{root_password};
# 			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
# 				name1 => "shell_call", value1 => $shell_call,
# 				name2 => "node",       value2 => $node,
# 			}, file => $THIS_FILE, line => __LINE__});
# 			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
# 				target		=>	$node,
# 				port		=>	$an->data->{node}{$node}{port}, 
# 				password	=>	$password,
# 				ssh_fh		=>	"",
# 				'close'		=>	0,
# 				shell_call	=>	$shell_call,
# 			});
# 			foreach my $line (@{$return})
# 			{
# 				$line =~ s/^\s+//;
# 				$line =~ s/\s+$//;
# 				$line =~ s/\s+/ /g;
# 				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
# 					name1 => "line", value1 => $line, 
# 				}, file => $THIS_FILE, line => __LINE__});
# 				
# 				push @{$an->data->{vm}{$vm}{xml}}, $line;
# 			}
# 		}
# 		else
# 		{
# 			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
# 				name1 => "vm",          value1 => $vm,
# 				name2 => "node1_ready", value2 => $an->data->{vm}{$vm}{node1_ready},
# 				name3 => "node2_ready", value3 => $an->data->{vm}{$vm}{node2_ready},
# 			}, file => $THIS_FILE, line => __LINE__});
# 			if (($an->data->{vm}{$vm}{node1_ready}) && ($an->data->{vm}{$vm}{node2_ready}))
# 			{
# 				# I can boot on either node, so choose the 
# 				# first one in the VM's failover domain.
# 				$an->data->{vm}{$vm}{boot_target} = find_prefered_host($an, $vm);
# 				$an->data->{vm}{$vm}{can_start}   = 1;
# 				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
# 					name1 => "vm",                   value1 => $vm,
# 					name2 => "boot target",          value2 => $an->data->{vm}{$vm}{boot_target},
# 					name3 => "vm::${vm}::can_start", value3 => $an->data->{vm}{$vm}{can_start},
# 				}, file => $THIS_FILE, line => __LINE__});
# 			}
# 			elsif ($an->data->{vm}{$vm}{node1_ready})
# 			{
# 				$an->data->{vm}{$vm}{boot_target} = $node1;
# 				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 					name1 => "vm",          value1 => $vm,
# 					name2 => "boot target", value2 => $an->data->{vm}{$vm}{boot_target},
# 				}, file => $THIS_FILE, line => __LINE__});
# 			}
# 			elsif ($an->data->{vm}{$vm}{node2_ready})
# 			{
# 				$an->data->{vm}{$vm}{boot_target} = $node2;
# 				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 					name1 => "vm",          value1 => $vm,
# 					name2 => "boot target", value2 => $an->data->{vm}{$vm}{boot_target},
# 				}, file => $THIS_FILE, line => __LINE__});
# 			}
# 			else
# 			{
# 				$an->data->{vm}{$vm}{can_start} = 0;
# 				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
# 					name1 => "vm",        value1 => $vm,
# 					name2 => "can_start", value2 => $an->data->{vm}{$vm}{can_start},
# 				}, file => $THIS_FILE, line => __LINE__});
# 			}
# 		}
# 	}
	
	return (0);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

### NOTE: This is ugly, but it's basically a port of the old function so ya, whatever.
# This does the actual calls out to get the data and parse the returned data.
sub _gather_node_details
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
		name2 => "node_key",  value2 => $node_key,
		name3 => "anvil",     value3 => $anvil,
		name4 => "node_name", value4 => $node_name,
		name5 => "target",    value5 => $target,
		name6 => "port",      value6 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{dmidecode}." -t 4,16,17";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $dmidecode) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
		
	# If this is the first up node, mark it as the one to use later if another function needs to get more
	# info from the Anvil!.
	$an->data->{sys}{use_node} = $node_name if not $an->data->{sys}{use_node};
	
	### Get the rest of the shell calls done before starting to parse.
	# Check to see if 'anvil-safe-start' is running
	$shell_call = $an->data->{path}{nodes}{'anvil-safe-start'}." --status";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $anvil_safe_start) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Get meminfo
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_meminfo};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $meminfo) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Get drbd info
	$shell_call = "
if [ -e ".$an->data->{path}{proc_drbd}." ]; 
then 
    ".$an->data->{path}{cat}." ".$an->data->{path}{proc_drbd}."; 
else 
    ".$an->data->{path}{echo}." 'drbd offline'; 
fi";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $proc_drbd) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	$shell_call = $an->data->{path}{drbdadm}." dump-xml";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $parse_drbdadm_dumpxml) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# clustat info
	$shell_call = $an->data->{path}{clustat};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $clustat) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Read cluster.conf
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{cman_config};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $cluster_conf) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Read the daemon states
	$shell_call = "
".$an->data->{path}{initd}."/rgmanager status; ".$an->data->{path}{echo}." striker:rgmanager:\$?; 
".$an->data->{path}{initd}."/cman status; ".$an->data->{path}{echo}." striker:cman:\$?; 
".$an->data->{path}{initd}."/drbd status; ".$an->data->{path}{echo}." striker:drbd:\$?; 
".$an->data->{path}{initd}."/clvmd status; ".$an->data->{path}{echo}." striker:clvmd:\$?; 
".$an->data->{path}{initd}."/gfs2 status; ".$an->data->{path}{echo}." striker:gfs2:\$?; 
".$an->data->{path}{initd}."/libvirtd status; ".$an->data->{path}{echo}." striker:libvirtd:\$?;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $daemons) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# LVM data
	$shell_call = "
".$an->data->{path}{pvscan}."; 
".$an->data->{path}{vgscan}."; 
".$an->data->{path}{lvscan};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $lvm_scan) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	$shell_call = "
".$an->data->{path}{pvs}." --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid; 
".$an->data->{path}{vgs}." --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name; 
".$an->data->{path}{lvs}." --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices;",
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $lvm_data) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# GFS2 data
	$shell_call = "
".$an->data->{path}{cat}." ".$an->data->{path}{etc_fstab}." | ".$an->data->{path}{'grep'}." gfs2;
".$an->data->{path}{df}." -hP";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $gfs2) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# virsh data
	$shell_call = $an->data->{path}{virsh}." list --all";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $virsh) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# VM definitions - from file
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{definitions}."/*";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $vm_defs) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# VM definitions - in memory
	$shell_call = "
for server in \$(".$an->data->{path}{virsh}." list | ".$an->data->{path}{'grep'}." running | ".$an->data->{path}{awk}." '{print \$2}'); 
do 
    ".$an->data->{path}{virsh}." dumpxml \$server; 
done
";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $vm_defs_in_mem) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Host name, in case the cluster isn't configured yet.
	$shell_call = $an->data->{path}{hostname};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $hostname) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	if ($hostname->[0])
	{
		$an->data->{node}{$node_name}{info}{host_name} = $hostname->[0]; 
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::info::host_name", value1 => $an->data->{node}{$node_name}{info}{host_name},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Read the node's host file.
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{etc_hosts};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $hosts) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Read the node's dmesg.
	$shell_call = $an->data->{path}{dmesg};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $dmesg) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Bond data
	$shell_call = "
for i in \$(".$an->data->{path}{ls}." ".$an->data->{path}{proc_bonding}."/); 
do 
    if [ \$i != 'bond0' ];
    then
        ".$an->data->{path}{echo}." 'start: \$i';
        ".$an->data->{path}{cat}." ".$an->data->{path}{proc_bonding}."/\$i;
    fi
done
";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name",  value1 => $node_name,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $bond) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	$an->Striker->_parse_anvil_safe_start({node_name => $node_name, data => $anvil_safe_start});
# 	$an->Striker->_parse_bonds           ({node_name => $node_name, data => $bond});
# 	$an->Striker->_parse_clustat         ({node_name => $node_name, data => $clustat});
# 	$an->Striker->_parse_cluster_conf    ({node_name => $node_name, data => $cluster_conf});
# 	$an->Striker->_parse_daemons         ({node_name => $node_name, data => $daemons});
# 	$an->Striker->_parse_drbdadm_dumpxml ({node_name => $node_name, data => $parse_drbdadm_dumpxml});
# 	$an->Striker->_parse_dmesg           ({node_name => $node_name, data => $dmesg});
# 	$an->Striker->_parse_dmidecode       ({node_name => $node_name, data => $dmidecode});
# 	$an->Striker->_parse_gfs2            ({node_name => $node_name, data => $gfs2});
# 	$an->Striker->_parse_hosts           ({node_name => $node_name, data => $hosts});
# 	$an->Striker->_parse_lvm_data        ({node_name => $node_name, data => $lvm_data});
# 	$an->Striker->_parse_lvm_scan        ({node_name => $node_name, data => $lvm_scan});
# 	$an->Striker->_parse_meminfo         ({node_name => $node_name, data => $meminfo});
# 	$an->Striker->_parse_proc_drbd       ({node_name => $node_name, data => $proc_drbd});
# 	$an->Striker->_parse_virsh           ({node_name => $node_name, data => $virsh});
# 	$an->Striker->_parse_vm_defs         ({node_name => $node_name, data => $vm_defs});
# 	$an->Striker->_parse_vm_defs_in_mem  ({node_name => $node_name, data => $vm_defs_in_mem});	# Always parse this after 'parse_vm_defs()' so that we overwrite it.

# 	# Some stuff, like setting the system memory, needs some post-scan math.
# 	$an->Striker->_post_node_calculations({node_name => $node_name});
	
	return (0);
}

# Parse the 'anvil-safe-start' status.
sub _parse_anvil_safe_start
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_name = $parameter->{node_name};
	my $data      = $parameter->{data};
	
	$an->data->{node}{$node_name}{'anvil-safe-start'} = 0;
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "line",      value2 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($line =~ /\[running\]/i) or ($line =~ /\[queued\]/i))
		{
			$an->data->{node}{$node_name}{'anvil-safe-start'} = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node_name}::anvil-safe-start", value1 => $an->data->{node}{$node_name}{'anvil-safe-start'},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

1;
