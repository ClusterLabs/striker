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
# 


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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0012", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0016", message_variables => {
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
		anvil_message	=>	$an->String->get({key => "message_0272", variables => { anvil => $an->data->{cgi}{cluster} }}),
	}});
	
	# Start your engines!
	$an->Striker->scan_node({ uuid => $an->data->{sys}{anvil}{node1}{uuid} });
	$an->Striker->scan_node({ uuid => $an->data->{sys}{anvil}{node2}{uuid} });

	#check_node_status($an);
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "up nodes", value1 => $an->data->{sys}{up_nodes},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{up_nodes} > 0)
	{
		AN::Striker::check_vms($an);
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
		name1 => "up nodes", value1 => $an->data->{sys}{up_nodes},
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
	my $node_key = $node_uuid eq $an->data->{sys}{anvil}{node1}{uuid} ? "node1" : "node2";
	
	### TODO: Cache the network we connect on so we don't waste time trying to connect on subsequent 
	###       loads. Work this into the 'cache' DB table when we create it.
	### Figure out how to access the node.
	# BCN first.
	my $bcn_access = $an->Check->access({
			target   => $an->data->{sys}{anvil}{$node_key}{bcn_ip},
			port     => 22,
			password => $an->data->{sys}{anvil}{$node_key}{password},
		});
	if ($bcn_access)
	{
		# Woot
		$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{bcn_ip};
		$an->data->{sys}{anvil}{$node_key}{use_port} = 22; 
		$an->data->{sys}{anvil}{$node_key}{online}   = 1;
	}
	else
	{
		# Try the IFN
		my $ifn_access = $an->Check->access({
				target   => $an->data->{sys}{anvil}{$node_key}{ifn_ip},
				port     => 22,
				password => $an->data->{sys}{anvil}{$node_key}{password},
			});
		if ($ifn_access)
		{
			# Woot
			$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{ifn_ip};
			$an->data->{sys}{anvil}{$node_key}{use_port} = 22; 
			$an->data->{sys}{anvil}{$node_key}{online}   = 1;
		}
		else
		{
			# Try the remote IP/Port
			my $remote_access = $an->Check->access({
					target   => $an->data->{sys}{anvil}{$node_key}{remote_ip},
					port     => $an->data->{sys}{anvil}{$node_key}{remote_port},
					password => $an->data->{sys}{anvil}{$node_key}{password},
				});
			if ($remote_access)
			{
				# Woot
				$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{remote_ip};
				$an->data->{sys}{anvil}{$node_key}{use_port} = $an->data->{sys}{anvil}{$node_key}{remote_port}; 
				$an->data->{sys}{anvil}{$node_key}{online}   = 1;
			}
			else
			{
				### TODO: Check for the power_check command and see if we can read the power 
				###       state
				# No luck.
				$an->data->{sys}{anvil}{$node_key}{online} = 0;
			}
		}
	}
	
# 	# set daemon states to 'Unknown'.
# 	$an->Log->entry({log_level => 3, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
# 	set_daemons($an, $node, "Unknown", "highlight_unavailable");
# 	
# 	# Gather details on the node.
# 	$an->Log->entry({log_level => 3, message_key => "log_0018", message_variables => {
# 		node => $node, 
# 	}, file => $THIS_FILE, line => __LINE__});
# 	gather_node_details($an, $node);
# 	
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
# 			if ($an->data->{clusters}{$cluster}{cache_exists})
# 			{
# 				print $an->Web->template({file => "main-page.html", template => "no-access-message", replace => { 
# 					anvil	=>	$an->data->{cgi}{cluster},
# 					message	=>	"#!string!message_0028!#",
# 				}});
# 			}
# 			else
# 			{
# 				print $an->Web->template({file => "main-page.html", template => "no-access-message", replace => { 
# 					anvil	=>	$an->data->{cgi}{cluster},
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


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
