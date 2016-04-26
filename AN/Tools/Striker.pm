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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0011", message_variables => {
		name1  => "sys::anvil::name",                 value1  => $an->data->{sys}{anvil}{name}, 
		name2  => "sys::anvil::description",          value2  => $an->data->{sys}{anvil}{description}, 
		name3  => "sys::anvil::note",                 value3  => $an->data->{sys}{anvil}{note}, 
		name4  => "sys::anvil::owner::name",          value4  => $an->data->{sys}{anvil}{owner}{name}, 
		name5  => "sys::anvil::owner::note",          value5  => $an->data->{sys}{anvil}{owner}{note}, 
		name6  => "sys::anvil::smtp::server",         value6  => $an->data->{sys}{anvil}{smtp}{server}, 
		name7  => "sys::anvil::smtp::port",           value7  => $an->data->{sys}{anvil}{smtp}{port}, 
		name8  => "sys::anvil::smtp::username",       value8  => $an->data->{sys}{anvil}{smtp}{username}, 
		name9  => "sys::anvil::smtp::security",       value9  => $an->data->{sys}{anvil}{smtp}{security}, 
		name10 => "sys::anvil::smtp::authentication", value10 => $an->data->{sys}{anvil}{smtp}{authentication}, 
		name11 => "sys::anvil::smtp::helo_domain",    value11 => $an->data->{sys}{anvil}{smtp}{helo_domain}, 
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0012", message_variables => {
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
		}, file => $THIS_FILE, line => __LINE__});
		
		# Password
		$an->data->{sys}{anvil}{$node_key}{password} = $an->data->{anvils}{$anvil_uuid}{$node_key}{password};
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::${node_key}::password", value1 => $an->data->{sys}{anvil}{$node_key}{password}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		### TODO: Test access on the BCN. If that fails, try the IFN and if that fails, the 
		###       remote_ip/port and record which to use. Make this a 'test_access()' method below.
	}
	
	return(0);
}

#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
