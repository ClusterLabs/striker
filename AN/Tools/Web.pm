package AN::Tools::Web;
# 
# This module will be used to process anything to do with presenting data to a user's web browser.
# 

use strict;
use warnings;
use Data::Dumper;
use CGI;
#use CGI::Carp qw(fatalsToBrowser);
use Encode;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Web.pm";

### Methods;
# build_select
# check_all_cgi
# initialize_http
# get_cgi
# more_info_link
# no_db_access
# parse_text_line
# template


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
	my $class = shift;
	
	my $self  = {};
	
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

# This builds an HTML select field.
sub build_select
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "build_select" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Required
	my $name     = $parameter->{name};
	my $options  = $parameter->{options};
	# Optional
	my $id        = defined $parameter->{id}        ? $parameter->{id}        : $name;
	my $sort      = defined $parameter->{'sort'}    ? $parameter->{'sort'}    : 1;	# Sort the entries?
	my $width     = defined $parameter->{width}     ? $parameter->{width}     : 0;	# 0 = let the browser set the width
	my $blank     = defined $parameter->{blank}     ? $parameter->{blank}     : 0;	# Add a blank/null entry?
	my $say_blank = defined $parameter->{say_blank} ? $parameter->{say_blank} : "";	# An optional, grayed-out string in the place of the "blank" option
	my $selected  = defined $parameter->{selected}  ? $parameter->{selected}  : "";	# Pre-select an option?
	$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
		name1 => "name",      value1 => $name, 
		name2 => "options",   value2 => $options, 
		name3 => "sort",      value3 => $sort, 
		name4 => "width",     value4 => $width, 
		name5 => "blank",     value5 => $blank, 
		name6 => "say_blank", value6 => $say_blank, 
		name7 => "selected",  value7 => $selected, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $select = "<select name=\"$name\" id=\"$id\">\n";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select", value1 => $select,
	}, file => $THIS_FILE, line => __LINE__});
	if ($width)
	{
		$select = "<select name=\"$name\" id=\"$id\" style=\"width: ${width}px;\">\n";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "select", value1 => $select,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Insert a blank line.
	if ($blank)
	{
		# If 'say_blank' is a string key, use it.
		my $blank_string = "";
		my $blank_class  = "";
		if ($say_blank)
		{
			$blank_string = "#!string!".$say_blank."!#";
			$blank_class  = "class=\"subtle_text\"";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "blank_string", value1 => $blank_string,
				name2 => "blank_class",  value2 => $blank_class,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($selected eq "new")
		{
			$selected =  "";
			$select   .= "<option value=\"\" $blank_class selected>$blank_string</option>\n";
		}
		else
		{
			$select .= "<option value=\"\" $blank_class>$blank_string</option>\n";
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "select", value1 => $select,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# This needs to be smarter.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sort", value1 => $sort,
	}, file => $THIS_FILE, line => __LINE__});
	if ($sort)
	{
		foreach my $entry (sort {$a cmp $b} @{$options})
		{
			next if not $entry;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "entry", value1 => $entry,
			}, file => $THIS_FILE, line => __LINE__});
			if ($entry =~ /^(.*?)#!#(.*)$/)
			{
				my $value       =  $1;
				my $description =  $2;
				   $select      .= "<option value=\"$value\">$description</option>\n";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "value",       value1 => $value,
					name2 => "description", value2 => $description,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$select .= "<option value=\"$entry\">$entry</option>\n";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "entry", value1 => $entry,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		foreach my $entry (@{$options})
		{
			next if not $entry;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "entry", value1 => $entry,
			}, file => $THIS_FILE, line => __LINE__});
			if ($entry =~ /^(.*?)#!#(.*)$/)
			{
				my $value       =  $1;
				my $description =  $2;
				   $select      .= "<option value=\"$value\">$description</option>\n";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "value",       value1 => $value,
					name2 => "description", value2 => $description,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$select .= "<option value=\"$entry\">$entry</option>\n";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "entry", value1 => $entry,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "selected", value1 => $selected,
	}, file => $THIS_FILE, line => __LINE__});
	if ($selected)
	{
		$select =~ s/value=\"$selected\">/value=\"$selected\" selected>/m;
	}
	
	$select .= "</select>\n";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select", value1 => $select,
	}, file => $THIS_FILE, line => __LINE__});
	
	return ($select);
}

# This checks for all the possible CGI variables and reads in the ones it finds.
sub check_all_cgi
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_all_cgi" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $cgi = [
		"adapter",
		"anvil",
		"anvil_bcn_ethtool_opts",
		"anvil_bcn_network",
		"anvil_bcn_subnet",
		"anvil_description",
		"anvil_dns1",
		"anvil_dns2",
		"anvil_domain",
		"anvil_drbd_disk_disk-barrier",
		"anvil_drbd_disk_disk-flushes",
		"anvil_drbd_disk_md-flushes",
		"anvil_drbd_disk_c-plan-ahead",
		"anvil_drbd_disk_c-max-rate",
		"anvil_drbd_disk_c-min-rate",
		"anvil_drbd_disk_c-fill-target",
		"anvil_drbd_net_max-buffers",
		"anvil_drbd_net_rcvbuf-size",
		"anvil_drbd_net_sndbuf-size",
		"anvil_drbd_options_cpu-mask",
		"anvil_fence_order",
		"anvil_id",
		"anvil_ifn_ethtool_opts",
		"anvil_ifn_gateway",
		"anvil_ifn_network",
		"anvil_ifn_subnet",
		"anvil_media_library_size",
		"anvil_media_library_unit",
		"anvil_mtu_size",
		"anvil_name",
		"anvil_node1_bcn_ip",
		"anvil_node1_bcn_link1_mac",
		"anvil_node1_bcn_link2_mac",
		"anvil_node1_current_ip",
		"anvil_node1_current_password",
		"anvil_node1_ifn_ip",
		"anvil_node1_ifn_link1_mac",
		"anvil_node1_ifn_link2_mac",
		"anvil_node1_ipmi_gateway",
		"anvil_node1_ipmi_ip",
		"anvil_node1_ipmi_netmask",
		"anvil_node1_ipmi_password",
		"anvil_node1_ipmi_user",
		"anvil_node1_name",
		"anvil_node1_pdu1_outlet",
		"anvil_node1_pdu2_outlet",
		"anvil_node1_pdu3_outlet",
		"anvil_node1_pdu4_outlet",
		"anvil_node1_sn_ip",
		"anvil_node1_sn_link1_mac",
		"anvil_node1_sn_link2_mac",
		"anvil_node1_uuid",
		"anvil_node2_bcn_ip",
		"anvil_node2_bcn_link1_mac",
		"anvil_node2_bcn_link2_mac",
		"anvil_node2_current_ip",
		"anvil_node2_current_password",
		"anvil_node2_ifn_ip",
		"anvil_node2_ifn_link1_mac",
		"anvil_node2_ifn_link2_mac",
		"anvil_node2_ipmi_ip",
		"anvil_node2_ipmi_netmask",
		"anvil_node2_ipmi_password",
		"anvil_node2_ipmi_user",
		"anvil_node2_name",
		"anvil_node2_pdu1_outlet",
		"anvil_node2_pdu2_outlet",
		"anvil_node2_pdu3_outlet",
		"anvil_node2_pdu4_outlet",
		"anvil_node2_sn_ip",
		"anvil_node2_sn_link1_mac",
		"anvil_node2_sn_link2_mac",
		"anvil_node2_uuid",
		"anvil_note",
		"anvil_ntp1",
		"anvil_ntp2",
		"anvil_open_vnc_ports",
		"anvil_owner_uuid",
		"anvil_password",
		"anvil_pdu1_agent",
		"anvil_pdu1_ip",
		"anvil_pdu1_name",
		"anvil_pdu2_agent",
		"anvil_pdu2_ip",
		"anvil_pdu2_name",
		"anvil_pdu3_agent",
		"anvil_pdu3_ip",
		"anvil_pdu3_name",
		"anvil_pdu4_agent",
		"anvil_pdu4_ip",
		"anvil_pdu4_name",
		"anvil_prefix",
		"anvil_pts1_ip",
		"anvil_pts1_name",
		"anvil_pts2_ip",
		"anvil_pts2_name",
		"anvil_repositories",
		"anvil_ricci_password",
		"anvil_root_password",
		"anvil_sequence",
		"anvil_smtp_uuid",
		"anvil_sn_ethtool_opts",
		"anvil_sn_network",
		"anvil_sn_subnet",
		"anvil_ssh_keysize",
		"anvil_storage_partition_1_byte_size",
		"anvil_storage_partition_2_byte_size",
		"anvil_storage_pool1_size",
		"anvil_storage_pool1_unit",
		"anvil_striker1_bcn_ip",
		"anvil_striker1_database",
		"anvil_striker1_ifn_ip",
		"anvil_striker1_name",
		"anvil_striker1_password",
		"anvil_striker1_user",
		"anvil_striker1_uuid",
		"anvil_striker2_bcn_ip",
		"anvil_striker2_database",
		"anvil_striker2_ifn_ip",
		"anvil_striker2_name",
		"anvil_striker2_password",
		"anvil_striker2_user",
		"anvil_striker2_uuid",
		"anvil_switch1_ip",
		"anvil_switch1_name",
		"anvil_switch2_ip",
		"anvil_switch2_name",
		"anvil_ups1_ip",
		"anvil_ups1_name",
		"anvil_ups2_ip",
		"anvil_ups2_name",
		"anvil_uuid",
		"boot_device",
		"change",
		"cluster",
		"config",
		"configure",
		"confirm",
		"cpu_cores",
		"delete",
		"dev",
		"device",
		"device_keys",
		"disk_address",
		"do",
		"dr_job",
		"dr_job_name", 
		"dr_job_note", 
		"dr_job_auto_prune",
		"dr_job_dr_target_uuid",
		"dr_job_anvil_uuid",
		"dr_job_schedule",
		"dr_job_server_list", 
		"dr_job_servers",
		"dr_job_uuid",
		"dr_target",
		"dr_target_name",
		"dr_target_note", 
		"dr_target_bandwidth_limit",
		"dr_target_copies",
		"dr_target_address",
		"dr_target_password",
		"dr_target_store",
		"dr_target_store_type",
		"dr_target_store_location",
		"dr_target_tcp_port",
		"dr_target_use_cache",
		"dr_target_uuid",
		"driver_iso",
		"expire",
		"file",
		"generate",
		"host",
		"insert",
		"install_iso",
		"install_target",
		"load",
		"load_anvil",
		"load_dr_job", 
		"load_dr_target",
		"load_notify",
		"load_owner",
		"load_smtp",
		"logical_disk",
		"logo",
		"mail_data__sending_domain",
		"mail_data__to",
		"make_disk_good",
		"manifest_data",
		"manifest_uuid",
		"max_cores",
		"max_ram",
		"max_storage",
		"name",
		"node",
		"node_name",
		"node_uuid",
		"node1_access",
		"node1_bcn",
		"node1_host_name",
		"node1_host_uuid",
		"node1_ifn",
		"node1_note",
		"node1_password",
		"node1_remote_ip",
		"node1_remote_port",
		"node1_sn",
		"node1_uuid",
		"node2_access",
		"node2_bcn",
		"node2_host_name",
		"node2_host_uuid",
		"node2_ifn",
		"node2_note",
		"node2_password",
		"node2_remote_ip",
		"node2_remote_port",
		"node2_sn",
		"node2_uuid",
		"node_cluster_name",
		"note",
		"notify_address",
		"notify_language",
		"notify_level",
		"notify_name",
		"notify_note",
		"notify_target",
		"notify_units",
		"notify_uuid",
		"os_variant",
		"owner_name",
		"owner_note",
		"owner_uuid",
		"perform_install",
		"ram",
		"ram_suffix",
		"raw",
		"recipient_anvil_uuid",
		"recipient_log_level",
		"recipient_note",
		"recipient_notify_uuid",
		"recipient_uuid",
		"remap_network",
		"rhn_password",
		"rhn_user",
		"row",
		"run",
		"save",
		"script", 
		"section",
		"server",
		"server_migration_type",
		"server_note",
		"server_post_migration_arguments",
		"server_post_migration_script",
		"server_pre_migration_arguments",
		"server_pre_migration_script",
		"server_start_after",
		"server_start_delay",
		"smtp_alt_port", 
		"smtp_alt_server", 
		"smtp_authentication",
		"smtp_helo_domain",
		"smtp_note",
		"smtp_password",
		"smtp_port",
		"smtp_security",
		"smtp_server",
		"smtp_username",
		"smtp_uuid",
		"storage",
		"striker_database",
		"striker_user",
		"subtask",
		"system",
		"target",
		"task",
		"update_manifest",
		"url",
		"vg_list",
		"vm",
		"vm_ram",
	];
	
	# When saving notifications, the user can select a specific alert level per configured Anvil!. This 
	# adds the potential CGI variables to the array.
	my $anvil_data  = $an->ScanCore->get_anvils();
	foreach my $hash_ref (@{$anvil_data})
	{
		push @{$cgi}, "notify_anvil_".$hash_ref->{anvil_uuid};
	}
	$an->Web->get_cgi({variables => $cgi});
	
	# When saving DR jobs, the user can select one or more servers for the given job. This adds the 
	# potential CGI variables to the array.
	my $server_data = $an->ScanCore->get_servers();
	foreach my $hash_ref (@{$anvil_data})
	{
		if (exists $hash_ref->{server_uuid})
		{
			push @{$cgi}, "dr_job_server_uuid_".$hash_ref->{server_uuid};
		}
	}
	$an->Web->get_cgi({variables => $cgi});
	
	return (0);
}

# This simply initializes browsers.
sub initialize_http
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "initialize_http" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	print "Content-type: text/html; charset=utf-8\n\n";
	
	return (0);
}

# This reads in data from CGI
sub get_cgi
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_cgi" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure we have an array reference of variables to read.
	my $variables = ref($parameter->{variables}) eq "ARRAY" ? $parameter->{variables} : "";
	if (not $variables)
	{
		# Throw an error and exit.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0069", code => 69, file => $THIS_FILE, line => __LINE__});
	}
	
	# Needed to read in passed CGI variables
	my $cgi = CGI->new();
	
	# This will store the string I was passed.
	$an->data->{sys}{cgi_string} = "?";
	foreach my $variable (@{$variables})
	{
		# A stray comma will cause a loop with no var name
		next if not $variable;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "variable", value1 => $variable, 
		}, file => $THIS_FILE, line => __LINE__});
		
# 		### TODO: We now set 'sys::anvil_uuid_set' when auto-selecting an Anvil! UUID when only one
# 		###       exists. If 'anvil_uuid' is set in CGI though, override it. Sort out the logic to
# 		###       handle this properly below...
# 		# I auto-select the 'anvil' variable if only one is checked. Because of this, I don't want
# 		# to overwrite the empty CGI value. This prevents that. Note that sometimes the 'anvil_uuid'
# 		# passed in will be 'NULL'. In those cases, we overwrite the selected UUID.
# 		if (($variable eq "anvil_uuid") && ($cgi->param($variable) ne "NULL") && ($cgi->param($variable) ne "new") && ($an->data->{cgi}{anvil_uuid}))
# 		#if (($variable eq "anvil_uuid") && (defined $cgi->param($variable)) && (not $an->validate->is_uuid({uuid => $cgi->param($variable)})) && ($an->data->{cgi}{anvil_uuid}))
# 		{
# 			$an->data->{sys}{cgi_string} .= "$variable=".$an->data->{cgi}{$variable}."&";
# 			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
# 				name1 => "variable", value1 => $variable, 
# 				name2 => "value",    value2 => $an->data->{cgi}{$variable},
# 			}, file => $THIS_FILE, line => __LINE__});
# 			next;
# 		}
		
		# Avoid "uninitialized" warning messages.
		$an->data->{cgi}{$variable} = "";
		if (defined $cgi->param($variable))
		{
			my $value = $cgi->param($variable);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "value", value1 => $value,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($variable eq "file")
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "variable", value1 => $variable,
				}, file => $THIS_FILE, line => __LINE__});
				if (not $cgi->upload($variable))
				{
					# Empty file passed, looks like the user forgot to select a file to upload.
					$an->Log->entry({log_level => 2, message_key => "log_0016", file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					   $an->data->{cgi_fh}{$variable}       = $cgi->upload($variable);
					my $file                                = $an->data->{cgi_fh}{$variable};
					   $an->data->{cgi_mimetype}{$variable} = $cgi->uploadInfo($file)->{'Content-Type'};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "variable",                value1 => $variable,
						name2 => "cgi_fh::$variable",       value2 => $an->data->{cgi_fh}{$variable},
						name3 => "cgi_mimetype::$variable", value3 => $an->data->{cgi_mimetype}{$variable},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$an->data->{cgi}{$variable} = $cgi->param($variable);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::${variable}", value1 => $an->data->{cgi}{$variable}, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Make this UTF8 if it isn't already.
			if (not Encode::is_utf8($an->data->{cgi}{$variable}))
			{
				$an->data->{cgi}{$variable} = Encode::decode_utf8( $an->data->{cgi}{$variable} );
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "cgi::${variable}", value1 => $an->data->{cgi}{$variable}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Log the variable and add to cgi_string, if set
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::${variable}", value1 => $an->data->{cgi}{$variable}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{$variable})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::$variable", value1 => $an->data->{cgi}{$variable},
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{sys}{cgi_string} .= "$variable=".$an->data->{cgi}{$variable}."&";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::cgi_string", value1 => $an->data->{sys}{cgi_string}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	# Clear the final '&' from sys::cgi_string
	$an->data->{sys}{cgi_string} =~ s/&$//;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::cgi_string", value1 => $an->data->{sys}{cgi_string}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# This is a pretty way of displaying the passed-in CGI variables. It loops through all we've got and
	# sorts out the longest variable name. Then it loops again, appending '.' to shorter ones so that 
	# everything is lined up in the logs.
	my $longest_variable = 0;
	foreach my $variable (keys %{$an->data->{cgi}})
	{
		next if $an->data->{cgi}{$variable} eq "";
		if (length($variable) > $longest_variable)
		{
			$longest_variable = length($variable);
		}
	}
	
	# Now loop again in alphabetical order printing in the dots as needed.
	foreach my $variable (sort {$a cmp $b} keys %{$an->data->{cgi}})
	{
		next if $an->data->{cgi}{$variable} eq "";
		my $difference   = $longest_variable - length($variable);
		my $say_variable = $variable;
		if ($difference == 0)
		{
			# Do nothing
		}
		elsif ($difference == 1) 
		{
			$say_variable .= " ";
		}
		elsif ($difference == 2) 
		{
			$say_variable .= "  ";
		}
		else
		{
			my $dots         =  $difference - 2;
			   $say_variable .= " ";
			for (1 .. $dots)
			{
				$say_variable .= ".";
			}
			$say_variable .= " ";
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::$say_variable", value1 => $an->data->{cgi}{$variable},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This returns a "More Info" link, *if* 'sys::disable_links' is not set.
sub more_info_link
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "more_info_link" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# TODO: Error if this is not set.
	my $url  = $parameter->{url} ? $parameter->{url} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "url", value1 => $url,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $link = $an->Web->template({file => "web.html", template => "more-info-link", replace => { url => $url }, no_comment => 1});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "link",               value1 => $link,
		name2 => "sys::disable_links", value2 => $an->data->{sys}{disable_links},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{disable_links})
	{
		$link = "&nbsp;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "link", value1 => $link,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "link", value1 => $link,
	}, file => $THIS_FILE, line => __LINE__});
	return($link);
}

# This is presented when no access to a ScanCore database is available.
sub no_db_access
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "no_db_access" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: Move these to 'common.html' once the clean-up is done.
	# Put together the frame of the page.
	my $back_image    = "";
	my $refresh_image = $an->Web->template({file => "common.html", template	=> "image", no_comment => 1, replace => {
			image_source => $an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/refresh.png",
			alt_text     => "#!string!button_0002!#",
			id           => "refresh_icon",
		}});
	my $header = $an->Web->template({file => "configure.html", template => "configure-header", replace => {
			back		=>	$back_image,
			refresh		=>	"<a href=\"".$an->data->{sys}{cgi_string}."\">$refresh_image</a>",,
		}});
	my $footer = $an->Web->template({file => "configure.html", template => "configure-footer"});
	
	my $menu = $an->Web->template({file => "configure.html", template => "no-database-access"});
	
	print $an->Web->template({
			file		=>	"configure.html",
			template	=>	"configure-main-page",
			replace		=>	{
				header		=>	$header, 
				body		=>	$menu, 
				footer		=>	$footer, 
			},
		});
	
	
	return(0);
}

# This tries to parse lines coming back from a shell call to add highlighting and what-not.
sub parse_text_line
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "parse_text_line" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $line = $parameter->{line} ? $parameter->{line} : "";
	
	# 'Da good ^_^
	$line =~ s/(success)/<span class="highlight_good">$1<\/span>/ig;
	$line =~ s/\[\s+(ok)\s+\]/[ <span class="highlight_good">$1<\/span> ]/ig;
	
	# Informational.
	$line =~ s/(done)/<span class="highlight_ready">$1<\/span>/ig;
	$line =~ s/(Starting Cluster):/<span class="highlight_ready">$1<\/span>:/ig;
	$line =~ s/(Stopping Cluster):/<span class="highlight_ready">$1<\/span>:/ig;
	$line =~ s/(shut down)/<span class="highlight_ready">$1<\/span>/ig;
	
	# 'Da bad. ;_;
	$line =~ s/(failed)/<span class="highlight_bad">$1<\/span>/ig;
	$line =~ s/\[\s+(failed)\s+\]/[ <span class="highlight_bad">$1<\/span> ]/ig;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "line", value1 => $line,
	}, file => $THIS_FILE, line => __LINE__});
	return($line);
}

# This takes the name of a template file, the name of a template section within the file, an optional hash
# containing replacement variables to feed into the template and an optional hash containing variables to
# pass into strings, and generates a page to display formatted according to the page.
sub template
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "template" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure we got a file and template name.
	if (not $parameter->{file})
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0073", code => 73, file => $THIS_FILE, line => __LINE__});
	}
	if (not $parameter->{template})
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0074", code => 74, file => $THIS_FILE, line => __LINE__});
	}
	
	my $file       = $parameter->{file};
	my $template   = $parameter->{template};
	my $replace    = $parameter->{replace}    ? $parameter->{replace}    : {};
	my $no_comment = $parameter->{no_comment} ? $parameter->{no_comment} : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "file",       value1 => $file,
		name2 => "template",   value2 => $template,
		name3 => "no_comment", value3 => $no_comment,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If this is called without a skin directory, it will fail. So default to 'alteeve' in such cases.
	if (not $an->data->{sys}{skin})
	{
		$an->data->{sys}{skin} = "alteeve";
	}
	
	my @contents;
	my $template_file = $an->data->{path}{skins}."/".$an->data->{sys}{skin}."/".$file;
	
	# Make sure the file exists.
	if (not -e $template_file)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0075", message_variables => { file => $template_file }, code => 75, file => $THIS_FILE, line => __LINE__});
	}
	elsif (not -r $template_file)
	{
		my $user = getpwuid($<);
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0075", message_variables => { 
			file => $template_file,
			user => $user,
		}, code => 75, file => $THIS_FILE, line => __LINE__});
	}
	
	# Read in the raw template.
	my $in_template = 0;
	my $shell_call  = $template_file;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
	#binmode $file_handle, ":utf8:";
	### WARNING: DO NOT USE $an->Log->entry() below here, it will create an infinite loop!
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		
		if ($line =~ /<!-- start $template -->/)
		{
			$in_template = 1;
			next;
		}
		if ($line =~ /<!-- end $template -->/)
		{
			$in_template = 0;
			last;
		}
		if ($in_template)
		{
			# Read in the template.
			push @contents, $line;
		}
	}
	close $file_handle;
	
	# Now parse the contents for replacement keys.
	my $page = "";
	if (not $no_comment)
	{
		# Add the template opening comment
		my $comment = $an->String->get({key => "tools_log_0025", variables => { 
				template => $template, 
				file     => $file,
			}});
		$page .= "<!-- $comment -->\n";
	}
	foreach my $string (@contents)
	{
		# Replace the '#!replace!...!#' substitution keys.
		$string = $an->String->_process_string_replace({
			string   => $string,
			replace  => $replace, 
			file     => $template_file,
			template => $template,
		});
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "<< string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Process all the #!...!# escape variables.
		($string) = $an->String->_process_string({string => $string, variables => {}});

		$page .= "$string\n";
	}
	if (not $no_comment)
	{
		# Add the closing comment
		my $comment = $an->String->get({key => "tools_log_0026", variables => { 
				template => $template, 
				file     => $file,
			}});
		$page .= "<!-- $comment -->\n";
	}
	
	# If this was the footer, record the footer as having been printed.
	if (($template eq "footer") && ($file eq "commont.html"))
	{
		$an->data->{sys}{footer_printed} = 1;
	}
	
	return($page);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
