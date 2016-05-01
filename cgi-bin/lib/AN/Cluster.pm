package AN::Cluster;

# Striker - Alteeve's Niche! Cluster Dashboard
# 
# This software is released under the GNU GPL v2+ license.
# 
# No warranty is provided. Do not use this software unless you are willing and
# able to take full liability for it's use. The authors take care to prevent
# unexpected side effects when using this program. However, no software is
# perfect and bugs may exist which could lead to hangs or crashes in the
# program, in your cluster and possibly even data loss.
# 
# If you are concerned about these risks, please stick to command line tools.
# 
# This program is designed to extend clusters built according to this tutorial:
# - https://alteeve.ca/w/2-Node_Red_Hat_KVM_Cluster_Tutorial
#
# This program's source code and updates are available on Github:
# - https://github.com/ClusterLabs/striker
#
# Author;
# Alteeve's Niche!  -  https://alteeve.ca
# Madison Kelly     -  mkelly@alteeve.ca
# 
# NOTE: The '$an' file handle has been added to all functions to enable the transition to using AN::Tools.
# 

use strict;
use warnings;
use IO::Handle;
use Net::SSH2;

use AN::Common;
use AN::Striker;

# Setup for UTF-8 mode.
binmode STDOUT, ":utf8:";
$ENV{'PERL_UNICODE'}=1;
my $THIS_FILE = "AN::Cluster.pm";
our $VERSION  = "1.2.0b";

# This sanity-checks striker.conf values before saving.
sub sanity_check_striker_conf
{
	my ($an, $sections) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "sanity_check_striker_conf" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "sections", value1 => $sections, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# This will flip to '0' if any errors are encountered.
	my $save = 1;
	
	# Which global values I am sanity checking depends on whether the user
	# is modifying the global section or an anvil!.
	my $smtp__server_key              = "smtp__server";
	my $smtp__port_key                = "smtp__port";
	my $smtp__username_key            = "smtp__username";
	my $smtp__password_key            = "smtp__password";
	my $smtp__security_key            = "smtp__security";
	my $smtp__encrypt_pass_key        = "smtp__encrypt_pass";
	my $smtp__helo_domain_key         = "smtp__helo_domain";
	my $mail_data__to_key             = "mail_data__to";
	my $mail_data__sending_domain_key = "mail_data__sending_domain";

	# These will be populated in a moment if an Anvil! is being saved.
	my $name_key         = "";
	my $description_key  = "";
	my $url_key          = "";
	my $company_key      = "";
	my $ricci_pw_key     = "";
	my $root_pw_key      = "";
	my $nodes_1_name_key = "";
	my $nodes_1_ip_key   = "";
	my $nodes_1_port_key = "";
	my $nodes_2_name_key = "";
	my $nodes_2_ip_key   = "";
	my $nodes_2_port_key = "";
	
	my $this_nodes_1_ip   = "";
	my $this_nodes_1_name = "";
	my $this_nodes_1_port = "";
	my $this_nodes_2_name = "";
	my $this_nodes_2_ip   = "";
	my $this_nodes_2_port = "";
	
	# Now see if I have an Anvil!
	my $this_cluster = "";
	my $this_id      = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_id", value1 => $an->data->{cgi}{anvil_id},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{anvil_id})
	{
		# Switch out the global keys to this Anvil!'s keys.
		$this_id          = $an->data->{cgi}{anvil_id};
		$name_key         = "cluster__${this_id}__name";
		$description_key  = "cluster__${this_id}__description";
		$url_key          = "cluster__${this_id}__url";
		$company_key      = "cluster__${this_id}__company";
		$ricci_pw_key     = "cluster__${this_id}__ricci_pw";
		$root_pw_key      = "cluster__${this_id}__root_pw";
		$nodes_1_name_key = "cluster__${this_id}__nodes_1_name";
		$nodes_1_ip_key   = "cluster__${this_id}__nodes_1_ip";
		$nodes_1_port_key = "cluster__${this_id}__nodes_1_port";
		$nodes_2_name_key = "cluster__${this_id}__nodes_2_name";
		$nodes_2_ip_key   = "cluster__${this_id}__nodes_2_ip";
		$nodes_2_port_key = "cluster__${this_id}__nodes_2_port";
		
		my $this_name         =  $an->data->{cgi}{$name_key};
		   $this_cluster      =  $this_name;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "this_cluster", value1 => $this_cluster,
		}, file => $THIS_FILE, line => __LINE__});
		my $this_description  =  $an->data->{cgi}{$description_key};
		my $this_url          =  $an->data->{cgi}{$url_key};
		my $this_company      =  $an->data->{cgi}{$company_key};
		my $this_ricci_pw     =  $an->data->{cgi}{$ricci_pw_key};
		my $this_root_pw      =  $an->data->{cgi}{$root_pw_key};
		   $this_nodes_1_name =  $an->data->{cgi}{$nodes_1_name_key};
		   $this_nodes_1_ip   =  $an->data->{cgi}{$nodes_1_ip_key};
		   $this_nodes_1_port =  $an->data->{cgi}{$nodes_1_port_key};
		   $this_nodes_1_port =~ s/,//g;
		   $this_nodes_2_name =  $an->data->{cgi}{$nodes_2_name_key};
		   $this_nodes_2_ip   =  $an->data->{cgi}{$nodes_2_ip_key};
		   $this_nodes_2_port =  $an->data->{cgi}{$nodes_2_port_key};
		   $this_nodes_2_port =~ s/,//g;
		
		$smtp__server_key              = "cluster__${this_id}__smtp__server";
		$smtp__port_key                = "cluster__${this_id}__smtp__port";
		$smtp__username_key            = "cluster__${this_id}__smtp__username";
		$smtp__password_key            = "cluster__${this_id}__smtp__password";
		$smtp__security_key            = "cluster__${this_id}__smtp__security";
		$smtp__encrypt_pass_key        = "cluster__${this_id}__smtp__encrypt_pass";
		$smtp__helo_domain_key         = "cluster__${this_id}__smtp__helo_domain";
		$mail_data__to_key             = "cluster__${this_id}__mail_data__to";
		$mail_data__sending_domain_key = "cluster__${this_id}__mail_data__sending_domain";
		
		# Start the (in)sanity!
		# Add the passed in port and IP (if exists) into the hashed
		# created in read_hosts() and read_ssh_config;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "this_nodes_1_name", value1 => $this_nodes_1_name,
			name2 => "this_nodes_1_ip",   value2 => $this_nodes_1_ip,
		}, file => $THIS_FILE, line => __LINE__});
		if (($this_nodes_1_name) && ($this_nodes_1_ip))
		{
			$an->data->{hosts}{$this_nodes_1_name}{ip} = $this_nodes_1_ip;
			if (not exists $an->data->{hosts}{by_ip}{$this_nodes_1_ip})
			{
				$an->data->{hosts}{by_ip}{$this_nodes_1_ip} = [];
			}
			push @{$an->data->{hosts}{by_ip}{$this_nodes_1_ip}}, $this_nodes_1_name;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "this_nodes_2_name", value1 => $this_nodes_2_name,
			name2 => "this_nodes_2_ip",   value2 => $this_nodes_2_ip,
		}, file => $THIS_FILE, line => __LINE__});
		if (($this_nodes_2_name) && ($this_nodes_2_ip))
		{
			$an->data->{hosts}{$this_nodes_2_name}{ip} = $this_nodes_2_ip;
			if (not exists $an->data->{hosts}{by_ip}{$this_nodes_2_ip})
			{
				$an->data->{hosts}{by_ip}{$this_nodes_2_ip} = [];
			}
			push @{$an->data->{hosts}{by_ip}{$this_nodes_2_ip}}, $this_nodes_2_name;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "this_nodes_1_name", value1 => $this_nodes_1_name,
			name2 => "this_nodes_1_port", value2 => $this_nodes_1_port,
		}, file => $THIS_FILE, line => __LINE__});
		if (($this_nodes_1_name) && ($this_nodes_1_port))
		{
			$an->data->{hosts}{$this_nodes_1_name}{port} = $this_nodes_1_port;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "this_nodes_2_name", value1 => $this_nodes_2_name,
			name2 => "this_nodes_2_port", value2 => $this_nodes_2_port,
		}, file => $THIS_FILE, line => __LINE__});
		if (($this_nodes_2_name) && ($this_nodes_2_port))
		{
			$an->data->{hosts}{$this_nodes_2_name}{port} = $this_nodes_2_port;
		}
		
		# If everything is empty, that's fine.
		if ((not $this_name) && 
		    (not $this_description) && 
		    (not $this_url) && 
		    (not $this_company) && 
		    (not $this_ricci_pw) && 
		    (not $this_root_pw) && 
		    (not $this_nodes_1_name) && 
		    (not $this_nodes_1_ip) && 
		    (not $this_nodes_1_port) && 
		    (not $this_nodes_2_name) && 
		    (not $this_nodes_2_ip) && 
		    (not $this_nodes_2_port))
		{
			# If this isn't 'new', delete this Anvil! from the config.
			$an->Log->entry({log_level => 2, message_key => "log_0002", file => $THIS_FILE, line => __LINE__});
			if ($this_id ne "new")
			{
				# The Anvil! has been deleted. Call 'striker-anvil-delete --anvil <name>'
				# locally and on the peer, if accessible. This handles removing the Anvil!
				# from ssh_config, hosts and the VMM 'connections/%gconf.xml' files as well
				# as remove it from striker.conf.
				my $anvil_name = $an->data->{cluster}{$this_id}{name};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "anvil_name", value1 => $anvil_name,
				}, file => $THIS_FILE, line => __LINE__});
				
				# Delete it locally
				my $shell_call = $an->data->{path}{'call_striker-delete-anvil'}." --anvil $anvil_name";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Calling", value1 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
				while(<$file_handle>)
				{
					chomp;
					my $line = $_;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				close $file_handle;
				
				### Delete it on the peer, if one exists and if it is up.
				# Get a list of peer(s). This returns an array of
				my $peers = $an->Get->striker_peers();
				foreach my $hash (@{$peers})
				{
					next if not $hash;
					my $peer_name     = $hash->{name};
					my $peer_password = $hash->{password};
					$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
						name1 => "peer_name",     value1 => $peer_name,
						name2 => "peer_password", value2 => $peer_password,
					}, file => $THIS_FILE, line => __LINE__});
					
					my $shell_call = $an->data->{path}{'striker-delete-anvil'}." --anvil $anvil_name";
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "shell_call", value1 => $shell_call,
						name2 => "peer_name",  value2 => $peer_name,
					}, file => $THIS_FILE, line => __LINE__});
					my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
						target		=>	$peer_name,
						port		=>	22, 
						password	=>	$peer_password,
						ssh_fh		=>	"",
						'close'		=>	0,
						shell_call	=>	$shell_call,
					});
					foreach my $line (@{$return})
					{
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				# Set 'save' to '2' to tell the caller we deleted the Anvil!.
				$save = 2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "save", value1 => $save,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Not sure why a user is trying to save an empty Anvil!...
				$save = 0;
				print $an->Web->template({file => "config.html", template => "form-value-warning", replace => {
					row	=>	"#!string!row_0004!#",
					message	=>	"#!string!message_0004!#",
				}});
			}
		}
		else
		{
			# Something is defined, make sure it's sane.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "this_name",         value1 => $this_name,
				name2 => "this_nodes_1_name", value2 => $this_nodes_1_name,
				name3 => "this_nodes_2_name", value3 => $this_nodes_2_name,
			}, file => $THIS_FILE, line => __LINE__});
			if ((not $this_name) || (not $this_nodes_1_name) || (not $this_nodes_2_name))
			{
				$save = 0;
				# The second hash passes in the variables for
				# the 'message' string.
				print $an->Web->template({file => "config.html", template => "form-value-warning", replace => {
					row	=>	"#!string!row_0004!#",
					message	=>	$an->String->get({key => "message_0005", variables => { id => $this_id }}),
				}});
			}
			else
			{
				# The minimum information is present, now make sure the set values are sane.
				# IPs sane?
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_nodes_1_ip", value1 => $this_nodes_1_ip,
				}, file => $THIS_FILE, line => __LINE__});
				if (($this_nodes_1_ip) && ($this_nodes_1_ip !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/))
				{
					$save = 0;
					print $an->Web->template({file => "config.html", template => "form-value-warning", replace => {
						row	=>	"#!string!row_0008!#",
						message	=>	$an->String->get({key => "message_0006", variables => { name => $this_name, node => $this_nodes_1_name }}),
					}});
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_nodes_2_ip", value1 => $this_nodes_2_ip,
				}, file => $THIS_FILE, line => __LINE__});
				if (($this_nodes_2_ip) && ($this_nodes_2_ip !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/))
				{
					$save = 0;
					print $an->Web->template({file => "config.html", template => "form-value-warning", replace => {
						row	=>	"#!string!row_0009!#",
						message	=>	$an->String->get({key => "message_0006", variables => { name => $this_name, node => $this_nodes_2_name }}),
					}});
				}
				# Ports sane?
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_nodes_1_port", value1 => $this_nodes_1_port,
				}, file => $THIS_FILE, line => __LINE__});
				if (($this_nodes_1_port) && (($this_nodes_1_port =~ /\D/) || ($this_nodes_1_port < 1) || ($this_nodes_1_port > 65535)))
				{
					$save = 0;
					print $an->Web->template({file => "config.html", template => "form-value-warning", replace => {
						row	=>	"#!string!row_0010!#",
						message	=>	$an->String->get({key => "message_0007", variables => { name => $this_name, node => $this_nodes_1_name }}),
					}});
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_nodes_2_port", value1 => $this_nodes_2_port,
				}, file => $THIS_FILE, line => __LINE__});
				if (($this_nodes_2_port) && (($this_nodes_2_port =~ /\D/) || ($this_nodes_2_port < 1) || ($this_nodes_2_port > 65535)))
				{
					$save = 0;
					print $an->Web->template({file => "config.html", template => "form-value-warning", replace => {
						row	=>	"#!string!row_0011!#",
						message	=>	$an->String->get({key => "message_0007", variables => { name => $this_name, node => $this_nodes_2_name }}),
					}});
				}
				# If there is an IP or Port, but no node name, well that's just not good.
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "this_nodes_1_name", value1 => $this_nodes_1_name,
					name2 => "this_nodes_1_ip",   value2 => $this_nodes_1_ip,
					name3 => "this_nodes_1_port", value3 => $this_nodes_1_port,
				}, file => $THIS_FILE, line => __LINE__});
				if ((not $this_nodes_1_name) && (($this_nodes_1_ip) || ($this_nodes_1_port)))
				{
					$save = 0;
					print $an->Web->template({file => "config.html", template => "form-value-warning", replace => {
						row	=>	"#!string!row_0012!#",
						message	=>	$an->String->get({key => "message_0008", variables => { name => $this_name }}),
					}});
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "this_nodes_2_name", value1 => $this_nodes_2_name,
					name2 => "this_nodes_2_ip",   value2 => $this_nodes_2_ip,
					name3 => "this_nodes_2_port", value3 => $this_nodes_2_port,
				}, file => $THIS_FILE, line => __LINE__});
				if ((not $this_nodes_2_name) && (($this_nodes_2_ip) || ($this_nodes_2_port)))
				{
					$save = 0;
					print $an->Web->template({file => "config.html", template => "form-value-warning", replace => {
						row	=>	"#!string!row_0012!#",
						message	=>	$an->String->get({key => "message_0009", variables => { name => $this_name }}),
					}});
				}
			}
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "save", value1 => $save,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now Sanity check the global (or Anvil! override) values.
	print $an->Web->template({file => "config.html", template => "sanity-check-global-header"});
	
	# Make sure email addresses are.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::$smtp__username_key", value1 => $an->data->{cgi}{$smtp__username_key},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{cgi}{$smtp__username_key}) && ($an->data->{cgi}{$smtp__username_key} ne "#!inherit!#") && ($an->data->{cgi}{$smtp__username_key} !~ /^\w[\w\.\-]*\w\@\w[\w\.\-]*\w(\.\w+)$/))
	{
		   $save        = 0;
		my $say_message = $an->String->get({key => "message_0011", variables => { email => $an->data->{cgi}{$smtp__username_key} }});
		print $an->Web->template({file => "config.html", template => "form-value-warning", replace => { 
			row	=>	"#!string!row_0014!#",
			message	=>	$say_message,
		}});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::$mail_data__to_key", value1 => $an->data->{cgi}{$mail_data__to_key},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{cgi}{$mail_data__to_key}) && ($an->data->{cgi}{$mail_data__to_key} ne "#!inherit!#"))
	{
		foreach my $email (split /,/, $an->data->{cgi}{$mail_data__to_key})
		{
			next if not $email;
			if ($email !~ /^\w[\w\.\-]*\w\@\w[\w\.\-]*\w(\.\w+)$/)
			{
				   $save        = 0;
				my $say_message = $an->String->get({key => "message_0011", variables => { email => $email }});
				print $an->Web->template({file => "config.html", template => "form-value-warning", replace => { 
					row	=>	"#!string!row_0015!#",
					message	=>	$say_message,
				}});
			}
		}
	}
	
	# Make sure values that should be numerical are.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::$smtp__port_key",   value1 => $an->data->{cgi}{$smtp__port_key},
		name2 => "cgi::$smtp__server_key", value2 => $an->data->{cgi}{$smtp__server_key},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{cgi}{$smtp__port_key}) && ($an->data->{cgi}{$smtp__port_key} ne "#!inherit!#"))
	{
		$an->data->{cgi}{$smtp__port_key} =~ s/,//;
		if (($an->data->{cgi}{$smtp__port_key} =~ /\D/) || ($an->data->{cgi}{$smtp__port_key} < 1) || ($an->data->{cgi}{$smtp__port_key} > 65535))
		{
			$save = 0;
			print $an->Web->template({file => "config.html", template => "form-value-warning", replace => { 
				row	=>	"#!string!row_0016!#",
				message	=>	"#!string!message_0012!#",
			}});
		}
	}
	elsif (($an->data->{cgi}{$smtp__server_key}) && ($an->data->{cgi}{$smtp__server_key} ne "#!inherit!#"))
	{
		   $save        = 0;
		my $say_row     = $an->String->get({key => "row_0016"});
		my $say_message = $an->String->get({key => "message_0013"});
		print $an->Web->template({file => "config.html", template => "form-value-warning", replace => { 
			row	=>	"#!string!row_0016!#",
			message	=>	"#!string!message_0013!#",
		}});
	}

	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "save",          value1 => $save,
		name2 => "cgi::anvil_id", value2 => $an->data->{cgi}{anvil_id},
	}, file => $THIS_FILE, line => __LINE__});
	if ($save)
	{
		# If 'anvil_id' is set, then we're editing an Anvil! (new or existing) instead of the global
		# section.
		if ($save eq "2")
		{
			# The Anvil! was deleted, no more sanity checks needed.
			$an->Log->entry({log_level => 2, message_key => "log_0003", file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{cgi}{anvil_id})
		{
			# Find a free ID after populating the keys above because they're going to come in 
			# from CGI as '...__new__...'.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "this_id", value1 => $this_id,
			}, file => $THIS_FILE, line => __LINE__});
			if ($this_id eq "new")
			{
				# Find the next free ID number.
				my $free_id = 1;
				foreach my $existing_id (sort {$a cmp $b} keys %{$an->data->{cluster}})
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "free_id",     value1 => $free_id,
						name2 => "existing_id", value2 => $existing_id,
					}, file => $THIS_FILE, line => __LINE__});
					if ($existing_id eq $free_id)
					{
						# ID used.
						$free_id++;
						$an->Log->entry({log_level => 3, message_key => "log_0004", file => $THIS_FILE, line => __LINE__});
						next;
					}
					else
					{
						# Got a free one.
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "free; free_id", value1 => $free_id,
						}, file => $THIS_FILE, line => __LINE__});
						last;
					}
				}
				$this_id = $free_id;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_id", value1 => $this_id,
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# If I'm still alive, push the passed in keys into $an->data->{cluster}... so that they 
			# get written out in the next step.
			$an->data->{cluster}{$this_id}{name}        = $an->data->{cgi}{$name_key};
			$an->data->{cluster}{$this_id}{description} = $an->data->{cgi}{$description_key};
			$an->data->{cluster}{$this_id}{url}         = $an->data->{cgi}{$url_key};
			$an->data->{cluster}{$this_id}{company}     = $an->data->{cgi}{$company_key};
			$an->data->{cluster}{$this_id}{ricci_pw}    = $an->data->{cgi}{$ricci_pw_key};
			$an->data->{cluster}{$this_id}{root_pw}     = $an->data->{cgi}{$root_pw_key};
			$an->data->{cluster}{$this_id}{nodes}       = $an->data->{cgi}{$nodes_1_name_key}.", ".$an->data->{cgi}{$nodes_2_name_key};
			
			# Record overrides, if any.
			$an->data->{cluster}{$this_id}{smtp}{server}              = $an->data->{cgi}{$smtp__server_key};
			$an->data->{cluster}{$this_id}{smtp}{port}                = $an->data->{cgi}{$smtp__port_key};
			$an->data->{cluster}{$this_id}{smtp}{username}            = $an->data->{cgi}{$smtp__username_key};
			$an->data->{cluster}{$this_id}{smtp}{password}            = $an->data->{cgi}{$smtp__password_key};
			$an->data->{cluster}{$this_id}{smtp}{security}            = $an->data->{cgi}{$smtp__security_key};
			$an->data->{cluster}{$this_id}{smtp}{encrypt_pass}        = $an->data->{cgi}{$smtp__encrypt_pass_key};
			$an->data->{cluster}{$this_id}{smtp}{helo_domain}         = $an->data->{cgi}{$smtp__helo_domain_key};
			$an->data->{cluster}{$this_id}{mail_data}{to}             = $an->data->{cgi}{$mail_data__to_key};
			$an->data->{cluster}{$this_id}{mail_data}{sending_domain} = $an->data->{cgi}{$mail_data__sending_domain_key};
			
			# Record hosts
			$an->data->{hosts}{$this_nodes_1_name}{ip} = $this_nodes_1_ip;
			$an->data->{hosts}{$this_nodes_2_name}{ip} = $this_nodes_2_ip;
			
			# Create empty arrays, if needed.
			$an->data->{hosts}{by_ip}{$this_nodes_1_ip} = [] if not $an->data->{hosts}{by_ip}{$this_nodes_1_ip};
			$an->data->{hosts}{by_ip}{$this_nodes_2_ip} = [] if not $an->data->{hosts}{by_ip}{$this_nodes_2_ip};
			push @{$an->data->{hosts}{by_ip}{$this_nodes_1_ip}}, $this_nodes_1_name;
			push @{$an->data->{hosts}{by_ip}{$this_nodes_2_ip}}, $this_nodes_2_name;
			
			# Search in 'hosts' and 'ssh_config' for previous entries with these names and delete
			# them if found.
			foreach my $this_ip (sort {$a cmp $b} keys %{$an->data->{hosts}{by_ip}})
			{
				my $say_node_1 = $an->data->{cgi}{$nodes_1_name_key};
				my $say_node_2 = $an->data->{cgi}{$nodes_2_name_key};
				if ($this_ip ne $this_nodes_1_ip)
				{
					delete_string_from_array($an, $say_node_1, $an->data->{hosts}{by_ip}{$this_ip});
				}
				if ($this_ip ne $this_nodes_2_ip)
				{
					delete_string_from_array($an, $say_node_2, $an->data->{hosts}{by_ip}{$this_ip});
				}
			}
			foreach my $this_host (sort {$a cmp $b} keys %{$an->data->{hosts}})
			{
				if ($this_host eq $an->data->{cgi}{$nodes_1_name_key})
				{
					$an->data->{hosts}{$this_host}{port} = $this_nodes_1_port ? $this_nodes_1_port : "";
				}
				if ($this_host eq $an->data->{cgi}{$nodes_2_name_key})
				{
					$an->data->{hosts}{$this_host}{port} = $this_nodes_2_port ? $this_nodes_2_port : "";
				}
			}
		}
		else
		{
			# Modifying global, copy CGI to main variables.
			$an->data->{smtp}{server}              = $an->data->{cgi}{smtp__server};
			$an->data->{smtp}{port}                = $an->data->{cgi}{smtp__port};
			$an->data->{smtp}{username}            = $an->data->{cgi}{smtp__username};
			$an->data->{smtp}{password}            = $an->data->{cgi}{smtp__password};
			$an->data->{smtp}{security}            = $an->data->{cgi}{smtp__security};
			$an->data->{smtp}{encrypt_pass}        = $an->data->{cgi}{smtp__encrypt_pass};
			$an->data->{smtp}{helo_domain}         = $an->data->{cgi}{smtp__helo_domain};
			$an->data->{mail_data}{to}             = $an->data->{cgi}{mail_data__to};
			$an->data->{mail_data}{sending_domain} = $an->data->{cgi}{mail_data__sending_domain};
		}
	}

	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "save", value1 => $save,
	}, file => $THIS_FILE, line => __LINE__});
	return ($save);
}

# This deletes an entry from an array by blanking it's value if it's existing
# value matches the string passed in.
sub delete_string_from_array
{
	my ($an, $string, $array) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "delete_string_from_array" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Delete the nodes (empty values are skipped later)
	for (my $i = 0; $i < @{$array}; $i++)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "i",      value1 => $i,
			name2 => "value",  value2 => $array->[$i],
			name3 => "string", value3 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		if ($array->[$i] eq $string)
		{
			$an->Log->entry({log_level => 3, message_key => "log_0005", file => $THIS_FILE, line => __LINE__});
			$array->[$i] = "";
		}
	}
	
	return($array);
}

# This writes out the new striker.conf file.
sub write_new_striker_conf
{
	my ($an, $say_date) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "write_new_striker_conf" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "say_date", value1 => $say_date, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Tell the user where ready to go.
	print $an->Web->template({file => "config.html", template => "general-row-good", replace => { 
		row	=>	"#!string!row_0018!#",
		message	=>	"#!string!message_0015!#",
	}});
	
	# Tweak some values, if needed
	if (not $an->data->{cgi}{anvil_id})
	{
		# If the sending domain or helo domain are  'example.com', make them the short version of the
		# sending email, if defined, or else the smtp server.
		if ($an->data->{cgi}{mail_data__sending_domain} eq "example.com")
		{
			if ($an->data->{cgi}{smtp__username} =~ /.*?\@(.*)/)
			{
				$an->data->{cgi}{mail_data__sending_domain} = $1;
			}
			else
			{
				$an->data->{cgi}{mail_data__sending_domain} =  $an->data->{cgi}{smtp__server};
				$an->data->{cgi}{mail_data__sending_domain} =~ s/^.*?\.(.*?\..*?)$/$1/;
			}
		}
		if ($an->data->{cgi}{smtp__helo_domain} eq "example.com")
		{
			if ($an->data->{cgi}{smtp__username} =~ /.*?\@(.*)/)
			{
				$an->data->{cgi}{smtp__helo_domain} = $1;
			}
			else
			{
				$an->data->{cgi}{smtp__helo_domain} =  $an->data->{cgi}{smtp__server};
				$an->data->{cgi}{smtp__helo_domain} =~ s/^.*?\.(.*?\..*?)$/$1/;
			}
		}
	}
	
	# Read in the existing config file.
	my $new_config = "";
	if (-e $an->data->{path}{config_file})
	{
		my $anvil_id   = $an->data->{cgi}{anvil_id};
		my $shell_call = $an->data->{path}{config_file};
		open (my $file_handle, "<$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
		binmode $file_handle, ":utf8:";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			
			# We don't want to munge the config any more than necessary as the user may have 
			# customizations we don't want to clobber.
			if (($line =~ /^#/) || ($line =~ /^\s+#/))
			{
				# This just makes sure we don't parse commented out example variable=value 
				# pairs.
			}
			elsif ($line =~ /(.*?)=(.*)$/)
			{
				# Looks like a variable. Even if it's not though, that should be OK because 
				# we won't alter any variables we're not explicitely checking for.
				my $variable = $1;
				my $value    = $2;
				
				# Strip white spaces
				$variable =~ s/^\s+//;
				$variable =~ s/\s+$//;
				$value    =~ s/^\s+//;
				$value    =~ s/\s+$//;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "variable", value1 => $variable,
					name2 => "value",    value2 => $value,
				}, file => $THIS_FILE, line => __LINE__});
				
				# We're setting certain values. If this variable matches on of the ones we're
				# setting, overwrite the current value. Otherwise, leave it as-is.
				
				if (($variable eq "smtp::encrypt_pass")        && ($an->data->{cgi}{smtp__encrypt_pass}))        { $line =~ s/=.*$/=\t$an->data->{cgi}{smtp__encrypt_pass}/; }
				if (($variable eq "smtp::helo_domain")         && ($an->data->{cgi}{smtp__helo_domain}))         { $line =~ s/=.*$/=\t$an->data->{cgi}{smtp__helo_domain}/; }
				if (($variable eq "smtp::password")            && ($an->data->{cgi}{smtp__password}))            { $line =~ s/=.*$/=\t$an->data->{cgi}{smtp__password}/; }
				if (($variable eq "smtp::port")                && ($an->data->{cgi}{smtp__port}))                { $line =~ s/=.*$/=\t$an->data->{cgi}{smtp__port}/; }
				if (($variable eq "smtp::security")            && ($an->data->{cgi}{smtp__security}))            { $line =~ s/=.*$/=\t$an->data->{cgi}{smtp__security}/; }
				if (($variable eq "smtp::server")              && ($an->data->{cgi}{smtp__server}))              { $line =~ s/=.*$/=\t$an->data->{cgi}{smtp__server}/; }
				if (($variable eq "smtp::username")            && ($an->data->{cgi}{smtp__username}))            { $line =~ s/=.*$/=\t$an->data->{cgi}{smtp__username}/; }
				if (($variable eq "mail_data::to")             && ($an->data->{cgi}{mail_data__to}))             { $line =~ s/=.*$/=\t$an->data->{cgi}{mail_data__to}/; }
				if (($variable eq "mail_data::sending_domain") && ($an->data->{cgi}{mail_data__sending_domain})) { $line =~ s/=.*$/=\t$an->data->{cgi}{mail_data__sending_domain}/; }
				
				# If I am saving a new or edited Anvil! definition, check to see if it 
				# already exists in the config file. If so, edit it in place. If the Anvil!
				# is not seen, it will be appended at the end.
				if (($anvil_id) && ($anvil_id ne "new"))
				{
					$an->data->{seen_anvil}{$anvil_id} = 1;
					my $company_key     = "cluster__${anvil_id}__company";
					my $description_key = "cluster__${anvil_id}__description";
					my $name_key        = "cluster__${anvil_id}__name";
					my $ricci_pw_key    = "cluster__${anvil_id}__ricci_pw";
					my $root_pw_key     = "cluster__${anvil_id}__root_pw";
					my $url_key         = "cluster__${anvil_id}__url";
					
					# Nodes
					my $node1_name_key  = "cluster__${anvil_id}__nodes_1_name";
					my $node1_ip_key    = "cluster__${anvil_id}__nodes_1_ip";
					my $node1_port_key  = "cluster__${anvil_id}__nodes_1_port";
					my $node2_name_key  = "cluster__${anvil_id}__nodes_2_name";
					my $node2_ip_key    = "cluster__${anvil_id}__nodes_2_ip";
					my $node2_port_key  = "cluster__${anvil_id}__nodes_2_port";
					# Mail stuff
					my $smtp_server_key              = "cluster__${anvil_id}__smtp__server";
					my $smtp_port_key                = "cluster__${anvil_id}__smtp__port";
					my $smtp_username_key            = "cluster__${anvil_id}__smtp__username";
					my $smtp_password_key            = "cluster__${anvil_id}__smtp__password";
					my $smtp_security_key            = "cluster__${anvil_id}__smtp__security";
					my $smtp_encrypt_pass_key        = "cluster__${anvil_id}__smtp__encrypt_pass";
					my $smtp_helo_domain_key         = "cluster__${anvil_id}__smtp__helo_domain";
					my $mail_data_to_key             = "cluster__${anvil_id}__mail_data__to";
					my $mail_data_sending_domain_key = "cluster__${anvil_id}__mail_data__sending_domain";
					
					# If the anvil has been deleted, simply skip this line.
					next if ((not $an->data->{cgi}{$name_key}) && ($line =~ /cluster::$anvil_id::/));
					
					# Anvil! details
					if ($variable eq "cluster::${anvil_id}::company")     { $line =~ s/=.*$/=\t$an->data->{cgi}{$company_key}/; }
					if ($variable eq "cluster::${anvil_id}::description") { $line =~ s/=.*$/=\t$an->data->{cgi}{$description_key}/; }
					if ($variable eq "cluster::${anvil_id}::name")        { $line =~ s/=.*$/=\t$an->data->{cgi}{$name_key}/; }
					if ($variable eq "cluster::${anvil_id}::nodes")       { $line =~ s/=.*$/=\t$an->data->{cgi}{$node1_name_key}, $an->data->{cgi}{$node2_name_key}/; }
					if ($variable eq "cluster::${anvil_id}::ricci_pw")    { $line =~ s/=.*$/=\t$an->data->{cgi}{$ricci_pw_key}/; }
					if ($variable eq "cluster::${anvil_id}::root_pw")     { $line =~ s/=.*$/=\t$an->data->{cgi}{$root_pw_key}/; }
					if ($variable eq "cluster::${anvil_id}::url")         { $line =~ s/=.*$/=\t$an->data->{cgi}{$url_key}/; }
					
					# Mail variables
					if ($variable eq "cluster::${anvil_id}::smtp::server")              { $line =~ s/=.*$/=\t$an->data->{cgi}{$smtp_server_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::port")                { $line =~ s/=.*$/=\t$an->data->{cgi}{$smtp_port_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::username")            { $line =~ s/=.*$/=\t$an->data->{cgi}{$smtp_username_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::password")            { $line =~ s/=.*$/=\t$an->data->{cgi}{$smtp_password_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::security")            { $line =~ s/=.*$/=\t$an->data->{cgi}{$smtp_security_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::encrypt_pass")        { $line =~ s/=.*$/=\t$an->data->{cgi}{$smtp_encrypt_pass_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::helo_domain")         { $line =~ s/=.*$/=\t$an->data->{cgi}{$smtp_helo_domain_key}/; }
					if ($variable eq "cluster::${anvil_id}::mail_data::to")             { $line =~ s/=.*$/=\t$an->data->{cgi}{$mail_data_to_key}/; }
					if ($variable eq "cluster::${anvil_id}::mail_data::sending_domain") { $line =~ s/=.*$/=\t$an->data->{cgi}{$mail_data_sending_domain_key}/; }
				}
			}
			$new_config .= "$line\n";
		}
		close $file_handle;
		
		### TODO: Look for and remove comments for now-deleted Anvil!
		###       systems.
		# If a new Anvil! has been created, add it.
		# Now print the individual Anvil!s 
		foreach my $this_id (sort {$a cmp $b} keys %{$an->data->{cluster}})
		{
			next if not $this_id;
			next if not $an->data->{cluster}{$this_id}{name};
			next if $an->data->{seen_anvil}{$this_id};
			
			# If I am still here, this is an unrecorded Anvil!.
			$new_config .= generate_anvil_entry_for_striker_conf($an, $this_id);
		}
	}
	else
	{
		# No existing config, write it new.
		my $say_date_header =  $an->String->get({key => "text_0003", variables => { date => $say_date }});
		my $say_text        =  $an->String->get({key => "text_0001"});
		   $new_config      .= "$say_date_header\n";
		   $new_config      .= "$say_text\n";
		
		# The user doesn't currently set the 'smtp::helo_domain' or 
		# 'mail_data::sending_domain', so for now we'll devine it from the user's 
		# 'smtp::username'.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "smtp::helo_domain",         value1 => $an->data->{smtp}{helo_domain},
			name2 => "mail_data::sending_domain", value2 => $an->data->{mail_data}{sending_domain},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{smtp}{helo_domain} eq "example.com")
		{
			my $domain = ($an->data->{smtp}{username} =~ /.*@(.*)$/)[0];
			$an->data->{smtp}{helo_domain} = $domain if $domain;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "smtp::helo_domain", value1 => $an->data->{smtp}{helo_domain},
				name2 => "domain",            value2 => $domain,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($an->data->{mail_data}{sending_domain} eq "example.com")
		{
			my $domain = ($an->data->{smtp}{username} =~ /.*@(.*)$/)[0];
			$an->data->{mail_data}{sending_domain} = $domain if $domain;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "mail_data::sending_domain", value1 => $an->data->{mail_data}{sending_domain},
				name2 => "domain",                    value2 => $domain,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Write out the global values.
		my $say_body = $an->String->get({key => "text_0002", variables => {
			smtp__server			=>	$an->data->{smtp}{server},
			smtp__port			=>	$an->data->{smtp}{port},
			smtp__username			=>	$an->data->{smtp}{username},
			smtp__password			=>	$an->data->{smtp}{password},
			smtp__security			=>	$an->data->{smtp}{security},
			smtp__encrypt_pass		=>	$an->data->{smtp}{encrypt_pass},
			smtp__helo_domain		=>	$an->data->{smtp}{helo_domain},
			mail_data__to			=>	$an->data->{mail_data}{to},
			mail_data__sending_domain	=>	$an->data->{mail_data}{sending_domain},
		}});
		$new_config .= $say_body;
		
		# Now print the individual Anvil!s 
		foreach my $this_id (sort {$a cmp $b} keys %{$an->data->{cluster}})
		{
			next if not $this_id;
			next if not $an->data->{cluster}{$this_id}{name};
			
			my ($new_anvil_data) = generate_anvil_entry_for_striker_conf($an, $this_id);
		}
	}
	
	# Save the file.
	my $shell_call = $an->data->{path}{config_file};
	#my $shell_call = "/tmp/striker.conf";
	open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write: [$shell_call], error was: $!\n";
	binmode $file_handle, ":utf8:";
	print $file_handle $new_config;
	close $file_handle;
	
	return(0);
}

# This generates the raw text entry lines for an Anvil! that can be added to
# striker.conf.
sub generate_anvil_entry_for_striker_conf
{
	my ($an, $this_id) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "generate_anvil_entry_for_striker_conf" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "this_id", value1 => $this_id, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $data = "";
	# Main Anvil! values, always recorded, even when blank.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cluster::${this_id}::nodes", value1 => $an->data->{cluster}{$this_id}{nodes},
	}, file => $THIS_FILE, line => __LINE__});
	$data .= "\n# ".$an->data->{cluster}{$this_id}{company}." - ".$an->data->{cluster}{$this_id}{description}."\n";
	$data .= "cluster::${this_id}::company\t\t\t=\t".$an->data->{cluster}{$this_id}{company}."\n";
	$data .= "cluster::${this_id}::description\t\t\t=\t".$an->data->{cluster}{$this_id}{description}."\n";
	$data .= "cluster::${this_id}::name\t\t\t=\t".$an->data->{cluster}{$this_id}{name}."\n";
	$data .= "cluster::${this_id}::nodes\t\t\t=\t".$an->data->{cluster}{$this_id}{nodes}."\n";
	$data .= "cluster::${this_id}::ricci_pw\t\t\t=\t".$an->data->{cluster}{$this_id}{ricci_pw}."\n";
	$data .= "cluster::${this_id}::root_pw\t\t\t=\t".$an->data->{cluster}{$this_id}{root_pw}."\n";
	$data .= "cluster::${this_id}::url\t\t\t\t=\t".$an->data->{cluster}{$this_id}{url}."\n";
	
	# Set any undefined values to '#!inherit!#'
	$an->data->{cluster}{$this_id}{smtp}{server}              = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{smtp}{server};
	$an->data->{cluster}{$this_id}{smtp}{port}                = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{smtp}{port};
	$an->data->{cluster}{$this_id}{smtp}{username}            = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{smtp}{username};
	$an->data->{cluster}{$this_id}{smtp}{password}            = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{smtp}{password};
	$an->data->{cluster}{$this_id}{smtp}{security}            = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{smtp}{security};
	$an->data->{cluster}{$this_id}{smtp}{encrypt_pass}        = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{smtp}{encrypt_pass};
	$an->data->{cluster}{$this_id}{smtp}{helo_domain}         = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{smtp}{helo_domain};
	$an->data->{cluster}{$this_id}{mail_data}{to}             = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{mail_data}{to};
	$an->data->{cluster}{$this_id}{mail_data}{sending_domain} = "#!inherit!#" if not exists $an->data->{cluster}{$this_id}{mail_data}{sending_domain};
	
	# Record this Anvil!'s overrides (or that it doesn't override,
	# as the case may be).
	$data .= "cluster::${this_id}::smtp::server\t\t=\t".$an->data->{cluster}{$this_id}{smtp}{server}."\n";
	$data .= "cluster::${this_id}::smtp::port\t\t\t=\t".$an->data->{cluster}{$this_id}{smtp}{port}."\n";
	$data .= "cluster::${this_id}::smtp::username\t\t=\t".$an->data->{cluster}{$this_id}{smtp}{username}."\n";
	$data .= "cluster::${this_id}::smtp::password\t\t=\t".$an->data->{cluster}{$this_id}{smtp}{password}."\n";
	$data .= "cluster::${this_id}::smtp::security\t\t=\t".$an->data->{cluster}{$this_id}{smtp}{security}."\n";
	$data .= "cluster::${this_id}::smtp::encrypt_pass\t\t=\t".$an->data->{cluster}{$this_id}{smtp}{encrypt_pass}."\n";
	$data .= "cluster::${this_id}::smtp::helo_domain\t\t=\t".$an->data->{cluster}{$this_id}{smtp}{helo_domain}."\n";
	$data .= "cluster::${this_id}::mail_data::to\t\t=\t".$an->data->{cluster}{$this_id}{mail_data}{to}."\n";
	$data .= "cluster::${this_id}::mail_data::sending_domain\t=\t".$an->data->{cluster}{$this_id}{mail_data}{sending_domain}."\n";
	$data .= "\n";
	
	return($data);
}

# This copies a file from one place to another.
sub copy_file
{
	my ($an, $source, $destination) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "copy_file" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "source",      value1 => $source, 
		name2 => "destination", value2 => $destination, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $output     = "";
	my $shell_call = $an->data->{path}{cp}." -f $source $destination; ".$an->data->{path}{sync};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "Calling", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$output .= "$line\n";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
	}
	close $file_handle;
	
	if (not -e $destination)
	{
		$output =~ s/\n$//;
		my $say_message = $an->String->get({key => "message_0016", variables => {
			file		=>	$source,
			destination	=>	$destination,
			output		=>	$output,
		}});
		error($an, $say_message, 1);
	}
	
	return(0);
}

sub write_new_ssh_config
{
	my ($an, $say_date) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "write_new_ssh_config" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "say_date", value1 => $say_date, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{ssh_config};
	open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write to: [$shell_call], error was: $!\n";
	
	my $say_date_header = $an->String->get({key => "text_0003", variables => { date => $say_date }});
	print $file_handle "$say_date_header\n";
	
	# Re print the ssh_config, but skip 'Host' sections for now.
	my $last_line_was_blank = 0;
	foreach my $line (@{$an->data->{raw}{ssh_config}})
	{
		$say_date_header =~ s/\[.*?\]/\[\]/;
		next if $line =~ /$say_date_header/;
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "ssh_config line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		last if ($line =~ /^Host\s+(.*)$/);
		last if ($line =~ /^###############/);
		# This cleans out multiple blank spaces which seem to creep in.
		if (not $line)
		{
			if ($last_line_was_blank)
			{
				next;
			}
			else
			{
				$last_line_was_blank = 1;
			}
		}
		else
		{
			$last_line_was_blank = 0;
		}
		print $file_handle "$line\n";
	}
	
	# Print the header box that separates the main config from our 'Host ...' entries.
	my $say_host_header = $an->String->get({key => "text_0004"});
	print $file_handle "\n$say_host_header\n\n";
	
	# Now add any new entries.
	foreach my $this_host (sort {$a cmp $b} keys %{$an->data->{hosts}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "this_host", value1 => $this_host,
			name2 => "port",      value2 => $an->data->{hosts}{$this_host}{port},
		}, file => $THIS_FILE, line => __LINE__});
		next if not $an->data->{hosts}{$this_host}{port};
		print $file_handle "Host $this_host\n";
		print $file_handle "\tPort ".$an->data->{hosts}{$this_host}{port}."\n\n";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "this_hostline",             value1 => $this_host,
			name2 => "hosts::${this_host}::port", value2 => $an->data->{hosts}{$this_host}{port},
		}, file => $THIS_FILE, line => __LINE__});
	}
	close $file_handle;

	return(0);
}

# Write out the new 'hosts' file. This is simple and doesn't preserve comments
# or formatting. It will preserve non-node related IPs.
sub write_new_hosts
{
	my ($an, $say_date) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "write_new_hosts" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "say_date", value1 => $say_date, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Open the file
	my $shell_call = $an->data->{path}{hosts};
	#my $shell_call = "/tmp/hosts";
	open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write to: [$shell_call], error was: $!\n";
	
	my $say_date_header = $an->String->get({key => "text_0003", variables => { date => $say_date }});
	my $say_host_header = $an->String->get({key => "text_0005"});
	print $file_handle "$say_date_header\n";
	print $file_handle "$say_host_header\n";
	
	# Print 127.0.0.1 first to keep things cleaner.
	my $hosts      = "";
	my $seen_hosts = {};
	my $this_ip    = "127.0.0.1";
	foreach my $this_host (sort {$a cmp $b} @{$an->data->{hosts}{by_ip}{$this_ip}})
	{
		# Avoid dupes
		next if $seen_hosts->{$this_ip}{$this_host};
		$seen_hosts->{$this_ip}{$this_host} = 1;
		$hosts .= "$this_host ";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "hosts", value1 => $hosts,
		}, file => $THIS_FILE, line => __LINE__});
	}
	   $hosts =~ s/ $//;
	my $line  =  "$this_ip\t$hosts";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "line", value1 => $line,
	}, file => $THIS_FILE, line => __LINE__});
	print $file_handle "$line\n";
	delete $an->data->{hosts}{by_ip}{"127.0.0.1"};
	
	# Push the IPs into an array for sorting.
	my @ip;
	foreach my $this_ip (sort {$a cmp $b} keys %{$an->data->{hosts}{by_ip}})
	{
		push @ip, $this_ip;
	}
	
	# Sort (from gryng's post here: http://www.perlmonks.org/?node=Sorting%20IP%20Addresses%20Quickly)
	my @sorted_ip = map  { $_->[0] }
	                sort { $a->[1] <=> $b->[1] }
	                map  { my ($x, $y) = (0, $_);
	                       $x = $_ + $x * 256 for split(/\./, $y);
	                       [$y,$x]
	                     } @ip;
	
	# Cycle through the passed variables and add them to the hashed created
	# when the hosts file was last read.
	my $last_start_octals = "";
	foreach my $this_ip (@sorted_ip)
	{
		# There can be one or more hosts for a given IP, contained in
		# an array
		my $hosts      = "";
		my $seen_hosts = {};
		my $host_count = 0;
		foreach my $this_host (sort {$a cmp $b} @{$an->data->{hosts}{by_ip}{$this_ip}})
		{
			# Avoid dupes
			next if $seen_hosts->{$this_ip}{$this_host};
			$seen_hosts->{$this_ip}{$this_host} = 1;
			$hosts .= "$this_host ";
			$host_count++ if $this_host;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "host_count", value1 => $host_count,
				name2 => "hosts",      value2 => $hosts,
			}, file => $THIS_FILE, line => __LINE__});
		}
		$hosts =~ s/ $//;
		
		# Skip IPs with no remaining hosts.
		next if not $host_count;
		
		# Add a space if the first three octals have changed.
		my $start_octals = ($this_ip =~ /^(\d+\.\d+\.\d+)\./)[0];
		if ($start_octals ne $last_start_octals)
		{
			$last_start_octals = $start_octals;
			print $file_handle "\n";
		}
		
		my $line  =  "$this_ip\t$hosts";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		print $file_handle "$line\n";
	}
	close $file_handle;
	
	return(0);
}

# Verify and then save the global dashboard configuration.
sub save_dashboard_configure
{
	my ($an) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "save_dashboard_configure" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($save) = sanity_check_striker_conf($an, $an->data->{cgi}{section});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "save", value1 => $save,
	}, file => $THIS_FILE, line => __LINE__});
	if ($save eq "1")
	{
		# Get the current date and time.
		my ($say_date) =  $an->Get->date_and_time({split_date_time => 0});
		my $date       =  $say_date;
		   $date       =~ s/ /_/g;
		   $date       =~ s/:/-/g;
		   $say_date   =~ s/ /, /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "say_date", value1 => $say_date,
			name2 => "date",     value2 => $date,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Write out the new config file.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "path::config_file",                        value1 => $an->data->{path}{config_file},
			name2 => "path::home::/archive/striker.conf.\$date", value2 => $an->data->{path}{home}."/archive/striker.conf.$date",
		}, file => $THIS_FILE, line => __LINE__});
		copy_file($an, $an->data->{path}{config_file}, $an->data->{path}{home}."/archive/striker.conf.$date");
		write_new_striker_conf($an, $say_date);
		
		# Write out the 'hosts' file.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "path::hosts",                     value1 => $an->data->{path}{hosts},
			name2 => "path::home/archive/hosts.\$date", value2 => $an->data->{path}{home}."/archive/hosts.$date",
		}, file => $THIS_FILE, line => __LINE__});
		copy_file($an, $an->data->{path}{hosts}, $an->data->{path}{home}."/archive/hosts.$date");
		write_new_hosts($an, $say_date);
		
		# Write out the 'ssh_config' file.
		copy_file($an, $an->data->{path}{ssh_config}, $an->data->{path}{home}."/archive/ssh_config.$date");
		write_new_ssh_config($an, $say_date);
		
		# Setup some variables...
		my $anvil_id       = $an->data->{cgi}{anvil_id};
		my $anvil_name_key = "cluster__${anvil_id}__name";
		my $anvil_name     = $an->data->{cgi}{$anvil_name_key};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "anvil_id",       value1 => $anvil_id,
			name2 => "anvil_name_key", value2 => $anvil_name_key,
			name3 => "anvil_name",     value3 => $anvil_name,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Configure SSH and Virtual Machine Manager (if configured).
		configure_ssh_local($an, $anvil_name);
		configure_vmm_local($an);
		
		# Sync with our peer. If 'peer' is empty, the sync didn't run. If it's set to '#!error!#',
		# then something went wrong. Otherwise the peer's hostname is returned.
		my $peer = sync_with_peer($an);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "peer", value1 => $peer,
		}, file => $THIS_FILE, line => __LINE__});
		if (($peer) && ($peer ne "#!error!#"))
		{
			# Tell the user
			my $message  = $an->String->get({key => "message_0449", variables => { peer => $peer }});
			print $an->Web->template({file => "config.html", template => "general-row-good", replace => { 
				row	=>	"#!string!row_0292!#",
				message	=>	$message,
			}});
		}
		
		# Which message to show will depend on whether we're saving an Anvil! or the global config. 
		# The 'message_0017' provides a link to the user's Anvil!, which is non-existent when saving
		# global values.
		my $message = $an->String->get({key => "message_0377"});
		if ($anvil_name)
		{
			$message = $an->String->get({key => "message_0017", variables => { url => "?cluster=$anvil_name" }});
		}
		print $an->Web->template({file => "config.html", template => "general-row-good", replace => { 
			row	=>	"#!string!row_0019!#",
			message	=>	$message,
		}});
		print $an->Web->template({file => "config.html", template => "close-table"});
		footer($an);
		exit(0);
	}
	elsif ($save eq "2")
	{
		# The Anvil! was deleted by 'striker-delete-anvil'.
		my $message = $an->String->get({key => "message_0451", variables => { anvil => $an->data->{cgi}{anvil} }});
		print $an->Web->template({file => "config.html", template => "general-row-good", replace => { 
			row	=>	"#!string!row_0019!#",
			message	=>	$message,
		}});
		print $an->Web->template({file => "config.html", template => "close-table"});
		footer($an);
		exit(0);
	}
	else
	{
		# Problem
		print $an->Web->template({file => "config.html", template => "form-value-warning", replace => { 
			row	=>	"#!string!row_0020!#",
			message	=>	"#!string!message_0018!#",
		}});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::cluster__new__name", value1 => $an->data->{cgi}{cluster__new__name},
	}, file => $THIS_FILE, line => __LINE__});
	
	print $an->Web->template({file => "config.html", template => "close-table"});

	return(0);
}

# This calls 'striker-merge-dashboards' and 'striker-configure-vmm' to sync with the peer and configure 
# Virtual Machine Manager.
sub sync_with_peer
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "sync_with_peer" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Return if this is disabled.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "tools::striker::auto-sync", value1 => $an->data->{tools}{striker}{'auto-sync'},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{tools}{striker}{'auto-sync'})
	{
		return("");
	}
	
	# Make sure I have a peer.
	my $db_count      =  0;
	my $local_id      =  "";
	my $peer_name     =  "";
	my $peer_password =  "";
	my $i_am_long     =  $an->hostname();
	my $i_am_short    =  $an->short_hostname();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "i_am_long",  value1 => $i_am_long,
		name2 => "i_am_short", value2 => $i_am_short,
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		$db_count++;
		my $this_host = $an->data->{scancore}{db}{$id}{host};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "id",        value1 => $id,
			name2 => "this_host", value2 => $this_host,
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($this_host eq $i_am_long) or ($this_host eq $i_am_short))
		{
			$local_id = $id;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "local_id", value1 => $local_id,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If there were too many peers, exit.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "db_count", value1 => $db_count,
	}, file => $THIS_FILE, line => __LINE__});
	if ($db_count ne "2")
	{
		# Wrong number of DBs
		$an->Log->entry({log_level => 1, message_key => "log_0006", message_variables => {
			db_count => $db_count,
		}, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "local_id", value1 => $local_id,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $local_id)
	{
		# Configured scancore hosts don't match local hostname
		$an->Log->entry({log_level => 1, message_key => "log_0007", message_variables => {
			i_am_long  => $i_am_long, 
			i_am_short => $i_am_short, 
		}, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Now I know who I am, find the peer.
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "id",              value1 => $id,
			name2 => "node::id::local", value2 => $an->data->{node}{id}{'local'},
		}, file => $THIS_FILE, line => __LINE__});
		if ($id ne $local_id)
		{
			$peer_name     = $an->data->{scancore}{db}{$id}{host};
			$peer_password = $an->data->{scancore}{db}{$id}{password};
			$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
				name1 => "peer_name",     value1 => $peer_name,
				name2 => "peer_password", value2 => $peer_password,
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
	}
	
	# Final check...
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "peer_name", value1 => $peer_name,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $peer_name)
	{
		# Unable to determine local host name.
		$an->Log->entry({log_level => 1, message_key => "log_0008", file => $THIS_FILE, line => __LINE__});
	}
	
	# Configure the local virtual machine manager, if it is installed.
	my $merge_striker_ok = 1;
	my $shell_call = $an->data->{path}{'call_striker-merge-dashboards'}." --force --prefer local; echo rc:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open(my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /rc:(\d+)/)
		{
			my $rc = $1;
			$merge_striker_ok = $rc eq "0" ? 1 : 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "rc",               value1 => $rc,
				name2 => "merge_striker_ok", value2 => $merge_striker_ok,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	close $file_handle;
	
	# Setup VMM on the peer.
	# Note: I don't worry about the fingerprint because it would have been setup by 
	#       'striker-merge-dashboards'.
	if ($peer_password)
	{
		# Both of these will exit on their own if needed, so we can blindly call them.
		my $say_anvil  = $an->data->{cgi}{anvil} ? $an->data->{cgi}{anvil} : $an->data->{cgi}{cluster};
		my $shell_call = "
".$an->data->{path}{'striker-push-ssh'}." --anvil $say_anvil
".$an->data->{path}{'striker-configure-vmm'}."
";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "peer_name",  value2 => $peer_name,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$peer_name,
			port		=>	22, 
			password	=>	$peer_password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If either program errors, change the host name to '#!error!#'.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "merge_striker_ok", value1 => $merge_striker_ok,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $merge_striker_ok)
	{
		$peer_name = "#!error!#";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "peer_name", value1 => $peer_name,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "peer_name", value1 => $peer_name,
	}, file => $THIS_FILE, line => __LINE__});
	return($peer_name);
}

# This prepares and displays the header section of an Anvil! configuration page.
sub show_anvil_config_header
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_anvil_config_header" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $this_cluster          = $an->data->{cgi}{anvil};
	my $say_this_cluster      = $this_cluster;
	my $this_id               = defined $an->data->{clusters}{$this_cluster}{id}               ? $an->data->{clusters}{$this_cluster}{id}               : "new";
	my $clear_icon            = $an->Web->template({file => "config.html", template => "image_with_js", replace => { 
			image_source	=>	$an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/icon_clear-fields_16x16.png",
			javascript	=>	"onclick=\"\$('#cluster__${this_id}__name, #cluster__${this_id}__description, #cluster__${this_id}__company, #cluster__${this_id}__ricci_pw, #cluster__${this_id}__root_pw, #cluster__${this_id}__url, #cluster__${this_id}__nodes_1_name, #cluster__${this_id}__nodes_1_ip, #cluster__${this_id}__nodes_1_port, #cluster__${this_id}__nodes_2_name, #cluster__${this_id}__nodes_2_ip, #cluster__${this_id}__nodes_2_port').val('')\"",
			alt_text	=>	"",
			id		=>	"clear",
		}});
	my $this_name             = defined $an->data->{clusters}{$this_cluster}{name}             ? $an->data->{clusters}{$this_cluster}{name}             : "";
	my $this_company          = defined $an->data->{clusters}{$this_cluster}{company}          ? $an->data->{clusters}{$this_cluster}{company}          : "";
	   $this_company          = convert_text_to_html($an, $this_company);
	my $this_description      = defined $an->data->{clusters}{$this_cluster}{description}      ? $an->data->{clusters}{$this_cluster}{description}      : "";
	   $this_description      = convert_text_to_html($an, $this_description);
	my $this_url              = defined $an->data->{clusters}{$this_cluster}{url}              ? $an->data->{clusters}{$this_cluster}{url}              : "";
	my $this_ricci_pw         = defined $an->data->{clusters}{$this_cluster}{ricci_pw}         ? $an->data->{clusters}{$this_cluster}{ricci_pw}         : "";
	my $this_root_pw          = defined $an->data->{clusters}{$this_cluster}{root_pw}          ? $an->data->{clusters}{$this_cluster}{root_pw}          : "";
	my $this_nodes_1_name     = defined $an->data->{clusters}{$this_cluster}{nodes}[0]         ? $an->data->{clusters}{$this_cluster}{nodes}[0]         : "";
	my $this_nodes_1_ip       = defined $an->data->{hosts}{$this_nodes_1_name}{ip}             ? $an->data->{hosts}{$this_nodes_1_name}{ip}             : "";
	my $this_nodes_1_port     = defined $an->data->{hosts}{$this_nodes_1_name}{port}           ? $an->data->{hosts}{$this_nodes_1_name}{port}           : "";
	my $this_nodes_2_name     = defined $an->data->{clusters}{$this_cluster}{nodes}[1]         ? $an->data->{clusters}{$this_cluster}{nodes}[1]         : "";
	my $this_nodes_2_ip       = defined $an->data->{hosts}{$this_nodes_2_name}{ip}             ? $an->data->{hosts}{$this_nodes_2_name}{ip}             : "";
	my $this_nodes_2_port     = defined $an->data->{hosts}{$this_nodes_2_name}{port}           ? $an->data->{hosts}{$this_nodes_2_name}{port}           : "";
	my $this_node_1_ipmi_name = defined $an->data->{clusters}{$this_cluster}{node_1_ipmi_name} ? $an->data->{clusters}{$this_cluster}{node_1_ipmi_name} : "";
	my $this_node_1_ipmi_ip   = defined $an->data->{hosts}{$this_node_1_ipmi_name}{ip}         ? $an->data->{hosts}{$this_node_1_ipmi_name}{ip}         : "";
	my $this_node_2_ipmi_name = defined $an->data->{clusters}{$this_cluster}{node_2_ipmi_name} ? $an->data->{clusters}{$this_cluster}{node_2_ipmi_name} : "";
	my $this_node_2_ipmi_ip   = defined $an->data->{hosts}{$this_node_2_ipmi_name}{ip}         ? $an->data->{hosts}{$this_node_2_ipmi_name}{ip}         : "";
	
	# If this is the first time loading the config, pre-populate the values
	# for the overrides with the data from the config file.
	if (not $an->data->{cgi}{save})
	{
		my $smtp__server_key              = "cluster__${this_id}__smtp__server";
		my $smtp__port_key                = "cluster__${this_id}__smtp__port";
		my $smtp__username_key            = "cluster__${this_id}__smtp__username";
		my $smtp__password_key            = "cluster__${this_id}__smtp__password";
		my $smtp__security_key            = "cluster__${this_id}__smtp__security";
		my $smtp__encrypt_pass_key        = "cluster__${this_id}__smtp__encrypt_pass";
		my $smtp__helo_domain_key         = "cluster__${this_id}__smtp__helo_domain";
		my $mail_data__to_key             = "cluster__${this_id}__mail_data__to";
		my $mail_data__sending_domain_key = "cluster__${this_id}__mail_data__sending_domain";
		$an->data->{cgi}{$smtp__server_key}              = defined $an->data->{cluster}{$this_id}{smtp}{server}              ? $an->data->{cluster}{$this_id}{smtp}{server}              : "#!inherit!#";
		$an->data->{cgi}{$smtp__port_key}                = defined $an->data->{cluster}{$this_id}{smtp}{port}                ? $an->data->{cluster}{$this_id}{smtp}{port}                : "#!inherit!#";
		$an->data->{cgi}{$smtp__username_key}            = defined $an->data->{cluster}{$this_id}{smtp}{username}            ? $an->data->{cluster}{$this_id}{smtp}{username}            : "#!inherit!#";
		$an->data->{cgi}{$smtp__password_key}            = defined $an->data->{cluster}{$this_id}{smtp}{password}            ? $an->data->{cluster}{$this_id}{smtp}{password}            : "#!inherit!#";
		$an->data->{cgi}{$smtp__security_key}            = defined $an->data->{cluster}{$this_id}{smtp}{security}            ? $an->data->{cluster}{$this_id}{smtp}{security}            : "#!inherit!#";
		$an->data->{cgi}{$smtp__encrypt_pass_key}        = defined $an->data->{cluster}{$this_id}{smtp}{encrypt_pass}        ? $an->data->{cluster}{$this_id}{smtp}{encrypt_pass}        : "#!inherit!#";
		$an->data->{cgi}{$smtp__helo_domain_key}         = defined $an->data->{cluster}{$this_id}{smtp}{helo_domain}         ? $an->data->{cluster}{$this_id}{smtp}{helo_domain}         : "#!inherit!#";
		$an->data->{cgi}{$mail_data__to_key}             = defined $an->data->{cluster}{$this_id}{mail_data}{to}             ? $an->data->{cluster}{$this_id}{mail_data}{to}             : "#!inherit!#";
		$an->data->{cgi}{$mail_data__sending_domain_key} = defined $an->data->{cluster}{$this_id}{mail_data}{sending_domain} ? $an->data->{cluster}{$this_id}{mail_data}{sending_domain} : "#!inherit!#";
		$an->Log->entry({log_level => 4, message_key => "an_variables_0009", message_variables => {
			name1 => "cgi::$smtp__server_key",              value1 => $an->data->{cgi}{$smtp__server_key},
			name2 => "cgi::$smtp__port_key",                value2 => $an->data->{cgi}{$smtp__port_key},
			name3 => "cgi::$smtp__username_key",            value3 => $an->data->{cgi}{$smtp__username_key},
			name4 => "cgi::$smtp__password_key",            value4 => $an->data->{cgi}{$smtp__password_key},
			name5 => "cgi::$smtp__security_key",            value5 => $an->data->{cgi}{$smtp__security_key},
			name6 => "cgi::$smtp__encrypt_pass_key",        value6 => $an->data->{cgi}{$smtp__encrypt_pass_key},
			name7 => "cgi::$smtp__helo_domain_key",         value7 => $an->data->{cgi}{$smtp__helo_domain_key},
			name8 => "cgi::$mail_data__to_key",             value8 => $an->data->{cgi}{$mail_data__to_key},
			name9 => "cgi::$mail_data__sending_domain_key", value9 => $an->data->{cgi}{$mail_data__sending_domain_key},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Show the right header.
	if ($this_cluster eq "new")
	{
		# New Anvil! If the user is finishing an Install Manifest run,
		# some values will be set.
		$say_this_cluster  = $an->data->{cgi}{cluster__new__name}         if $an->data->{cgi}{cluster__new__name};
		$this_description  = $an->data->{cgi}{cluster__new__description}  if $an->data->{cgi}{cluster__new__description};
		$this_url          = $an->data->{cgi}{cluster__new__url}          if $an->data->{cgi}{cluster__new__url};
		$this_company      = $an->data->{cgi}{cluster__new__company}      if $an->data->{cgi}{cluster__new__company};
		$this_ricci_pw     = $an->data->{cgi}{cluster__new__ricci_pw}     if $an->data->{cgi}{cluster__new__ricci_pw};
		$this_root_pw      = $an->data->{cgi}{cluster__new__root_pw}      if $an->data->{cgi}{cluster__new__root_pw};
		$this_nodes_1_name = $an->data->{cgi}{cluster__new__nodes_1_name} if $an->data->{cgi}{cluster__new__nodes_1_name};
		$this_nodes_2_name = $an->data->{cgi}{cluster__new__nodes_2_name} if $an->data->{cgi}{cluster__new__nodes_2_name};
		$this_nodes_1_ip   = $an->data->{cgi}{cluster__new__nodes_1_ip}   if $an->data->{cgi}{cluster__new__nodes_1_ip};
		$this_nodes_2_ip   = $an->data->{cgi}{cluster__new__nodes_2_ip}   if $an->data->{cgi}{cluster__new__nodes_2_ip};
		$this_nodes_1_port = $an->data->{cgi}{cluster__new__nodes_1_port} if $an->data->{cgi}{cluster__new__nodes_1_port};
		$this_nodes_2_port = $an->data->{cgi}{cluster__new__nodes_2_port} if $an->data->{cgi}{cluster__new__nodes_2_port};
		$clear_icon        = "";
		print $an->Web->template({file => "config.html", template => "config-header", replace => { 
			title_1	=>	"#!string!title_0003!#",
			title_2	=>	"#!string!title_0004!#",
		}});
	}
	else
	{
		# Existing Anvil!
		print $an->Web->template({file => "config.html", template => "config-header", replace => { 
			title_1	=>	"#!string!title_0005!#",
			title_2	=>	"#!string!title_0006!#",
		}});
	}
	
	# Print the body of the global/overrides section.
	print $an->Web->template({file => "config.html", template => "anvil-variables", replace => { 
		anvil_id			=>	$this_id,
		anvil				=>	$an->data->{cgi}{anvil},
		clear_icon			=>	"$clear_icon",
		cluster_name_name		=>	"cluster__${this_id}__name",
		cluster_name_id			=>	"cluster__${this_id}__name",
		cluster_name_value		=>	"$say_this_cluster",
		cluster_description_name	=>	"cluster__${this_id}__description",
		cluster_description_id		=>	"cluster__${this_id}__description",
		cluster_description_value	=>	"$this_description",
		cluster_url_name		=>	"cluster__${this_id}__url",
		cluster_url_id			=>	"cluster__${this_id}__url",
		cluster_url_value		=>	"$this_url",
		cluster_company_name		=>	"cluster__${this_id}__company",
		cluster_company_id		=>	"cluster__${this_id}__company",
		cluster_company_value		=>	"$this_company",
		cluster_ricci_pw_name		=>	"cluster__${this_id}__ricci_pw",
		cluster_ricci_pw_id		=>	"cluster__${this_id}__ricci_pw",
		cluster_ricci_pw_value		=>	"$this_ricci_pw",
		cluster_root_pw_name		=>	"cluster__${this_id}__root_pw",
		cluster_root_pw_id		=>	"cluster__${this_id}__root_pw",
		cluster_root_pw_value		=>	"$this_root_pw",
		cluster_nodes_1_name_name	=>	"cluster__${this_id}__nodes_1_name",
		cluster_nodes_1_name_id		=>	"cluster__${this_id}__nodes_1_name",
		cluster_nodes_1_name_value	=>	"$this_nodes_1_name",
		cluster_nodes_2_name_name	=>	"cluster__${this_id}__nodes_2_name",
		cluster_nodes_2_name_id		=>	"cluster__${this_id}__nodes_2_name",
		cluster_nodes_2_name_value	=>	"$this_nodes_2_name",
		cluster_nodes_1_ip_name		=>	"cluster__${this_id}__nodes_1_ip",
		cluster_nodes_1_ip_id		=>	"cluster__${this_id}__nodes_1_ip",
		cluster_nodes_1_ip_value	=>	"$this_nodes_1_ip",
		cluster_nodes_2_ip_name		=>	"cluster__${this_id}__nodes_2_ip",
		cluster_nodes_2_ip_id		=>	"cluster__${this_id}__nodes_2_ip",
		cluster_nodes_2_ip_value	=>	"$this_nodes_2_ip",
		cluster_nodes_1_port_name	=>	"cluster__${this_id}__nodes_1_port",
		cluster_nodes_1_port_id		=>	"cluster__${this_id}__nodes_1_port",
		cluster_nodes_1_port_value	=>	"$this_nodes_1_port",
		cluster_nodes_2_port_name	=>	"cluster__${this_id}__nodes_2_port",
		cluster_nodes_2_port_id		=>	"cluster__${this_id}__nodes_2_port",
		cluster_nodes_2_port_value	=>	"$this_nodes_2_port",
	}});
	
	return(0);
}

# This shows the header of the global configuration section.
sub show_global_config_header
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_global_config_header" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	print $an->Web->template({file => "config.html", template => "config-header", replace => { 
		title_1	=>	"#!string!title_0011!#",
		title_2	=>	"#!string!title_0012!#",
	}});

	return(0);
}

# This shows all the mail settings that are common to both the global and per-anvil config sections.
sub show_common_config_section
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_common_config_section" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# We display the global values or the per-Anvil! ones below. Load the global, the override with the 
	# Anvil! if needed.
	my $smtp__server_key              = "smtp__server";
	my $smtp__port_key                = "smtp__port";
	my $smtp__username_key            = "smtp__username";
	my $smtp__password_key            = "smtp__password";
	my $smtp__security_key            = "smtp__security";
	my $smtp__encrypt_pass_key        = "smtp__encrypt_pass";
	my $smtp__helo_domain_key         = "smtp__helo_domain";
	my $mail_data__to_key             = "mail_data__to";
	my $mail_data__sending_domain_key = "mail_data__sending_domain";
	my $security_select_options       = [
		"None",
		"SSL/TLS",
		"STARTTLS"
	];
	my $encrypt_pass_select_options   = [
		"1#!#Yes",
		"0#!#No"
	];
	$an->Log->entry({log_level => 4, message_key => "an_variables_0009", message_variables => {
		name1 => "smtp__server_key",              value1 => $smtp__server_key,
		name2 => "smtp__port_key",                value2 => $smtp__port_key,
		name3 => "smtp__username_key",            value3 => $smtp__username_key,
		name4 => "smtp__password_key",            value4 => $smtp__password_key,
		name5 => "smtp__security_key",            value5 => $smtp__security_key,
		name6 => "smtp__encrypt_pass_key",        value6 => $smtp__encrypt_pass_key,
		name7 => "smtp__helo_domain_key",         value7 => $smtp__helo_domain_key,
		name8 => "mail_data__to_key",             value8 => $mail_data__to_key,
		name9 => "mail_data__sending_domain_key", value9 => $mail_data__sending_domain_key,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{cgi}{save})
	{
		# First time loading the config, so pre-populate the values
		# with the data from the config file.
		$an->data->{cgi}{smtp__server}              = defined $an->data->{smtp}{server}              ? $an->data->{smtp}{server}              : ""; 
		$an->data->{cgi}{smtp__port}                = defined $an->data->{smtp}{port}                ? $an->data->{smtp}{port}                : "";
		$an->data->{cgi}{smtp__username}            = defined $an->data->{smtp}{username}            ? $an->data->{smtp}{username}            : "";
		$an->data->{cgi}{smtp__password}            = defined $an->data->{smtp}{password}            ? $an->data->{smtp}{password}            : "";
		$an->data->{cgi}{smtp__security}            = defined $an->data->{smtp}{security}            ? $an->data->{smtp}{security}            : "";
		$an->data->{cgi}{smtp__encrypt_pass}        = defined $an->data->{smtp}{encrypt_pass}        ? $an->data->{smtp}{encrypt_pass}        : "";
		$an->data->{cgi}{smtp__helo_domain}         = defined $an->data->{smtp}{helo_domain}         ? $an->data->{smtp}{helo_domain}         : "";
		$an->data->{cgi}{mail_data__to}             = defined $an->data->{mail_data}{to}             ? $an->data->{mail_data}{to}             : "";
		$an->data->{cgi}{mail_data__sending_domain} = defined $an->data->{mail_data}{sending_domain} ? $an->data->{mail_data}{sending_domain} : "";
		$an->Log->entry({log_level => 4, message_key => "an_variables_0009", message_variables => {
			name1 => "cgi::smtp__server",              value1 => $an->data->{cgi}{smtp__server},
			name2 => "cgi::smtp__port",                value2 => $an->data->{cgi}{smtp__port},
			name3 => "cgi::smtp__username",            value3 => $an->data->{cgi}{smtp__username},
			name4 => "cgi::smtp__password",            value4 => $an->data->{cgi}{smtp__password},
			name5 => "cgi::smtp__security",            value5 => $an->data->{cgi}{smtp__security},
			name6 => "cgi::smtp__encrypt_pass",        value6 => $an->data->{cgi}{smtp__encrypt_pass},
			name7 => "cgi::smtp__helo_domain",         value7 => $an->data->{cgi}{smtp__helo_domain},
			name8 => "cgi::mail_data__to",             value8 => $an->data->{cgi}{mail_data__to},
			name9 => "cgi::mail_data__sending_domain", value9 => $an->data->{cgi}{mail_data__sending_domain},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Switch to the per-Anvil! values if an Anvil! is defined.
	my $this_cluster = "";
	my $this_id      = "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil", value1 => $an->data->{cgi}{anvil},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{anvil})
	{
		$this_cluster                  = $an->data->{cgi}{anvil};
		$this_id                       = defined $an->data->{clusters}{$this_cluster}{id} ? $an->data->{clusters}{$this_cluster}{id} : "new";
		$smtp__server_key              = "cluster__${this_id}__smtp__server";
		$smtp__port_key                = "cluster__${this_id}__smtp__port";
		$smtp__username_key            = "cluster__${this_id}__smtp__username";
		$smtp__password_key            = "cluster__${this_id}__smtp__password";
		$smtp__security_key            = "cluster__${this_id}__smtp__security";
		$smtp__encrypt_pass_key        = "cluster__${this_id}__smtp__encrypt_pass";
		$smtp__helo_domain_key         = "cluster__${this_id}__smtp__helo_domain";
		$mail_data__to_key             = "cluster__${this_id}__mail_data__to";
		$mail_data__sending_domain_key = "cluster__${this_id}__mail_data__sending_domain";
		$an->Log->entry({log_level => 4, message_key => "an_variables_0009", message_variables => {
			name1 => "smtp__server_key",              value1 => $smtp__server_key,
			name2 => "smtp__port_key",                value2 => $smtp__port_key,
			name3 => "smtp__username_key",            value3 => $smtp__username_key,
			name4 => "smtp__password_key",            value4 => $smtp__password_key,
			name5 => "smtp__security_key",            value5 => $smtp__security_key,
			name6 => "smtp__encrypt_pass_key",        value6 => $smtp__encrypt_pass_key,
			name7 => "smtp__helo_domain_key",         value7 => $smtp__helo_domain_key,
			name8 => "mail_data__to_key",             value8 => $mail_data__to_key,
			name9 => "mail_data__sending_domain_key", value9 => $mail_data__sending_domain_key,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Add the 'inherit' options.
		push @{$security_select_options},     "#!inherit!#";
		push @{$encrypt_pass_select_options}, "#!inherit!#";
	}
	
	my $say_smtp__server              = $an->data->{cgi}{$smtp__server_key}; 
	my $say_smtp__port                = $an->data->{cgi}{$smtp__port_key};
	my $say_smtp__username            = $an->data->{cgi}{$smtp__username_key};
	my $say_smtp__password            = $an->data->{cgi}{$smtp__password_key};
	my $say_smtp__security            = $an->data->{cgi}{$smtp__security_key};
	my $say_smtp__encrypt_pass        = $an->data->{cgi}{$smtp__encrypt_pass_key};
	my $say_smtp__helo_domain         = $an->data->{cgi}{$smtp__helo_domain_key};
	my $say_mail_data__to             = $an->data->{cgi}{$mail_data__to_key};
	my $say_mail_data__sending_domain = $an->data->{cgi}{$mail_data__sending_domain_key};
	$an->Log->entry({log_level => 4, message_key => "an_variables_0009", message_variables => {
		name1 => "say_smtp__server",              value1 => $say_smtp__server,
		name2 => "say_smtp__port",                value2 => $say_smtp__port,
		name3 => "say_smtp__username",            value3 => $say_smtp__username,
		name4 => "say_smtp__password",            value4 => $say_smtp__password,
		name5 => "say_smtp__security",            value5 => $say_smtp__security,
		name6 => "say_smtp__encrypt_pass",        value6 => $say_smtp__encrypt_pass,
		name7 => "say_smtp__helo_domain",         value7 => $say_smtp__helo_domain,
		name8 => "say_mail_data__to",             value8 => $say_mail_data__to,
		name9 => "say_mail_data__sending_domain", value9 => $say_mail_data__sending_domain,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Build the security and encrypt password select boxes.
	my $say_security_select     = build_select($an, "$smtp__security_key",     0, 0, 300, $an->data->{cgi}{$smtp__security_key},     $security_select_options);
	my $say_encrypt_pass_select = build_select($an, "$smtp__encrypt_pass_key", 0, 0, 300, $an->data->{cgi}{$smtp__encrypt_pass_key}, $encrypt_pass_select_options);
	$say_security_select     =~ s/<select name=/<select tabindex="18" name=/;
	$say_encrypt_pass_select =~ s/<select name=/<select tabindex="19" name=/;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "say_security_select", value1 => $say_security_select,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "say_encrypt_pass_select", value1 => $say_encrypt_pass_select,
	}, file => $THIS_FILE, line => __LINE__});
	# If both nodes are up, enable the 'Push' button.
	my $push_button = "";
	if (($an->data->{cgi}{anvil}) && ($an->data->{cgi}{anvil} ne "new"))
	{
		$push_button =  "&nbsp; ";
		$push_button .= $an->Web->template({file => "config.html", template => "enabled-button", replace => { 
				button_class	=>	"bold_button",
				button_link	=>	"?config=true&anvil=".$an->data->{cgi}{anvil}."&task=push",
				button_text	=>	"#!string!button_0039!#",
				id		=>	"push",
			}});
	}
	else
	{
		$push_button =  "&nbsp; ";
	}
	
	print $an->Web->template({file => "config.html", template => "global-variables", replace => { 
		anvil_id			=>	$this_id,
		smtp__server_name		=>	$smtp__server_key,
		smtp__server_id			=>	$smtp__server_key,
		smtp__server_value		=>	$an->data->{cgi}{$smtp__server_key},
		mail_data__sending_domain_name	=>	$mail_data__sending_domain_key,
		mail_data__sending_domain_id	=>	$mail_data__sending_domain_key,
		mail_data__sending_domain_value	=>	$an->data->{cgi}{$mail_data__sending_domain_key},
		smtp__helo_domain_name		=>	$smtp__helo_domain_key,
		smtp__helo_domain_id		=>	$smtp__helo_domain_key,
		smtp__helo_domain_value		=>	$an->data->{cgi}{$smtp__helo_domain_key},
		smtp__port_name			=>	$smtp__port_key,
		smtp__port_id			=>	$smtp__port_key,
		smtp__port_value		=>	$an->data->{cgi}{$smtp__port_key},
		smtp__username_name		=>	$smtp__username_key,
		smtp__username_id		=>	$smtp__username_key,
		smtp__username_value		=>	$an->data->{cgi}{$smtp__username_key},
		smtp__password_name		=>	$smtp__password_key,
		smtp__password_id		=>	$smtp__password_key,
		smtp__password_value		=>	$an->data->{cgi}{$smtp__password_key},
		security_select			=>	$say_security_select,
		encrypt_pass_select		=>	$say_encrypt_pass_select,
		mail_data__to_name		=>	$mail_data__to_key,
		mail_data__to_id		=>	$mail_data__to_key,
		mail_data__to_value		=>	$an->data->{cgi}{$mail_data__to_key},
		push_button			=>	$push_button,
	}});
	
	return(0);
}

# This displays a list of all Anvil!s for the global configuration page.
sub show_global_anvil_list
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_global_anvil_list" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	print $an->Web->template({file => "config.html", template => "config-header", replace => { 
		title_1	=>	"#!string!title_0009!#",
		title_2	=>	"#!string!title_0010!#",
	}});
	print $an->Web->template({file => "config.html", template => "anvil-column-header"});
	my $ids = "";
	foreach my $this_cluster ("new", (sort {$a cmp $b} keys %{$an->data->{clusters}}))
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "this_cluster",                   value1 => $this_cluster,
			name2 => "clusters:${this_cluster}::name", value2 => $an->data->{clusters}{$this_cluster}{name},
		}, file => $THIS_FILE, line => __LINE__});
		my $this_id           = defined $an->data->{clusters}{$this_cluster}{id}          ? $an->data->{clusters}{$this_cluster}{id}          : "new";
		my $this_company      = defined $an->data->{clusters}{$this_cluster}{company}     ? $an->data->{clusters}{$this_cluster}{company}     : "--";
		$this_company      = convert_text_to_html($an, $this_company);
		my $this_description  = defined $an->data->{clusters}{$this_cluster}{description} ? $an->data->{clusters}{$this_cluster}{description} : "--";
		$this_description  = convert_text_to_html($an, $this_description);
		my $this_url          = defined $an->data->{clusters}{$this_cluster}{url}         ? $an->data->{clusters}{$this_cluster}{url}         : "";
		if ($this_url)
		{
			my $image = $an->Web->template({file => "config.html", template => "image", replace => { 
					image_source	=>	$an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/anvil-url_16x16.png",
					alt_text	=>	"",
					id		=>	"url_icon",
				}});
			$this_url = $an->Web->template({file => "config.html", template => "enabled-button-no-class-new-tab", replace => { 
					button_link	=>	"$this_url",
					button_text	=>	"$image",
					id		=>	"url_$this_cluster",
				}});
		}
		
		print $an->Web->template({file => "config.html", template => "anvil-column-entry", replace => { 
			anvil		=>	$this_cluster,
			company		=>	$this_company,
			description	=>	$this_description,
			url		=>	$this_url,
		}});
	}

	print $an->Web->template({file => "config.html", template => "anvil-column-footer"});
	
	return(0);
}

# This checks to see if the Anvil! is online and, if both nodes are, pushes the config to the nods.
sub push_config_to_anvil
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "push_config_to_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil = $an->data->{cgi}{anvil};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil", value1 => $anvil,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure both nodes are up.
	$an->data->{cgi}{cluster}       = $an->data->{cgi}{anvil};
	$an->data->{sys}{root_password} = $an->data->{clusters}{$anvil}{root_pw};
	scan_cluster($an);
	
	my $up = @{$an->data->{up_nodes}};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "online nodes", value1 => $up,
	}, file => $THIS_FILE, line => __LINE__});
	if ($up == 0)
	{
		# Neither node is reachable or online.
		print $an->Web->template({file => "config.html", template => "can-not-push-config-no-access"});
	}
	elsif ($up == 1)
	{
		# Only one node online, don't update to prevent divergent configs.
		print $an->Web->template({file => "config.html", template => "can-not-push-config-only-one-node"});
	}
	else
	{
		# Push!
		my $config_file = $an->data->{path}{config_file};
		if (not -r $config_file)
		{
			die "Failed to read local: [$config_file]\n";
		}
		
		# We're going to want to backup each file before pushing the updates.
		my ($say_date) =  $an->Get->date_and_time({split_date_time => 0});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "say_date", value1 => $say_date,
		}, file => $THIS_FILE, line => __LINE__});
		my $date       =  $say_date;
		   $date       =~ s/ /_/g;
		   $date       =~ s/:/-/g;
		   $say_date   =~ s/ /, /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "say_date", value1 => $say_date,
			name2 => "date",     value2 => $date,
		}, file => $THIS_FILE, line => __LINE__});
		
		print $an->Web->template({file => "config.html", template => "open-push-table"});
		foreach my $node (@{$an->data->{up_nodes}})
		{
			my $message = $an->String->get({key => "message_0280", variables => { 
					node		=>	$node,
					source		=>	$config_file,
					destination	=>	"$config_file.$date",
				}});
			print $an->Web->template({file => "config.html", template => "open-push-entry", replace => { 
				row	=>	"#!string!row_0130!#",
				message	=>	"$message",
			}});
			
			# Make sure there is an '/etc/striker' directory on the node and create it, if not.
			my $striker_directory = ($an->data->{path}{config_file} =~ /^(.*)\/.*$/)[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "striker_directory", value1 => $striker_directory,
			}, file => $THIS_FILE, line => __LINE__});
			my $shell_call = "
if [ ! -e '$striker_directory' ]; 
then 
    mkdir -p $striker_directory;
    echo 'Create: [$striker_directory]';
fi;
ls $striker_directory";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
				password	=>	$an->data->{sys}{root_password},
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "line",        value1 => $line, 
					name2 => "config_file", value2 => $config_file, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($config_file =~ /$line$/)
				{
					$line = $an->String->get({key => "message_0283"});
					print $an->Web->template({file => "config.html", template => "shell-call-output", replace => { line => $line }});
				}
			}
			$error      = "";
			$return     = "";
			$shell_call = "";
			
			# Backup, but don't care if it fails.
			my $backup_file = "$config_file.$date";
			   $shell_call  = "
if [ -e \"$config_file\" ]; 
then 
    cp $config_file $backup_file; 
fi; 
ls $backup_file";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
				password	=>	$an->data->{sys}{root_password},
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "line",        value1 => $line, 
					name2 => "backup_file", value2 => $backup_file, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($backup_file =~ /$line$/)
				{
					$line = $an->String->get({key => "message_0284"});
				}
				if ($line =~ /No such file or directory/)
				{
					$line = $an->String->get({key => "message_0285"});
				}
				print $an->Web->template({file => "config.html", template => "shell-call-output", replace => { line => $line }});
			}
			
			print $an->Web->template({file => "config.html", template => "close-push-entry"});
			
			# Now push the actual config file.
			$message = $an->String->get({key => "message_0281", variables => { 
					node		=>	$node,
					config_file	=>	"$config_file",
				}});
			print $an->Web->template({file => "config.html", template => "open-push-entry", replace => { 
				row	=>	"#!string!row_0131!#",
				message	=>	"$message",
			}});
			$an->Storage->rsync({
				source		=>	$config_file,
				target		=>	$node,
				password	=>	$an->data->{sys}{root_password},
				destination	=>	"root\@$node:$config_file",
				switches	=>	$an->data->{args}{rsync},
			});
			print $an->Web->template({file => "config.html", template => "close-push-entry"});
		}
		print $an->Web->template({file => "config.html", template => "close-table"});
	}
	
	return(0);
}

# This offers an option for the user to either download the current config or upload a past backup.
sub show_archive_options
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_archive_options" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# First up, collect the config files and make them available for download.
	my $backup_url = create_backup_file($an);
	
	print $an->Web->template({file => "config.html", template => "archive-menu", replace => { form_file => "/cgi-bin/striker" }});
	
	return(0);
}

# This gathers up the config files into a single bzip2 file and returns a URL where the user can click to 
# download.
sub create_backup_file
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "create_backup_file" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $config_data =  "<!-- Striker Backup -->\n";
	   $config_data .= "<!-- Striker version $an->data->{sys}{version} -->\n";
	   $config_data .= "<!-- Backup created ".$an->Get->date_and_time({split_date_time => 0})." -->\n\n";
	
	# Get a list of install manifests on this machine.
	my @manifests;
	my $manifest_directory =  $an->data->{path}{apache_manifests_dir};
	   $manifest_directory =~ s/\/$//g;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "manifest_directory", value1 => $manifest_directory,
	}, file => $THIS_FILE, line => __LINE__});
	local(*DIRECTORY);
	opendir(DIRECTORY, $manifest_directory);
	while(my $file = readdir(DIRECTORY))
	{
		next if $file eq ".";
		next if $file eq "..";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "file", value1 => $file,
		}, file => $THIS_FILE, line => __LINE__});
		if ($file =~ /^install-manifest_(.*?).xml$/)
		{
			my $full_path = "$manifest_directory/$file";
			push @manifests, $full_path;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "full_path", value1 => $full_path,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	   
	# Read the three config files and write them out to a file.
	foreach my $file ($an->data->{path}{config_file}, $an->data->{path}{hosts}, $an->data->{path}{ssh_config}, @manifests)
	{
		# Read in /etc/striker/striker.conf.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "reading", value1 => $file,
		}, file => $THIS_FILE, line => __LINE__});
		$config_data .= "<!-- start $file -->\n";
		my $shell_call = "$file";
		open (my $file_handle, "<:encoding(UTF-8)", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
		while (<$file_handle>)
		{
			$config_data .= $_;
		}
		close $file_handle;
		$config_data .= "<!-- end $file -->\n\n";
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "config_data", value1 => $config_data,
	}, file => $THIS_FILE, line => __LINE__});

	# Modify the backup file and URL file names to insert this dashboard's hostname.
	my $date                        =  $an->Get->date_and_time({split_date_time => 0, no_spaces => 1});
	my $backup_file                 =  $an->data->{path}{backup_config};
	my $hostname                    =  $an->hostname();
	   $backup_file                 =~ s/#!hostname!#/$hostname/;
	   $backup_file                 =~ s/#!date!#/$date/;
	   $an->data->{sys}{backup_url} =~ s/#!hostname!#/$hostname/;
	   $an->data->{sys}{backup_url} =~ s/#!date!#/$date/;
	
	# Now write out the file.
	my $shell_call = "$backup_file";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "Writing", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, ">", $shell_call) or die "Failed to write: [$shell_call], the error was: $!\n";
	print $file_handle $config_data;
	close $file_handle;
	
	return(0);
}

# This checks the user's uploaded file and, if it is a valid backup file, uses it's data to overwrite the 
# existing config files.
sub load_backup_configuration
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "load_backup_configuration" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This file handle will contain the uploaded file, so be careful.
	my $in_fh = $an->data->{cgi_fh}{file};
	
	# Some variables.
	my $file         = "";
	my $striker_conf = "";
	my $hosts        = "";
	my $ssh_config   = "";
	my $valid        = 0;
	
	### NOTE: If this fails, we want to re-display the archive page.
	# If the file handle is empty, nothing was uploaded.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "in_fh",              value1 => $in_fh,
		name2 => "cgi_mimetype::file", value2 => $an->data->{cgi_mimetype}{file},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $in_fh)
	{
		print $an->Web->template({file => "config.html", template => "no-backup-file-uploaded"});
		show_archive_options($an);
		return(1);
	}
	elsif ($an->data->{cgi_mimetype}{file} ne "text/plain")
	{
		my $message1 = $an->String->get({key => "explain_0039", variables => { file => $an->data->{cgi}{file} }});
		my $message2 = $an->String->get({key => "explain_0040", variables => { mimetype => $an->data->{cgi_mimetype}{file} }});
		print $an->Web->template({file => "config.html", template => "backup-file-bad-mimetype", replace => { 
			message1	=>	$message1,
			message2	=>	$message2,
		}});
		show_archive_options($an);
		return(1);
	}
	else
	{
		# Parse the incoming file.
		while (<$in_fh>)
		{
			chomp;
			my $line = $_;
			# If the first line of the file isn't 
			# '<!-- Striker Backup -->', do not proceed.
			if ($line =~ /<!-- Striker Backup -->/)
			{
				# Looks like a valid file.
				$valid = 1;
			}
			elsif (not $valid)
			{
				# Not a valid backup file.
				my $explain = $an->String->get({key => "explain_0039", variables => { file => $an->data->{cgi}{file} }});
				print $an->Web->template({file => "config.html", template => "invalid-backup-file-uploaded", replace => { replace => $explain }});
				show_archive_options($an);
				return(1);
			}
			else
			{
				# Where in a valid file.
				if ($line =~ /<!-- end (.*?) -->/)
				{
					$file = "";
					next;
				}
				if ($line =~ /<!-- start (.*?) -->/)
				{
					$file = $1;
					if ($file =~ /install-manifest/)
					{
						$an->data->{install_manifest}{$file}{config} = "";
					}
					next;
				}
				if ($file eq $an->data->{path}{config_file})
				{
					$striker_conf .= "$line\n";
				}
				elsif ($file eq $an->data->{path}{hosts})
				{
					$hosts .= "$line\n";
				}
				elsif ($file eq $an->data->{path}{ssh_config})
				{
					$ssh_config .= "$line\n";
				}
				elsif ($file =~ /install-manifest/)
				{
					$an->data->{install_manifest}{$file}{config} .= "$line\n";
				}
				elsif ($file)
				{
					# Unknown file...
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "Unknown file", value1 => $file,
						name2 => "line",         value2 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "striker_conf", value1 => $striker_conf,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "hosts", value1 => $hosts,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ssh_config", value1 => $ssh_config,
	}, file => $THIS_FILE, line => __LINE__});
	if (($striker_conf) && ($hosts) && ($ssh_config))
	{
		### TODO: examine the contents of each file to ensure it looks sane.
		# Looks good, write them out.
		open (my $an_fh, ">", $an->data->{path}{config_file}) or die "$THIS_FILE ".__LINE__."; Can't write to: [".$an->data->{path}{config_file}."], error: $!\n";
		print $an_fh $striker_conf;
		close $an_fh;
		
		open (my $hosts_fh, ">", $an->data->{path}{hosts}) or die "$THIS_FILE ".__LINE__."; Can't write to: [".$an->data->{path}{hosts}."], error: $!\n";
		print $hosts_fh $hosts;
		close $hosts_fh;
		
		open (my $ssh_fh, ">", $an->data->{path}{ssh_config}) or die "$THIS_FILE ".__LINE__."; Can't write to: [".$an->data->{path}{ssh_config}."], error: $!\n";
		print $ssh_fh $ssh_config;
		close $ssh_fh;
		
		# Load any manifests.
		foreach my $file (sort {$a cmp $b} keys %{$an->data->{install_manifest}})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "writing manifest file", value1 => $file,
			}, file => $THIS_FILE, line => __LINE__});
			open (my $manifest_fh, ">", "$file") or die "$THIS_FILE ".__LINE__."; Can't write to: [$file], error: $!\n";
			print $manifest_fh $an->data->{install_manifest}{$file}{config};
			close $manifest_fh;
		}
		
		# Sync with our peer. If 'peer' is empty, the sync didn't run. If it's set to '#!error!#',
		# then something went wrong. Otherwise the peer's hostname is returned.
		my $peer = sync_with_peer($an);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "peer", value1 => $peer,
		}, file => $THIS_FILE, line => __LINE__});
		if (($peer) && ($peer ne "#!error!#"))
		{
			# Tell the user
			my $message = $an->String->get({key => "message_0449", variables => { peer => $peer }});
			print $an->Web->template({file => "config.html", template => "general-table-row-good", replace => { 
				row	=>	"#!string!row_0292!#",
				message	=>	$message,
			}});
		}
		
		# Configure SSH for each configured Anvil! and setup Virtual Machine Manager.
		$an->Storage->read_conf({file => $an->data->{path}{striker_config}});
		foreach my $id (sort {$a cmp $b} keys %{$an->data->{cluster}})
		{
			my $anvil_name = $an->data->{cluster}{$id}{name};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "id",         value1 => $id,
				name2 => "anvil_name", value2 => $anvil_name,
			}, file => $THIS_FILE, line => __LINE__});
			configure_ssh_local($an, $anvil_name);
		}
		configure_vmm_local($an);
		
		print $an->Web->template({file => "config.html", template => "backup-file-loaded"});
		footer($an);
		exit;
	}
	
	return(0);
}

# This calls 'striker-push-ssh'
sub configure_ssh_local
{
	my ($an, $anvil_name) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_ssh_local" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "anvil_name", value1 => $anvil_name, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Add the user's SSH keys to the new anvil! (will simply exit if disabled in striker.conf).
	my $shell_call = $an->data->{path}{'call_striker-push-ssh'}." --anvil $anvil_name";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "Calling", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
	}
	close $file_handle;
	
	return(0);
}

# This calls 'call_striker-configure-vmm'
sub configure_vmm_local
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_vmm_local" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: I don't currently check if this passes or not.
	# Setup VMM locally (the script exits without doing anything if disabled or if virt-manager is not 
	# installed).
	my $shell_call = $an->data->{path}{'call_striker-configure-vmm'};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open(my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
	}
	close $file_handle;
	
	return(0);
}

# This presents a form for the user to complete. When complete, an XML file
# with the install information for new nodes is created.
sub create_install_manifest
{
	my ($an) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "create_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $show_form = 1;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::do", value1 => $an->data->{cgi}{'do'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->data->{form}{anvil_prefix_star}                   = "";
	$an->data->{form}{anvil_sequence_star}                 = "";
	$an->data->{form}{anvil_domain_star}                   = "";
	$an->data->{form}{anvil_name_star}                     = "";
	$an->data->{form}{anvil_password_star}                 = "";
	$an->data->{form}{anvil_bcn_ethtool_opts_star}         = "";
	$an->data->{form}{anvil_bcn_network_star}              = "";
	$an->data->{form}{anvil_sn_ethtool_opts_star}          = "";
	$an->data->{form}{anvil_sn_network_star}               = "";
	$an->data->{form}{anvil_ifn_ethtool_opts_star}         = "";
	$an->data->{form}{anvil_ifn_network_star}              = "";
	$an->data->{form}{anvil_ifn_gateway_star}              = "";
	$an->data->{form}{anvil_dns1_star}                     = "";
	$an->data->{form}{anvil_dns2_star}                     = "";
	$an->data->{form}{anvil_ntp1_star}                     = "";
	$an->data->{form}{anvil_ntp2_star}                     = "";
	$an->data->{form}{anvil_switch1_name_star}             = "";
	$an->data->{form}{anvil_switch1_ip_star}               = "";
	$an->data->{form}{anvil_switch2_name_star}             = "";
	$an->data->{form}{anvil_switch2_ip_star}               = "";
	$an->data->{form}{anvil_pdu1_name_star}                = "";
	$an->data->{form}{anvil_pdu1_ip_star}                  = "";
	$an->data->{form}{anvil_pdu1_agent_star}               = "";
	$an->data->{form}{anvil_pdu2_name_star}                = "";
	$an->data->{form}{anvil_pdu2_ip_star}                  = "";
	$an->data->{form}{anvil_pdu2_agent_star}               = "";
	$an->data->{form}{anvil_pdu3_name_star}                = "";
	$an->data->{form}{anvil_pdu3_ip_star}                  = "";
	$an->data->{form}{anvil_pdu3_agent_star}               = "";
	$an->data->{form}{anvil_pdu4_name_star}                = "";
	$an->data->{form}{anvil_pdu4_ip_star}                  = "";
	$an->data->{form}{anvil_pdu4_agent_star}               = "";
	$an->data->{form}{anvil_ups1_name_star}                = "";
	$an->data->{form}{anvil_ups1_ip_star}                  = "";
	$an->data->{form}{anvil_ups2_name_star}                = "";
	$an->data->{form}{anvil_ups2_ip_star}                  = "";
	$an->data->{form}{anvil_pts1_name_star}                = "";
	$an->data->{form}{anvil_pts1_ip_star}                  = "";
	$an->data->{form}{anvil_pts2_name_star}                = "";
	$an->data->{form}{anvil_pts2_ip_star}                  = "";
	$an->data->{form}{anvil_striker1_name_star}            = "";
	$an->data->{form}{anvil_striker1_bcn_ip_star}          = "";
	$an->data->{form}{anvil_striker1_ifn_ip_star}          = "";
	$an->data->{form}{anvil_striker2_name_star}            = "";
	$an->data->{form}{anvil_striker2_bcn_ip_star}          = "";
	$an->data->{form}{anvil_striker2_ifn_ip_star}          = "";
	$an->data->{form}{anvil_media_library_star}            = "";
	$an->data->{form}{anvil_storage_pool1_star}            = "";
	$an->data->{form}{anvil_repositories_star}             = "";
	$an->data->{form}{anvil_node1_name_star}               = "";
	$an->data->{form}{anvil_node1_bcn_ip_star}             = "";
	$an->data->{form}{anvil_node1_ipmi_ip_star}            = "";
	$an->data->{form}{anvil_node1_sn_ip_star}              = "";
	$an->data->{form}{anvil_node1_ifn_ip_star}             = "";
	$an->data->{form}{anvil_node1_pdu1_outlet_star}        = "";
	$an->data->{form}{anvil_node1_pdu2_outlet_star}        = "";
	$an->data->{form}{anvil_node1_pdu3_outlet_star}        = "";
	$an->data->{form}{anvil_node1_pdu4_outlet_star}        = "";
	$an->data->{form}{anvil_node2_name_star}               = "";
	$an->data->{form}{anvil_node2_bcn_ip_star}             = "";
	$an->data->{form}{anvil_node2_ipmi_ip_star}            = "";
	$an->data->{form}{anvil_node2_sn_ip_star}              = "";
	$an->data->{form}{anvil_node2_ifn_ip_star}             = "";
	$an->data->{form}{anvil_node2_pdu1_outlet_star}        = "";
	$an->data->{form}{anvil_node2_pdu2_outlet_star}        = "";
	$an->data->{form}{anvil_node2_pdu3_outlet_star}        = "";
	$an->data->{form}{anvil_node2_pdu4_outlet_star}        = "";
	$an->data->{form}{anvil_open_vnc_ports_star}           = "";
	$an->data->{form}{striker_user_star}                   = "";
	$an->data->{form}{striker_database_star}               = "";
	$an->data->{form}{anvil_striker1_user_star}            = "";
	$an->data->{form}{anvil_striker1_password_star}        = "";
	$an->data->{form}{anvil_striker1_database_star}        = "";
	$an->data->{form}{anvil_striker2_user_star}            = "";
	$an->data->{form}{anvil_striker2_password_star}        = "";
	$an->data->{form}{anvil_striker2_database_star}        = "";
	$an->data->{form}{anvil_mtu_size_star}                 = "";
	$an->data->{form}{'anvil_drbd_disk_disk-barrier_star'} = "";
	$an->data->{form}{'anvil_drbd_disk_disk-flushes_star'} = "";
	$an->data->{form}{'anvil_drbd_disk_md-flushes_star'}   = "";
	$an->data->{form}{'anvil_drbd_options_cpu-mask_star'}  = "";
	$an->data->{form}{'anvil_drbd_net_max-buffers_star'}   = "";
	$an->data->{form}{'anvil_drbd_net_sndbuf-size_star'}   = "";
	$an->data->{form}{'anvil_drbd_net_rcvbuf-size_star'}   = "";
	
	# Delete it, if requested
	if ($an->data->{cgi}{'delete'})
	{
		my $return     = $an->ScanCore->parse_install_manifest({uuid => $an->data->{cgi}{manifest_uuid}});
		my $anvil_name = $an->data->{cgi}{anvil_name};
		if ($an->data->{cgi}{confirm})
		{
			### TODO: Switch to configure->delete_manifest
			# Make sure that the file exists and that it is in the manifests directory.
			my $queries = [];
			push @{$queries}, "
UPDATE 
    manifests 
SET 
    manifest_note = 'DELETED' 
WHERE 
    manifest_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{cgi}{manifest_uuid})."
;";
	push @{$queries}, "
DELETE FROM  
    manifests 
WHERE 
    manifest_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{cgi}{manifest_uuid})."
;";
			# Log the queries
			foreach my $query (@{$queries})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1  => "query", value1 => $query, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Pass the array in.
			$an->DB->do_db_write({query => $queries, source => $THIS_FILE, line => __LINE__});
			my $message = $an->String->get({key => "message_0462", variables => { anvil => $anvil_name }});
			print $an->Web->template({file => "config.html", template => "delete-manifest-success", replace => { message => $message }});
		}
		else
		{
			$show_form = 0;
			my $message = $an->String->get({key => "message_0463", variables => { anvil => $anvil_name }});
			print $an->Web->template({file => "config.html", template => "manifest-confirm-delete", replace => { 
				message	=>	$message,
				confirm	=>	"?config=true&task=create-install-manifest&delete=true&manifest_uuid=".$an->data->{cgi}{manifest_uuid}."&confirm=true",
			}});
		}
	}
	
	# If the 'raw' was passed, present a form with the XML definition shown raw.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::raw", value1 => $an->data->{cgi}{raw},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{raw})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::save", value1 => $an->data->{cgi}{save},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{save})
		{
			my $manifest_uuid = $an->ScanCore->save_install_manifest();
			
			#my ($target_url, $xml_file) = generate_install_manifest($an);
			my $message = $an->String->get({key => "explain_0124", variables => { uuid => $manifest_uuid }});
			print $an->Web->template({file => "config.html", template => "manifest-created", replace => { message => $message }});
			$show_form = 1;
		}
		else
		{
			   $show_form = 0;
			my $return    = $an->ScanCore->get_manifests();
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return", value1 => $return,
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $hash_ref (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "hash_ref->manifest_uuid", value1 => $hash_ref->{manifest_uuid}, 
					name2 => "cgi::manifest_uuid",      value2 => $an->data->{cgi}{manifest_uuid}, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($hash_ref->{manifest_uuid} eq $an->data->{cgi}{manifest_uuid})
				{
					$an->data->{cgi}{manifest_data} = $hash_ref->{manifest_data};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "cgi::manifest_data", value1 => $an->data->{cgi}{manifest_uuid}, 
					}, file => $THIS_FILE, line => __LINE__});
					last;
				}
			}
			print $an->Web->template({file => "config.html", template => "manifest-raw-edit", replace => { 
				manifest_uuid	=>	$an->data->{cgi}{manifest_uuid},
				manifest_data	=>	$an->data->{cgi}{manifest_data},
			}});
		}
	}
	
	# Generate a new one, if requested.
	if ($an->data->{cgi}{generate})
	{
		# Sanity check the user's answers and, if OK, returns 0. Any problem detected returns 1.
		if (not sanity_check_manifest_answers($an))
		{
			# No errors, write out the manifest and create the download link.
			if (not $an->data->{cgi}{confirm})
			{
				$show_form = 0;
				show_summary_manifest($an);
			}
			else
			{
				# The form will redisplay after this.
				my $manifest_uuid = $an->ScanCore->save_install_manifest();
				
				#my ($target_url, $xml_file) = generate_install_manifest($an);
				my $message = $an->String->get({key => "explain_0124", variables => { uuid => $manifest_uuid }});
				print $an->Web->template({file => "config.html", template => "manifest-created", replace => { message => $message }});
			}
		}
	}
	elsif ($an->data->{cgi}{run})
	{
		# Read in the install manifest.
		my $return     = $an->ScanCore->parse_install_manifest({uuid => $an->data->{cgi}{manifest_uuid}});
		my $anvil_name = $an->data->{cgi}{anvil_name};
		#load_install_manifest($an, $an->data->{cgi}{run});
		if ($an->data->{cgi}{confirm})
		{
			# Do it.
			$show_form = 0;
			my ($return_code) = AN::InstallManifest::run_new_install_manifest($an);
			# 0 == success
			# 1 == failed
			# 2 == failed, but don't show the error footer.
			if ($return_code eq "1")
			{
				# Something went wrong.
				my $button = $an->Web->template({file => "config.html", template => "form-button", replace => { 
						class	=>	"bold_button", 
						name	=>	"confirm",
						id	=>	"confirm",
						value	=>	"#!string!button_0063!#",
					}});
				my $message = $an->String->get({key => "message_0432", variables => { try_again_button => $button }});
				$an->Log->entry({log_level => 3, message_key => "an_variables_0012", message_variables => {
					name1  => "cgi::anvil_node1_bcn_link1_mac", value1  => $an->data->{cgi}{anvil_node1_bcn_link1_mac},
					name2  => "cgi::anvil_node1_bcn_link2_mac", value2  => $an->data->{cgi}{anvil_node1_bcn_link2_mac},
					name3  => "cgi::anvil_node1_sn_link1_mac",  value3  => $an->data->{cgi}{anvil_node1_sn_link1_mac},
					name4  => "cgi::anvil_node1_sn_link2_mac",  value4  => $an->data->{cgi}{anvil_node1_sn_link2_mac},
					name5  => "cgi::anvil_node1_ifn_link1_mac", value5  => $an->data->{cgi}{anvil_node1_ifn_link1_mac},
					name6  => "cgi::anvil_node1_ifn_link2_mac", value6  => $an->data->{cgi}{anvil_node1_ifn_link2_mac},
					name7  => "cgi::anvil_node2_bcn_link1_mac", value7  => $an->data->{cgi}{anvil_node2_bcn_link1_mac},
					name8  => "cgi::anvil_node2_bcn_link2_mac", value8  => $an->data->{cgi}{anvil_node2_bcn_link2_mac},
					name9  => "cgi::anvil_node2_sn_link1_mac",  value9  => $an->data->{cgi}{anvil_node2_sn_link1_mac},
					name10 => "cgi::anvil_node2_sn_link2_mac",  value10 => $an->data->{cgi}{anvil_node2_sn_link2_mac},
					name11 => "cgi::anvil_node2_ifn_link1_mac", value11 => $an->data->{cgi}{anvil_node2_ifn_link1_mac},
					name12 => "cgi::anvil_node2_ifn_link2_mac", value12 => $an->data->{cgi}{anvil_node2_ifn_link2_mac},
				}, file => $THIS_FILE, line => __LINE__});
				my $restart_html = $an->Web->template({file => "config.html", template => "new-anvil-install-failed-footer", replace => { 
						form_file			=>	"/cgi-bin/striker",
						button_class			=>	"bold_button", 
						button_name			=>	"confirm",
						button_id			=>	"confirm",
						button_value			=>	"#!string!button_0063!#",
						message				=>	$message, 
						anvil_node1_current_ip		=>	$an->data->{cgi}{anvil_node1_current_ip},
						anvil_node1_current_password	=>	$an->data->{cgi}{anvil_node1_current_password},
						anvil_node2_current_ip		=>	$an->data->{cgi}{anvil_node2_current_ip},
						anvil_node2_current_password	=>	$an->data->{cgi}{anvil_node2_current_password},
						anvil_open_vnc_ports		=>	$an->data->{cgi}{anvil_open_vnc_ports},
						run				=>	$an->data->{cgi}{run},
						try_again_button		=>	$button,
						anvil_node1_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link1_mac},
						anvil_node1_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link2_mac},
						anvil_node1_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link1_mac},
						anvil_node1_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link2_mac},
						anvil_node1_sn_link1_mac	=>	$an->data->{cgi}{anvil_node1_sn_link1_mac},
						anvil_node1_sn_link2_mac	=>	$an->data->{cgi}{anvil_node1_sn_link2_mac},
						anvil_node2_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link1_mac},
						anvil_node2_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link2_mac},
						anvil_node2_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link1_mac},
						anvil_node2_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link2_mac},
						anvil_node2_sn_link1_mac	=>	$an->data->{cgi}{anvil_node2_sn_link1_mac},
						anvil_node2_sn_link2_mac	=>	$an->data->{cgi}{anvil_node2_sn_link2_mac},
						rhn_user			=>	$an->data->{cgi}{rhn_user},
						rhn_password			=>	$an->data->{cgi}{rhn_password},
					}});
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "restart_html", value1 => $restart_html,
				}, file => $THIS_FILE, line => __LINE__});
				print $restart_html;
			}
		}
		else
		{
			# Confirm
			$show_form = 0;
			confirm_install_manifest_run($an);
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "show_form", value1 => $show_form,
	}, file => $THIS_FILE, line => __LINE__});
	if ($show_form)
	{
		# Show the existing install manifest files.
		show_existing_install_manifests($an);
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_domain", value1 => $an->data->{cgi}{anvil_domain},
		}, file => $THIS_FILE, line => __LINE__});
		
		if (not $an->data->{cgi}{manifest_uuid})
		{
			# Blank out all anvil CGI variables that might have been set when we parsed the 
			# existing manifests.
			foreach my $key (sort {$a cmp $b} keys %{$an->data->{cgi}})
			{
				next if $key !~ /^anvil_/;
				$an->data->{cgi}{$key} = "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "cgi::$key", value1 => $an->data->{cgi}{$key},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Set some default values if 'save' isn't set.
		if ($an->data->{cgi}{load})
		{
			$an->ScanCore->parse_install_manifest({uuid => $an->data->{cgi}{manifest_uuid}});
			#load_install_manifest($an, $an->data->{cgi}{load});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0012", message_variables => {
				name1  => "cgi::anvil_node1_bcn_link1_mac", value1  => $an->data->{cgi}{anvil_node1_bcn_link1_mac},
				name2  => "cgi::anvil_node1_bcn_link2_mac", value2  => $an->data->{cgi}{anvil_node1_bcn_link2_mac},
				name3  => "cgi::anvil_node1_sn_link1_mac",  value3  => $an->data->{cgi}{anvil_node1_sn_link1_mac},
				name4  => "cgi::anvil_node1_sn_link2_mac",  value4  => $an->data->{cgi}{anvil_node1_sn_link2_mac},
				name5  => "cgi::anvil_node1_ifn_link1_mac", value5  => $an->data->{cgi}{anvil_node1_ifn_link1_mac},
				name6  => "cgi::anvil_node1_ifn_link2_mac", value6  => $an->data->{cgi}{anvil_node1_ifn_link2_mac},
				name7  => "cgi::anvil_node2_bcn_link1_mac", value7  => $an->data->{cgi}{anvil_node2_bcn_link1_mac},
				name8  => "cgi::anvil_node2_bcn_link2_mac", value8  => $an->data->{cgi}{anvil_node2_bcn_link2_mac},
				name9  => "cgi::anvil_node2_sn_link1_mac",  value9  => $an->data->{cgi}{anvil_node2_sn_link1_mac},
				name10 => "cgi::anvil_node2_sn_link2_mac",  value10 => $an->data->{cgi}{anvil_node2_sn_link2_mac},
				name11 => "cgi::anvil_node2_ifn_link1_mac", value11 => $an->data->{cgi}{anvil_node2_ifn_link1_mac},
				name12 => "cgi::anvil_node2_ifn_link2_mac", value12 => $an->data->{cgi}{anvil_node2_ifn_link2_mac},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $an->data->{cgi}{generate})
		{
			# This function uses sys::install_manifest::default::x if set.
			my ($default_prefix, $default_domain) = get_striker_prefix_and_domain($an);
			
			# Primary Config values
			if (not $an->data->{cgi}{anvil_prefix})             { $an->data->{cgi}{anvil_prefix}             = $default_prefix; }
			if (not $an->data->{cgi}{anvil_sequence})           { $an->data->{cgi}{anvil_sequence}           = $an->data->{sys}{install_manifest}{'default'}{sequence}; }
			if (not $an->data->{cgi}{anvil_domain})             { $an->data->{cgi}{anvil_domain}             = $default_domain; }
			if (not $an->data->{cgi}{anvil_password})           { $an->data->{cgi}{anvil_password}           = $an->data->{sys}{install_manifest}{'default'}{password}; }
			if (not $an->data->{cgi}{anvil_bcn_ethtool_opts})   { $an->data->{cgi}{anvil_bcn_ethtool_opts}   = $an->data->{sys}{install_manifest}{'default'}{bcn_ethtool_opts}; }
			if (not $an->data->{cgi}{anvil_bcn_network})        { $an->data->{cgi}{anvil_bcn_network}        = $an->data->{sys}{install_manifest}{'default'}{bcn_network}; }
			if (not $an->data->{cgi}{anvil_bcn_subnet})         { $an->data->{cgi}{anvil_bcn_subnet}         = $an->data->{sys}{install_manifest}{'default'}{bcn_subnet}; }
			if (not $an->data->{cgi}{anvil_sn_ethtool_opts})    { $an->data->{cgi}{anvil_sn_ethtool_opts}    = $an->data->{sys}{install_manifest}{'default'}{sn_ethtool_opts}; }
			if (not $an->data->{cgi}{anvil_sn_network})         { $an->data->{cgi}{anvil_sn_network}         = $an->data->{sys}{install_manifest}{'default'}{sn_network}; }
			if (not $an->data->{cgi}{anvil_sn_subnet})          { $an->data->{cgi}{anvil_sn_subnet}          = $an->data->{sys}{install_manifest}{'default'}{sn_subnet}; }
			if (not $an->data->{cgi}{anvil_ifn_ethtool_opts})   { $an->data->{cgi}{anvil_ifn_ethtool_opts}   = $an->data->{sys}{install_manifest}{'default'}{ifn_ethtool_opts}; }
			if (not $an->data->{cgi}{anvil_ifn_network})        { $an->data->{cgi}{anvil_ifn_network}        = $an->data->{sys}{install_manifest}{'default'}{ifn_network}; }
			if (not $an->data->{cgi}{anvil_ifn_subnet})         { $an->data->{cgi}{anvil_ifn_subnet}         = $an->data->{sys}{install_manifest}{'default'}{ifn_subnet}; }
			if (not $an->data->{cgi}{anvil_media_library_size}) { $an->data->{cgi}{anvil_media_library_size} = $an->data->{sys}{install_manifest}{'default'}{library_size}; }
			if (not $an->data->{cgi}{anvil_media_library_unit}) { $an->data->{cgi}{anvil_media_library_unit} = $an->data->{sys}{install_manifest}{'default'}{library_unit}; }
			if (not $an->data->{cgi}{anvil_storage_pool1_size}) { $an->data->{cgi}{anvil_storage_pool1_size} = $an->data->{sys}{install_manifest}{'default'}{pool1_size}; }
			if (not $an->data->{cgi}{anvil_storage_pool1_unit}) { $an->data->{cgi}{anvil_storage_pool1_unit} = $an->data->{sys}{install_manifest}{'default'}{pool1_unit}; }
			if (not $an->data->{cgi}{anvil_repositories})       { $an->data->{cgi}{anvil_repositories}       = $an->data->{sys}{install_manifest}{'default'}{repositories}; }
			
			# DRBD variables
			if (not $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'}) { $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} = $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-barrier'}; }
			if (not $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'}) { $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} = $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-flushes'}; }
			if (not $an->data->{cgi}{'anvil_drbd_disk_md-flushes'})   { $an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   = $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_md-flushes'}; }
			if (not $an->data->{cgi}{'anvil_drbd_options_cpu-mask'})  { $an->data->{cgi}{'anvil_drbd_options_cpu-mask'}  = $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_options_cpu-mask'}; }
			if (not $an->data->{cgi}{'anvil_drbd_net_max-buffers'})   { $an->data->{cgi}{'anvil_drbd_net_max-buffers'}   = $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_max-buffers'}; }
			if (not $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'})   { $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}   = $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_sndbuf-size'}; }
			if (not $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'})   { $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}   = $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_rcvbuf-size'}; }
			
			# Hidden fields for now.
			if (not $an->data->{cgi}{anvil_cluster_name})       { $an->data->{cgi}{anvil_cluster_name}       = $an->data->{sys}{install_manifest}{'default'}{cluster_name}; }
			if (not $an->data->{cgi}{anvil_open_vnc_ports})     { $an->data->{cgi}{anvil_open_vnc_ports}     = $an->data->{sys}{install_manifest}{'default'}{open_vnc_ports}; }
			if (not $an->data->{cgi}{anvil_mtu_size})           { $an->data->{cgi}{anvil_mtu_size}           = $an->data->{sys}{install_manifest}{'default'}{mtu_size}; }
			
			# It's possible for the user to set default values in
			# the install manifest.
			if (not $an->data->{cgi}{anvil_name})               { $an->data->{cgi}{anvil_name}               = $an->data->{sys}{install_manifest}{'default'}{name}; }
			if (not $an->data->{cgi}{anvil_ifn_gateway})        { $an->data->{cgi}{anvil_ifn_gateway}        = $an->data->{sys}{install_manifest}{'default'}{ifn_gateway}; }
			if (not $an->data->{cgi}{anvil_dns1})               { $an->data->{cgi}{anvil_dns1}               = $an->data->{sys}{install_manifest}{'default'}{dns1}; }
			if (not $an->data->{cgi}{anvil_dns2})               { $an->data->{cgi}{anvil_dns2}               = $an->data->{sys}{install_manifest}{'default'}{dns2}; }
			if (not $an->data->{cgi}{anvil_ntp1})               { $an->data->{cgi}{anvil_ntp1}               = $an->data->{sys}{install_manifest}{'default'}{ntp1}; }
			if (not $an->data->{cgi}{anvil_ntp2})               { $an->data->{cgi}{anvil_ntp2}               = $an->data->{sys}{install_manifest}{'default'}{ntp2}; }
			
			# Foundation Pack
			if (not $an->data->{cgi}{anvil_switch1_name})       { $an->data->{cgi}{anvil_switch1_name}       = $an->data->{sys}{install_manifest}{'default'}{switch1_name}; }
			if (not $an->data->{cgi}{anvil_switch1_ip})         { $an->data->{cgi}{anvil_switch1_ip}         = $an->data->{sys}{install_manifest}{'default'}{switch1_ip}; }
			if (not $an->data->{cgi}{anvil_switch2_name})       { $an->data->{cgi}{anvil_switch2_name}       = $an->data->{sys}{install_manifest}{'default'}{switch2_name}; }
			if (not $an->data->{cgi}{anvil_switch2_ip})         { $an->data->{cgi}{anvil_switch2_ip}         = $an->data->{sys}{install_manifest}{'default'}{switch2_ip}; }
			if (not $an->data->{cgi}{anvil_ups1_name})          { $an->data->{cgi}{anvil_ups1_name}          = $an->data->{sys}{install_manifest}{'default'}{ups1_name}; }
			if (not $an->data->{cgi}{anvil_ups1_ip})            { $an->data->{cgi}{anvil_ups1_ip}            = $an->data->{sys}{install_manifest}{'default'}{ups1_ip}; }
			if (not $an->data->{cgi}{anvil_ups2_name})          { $an->data->{cgi}{anvil_ups2_name}          = $an->data->{sys}{install_manifest}{'default'}{ups2_name}; }
			if (not $an->data->{cgi}{anvil_ups2_ip})            { $an->data->{cgi}{anvil_ups2_ip}            = $an->data->{sys}{install_manifest}{'default'}{ups2_ip}; }
			if (not $an->data->{cgi}{anvil_pts1_name})          { $an->data->{cgi}{anvil_pts1_name}          = $an->data->{sys}{install_manifest}{'default'}{pts1_name}; }
			if (not $an->data->{cgi}{anvil_pts1_ip})            { $an->data->{cgi}{anvil_pts1_ip}            = $an->data->{sys}{install_manifest}{'default'}{pts1_ip}; }
			if (not $an->data->{cgi}{anvil_pts2_name})          { $an->data->{cgi}{anvil_pts2_name}          = $an->data->{sys}{install_manifest}{'default'}{pts2_name}; }
			if (not $an->data->{cgi}{anvil_pts2_ip})            { $an->data->{cgi}{anvil_pts2_ip}            = $an->data->{sys}{install_manifest}{'default'}{pts2_ip}; }
			if (not $an->data->{cgi}{anvil_pdu1_name})          { $an->data->{cgi}{anvil_pdu1_name}          = $an->data->{sys}{install_manifest}{'default'}{pdu1_name}; }
			if (not $an->data->{cgi}{anvil_pdu1_ip})            { $an->data->{cgi}{anvil_pdu1_ip}            = $an->data->{sys}{install_manifest}{'default'}{pdu1_ip}; }
			if (not $an->data->{cgi}{anvil_pdu2_name})          { $an->data->{cgi}{anvil_pdu2_name}          = $an->data->{sys}{install_manifest}{'default'}{pdu2_name}; }
			if (not $an->data->{cgi}{anvil_pdu2_ip})            { $an->data->{cgi}{anvil_pdu2_ip}            = $an->data->{sys}{install_manifest}{'default'}{pdu2_ip}; }
			if (not $an->data->{cgi}{anvil_pdu3_name})          { $an->data->{cgi}{anvil_pdu3_name}          = $an->data->{sys}{install_manifest}{'default'}{pdu3_name}; }
			if (not $an->data->{cgi}{anvil_pdu3_ip})            { $an->data->{cgi}{anvil_pdu3_ip}            = $an->data->{sys}{install_manifest}{'default'}{pdu3_ip}; }
			if (not $an->data->{cgi}{anvil_pdu4_name})          { $an->data->{cgi}{anvil_pdu4_name}          = $an->data->{sys}{install_manifest}{'default'}{pdu4_name}; }
			if (not $an->data->{cgi}{anvil_pdu4_ip})            { $an->data->{cgi}{anvil_pdu4_ip}            = $an->data->{sys}{install_manifest}{'default'}{pdu4_ip}; }
			if (not $an->data->{cgi}{anvil_striker1_name})      { $an->data->{cgi}{anvil_striker1_name}      = $an->data->{sys}{install_manifest}{'default'}{striker1_name}; }
			if (not $an->data->{cgi}{anvil_striker1_bcn_ip})    { $an->data->{cgi}{anvil_striker1_bcn_ip}    = $an->data->{sys}{install_manifest}{'default'}{striker1_bcn_ip}; }
			if (not $an->data->{cgi}{anvil_striker1_ifn_ip})    { $an->data->{cgi}{anvil_striker1_ifn_ip}    = $an->data->{sys}{install_manifest}{'default'}{striker1_ifn_ip}; }
			if (not $an->data->{cgi}{anvil_striker2_name})      { $an->data->{cgi}{anvil_striker2_name}      = $an->data->{sys}{install_manifest}{'default'}{striker2_name}; }
			if (not $an->data->{cgi}{anvil_striker2_bcn_ip})    { $an->data->{cgi}{anvil_striker2_bcn_ip}    = $an->data->{sys}{install_manifest}{'default'}{striker2_bcn_ip}; }
			if (not $an->data->{cgi}{anvil_striker2_ifn_ip})    { $an->data->{cgi}{anvil_striker2_ifn_ip}    = $an->data->{sys}{install_manifest}{'default'}{striker2_ifn_ip}; }
			
			# Node 1 variables
			if (not $an->data->{cgi}{anvil_node1_name})         { $an->data->{cgi}{anvil_node1_name}         = $an->data->{sys}{install_manifest}{'default'}{node1_name}; }
			if (not $an->data->{cgi}{anvil_node1_bcn_ip})       { $an->data->{cgi}{anvil_node1_bcn_ip}       = $an->data->{sys}{install_manifest}{'default'}{node1_bcn_ip}; }
			if (not $an->data->{cgi}{anvil_node1_ipmi_ip})      { $an->data->{cgi}{anvil_node1_ipmi_ip}      = $an->data->{sys}{install_manifest}{'default'}{node1_ipmi_ip}; }
			if (not $an->data->{cgi}{anvil_node1_sn_ip})        { $an->data->{cgi}{anvil_node1_sn_ip}        = $an->data->{sys}{install_manifest}{'default'}{node1_sn_ip}; }
			if (not $an->data->{cgi}{anvil_node1_ifn_ip})       { $an->data->{cgi}{anvil_node1_ifn_ip}       = $an->data->{sys}{install_manifest}{'default'}{node1_ifn_ip}; }
			if (not $an->data->{cgi}{anvil_node1_pdu1_outlet})  { $an->data->{cgi}{anvil_node1_pdu1_outlet}  = $an->data->{sys}{install_manifest}{'default'}{node1_pdu1_outlet}; }
			if (not $an->data->{cgi}{anvil_node1_pdu2_outlet})  { $an->data->{cgi}{anvil_node1_pdu2_outlet}  = $an->data->{sys}{install_manifest}{'default'}{node1_pdu2_outlet}; }
			if (not $an->data->{cgi}{anvil_node1_pdu3_outlet})  { $an->data->{cgi}{anvil_node1_pdu3_outlet}  = $an->data->{sys}{install_manifest}{'default'}{node1_pdu3_outlet}; }
			if (not $an->data->{cgi}{anvil_node2_pdu4_outlet})  { $an->data->{cgi}{anvil_node2_pdu4_outlet}  = $an->data->{sys}{install_manifest}{'default'}{node2_pdu4_outlet}; }
			
			# Node 2 variables
			if (not $an->data->{cgi}{anvil_node2_name})         { $an->data->{cgi}{anvil_node2_name}         = $an->data->{sys}{install_manifest}{'default'}{node2_name}; }
			if (not $an->data->{cgi}{anvil_node2_bcn_ip})       { $an->data->{cgi}{anvil_node2_bcn_ip}       = $an->data->{sys}{install_manifest}{'default'}{node2_bcn_ip}; }
			if (not $an->data->{cgi}{anvil_node2_ipmi_ip})      { $an->data->{cgi}{anvil_node2_ipmi_ip}      = $an->data->{sys}{install_manifest}{'default'}{node2_ipmi_ip}; }
			if (not $an->data->{cgi}{anvil_node2_sn_ip})        { $an->data->{cgi}{anvil_node2_sn_ip}        = $an->data->{sys}{install_manifest}{'default'}{node2_sn_ip}; }
			if (not $an->data->{cgi}{anvil_node2_ifn_ip})       { $an->data->{cgi}{anvil_node2_ifn_ip}       = $an->data->{sys}{install_manifest}{'default'}{node2_ifn_ip}; }
			if (not $an->data->{cgi}{anvil_node2_pdu1_outlet})  { $an->data->{cgi}{anvil_node2_pdu1_outlet}  = $an->data->{sys}{install_manifest}{'default'}{node2_pdu1_outlet}; }
			if (not $an->data->{cgi}{anvil_node2_pdu2_outlet})  { $an->data->{cgi}{anvil_node2_pdu2_outlet}  = $an->data->{sys}{install_manifest}{'default'}{node2_pdu2_outlet}; }
			if (not $an->data->{cgi}{anvil_node2_pdu3_outlet})  { $an->data->{cgi}{anvil_node2_pdu3_outlet}  = $an->data->{sys}{install_manifest}{'default'}{node2_pdu3_outlet}; }
			if (not $an->data->{cgi}{anvil_node1_pdu4_outlet})  { $an->data->{cgi}{anvil_node1_pdu4_outlet}  = $an->data->{sys}{install_manifest}{'default'}{node1_pdu4_outlet}; }
		}
		
		# Print the header
		print $an->Web->template({file => "config.html", template => "install-manifest-form-header", replace => { form_file => "/cgi-bin/striker" }});
		
		# Record the manifest_uuid, if set.
		if ($an->data->{cgi}{manifest_uuid})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"manifest_uuid",
				id		=>	"manifest_uuid",
				value		=>	$an->data->{cgi}{manifest_uuid},
			}});
		}
		
		# Anvil! prefix
		if (not $an->data->{sys}{install_manifest}{show}{prefix_field})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_prefix",
				id		=>	"anvil_prefix",
				value		=>	$an->data->{cgi}{anvil_prefix},
			}});
		}
		else
		{
			my $anvil_prefix_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names" }});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0159!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0061!#" : "#!string!explain_0061!#",
				name		=>	"anvil_prefix",
				id		=>	"anvil_prefix",
				value		=>	$an->data->{cgi}{anvil_prefix},
				star		=>	$an->data->{form}{anvil_prefix_star},
				more_info	=>	"$anvil_prefix_more_info",
			}});
		}
		
		# Anvil! sequence
		if (not $an->data->{sys}{install_manifest}{show}{sequence_field})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_sequence",
				id		=>	"anvil_sequence",
				value		=>	$an->data->{cgi}{anvil_sequence},
			}});
		}
		else
		{
			my $anvil_sequence_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names" }});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0161!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0063!#" : "#!string!explain_0063!#",
				name		=>	"anvil_sequence",
				id		=>	"anvil_sequence",
				value		=>	$an->data->{cgi}{anvil_sequence},
				star		=>	$an->data->{form}{anvil_sequence_star},
				more_info	=>	"$anvil_sequence_more_info",
			}});
		}
		
		# Anvil! domain name
		if (not $an->data->{sys}{install_manifest}{show}{domain_field})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_domain",
				id		=>	"anvil_domain",
				value		=>	$an->data->{cgi}{anvil_domain},
			}});
		}
		else
		{
			my $anvil_domain_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names" }});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::anvil_domain", value1 => $an->data->{cgi}{anvil_domain},
			}, file => $THIS_FILE, line => __LINE__});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0160!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0062!#" : "#!string!explain_0062!#",
				name		=>	"anvil_domain",
				id		=>	"anvil_domain",
				value		=>	$an->data->{cgi}{anvil_domain},
				star		=>	$an->data->{form}{anvil_domain_star},
				more_info	=>	"$anvil_domain_more_info",
			}});
		}
		
		# Anvil! password - Skip if set and hidden.
		if (($an->data->{sys}{install_manifest}{'default'}{password}) && (not $an->data->{sys}{install_manifest}{show}{password_field}))
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_password",
				id		=>	"anvil_password",
				value		=>	$an->data->{cgi}{anvil_password},
			}});
		}
		else
		{
			my $anvil_password_more_info = "";
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0194!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0110!#" : "#!string!explain_0110!#",
				name		=>	"anvil_password",
				id		=>	"anvil_password",
				value		=>	$an->data->{cgi}{anvil_password},
				star		=>	$an->data->{form}{anvil_password_star},
				more_info	=>	"$anvil_password_more_info",
			}});
		}
		
		# Anvil! BCN Network definition
		if (($an->data->{sys}{install_manifest}{'default'}{bcn_network}) && 
		    ($an->data->{sys}{install_manifest}{'default'}{bcn_subnet}) && 
		    (not $an->data->{sys}{install_manifest}{show}{bcn_network_fields}))
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_bcn_network",
				id		=>	"anvil_bcn_network",
				value		=>	$an->data->{cgi}{anvil_bcn_network},
			}});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_bcn_subnet",
				id		=>	"anvil_bcn_subnet",
				value		=>	$an->data->{cgi}{anvil_bcn_subnet},
			}});
		}
		else
		{
			my $anvil_bcn_network_more_info = "";
			print $an->Web->template({file => "config.html", template => "install-manifest-form-subnet-entry", replace => { 
				row		=>	"#!string!row_0162!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0065!#" : "#!string!explain_0065!#",
				network_name	=>	"anvil_bcn_network",
				network_id	=>	"anvil_bcn_network",
				network_value	=>	$an->data->{cgi}{anvil_bcn_network},
				subnet_name	=>	"anvil_bcn_subnet",
				subnet_id	=>	"anvil_bcn_subnet",
				subnet_value	=>	$an->data->{cgi}{anvil_bcn_subnet},
				star		=>	$an->data->{form}{anvil_bcn_network_star},
				more_info	=>	"$anvil_bcn_network_more_info",
			}});
		}
		# For now, ethtool_opts is always hidden.
		if (1)
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_bcn_ethtool_opts",
				id		=>	"anvil_bcn_ethtool_opts",
				value		=>	$an->data->{cgi}{anvil_bcn_ethtool_opts},
			}});
		}
		
		# Anvil! SN Network definition
		if (($an->data->{sys}{install_manifest}{'default'}{sn_network}) && 
		    ($an->data->{sys}{install_manifest}{'default'}{sn_subnet}) && 
		    (not $an->data->{sys}{install_manifest}{show}{sn_network_fields}))
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_sn_network",
				id		=>	"anvil_sn_network",
				value		=>	$an->data->{cgi}{anvil_sn_network},
			}});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_sn_subnet",
				id		=>	"anvil_sn_subnet",
				value		=>	$an->data->{cgi}{anvil_sn_subnet},
			}});
		}
		else
		{
			my $anvil_sn_network_more_info = "";
			print $an->Web->template({file => "config.html", template => "install-manifest-form-subnet-entry", replace => { 
				row		=>	"#!string!row_0163!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0066!#" : "#!string!explain_0066!#",
				network_name	=>	"anvil_sn_network",
				network_id	=>	"anvil_sn_network",
				network_value	=>	$an->data->{cgi}{anvil_sn_network},
				subnet_name	=>	"anvil_sn_subnet",
				subnet_id	=>	"anvil_sn_subnet",
				subnet_value	=>	$an->data->{cgi}{anvil_sn_subnet},
				star		=>	$an->data->{form}{anvil_sn_network_star},
				more_info	=>	"$anvil_sn_network_more_info",
			}});
		}
		# For now, ethtool_opts is always hidden.
		if (1)
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_sn_ethtool_opts",
				id		=>	"anvil_sn_ethtool_opts",
				value		=>	$an->data->{cgi}{anvil_sn_ethtool_opts},
			}});
		}
		
		# Anvil! IFN Network definition
		if (($an->data->{sys}{install_manifest}{'default'}{ifn_network}) && 
		    ($an->data->{sys}{install_manifest}{'default'}{ifn_subnet}) && 
		    (not $an->data->{sys}{install_manifest}{show}{ifn_network_fields}))
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_ifn_network",
				id		=>	"anvil_ifn_network",
				value		=>	$an->data->{cgi}{anvil_ifn_network},
			}});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_ifn_subnet",
				id		=>	"anvil_ifn_subnet",
				value		=>	$an->data->{cgi}{anvil_ifn_subnet},
			}});
		}
		else
		{
			my $anvil_ifn_network_more_info = "";
			print $an->Web->template({file => "config.html", template => "install-manifest-form-subnet-entry", replace => { 
				row		=>	"#!string!row_0164!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0067!#" : "#!string!explain_0067!#",
				network_name	=>	"anvil_ifn_network",
				network_id	=>	"anvil_ifn_network",
				network_value	=>	$an->data->{cgi}{anvil_ifn_network},
				subnet_name	=>	"anvil_ifn_subnet",
				subnet_id	=>	"anvil_ifn_subnet",
				subnet_value	=>	$an->data->{cgi}{anvil_ifn_subnet},
				star		=>	$an->data->{form}{anvil_ifn_network_star},
				more_info	=>	"$anvil_ifn_network_more_info",
			}});
		}
		# For now, ethtool_opts is always hidden.
		if (1)
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_ifn_ethtool_opts",
				id		=>	"anvil_ifn_ethtool_opts",
				value		=>	$an->data->{cgi}{anvil_ifn_ethtool_opts},
			}});
		}
		
		# Anvil! Media Library size
		if (($an->data->{sys}{install_manifest}{'default'}{library_size}) && 
		    ($an->data->{sys}{install_manifest}{'default'}{library_unit}) && 
		    (not $an->data->{sys}{install_manifest}{show}{library_fields}))
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_media_library_size",
				id		=>	"anvil_media_library_size",
				value		=>	$an->data->{cgi}{anvil_media_library_size},
			}});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_media_library_unit",
				id		=>	"anvil_media_library_unit",
				value		=>	$an->data->{cgi}{anvil_media_library_unit},
			}});
		}
		else
		{
			my $anvil_media_library_more_info = "";
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-and-select-entry", replace => { 
				row		=>	"#!string!row_0191!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0114!#" : "#!string!explain_0114!#",
				name		=>	"anvil_media_library_size",
				id		=>	"anvil_media_library_size",
				value		=>	$an->data->{cgi}{anvil_media_library_size},
				'select'	=>	build_select($an, "anvil_media_library_unit", 0, 0, 60, $an->data->{cgi}{anvil_media_library_unit}, ["GiB", "TiB"]),
				star		=>	$an->data->{form}{anvil_media_library_star},
				more_info	=>	"$anvil_media_library_more_info",
			}});
		}
		
		### NOTE: Disabled, now all goes to Pool 1
		# Anvil! Storage Pools
		if (0)
		{
			if (($an->data->{sys}{install_manifest}{'default'}{pool1_size}) && 
			    ($an->data->{sys}{install_manifest}{'default'}{pool1_unit}) && 
			    (not $an->data->{sys}{install_manifest}{show}{pool1_fields}))
			{
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"anvil_storage_pool1_size",
					id		=>	"anvil_storage_pool1_size",
					value		=>	$an->data->{cgi}{anvil_storage_pool1_size},
				}});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"anvil_storage_pool1_unit",
					id		=>	"anvil_storage_pool1_unit",
					value		=>	$an->data->{cgi}{anvil_storage_pool1_unit},
				}});
			}
			else
			{
				my $anvil_storage_pool1_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names" }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-and-select-entry", replace => { 
					row		=>	"#!string!row_0199!#",
					explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0115!#" : "#!string!explain_0115!#",
					name		=>	"anvil_storage_pool1_size",
					id		=>	"anvil_storage_pool1_size",
					value		=>	$an->data->{cgi}{anvil_storage_pool1_size},
					'select'	=>	build_select($an, "anvil_storage_pool1_unit", 0, 0, 60, $an->data->{cgi}{anvil_storage_pool1_unit}, ["%", "GiB", "TiB"]),
					star		=>	$an->data->{form}{anvil_storage_pool1_star},
					more_info	=>	"$anvil_storage_pool1_more_info",
				}});
			}
		}
		else
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_storage_pool1_size",
				id		=>	"anvil_storage_pool1_size",
				value		=>	$an->data->{cgi}{anvil_storage_pool1_size},
			}});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_storage_pool1_unit",
				id		=>	"anvil_storage_pool1_unit",
				value		=>	$an->data->{cgi}{anvil_storage_pool1_unit},
			}});
		}
		
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_repositories",
			id		=>	"anvil_repositories",
			value		=>	$an->data->{cgi}{anvil_repositories},
		}});
		
		# Button to pre-populate the rest of the form.
		print $an->Web->template({file => "config.html", template => "install-manifest-form-spacer"});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-set-values"});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-spacer"});
		
		# The header for the "Secondary" section (all things below
		# *should* populate properly for most users)
		print $an->Web->template({file => "config.html", template => "install-manifest-form-secondary-header"});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-spacer"});
		
		# Now show the header for the Common section.
		print $an->Web->template({file => "config.html", template => "install-manifest-form-common-header"});
		
		### NOTE: For now, DRBD options are hidden.
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_drbd_disk_disk-barrier",
			id		=>	"anvil_drbd_disk_disk-barrier",
			value		=>	$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
		}});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_drbd_disk_disk-flushes",
			id		=>	"anvil_drbd_disk_disk-flushes",
			value		=>	$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
		}});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_drbd_disk_md-flushes",
			id		=>	"anvil_drbd_disk_md-flushes",
			value		=>	$an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
		}});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_drbd_options_cpu-mask",
			id		=>	"anvil_drbd_options_cpu-mask",
			value		=>	$an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
		}});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_drbd_net_max-buffers",
			id		=>	"anvil_drbd_net_max-buffers",
			value		=>	$an->data->{cgi}{'anvil_drbd_net_max-buffers'},
		}});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_drbd_net_sndbuf-size",
			id		=>	"anvil_drbd_net_sndbuf-size",
			value		=>	$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
		}});
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_drbd_net_rcvbuf-size",
			id		=>	"anvil_drbd_net_rcvbuf-size",
			value		=>	$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
		}});
		
		# Store defined MAC addresses
		if ($an->data->{cgi}{anvil_node1_bcn_link1_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node1_bcn_link1_mac",
				id		=>	"anvil_node1_bcn_link1_mac",
				value		=>	$an->data->{cgi}{anvil_node1_bcn_link1_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node1_bcn_link2_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node1_bcn_link2_mac",
				id		=>	"anvil_node1_bcn_link2_mac",
				value		=>	$an->data->{cgi}{anvil_node1_bcn_link2_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node1_sn_link1_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node1_sn_link1_mac",
				id		=>	"anvil_node1_sn_link1_mac",
				value		=>	$an->data->{cgi}{anvil_node1_sn_link1_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node1_sn_link2_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node1_sn_link2_mac",
				id		=>	"anvil_node1_sn_link2_mac",
				value		=>	$an->data->{cgi}{anvil_node1_sn_link2_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node1_ifn_link1_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node1_ifn_link1_mac",
				id		=>	"anvil_node1_ifn_link1_mac",
				value		=>	$an->data->{cgi}{anvil_node1_ifn_link1_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node1_ifn_link2_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node1_ifn_link2_mac",
				id		=>	"anvil_node1_ifn_link2_mac",
				value		=>	$an->data->{cgi}{anvil_node1_ifn_link2_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node2_bcn_link1_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node2_bcn_link1_mac",
				id		=>	"anvil_node2_bcn_link1_mac",
				value		=>	$an->data->{cgi}{anvil_node2_bcn_link1_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node2_bcn_link2_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node2_bcn_link2_mac",
				id		=>	"anvil_node2_bcn_link2_mac",
				value		=>	$an->data->{cgi}{anvil_node2_bcn_link2_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node2_sn_link1_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node2_sn_link1_mac",
				id		=>	"anvil_node2_sn_link1_mac",
				value		=>	$an->data->{cgi}{anvil_node2_sn_link1_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node2_sn_link2_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node2_sn_link2_mac",
				id		=>	"anvil_node2_sn_link2_mac",
				value		=>	$an->data->{cgi}{anvil_node2_sn_link2_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node2_ifn_link1_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node2_ifn_link1_mac",
				id		=>	"anvil_node2_ifn_link1_mac",
				value		=>	$an->data->{cgi}{anvil_node2_ifn_link1_mac},
			}});
		}
		if ($an->data->{cgi}{anvil_node2_ifn_link2_mac})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_node2_ifn_link2_mac",
				id		=>	"anvil_node2_ifn_link2_mac",
				value		=>	$an->data->{cgi}{anvil_node2_ifn_link2_mac},
			}});
		}
		
		# Anvil! (cman cluster) Name
		if (($an->data->{sys}{install_manifest}{'default'}{name}) && 
		    (not $an->data->{sys}{install_manifest}{show}{name_field}))
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_name",
				id		=>	"anvil_name",
				value		=>	$an->data->{cgi}{anvil_name},
			}});
		}
		else
		{
			my $anvil_name_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#The_First_cluster.conf_Foundation_Configuration" }});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0005!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0095!#" : "#!string!explain_0095!#",
				name		=>	"anvil_name",
				id		=>	"anvil_name",
				value		=>	$an->data->{cgi}{anvil_name},
				star		=>	$an->data->{form}{anvil_name_star},
				more_info	=>	"$anvil_name_more_info",
			}});
		}
		# The "anvil_name" is stored as a hidden field.
		print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
			name		=>	"anvil_cluster_name",
			id		=>	"anvil_cluster_name",
			value		=>	$an->data->{cgi}{anvil_cluster_name},
		}});
		
		# Anvil! IFN Gateway
		if (not $an->data->{sys}{install_manifest}{show}{ifn_network_fields})
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_ifn_gateway",
				id		=>	"anvil_ifn_gateway",
				value		=>	$an->data->{cgi}{anvil_ifn_gateway},
			}});
		}
		else
		{
			my $anvil_ifn_gateway_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names" }});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0188!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0092!#" : "#!string!explain_0092!#",
				name		=>	"anvil_ifn_gateway",
				id		=>	"anvil_ifn_gateway",
				value		=>	$an->data->{cgi}{anvil_ifn_gateway},
				star		=>	$an->data->{form}{anvil_ifn_gateway_star},
				more_info	=>	"$anvil_ifn_gateway_more_info",
			}});
		}
		
		# DNS
		if (not $an->data->{sys}{install_manifest}{show}{dns_fields})
		{
			# Anvil! Primary DNS
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_dns1",
				id		=>	"anvil_dns1",
				value		=>	$an->data->{cgi}{anvil_dns1},
			}});
			
			# Anvil! Secondary DNS
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_dns2",
				id		=>	"anvil_dns2",
				value		=>	$an->data->{cgi}{anvil_dns2},
			}});
		}
		else
		{
			# Anvil! Primary DNS
			my $anvil_dns1_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "http://en.wikipedia.org/wiki/Domain_Name_System" }});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0189!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0093!#" : "#!string!explain_0093!#",
				name		=>	"anvil_dns1",
				id		=>	"anvil_dns1",
				value		=>	$an->data->{cgi}{anvil_dns1},
				star		=>	$an->data->{form}{anvil_dns1_star},
				more_info	=>	"$anvil_dns1_more_info",
			}});
			
			# Anvil! Secondary DNS
			my $anvil_dns2_more_info = "";
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0190!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0094!#" : "#!string!explain_0094!#",
				name		=>	"anvil_dns2",
				id		=>	"anvil_dns2",
				value		=>	$an->data->{cgi}{anvil_dns2},
				star		=>	$an->data->{form}{anvil_dns2_star},
				more_info	=>	"$anvil_dns2_more_info",
			}});
		}
		
		# NTP
		if (not $an->data->{sys}{install_manifest}{show}{ntp_fields})
		{
			# Anvil! Primary NTP
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_ntp1",
				id		=>	"anvil_ntp1",
				value		=>	$an->data->{cgi}{anvil_ntp1},
			}});
			
			# Anvil! Secondary NTP
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_ntp2",
				id		=>	"anvil_ntp2",
				value		=>	$an->data->{cgi}{anvil_ntp2},
			}});
		}
		else
		{
			# Anvil! Primary NTP
			my $anvil_ntp1_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://en.wikipedia.org/wiki/Network_Time_Protocol" }});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0192!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0097!#" : "#!string!explain_0097!#",
				name		=>	"anvil_ntp1",
				id		=>	"anvil_ntp1",
				value		=>	$an->data->{cgi}{anvil_ntp1},
				star		=>	$an->data->{form}{anvil_ntp1_star},
				more_info	=>	"$anvil_ntp1_more_info",
			}});
			
			# Anvil! Secondary NTP
			my $anvil_ntp2_more_info = "";
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0193!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0098!#" : "#!string!explain_0098!#",
				name		=>	"anvil_ntp2",
				id		=>	"anvil_ntp2",
				value		=>	$an->data->{cgi}{anvil_ntp2},
				star		=>	$an->data->{form}{anvil_ntp2_star},
				more_info	=>	"$anvil_ntp2_more_info",
			}});
		}
		
		# Allows the user to set the MTU size manually
		if (1)
		{
			my $anvil_name_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://en.wikipedia.org/wiki/Maximum_transmission_unit" }});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
				row		=>	"#!string!row_0291!#",
				explain		=>	$an->data->{sys}{expert_ui} ? "#!string!terse_0156!#" : "#!string!explain_0156!#",
				name		=>	"anvil_mtu_size",
				id		=>	"anvil_mtu_size",
				value		=>	$an->data->{cgi}{anvil_mtu_size},
				star		=>	$an->data->{form}{anvil_mtu_size_star},
				more_info	=>	"$anvil_name_more_info",
			}});
		}
		else
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
				name		=>	"anvil_mtu_size",
				id		=>	"anvil_mtu_size",
				value		=>	$an->data->{cgi}{anvil_mtu_size},
			}});
		}
		
		# Now show the header for the Foundation pack section.
		print $an->Web->template({file => "config.html", template => "install-manifest-form-foundation-pack-header"});
		
		# Anvil! network switches
		foreach my $i (1, 2)
		{
			my $name_key         = "anvil_switch${i}_name";
			my $name_star_key    = "anvil_switch${i}_name_star";
			my $ip_key           = "anvil_switch${i}_ip";
			my $ip_star_key      = "anvil_switch${i}_ip_star";
			my $say_name_row     = "";
			my $say_name_explain = "";
			my $say_name_url     = "";
			my $say_ip_row       = "";
			my $say_ip_explain   = "";
			my $say_ip_url       = "";
			if ($i == 1)
			{
				$say_name_row     = "#!string!row_0178!#";
				$say_name_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0082!#" : "#!string!explain_0082!#";
				$say_name_url     = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_ip_row       = "#!string!row_0179!#";
				$say_ip_explain   = $an->data->{sys}{expert_ui} ? "#!string!terse_0083!#" : "#!string!explain_0083!#";
				$say_ip_url       = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Network_Switches";
			}
			elsif ($i == 2)
			{
				$say_name_row     = "#!string!row_0180!#";
				$say_name_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0084!#" : "#!string!explain_0084!#";
				$say_name_url     = "";
				$say_ip_row       = "#!string!row_0181!#";
				$say_ip_explain   = $an->data->{sys}{expert_ui} ? "#!string!terse_0085!#" : "#!string!explain_0085!#";
				$say_ip_url       = "";
			}
			
			# Switches
			if (not $an->data->{sys}{install_manifest}{show}{switch_fields})
			{
				# Switch name
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$an->data->{cgi}{$name_key},
				}});
				
				# Switch IP
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$an->data->{cgi}{$ip_key},
				}});
			}
			else
			{
				# Switch name
				my $network_switch_name_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_name_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_name_row",
					explain		=>	"$say_name_explain",
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$an->data->{cgi}{$name_key},
					star		=>	$an->data->{form}{$name_star_key},
					more_info	=>	"$network_switch_name_more_info",
				}});
				
				# Switch IP
				my $network_switch_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_ip_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_ip_row",
					explain		=>	"$say_ip_explain",
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$an->data->{cgi}{$ip_key},
					star		=>	$an->data->{form}{$ip_star_key},
					more_info	=>	"$network_switch_ip_more_info",
				}});
			}
		}
		
		# UPSes
		foreach my $i (1, 2)
		{
			my $name_key         = "anvil_ups${i}_name";
			my $name_star_key    = "anvil_ups${i}_name_star";
			my $ip_key           = "anvil_ups${i}_ip";
			my $ip_star_key      = "anvil_ups${i}_ip_star";
			my $say_name_row     = "";
			my $say_name_explain = "";
			my $say_name_url     = "";
			my $say_ip_row       = "";
			my $say_ip_explain   = "";
			my $say_ip_url       = "";
			if ($i == 1)
			{
				$say_name_row     = "#!string!row_0170!#";
				$say_name_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0074!#" : "#!string!explain_0074!#";
				$say_name_url     = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_ip_row       = "#!string!row_0171!#";
				$say_ip_explain   = $an->data->{sys}{expert_ui} ? "#!string!terse_0075!#" : "#!string!explain_0075!#";
				$say_ip_url       = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Network_Managed_UPSes_Are_Worth_It";
			}
			elsif ($i == 2)
			{
				$say_name_row     = "#!string!row_0172!#";
				$say_name_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0076!#" : "#!string!explain_0076!#";
				$say_name_url     = "";
				$say_ip_row       = "#!string!row_0173!#";
				$say_ip_explain   = $an->data->{sys}{expert_ui} ? "#!string!terse_0077!#" : "#!string!explain_0077!#";
				$say_ip_url       = "";
			}
			
			# UPSes
			if (not $an->data->{sys}{install_manifest}{show}{ups_fields})
			{
				# UPS name
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$an->data->{cgi}{$name_key},
				}});
				
				# UPS IP
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$an->data->{cgi}{$ip_key},
				}});
			}
			else
			{
				# UPS name
				my $network_ups_name_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_name_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_name_row",
					explain		=>	"$say_name_explain",
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$an->data->{cgi}{$name_key},
					star		=>	$an->data->{form}{$name_star_key},
					more_info	=>	"$network_ups_name_more_info",
				}});
				
				# UPS IP
				my $network_ups_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_ip_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_ip_row",
					explain		=>	"$say_ip_explain",
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$an->data->{cgi}{$ip_key},
					star		=>	$an->data->{form}{$ip_star_key},
					more_info	=>	"$network_ups_ip_more_info",
				}});
			}
		}
		
		# PTSes
		foreach my $i (1, 2)
		{
			my $name_key         = "anvil_pts${i}_name";
			my $name_star_key    = "anvil_pts${i}_name_star";
			my $ip_key           = "anvil_pts${i}_ip";
			my $ip_star_key      = "anvil_pts${i}_ip_star";
			my $say_name_row     = "";
			my $say_name_explain = "";
			my $say_name_url     = "";
			my $say_ip_row       = "";
			my $say_ip_explain   = "";
			my $say_ip_url       = "";
			if ($i == 1)
			{
				$say_name_row     = "#!string!row_0296!#";
				$say_name_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0162!#" : "#!string!explain_0162!#";
				$say_name_url     = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_ip_row       = "#!string!row_0297!#";
				$say_ip_explain   = $an->data->{sys}{expert_ui} ? "#!string!terse_0163!#" : "#!string!explain_0163!#";
				$say_ip_url       = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Network_Managed_PTSes_Are_Worth_It";
			}
			elsif ($i == 2)
			{
				$say_name_row     = "#!string!row_0298!#";
				$say_name_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0164!#" : "#!string!explain_0164!#";
				$say_name_url     = "";
				$say_ip_row       = "#!string!row_0299!#";
				$say_ip_explain   = $an->data->{sys}{expert_ui} ? "#!string!terse_0165!#" : "#!string!explain_0165!#";
				$say_ip_url       = "";
			}
			
			# PTSes
			if (not $an->data->{sys}{install_manifest}{show}{pts_fields})
			{
				# PTS name
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$an->data->{cgi}{$name_key},
				}});
				
				# PTS IP
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$an->data->{cgi}{$ip_key},
				}});
			}
			else
			{
				# PTS name
				my $network_pts_name_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_name_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_name_row",
					explain		=>	"$say_name_explain",
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$an->data->{cgi}{$name_key},
					star		=>	$an->data->{form}{$name_star_key},
					more_info	=>	"$network_pts_name_more_info",
				}});
				
				# PTS IP
				my $network_pts_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_ip_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_ip_row",
					explain		=>	"$say_ip_explain",
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$an->data->{cgi}{$ip_key},
					star		=>	$an->data->{form}{$ip_star_key},
					more_info	=>	"$network_pts_ip_more_info",
				}});
			}
		}
		
		# Ask the user which model of PDU they're using.
		my $say_apc     = $an->String->get({key => "brand_0017"});
		my $say_raritan = $an->String->get({key => "brand_0018"});
		
		# Build the two or four PDU form entries.
		foreach my $i (1..$an->data->{sys}{install_manifest}{pdu_count})
		{
			next if ($i > $an->data->{sys}{install_manifest}{pdu_count});
			my $pdu_name_key       = "anvil_pdu${i}_name";
			my $pdu_ip_key         = "anvil_pdu${i}_ip";
			my $pdu_star_name_key  = "anvil_pdu${i}_name_star";
			my $pdu_star_ip_key    = "anvil_pdu${i}_ip_star";
			my $pdu_agent_key      = "anvil_pdu${i}_agent";
			my $pdu_star_agent_key = "anvil_pdu${i}_agent_star";
			my $say_pdu            = "";
			my $say_name_explain   = "";
			my $say_ip_explain     = "";
			my $say_name_url       = "";
			my $say_ip_url         = "";
			my $say_agent_url      = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Defining_Fence_Devices";
			my $say_agent_explain  = "";
			
			# Set the agent to use the global default if not set already.
			$an->data->{cgi}{$pdu_agent_key} = $an->data->{sys}{install_manifest}{pdu_agent} if not $an->data->{cgi}{$pdu_agent_key};
			
			# Build the select.
			my $pdu_list  = ["fence_apc_snmp#!#$say_apc", "fence_raritan_snmp#!#$say_raritan"];
			my $pdu_model = build_select($an, "$pdu_agent_key", 0, 0, 220, $an->data->{cgi}{$pdu_agent_key}, $pdu_list);
			
			if ($i == 1)
			{
				$say_pdu           = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#"  : "#!string!device_0007!#";
				$say_name_explain  = $an->data->{sys}{expert_ui} ? "#!string!terse_0078!#" : "#!string!explain_0078!#";
				$say_name_url      = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_ip_explain    = $an->data->{sys}{expert_ui} ? "#!string!terse_0079!#" : "#!string!explain_0079!#";
				$say_ip_url        = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Why_Switched_PDUs.3F";
				$say_agent_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0150!#" : "#!string!explain_0150!#";
			}
			elsif ($i == 2)
			{
				$say_pdu           = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#";
				$say_name_explain  = $an->data->{sys}{expert_ui} ? "#!string!terse_0080!#" : "#!string!explain_0080!#";
				$say_ip_explain    = $an->data->{sys}{expert_ui} ? "#!string!terse_0081!#" : "#!string!explain_0081!#";
				$say_agent_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0151!#" : "#!string!explain_0151!#";
			}
			elsif ($i == 3)
			{
				$say_pdu           = "#!string!device_0009!#";
				$say_name_explain  = $an->data->{sys}{expert_ui} ? "#!string!terse_0146!#" : "#!string!explain_0146!#";
				$say_ip_explain    = $an->data->{sys}{expert_ui} ? "#!string!terse_0147!#" : "#!string!explain_0147!#";
				$say_agent_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0152!#" : "#!string!explain_0152!#";
			}
			elsif ($i == 4)
			{
				$say_pdu           = "#!string!device_0010!#";
				$say_name_explain  = $an->data->{sys}{expert_ui} ? "#!string!terse_0148!#" : "#!string!explain_0148!#";
				$say_ip_explain    = $an->data->{sys}{expert_ui} ? "#!string!terse_0149!#" : "#!string!explain_0149!#";
				$say_agent_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0153!#" : "#!string!explain_0153!#";
			}
			my $say_pdu_name  = $an->String->get({key => "row_0174", variables => { say_pdu => $say_pdu }});
			my $say_pdu_ip    = $an->String->get({key => "row_0175", variables => { say_pdu => $say_pdu }});
			my $say_pdu_agent = $an->String->get({key => "row_0177", variables => { say_pdu => $say_pdu }});
			
			# PDUs
			my $default_pdu_name_key = "pdu${i}_name";
			my $default_pdu_ip_key   = "pdu${i}_ip";
			if (($an->data->{sys}{install_manifest}{'default'}{$default_pdu_name_key}) && 
			    ($an->data->{sys}{install_manifest}{'default'}{$default_pdu_ip_key}) && 
			    (not $an->data->{sys}{install_manifest}{show}{pdu_fields}))
			{
				# PDU name
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$pdu_name_key",
					id		=>	"$pdu_name_key",
					value		=>	$an->data->{cgi}{$pdu_name_key},
				}});
				
				# PDU IP
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$pdu_ip_key",
					id		=>	"$pdu_ip_key",
					value		=>	$an->data->{cgi}{$pdu_ip_key},
				}});
				
				# PDU Brand
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$pdu_agent_key",
					id		=>	"$pdu_agent_key",
					value		=>	$an->data->{cgi}{$pdu_agent_key},
				}});
			}
			else
			{
				# PDU Name
				my $pdu_name_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_name_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_pdu_name",
					explain		=>	"$say_name_explain",
					name		=>	"$pdu_name_key",
					id		=>	"$pdu_name_key",
					value		=>	$an->data->{cgi}{$pdu_name_key},
					star		=>	$an->data->{form}{$pdu_star_name_key},
					more_info	=>	"$pdu_name_more_info",
				}});
				
				# PDU IP
				my $pdu_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_ip_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_pdu_ip",
					explain		=>	"$say_ip_explain",
					name		=>	"$pdu_ip_key",
					id		=>	"$pdu_ip_key",
					value		=>	$an->data->{cgi}{$pdu_ip_key},
					star		=>	$an->data->{form}{$pdu_star_ip_key},
					more_info	=>	"$pdu_ip_more_info",
				}});
				
				# PDU Brand
				my $pdu_agent_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_agent_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-select-entry", replace => { 
					row		=>	"$say_pdu_agent",
					explain		=>	"$say_agent_explain",
					'select'	=>	$pdu_model,
					star		=>	$an->data->{form}{$pdu_star_agent_key},
					more_info	=>	"$pdu_agent_more_info",
				}});
			}
		}
		
		# Dashboards
		foreach my $i (1, 2)
		{
			my $name_key           = "anvil_striker${i}_name";
			my $name_star_key      = "anvil_striker${i}_name_star";
			my $bcn_ip_key         = "anvil_striker${i}_bcn_ip";
			my $bcn_ip_star_key    = "anvil_striker${i}_bcn_ip_star";
			my $ifn_ip_key         = "anvil_striker${i}_ifn_ip";
			my $ifn_ip_star_key    = "anvil_striker${i}_ifn_ip_star";
			my $say_name_row       = "";
			my $say_name_explain   = "";
			my $say_name_url       = "";
			my $say_bcn_ip_row     = "";
			my $say_bcn_ip_explain = "";
			my $say_bcn_ip_url     = "";
			my $say_ifn_ip_row     = "";
			my $say_ifn_ip_explain = "";
			my $say_ifn_ip_url     = "";
			if ($i == 1)
			{
				$say_name_row       = "#!string!row_0182!#";
				$say_name_explain   = $an->data->{sys}{expert_ui} ? "#!string!terse_0086!#" : "#!string!explain_0086!#";
				$say_name_url       = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_bcn_ip_row     = "#!string!row_0183!#";
				$say_bcn_ip_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0087!#" : "#!string!explain_0087!#";
				$say_bcn_ip_url     = "https://alteeve.ca/w/Striker";
				$say_ifn_ip_row     = "#!string!row_0184!#";
				$say_ifn_ip_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0088!#" : "#!string!explain_0088!#";
				$say_ifn_ip_url     = "https://alteeve.ca/w/Striker";
			}
			elsif ($i == 2)
			{
				$say_name_row       = "#!string!row_0185!#";
				$say_name_explain   = $an->data->{sys}{expert_ui} ? "#!string!terse_0089!#" : "#!string!explain_0089!#";
				$say_name_url       = "";
				$say_bcn_ip_row     = "#!string!row_0186!#";
				$say_bcn_ip_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0090!#" : "#!string!explain_0090!#";
				$say_bcn_ip_url     = "";
				$say_ifn_ip_row     = "#!string!row_0187!#";
				$say_ifn_ip_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0091!#" : "#!string!explain_0091!#";
				$say_ifn_ip_url     = "";
			}
			
			# Dashboards
			if (not $an->data->{sys}{install_manifest}{show}{dashboard_fields})
			{
				# Striker name
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$an->data->{cgi}{$name_key},
				}});
				
				# Striker BCN IP
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$bcn_ip_key",
					id		=>	"$bcn_ip_key",
					value		=>	$an->data->{cgi}{$bcn_ip_key},
				}});
				
				# Striker IFN IP
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	"$ifn_ip_key",
					id		=>	"$ifn_ip_key",
					value		=>	$an->data->{cgi}{$ifn_ip_key},
				}});
			}
			else
			{
				# Striker name
				my $striker_name_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_name_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_name_row",
					explain		=>	"$say_name_explain",
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$an->data->{cgi}{$name_key},
					star		=>	$an->data->{form}{$name_star_key},
					more_info	=>	"$striker_name_more_info",
				}});
				
				# Striker BCN IP
				my $striker_bcn_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_bcn_ip_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_bcn_ip_row",
					explain		=>	"$say_bcn_ip_explain",
					name		=>	"$bcn_ip_key",
					id		=>	"$bcn_ip_key",
					value		=>	$an->data->{cgi}{$bcn_ip_key},
					star		=>	$an->data->{form}{$bcn_ip_star_key},
					more_info	=>	"$striker_bcn_ip_more_info",
				}});
				
				# Striker IFN IP
				my $striker_ifn_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => $say_ifn_ip_url }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"$say_ifn_ip_row",
					explain		=>	"$say_ifn_ip_explain",
					name		=>	"$ifn_ip_key",
					id		=>	"$ifn_ip_key",
					value		=>	$an->data->{cgi}{$ifn_ip_key},
					star		=>	$an->data->{form}{$ifn_ip_star_key},
					more_info	=>	"$striker_ifn_ip_more_info",
				}});
			}
		}
		
		# Spacer
		print $an->Web->template({file => "config.html", template => "install-manifest-form-spacer"});
		
		### Nodes are a little more complicated, too, as we might have
		### two or four PDUs that each node might be plugged into.
		foreach my $j (1, 2)
		{
			# Print the node header
			my $title = $an->String->get({key => "title_0152", variables => { node_number => $j }});
			print $an->Web->template({file => "config.html", template => "install-manifest-form-nodes-header", replace => { title => $title }});
			
			my $name_key        = "anvil_node${j}_name";
			my $explain_name    = "";
			my $explain_bcn_ip  = $an->data->{sys}{expert_ui} ? "#!string!terse_0070!#" : "#!string!explain_0070!#";
			my $explain_ipmi_ip = $an->data->{sys}{expert_ui} ? "#!string!terse_0073!#" : "#!string!explain_0073!#";
			my $explain_sn_ip   = $an->data->{sys}{expert_ui} ? "#!string!terse_0071!#" : "#!string!explain_0071!#";
			my $explain_ifn_ip  = $an->data->{sys}{expert_ui} ? "#!string!terse_0072!#" : "#!string!explain_0072!#";
			if ($j == 1)
			{
				$explain_name    = $an->data->{sys}{expert_ui} ? "#!string!terse_0068!#" : "#!string!explain_0068!#";
			}
			elsif ($j == 2)
			{
				$explain_name    = $an->data->{sys}{expert_ui} ? "#!string!terse_0069!#" : "#!string!explain_0069!#";
			}
			
			# Node's hostname
			my $anvil_node_name_key      = "anvil_node${j}_name";
			my $anvil_node_name_star_key = "anvil_node${j}_name_star";
			my $default_node_name_key    = "node${j}_name";
			if (($an->data->{sys}{install_manifest}{'default'}{$default_node_name_key}) && 
			    (not $an->data->{sys}{install_manifest}{show}{nodes_name_field}))
			{
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	$anvil_node_name_key,
					id		=>	$anvil_node_name_key,
					value		=>	$an->data->{cgi}{$anvil_node_name_key},
				}});
			}
			else
			{
				my $anvil_node_name_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names" }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"#!string!row_0165!#",
					explain		=>	$explain_name,
					name		=>	$anvil_node_name_key,
					id		=>	$anvil_node_name_key,
					value		=>	$an->data->{cgi}{$anvil_node_name_key},
					star		=>	$an->data->{form}{$anvil_node_name_star_key},
					more_info	=>	"$anvil_node_name_more_info",
				}});
			}
			
			# Node's BCN IP address
			my $anvil_node_bcn_ip_key      = "anvil_node${j}_bcn_ip";
			my $anvil_node_bcn_ip_star_key = "anvil_node${j}_bcn_ip_star";
			my $default_node_bcn_ip_key    = "node${j}_bcn_ip";
			if (($an->data->{sys}{install_manifest}{'default'}{$default_node_bcn_ip_key}) && 
			    (not $an->data->{sys}{install_manifest}{show}{nodes_bcn_field}))
			{
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	$anvil_node_bcn_ip_key,
					id		=>	$anvil_node_bcn_ip_key,
					value		=>	$an->data->{cgi}{$anvil_node_bcn_ip_key},
				}});
			}
			else
			{
				my $anvil_node_bcn_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Subnets" }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"#!string!row_0166!#",
					explain		=>	$explain_bcn_ip,
					name		=>	$anvil_node_bcn_ip_key,
					id		=>	$anvil_node_bcn_ip_key,
					value		=>	$an->data->{cgi}{$anvil_node_bcn_ip_key},
					star		=>	$an->data->{form}{$anvil_node_bcn_ip_star_key},
					more_info	=>	"$anvil_node_bcn_ip_more_info",
				}});
			}
			
			# Node's IPMI IP address
			my $anvil_node_ipmi_ip_key      = "anvil_node${j}_ipmi_ip";
			my $anvil_node_ipmi_ip_star_key = "anvil_node${j}_ipmi_ip_star";
			my $default_node_ipmi_ip_key    = "node${j}_ipmi_ip";
			if (($an->data->{sys}{install_manifest}{'default'}{$default_node_ipmi_ip_key}) && 
			    (not $an->data->{sys}{install_manifest}{show}{nodes_ipmi_field}))
			{
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	$anvil_node_ipmi_ip_key,
					id		=>	$anvil_node_ipmi_ip_key,
					value		=>	$an->data->{cgi}{$anvil_node_ipmi_ip_key},
				}});
			}
			else
			{
				my $anvil_node_ipmi_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#What_is_IPMI" }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"#!string!row_0168!#",
					explain		=>	$explain_ipmi_ip,
					name		=>	$anvil_node_ipmi_ip_key,
					id		=>	$anvil_node_ipmi_ip_key,
					value		=>	$an->data->{cgi}{$anvil_node_ipmi_ip_key},
					star		=>	$an->data->{form}{$anvil_node_ipmi_ip_star_key},
					more_info	=>	"$anvil_node_ipmi_ip_more_info",
				}});
			}
			
			# Node's SN IP address
			my $anvil_node_sn_ip_key      = "anvil_node${j}_sn_ip";
			my $anvil_node_sn_ip_star_key = "anvil_node${j}_sn_ip_star";
			my $default_node_sn_ip_key    = "node${j}_sn_ip";
			if (($an->data->{sys}{install_manifest}{'default'}{$default_node_sn_ip_key}) && 
			   (not $an->data->{sys}{install_manifest}{show}{nodes_sn_field}))
			{
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	$anvil_node_sn_ip_key,
					id		=>	$anvil_node_sn_ip_key,
					value		=>	$an->data->{cgi}{$anvil_node_sn_ip_key},
				}});
			}
			else
			{
				my $anvil_node_sn_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Subnets" }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"#!string!row_0167!#",
					explain		=>	$explain_sn_ip,
					name		=>	$anvil_node_sn_ip_key,
					id		=>	$anvil_node_sn_ip_key,
					value		=>	$an->data->{cgi}{$anvil_node_sn_ip_key},
					star		=>	$an->data->{form}{$anvil_node_sn_ip_star_key},
					more_info	=>	"$anvil_node_sn_ip_more_info",
				}});
			}
			
			# Node's IFN IP address
			my $anvil_node_ifn_ip_key      = "anvil_node${j}_ifn_ip";
			my $anvil_node_ifn_ip_star_key = "anvil_node${j}_ifn_ip_star";
			my $default_node_ifn_ip_key    = "node${j}_ifn_ip";
			if (($an->data->{sys}{install_manifest}{'default'}{$default_node_ifn_ip_key}) && 
			   (not $an->data->{sys}{install_manifest}{show}{nodes_ifn_field}))
			{
				print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
					name		=>	$anvil_node_ifn_ip_key,
					id		=>	$anvil_node_ifn_ip_key,
					value		=>	$an->data->{cgi}{$anvil_node_ifn_ip_key},
				}});
			}
			else
			{
				my $anvil_node_ifn_ip_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Subnets" }});
				print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
					row		=>	"#!string!row_0169!#",
					explain		=>	$explain_ifn_ip,
					name		=>	$anvil_node_ifn_ip_key,
					id		=>	$anvil_node_ifn_ip_key,
					value		=>	$an->data->{cgi}{$anvil_node_ifn_ip_key},
					star		=>	$an->data->{form}{$anvil_node_ifn_ip_star_key},
					more_info	=>	"$anvil_node_ifn_ip_more_info",
				}});
			}
			
			# Now we create an entry for each possible PDU (2 to 4).
			foreach my $i (1..4)
			{
				next if ($i > $an->data->{sys}{install_manifest}{pdu_count});
				my $say_pdu     = "";
				my $say_explain = "";
				if    ($i == 1)
				{
					$say_pdu     = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#"  : "#!string!device_0007!#";
					$say_explain = $an->data->{sys}{expert_ui} ? "#!string!terse_0096!#" : "#!string!explain_0096!#";
				}
				elsif ($i == 2)
				{
					$say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#";
				}
				elsif ($i == 3)
				{
					$say_pdu = "#!string!device_0009!#";
				}
				elsif ($i == 4)
				{
					$say_pdu = "#!string!device_0010!#";
				}
				my $say_pdu_name = $an->String->get({key => "row_0176", variables => { say_pdu => $say_pdu }});
				
				# PDU entry.
				my $pdu_outlet_key       = "anvil_node${j}_pdu${i}_outlet";
				my $pdu_outlet_star_key  = "anvil_node${j}_pdu${i}_outlet_star";
				if (not $an->data->{sys}{install_manifest}{show}{nodes_ifn_field})
				{
					print $an->Web->template({file => "config.html", template => "install-manifest-form-hidden-entry", replace => { 
						name		=>	$pdu_outlet_key,
						id		=>	$pdu_outlet_key,
						value		=>	$an->data->{cgi}{$pdu_outlet_key},
					}});
				}
				else
				{
					my $pdu_outlet_more_info = $an->data->{sys}{disable_links} ? "" : $an->Web->template({file => "config.html", template => "install-manifest-more-info-url", replace => { url => "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Why_Switched_PDUs.3F" }});
					print $an->Web->template({file => "config.html", template => "install-manifest-form-text-entry", replace => { 
						row		=>	"$say_pdu_name",
						explain		=>	$say_explain,
						name		=>	$pdu_outlet_key,
						id		=>	$pdu_outlet_key,
						value		=>	$an->data->{cgi}{$pdu_outlet_key},
						star		=>	$an->data->{form}{$pdu_outlet_star_key},
						more_info	=>	"$pdu_outlet_more_info",
					}});
				}
			}
			
			print $an->Web->template({file => "config.html", template => "install-manifest-form-nodes", replace => { 
				anvil_node2_name		=>	$an->data->{cgi}{anvil_node2_name},
				anvil_node2_name_star		=>	$an->data->{form}{anvil_node2_name_star},
				anvil_node2_bcn_ip		=>	$an->data->{cgi}{anvil_node2_bcn_ip},
				anvil_node2_bcn_ip_star		=>	$an->data->{form}{anvil_node2_bcn_ip_star},
				anvil_node2_ipmi_ip		=>	$an->data->{cgi}{anvil_node2_ipmi_ip},
				anvil_node2_ipmi_ip_star	=>	$an->data->{form}{anvil_node2_ipmi_ip_star},
				anvil_node2_sn_ip		=>	$an->data->{cgi}{anvil_node2_sn_ip},
				anvil_node2_sn_ip_star		=>	$an->data->{form}{anvil_node2_sn_ip_star},
				anvil_node2_ifn_ip		=>	$an->data->{cgi}{anvil_node2_ifn_ip},
				anvil_node2_ifn_ip_star		=>	$an->data->{form}{anvil_node2_ifn_ip_star},
				anvil_node2_pdu1_outlet		=>	$an->data->{cgi}{anvil_node2_pdu1_outlet},
				anvil_node2_pdu1_outlet_star	=>	$an->data->{form}{anvil_node2_pdu1_outlet_star},
				anvil_node2_pdu2_outlet		=>	$an->data->{cgi}{anvil_node2_pdu2_outlet},
				anvil_node2_pdu2_outlet_star	=>	$an->data->{form}{anvil_node2_pdu2_outlet_star},
				anvil_node2_pdu3_outlet		=>	$an->data->{cgi}{anvil_node2_pdu3_outlet},
				anvil_node2_pdu3_outlet_star	=>	$an->data->{form}{anvil_node2_pdu3_outlet_star},
				anvil_node2_pdu4_outlet		=>	$an->data->{cgi}{anvil_node2_pdu4_outlet},
				anvil_node2_pdu4_outlet_star	=>	$an->data->{form}{anvil_node2_pdu4_outlet_star},
			}});
		}
		
		# Footer.
		print $an->Web->template({file => "config.html", template => "install-manifest-form-footer"});
	}
	
	return(0);
}

# This parses this Striker dashboard's hostname and returns the prefix and
# domain name.
sub get_striker_prefix_and_domain
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_striker_prefix_and_domain" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($hostname) = $an->hostname();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "hostname", value1 => $hostname,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $default_prefix = "";
	if ($hostname =~ /^(\w+)-/)
	{
		$default_prefix = $1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "default_prefix", value1 => $default_prefix,
		}, file => $THIS_FILE, line => __LINE__});
	}
	my $default_domain = ($hostname =~ /\.(.*)$/)[0];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "default_prefix", value1 => $default_prefix,
		name2 => "default_domain", value2 => $default_domain,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the user has defined default prefix and/or domain, use them instead.
	if ($an->data->{sys}{install_manifest}{'default'}{prefix}) { $default_prefix = $an->data->{sys}{install_manifest}{'default'}{prefix}; }
	if ($an->data->{sys}{install_manifest}{'default'}{domain}) { $default_domain = $an->data->{sys}{install_manifest}{'default'}{domain}; }
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "default_prefix", value1 => $default_prefix,
		name2 => "default_domain", value2 => $default_domain,
	}, file => $THIS_FILE, line => __LINE__});
	return($default_prefix, $default_domain);
}

# This reads in the passed in install manifest file name and loads it into the
# appropriate cgi variables for use in the install manifest form.
sub load_install_manifest
{
	my ($an, $file) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "load_install_manifest" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "file", value1 => $file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Read in the install manifest file.
	my $manifest_file = $an->data->{path}{apache_manifests_dir}."/".$file;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "manifest_file", value1 => $manifest_file,
	}, file => $THIS_FILE, line => __LINE__});
	if (-e $manifest_file)
	{
		# Load it!
		my $xml  = XML::Simple->new();
		my $data = $xml->XMLin($manifest_file, KeyAttr => {node => 'name'}, ForceArray => 1);
		
		# Nodes.
		foreach my $node (keys %{$data->{node}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node", value1 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $a (keys %{$data->{node}{$node}})
			{
				if ($a eq "interfaces")
				{
					foreach my $b (keys %{$data->{node}{$node}{interfaces}->[0]})
					{
						foreach my $c (@{$data->{node}{$node}{interfaces}->[0]->{$b}})
						{
							my $name = $c->{name} ? $c->{name} : "";
							my $mac  = $c->{mac}  ? $c->{mac}  : "";
							$an->data->{install_manifest}{$file}{node}{$node}{interface}{$name}{mac} = "";
							if (($mac) && ($mac =~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i))
							{
								$an->data->{install_manifest}{$file}{node}{$node}{interface}{$name}{mac} = $mac;
							}
							elsif ($mac)
							{
								# Malformed MAC
								$an->Log->entry({log_level => 2, message_key => "log_0010", message_variables => {
									file => $file, 
									node => $node, 
									name => $name, 
									mac  => $mac, 
								}, file => $THIS_FILE, line => __LINE__});
							}
						}
					}
				}
				elsif ($a eq "network")
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "a", value1 => $a,
						name2 => "b", value2 => $data->{node}{$node}{network}->[0],
					}, file => $THIS_FILE, line => __LINE__});
					foreach my $network (keys %{$data->{node}{$node}{network}->[0]})
					{
						my $ip = $data->{node}{$node}{network}->[0]->{$network}->[0]->{ip};
						$an->data->{install_manifest}{$file}{node}{$node}{network}{$network}{ip} = $ip ? $ip : "";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "Node",    value1 => $node,
							name2 => "Network", value2 => $network,
							name3 => "IP",      value3 => $an->data->{install_manifest}{$file}{node}{$node}{network}{$network}{ip},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($a eq "pdu")
				{
					foreach my $b (@{$data->{node}{$node}{pdu}->[0]->{on}})
					{
						my $reference       = $b->{reference};
						my $name            = $b->{name};
						my $port            = $b->{port};
						my $user            = $b->{user};
						my $password        = $b->{password};
						my $password_script = $b->{password_script};
						
						$an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{name}            = $name            ? $name            : "";
						$an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{port}            = $port            ? $port            : ""; 
						$an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{user}            = $user            ? $user            : "";
						$an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password}        = $password        ? $password        : "";
						$an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password_script} = $password_script ? $password_script : "";
						$an->Log->entry({log_level => 4, message_key => "an_variables_0007", message_variables => {
							name1 => "Node",            value1 => $node,
							name2 => "PDU",             value2 => $reference,
							name3 => "Name",            value3 => $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{name},
							name4 => "Port",            value4 => $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{port},
							name5 => "User",            value5 => $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{user},
							name6 => "Password",        value6 => $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password},
							name7 => "Password Script", value7 => $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password_script},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($a eq "kvm")
				{
					foreach my $b (@{$data->{node}{$node}{kvm}->[0]->{on}})
					{
						my $reference       = $b->{reference};
						my $name            = $b->{name};
						my $port            = $b->{port};
						my $user            = $b->{user};
						my $password        = $b->{password};
						my $password_script = $b->{password_script};
						
						$an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{name}            = $name            ? $name            : "";
						$an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{port}            = $port            ? $port            : "";
						$an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{user}            = $user            ? $user            : "";
						$an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password}        = $password        ? $password        : "";
						$an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password_script} = $password_script ? $password_script : "";
						$an->Log->entry({log_level => 4, message_key => "an_variables_0007", message_variables => {
							name1 => "Node",            value1 => $node,
							name2 => "KVM",             value2 => $reference,
							name3 => "Name",            value3 => $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{name},
							name4 => "Port",            value4 => $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{port},
							name5 => "User",            value5 => $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{user},
							name6 => "Password",        value6 => $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password},
							name7 => "password_script", value7 => $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password_script},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($a eq "ipmi")
				{
					foreach my $b (@{$data->{node}{$node}{ipmi}->[0]->{on}})
					{
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "node",   value1 => $node,
							name2 => "ipmi b", value2 => $b,
						}, file => $THIS_FILE, line => __LINE__});
						foreach my $key (keys %{$b})
						{
							$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
								name1 => "node",         value1 => $node,
								name2 => "ipmi b",       value2 => $b,
								name3 => "key",          value3 => $key, 
								name4 => "\$b->{\$key}", value4 => $b->{$key}, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						my $reference       = $b->{reference};
						my $name            = $b->{name};
						my $ip              = $b->{ip};
						my $gateway         = $b->{gateway};
						my $netmask         = $b->{netmask};
						my $user            = $b->{user};
						my $password        = $b->{password};
						my $password_script = $b->{password_script};
						
						# If the password is more than
						# 16 characters long, truncate
						# it so that nodes with IPMI
						# v1.5 don't spazz out.
						$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
							name1 => "password", value1 => $password,
							name2 => "length",      value2 => length($password),
						}, file => $THIS_FILE, line => __LINE__});
						if (length($password) > 16)
						{
							$password = substr($password, 0, 16);
							$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
								name1 => "password", value1 => $password,
								name2 => "length",      value2 => length($password),
							}, file => $THIS_FILE, line => __LINE__});
						}
						
						$an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{name}            = $name            ? $name            : "";
						$an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{ip}              = $ip              ? $ip              : "";
						$an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{gateway}         = $gateway         ? $gateway         : "";
						$an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{netmask}         = $netmask         ? $netmask         : "";
						$an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{user}            = $user            ? $user            : "";
						$an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password}        = $password        ? $password        : "";
						$an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password_script} = $password_script ? $password_script : "";
						$an->Log->entry({log_level => 4, message_key => "an_variables_0009", message_variables => {
							name1 => "node",            value1 => $node,
							name2 => "ipmi",            value2 => $reference,
							name3 => "name",            value3 => $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{name},
							name4 => "IP",              value4 => $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{ip},
							name5 => "netmask",         value5 => $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{netmask}, 
							name6 => "gateway",         value6 => $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{gateway},
							name7 => "User",            value7 => $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{user},
							name8 => "Password",        value8 => $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password},
							name9 => "password_script", value9 => $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password_script},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($a eq "uuid")
				{
					my $uuid = $data->{node}{$node}{uuid};
					$an->data->{install_manifest}{$file}{node}{$node}{uuid} = $uuid ? $uuid : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "node",                                           value1 => $node,
						name2 => "uuid",                                           value2 => $uuid,
						name3 => "install_manifest::${file}::node::${node}::uuid", value3 => $an->data->{install_manifest}{$file}{node}{$node}{uuid},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# What's this?
					$an->Log->entry({log_level => 2, message_key => "log_0261", message_variables => {
						node    => $node, 
						file    => $file, 
						element => $b, 
					}, file => $THIS_FILE, line => __LINE__});
					foreach my $b (@{$data->{node}{$node}{$a}})
					{
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "- b",                               value1 => $b, 
							name2 => "data->node::${node}::${a}->[${b}]", value2 => $data->{node}{$node}{$a}->[$b],
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
		}
		
		# The common variables
		foreach my $a (@{$data->{common}})
		{
			foreach my $b (keys %{$a})
			{
				# Pull out and record the 'anvil'
				if ($b eq "anvil")
				{
					# Only ever one entry in the array 
					# reference, so we can safely 
					# dereference immediately.
					my $prefix           = $a->{$b}->[0]->{prefix};
					my $domain           = $a->{$b}->[0]->{domain};
					my $sequence         = $a->{$b}->[0]->{sequence};
					my $password         = $a->{$b}->[0]->{password};
					my $striker_user     = $a->{$b}->[0]->{striker_user};
					my $striker_database = $a->{$b}->[0]->{striker_database};
					$an->data->{install_manifest}{$file}{common}{anvil}{prefix}           = $prefix           ? $prefix           : "";
					$an->data->{install_manifest}{$file}{common}{anvil}{domain}           = $domain           ? $domain           : "";
					$an->data->{install_manifest}{$file}{common}{anvil}{sequence}         = $sequence         ? $sequence         : "";
					$an->data->{install_manifest}{$file}{common}{anvil}{password}         = $password         ? $password         : "";
					$an->data->{install_manifest}{$file}{common}{anvil}{striker_user}     = $striker_user     ? $striker_user     : "";
					$an->data->{install_manifest}{$file}{common}{anvil}{striker_database} = $striker_database ? $striker_database : "";
				}
				elsif ($b eq "cluster")
				{
					# Cluster Name
					my $name = $a->{$b}->[0]->{name};
					$an->data->{install_manifest}{$file}{common}{cluster}{name} = $name ? $name : "";
					
					# Fencing stuff
					my $post_join_delay = $a->{$b}->[0]->{fence}->[0]->{post_join_delay};
					my $order           = $a->{$b}->[0]->{fence}->[0]->{order};
					my $delay           = $a->{$b}->[0]->{fence}->[0]->{delay};
					my $delay_node      = $a->{$b}->[0]->{fence}->[0]->{delay_node};
					$an->data->{install_manifest}{$file}{common}{cluster}{fence}{post_join_delay} = $post_join_delay ? $post_join_delay : "";
					$an->data->{install_manifest}{$file}{common}{cluster}{fence}{order}           = $order           ? $order           : "";
					$an->data->{install_manifest}{$file}{common}{cluster}{fence}{delay}           = $delay           ? $delay           : "";
					$an->data->{install_manifest}{$file}{common}{cluster}{fence}{delay_node}      = $delay_node      ? $delay_node      : "";
				}
				### This is currently not used, may not have a
				### use-case in the future.
				elsif ($b eq "file")
				{
					foreach my $c (@{$a->{$b}})
					{
						my $name    = $c->{name};
						my $mode    = $c->{mode};
						my $owner   = $c->{owner};
						my $group   = $c->{group};
						my $content = $c->{content};
						
						$an->data->{install_manifest}{$file}{common}{file}{$name}{mode}    = $mode    ? $mode    : "";
						$an->data->{install_manifest}{$file}{common}{file}{$name}{owner}   = $owner   ? $owner   : "";
						$an->data->{install_manifest}{$file}{common}{file}{$name}{group}   = $group   ? $group   : "";
						$an->data->{install_manifest}{$file}{common}{file}{$name}{content} = $content ? $content : "";
					}
				}
				elsif ($b eq "iptables")
				{
					my $ports = $a->{$b}->[0]->{vnc}->[0]->{ports};
					$an->data->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports} = $ports ? $ports : 100;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "Firewall iptables; VNC port count", value1 => $an->data->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports},
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($b eq "servers")
				{
					# I may use this later for other things.
					#my $use_spice_graphics = $a->{$b}->[0]->{provision}->[0]->{use_spice_graphics};
					#$an->data->{install_manifest}{$file}{common}{cluster}{servers}{provision}{use_spice_graphics} = $use_spice_graphics ? $use_spice_graphics : "0";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "Server provisioning; Use spice graphics", value1 => $an->data->{install_manifest}{$file}{common}{cluster}{servers}{provision}{use_spice_graphics},
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($b eq "tools")
				{
					# Used to control which Anvil! tools are used and how to use them.
					my $anvil_safe_start   = $a->{$b}->[0]->{'use'}->[0]->{'anvil-safe-start'};
					my $anvil_kick_apc_ups = $a->{$b}->[0]->{'use'}->[0]->{'anvil-kick-apc-ups'};
					my $scancore           = $a->{$b}->[0]->{'use'}->[0]->{scancore};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "anvil-safe-start",   value1 => $anvil_safe_start,
						name2 => "anvil-kick-apc-ups", value2 => $anvil_kick_apc_ups,
						name3 => "scancore",           value3 => $scancore,
					}, file => $THIS_FILE, line => __LINE__});
					
					# Make sure we're using digits.
					$anvil_safe_start   =~ s/true/1/i;
					$anvil_safe_start   =~ s/yes/1/i;
					$anvil_safe_start   =~ s/false/0/i;
					$anvil_safe_start   =~ s/no/0/i;
					
					$anvil_kick_apc_ups =~ s/true/1/i;  
					$anvil_kick_apc_ups =~ s/yes/1/i;
					$anvil_kick_apc_ups =~ s/false/0/i; 
					$anvil_kick_apc_ups =~ s/no/0/i;
					
					$scancore           =~ s/true/1/i;  
					$scancore           =~ s/yes/1/i;
					$scancore           =~ s/false/0/i; 
					$scancore           =~ s/no/0/i;
					
					$an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-safe-start'}   = defined $anvil_safe_start   ? $anvil_safe_start   : $an->data->{sys}{install_manifest}{'default'}{'use_anvil-safe-start'};
					$an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} = defined $anvil_kick_apc_ups ? $anvil_kick_apc_ups : $an->data->{sys}{install_manifest}{'default'}{'use_anvil-kick-apc-ups'};
					$an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{scancore}             = defined $scancore           ? $scancore           : $an->data->{sys}{install_manifest}{'default'}{use_scancore};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "anvil-safe-start",   value1 => $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-safe-start'},
						name2 => "anvil-kick-apc-ups", value2 => $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'},
						name3 => "scancore",           value3 => $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{scancore},
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($b eq "media_library")
				{
					my $size  = $a->{$b}->[0]->{size};
					my $units = $a->{$b}->[0]->{units};
					$an->data->{install_manifest}{$file}{common}{media_library}{size}  = $size  ? $size  : "";
					$an->data->{install_manifest}{$file}{common}{media_library}{units} = $units ? $units : "";
				}
				elsif ($b eq "repository")
				{
					my $urls = $a->{$b}->[0]->{urls};
					$an->data->{install_manifest}{$file}{common}{anvil}{repositories} = $urls ? $urls : "";
				}
				elsif ($b eq "networks")
				{
					foreach my $c (keys %{$a->{$b}->[0]})
					{
						if ($c eq "bonding")
						{
							foreach my $d (keys %{$a->{$b}->[0]->{$c}->[0]})
							{
								if ($d eq "opts")
								{
									# Global bonding options.
									my $options = $a->{$b}->[0]->{$c}->[0]->{opts};
									$an->data->{install_manifest}{$file}{common}{network}{bond}{options} = $options ? $options : "";
									$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
										name1 => "Common bonding options", value1 => $an->data->{install_manifest}{$file}{common}{network}{bonds}{options},
									}, file => $THIS_FILE, line => __LINE__});
								}
								else
								{
									# Named network.
									my $name      = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{name};
									my $primary   = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{primary};
									my $secondary = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{secondary};
									$an->data->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{primary}   = $primary   ? $primary   : "";
									$an->data->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{secondary} = $secondary ? $secondary : "";
									$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
										name1 => "Bond",      value1 => $name,
										name2 => "Primary",   value2 => $an->data->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{primary},
										name3 => "Secondary", value3 => $an->data->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{secondary},
									}, file => $THIS_FILE, line => __LINE__});
								}
							}
						}
						elsif ($c eq "bridges")
						{
							foreach my $d (@{$a->{$b}->[0]->{$c}->[0]->{bridge}})
							{
								my $name = $d->{name};
								my $on   = $d->{on};
								$an->data->{install_manifest}{$file}{common}{network}{bridge}{$name}{on} = $on ? $on : "";
								$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
									name1 => "name",                                                            value1 => $name, 
									name2 => "install_manifest::${file}::common::network::bridge::${name}::on", value2 => $an->data->{install_manifest}{$file}{common}{network}{bridge}{$name}{on},
								}, file => $THIS_FILE, line => __LINE__});
							}
						}
						elsif ($c eq "mtu")
						{
							#<mtu size=\"".$an->data->{cgi}{anvil_mtu_size}."\" />
							my $size = $a->{$b}->[0]->{$c}->[0]->{size};
							$an->data->{install_manifest}{$file}{common}{network}{mtu}{size} = $size ? $size : 1500;
						}
						else
						{
							my $netblock     = $a->{$b}->[0]->{$c}->[0]->{netblock};
							my $netmask      = $a->{$b}->[0]->{$c}->[0]->{netmask};
							my $gateway      = $a->{$b}->[0]->{$c}->[0]->{gateway};
							my $defroute     = $a->{$b}->[0]->{$c}->[0]->{defroute};
							my $dns1         = $a->{$b}->[0]->{$c}->[0]->{dns1};
							my $dns2         = $a->{$b}->[0]->{$c}->[0]->{dns2};
							my $ntp1         = $a->{$b}->[0]->{$c}->[0]->{ntp1};
							my $ntp2         = $a->{$b}->[0]->{$c}->[0]->{ntp2};
							my $ethtool_opts = $a->{$b}->[0]->{$c}->[0]->{ethtool_opts};
							
							my $netblock_key     = "${c}_network";
							my $netmask_key      = "${c}_subnet";
							my $gateway_key      = "${c}_gateway";
							my $defroute_key     = "${c}_defroute";
							my $ethtool_opts_key = "${c}_ethtool_opts";
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{netblock}     = defined $netblock     ? $netblock     : $an->data->{sys}{install_manifest}{'default'}{$netblock_key};
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{netmask}      = defined $netmask      ? $netmask      : $an->data->{sys}{install_manifest}{'default'}{$netmask_key};
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{gateway}      = defined $gateway      ? $gateway      : $an->data->{sys}{install_manifest}{'default'}{$gateway_key};
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{defroute}     = defined $defroute     ? $defroute     : $an->data->{sys}{install_manifest}{'default'}{$defroute_key};
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{dns1}         = defined $dns1         ? $dns1         : "";
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{dns2}         = defined $dns2         ? $dns2         : "";
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{ntp1}         = defined $ntp1         ? $ntp1         : "";
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{ntp2}         = defined $ntp2         ? $ntp2         : "";
							$an->data->{install_manifest}{$file}{common}{network}{name}{$c}{ethtool_opts} = defined $ethtool_opts ? $ethtool_opts : $an->data->{sys}{install_manifest}{'default'}{$ethtool_opts_key};
							$an->Log->entry({log_level => 3, message_key => "an_variables_0010", message_variables => {
								name1  => "Network",      value1  => $c,
								name2  => "netblock",     value2  => $an->data->{install_manifest}{$file}{common}{network}{name}{bcn}{netblock},
								name3  => "netmask",      value3  => $an->data->{install_manifest}{$file}{common}{network}{name}{$c}{netmask},
								name4  => "gateway",      value4  => $an->data->{install_manifest}{$file}{common}{network}{name}{$c}{gateway},
								name5  => "defroute",     value5  => $an->data->{install_manifest}{$file}{common}{network}{name}{$c}{defroute},
								name6  => "dns1",         value6  => $an->data->{install_manifest}{$file}{common}{network}{name}{$c}{dns1},
								name7  => "dns2",         value7  => $an->data->{install_manifest}{$file}{common}{network}{name}{$c}{dns2},
								name8  => "ntp1",         value8  => $an->data->{install_manifest}{$file}{common}{network}{name}{$c}{ntp1},
								name9  => "ntp2",         value9  => $an->data->{install_manifest}{$file}{common}{network}{name}{$c}{ntp2},
								name10 => "ethtool_opts", value10 => $an->data->{install_manifest}{$file}{common}{network}{name}{$c}{ethtool_opts},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
				elsif ($b eq "drbd")
				{
					foreach my $c (keys %{$a->{$b}->[0]})
					{
						if ($c eq "disk")
						{
							my $disk_barrier = $a->{$b}->[0]->{$c}->[0]->{'disk-barrier'};
							my $disk_flushes = $a->{$b}->[0]->{$c}->[0]->{'disk-flushes'};
							my $md_flushes   = $a->{$b}->[0]->{$c}->[0]->{'md-flushes'};
							
							$an->data->{install_manifest}{$file}{common}{drbd}{disk}{'disk-barrier'} = defined $disk_barrier ? $disk_barrier : "";
							$an->data->{install_manifest}{$file}{common}{drbd}{disk}{'disk-flushes'} = defined $disk_flushes ? $disk_flushes : "";
							$an->data->{install_manifest}{$file}{common}{drbd}{disk}{'md-flushes'}   = defined $md_flushes   ? $md_flushes   : "";
						}
						elsif ($c eq "options")
						{
							my $cpu_mask = $a->{$b}->[0]->{$c}->[0]->{'cpu-mask'};
							$an->data->{install_manifest}{$file}{common}{drbd}{options}{'cpu-mask'} = defined $cpu_mask ? $cpu_mask : "";
						}
						elsif ($c eq "net")
						{
							my $max_buffers = $a->{$b}->[0]->{$c}->[0]->{'max-buffers'};
							my $sndbuf_size = $a->{$b}->[0]->{$c}->[0]->{'sndbuf-size'};
							my $rcvbuf_size = $a->{$b}->[0]->{$c}->[0]->{'rcvbuf-size'};
							$an->data->{install_manifest}{$file}{common}{drbd}{net}{'max-buffers'} = defined $max_buffers ? $max_buffers : "";
							$an->data->{install_manifest}{$file}{common}{drbd}{net}{'sndbuf-size'} = defined $sndbuf_size ? $sndbuf_size : "";
							$an->data->{install_manifest}{$file}{common}{drbd}{net}{'rcvbuf-size'} = defined $rcvbuf_size ? $rcvbuf_size : "";
						}
					}
				}
				elsif ($b eq "pdu")
				{
					foreach my $c (@{$a->{$b}->[0]->{pdu}})
					{
						my $reference       = $c->{reference};
						my $name            = $c->{name};
						my $ip              = $c->{ip};
						my $user            = $c->{user};
						my $password        = $c->{password};
						my $password_script = $c->{password_script};
						my $agent           = $c->{agent};
						
						$an->data->{install_manifest}{$file}{common}{pdu}{$reference}{name}            = $name            ? $name            : "";
						$an->data->{install_manifest}{$file}{common}{pdu}{$reference}{ip}              = $ip              ? $ip              : "";
						$an->data->{install_manifest}{$file}{common}{pdu}{$reference}{user}            = $user            ? $user            : "";
						$an->data->{install_manifest}{$file}{common}{pdu}{$reference}{password}        = $password        ? $password        : "";
						$an->data->{install_manifest}{$file}{common}{pdu}{$reference}{password_script} = $password_script ? $password_script : "";
						$an->data->{install_manifest}{$file}{common}{pdu}{$reference}{agent}           = $agent           ? $agent           : $an->data->{sys}{install_manifest}{pdu_agent};
						$an->Log->entry({log_level => 4, message_key => "an_variables_0007", message_variables => {
							name1 => "PDU reference",   value1 => $reference,
							name2 => "Name",            value2 => $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{name},
							name3 => "IP",              value3 => $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{ip},
							name4 => "user",            value4 => $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{user},
							name5 => "password",        value5 => $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{password},
							name6 => "password_script", value6 => $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{password_script},
							name7 => "agent",           value7 => $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{agent},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($b eq "kvm")
				{
					foreach my $c (@{$a->{$b}->[0]->{kvm}})
					{
						my $reference       = $c->{reference};
						my $name            = $c->{name};
						my $ip              = $c->{ip};
						my $user            = $c->{user};
						my $password        = $c->{password};
						my $password_script = $c->{password_script};
						my $agent           = $c->{agent};
						
						$an->data->{install_manifest}{$file}{common}{kvm}{$reference}{name}            = $name            ? $name            : "";
						$an->data->{install_manifest}{$file}{common}{kvm}{$reference}{ip}              = $ip              ? $ip              : "";
						$an->data->{install_manifest}{$file}{common}{kvm}{$reference}{user}            = $user            ? $user            : "";
						$an->data->{install_manifest}{$file}{common}{kvm}{$reference}{password}        = $password        ? $password        : "";
						$an->data->{install_manifest}{$file}{common}{kvm}{$reference}{password_script} = $password_script ? $password_script : "";
						$an->data->{install_manifest}{$file}{common}{kvm}{$reference}{agent}           = $agent           ? $agent           : "fence_virsh";
						$an->Log->entry({log_level => 4, message_key => "an_variables_0007", message_variables => {
							name1 => "KVM",             value1 => $reference,
							name2 => "Name",            value2 => $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{name},
							name3 => "IP",              value3 => $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{ip},
							name4 => "user",            value4 => $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{user},
							name5 => "password",        value5 => $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{password},
							name6 => "password_script", value6 => $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{password_script},
							name7 => "agent",           value7 => $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{agent},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($b eq "ipmi")
				{
					foreach my $c (@{$a->{$b}->[0]->{ipmi}})
					{
						my $reference       = $c->{reference};
						my $name            = $c->{name};
						my $ip              = $c->{ip};
						my $netmask         = $c->{netmask};
						my $gateway         = $c->{gateway};
						my $user            = $c->{user};
						my $password        = $c->{password};
						my $password_script = $c->{password_script};
						my $agent           = $c->{agent};
						
						$an->data->{install_manifest}{$file}{common}{namemi}{$reference}{name}          = $name            ? $name            : "";
						$an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{ip}              = $ip              ? $ip              : "";
						$an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{netmask}         = $netmask         ? $netmask         : "";
						$an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{gateway}         = $gateway         ? $gateway         : "";
						$an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{user}            = $user            ? $user            : "";
						$an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password}        = $password        ? $password        : "";
						$an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password_script} = $password_script ? $password_script : "";
						$an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{agent}           = $agent           ? $agent           : "fence_ipmilan";
						
						# If the password is more than 16 characters long, truncate
						# it so that nodes with IPMI v1.5 don't spazz out.
						$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
							name1 => "install_manifest::${file}::common::ipmi::${reference}::password", value1 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password},
							name2 => "length",                                                             value2 => ".length($an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password}).",
						}, file => $THIS_FILE, line => __LINE__});
						if (length($an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password}) > 16)
						{
							$an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password} = substr($an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password}, 0, 16);
							$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
								name1 => "install_manifest::${file}::common::ipmi::${reference}::password", value1 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password},
								name2 => "length",                                                             value2 => ".length($an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password}).",
							}, file => $THIS_FILE, line => __LINE__});
						}
						
						$an->Log->entry({log_level => 4, message_key => "an_variables_0009", message_variables => {
							name1 => "IPMI",            value1 => $reference,
							name2 => "Name",            value2 => $an->data->{install_manifest}{$file}{common}{namemi}{$reference}{name},
							name3 => "IP",              value3 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{ip},
							name4 => "Netmask",         value4 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{netmask},
							name5 => "Gateway",         value5 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{gateway},
							name6 => "user",            value6 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{user},
							name7 => "password",        value7 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password},
							name8 => "password_script", value8 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password_script},
							name9 => "agent",           value9 => $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{agent},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($b eq "ssh")
				{
					my $keysize = $a->{$b}->[0]->{keysize};
					$an->data->{install_manifest}{$file}{common}{ssh}{keysize} = $keysize ? $keysize : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "install_manifest::${file}::common::ssh::keysize", value1 => $an->data->{install_manifest}{$file}{common}{ssh}{keysize},
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($b eq "storage_pool_1")
				{
					my $size  = $a->{$b}->[0]->{size};
					my $units = $a->{$b}->[0]->{units};
					$an->data->{install_manifest}{$file}{common}{storage_pool}{1}{size}  = $size  ? $size  : "";
					$an->data->{install_manifest}{$file}{common}{storage_pool}{1}{units} = $units ? $units : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "install_manifest::${file}::common::storage_pool::1::size",  value1 => $an->data->{install_manifest}{$file}{common}{storage_pool}{1}{size},
						name2 => "install_manifest::${file}::common::storage_pool::1::units", value2 => $an->data->{install_manifest}{$file}{common}{storage_pool}{1}{units},
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($b eq "striker")
				{
					foreach my $c (@{$a->{$b}->[0]->{striker}})
					{
						my $name     = $c->{name};
						my $bcn_ip   = $c->{bcn_ip};
						my $ifn_ip   = $c->{ifn_ip};
						my $password = $c->{password};
						my $user     = $c->{user};
						my $database = $c->{database};
						
						$an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{bcn_ip}   = $bcn_ip   ? $bcn_ip   : "";
						$an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{ifn_ip}   = $ifn_ip   ? $ifn_ip   : "";
						$an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{password} = $password ? $password : "";
						$an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{user}     = $user     ? $user     : "";
						$an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{database} = $database ? $database : "";
						$an->Log->entry({log_level => 4, message_key => "an_variables_0006", message_variables => {
							name1 => "Striker",                                                             value1 => $name,
							name2 => "BCN IP",                                                              value2 => $an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{bcn_ip},
							name3 => "IFN IP",                                                              value3 => $an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{ifn_ip},
							name4 => "install_manifest${file}::common::striker::name::${name}::password",   value4 => $an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{password},
							name5 => "install_manifest::${file}::common::striker::name::${name}::user",     value5 => $an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{user},
							name6 => "install_manifest::${file}::common::striker::name::${name}::database", value6 => $an->data->{install_manifest}{$file}{common}{striker}{name}{$name}{database},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($b eq "switch")
				{
					foreach my $c (@{$a->{$b}->[0]->{switch}})
					{
						my $name = $c->{name};
						my $ip   = $c->{ip};
						$an->data->{install_manifest}{$file}{common}{switch}{$name}{ip} = $ip ? $ip : "";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "Switch", value1 => $name,
							name2 => "IP",     value2 => $an->data->{install_manifest}{$file}{common}{switch}{$name}{ip},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($b eq "update")
				{
					my $os = $a->{$b}->[0]->{os};
					$an->data->{install_manifest}{$file}{common}{update}{os} = $os ? $os : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "Update OS", value1 => $an->data->{install_manifest}{$file}{common}{update}{os},
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($b eq "ups")
				{
					foreach my $c (@{$a->{$b}->[0]->{ups}})
					{
						my $name = $c->{name};
						my $ip   = $c->{ip};
						my $type = $c->{type};
						my $port = $c->{port};
						$an->data->{install_manifest}{$file}{common}{ups}{$name}{ip}   = $ip   ? $ip   : "";
						$an->data->{install_manifest}{$file}{common}{ups}{$name}{type} = $type ? $type : "";
						$an->data->{install_manifest}{$file}{common}{ups}{$name}{port} = $port ? $port : "";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
							name1 => "UPS",  value1 => $name,
							name2 => "IP",   value2 => $an->data->{install_manifest}{$file}{common}{ups}{$name}{ip},
							name3 => "type", value3 => $an->data->{install_manifest}{$file}{common}{ups}{$name}{type},
							name4 => "port", value4 => $an->data->{install_manifest}{$file}{common}{ups}{$name}{port},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($b eq "pts")
				{
					foreach my $c (@{$a->{$b}->[0]->{pts}})
					{
						my $name = $c->{name};
						my $ip   = $c->{ip};
						my $type = $c->{type};
						my $port = $c->{port};
						$an->data->{install_manifest}{$file}{common}{pts}{$name}{ip}   = $ip   ? $ip   : "";
						$an->data->{install_manifest}{$file}{common}{pts}{$name}{type} = $type ? $type : "";
						$an->data->{install_manifest}{$file}{common}{pts}{$name}{port} = $port ? $port : "";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
							name1 => "UPS",  value1 => $name,
							name2 => "IP",   value2 => $an->data->{install_manifest}{$file}{common}{pts}{$name}{ip},
							name3 => "type", value3 => $an->data->{install_manifest}{$file}{common}{pts}{$name}{type},
							name4 => "port", value4 => $an->data->{install_manifest}{$file}{common}{pts}{$name}{port},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				else
				{
					# Extra element.
					$an->Log->entry({log_level => 2, message_key => "log_0033", message_variables => {
						file    => $file, 
						element => $b, 
						value   => $a->{$b}, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		
		# Load the common variables.
		$an->data->{cgi}{anvil_prefix}       = $an->data->{install_manifest}{$file}{common}{anvil}{prefix};
		$an->data->{cgi}{anvil_domain}       = $an->data->{install_manifest}{$file}{common}{anvil}{domain};
		$an->data->{cgi}{anvil_sequence}     = $an->data->{install_manifest}{$file}{common}{anvil}{sequence};
		$an->data->{cgi}{anvil_password}     = $an->data->{install_manifest}{$file}{common}{anvil}{password}         ? $an->data->{install_manifest}{$file}{common}{anvil}{password}         : $an->data->{sys}{install_manifest}{'default'}{password};
		$an->data->{cgi}{anvil_repositories} = $an->data->{install_manifest}{$file}{common}{anvil}{repositories};
		$an->data->{cgi}{anvil_ssh_keysize}  = $an->data->{install_manifest}{$file}{common}{ssh}{keysize}            ? $an->data->{install_manifest}{$file}{common}{ssh}{keysize}            : $an->data->{sys}{install_manifest}{'default'}{ssh_keysize};
		$an->data->{cgi}{anvil_mtu_size}     = $an->data->{install_manifest}{$file}{common}{network}{mtu}{size}      ? $an->data->{install_manifest}{$file}{common}{network}{mtu}{size}      : $an->data->{sys}{install_manifest}{'default'}{mtu_size};
		$an->data->{cgi}{striker_user}       = $an->data->{install_manifest}{$file}{common}{anvil}{striker_user}     ? $an->data->{install_manifest}{$file}{common}{anvil}{striker_user}     : $an->data->{sys}{install_manifest}{'default'}{striker_user};
		$an->data->{cgi}{striker_database}   = $an->data->{install_manifest}{$file}{common}{anvil}{striker_database} ? $an->data->{install_manifest}{$file}{common}{anvil}{striker_database} : $an->data->{sys}{install_manifest}{'default'}{striker_database};
		$an->Log->entry({log_level => 4, message_key => "an_variables_0007", message_variables => {
			name1 => "cgi::anvil_prefix",       value1 => $an->data->{cgi}{anvil_prefix},
			name2 => "cgi::anvil_domain",       value2 => $an->data->{cgi}{anvil_domain},
			name3 => "cgi::anvil_sequence",     value3 => $an->data->{cgi}{anvil_sequence},
			name4 => "cgi::anvil_password",     value4 => $an->data->{cgi}{anvil_password},
			name5 => "cgi::anvil_repositories", value5 => $an->data->{cgi}{anvil_repositories},
			name6 => "cgi::anvil_ssh_keysize",  value6 => $an->data->{cgi}{anvil_ssh_keysize},
			name7 => "cgi::striker_database",   value7 => $an->data->{cgi}{striker_database},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Media Library values
		$an->data->{cgi}{anvil_media_library_size} = $an->data->{install_manifest}{$file}{common}{media_library}{size};
		$an->data->{cgi}{anvil_media_library_unit} = $an->data->{install_manifest}{$file}{common}{media_library}{units};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_media_library_size", value1 => $an->data->{cgi}{anvil_media_library_size},
			name2 => "cgi::anvil_media_library_unit", value2 => $an->data->{cgi}{anvil_media_library_unit},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Networks
		$an->data->{cgi}{anvil_bcn_ethtool_opts} = $an->data->{install_manifest}{$file}{common}{network}{name}{bcn}{ethtool_opts};
		$an->data->{cgi}{anvil_bcn_network}      = $an->data->{install_manifest}{$file}{common}{network}{name}{bcn}{netblock};
		$an->data->{cgi}{anvil_bcn_subnet}       = $an->data->{install_manifest}{$file}{common}{network}{name}{bcn}{netmask};
		$an->data->{cgi}{anvil_sn_ethtool_opts}  = $an->data->{install_manifest}{$file}{common}{network}{name}{sn}{ethtool_opts};
		$an->data->{cgi}{anvil_sn_network}       = $an->data->{install_manifest}{$file}{common}{network}{name}{sn}{netblock};
		$an->data->{cgi}{anvil_sn_subnet}        = $an->data->{install_manifest}{$file}{common}{network}{name}{sn}{netmask};
		$an->data->{cgi}{anvil_ifn_ethtool_opts} = $an->data->{install_manifest}{$file}{common}{network}{name}{ifn}{ethtool_opts};
		$an->data->{cgi}{anvil_ifn_network}      = $an->data->{install_manifest}{$file}{common}{network}{name}{ifn}{netblock};
		$an->data->{cgi}{anvil_ifn_subnet}       = $an->data->{install_manifest}{$file}{common}{network}{name}{ifn}{netmask};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
			name1 => "cgi::anvil_bcn_ethtool_opts", value1 => $an->data->{cgi}{anvil_bcn_ethtool_opts},
			name2 => "cgi::anvil_bcn_network",      value2 => $an->data->{cgi}{anvil_bcn_network},
			name3 => "cgi::anvil_bcn_subnet",       value3 => $an->data->{cgi}{anvil_bcn_subnet},
			name4 => "cgi::anvil_sn_ethtool_opts",  value4 => $an->data->{cgi}{anvil_sn_ethtool_opts},
			name5 => "cgi::anvil_sn_network",       value5 => $an->data->{cgi}{anvil_sn_network},
			name6 => "cgi::anvil_sn_subnet",        value6 => $an->data->{cgi}{anvil_sn_subnet},
			name7 => "cgi::anvil_ifn_ethtool_opts", value7 => $an->data->{cgi}{anvil_ifn_ethtool_opts},
			name8 => "cgi::anvil_ifn_network",      value8 => $an->data->{cgi}{anvil_ifn_network},
			name9 => "cgi::anvil_ifn_subnet",       value9 => $an->data->{cgi}{anvil_ifn_subnet},
		}, file => $THIS_FILE, line => __LINE__});
		
		# iptables
		$an->data->{cgi}{anvil_open_vnc_ports} = $an->data->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_open_vnc_ports", value1 => $an->data->{cgi}{anvil_open_vnc_ports},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Storage Pool 1
		$an->data->{cgi}{anvil_storage_pool1_size} = $an->data->{install_manifest}{$file}{common}{storage_pool}{1}{size};
		$an->data->{cgi}{anvil_storage_pool1_unit} = $an->data->{install_manifest}{$file}{common}{storage_pool}{1}{units};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_storage_pool1_size", value1 => $an->data->{cgi}{anvil_storage_pool1_size},
			name2 => "cgi::anvil_storage_pool1_unit", value2 => $an->data->{cgi}{anvil_storage_pool1_unit},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Tools
		$an->data->{sys}{install_manifest}{'use_anvil-safe-start'}   = defined $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-safe-start'}   ? $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-safe-start'}   : $an->data->{sys}{install_manifest}{'default'}{'use_anvil-safe-start'};
		$an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'} = defined $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} ? $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} : $an->data->{sys}{install_manifest}{'default'}{'use_anvil-kick-apc-ups'};
		$an->data->{sys}{install_manifest}{use_scancore}             = defined $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{scancore}             ? $an->data->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{scancore}             : $an->data->{sys}{install_manifest}{'default'}{use_scancore};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "sys::install_manifest::use_anvil-safe-start",   value1 => $an->data->{sys}{install_manifest}{'use_anvil-safe-start'},
			name2 => "sys::install_manifest::use_anvil-kick-apc-ups", value2 => $an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'},
			name3 => "sys::install_manifest::use_scancore",           value3 => $an->data->{sys}{install_manifest}{use_scancore},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Shared Variables
		$an->data->{cgi}{anvil_name}        = $an->data->{install_manifest}{$file}{common}{cluster}{name};
		$an->data->{cgi}{anvil_ifn_gateway} = $an->data->{install_manifest}{$file}{common}{network}{name}{ifn}{gateway};
		$an->data->{cgi}{anvil_dns1}        = $an->data->{install_manifest}{$file}{common}{network}{name}{ifn}{dns1};
		$an->data->{cgi}{anvil_dns2}        = $an->data->{install_manifest}{$file}{common}{network}{name}{ifn}{dns2};
		$an->data->{cgi}{anvil_ntp1}        = $an->data->{install_manifest}{$file}{common}{network}{name}{ifn}{ntp1};
		$an->data->{cgi}{anvil_ntp2}        = $an->data->{install_manifest}{$file}{common}{network}{name}{ifn}{ntp2};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
			name1 => "cgi::anvil_name",        value1 => $an->data->{cgi}{anvil_name},
			name2 => "cgi::anvil_ifn_gateway", value2 => $an->data->{cgi}{anvil_ifn_gateway},
			name3 => "cgi::anvil_dns1",        value3 => $an->data->{cgi}{anvil_dns1},
			name4 => "cgi::anvil_dns2",        value4 => $an->data->{cgi}{anvil_dns2},
			name5 => "cgi::anvil_ntp1",        value5 => $an->data->{cgi}{anvil_ntp1},
			name6 => "cgi::anvil_ntp2",        value6 => $an->data->{cgi}{anvil_ntp2},
		}, file => $THIS_FILE, line => __LINE__});
		
		# DRBD variables
		$an->Log->entry({log_level => 3, message_key => "an_variables_0014", message_variables => {
			name1  => "install_manifest::${file}::common::drbd::disk::disk-barrier",  value1  => $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'disk-barrier'},
			name2  => "sys::install_manifest::default::anvil_drbd_disk_disk-barrier", value2  => $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-barrier'},
			name3  => "install_manifest::${file}::common::drbd::disk::disk-flushes",  value3  => $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'disk-flushes'},
			name4  => "sys::install_manifest::default::anvil_drbd_disk_disk-flushes", value4  => $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-flushes'},
			name5  => "install_manifest::${file}::common::drbd::disk::md-flushes",    value5  => $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'md-flushes'},
		  	name6  => "sys::install_manifest::default::anvil_drbd_disk_md-flushes",   value6  => $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_md-flushes'},
			name7  => "install_manifest::${file}::common::drbd::options::cpu-mask",   value7  => $an->data->{install_manifest}{$file}{common}{drbd}{options}{'cpu-mask'},
			name8  => "sys::install_manifest::default::anvil_drbd_options_cpu-mask",  value8  => $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_options_cpu-mask'},
			name9  => "install_manifest::${file}::common::drbd::net::max-buffers",    value9  => $an->data->{install_manifest}{$file}{common}{drbd}{net}{'max-buffers'},
			name10 => "sys::install_manifest::default::anvil_drbd_net_max-buffers",   value10 => $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_max-buffers'},
			name11 => "install_manifest::${file}::common::drbd::net::sndbuf-size",    value11 => $an->data->{install_manifest}{$file}{common}{drbd}{net}{'sndbuf-size'},
			name12 => "sys::install_manifest::default::anvil_drbd_net_sndbuf-size",   value12 => $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_sndbuf-size'},
			name13 => "install_manifest::${file}::common::drbd::net::rcvbuf-size",    value13 => $an->data->{install_manifest}{$file}{common}{drbd}{net}{'rcvbuf-size'},
			name14 => "sys::install_manifest::default::anvil_drbd_net_rcvbuf-size",   value14 => $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_rcvbuf-size'},
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} = defined $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'disk-barrier'}    ? $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'disk-barrier'}    : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-barrier'};
		$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} = defined $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'disk-flushes'}    ? $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'disk-flushes'}    : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-flushes'};
		$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   = defined $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'md-flushes'}      ? $an->data->{install_manifest}{$file}{common}{drbd}{disk}{'md-flushes'}      : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_md-flushes'};
		$an->data->{cgi}{'anvil_drbd_options_cpu-mask'}  = defined $an->data->{install_manifest}{$file}{common}{drbd}{options}{'cpu-mask'}     ? $an->data->{install_manifest}{$file}{common}{drbd}{options}{'cpu-mask'}     : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_options_cpu-mask'};
		$an->data->{cgi}{'anvil_drbd_net_max-buffers'}   = defined $an->data->{install_manifest}{$file}{common}{drbd}{net}{'max-buffers'}      ? $an->data->{install_manifest}{$file}{common}{drbd}{net}{'max-buffers'}      : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_max-buffers'};
		$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}   = defined $an->data->{install_manifest}{$file}{common}{drbd}{net}{'sndbuf-size'}      ? $an->data->{install_manifest}{$file}{common}{drbd}{net}{'sndbuf-size'}      : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_sndbuf-size'};
		$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}   = defined $an->data->{install_manifest}{$file}{common}{drbd}{net}{'rcvbuf-size'}      ? $an->data->{install_manifest}{$file}{common}{drbd}{net}{'rcvbuf-size'}      : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_rcvbuf-size'};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "cgi::anvil_drbd_disk_disk-barrier", value1 => $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
			name2 => "cgi::anvil_drbd_disk_disk-flushes", value2 => $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
			name3 => "cgi::anvil_drbd_disk_md-flushes",   value3 => $an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
			name4 => "cgi::anvil_drbd_options_cpu-mask",  value4 => $an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
			name5 => "cgi::anvil_drbd_net_max-buffers",   value5 => $an->data->{cgi}{'anvil_drbd_net_max-buffers'},
			name6 => "cgi::anvil_drbd_net_sndbuf-size",   value6 => $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
			name7 => "cgi::anvil_drbd_net_rcvbuf-size",   value7 => $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
		}, file => $THIS_FILE, line => __LINE__});
		
		### Foundation Pack
		# Switches
		my $i = 1;
		foreach my $switch (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{common}{switch}})
		{
			my $name_key = "anvil_switch".$i."_name";
			my $ip_key   = "anvil_switch".$i."_ip";
			$an->data->{cgi}{$name_key} = $switch;
			$an->data->{cgi}{$ip_key}   = $an->data->{install_manifest}{$file}{common}{switch}{$switch}{ip};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "Switch",    value1 => $switch,
				name2 => "name_key",  value2 => $name_key,
				name3 => "ip_key",    value3 => $ip_key,
				name4 => "CGI; Name", value4 => $an->data->{cgi}{$name_key},
				name5 => "IP",        value5 => $an->data->{cgi}{$ip_key},
			}, file => $THIS_FILE, line => __LINE__});
			$i++;
		}
		# PDUs
		$i = 1;
		foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{common}{pdu}})
		{
			my $name_key = "anvil_pdu".$i."_name";
			my $ip_key   = "anvil_pdu".$i."_ip";
			my $name     = $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{name};
			my $ip       = $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{ip};
			$an->data->{cgi}{$name_key} = $name ? $name : "";
			$an->data->{cgi}{$ip_key}   = $ip   ? $ip   : "";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "PDU reference", value1 => $reference,
				name2 => "name_key",      value2 => $name_key,
				name3 => "ip_key",        value3 => $ip_key,
				name4 => "CGI; Name",     value4 => $an->data->{cgi}{$name_key},
				name5 => "IP",            value5 => $an->data->{cgi}{$ip_key},
			}, file => $THIS_FILE, line => __LINE__});
			$i++;
		}
		# UPSes
		$i = 1;
		foreach my $ups (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{common}{ups}})
		{
			my $name_key = "anvil_ups".$i."_name";
			my $ip_key   = "anvil_ups".$i."_ip";
			$an->data->{cgi}{$name_key} = $ups;
			$an->data->{cgi}{$ip_key}   = $an->data->{install_manifest}{$file}{common}{ups}{$ups}{ip};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "UPS",       value1 => $ups,
				name2 => "name_key",  value2 => $name_key,
				name3 => "ip_key",    value3 => $ip_key,
				name4 => "CGI; Name", value4 => $an->data->{cgi}{$name_key},
				name5 => "IP",        value5 => $an->data->{cgi}{$ip_key},
			}, file => $THIS_FILE, line => __LINE__});
			$i++;
		}
		# PTSes
		$i = 1;
		foreach my $pts (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{common}{pts}})
		{
			my $name_key = "anvil_pts".$i."_name";
			my $ip_key   = "anvil_pts".$i."_ip";
			$an->data->{cgi}{$name_key} = $pts;
			$an->data->{cgi}{$ip_key}   = $an->data->{install_manifest}{$file}{common}{pts}{$pts}{ip};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "PTS",       value1 => $pts,
				name2 => "name_key",  value2 => $name_key,
				name3 => "ip_key",    value3 => $ip_key,
				name4 => "CGI; Name", value4 => $an->data->{cgi}{$name_key},
				name5 => "IP",        value5 => $an->data->{cgi}{$ip_key},
			}, file => $THIS_FILE, line => __LINE__});
			$i++;
		}
		# Striker Dashboards
		$i = 1;
		foreach my $striker (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{common}{striker}{name}})
		{
			my $name_key     =  "anvil_striker".$i."_name";
			my $bcn_ip_key   =  "anvil_striker".$i."_bcn_ip";
			my $ifn_ip_key   =  "anvil_striker".$i."_ifn_ip";
			my $user_key     =  "anvil_striker".$i."_user";
			my $password_key =  "anvil_striker".$i."_password";
			my $database_key =  "anvil_striker".$i."_database";
			$an->data->{cgi}{$name_key}     = $striker;
			$an->data->{cgi}{$bcn_ip_key}   = $an->data->{install_manifest}{$file}{common}{striker}{name}{$striker}{bcn_ip};
			$an->data->{cgi}{$ifn_ip_key}   = $an->data->{install_manifest}{$file}{common}{striker}{name}{$striker}{ifn_ip};
			$an->data->{cgi}{$user_key}     = $an->data->{install_manifest}{$file}{common}{striker}{name}{$striker}{user}     ? $an->data->{install_manifest}{$file}{common}{striker}{name}{$striker}{user}     : $an->data->{cgi}{striker_user};
			$an->data->{cgi}{$password_key} = $an->data->{install_manifest}{$file}{common}{striker}{name}{$striker}{password} ? $an->data->{install_manifest}{$file}{common}{striker}{name}{$striker}{password} : $an->data->{cgi}{anvil_password};
			$an->data->{cgi}{$database_key} = $an->data->{install_manifest}{$file}{common}{striker}{name}{$striker}{database} ? $an->data->{install_manifest}{$file}{common}{striker}{name}{$striker}{database} : $an->data->{cgi}{striker_database};
			$an->Log->entry({log_level => 4, message_key => "an_variables_0006", message_variables => {
				name1 => "cgi::$name_key",     value1 => $an->data->{cgi}{$name_key},
				name2 => "cgi::$bcn_ip_key",   value2 => $an->data->{cgi}{$bcn_ip_key},
				name3 => "cgi::$ifn_ip_key",   value3 => $an->data->{cgi}{$ifn_ip_key},
				name4 => "cgi::$user_key",     value4 => $an->data->{cgi}{$user_key},
				name5 => "cgi::$password_key", value5 => $an->data->{cgi}{$password_key},
				name6 => "cgi::$database_key", value6 => $an->data->{cgi}{$database_key},
			}, file => $THIS_FILE, line => __LINE__});
			$i++;
		}
		
		### Now the Nodes.
		$i = 1;
		foreach my $node (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{node}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "i",    value1 => $i,
				name2 => "node", value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my $name_key          = "anvil_node".$i."_name";
			my $bcn_ip_key        = "anvil_node".$i."_bcn_ip";
			my $bcn_link1_mac_key = "anvil_node".$i."_bcn_link1_mac";
			my $bcn_link2_mac_key = "anvil_node".$i."_bcn_link2_mac";
			my $sn_ip_key         = "anvil_node".$i."_sn_ip";
			my $sn_link1_mac_key  = "anvil_node".$i."_sn_link1_mac";
			my $sn_link2_mac_key  = "anvil_node".$i."_sn_link2_mac";
			my $ifn_ip_key        = "anvil_node".$i."_ifn_ip";
			my $ifn_link1_mac_key = "anvil_node".$i."_ifn_link1_mac";
			my $ifn_link2_mac_key = "anvil_node".$i."_ifn_link2_mac";
			my $uuid_key          = "anvil_node".$i."_uuid";
			
			my $ipmi_ip_key       = "anvil_node".$i."_ipmi_ip";
			my $ipmi_netmask_key  = "anvil_node".$i."_ipmi_netmask",
			my $ipmi_gateway_key  = "anvil_node".$i."_ipmi_gateway",
			my $ipmi_password_key = "anvil_node".$i."_ipmi_password",
			my $ipmi_user_key     = "anvil_node".$i."_ipmi_user",
			my $pdu1_key          = "anvil_node".$i."_pdu1_outlet";
			my $pdu2_key          = "anvil_node".$i."_pdu2_outlet";
			my $pdu3_key          = "anvil_node".$i."_pdu3_outlet";
			my $pdu4_key          = "anvil_node".$i."_pdu4_outlet";
			
			# IPMI is, by default, tempremental about passwords. If the manifest doesn't specify 
			# the password to use, we'll copy the cluster password but then strip out special 
			# characters and shorten it to 16 characters or less.
			my $default_ipmi_pw =  $an->data->{cgi}{anvil_password};
			   $default_ipmi_pw =~ s/!//g;
			if (length($default_ipmi_pw) > 16)
			{
				$default_ipmi_pw = substr($default_ipmi_pw, 0, 16);
			}
			
			# Find the IPMI, PDU and KVM reference names
			my $ipmi_reference = "";
			my $pdu1_reference = "";
			my $pdu2_reference = "";
			my $pdu3_reference = "";
			my $pdu4_reference = "";
			my $kvm_reference  = "";
			foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{node}{$node}{ipmi}})
			{
				# There should only be one entry
				$ipmi_reference = $reference;
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "ipmi_reference", value1 => $ipmi_reference,
			}, file => $THIS_FILE, line => __LINE__});
			my $j = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "j",                                             value1 => $j,
				name2 => "install_manifest::${file}::node::${node}::pdu", value2 => $an->data->{install_manifest}{$file}{node}{$node}{pdu},
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{node}{$node}{pdu}})
			{
				# There should be two or four PDUs
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "j",         value1 => $j,
					name2 => "reference", value2 => $reference,
				}, file => $THIS_FILE, line => __LINE__});
				if ($j == 1)
				{
					$pdu1_reference = $reference;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pdu1_reference", value1 => $pdu1_reference,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($j == 2)
				{
					$pdu2_reference = $reference;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pdu2_reference", value1 => $pdu2_reference,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($j == 3)
				{
					$pdu3_reference = $reference;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pdu3_reference", value1 => $pdu3_reference,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($j == 4)
				{
					$pdu4_reference = $reference;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pdu4_reference", value1 => $pdu4_reference,
					}, file => $THIS_FILE, line => __LINE__});
				}
				$j++;
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "pdu1_reference", value1 => $pdu1_reference,
				name2 => "pdu2_reference", value2 => $pdu2_reference,
				name3 => "pdu3_reference", value3 => $pdu3_reference,
				name4 => "pdu4_reference", value4 => $pdu4_reference,
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{node}{$node}{kvm}})
			{
				# There should only be one entry
				$kvm_reference = $reference;
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "kvm_reference", value1 => $kvm_reference,
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{cgi}{$name_key}          = $node;
			$an->data->{cgi}{$bcn_ip_key}        = $an->data->{install_manifest}{$file}{node}{$node}{network}{bcn}{ip};
			$an->data->{cgi}{$sn_ip_key}         = $an->data->{install_manifest}{$file}{node}{$node}{network}{sn}{ip};
			$an->data->{cgi}{$ifn_ip_key}        = $an->data->{install_manifest}{$file}{node}{$node}{network}{ifn}{ip};
			
			$an->data->{cgi}{$ipmi_ip_key}       = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{ip};
			$an->data->{cgi}{$ipmi_netmask_key}  = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{netmask}  ? $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{netmask}  : $an->data->{cgi}{anvil_bcn_subnet};
			$an->data->{cgi}{$ipmi_gateway_key}  = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{gateway}  ? $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{gateway}  : "";
			$an->data->{cgi}{$ipmi_password_key} = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{password} ? $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{password} : $default_ipmi_pw;
			$an->data->{cgi}{$ipmi_user_key}     = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{user}     ? $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{user}     : "admin";
			$an->data->{cgi}{$pdu1_key}          = $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$pdu1_reference}{port};
			$an->data->{cgi}{$pdu2_key}          = $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$pdu2_reference}{port};
			$an->data->{cgi}{$pdu3_key}          = $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$pdu3_reference}{port};
			$an->data->{cgi}{$pdu4_key}          = $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$pdu4_reference}{port};
			$an->data->{cgi}{$uuid_key}          = $an->data->{install_manifest}{$file}{node}{$node}{uuid}                            ? $an->data->{install_manifest}{$file}{node}{$node}{uuid}                            : "";
			$an->Log->entry({log_level => 4, message_key => "an_variables_0014", message_variables => {
				name1  => "cgi::$name_key",          value1  => $an->data->{cgi}{$name_key},
				name2  => "cgi::$bcn_ip_key",        value2  => $an->data->{cgi}{$bcn_ip_key},
				name3  => "cgi::$ipmi_ip_key",       value3  => $an->data->{cgi}{$ipmi_ip_key},
				name4  => "cgi::$ipmi_netmask_key",  value4  => $an->data->{cgi}{$ipmi_netmask_key},
				name5  => "cgi::$ipmi_gateway_key",  value5  => $an->data->{cgi}{$ipmi_gateway_key},
				name6  => "cgi::$ipmi_password_key", value6  => $an->data->{cgi}{$ipmi_password_key},
				name7  => "cgi::$ipmi_user_key",     value7  => $an->data->{cgi}{$ipmi_user_key},
				name8  => "cgi::$sn_ip_key",         value8  => $an->data->{cgi}{$sn_ip_key},
				name9  => "cgi::$ifn_ip_key",        value9  => $an->data->{cgi}{$ifn_ip_key},
				name10 => "cgi::$pdu1_key",          value10 => $an->data->{cgi}{$pdu1_key},
				name11 => "cgi::$pdu2_key",          value11 => $an->data->{cgi}{$pdu2_key},
				name12 => "cgi::$pdu3_key",          value12 => $an->data->{cgi}{$pdu3_key},
				name13 => "cgi::$pdu4_key",          value13 => $an->data->{cgi}{$pdu4_key},
				name14 => "cgi::$uuid_key",          value14 => $an->data->{cgi}{$uuid_key},
			}, file => $THIS_FILE, line => __LINE__});
			
			# If the user remapped their network, we don't want to undo the results.
			if (not $an->data->{cgi}{perform_install})
			{
				$an->data->{cgi}{$bcn_link1_mac_key} = $an->data->{install_manifest}{$file}{node}{$node}{interface}{bcn_link1}{mac};
				$an->data->{cgi}{$bcn_link2_mac_key} = $an->data->{install_manifest}{$file}{node}{$node}{interface}{bcn_link2}{mac};
				$an->data->{cgi}{$sn_link1_mac_key}  = $an->data->{install_manifest}{$file}{node}{$node}{interface}{sn_link1}{mac};
				$an->data->{cgi}{$sn_link2_mac_key}  = $an->data->{install_manifest}{$file}{node}{$node}{interface}{sn_link2}{mac};
				$an->data->{cgi}{$ifn_link1_mac_key} = $an->data->{install_manifest}{$file}{node}{$node}{interface}{ifn_link1}{mac};
				$an->data->{cgi}{$ifn_link2_mac_key} = $an->data->{install_manifest}{$file}{node}{$node}{interface}{ifn_link2}{mac};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
					name1 => "cgi::$bcn_link1_mac_key", value1 => $an->data->{cgi}{$bcn_link1_mac_key},
					name2 => "cgi::$bcn_link2_mac_key", value2 => $an->data->{cgi}{$bcn_link2_mac_key},
					name3 => "cgi::$sn_link1_mac_key",  value3 => $an->data->{cgi}{$sn_link1_mac_key},
					name4 => "cgi::$sn_link2_mac_key",  value4 => $an->data->{cgi}{$sn_link2_mac_key},
					name5 => "cgi::$ifn_link1_mac_key", value5 => $an->data->{cgi}{$ifn_link1_mac_key},
					name6 => "cgi::$ifn_link2_mac_key", value6 => $an->data->{cgi}{$ifn_link2_mac_key},
				}, file => $THIS_FILE, line => __LINE__});
			}
			$i++;
		}
		
		### Now to build the fence strings.
		my $fence_order = $an->data->{install_manifest}{$file}{common}{cluster}{fence}{order};
		$an->data->{cgi}{anvil_fence_order} = $fence_order;
		
		# Nodes
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_node1_name", value1 => $an->data->{cgi}{anvil_node1_name},
			name2 => "cgi::anvil_node2_name", value2 => $an->data->{cgi}{anvil_node2_name},
		}, file => $THIS_FILE, line => __LINE__});
		my $node1_name = $an->data->{cgi}{anvil_node1_name};
		my $node2_name = $an->data->{cgi}{anvil_node2_name};
		my $delay_set  = 0;
		my $delay_node = $an->data->{install_manifest}{$file}{common}{cluster}{fence}{delay_node};
		my $delay_time = $an->data->{install_manifest}{$file}{common}{cluster}{fence}{delay};
		foreach my $node ($an->data->{cgi}{anvil_node1_name}, $an->data->{cgi}{anvil_node2_name})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node", value1 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my $i = 1;
			foreach my $method (split/,/, $fence_order)
			{
				if ($method eq "kvm")
				{
					# Only ever one, but...
					my $j = 1;
					foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{node}{$node}{kvm}})
					{
						my $port            = $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{port};
						my $user            = $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{user};
						my $password        = $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password};
						my $password_script = $an->data->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password_script};
						
						# Build the string.
						my $string =  "<device name=\"$reference\"";
						   $string .= " port=\"$port\""  if $port;
						   $string .= " login=\"$user\"" if $user;
						# One or the other, not both.
						if ($password)
						{
							$string .= " passwd=\"$password\"";
						}
						elsif ($password_script)
						{
							$string .= " passwd_script=\"$password_script\"";
						}
						if (($node eq $delay_node) && (not $delay_set))
						{
							$string    .= " delay=\"$delay_time\"";
							$delay_set =  1;
						}
						$string .= " action=\"reboot\" />";
						$string =~ s/\s+/ /g;
						$an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "node",                                                                       value1 => $node,
							name2 => "fence method",                                                               value2 => $method, 
							name3 => "fence::node::${node}::order::${i}::method::${method}::device::${j}::string", value3 => $an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string},
						}, file => $THIS_FILE, line => __LINE__});
						$j++;
					}
				}
				elsif ($method eq "ipmi")
				{
					# Only ever one, but...
					my $j = 1;
					foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{node}{$node}{ipmi}})
					{
						my $name            = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{name};
						my $ip              = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{ip};
						my $user            = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{user};
						my $password        = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password};
						my $password_script = $an->data->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password_script};
						if ((not $name) && ($ip))
						{
							$name = $ip;
						}
						# Build the string
						my $string =  "<device name=\"$reference\"";
						   $string .= " ipaddr=\"$name\"" if $name;
						   $string .= " login=\"$user\""  if $user;
						# One or the other, not both.
						if ($password)
						{
							$string .= " passwd=\"$password\"";
						}
						elsif ($password_script)
						{
							$string .= " passwd_script=\"$password_script\"";
						}
						if (($node eq $delay_node) && (not $delay_set))
						{
							$string    .= " delay=\"$delay_time\"";
							$delay_set =  1;
						}
						$string .= " action=\"reboot\" />";
						$string =~ s/\s+/ /g;
						$an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "node",                                                                       value1 => $node,
							name2 => "fence method",                                                               value2 => $method,
							name3 => "fence::node::${node}::order::${i}::method::${method}::device::${j}::string", value3 => $an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string},
						}, file => $THIS_FILE, line => __LINE__});
						$j++;
					}
				}
				elsif ($method eq "pdu")
				{
					# Here we can have > 1.
					my $j = 1;
					foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{node}{$node}{pdu}})
					{
						my $port            = $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{port};
						my $user            = $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{user};
						my $password        = $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password};
						my $password_script = $an->data->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password_script};
						
						# If there is no port, skip.
						next if not $port;
						
						# Build the string
						my $string = "<device name=\"$reference\" ";
						   $string .= " port=\"$port\""  if $port;
						   $string .= " login=\"$user\"" if $user;
						# One or the other, not both.
						if ($password)
						{
							$string .= " passwd=\"$password\"";
						}
						elsif ($password_script)
						{
							$string .= " passwd_script=\"$password_script\"";
						}
						if (($node eq $delay_node) && (not $delay_set))
						{
							$string    .= " delay=\"$delay_time\"";
							$delay_set =  1;
						}
						$string .= " action=\"reboot\" />";
						$string =~ s/\s+/ /g;
						$an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "node",                                                                       value1 => $node,
							name2 => "fence method",                                                               value2 => $method,
							name3 => "fence::node::${node}::order::${i}::method::${method}::device::${j}::string", value3 => $an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string},
						}, file => $THIS_FILE, line => __LINE__});
						$j++;
					}
				}
				$i++;
			}
		}
		
		# Devices
		foreach my $device (split/,/, $fence_order)
		{
			if ($device eq "kvm")
			{
				foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{common}{kvm}})
				{
					my $name            = $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{name};
					my $ip              = $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{ip};
					my $user            = $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{user};
					my $password        = $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{password};
					my $password_script = $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{password_script};
					my $agent           = $an->data->{install_manifest}{$file}{common}{kvm}{$reference}{agent};
					if ((not $name) && ($ip))
					{
						$name = $ip;
					}
					
					# Build the string
					my $string =  "<fencedevice name=\"$reference\" agent=\"$agent\"";
					   $string .= " ipaddr=\"$name\"" if $name;
					   $string .= " login=\"$user\""  if $user;
					# One or the other, not both.
					if ($password)
					{
						$string .= " passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= " passwd_script=\"$password_script\"";
					}
					$string .= " />";
					$string =~ s/\s+/ /g;
					$an->data->{fence}{device}{$device}{name}{$reference}{string} = $string;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "fence device", value1 => $device,
						name2 => "name",         value2 => $name,
						name3 => "string",       value3 => $an->data->{fence}{device}{$device}{name}{$reference}{string},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			if ($device eq "ipmi")
			{
				foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{common}{ipmi}})
				{
					my $name            = $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{name};
					my $ip              = $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{ip};
					my $user            = $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{user};
					my $password        = $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password};
					my $password_script = $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{password_script};
					my $agent           = $an->data->{install_manifest}{$file}{common}{ipmi}{$reference}{agent};
					if ((not $name) && ($ip))
					{
						$name = $ip;
					}
					   
					# Build the string
					my $string =  "<fencedevice name=\"$reference\" agent=\"$agent\"";
					   $string .= " ipaddr=\"$name\"" if $name;
					   $string .= " login=\"$user\""  if $user;
					if ($password)
					{
						$string .= " passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= " passwd_script=\"$password_script\"";
					}
					$string .= " />";
					$string =~ s/\s+/ /g;
					$an->data->{fence}{device}{$device}{name}{$reference}{string} = $string;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "fence device", value1 => $device,
						name2 => "name",         value2 => $name,
						name3 => "string",       value3 => $an->data->{fence}{device}{$device}{name}{$reference}{string},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			if ($device eq "pdu")
			{
				foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$file}{common}{pdu}})
				{
					my $name            = $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{name};
					my $ip              = $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{ip};
					my $user            = $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{user};
					my $password        = $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{password};
					my $password_script = $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{password_script};
					my $agent           = $an->data->{install_manifest}{$file}{common}{pdu}{$reference}{agent};
					if ((not $name) && ($ip))
					{
						$name = $ip;
					}
					   
					# Build the string
					my $string =  "<fencedevice name=\"$reference\" agent=\"$agent\" ";
					   $string .= " ipaddr=\"$name\"" if $name;
					   $string .= " login=\"$user\""  if $user;
					if ($password)
					{	
						$string .= "passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= "passwd_script=\"$password_script\"";
					}
					$string .= " />";
					$string =~ s/\s+/ /g;
					$an->data->{fence}{device}{$device}{name}{$reference}{string} = $string;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "fence device", value1 => $device,
						name2 => "name",         value2 => $name,
						name3 => "string",       value3 => $an->data->{fence}{device}{$device}{name}{$reference}{string},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		
		# Some system stuff.
		$an->data->{sys}{post_join_delay} = $an->data->{install_manifest}{$file}{common}{cluster}{fence}{post_join_delay};
		$an->data->{sys}{update_os}       = $an->data->{install_manifest}{$file}{common}{update}{os};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::post_join_delay", value1 => $an->data->{sys}{post_join_delay},
			name2 => "sys::update_os",       value2 => $an->data->{sys}{update_os},
		}, file => $THIS_FILE, line => __LINE__});
		if ((lc($an->data->{install_manifest}{$file}{common}{update}{os}) eq "false") || (lc($an->data->{install_manifest}{$file}{common}{update}{os}) eq "no"))
		{
			$an->data->{sys}{update_os} = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::update_os", value1 => $an->data->{sys}{update_os},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		# File is gone. ;_;
		my $message = $an->String->get({key => "message_0350", variables => { manifest_file => $manifest_file }});
		print $an->Web->template({file => "config.html", template => "load-manifest-failure", replace => { message => $message }});
	}
	
	return(0);
}

# This looks for existing install manifest files and displays those it finds.
sub show_existing_install_manifests
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_existing_install_manifests" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $header_printed = 0;
	my $return         = $an->ScanCore->get_manifests($an);
	foreach my $hash_ref (@{$return})
	{
		my $manifest_uuid = $hash_ref->{manifest_uuid};
		my $manifest_data = $hash_ref->{manifest_data};
		my $manifest_note = $hash_ref->{manifest_note};
		my $modified_date = $hash_ref->{modified_date};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "manifest_uuid", value1 => $manifest_uuid,
			name2 => "manifest_data", value2 => $manifest_data,
			name3 => "manifest_note", value3 => $manifest_note,
			name4 => "modified_date", value4 => $modified_date,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Parse this and pull out the details
		$an->ScanCore->parse_install_manifest({uuid => $manifest_uuid});
		
		my $anvil_name =  $an->data->{cgi}{anvil_name};
		my $edit_date  =  $modified_date;
		   $edit_date  =~ s/(:\d\d)\..*/$1/;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "anvil_name", value1 => $anvil_name,
			name2 => "edit_date",  value2 => $edit_date,
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{manifest_file}{$manifest_uuid}{anvil} = $an->String->get({key => "message_0460", variables => { 
				anvil	=>	$anvil_name,
				date	=>	$edit_date,
				raw	=>	"?config=true&task=create-install-manifest&raw=true&manifest_uuid=$manifest_uuid",
			}});
		
		if (not $header_printed)
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-header"});
			$header_printed = 1;
		}
	}
	
	foreach my $manifest_uuid (sort {$b cmp $a} keys %{$an->data->{manifest_file}})
	{
		print $an->Web->template({file => "config.html", template => "install-manifest-entry", replace => { 
			description	=>	$an->data->{manifest_file}{$manifest_uuid}{anvil},
			load		=>	"?config=true&task=create-install-manifest&load=true&manifest_uuid=$manifest_uuid",
			run		=>	"?config=true&task=create-install-manifest&run=true&manifest_uuid=$manifest_uuid",
			'delete'	=>	"?config=true&task=create-install-manifest&delete=true&manifest_uuid=$manifest_uuid",
		}});
	}
	if ($header_printed)
	{
		print $an->Web->template({file => "config.html", template => "install-manifest-footer"});
	}
	
	return(0);
}

# This looks for existing install manifest files and displays those it finds.
sub show_existing_install_manifests_old
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_existing_install_manifests_old" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $header_printed = 0;
	local(*DIR);
	opendir(DIR, $an->data->{path}{apache_manifests_dir}) or die "Failed to open the directory: [".$an->data->{path}{apache_manifests_dir}."], error was: $!\n";
	while (my $file = readdir(DIR))
	{
		next if (($file eq ".") or ($file eq ".."));
		if ($file =~ /^install-manifest_(.*?)_(\d+-\d+-\d+)_(\d+-\d+-\d+).xml/)
		{
			my $anvil =  $1;
			my $date  =  $2;
			my $time  =  $3;
			   $time  =~ s/-/:/g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "anvil", value1 => $anvil,
				name2 => "date",  value2 => $date,
				name3 => "time",  value3 => $time,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{manifest_file}{$file}{anvil} = $an->String->get({key => "message_0346", variables => { 
					anvil	=>	$anvil,
					date	=>	$date,
					'time'	=>	$time,
				}});
			if (not $header_printed)
			{
				print $an->Web->template({file => "config.html", template => "install-manifest-header"});
				$header_printed = 1;
			}
		}
		# Deprecated: Old-style names, will go away eventually. (these
		# were not [V]FAT compatible)
		if ($file =~ /^install-manifest_(.*?)_(\d+-\d+-\d+)_(\d+:\d+:\d+).xml/)
		{
			my $anvil   = $1;
			my $date    = $2;
			my $time    = $3;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "anvil", value1 => $anvil,
				name2 => "date",  value2 => $date,
				name3 => "time",  value3 => $time,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{manifest_file}{$file}{anvil} = $an->String->get({key => "message_0346", variables => { 
					anvil	=>	$anvil,
					date	=>	$date,
					'time'	=>	$time,
				}});
			if (not $header_printed)
			{
				print $an->Web->template({file => "config.html", template => "install-manifest-header"});
				$header_printed = 1;
			}
		}
	}
	foreach my $file (sort {$b cmp $a} keys %{$an->data->{manifest_file}})
	{
		print $an->Web->template({file => "config.html", template => "install-manifest-entry", replace => { 
			description	=>	$an->data->{manifest_file}{$file}{anvil},
			load		=>	"?config=true&task=create-install-manifest&load=$file",
			download	=>	$an->data->{path}{apache_manifests_url}."/".$file,
			run		=>	"?config=true&task=create-install-manifest&run=$file",
			'delete'	=>	"?config=true&task=create-install-manifest&delete=$file",
		}});
	}
	if ($header_printed)
	{
		print $an->Web->template({file => "config.html", template => "install-manifest-footer"});
	}
	
	return(0);
}

# This takes an IP, compares it to the BCN, SN and IFN networks and returns the
# netmask from the matched network.
sub get_netmask_from_ip
{
	my ($an, $ip) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_netmask_from_ip" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "ip", value1 => $ip, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make this support all possible subnet masks.
	my $netmask = "";
	
	# Create short versions of the three networks that I can use in the
	# regex.
	my $short_bcn = "";
	my $short_sn = "";
	my $short_ifn = "";
	
	# BCN
	if ($an->data->{cgi}{anvil_bcn_subnet} eq "255.0.0.0")
	{
		$short_bcn = ($an->data->{cgi}{anvil_bcn_network} =~ /^(\d+\.)/)[0];
	}
	elsif ($an->data->{cgi}{anvil_bcn_subnet} eq "255.255.0.0")
	{
		$short_bcn = ($an->data->{cgi}{anvil_bcn_network} =~ /^(\d+\.\d+\.)/)[0];
	}
	elsif ($an->data->{cgi}{anvil_bcn_subnet} eq "255.255.255.0")
	{
		$short_bcn = ($an->data->{cgi}{anvil_bcn_network} =~ /^(\d+\.\d+\.\d+\.)/)[0];
	}
	
	# SN
	if ($an->data->{cgi}{anvil_sn_subnet} eq "255.0.0.0")
	{
		$short_sn = ($an->data->{cgi}{anvil_sn_network} =~ /^(\d+\.)/)[0];
	}
	elsif ($an->data->{cgi}{anvil_sn_subnet} eq "255.255.0.0")
	{
		$short_sn = ($an->data->{cgi}{anvil_sn_network} =~ /^(\d+\.\d+\.)/)[0];
	}
	elsif ($an->data->{cgi}{anvil_sn_subnet} eq "255.255.255.0")
	{
		$short_sn = ($an->data->{cgi}{anvil_sn_network} =~ /^(\d+\.\d+\.\d+\.)/)[0];
	}
	
	# IFN 
	if ($an->data->{cgi}{anvil_ifn_subnet} eq "255.0.0.0")
	{
		$short_ifn = ($an->data->{cgi}{anvil_ifn_network} =~ /^(\d+\.)/)[0];
	}
	elsif ($an->data->{cgi}{anvil_ifn_subnet} eq "255.255.0.0")
	{
		$short_ifn = ($an->data->{cgi}{anvil_ifn_network} =~ /^(\d+\.\d+\.)/)[0];
	}
	elsif ($an->data->{cgi}{anvil_ifn_subnet} eq "255.255.255.0")
	{
		$short_ifn = ($an->data->{cgi}{anvil_ifn_network} =~ /^(\d+\.\d+\.\d+\.)/)[0];
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "short_bcn", value1 => $short_bcn,
		name2 => "short_sn",  value2 => $short_sn,
		name3 => "short_ifn", value3 => $short_ifn,
	}, file => $THIS_FILE, line => __LINE__});
	
	if ($ip =~ /^$short_bcn/)
	{
		$netmask = $an->data->{cgi}{anvil_bcn_subnet};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "netmask", value1 => $netmask,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($ip =~ /^$short_sn/)
	{
		$netmask = $an->data->{cgi}{anvil_sn_subnet};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "netmask", value1 => $netmask,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($ip =~ /^$short_ifn/)
	{
		$netmask = $an->data->{cgi}{anvil_ifn_subnet};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "netmask", value1 => $netmask,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "netmask", value1 => $netmask,
	}, file => $THIS_FILE, line => __LINE__});
	return($netmask);
}

# This takes the (sanity-checked) form data and generates the XML manifest file and then returns the download
# URL.
sub generate_install_manifest
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "generate_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Break up hostsnames
	my ($node1_short_name)    = ($an->data->{cgi}{anvil_node1_name}    =~ /^(.*?)\./);
	my ($node2_short_name)    = ($an->data->{cgi}{anvil_node2_name}    =~ /^(.*?)\./);
	my ($switch1_short_name)  = ($an->data->{cgi}{anvil_switch1_name}  =~ /^(.*?)\./);
	my ($switch2_short_name)  = ($an->data->{cgi}{anvil_switch2_name}  =~ /^(.*?)\./);
	my ($pdu1_short_name)     = ($an->data->{cgi}{anvil_pdu1_name}     =~ /^(.*?)\./);
	my ($pdu2_short_name)     = ($an->data->{cgi}{anvil_pdu2_name}     =~ /^(.*?)\./);
	my ($pdu3_short_name)     = ($an->data->{cgi}{anvil_pdu3_name}     =~ /^(.*?)\./);
	my ($pdu4_short_name)     = ($an->data->{cgi}{anvil_pdu4_name}     =~ /^(.*?)\./);
	my ($ups1_short_name)     = ($an->data->{cgi}{anvil_ups1_name}     =~ /^(.*?)\./);
	my ($ups2_short_name)     = ($an->data->{cgi}{anvil_ups2_name}     =~ /^(.*?)\./);
	my ($pts1_short_name)     = ($an->data->{cgi}{anvil_pts1_name}     =~ /^(.*?)\./);
	my ($pts2_short_name)     = ($an->data->{cgi}{anvil_pts2_name}     =~ /^(.*?)\./);
	my ($striker1_short_name) = ($an->data->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
	my ($striker2_short_name) = ($an->data->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
	my $date      =  $an->Get->date_and_time({split_date_time => 0});
	my $file_date =  $date;
	   $file_date =~ s/ /_/g;
	
	# Note yet supported but will be later.
	$an->data->{cgi}{anvil_node1_ipmi_password} = $an->data->{cgi}{anvil_node1_ipmi_password} ? $an->data->{cgi}{anvil_node1_ipmi_password} : $an->data->{cgi}{anvil_password};
	$an->data->{cgi}{anvil_node1_ipmi_user}     = $an->data->{cgi}{anvil_node1_ipmi_user}     ? $an->data->{cgi}{anvil_node1_ipmi_user}     : "admin";
	$an->data->{cgi}{anvil_node2_ipmi_password} = $an->data->{cgi}{anvil_node2_ipmi_password} ? $an->data->{cgi}{anvil_node2_ipmi_password} : $an->data->{cgi}{anvil_password};
	$an->data->{cgi}{anvil_node2_ipmi_user}     = $an->data->{cgi}{anvil_node2_ipmi_user}     ? $an->data->{cgi}{anvil_node2_ipmi_user}     : "admin";
	
	# Generate UUIDs if needed.
	$an->data->{cgi}{anvil_node1_uuid}          = $an->Get->uuid() if not $an->data->{cgi}{anvil_node1_uuid};
	$an->data->{cgi}{anvil_node2_uuid}          = $an->Get->uuid() if not $an->data->{cgi}{anvil_node2_uuid};
	
	### TODO: This isn't set for some reason, fix
	$an->data->{cgi}{anvil_open_vnc_ports} = $an->data->{sys}{install_manifest}{open_vnc_ports} if not $an->data->{cgi}{anvil_open_vnc_ports};
	
	# Set the MTU.
	$an->data->{cgi}{anvil_mtu_size} = $an->data->{sys}{install_manifest}{'default'}{mtu_size} if not $an->data->{cgi}{anvil_mtu_size};
	
	# Use the subnet mask of the IPMI devices by comparing their IP to that
	# of the BCN and IFN, and use the netmask of the matching network.
	my $node1_ipmi_netmask = get_netmask_from_ip($an, $an->data->{cgi}{anvil_node1_ipmi_ip});
	my $node2_ipmi_netmask = get_netmask_from_ip($an, $an->data->{cgi}{anvil_node2_ipmi_ip});
	
	### Setup the DRBD lines.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_disk_disk-barrier", value1 => $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_disk_disk-flushes", value1 => $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_disk_md-flushes", value1 => $an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_options_cpu-mask", value1 => $an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_net_max-buffers", value1 => $an->data->{cgi}{'anvil_drbd_net_max-buffers'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_net_sndbuf-size", value1 => $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_net_rcvbuf-size", value1 => $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
	}, file => $THIS_FILE, line => __LINE__});
	# Standardize
	$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} =  lc($an->data->{cgi}{'anvil_drbd_disk_disk-barrier'});
	$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} =~ s/no/false/;
	$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} =~ s/0/false/;
	$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} =  lc($an->data->{cgi}{'anvil_drbd_disk_disk-flushes'});
	$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} =~ s/no/false/;
	$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} =~ s/0/false/;
	$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   =  lc($an->data->{cgi}{'anvil_drbd_disk_md-flushes'});
	$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   =~ s/no/false/;
	$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   =~ s/0/false/;
	# Convert
	$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} = $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} eq "false" ? "no" : "yes";
	$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} = $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} eq "false" ? "no" : "yes";
	$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   = $an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   eq "false" ? "no" : "yes";
	$an->data->{cgi}{'anvil_drbd_options_cpu-mask'}  = defined $an->data->{cgi}{'anvil_drbd_options_cpu-mask'}   ? $an->data->{cgi}{'anvil_drbd_options_cpu-mask'} : "";
	$an->data->{cgi}{'anvil_drbd_net_max-buffers'}   = $an->data->{cgi}{'anvil_drbd_net_max-buffers'} =~ /^\d+$/ ? $an->data->{cgi}{'anvil_drbd_net_max-buffers'}  : "";
	$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}   = $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}            ? $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}  : "";
	$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}   = $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}            ? $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}  : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_disk_disk-barrier", value1 => $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_disk_disk-flushes", value1 => $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_disk_md-flushes", value1 => $an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_options_cpu-mask", value1 => $an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_net_max-buffers", value1 => $an->data->{cgi}{'anvil_drbd_net_max-buffers'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_net_sndbuf-size", value1 => $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_drbd_net_rcvbuf-size", value1 => $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Get the node and dashboard UUIDs if not yet set.
	
	### KVM-based fencing is supported but not documented. Sample entries
	### are here for those who might ask for it when building test Anvil!
	### systems later.
	# Many things are currently static but might be made configurable later.
	my $xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>

<!--
Generated on:    $date
Striker Version: $an->data->{sys}{version}
-->

<config>
	<node name=\"".$an->data->{cgi}{anvil_node1_name}."\" uuid=\"".$an->data->{cgi}{anvil_node1_uuid}."\">
		<network>
			<bcn ip=\"".$an->data->{cgi}{anvil_node1_bcn_ip}."\" />
			<sn ip=\"".$an->data->{cgi}{anvil_node1_sn_ip}."\" />
			<ifn ip=\"".$an->data->{cgi}{anvil_node1_ifn_ip}."\" />
		</network>
		<ipmi>
			<on reference=\"ipmi_n01\" ip=\"".$an->data->{cgi}{anvil_node1_ipmi_ip}."\" netmask=\"$node1_ipmi_netmask\" user=\"".$an->data->{cgi}{anvil_node1_ipmi_user}."\" password=\"".$an->data->{cgi}{anvil_node1_ipmi_password}."\" gateway=\"\" />
		</ipmi>
		<pdu>
			<on reference=\"pdu01\" port=\"".$an->data->{cgi}{anvil_node1_pdu1_outlet}."\" />
			<on reference=\"pdu02\" port=\"".$an->data->{cgi}{anvil_node1_pdu2_outlet}."\" />
			<on reference=\"pdu03\" port=\"".$an->data->{cgi}{anvil_node1_pdu3_outlet}."\" />
			<on reference=\"pdu04\" port=\"".$an->data->{cgi}{anvil_node1_pdu4_outlet}."\" />
		</pdu>
		<kvm>
			<!-- port == virsh name of VM -->
			<on reference=\"kvm_host\" port=\"\" />
		</kvm>
		<interfaces>
			<interface name=\"bcn_link1\" mac=\"".$an->data->{cgi}{anvil_node1_bcn_link1_mac}."\" />
			<interface name=\"bcn_link2\" mac=\"".$an->data->{cgi}{anvil_node1_bcn_link2_mac}."\" />
			<interface name=\"sn_link1\" mac=\"".$an->data->{cgi}{anvil_node1_sn_link1_mac}."\" />
			<interface name=\"sn_link2\" mac=\"".$an->data->{cgi}{anvil_node1_sn_link2_mac}."\" />
			<interface name=\"ifn_link1\" mac=\"".$an->data->{cgi}{anvil_node1_ifn_link1_mac}."\" />
			<interface name=\"ifn_link2\" mac=\"".$an->data->{cgi}{anvil_node1_ifn_link2_mac}."\" />
		</interfaces>
	</node>
	<node name=\"".$an->data->{cgi}{anvil_node2_name}."\" uuid=\"".$an->data->{cgi}{anvil_node2_uuid}."\">
		<network>
			<bcn ip=\"".$an->data->{cgi}{anvil_node2_bcn_ip}."\" />
			<sn ip=\"".$an->data->{cgi}{anvil_node2_sn_ip}."\" />
			<ifn ip=\"".$an->data->{cgi}{anvil_node2_ifn_ip}."\" />
		</network>
		<ipmi>
			<on reference=\"ipmi_n02\" ip=\"".$an->data->{cgi}{anvil_node2_ipmi_ip}."\" netmask=\"".$node2_ipmi_netmask."\" user=\"".$an->data->{cgi}{anvil_node2_ipmi_user}."\" password=\"".$an->data->{cgi}{anvil_node2_ipmi_password}."\" gateway=\"\" />
		</ipmi>
		<pdu>
			<on reference=\"pdu01\" port=\"".$an->data->{cgi}{anvil_node2_pdu1_outlet}."\" />
			<on reference=\"pdu02\" port=\"".$an->data->{cgi}{anvil_node2_pdu2_outlet}."\" />
			<on reference=\"pdu03\" port=\"".$an->data->{cgi}{anvil_node2_pdu3_outlet}."\" />
			<on reference=\"pdu04\" port=\"".$an->data->{cgi}{anvil_node2_pdu4_outlet}."\" />
		</pdu>
		<kvm>
			<on reference=\"kvm_host\" port=\"\" />
		</kvm>
		<interfaces>
			<interface name=\"bcn_link1\" mac=\"".$an->data->{cgi}{anvil_node2_bcn_link1_mac}."\" />
			<interface name=\"bcn_link2\" mac=\"".$an->data->{cgi}{anvil_node2_bcn_link2_mac}."\" />
			<interface name=\"sn_link1\" mac=\"".$an->data->{cgi}{anvil_node2_sn_link1_mac}."\" />
			<interface name=\"sn_link2\" mac=\"".$an->data->{cgi}{anvil_node2_sn_link2_mac}."\" />
			<interface name=\"ifn_link1\" mac=\"".$an->data->{cgi}{anvil_node2_ifn_link1_mac}."\" />
			<interface name=\"ifn_link2\" mac=\"".$an->data->{cgi}{anvil_node2_ifn_link2_mac}."\" />
		</interfaces>
	</node>
	<common>
		<networks>
			<bcn netblock=\"".$an->data->{cgi}{anvil_bcn_network}."\" netmask=\"".$an->data->{cgi}{anvil_bcn_subnet}."\" gateway=\"\" defroute=\"no\" ethtool_opts=\"".$an->data->{cgi}{anvil_bcn_ethtool_opts}."\" />
			<sn netblock=\"".$an->data->{cgi}{anvil_sn_network}."\" netmask=\"".$an->data->{cgi}{anvil_sn_subnet}."\" gateway=\"\" defroute=\"no\" ethtool_opts=\"".$an->data->{cgi}{anvil_sn_ethtool_opts}."\" />
			<ifn netblock=\"".$an->data->{cgi}{anvil_ifn_network}."\" netmask=\"".$an->data->{cgi}{anvil_ifn_subnet}."\" gateway=\"".$an->data->{cgi}{anvil_ifn_gateway}."\" dns1=\"".$an->data->{cgi}{anvil_dns1}."\" dns2=\"".$an->data->{cgi}{anvil_dns2}."\" ntp1=\"".$an->data->{cgi}{anvil_ntp1}."\" ntp2=\"".$an->data->{cgi}{anvil_ntp2}."\" defroute=\"yes\" ethtool_opts=\"".$an->data->{cgi}{anvil_ifn_ethtool_opts}."\" />
			<bonding opts=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0\">
				<bcn name=\"bcn_bond1\" primary=\"bcn_link1\" secondary=\"bcn_link2\" />
				<sn name=\"sn_bond1\" primary=\"sn_link1\" secondary=\"sn_link2\" />
				<ifn name=\"ifn_bond1\" primary=\"ifn_link1\" secondary=\"ifn_link2\" />
			</bonding>
			<bridges>
				<bridge name=\"ifn_bridge1\" on=\"ifn\" />
			</bridges>
			<mtu size=\"".$an->data->{cgi}{anvil_mtu_size}."\" />
		</networks>
		<repository urls=\"".$an->data->{cgi}{anvil_repositories}."\" />
		<media_library size=\"".$an->data->{cgi}{anvil_media_library_size}."\" units=\"".$an->data->{cgi}{anvil_media_library_unit}."\" />
		<storage_pool_1 size=\"".$an->data->{cgi}{anvil_storage_pool1_size}."\" units=\"".$an->data->{cgi}{anvil_storage_pool1_unit}."\" />
		<anvil prefix=\"".$an->data->{cgi}{anvil_prefix}."\" sequence=\"".$an->data->{cgi}{anvil_sequence}."\" domain=\"".$an->data->{cgi}{anvil_domain}."\" password=\"".$an->data->{cgi}{anvil_password}."\" striker_user=\"".$an->data->{cgi}{striker_user}."\" striker_databas=\"".$an->data->{cgi}{striker_database}."\" />
		<ssh keysize=\"8191\" />
		<cluster name=\"".$an->data->{cgi}{anvil_name}."\">
			<!-- Set the order to 'kvm' if building on KVM-backed VMs -->
			<fence order=\"ipmi,pdu\" post_join_delay=\"90\" delay=\"15\" delay_node=\"".$an->data->{cgi}{anvil_node1_name}."\" />
		</cluster>
		<drbd>
			<disk disk-barrier=\"".$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'}."\" disk-flushes=\"".$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'}."\" md-flushes=\"".$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}."\" />
			<options cpu-mask=\"".$an->data->{cgi}{'anvil_drbd_options_cpu-mask'}."\" />
			<net max-buffers=\"".$an->data->{cgi}{'anvil_drbd_net_max-buffers'}."\" sndbuf-size=\"".$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}."\" rcvbuf-size=\"".$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}."\" />
		</drbd>
		<switch>
			<switch name=\"".$an->data->{cgi}{anvil_switch1_name}."\" ip=\"".$an->data->{cgi}{anvil_switch1_ip}."\" />
";

	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_switch2_name", value1 => $an->data->{cgi}{anvil_switch2_name},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{cgi}{anvil_switch2_name}) && ($an->data->{cgi}{anvil_switch2_name} ne "--"))
	{
		$xml .= "\t\t\t<switch name=\"".$an->data->{cgi}{anvil_switch2_name}."\" ip=\"".$an->data->{cgi}{anvil_switch2_ip}."\" />";
	}
	$xml .= "
		</switch>
		<ups>
			<ups name=\"".$an->data->{cgi}{anvil_ups1_name}."\" type=\"apc\" port=\"3551\" ip=\"".$an->data->{cgi}{anvil_ups1_ip}."\" />
			<ups name=\"".$an->data->{cgi}{anvil_ups2_name}."\" type=\"apc\" port=\"3552\" ip=\"".$an->data->{cgi}{anvil_ups2_ip}."\" />
		</ups>
		<pts>
			<pts name=\"".$an->data->{cgi}{anvil_pts1_name}."\" type=\"raritan\" port=\"161\" ip=\"".$an->data->{cgi}{anvil_pts1_ip}."\" />
			<pts name=\"".$an->data->{cgi}{anvil_pts2_name}."\" type=\"raritan\" port=\"161\" ip=\"".$an->data->{cgi}{anvil_pts2_ip}."\" />
		</pts>
		<pdu>";
	# PDU 1 and 2 always exist.
	my $pdu1_agent = $an->data->{cgi}{anvil_pdu1_agent} ? $an->data->{cgi}{anvil_pdu1_agent} : $an->data->{sys}{install_manifest}{anvil_pdu_agent};
	$xml .= "
			<pdu reference=\"pdu01\" name=\"".$an->data->{cgi}{anvil_pdu1_name}."\" ip=\"".$an->data->{cgi}{anvil_pdu1_ip}."\" agent=\"$pdu1_agent\" />";
	my $pdu2_agent = $an->data->{cgi}{anvil_pdu2_agent} ? $an->data->{cgi}{anvil_pdu2_agent} : $an->data->{sys}{install_manifest}{anvil_pdu_agent};
	$xml .= "
			<pdu reference=\"pdu02\" name=\"".$an->data->{cgi}{anvil_pdu2_name}."\" ip=\"".$an->data->{cgi}{anvil_pdu2_ip}."\" agent=\"$pdu2_agent\" />";
	if ($an->data->{cgi}{anvil_pdu3_name})
	{
		my $pdu3_agent = $an->data->{cgi}{anvil_pdu3_agent} ? $an->data->{cgi}{anvil_pdu3_agent} : $an->data->{sys}{install_manifest}{anvil_pdu_agent};
		$xml .= "
			<pdu reference=\"pdu03\" name=\"".$an->data->{cgi}{anvil_pdu3_name}."\" ip=\"".$an->data->{cgi}{anvil_pdu3_ip}."\" agent=\"$pdu3_agent\" />";
	}
	if ($an->data->{cgi}{anvil_pdu4_name})
	{
		my $pdu4_agent = $an->data->{cgi}{anvil_pdu4_agent} ? $an->data->{cgi}{anvil_pdu4_agent} : $an->data->{sys}{install_manifest}{anvil_pdu_agent};
		$xml .= "
			<pdu reference=\"pdu04\" name=\"".$an->data->{cgi}{anvil_pdu4_name}."\" ip=\"".$an->data->{cgi}{anvil_pdu4_ip}."\" agent=\"$pdu4_agent\" />";
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::install_manifest::use_anvil-kick-apc-ups", value1 => $an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'},
		name2 => "sys::install_manifest::use_anvil-safe-start",   value2 => $an->data->{sys}{install_manifest}{'use_anvil-safe-start'},
		name3 => "sys::install_manifest::use_scancore",           value3 => $an->data->{sys}{install_manifest}{use_scancore},
	}, file => $THIS_FILE, line => __LINE__});
	my $say_use_anvil_kick_apc_ups = $an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'} ? "true" : "false";
	my $say_use_anvil_safe_start   = $an->data->{sys}{install_manifest}{'use_anvil-safe-start'}   ? "true" : "false";
	my $say_use_scancore           = $an->data->{sys}{install_manifest}{use_scancore}             ? "true" : "false";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "say_use_anvil_kick_apc_ups", value1 => $say_use_anvil_kick_apc_ups,
		name2 => "say_use_anvil-safe-start",   value2 => $say_use_anvil_safe_start,
		name3 => "say_use_scancore",           value3 => $say_use_scancore,
	}, file => $THIS_FILE, line => __LINE__});
	
	$xml .= "
		</pdu>
		<ipmi>
			<ipmi reference=\"ipmi_n01\" agent=\"fence_ipmilan\" />
			<ipmi reference=\"ipmi_n02\" agent=\"fence_ipmilan\" />
		</ipmi>
		<kvm>
			<kvm reference=\"kvm_host\" ip=\"192.168.122.1\" user=\"root\" password=\"\" password_script=\"\" agent=\"fence_virsh\" />
		</kvm>
		<striker>
			<!-- 
			The user and password are, primarily, for the ScanCore
			database user and passowrd, but should be the same as
			the user and password set via:
			striker-installer -u <user:password>
			These should be left unset in most cases. When unset,
			these will take the values from:
			<anvil password=\"<secret>\" striker_user=\"<user>\" />
			striker_user, if unset, defaults to 'admin'. There is
			no default password!
			TODO: Make the TCP port configurable
			-->
			<striker name=\"".$an->data->{cgi}{anvil_striker1_name}."\" bcn_ip=\"".$an->data->{cgi}{anvil_striker1_bcn_ip}."\" ifn_ip=\"".$an->data->{cgi}{anvil_striker1_ifn_ip}."\" database=\"\" user=\"\" password=\"\" uuid=\"\" />
			<striker name=\"".$an->data->{cgi}{anvil_striker2_name}."\" bcn_ip=\"".$an->data->{cgi}{anvil_striker2_bcn_ip}."\" ifn_ip=\"".$an->data->{cgi}{anvil_striker2_ifn_ip}."\" database=\"\" user=\"\" password=\"\" uuid=\"\" />
		</striker>
		<update os=\"true\" />
		<iptables>
			<vnc ports=\"".$an->data->{cgi}{anvil_open_vnc_ports}."\" />
		</iptables>
		<servers>
			<!-- This isn't used anymore, but this section may be useful for other things in the future, -->
			<!-- <provision use_spice_graphics=\"0\" /> -->
		</servers>
		<tools>
			<use anvil-safe-start=\"$say_use_anvil_safe_start\" anvil-kick-apc-ups=\"$say_use_anvil_kick_apc_ups\" scancore=\"$say_use_scancore\" />
		</tools>
	</common>
</config>
";
	
	# Write out the file.
	my $xml_file    =  "install-manifest_".$an->data->{cgi}{anvil_name}."_".$file_date.".xml";
	   $xml_file    =~ s/:/-/g;	# Make the filename FAT-compatible.
	my $target_path =  $an->data->{path}{apache_manifests_dir}."/".$xml_file;
	my $target_url  =  $an->data->{path}{apache_manifests_url}."/".$xml_file;
	open (my $file_handle, ">", $target_path) or die "Failed to write: [$target_path], the error was: $!\n";
	print $file_handle $xml;
	close $file_handle;
	
	return($target_url, $xml_file);
}

# This shows a summary of the install manifest and asks the user to choose a
# node to run it against (verifying they want to do it in the process).
sub confirm_install_manifest_run
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_install_manifest_run" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Show the manifest form.
	$an->data->{cgi}{anvil_node1_bcn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_bcn_link1_mac};
	$an->data->{cgi}{anvil_node1_bcn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_bcn_link2_mac};
	$an->data->{cgi}{anvil_node1_sn_link1_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_sn_link1_mac};
	$an->data->{cgi}{anvil_node1_sn_link2_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_sn_link2_mac};
	$an->data->{cgi}{anvil_node1_ifn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_ifn_link1_mac};
	$an->data->{cgi}{anvil_node1_ifn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_ifn_link2_mac};
	$an->data->{cgi}{anvil_node2_bcn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_bcn_link1_mac};
	$an->data->{cgi}{anvil_node2_bcn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_bcn_link2_mac};
	$an->data->{cgi}{anvil_node2_sn_link1_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_sn_link1_mac};
	$an->data->{cgi}{anvil_node2_sn_link2_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_sn_link2_mac};
	$an->data->{cgi}{anvil_node2_ifn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_ifn_link1_mac};
	$an->data->{cgi}{anvil_node2_ifn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_ifn_link2_mac};
	
	$an->data->{cgi}{anvil_node1_pdu1_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node1_pdu1_outlet};
	$an->data->{cgi}{anvil_node1_pdu2_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node1_pdu2_outlet};
	$an->data->{cgi}{anvil_node1_pdu3_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node1_pdu3_outlet};
	$an->data->{cgi}{anvil_node1_pdu4_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node1_pdu4_outlet};
	$an->data->{cgi}{anvil_node2_pdu1_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node2_pdu1_outlet};
	$an->data->{cgi}{anvil_node2_pdu2_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node2_pdu2_outlet};
	$an->data->{cgi}{anvil_node2_pdu3_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node2_pdu3_outlet};
	$an->data->{cgi}{anvil_node2_pdu4_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node2_pdu4_outlet};
	$an->data->{cgi}{anvil_dns1}                = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_dns1};
	$an->data->{cgi}{anvil_dns2}                = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_dns2};
	$an->data->{cgi}{anvil_ntp1}                = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_ntp1};
	$an->data->{cgi}{anvil_ntp2}                = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_ntp2};
	
	# If the first storage pool is a percentage, calculate
	# the percentage of the second. Otherwise, set storage
	# pool 2 to just same 'remainder'.
	my $say_storage_pool_1 = $an->data->{cgi}{anvil_storage_pool1_size}." ".$an->data->{cgi}{anvil_storage_pool1_unit};
	my $say_storage_pool_2 = "<span class=\"highlight_unavailable\">#!string!message_0357!#</span>";
	if ($an->data->{cgi}{anvil_storage_pool1_unit} eq "%")
	{
		$say_storage_pool_2 = (100 - $an->data->{cgi}{anvil_storage_pool1_size})." %";
	}
	
	# If this is the first load, the use the current IP and
	# password.
	$an->data->{cgi}{anvil_node1_current_ip}       = $an->data->{cgi}{anvil_node1_bcn_ip} if not $an->data->{cgi}{anvil_node1_current_ip};;
	$an->data->{cgi}{anvil_node1_current_password} = $an->data->{cgi}{anvil_password}     if not $an->data->{cgi}{anvil_node1_current_password};
	$an->data->{cgi}{anvil_node2_current_ip}       = $an->data->{cgi}{anvil_node2_bcn_ip} if not $an->data->{cgi}{anvil_node2_current_ip};
	$an->data->{cgi}{anvil_node2_current_password} = $an->data->{cgi}{anvil_password}     if not $an->data->{cgi}{anvil_node2_current_password};
	# I don't ask the user for the port range at this time,
	# so it's possible the number of ports to open isn't in
	# the manifest.
	$an->data->{cgi}{anvil_open_vnc_ports} = $an->data->{sys}{install_manifest}{open_vnc_ports} if not $an->data->{cgi}{anvil_open_vnc_ports};
	
	# NOTE: Dropping support for repos.
	my $say_repos = "<input type=\"hidden\" name=\"anvil_repositories\" id=\"anvil_repositories\" value=\"".$an->data->{cgi}{anvil_repositories}."\" />";
# 	my $say_repos =  $an->data->{cgi}{anvil_repositories};
# 	   $say_repos =~ s/,/<br \/>/;
# 	   $say_repos =  "--" if not $say_repos;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_name", value1 => $an->data->{cgi}{anvil_node1_name},
		name2 => "cgi::anvil_node2_name", value2 => $an->data->{cgi}{anvil_node2_name},
	}, file => $THIS_FILE, line => __LINE__});
	print $an->Web->template({file => "config.html", template => "confirm-anvil-manifest-run", replace => { 
		form_file			=>	"/cgi-bin/striker",
		say_storage_pool_1		=>	$say_storage_pool_1,
		say_storage_pool_2		=>	$say_storage_pool_2,
		anvil_node1_current_ip		=>	$an->data->{cgi}{anvil_node1_current_ip},
		anvil_node1_current_password	=>	$an->data->{cgi}{anvil_node1_current_password},
		anvil_node1_uuid		=>	$an->data->{cgi}{anvil_node1_uuid},
		anvil_node2_current_ip		=>	$an->data->{cgi}{anvil_node2_current_ip},
		anvil_node2_current_password	=>	$an->data->{cgi}{anvil_node2_current_password},
		anvil_node2_uuid		=>	$an->data->{cgi}{anvil_node2_uuid},
		anvil_password			=>	$an->data->{cgi}{anvil_password},
		anvil_bcn_ethtool_opts		=>	$an->data->{cgi}{anvil_bcn_ethtool_opts}, 
		anvil_bcn_network		=>	$an->data->{cgi}{anvil_bcn_network},
		anvil_bcn_subnet		=>	$an->data->{cgi}{anvil_bcn_subnet},
		anvil_sn_ethtool_opts		=>	$an->data->{cgi}{anvil_sn_ethtool_opts}, 
		anvil_sn_network		=>	$an->data->{cgi}{anvil_sn_network},
		anvil_sn_subnet			=>	$an->data->{cgi}{anvil_sn_subnet},
		anvil_ifn_ethtool_opts		=>	$an->data->{cgi}{anvil_ifn_ethtool_opts}, 
		anvil_ifn_network		=>	$an->data->{cgi}{anvil_ifn_network},
		anvil_ifn_subnet		=>	$an->data->{cgi}{anvil_ifn_subnet},
		anvil_media_library_size	=>	$an->data->{cgi}{anvil_media_library_size},
		anvil_media_library_unit	=>	$an->data->{cgi}{anvil_media_library_unit},
		anvil_storage_pool1_size	=>	$an->data->{cgi}{anvil_storage_pool1_size},
		anvil_storage_pool1_unit	=>	$an->data->{cgi}{anvil_storage_pool1_unit},
		anvil_name			=>	$an->data->{cgi}{anvil_name},
		anvil_node1_name		=>	$an->data->{cgi}{anvil_node1_name},
		anvil_node1_bcn_ip		=>	$an->data->{cgi}{anvil_node1_bcn_ip},
		anvil_node1_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link1_mac},
		anvil_node1_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link2_mac},
		anvil_node1_ipmi_ip		=>	$an->data->{cgi}{anvil_node1_ipmi_ip},
		anvil_node1_sn_ip		=>	$an->data->{cgi}{anvil_node1_sn_ip},
		anvil_node1_sn_link1_mac	=>	$an->data->{cgi}{anvil_node1_sn_link1_mac},
		anvil_node1_sn_link2_mac	=>	$an->data->{cgi}{anvil_node1_sn_link2_mac},
		anvil_node1_ifn_ip		=>	$an->data->{cgi}{anvil_node1_ifn_ip},
		anvil_node1_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link1_mac},
		anvil_node1_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link2_mac},
		anvil_node1_pdu1_outlet		=>	$an->data->{cgi}{anvil_node1_pdu1_outlet},
		anvil_node1_pdu2_outlet		=>	$an->data->{cgi}{anvil_node1_pdu2_outlet},
		anvil_node1_pdu3_outlet		=>	$an->data->{cgi}{anvil_node1_pdu3_outlet},
		anvil_node1_pdu4_outlet		=>	$an->data->{cgi}{anvil_node1_pdu4_outlet},
		anvil_node2_name		=>	$an->data->{cgi}{anvil_node2_name},
		anvil_node2_bcn_ip		=>	$an->data->{cgi}{anvil_node2_bcn_ip},
		anvil_node2_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link1_mac},
		anvil_node2_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link2_mac},
		anvil_node2_ipmi_ip		=>	$an->data->{cgi}{anvil_node2_ipmi_ip},
		anvil_node2_sn_ip		=>	$an->data->{cgi}{anvil_node2_sn_ip},
		anvil_node2_sn_link1_mac	=>	$an->data->{cgi}{anvil_node2_sn_link1_mac},
		anvil_node2_sn_link2_mac	=>	$an->data->{cgi}{anvil_node2_sn_link2_mac},
		anvil_node2_ifn_ip		=>	$an->data->{cgi}{anvil_node2_ifn_ip},
		anvil_node2_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link1_mac},
		anvil_node2_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link2_mac},
		anvil_node2_pdu1_outlet		=>	$an->data->{cgi}{anvil_node2_pdu1_outlet},
		anvil_node2_pdu2_outlet		=>	$an->data->{cgi}{anvil_node2_pdu2_outlet},
		anvil_node2_pdu3_outlet		=>	$an->data->{cgi}{anvil_node2_pdu3_outlet},
		anvil_node2_pdu4_outlet		=>	$an->data->{cgi}{anvil_node2_pdu4_outlet},
		anvil_ifn_gateway		=>	$an->data->{cgi}{anvil_ifn_gateway},
		anvil_dns1			=>	$an->data->{cgi}{anvil_dns1},
		anvil_dns2			=>	$an->data->{cgi}{anvil_dns2},
		anvil_ntp1			=>	$an->data->{cgi}{anvil_ntp1},
		anvil_ntp2			=>	$an->data->{cgi}{anvil_ntp2},
		anvil_pdu1_name			=>	$an->data->{cgi}{anvil_pdu1_name},
		anvil_pdu2_name			=>	$an->data->{cgi}{anvil_pdu2_name},
		anvil_pdu3_name			=>	$an->data->{cgi}{anvil_pdu3_name},
		anvil_pdu4_name			=>	$an->data->{cgi}{anvil_pdu4_name},
		anvil_open_vnc_ports		=>	$an->data->{cgi}{anvil_open_vnc_ports},
		say_anvil_repos			=>	$say_repos,
		run				=>	$an->data->{cgi}{run},
		striker_user			=>	$an->data->{cgi}{striker_user},
		striker_database		=>	$an->data->{cgi}{striker_database},
		anvil_striker1_user		=>	$an->data->{cgi}{anvil_striker1_user},
		anvil_striker1_password		=>	$an->data->{cgi}{anvil_striker1_password},
		anvil_striker1_database		=>	$an->data->{cgi}{anvil_striker1_database},
		anvil_striker2_user		=>	$an->data->{cgi}{anvil_striker2_user},
		anvil_striker2_password		=>	$an->data->{cgi}{anvil_striker2_password},
		anvil_striker2_database		=>	$an->data->{cgi}{anvil_striker2_database},
		anvil_mtu_size			=>	$an->data->{cgi}{anvil_mtu_size},
	}});
	
	return(0);
}

# This shows a summary of what the user selected and asks them to confirm that they are happy.
sub show_summary_manifest
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_summary_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Show the manifest form.
	my $say_repos =  $an->data->{cgi}{anvil_repositories};
	   $say_repos =~ s/,/<br \/>/;
	   $say_repos = "#!string!symbol_0011!#" if not $say_repos;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_name", value1 => $an->data->{cgi}{anvil_node1_name},
		name2 => "cgi::anvil_node2_name", value2 => $an->data->{cgi}{anvil_node2_name},
	}, file => $THIS_FILE, line => __LINE__});

	# Open the table.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-header", replace => { form_file => "/cgi-bin/striker" }});
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-title", replace => { title => "#!string!title_0159!#" }});
	
	# Node colum header.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-column-header", replace => { 
		column1		=>	"#!string!header_0001!#",
		column2		=>	"#!string!header_0002!#",
	}});
	
	# Node names
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0165!#",
		column1		=>	$an->data->{cgi}{anvil_node1_name},
		column2		=>	$an->data->{cgi}{anvil_node2_name},
	}});
	
	# Node BCN IPs
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0166!#",
		column1		=>	$an->data->{cgi}{anvil_node1_bcn_ip},
		column2		=>	$an->data->{cgi}{anvil_node2_bcn_ip},
	}});
	
	# Node IPMI BMC IPs
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0168!#",
		column1		=>	$an->data->{cgi}{anvil_node1_ipmi_ip},
		column2		=>	$an->data->{cgi}{anvil_node2_ipmi_ip},
	}});
	
	# Node SN IPs
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0167!#",
		column1		=>	$an->data->{cgi}{anvil_node1_sn_ip},
		column2		=>	$an->data->{cgi}{anvil_node2_sn_ip},
	}});
	
	# Node IFN IPs
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0169!#",
		column1		=>	$an->data->{cgi}{anvil_node1_ifn_ip},
		column2		=>	$an->data->{cgi}{anvil_node2_ifn_ip},
	}});
	
	### PDUs are a little more complicated.
	foreach my $i (1..$an->data->{sys}{install_manifest}{pdu_count})
	{
		my $say_pdu = "";
		if ($i == 1)    { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
		elsif ($i == 2) { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
		elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
		elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "i",       value1 => $i,
			name2 => "say_pdu", value2 => $say_pdu,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $say_pdu_name         = $an->String->get({key => "row_0176", variables => { say_pdu => $say_pdu }});
		my $node1_pdu_outlet_key = "anvil_node1_pdu${i}_outlet";
		my $node2_pdu_outlet_key = "anvil_node2_pdu${i}_outlet";
		
		# PDUs
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
			row		=>	"$say_pdu_name",
			column1		=>	$an->data->{cgi}{$node1_pdu_outlet_key} ? $an->data->{cgi}{$node1_pdu_outlet_key} : "#!string!symbol_0011!#",
			column2		=>	$an->data->{cgi}{$node2_pdu_outlet_key} ? $an->data->{cgi}{$node2_pdu_outlet_key} : "#!string!symbol_0011!#",
		}});
	}
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-spacer"});
	
	# Strikers header
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-title", replace => { title => "#!string!title_0161!#" }});
	
	# Striker colum header.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-column-header", replace => { 
		column1		=>	"#!string!header_0014!#",
		column2		=>	"#!string!header_0015!#",
	}});
	
	# Striker names
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0165!#",
		column1		=>	$an->data->{cgi}{anvil_striker1_name},
		column2		=>	$an->data->{cgi}{anvil_striker2_name},
	}});
	
	# Striker BCN IP
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0166!#",
		column1		=>	$an->data->{cgi}{anvil_striker1_bcn_ip},
		column2		=>	$an->data->{cgi}{anvil_striker2_bcn_ip},
	}});
	
	# Striker IFN IP
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0169!#",
		column1		=>	$an->data->{cgi}{anvil_striker1_ifn_ip},
		column2		=>	$an->data->{cgi}{anvil_striker2_ifn_ip},
	}});
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-spacer"});
	
	# Foundation Pack Header
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-title", replace => { title => "#!string!title_0160!#" }});
	
	# Striker 2 colum header.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-column-header", replace => { 
		column1		=>	"#!string!header_0003!#",
		column2		=>	"#!string!header_0004!#",
	}});
	
	# Striker 4 column header.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-header", replace => { 
		column1		=>	"#!string!header_0006!#",
		column2		=>	"#!string!header_0007!#",
		column3		=>	"#!string!header_0006!#",
		column4		=>	"#!string!header_0007!#",
	}});
	
	# Switches
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
		row		=>	"#!string!row_0195!#",
		column1		=>	$an->data->{cgi}{anvil_switch1_name},
		column2		=>	$an->data->{cgi}{anvil_switch1_ip},
		column3		=>	$an->data->{cgi}{anvil_switch2_name},
		column4		=>	$an->data->{cgi}{anvil_switch2_ip},
	}});
	
	# UPSes
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
		row		=>	"#!string!row_0197!#",
		column1		=>	$an->data->{cgi}{anvil_ups1_name},
		column2		=>	$an->data->{cgi}{anvil_ups1_ip},
		column3		=>	$an->data->{cgi}{anvil_ups2_name},
		column4		=>	$an->data->{cgi}{anvil_ups2_ip},
	}});
	
	# PTSes
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
		row		=>	"#!string!row_0225!#",
		column1		=>	$an->data->{cgi}{anvil_pts1_name},
		column2		=>	$an->data->{cgi}{anvil_pts1_ip},
		column3		=>	$an->data->{cgi}{anvil_pts2_name},
		column4		=>	$an->data->{cgi}{anvil_pts2_ip},
	}});
	
	### PDUs are, surprise, a little more complicated.
	my $say_apc        = $an->String->get({key => "brand_0017"});
	my $say_raritan    = $an->String->get({key => "brand_0018"});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "cgi::anvil_pdu1_agent", value1 => $an->data->{cgi}{anvil_pdu1_agent},
		name2 => "cgi::anvil_pdu2_agent", value2 => $an->data->{cgi}{anvil_pdu2_agent},
		name3 => "cgi::anvil_pdu3_agent", value3 => $an->data->{cgi}{anvil_pdu3_agent},
		name4 => "cgi::anvil_pdu4_agent", value4 => $an->data->{cgi}{anvil_pdu4_agent},
	}, file => $THIS_FILE, line => __LINE__});
	my $say_pdu1_brand = $an->data->{cgi}{anvil_pdu1_agent} eq "fence_raritan_snmp" ? $say_raritan : $say_apc;
	my $say_pdu2_brand = $an->data->{cgi}{anvil_pdu2_agent} eq "fence_raritan_snmp" ? $say_raritan : $say_apc;
	my $say_pdu3_brand = $an->data->{cgi}{anvil_pdu3_agent} eq "fence_raritan_snmp" ? $say_raritan : $say_apc;
	my $say_pdu4_brand = $an->data->{cgi}{anvil_pdu4_agent} eq "fence_raritan_snmp" ? $say_raritan : $say_apc;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "say_pdu1_brand", value1 => $say_pdu1_brand,
		name2 => "say_pdu2_brand", value2 => $say_pdu2_brand,
		name3 => "say_pdu3_brand", value3 => $say_pdu3_brand,
		name4 => "say_pdu4_brand", value4 => $say_pdu4_brand,
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{install_manifest}{pdu_count} == 2)
	{
		### Two PDU setup 
		# PDUs
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
			row		=>	"#!string!row_0196!#",
			column1		=>	$an->data->{cgi}{anvil_pdu1_name} ? $an->data->{cgi}{anvil_pdu1_name}." ($say_pdu1_brand)" : "--",
			column2		=>	$an->data->{cgi}{anvil_pdu1_ip}   ? $an->data->{cgi}{anvil_pdu1_ip}                       : "--",
			column3		=>	$an->data->{cgi}{anvil_pdu2_name} ? $an->data->{cgi}{anvil_pdu2_name}." ($say_pdu2_brand)" : "--",
			column4		=>	$an->data->{cgi}{anvil_pdu2_ip}   ? $an->data->{cgi}{anvil_pdu2_ip}                       : "--",
		}});
	}
	else
	{
		### Four PDU setup
		# 'PDU 1' will be for '1A' and '1B'.
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
			row		=>	"#!string!row_0276!#",
			column1		=>	$an->data->{cgi}{anvil_pdu1_name} ? $an->data->{cgi}{anvil_pdu1_name}." ($say_pdu1_brand)" : "--",
			column2		=>	$an->data->{cgi}{anvil_pdu1_ip}   ? $an->data->{cgi}{anvil_pdu1_ip}                       : "--",
			column3		=>	$an->data->{cgi}{anvil_pdu3_name} ? $an->data->{cgi}{anvil_pdu3_name}." ($say_pdu3_brand)" : "--",
			column4		=>	$an->data->{cgi}{anvil_pdu3_ip}   ? $an->data->{cgi}{anvil_pdu3_ip}                       : "--",
		}});
		
		# 'PDU 2' will be for '2A' and '2B'.
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
			row		=>	"#!string!row_0277!#",
			column1		=>	$an->data->{cgi}{anvil_pdu2_name} ? $an->data->{cgi}{anvil_pdu2_name}." ($say_pdu2_brand)" : "--",
			column2		=>	$an->data->{cgi}{anvil_pdu2_ip}   ? $an->data->{cgi}{anvil_pdu2_ip}                       : "--",
			column3		=>	$an->data->{cgi}{anvil_pdu4_name} ? $an->data->{cgi}{anvil_pdu4_name}." ($say_pdu4_brand)" : "--",
			column4		=>	$an->data->{cgi}{anvil_pdu4_ip}   ? $an->data->{cgi}{anvil_pdu4_ip}                       : "--",
		}});
	}
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-spacer"});
	
	# Shared Variables Header
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-title", replace => { title => "#!string!title_0154!#" }});
	
	# Anvil! name
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0005!#",
		column1		=>	$an->data->{cgi}{anvil_name},
		column2		=>	"&nbsp;",
	}});
	
	# Anvil! Password
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0194!#",
		column1		=>	$an->data->{cgi}{anvil_password},
		column2		=>	"&nbsp;",
	}});
	
	# Media Library size
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0191!#",
		column1		=>	$an->data->{cgi}{anvil_media_library_size}." ".$an->data->{cgi}{anvil_media_library_unit},
		column2		=>	"&nbsp;",
	}});
	
	### NOTE: Disabled now, always 100% to pool 1.
	# Storage Pool 1 size
	if (0)
	{
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
			row		=>	"#!string!row_0199!#",
			column1		=>	$an->data->{cgi}{anvil_storage_pool1_size}." ".$an->data->{cgi}{anvil_storage_pool1_unit},
			column2		=>	"&nbsp;",
		}});
	}
	
	# BCN Network Mask
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0200!#",
		column1		=>	$an->data->{cgi}{anvil_bcn_subnet},
		column2		=>	"&nbsp;",
	}});
	
	# SN Network Mask
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0201!#",
		column1		=>	$an->data->{cgi}{anvil_sn_subnet},
		column2		=>	"&nbsp;",
	}});
	
	# IFN Network Mask
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0202!#",
		column1		=>	$an->data->{cgi}{anvil_ifn_subnet},
		column2		=>	"&nbsp;",
	}});
	
	# Default Gateway
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0188!#",
		column1		=>	$an->data->{cgi}{anvil_ifn_gateway},
		column2		=>	"&nbsp;",
	}});
	
	# DNS 1
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0189!#",
		column1		=>	$an->data->{cgi}{anvil_dns1} ? $an->data->{cgi}{anvil_dns1} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	# DNS 2
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0189!#",
		column1		=>	$an->data->{cgi}{anvil_dns2} ? $an->data->{cgi}{anvil_dns2} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	# NTP 1
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0192!#",
		column1		=>	$an->data->{cgi}{anvil_ntp1} ? $an->data->{cgi}{anvil_ntp1} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	# NTP 2
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0193!#",
		column1		=>	$an->data->{cgi}{anvil_ntp2} ? $an->data->{cgi}{anvil_ntp2} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	# Repositories.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-one-column-entry", replace => { 
		row		=>	"#!string!row_0244!#",
		column1		=>	"$say_repos",
	}});
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-spacer"});
	
	# The footer has all the values recorded as hidden values for the form.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-footer", replace => { 
		anvil_prefix			=>	$an->data->{cgi}{anvil_prefix},
		anvil_sequence			=>	$an->data->{cgi}{anvil_sequence},
		anvil_domain			=>	$an->data->{cgi}{anvil_domain},
		anvil_password			=>	$an->data->{cgi}{anvil_password},
		anvil_bcn_ethtool_opts		=>	$an->data->{cgi}{anvil_bcn_ethtool_opts}, 
		anvil_bcn_network		=>	$an->data->{cgi}{anvil_bcn_network},
		anvil_bcn_subnet		=>	$an->data->{cgi}{anvil_bcn_subnet},
		anvil_sn_ethtool_opts		=>	$an->data->{cgi}{anvil_sn_ethtool_opts}, 
		anvil_sn_network		=>	$an->data->{cgi}{anvil_sn_network},
		anvil_sn_subnet			=>	$an->data->{cgi}{anvil_sn_subnet},
		anvil_ifn_ethtool_opts		=>	$an->data->{cgi}{anvil_ifn_ethtool_opts}, 
		anvil_ifn_network		=>	$an->data->{cgi}{anvil_ifn_network},
		anvil_ifn_subnet		=>	$an->data->{cgi}{anvil_ifn_subnet},
		anvil_media_library_size	=>	$an->data->{cgi}{anvil_media_library_size},
		anvil_media_library_unit	=>	$an->data->{cgi}{anvil_media_library_unit},
		anvil_storage_pool1_size	=>	$an->data->{cgi}{anvil_storage_pool1_size},
		anvil_storage_pool1_unit	=>	$an->data->{cgi}{anvil_storage_pool1_unit},
		anvil_name			=>	$an->data->{cgi}{anvil_name},
		anvil_node1_name		=>	$an->data->{cgi}{anvil_node1_name},
		anvil_node1_bcn_ip		=>	$an->data->{cgi}{anvil_node1_bcn_ip},
		anvil_node1_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link1_mac},
		anvil_node1_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link2_mac},
		anvil_node1_ipmi_ip		=>	$an->data->{cgi}{anvil_node1_ipmi_ip},
		anvil_node1_sn_ip		=>	$an->data->{cgi}{anvil_node1_sn_ip},
		anvil_node1_sn_link1_mac	=>	$an->data->{cgi}{anvil_node1_sn_link1_mac},
		anvil_node1_sn_link2_mac	=>	$an->data->{cgi}{anvil_node1_sn_link2_mac},
		anvil_node1_ifn_ip		=>	$an->data->{cgi}{anvil_node1_ifn_ip},
		anvil_node1_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link1_mac},
		anvil_node1_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link2_mac},
		anvil_node1_pdu1_outlet		=>	$an->data->{cgi}{anvil_node1_pdu1_outlet},
		anvil_node1_pdu2_outlet		=>	$an->data->{cgi}{anvil_node1_pdu2_outlet},
		anvil_node1_pdu3_outlet		=>	$an->data->{cgi}{anvil_node1_pdu3_outlet},
		anvil_node1_pdu4_outlet		=>	$an->data->{cgi}{anvil_node1_pdu4_outlet},
		anvil_node2_name		=>	$an->data->{cgi}{anvil_node2_name},
		anvil_node2_bcn_ip		=>	$an->data->{cgi}{anvil_node2_bcn_ip},
		anvil_node2_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link1_mac},
		anvil_node2_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link2_mac},
		anvil_node2_ipmi_ip		=>	$an->data->{cgi}{anvil_node2_ipmi_ip},
		anvil_node2_sn_ip		=>	$an->data->{cgi}{anvil_node2_sn_ip},
		anvil_node2_sn_link1_mac	=>	$an->data->{cgi}{anvil_node2_sn_link1_mac},
		anvil_node2_sn_link2_mac	=>	$an->data->{cgi}{anvil_node2_sn_link2_mac},
		anvil_node2_ifn_ip		=>	$an->data->{cgi}{anvil_node2_ifn_ip},
		anvil_node2_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link1_mac},
		anvil_node2_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link2_mac},
		anvil_node2_pdu1_outlet		=>	$an->data->{cgi}{anvil_node2_pdu1_outlet},
		anvil_node2_pdu2_outlet		=>	$an->data->{cgi}{anvil_node2_pdu2_outlet},
		anvil_node2_pdu3_outlet		=>	$an->data->{cgi}{anvil_node2_pdu3_outlet},
		anvil_node2_pdu4_outlet		=>	$an->data->{cgi}{anvil_node2_pdu4_outlet},
		anvil_ifn_gateway		=>	$an->data->{cgi}{anvil_ifn_gateway},
		anvil_dns1			=>	$an->data->{cgi}{anvil_dns1},
		anvil_dns2			=>	$an->data->{cgi}{anvil_dns2},
		anvil_ntp1			=>	$an->data->{cgi}{anvil_ntp1},
		anvil_ntp2			=>	$an->data->{cgi}{anvil_ntp2},
		anvil_ups1_name			=>	$an->data->{cgi}{anvil_ups1_name},
		anvil_ups1_ip			=>	$an->data->{cgi}{anvil_ups1_ip},
		anvil_ups2_name			=>	$an->data->{cgi}{anvil_ups2_name},
		anvil_ups2_ip			=>	$an->data->{cgi}{anvil_ups2_ip},
		anvil_pts1_name			=>	$an->data->{cgi}{anvil_pts1_name},
		anvil_pts1_ip			=>	$an->data->{cgi}{anvil_pts1_ip},
		anvil_pts2_name			=>	$an->data->{cgi}{anvil_pts2_name},
		anvil_pts2_ip			=>	$an->data->{cgi}{anvil_pts2_ip},
		anvil_pdu1_name			=>	$an->data->{cgi}{anvil_pdu1_name},
		anvil_pdu1_ip			=>	$an->data->{cgi}{anvil_pdu1_ip},
		anvil_pdu1_agent		=>	$an->data->{cgi}{anvil_pdu1_agent},
		anvil_pdu2_name			=>	$an->data->{cgi}{anvil_pdu2_name},
		anvil_pdu2_ip			=>	$an->data->{cgi}{anvil_pdu2_ip},
		anvil_pdu2_agent		=>	$an->data->{cgi}{anvil_pdu2_agent},
		anvil_pdu3_name			=>	$an->data->{cgi}{anvil_pdu3_name},
		anvil_pdu3_ip			=>	$an->data->{cgi}{anvil_pdu3_ip},
		anvil_pdu3_agent		=>	$an->data->{cgi}{anvil_pdu3_agent},
		anvil_pdu4_name			=>	$an->data->{cgi}{anvil_pdu4_name},
		anvil_pdu4_ip			=>	$an->data->{cgi}{anvil_pdu4_ip},
		anvil_pdu4_agent		=>	$an->data->{cgi}{anvil_pdu4_agent},
		anvil_switch1_name		=>	$an->data->{cgi}{anvil_switch1_name},
		anvil_switch1_ip		=>	$an->data->{cgi}{anvil_switch1_ip},
		anvil_switch2_name		=>	$an->data->{cgi}{anvil_switch2_name},
		anvil_switch2_ip		=>	$an->data->{cgi}{anvil_switch2_ip},
		anvil_striker1_name		=>	$an->data->{cgi}{anvil_striker1_name},
		anvil_striker1_bcn_ip		=>	$an->data->{cgi}{anvil_striker1_bcn_ip},
		anvil_striker1_ifn_ip		=>	$an->data->{cgi}{anvil_striker1_ifn_ip},
		anvil_striker2_name		=>	$an->data->{cgi}{anvil_striker2_name},
		anvil_striker2_bcn_ip		=>	$an->data->{cgi}{anvil_striker2_bcn_ip},
		anvil_striker2_ifn_ip		=>	$an->data->{cgi}{anvil_striker2_ifn_ip},
		anvil_repositories		=>	$an->data->{cgi}{anvil_repositories},
		anvil_mtu_size			=>	$an->data->{cgi}{anvil_mtu_size},
		say_anvil_repositories		=>	$say_repos,
		'anvil_drbd_disk_disk-barrier'	=>	$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
		'anvil_drbd_disk_disk-flushes'	=>	$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
		'anvil_drbd_disk_md-flushes'	=>	$an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
		'anvil_drbd_options_cpu-mask'	=>	$an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
		'anvil_drbd_net_max-buffers'	=>	$an->data->{cgi}{'anvil_drbd_net_max-buffers'},
		'anvil_drbd_net_sndbuf-size'	=>	$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
		'anvil_drbd_net_rcvbuf-size'	=>	$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
		manifest_uuid			=>	$an->data->{cgi}{manifest_uuid},
	}});
	
	return(0);
}

# This sanity-checks the user's answers.
sub sanity_check_manifest_answers
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "sanity_check_manifest_answers" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Clear all variables.
	my $problem = 0;
	
	# Make sure the sequence number is valid.
	if (not $an->data->{cgi}{anvil_sequence})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_sequence_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0161!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_sequence} =~ /\D/)
	{
		$an->data->{form}{anvil_sequence_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0102", variables => { field => "#!string!row_0161!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Now check the domain
	if (not $an->data->{cgi}{anvil_domain})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_domain_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0160!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_domain}}))
	{
		$an->data->{form}{anvil_domain_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0160!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# The password can not be blank, that's all we check for though.
	if (not $an->data->{cgi}{anvil_password})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_password_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0194!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### Start testing common stuff.
	# BCN network block and subnet mask
	if (not $an->data->{cgi}{anvil_bcn_network})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0116", variables => { field => "#!string!row_0162!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_bcn_network}}))
	{
		$an->data->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0118", variables => { field => "#!string!row_0162!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_bcn_subnet})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0117", variables => { field => "#!string!row_0162!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_bcn_subnet}}))
	{
		$an->data->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0119", variables => { field => "#!string!row_0162!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# SN network block and subnet mask
	if (not $an->data->{cgi}{anvil_sn_network})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0116", variables => { field => "#!string!row_0163!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_sn_network}}))
	{
		$an->data->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0118", variables => { field => "#!string!row_0163!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_sn_subnet})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0117", variables => { field => "#!string!row_0163!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_sn_subnet}}))
	{
		$an->data->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0119", variables => { field => "#!string!row_0163!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# IFN network block and subnet mask
	if (not $an->data->{cgi}{anvil_ifn_network})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0116", variables => { field => "#!string!row_0164!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ifn_network}}))
	{
		$an->data->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0118", variables => { field => "#!string!row_0164!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_ifn_subnet})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0117", variables => { field => "#!string!row_0164!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ifn_subnet}}))
	{
		$an->data->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0119", variables => { field => "#!string!row_0164!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# MTU
	$an->data->{cgi}{anvil_mtu_size} =~ s/,//g;
	$an->data->{cgi}{anvil_mtu_size} =~ s/\s+//g;
	if (not $an->data->{cgi}{anvil_mtu_size})
	{
		$an->data->{cgi}{anvil_mtu_size} = $an->data->{sys}{install_manifest}{'default'}{mtu_size};
	}
	else
	{
		# Defined, sane?
		if ($an->data->{cgi}{anvil_mtu_size} =~ /\D/)
		{
			$an->data->{form}{anvil_mtu_size_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0102", variables => { field => "#!string!row_0291!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		# Is the MTU too small or too big? - https://tools.ietf.org/html/rfc879
		elsif ($an->data->{cgi}{anvil_mtu_size} < 576)
		{
			$an->data->{form}{anvil_mtu_size_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0157", variables => { field => "#!string!row_0291!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
	}
	
	### TODO: Worth checking the select box values?
	# Check the /shared and node 1 storage sizes.
	if (not $an->data->{cgi}{anvil_media_library_size})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_media_library_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0191!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_integer_or_unsigned_float({number => $an->data->{cgi}{anvil_media_library_size}}))
	{
		$an->data->{form}{anvil_media_library_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0121", variables => { field => "#!string!row_0191!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check the size of the node 1 storage pool.
	if (not $an->data->{cgi}{anvil_storage_pool1_size})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0199!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_integer_or_unsigned_float({number => $an->data->{cgi}{anvil_storage_pool1_size}}))
	{
		$an->data->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0121", variables => { field => "#!string!row_0199!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	} # Make sure the percentage is between 0 and 100.
	elsif (($an->data->{cgi}{anvil_storage_pool1_unit} eq "%") && (($an->data->{cgi}{anvil_storage_pool1_size} < 0) || ($an->data->{cgi}{anvil_storage_pool1_size} > 100)))
	{
		$an->data->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0120", variables => { field => "#!string!row_0199!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check the repositor{y,ies} if passed.
	if ($an->data->{cgi}{anvil_repositories})
	{
		foreach my $url (split/,/, $an->data->{cgi}{anvil_repositories})
		{
			$url =~ s/^\s+//;
			$url =~ s/\s+$//;
			if (not $an->Validate->is_url({url => $url}))
			{
				$an->data->{form}{anvil_repositories_star} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0140", variables => { field => "#!string!row_0244!#" }});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
		}
	}

	# Check the anvil!'s cluster name.
	if (not $an->data->{cgi}{anvil_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0005!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	} # cman only allows 1-15 characters
	elsif (length($an->data->{cgi}{anvil_name}) > 15)
	{
		$an->data->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0122", variables => { field => "#!string!row_0005!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_name} =~ /[^a-zA-Z0-9\-]/)
	{
		$an->data->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0123", variables => { field => "#!string!row_0005!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### Convery anything with the value '--' to ''.
	$an->data->{cgi}{anvil_ifn_gateway}     = "" if $an->data->{cgi}{anvil_ifn_gateway}     eq "--";
	$an->data->{cgi}{anvil_dns1}            = "" if $an->data->{cgi}{anvil_dns1}            eq "--";
	$an->data->{cgi}{anvil_dns2}            = "" if $an->data->{cgi}{anvil_dns1}            eq "--";
	$an->data->{cgi}{anvil_ntp1}            = "" if $an->data->{cgi}{anvil_ntp1}            eq "--";
	$an->data->{cgi}{anvil_ntp2}            = "" if $an->data->{cgi}{anvil_ntp1}            eq "--";
	$an->data->{cgi}{anvil_switch1_name}    = "" if $an->data->{cgi}{anvil_switch1_name}    eq "--";
	$an->data->{cgi}{anvil_switch1_ip}      = "" if $an->data->{cgi}{anvil_switch1_ip}      eq "--";
	$an->data->{cgi}{anvil_switch2_name}    = "" if $an->data->{cgi}{anvil_switch2_name}    eq "--";
	$an->data->{cgi}{anvil_switch2_ip}      = "" if $an->data->{cgi}{anvil_switch2_ip}      eq "--";
	$an->data->{cgi}{anvil_pdu1_name}       = "" if $an->data->{cgi}{anvil_pdu1_name}       eq "--";
	$an->data->{cgi}{anvil_pdu1_ip}         = "" if $an->data->{cgi}{anvil_pdu1_ip}         eq "--";
	$an->data->{cgi}{anvil_pdu2_name}       = "" if $an->data->{cgi}{anvil_pdu2_name}       eq "--";
	$an->data->{cgi}{anvil_pdu2_ip}         = "" if $an->data->{cgi}{anvil_pdu2_ip}         eq "--";
	$an->data->{cgi}{anvil_pdu3_name}       = "" if $an->data->{cgi}{anvil_pdu3_name}       eq "--";
	$an->data->{cgi}{anvil_pdu3_ip}         = "" if $an->data->{cgi}{anvil_pdu3_ip}         eq "--";
	$an->data->{cgi}{anvil_pdu4_name}       = "" if $an->data->{cgi}{anvil_pdu4_name}       eq "--";
	$an->data->{cgi}{anvil_pdu4_ip}         = "" if $an->data->{cgi}{anvil_pdu4_ip}         eq "--";
	$an->data->{cgi}{anvil_ups1_name}       = "" if $an->data->{cgi}{anvil_ups1_name}       eq "--";
	$an->data->{cgi}{anvil_ups1_ip}         = "" if $an->data->{cgi}{anvil_ups1_ip}         eq "--";
	$an->data->{cgi}{anvil_ups2_name}       = "" if $an->data->{cgi}{anvil_ups2_name}       eq "--";
	$an->data->{cgi}{anvil_ups2_ip}         = "" if $an->data->{cgi}{anvil_ups2_ip}         eq "--";
	$an->data->{cgi}{anvil_pts1_name}       = "" if $an->data->{cgi}{anvil_pts1_name}       eq "--";
	$an->data->{cgi}{anvil_pts1_ip}         = "" if $an->data->{cgi}{anvil_pts1_ip}         eq "--";
	$an->data->{cgi}{anvil_pts2_name}       = "" if $an->data->{cgi}{anvil_pts2_name}       eq "--";
	$an->data->{cgi}{anvil_pts2_ip}         = "" if $an->data->{cgi}{anvil_pts2_ip}         eq "--";
	$an->data->{cgi}{anvil_striker1_name}   = "" if $an->data->{cgi}{anvil_striker1_name}   eq "--";
	$an->data->{cgi}{anvil_striker1_bcn_ip} = "" if $an->data->{cgi}{anvil_striker1_bcn_ip} eq "--";
	$an->data->{cgi}{anvil_striker1_ifn_ip} = "" if $an->data->{cgi}{anvil_striker1_ifn_ip} eq "--";
	$an->data->{cgi}{anvil_striker2_name}   = "" if $an->data->{cgi}{anvil_striker2_name}   eq "--";
	$an->data->{cgi}{anvil_striker2_bcn_ip} = "" if $an->data->{cgi}{anvil_striker2_bcn_ip} eq "--";
	$an->data->{cgi}{anvil_striker2_ifn_ip} = "" if $an->data->{cgi}{anvil_striker2_ifn_ip} eq "--";
	$an->data->{cgi}{anvil_node1_ipmi_ip}   = "" if $an->data->{cgi}{anvil_node1_ipmi_ip}   eq "--";
	$an->data->{cgi}{anvil_node2_ipmi_ip}   = "" if $an->data->{cgi}{anvil_node2_ipmi_ip}   eq "--";
	$an->data->{cgi}{anvil_open_vnc_ports}  = "" if $an->data->{cgi}{anvil_open_vnc_ports}  eq "--";
	
	## Check the common IFN values.
	# Check the gateway
	if (not $an->data->{cgi}{anvil_ifn_gateway})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ifn_gateway_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0188!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ifn_gateway}}))
	{
		$an->data->{form}{anvil_ifn_gateway_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0188!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### DNS is allowed to be blank but, if it is set, it must be IPv4.
	# Check DNS 1
	if (($an->data->{cgi}{anvil_dns1}) && (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_dns1}})))
	{
		$an->data->{form}{anvil_dns1_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0189!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check DNS 2
	if (($an->data->{cgi}{anvil_dns2}) && (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_dns2}})))
	{
		$an->data->{form}{anvil_dns2_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0190!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### NTP is allowed to be blank, but if it is set, if must be IPv4 or a domain name.
	# Check NTP 1
	if ($an->data->{cgi}{anvil_ntp1})
	{
		# It's defined, so it has to be either a domain name or an IPv4 IP.
		if ((not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ntp1}})) && (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_ntp1}})))
		{
			$an->data->{form}{anvil_ntp1_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0099", variables => { field => "#!string!row_0192!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
	}
	
	# Check NTP 2
	if ($an->data->{cgi}{anvil_ntp2})
	{
		# It's defined, so it has to be either a domain name or an IPv4 IP.
		if ((not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ntp2}})) && (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_ntp2}})))
		{
			$an->data->{form}{anvil_ntp2_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0099", variables => { field => "#!string!row_0193!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
	}
	
	### Foundation Pack
	# Check that switch #1's host name and IP are sane, if set. The switches are allowed to be blank in 
	# case the user has unmanaged switches.
	if (not $an->data->{cgi}{anvil_switch1_name})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($an->data->{cgi}{anvil_switch1_ip}) && ($an->data->{cgi}{anvil_switch1_ip} ne "--"))
		{
			# IP set, so host name is needed.
			$an->data->{form}{anvil_switch1_name_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0111", variables => { field => "#!string!row_0178!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		else
		{
			# Is OK
			$an->data->{cgi}{anvil_switch1_name} = "--";
		}
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_switch1_name}}))
	{
		$an->data->{form}{anvil_switch1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0178!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_switch1_ip})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($an->data->{cgi}{anvil_switch1_name}) && ($an->data->{cgi}{anvil_switch1_name} ne "--"))
		{
			# Host name set, so IP is needed.
			$an->data->{form}{anvil_switch1_ip_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0112", variables => { field => "#!string!row_0179!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		else
		{
			# Is OK
			$an->data->{cgi}{anvil_switch1_ip} = "--";
		}
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_switch1_ip}}))
	{
		$an->data->{form}{anvil_switch1_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0179!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that switch #2's host name and IP are sane.
	if (not $an->data->{cgi}{anvil_switch2_name})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($an->data->{cgi}{anvil_switch2_ip}) && ($an->data->{cgi}{anvil_switch2_ip} ne "--"))
		{
			# IP set, so host name is needed.
			$an->data->{form}{anvil_switch2_name_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0111", variables => { field => "#!string!row_0178!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		else
		{
			# Is OK
			$an->data->{cgi}{anvil_switch2_name} = "--";
		}
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_switch2_name}}))
	{
		$an->data->{form}{anvil_switch2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0180!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_switch2_ip})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($an->data->{cgi}{anvil_switch2_name}) && ($an->data->{cgi}{anvil_switch2_name} ne "--"))
		{
			# Host name set, so IP is needed.
			$an->data->{form}{anvil_switch2_ip_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0112", variables => { field => "#!string!row_0181!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		else
		{
			# Is OK
			$an->data->{cgi}{anvil_switch2_ip} = "--";
		}
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_switch2_ip}}))
	{
		$an->data->{form}{anvil_switch2_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0181!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### At least two PDUs must be defined.
	# Check that PDU #1's host name and IP are sane.
	my $defined_pdus = 0;
	my $pdus         = [0, 0, 0, 0];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "defined_pdus", value1 => $defined_pdus,
		name2 => "pdus",         value2 => $pdus,
		name3 => "pdus->[0]",    value3 => $pdus->[0],
		name4 => "pdus->[1]",    value4 => $pdus->[1],
		name5 => "pdus->[2]",    value5 => $pdus->[2],
		name6 => "pdus->[3]",    value6 => $pdus->[3],
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $i (1..4)
	{
		my $name_key      = "anvil_pdu${i}_name";
		my $ip_key        = "anvil_pdu${i}_ip";
		my $name_star_key = "anvil_pdu${i}_name_star";
		my $ip_star_key   = "anvil_pdu${i}_ip_star";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "i",             value1 => $i,
			name2 => "name_key",      value2 => $name_key,
			name3 => "ip_key",        value3 => $ip_key,
			name4 => "name_star_key", value4 => $name_star_key,
			name5 => "ip_star_key",   value5 => $ip_star_key,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Some clients/users want PDUs name '1,2,3,4', others 
		# '1A,1B,2A,2B'. This allows for that.
		my $say_pdu = "";
		if ($i == 1)    { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
		elsif ($i == 2) { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
		elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
		elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "i",       value1 => $i,
			name2 => "say_pdu", value2 => $say_pdu,
		}, file => $THIS_FILE, line => __LINE__});
		my $say_pdu_name = $an->String->get({key => "row_0174", variables => { say_pdu => $say_pdu }});
		my $say_pdu_ip   = $an->String->get({key => "row_0175", variables => { say_pdu => $say_pdu }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "i",            value1 => $i,
			name2 => "say_pdu_name", value2 => $say_pdu_name,
			name3 => "say_pdu_ip",   value3 => $say_pdu_ip,
		}, file => $THIS_FILE, line => __LINE__});
		
		# If either the IP or name is set, validate.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "i",              value1 => $i,
			name2 => "cgi::$name_key", value2 => $an->data->{cgi}{$name_key},
			name3 => "cgi::$ip_key",   value3 => $an->data->{cgi}{$ip_key},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{cgi}{$name_key}) || ($an->data->{cgi}{$ip_key}))
		{
			$defined_pdus++;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "i",            value1 => $i,
				name2 => "defined_pdus", value2 => $defined_pdus,
				name3 => "pdus",         value3 => $pdus,
			}, file => $THIS_FILE, line => __LINE__});
			$pdus->[$i] = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "pdus->[$i]", value1 => $pdus->[$i],
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{cgi}{$name_key})
			{
				# Not allowed to be blank.
				$an->data->{form}{$name_star_key} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0142", variables => { 
						field 		=>	$say_pdu_name,
						dependent_field	=>	$say_pdu_ip,
					}});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
			elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{$name_key}}))
			{
				$an->data->{form}{$name_star_key} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0103", variables => { field => $say_pdu_name }});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
			if (not $an->data->{cgi}{$ip_key})
			{
				# Not allowed to be blank.
				$an->data->{form}{$ip_star_key} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0142", variables => { 
						field 		=>	$say_pdu_ip,
						dependent_field	=>	$say_pdu_name,
					}});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
			elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{$ip_key}}))
			{
				$an->data->{form}{$ip_star_key} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0104", variables => { field => $say_pdu_ip }});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
		}
	}
	
	# Each node has to have an outlet defined for at least two PDUs.
	foreach my $j (1, 2)
	{
		my $node_pdu_count = 0;
		my $say_node       = $an->String->get({key => "title_0156", variables => { node_number => $j }});
		foreach my $i (1..4)
		{
			my $outlet_key      = "anvil_node${j}_pdu${i}_outlet";
			my $outlet_star_key = "anvil_node${j}_pdu${i}_outlet_star";
			my $say_pdu         = "";
			if ($i == 1)    { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
			elsif ($i == 2) { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
			elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
			elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
			my $say_pdu_name = $an->String->get({key => "row_0174", variables => { say_pdu => $say_pdu }});
			if ($an->data->{cgi}{$outlet_key})
			{
				$node_pdu_count++;
				if ($an->data->{cgi}{$outlet_key} =~ /\D/)
				{
					$an->data->{form}{$outlet_star_key} = "#!string!symbol_0012!#";
					my $message = $an->String->get({key => "explain_0108", variables => { 
							node	=>	$say_node,
							field	=>	$say_pdu_name,
						}});
					print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
					$problem = 1;
				}
				# Make sure this PDU is defined.
				if (not $pdus->[$i])
				{
					# It's not.
					$an->data->{form}{$outlet_star_key} = "#!string!symbol_0012!#";
					my $message = $an->String->get({key => "explain_0144", variables => { 
							node	=>	$say_node,
							field	=>	$say_pdu_name,
						}});
					print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
					$problem = 1;
				}
			}
		}
		
		# If there isn't at least 2 outlets defined, bail.
		if ($node_pdu_count < 2)
		{
			my $message = $an->String->get({key => "explain_0145", variables => { node => $say_node }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
	}
	
	# Make sure at least two PDUs were defined.
	if ($defined_pdus < 2)
	{
		# Not allowed!
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => "#!string!explain_0143!#" }});
		$problem = 1;
	}
	
	# Check that UPS #1's host name and IP are sane.
	if (not $an->data->{cgi}{anvil_ups1_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ups1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0170!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_ups1_name}}))
	{
		$an->data->{form}{anvil_ups1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0170!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_ups1_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ups1_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0171!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ups1_ip}}))
	{
		$an->data->{form}{anvil_ups1_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0171!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that UPS #2's host name and IP are sane.
	if (not $an->data->{cgi}{anvil_ups2_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ups2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0172!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_ups2_name}}))
	{
		$an->data->{form}{anvil_ups2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0172!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_ups2_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ups2_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0173!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ups2_ip}}))
	{
		$an->data->{form}{anvil_ups2_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0173!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that PTS #1's host name and IP are sane.
	if (($an->data->{cgi}{anvil_pts1_name}) && (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_pts1_name}})))
	{
		$an->data->{form}{anvil_pts1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0296!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (($an->data->{cgi}{anvil_pts1_ip}) && (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_pts1_ip}})))
	{
		$an->data->{form}{anvil_pts1_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0297!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that PTS #2's host name and IP are sane.
	if (($an->data->{cgi}{anvil_pts2_name}) && (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_pts2_name}})))
	{
		$an->data->{form}{anvil_pts2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0298!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (($an->data->{cgi}{anvil_pts2_ip}) && (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_pts2_ip}})))
	{
		$an->data->{form}{anvil_pts2_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0299!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that Striker #1's host name and BCN and IFN IPs are sane.
	if (not $an->data->{cgi}{anvil_striker1_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_striker1_name}}))
	{
		$an->data->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_striker1_name} !~ /\./)
	{
		# Must be a FQDN
		$an->data->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0042", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_striker1_bcn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0183!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_striker1_bcn_ip}}))
	{
		$an->data->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0183!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_striker1_ifn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker1_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0184!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_striker1_bcn_ip}}))
	{
		$an->data->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0184!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that Striker #2's host name and BCN and IFN IPs are sane.
	if (not $an->data->{cgi}{anvil_striker2_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0185!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_striker2_name}}))
	{
		$an->data->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0185!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_striker2_name} !~ /\./)
	{
		# Must be a FQDN
		$an->data->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0042", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_striker2_bcn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0186!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_striker2_bcn_ip}}))
	{
		$an->data->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0186!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_striker2_ifn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker2_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0187!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_striker2_bcn_ip}}))
	{
		$an->data->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0187!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### Node specific values.
	# Node 1
	# Host name
	if (not $an->data->{cgi}{anvil_node1_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0165!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_node1_name}}))
	{
		$an->data->{form}{anvil_node1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0107", variables => { 
				field	=>	"#!string!row_0165!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_node2_name} !~ /\./)
	{
		# Must be a FQDN
		$an->data->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0042", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# BCN IP address
	if (not $an->data->{cgi}{anvil_node1_bcn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0166!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node1_bcn_ip}}))
	{
		$an->data->{form}{anvil_node1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0166!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IPMI IP address
	if (not $an->data->{cgi}{anvil_node1_ipmi_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_ipmi_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0168!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node1_ipmi_ip}}))
	{
		$an->data->{form}{anvil_node1_ipmi_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0168!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# SN IP address
	if (not $an->data->{cgi}{anvil_node1_sn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_sn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node1_sn_ip}}))
	{
		$an->data->{form}{anvil_node1_sn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IFN IP address
	if (not $an->data->{cgi}{anvil_node1_ifn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node1_ifn_ip}}))
	{
		$an->data->{form}{anvil_node1_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Node 2
	# Host name
	if (not $an->data->{cgi}{anvil_node2_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0165!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_node2_name}}))
	{
		$an->data->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0107", variables => { 
				field	=>	"#!string!row_0165!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# BCN IP address
	if (not $an->data->{cgi}{anvil_node2_bcn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0166!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node2_bcn_ip}}))
	{
		$an->data->{form}{anvil_node2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0166!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IPMI IP address
	if (not $an->data->{cgi}{anvil_node2_ipmi_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_ipmi_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0168!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node2_ipmi_ip}}))
	{
		$an->data->{form}{anvil_node2_ipmi_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0168!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# SN IP address
	if (not $an->data->{cgi}{anvil_node2_sn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_sn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node2_sn_ip}}))
	{
		$an->data->{form}{anvil_node2_sn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IFN IP address
	if (not $an->data->{cgi}{anvil_node2_ifn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node2_ifn_ip}}))
	{
		$an->data->{form}{anvil_node2_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	return($problem);
}

# This allows the user to configure their dashboard.
sub configure_dashboard
{
	my ($an) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_dashboard" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Storage->read_hosts();
	$an->Storage->read_ssh_config();
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::save", value1 => $an->data->{cgi}{save},
		name2 => "cgi::task", value2 => $an->data->{cgi}{task},
	}, file => $THIS_FILE, line => __LINE__});
	my $show_global = 1;
	if ($an->data->{cgi}{save})
	{
		if ($an->data->{cgi}{task} eq "create-install-manifest")
		{
			create_install_manifest($an);
			return(0);
		}
		else
		{
			save_dashboard_configure($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "push")
	{
		push_config_to_anvil($an);
	}
	elsif ($an->data->{cgi}{task} eq "archive")
	{
		show_archive_options($an);
		$show_global = 0;
	}
	elsif ($an->data->{cgi}{task} eq "load_config")
	{
		load_backup_configuration($an);
	}
	elsif ($an->data->{cgi}{task} eq "create-install-manifest")
	{
		create_install_manifest($an);
		return(0);
	}
	
	### Header section
	# If showing the main page, it's global settings and then the list of Anvil!s. If showing an Anvil!,
	# it's the Anvil!'s details and then the overrides.

	print $an->Web->template({file => "config.html", template => "open-form-table", replace => { form_file => "/cgi-bin/striker" }});
	
	# If showing an Anvil!, display it's details first.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil", value1 => $an->data->{cgi}{anvil},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{anvil})
	{
		# Show Anvil! header and node settings.
		show_anvil_config_header($an);
	}
	else
	{
		# Show the global header only. We'll show the settings in a minute.
		show_global_config_header($an) if $show_global;
	}
	
	# Show the common options (whether global or anvil-specific will have been sorted out above.
	show_common_config_section($an) if $show_global;
	
	my $say_section = "global";
	if ($an->data->{cgi}{anvil})
	{
		$say_section = "anvil";
	}
	else
	{
		# Show the list of Anvil!s if this is the global section.
		#show_global_anvil_list($an);
	}
	# Close out the form.
	print $an->Web->template({file => "config.html", template => "close-form-table"});

	return(0);
}

# This takes a plain text string and escapes special characters for displaying
# in HTML.
sub convert_text_to_html
{
	my ($an, $string) = @_;
	$string = "" if not defined $string;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "convert_text_to_html" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "string", value1 => $string,
	}, file => $THIS_FILE, line => __LINE__});
	$string =~ s/;/&#59;/g;		# Semi-colon - Must be first!  \
	$string =~ s/&/&amp;/g;		# Ampersand - Must be second!  |- These three are used in other escape codes
	$string =~ s/#/&#35;/g;		# Number sign - Must be third! /
# 	$string =~ s/\t/ &nbsp; &nbsp;/g;	# Horizontal tab
	#$string =~ s/\n/&#10;/g;	# Line feed
	#$string =~ s/\r/&#13;/g;	# Carriage Return
# 	$string =~ s/\s/ /g;	# Space
# 	$string =~ s/!/&#33;/g;		# Exclamation mark
	$string =~ s/\n/#!br!#/g;
	$string =~ s/"/&#34;/g;		# Quotation mark
	$string =~ s/\$/&#36;/g;	# Dollar sign
	$string =~ s/\%/&#37;/g;	# Percent sign
 	$string =~ s/'/&#39;/g;		# Apostrophe
#	$string =~ s/'/&rsquo;/g;	# Apostrophe - But in a JS-friendly format.
	$string =~ s/\(/&#40;/g;	# Left parenthesis
	$string =~ s/\)/&#41;/g;	# Right parenthesis
	$string =~ s/\*/&#42;/g;	# Asterisk
	$string =~ s/\+/&#43;/g;	# Plus sign
	$string =~ s/,/&#44;/g;		# Comma
	$string =~ s/-/&#45;/g;		# Hyphen
	$string =~ s/\./&#46;/g;	# Period (fullstop)
	$string =~ s/\//&#47;/g;	# Solidus (slash)
	$string =~ s/:/&#58;/g;		# Colon
	$string =~ s/</&lt;/g;		# Less than
	$string =~ s/=/&#61;/g;		# Equals sign
	$string =~ s/>/&gt;/g;		# Greater than
	$string =~ s/\?/&#63;/g;	# Question mark
	$string =~ s/\@/&#64;/g;	# Commercial at
	$string =~ s/\[/&#91;/g;	# Left square bracket
	$string =~ s/\\/&#92;/g;	# Reverse solidus (backslash)
	$string =~ s/\]/&#93;/g;	# Right square bracket
	$string =~ s/\^/&#94;/g;	# Caret
	$string =~ s/_/&#95;/g;		# Horizontal bar (underscore)
	$string =~ s/`/&#96;/g;		# Acute accent# 	if ($string =~/^Qu/ ) { print $log "=2 string: [$string]<br />\n"; }
	$string =~ s/{/&#123;/g;	# Left curly brace
	$string =~ s/\|/&#124;/g;	# Vertical bar
	$string =~ s/}/&#125;/g;	# Right curly brace
	$string =~ s/~/&#126;/g;	# Tilde
	$string =~ s/  /&nbsp; /g;	# Non-breaking Space
	$string =~ s/¡/&#161;/g;	# Inverted exclamation
	$string =~ s/¢/&#162;/g;	# Cent sign
	$string =~ s/£/&#163;/g;	# Pound sterling
	$string =~ s/¤/&#164;/g;	# General currency sign
	$string =~ s/¥/&#165;/g;	# Yen sign
	$string =~ s/¦/&#166;/g;	# Broken vertical bar
	$string =~ s/§/&#167;/g;	# Section sign
	$string =~ s/¨/&#168;/g;	# Umlaut (dieresis)
	$string =~ s/©/&copy;/g;	# Copyright
	$string =~ s/ª/&#170;/g;	# Feminine ordinal
	$string =~ s/«/&#171;/g;	# Left angle quote, guillemotleft
	$string =~ s/¬/&#172;/g;	# Not sign
	$string =~ s/­/&#173;/g;		# Soft hyphen
	$string =~ s/®/&#174;/g;	# Registered trademark
	$string =~ s/¯/&#175;/g;	# Macron accent
	$string =~ s/°/&#176;/g;	# Degree sign
	$string =~ s/±/&#177;/g;	# Plus or minus
	$string =~ s/²/&#178;/g;	# Superscript two
	$string =~ s/³/&#179;/g;	# Superscript three
	$string =~ s/´/&#180;/g;	# Acute accent
	$string =~ s/µ/&#181;/g;	# Micro sign
	$string =~ s/¶/&#182;/g;	# Paragraph sign
	$string =~ s/·/&#183;/g;	# Middle dot
	$string =~ s/¸/&#184;/g;	# Cedilla
	$string =~ s/¹/&#185;/g;	# Superscript one
	$string =~ s/º/&#186;/g;	# Masculine ordinal
	$string =~ s/»/&#187;/g;	# Right angle quote, guillemotright
	$string =~ s/¼/&frac14;/g;	# Fraction one-fourth
	$string =~ s/½/&frac12;/g;	# Fraction one-half
	$string =~ s/¾/&frac34;/g;	# Fraction three-fourths
	$string =~ s/¿/&#191;/g;	# Inverted question mark
	$string =~ s/À/&#192;/g;	# Capital A, grave accent
	$string =~ s/Á/&#193;/g;	# Capital A, acute accent
	$string =~ s/Â/&#194;/g;	# Capital A, circumflex accent
	$string =~ s/Ã/&#195;/g;	# Capital A, tilde
	$string =~ s/Ä/&#196;/g;	# Capital A, dieresis or umlaut mark
	$string =~ s/Å/&#197;/g;	# Capital A, ring
	$string =~ s/Æ/&#198;/g;	# Capital AE dipthong (ligature)
	$string =~ s/Ç/&#199;/g;	# Capital C, cedilla
	$string =~ s/È/&#200;/g;	# Capital E, grave accent
	$string =~ s/É/&#201;/g;	# Capital E, acute accent
	$string =~ s/Ê/&#202;/g;	# Capital E, circumflex accent
	$string =~ s/Ë/&#203;/g;	# Capital E, dieresis or umlaut mark
	$string =~ s/Ì/&#204;/g;	# Capital I, grave accent
	$string =~ s/Í/&#205;/g;	# Capital I, acute accent
	$string =~ s/Î/&#206;/g;	# Capital I, circumflex accent
	$string =~ s/Ï/&#207;/g;	# Capital I, dieresis or umlaut mark
	$string =~ s/Ð/&#208;/g;	# Capital Eth, Icelandic
	$string =~ s/Ñ/&#209;/g;	# Capital N, tilde
	$string =~ s/Ò/&#210;/g;	# Capital O, grave accent
	$string =~ s/Ó/&#211;/g;	# Capital O, acute accent
	$string =~ s/Ô/&#212;/g;	# Capital O, circumflex accent
	$string =~ s/Õ/&#213;/g;	# Capital O, tilde
	$string =~ s/Ö/&#214;/g;	# Capital O, dieresis or umlaut mark
	$string =~ s/×/&#215;/g;	# Multiply sign
	$string =~ s/Ø/&#216;/g;	# Capital O, slash
	$string =~ s/Ù/&#217;/g;	# Capital U, grave accent
	$string =~ s/Ú/&#218;/g;	# Capital U, acute accent
	$string =~ s/Û/&#219;/g;	# Capital U, circumflex accent
	$string =~ s/Ü/&#220;/g;	# Capital U, dieresis or umlaut mark
	$string =~ s/Ý/&#221;/g;	# Capital Y, acute accent
	$string =~ s/Þ/&#222;/g;	# Capital THORN, Icelandic
	$string =~ s/ß/&#223;/g;	# Small sharp s, German (sz ligature)
	$string =~ s/à/&#224;/g;	# Small a, grave accent
	$string =~ s/á/&#225;/g;	# Small a, acute accent
	$string =~ s/â/&#226;/g;	# Small a, circumflex accent
	$string =~ s/ã/&#227;/g;	# Small a, tilde
	$string =~ s/ä/&#228;/g;	# Small a, dieresis or umlaut mark
	$string =~ s/å/&#229;/g;	# Small a, ring
	$string =~ s/æ/&#230;/g;	# Small ae dipthong (ligature)
	$string =~ s/ç/&#231;/g;	# Small c, cedilla
	$string =~ s/è/&#232;/g;	# Small e, grave accent
	$string =~ s/é/&#233;/g;	# Small e, acute accent
	$string =~ s/ê/&#234;/g;	# Small e, circumflex accent
	$string =~ s/ë/&#235;/g;	# Small e, dieresis or umlaut mark
	$string =~ s/ì/&#236;/g;	# Small i, grave accent
	$string =~ s/í/&#237;/g;	# Small i, acute accent
	$string =~ s/î/&#238;/g;	# Small i, circumflex accent
	$string =~ s/ï/&#239;/g;	# Small i, dieresis or umlaut mark
	$string =~ s/ð/&#240;/g;	# Small eth, Icelandic
	$string =~ s/ñ/&#241;/g;	# Small n, tilde
	$string =~ s/ò/&#242;/g;	# Small o, grave accent
	$string =~ s/ó/&#243;/g;	# Small o, acute accent
	$string =~ s/ô/&#244;/g;	# Small o, circumflex accent
	$string =~ s/õ/&#245;/g;	# Small o, tilde
	$string =~ s/ö/&#246;/g;	# Small o, dieresis or umlaut mark
	$string =~ s/÷/&#247;/g;	# Division sign
	$string =~ s/ø/&#248;/g;	# Small o, slash
	$string =~ s/ù/&#249;/g;	# Small u, grave accent
	$string =~ s/ú/&#250;/g;	# Small u, acute accent
	$string =~ s/û/&#251;/g;	# Small u, circumflex accent
	$string =~ s/ü/&#252;/g;	# Small u, dieresis or umlaut mark
	$string =~ s/ý/&#253;/g;	# Small y, acute accent
	$string =~ s/þ/&#254;/g;	# Small thorn, Icelandic
	$string =~ s/ÿ/&#255;/g;	# Small y, dieresis or umlaut mark

	# These are a few special ones.
	$string =~ s/\t/&nbsp; &nbsp; &nbsp; &nbsp;/g;
	$string =~ s/  /&nbsp; /g;

	# Make sure no control characters were double-encoded
	$string =~ s/&lt;br \/&gt;/<br>/g;
	
	$string =~ s/#!br!#/<br \/>/g;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "string", value1 => $string,
	}, file => $THIS_FILE, line => __LINE__});
	return ($string);
}

# This asks the user which cluster they want to work with.
sub ask_which_cluster
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "ask_which_cluster" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	print $an->Web->template({file => "select-anvil.html", template => "open-table"});
	
	# Now see if we have any Anvil! systems configured.
	my $anvil_count = 0;
	foreach my $cluster (sort {$a cmp $b} keys %{$an->data->{clusters}})
	{
		$anvil_count++;
	}
	if (not $anvil_count)
	{
		print $an->Web->template({file => "select-anvil.html", template => "no-anvil-configured"});
	}
	else
	{
		foreach my $cluster (sort {$a cmp $b} keys %{$an->data->{clusters}})
		{
			next if not $cluster;
			my $say_url = "&nbsp;";
			
			# Create the 'Configure' link.
			my $image = $an->Web->template({file => "common.html", template => "image", replace => { 
					image_source	=>	$an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/icon_edit-anvil_16x16.png",
					alt_text	=>	"#!string!button_0044!#",
					id		=>	"configure_icon",
				}});
			my $say_configure = $an->Web->template({file => "common.html", template => "enabled-button-no-class-new-tab", replace => { 
					button_link	=>	"?config=true&anvil=$cluster",
					button_text	=>	$image,
					id		=>	"configure_$cluster",
				}});
			
			# If an info link has been specified, show it.
			if ($an->data->{clusters}{$cluster}{url})
			{
				my $image = $an->Web->template({file => "common.html", template => "image", replace => { 
					image_source	=>	$an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/anvil-url_16x16.png",
					alt_text	=>	"",
					id		=>	"url_icon",
				}});
				$say_url = $an->Web->template({file => "common.html", template => "enabled-button-no-class-new-tab", replace => { 
					button_link	=>	$an->data->{clusters}{$cluster}{url},
					button_text	=>	$image,
					id		=>	"url_$cluster",
				}});
			}
			print $an->Web->template({file => "select-anvil.html", template => "anvil-entry", replace => { 
				anvil		=>	$cluster,
				company		=>	$an->data->{clusters}{$cluster}{company},
				description	=>	$an->data->{clusters}{$cluster}{description},
				configure	=>	$say_configure,
				url		=>	$say_url,
			}});
		}
	}
	
	# See if the global options have been configured yet.
# 	my ($global_set) = AN::Common::check_global_settings($an);
# 	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
# 		name1 => "global_set", value1 => $global_set,
# 	}, file => $THIS_FILE, line => __LINE__});
# 	if (not $global_set)
# 	{
# 		# Looks like the user hasn't configured the global values yet.
# 		print $an->Web->template({file => "select-anvil.html", template => "global-not-configured"});
# 	}
	
	return (0);
}

# This toggles the dhcpd server and shorewall/iptables to turn the Install
# Target feature on and off.
sub control_install_target
{
	my ($an, $action) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "control_install_target" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "action", value1 => $action, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Track what was running and start back up things we turned off only.
	###       Check the 'start' and 'stop' calls for rc:4 (bad setuid)
	# If the user installed libvirtd for some reason, and if it is running,
	# it will block dhcpd from starting.
	my $ok           = 1;
	my $dhcpd_rc     = 0;
	my $libvirtd_rc  = 0;
	my $shorewall_rc = 0;
	my $iptables_rc  = 0;
	my $shell_call   = "";
	if ($action eq "start")
	{
		# Start == stop libvirtd -> cycle iptablte to shorewall -> start dhcpd
		$shell_call = "
if [ -e '".$an->data->{path}{initd_libvirtd}."' ];
then
    ".$an->data->{path}{control_libvirtd}." status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'libvirtd running, stopping it'
        ".$an->data->{path}{control_libvirtd}." stop
        ".$an->data->{path}{control_libvirtd}." status
        if [ \"\$?\" -eq \"3\" ];
        then 
            echo 'libvirtd stopped'
        else
            echo 'libvirtd failed to stop'
        fi;
    else
        echo 'libvirtd not running'
    fi;
else 
    echo 'libvirtd not installed'; 
fi
";
		# If we've got shorewall, stop iptables and start it.
		$shell_call .= "
if grep -q 'STARTUP_ENABLED=Yes' /etc/shorewall/shorewall.conf
then
    echo 'shorewall enabled, stopping iptables and starting shorewall'
    if [ -e '".$an->data->{path}{initd_iptables}."' ];
    then
        $an->data->{path}{control_iptables} status;
        if [ \"\$?\" -eq \"0\" ];
        then 
            echo 'iptables running, stopping it'
            ".$an->data->{path}{control_iptables}." stop
            ".$an->data->{path}{control_iptables}." status
            if [ \"\$?\" -eq \"3\" ];
            then 
                echo 'iptables stopped'
            else
                echo 'iptables failed to stop'
            fi;
        else
            echo 'iptables not running'
        fi;
    else 
        echo 'iptables not installed'; 
    fi

    ".$an->data->{path}{control_shorewall}." status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'shorewall running'
    else
        echo 'shorewall stopped, starting it'
        ".$an->data->{path}{control_shorewall}." restart
        ".$an->data->{path}{control_shorewall}." status
        # This is currently broken, status always returns 0...
        if [ \"\$?\" -eq \"0\" ];
        then 
            echo 'shorewall started'
        else
            echo 'shorewall failed to start'
        fi;
    fi;
else 
    echo 'shorewall not enabled';
fi

if [ -e '".$an->data->{path}{control_dhcpd}."' ];
then
    ".$an->data->{path}{control_dhcpd}." status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'dhcpd running'
    else
        echo 'dhcpd running, starting it'
        ".$an->data->{path}{control_dhcpd}." restart
        ".$an->data->{path}{control_dhcpd}." status
        if [ \"\$?\" -eq \"0\" ];
        then 
            echo 'dhcpd started'
        else
            echo 'dhcpd failed to start'
        fi;
    fi;
else 
    echo 'dhcpd not installed'; 
fi
";
	}
	else
	{
		# We don't start libvirtd, period. Stop shorewall and start iptables
		$shell_call .= "
if [ -e '".$an->data->{path}{initd_libvirtd}."' ];
then
    ".$an->data->{path}{control_libvirtd}." status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'libvirtd running, stopping it'
        ".$an->data->{path}{control_libvirtd}." stop
        ".$an->data->{path}{control_libvirtd}." status
        if [ \"\$?\" -eq \"3\" ];
        then 
            echo 'libvirtd stopped'
        else
            echo 'libvirtd failed to stop'
        fi;
    else
        echo 'libvirtd not running'
    fi;
else 
    echo 'libvirtd not installed'; 
fi
";
		# Cycle shorewall to iptables, stop dhcpd
		$shell_call .= "
if grep -q 'STARTUP_ENABLED=Yes' /etc/shorewall/shorewall.conf
then
    echo 'shorewall enabled, stopping it and starting iptables'
    ".$an->data->{path}{control_shorewall}." status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'shorewall running, stopping it'
        ".$an->data->{path}{control_shorewall}." stop
        ".$an->data->{path}{control_shorewall}." status
        if [ \"\$?\" -eq \"3\" ];
        then 
            echo 'shorewall stopped'
            echo 'Restarting iptables now'
            ".$an->data->{path}{control_iptables}." stop;
            ".$an->data->{path}{control_iptables}." start;
            if [ \"\$?\" -eq \"0\" ];
            then 
                echo 'iptables started'
            else
                echo 'iptables failed to start'
            fi;
        else
            echo 'shorewall failed to stop'
        fi;
    else
        echo 'shorewall not running'
    fi;
else 
    echo 'shorewall not enabled';
fi

if [ -e '".$an->data->{path}{control_dhcpd}."' ];
then
    ".$an->data->{path}{control_dhcpd}." status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'dhcpd running, stopping it'
        ".$an->data->{path}{control_dhcpd}." stop
        ".$an->data->{path}{control_dhcpd}." status
        if [ \"\$?\" -eq \"3\" ];
        then 
            echo 'dhcpd stopped'
        else
            echo 'dhcpd failed to stop'
        fi;
    else
        echo 'dhcpd not running'
    fi;
else 
    echo 'dhcpd not installed'; 
fi
";
	}
	$shell_call .= $an->data->{path}{control_dhcpd}." $action; echo rc:\$?";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		# libvirtd
		if ($line =~ /libvirtd not installed/)
		{
			$libvirtd_rc = 0;
		}
		if ($line =~ /libvirtd not running/)
		{
			$libvirtd_rc = 1;
		}
		if ($line =~ /libvirtd stopped/)
		{
			$libvirtd_rc = 2;
		}
		if ($line =~ /libvirtd failed to stop/)
		{
			$libvirtd_rc = 3;
		}
		
		# shorewall
		if ($line =~ /shorewall not enabled/)
		{
			$shorewall_rc = 0;
		}
		if ($line =~ /shorewall not running/)
		{
			$shorewall_rc = 1;
		}
		if ($line =~ /shorewall stopped/)
		{
			$shorewall_rc = 2;
		}
		if ($line =~ /shorewall failed to stop/)
		{
			$shorewall_rc = 3;
		}
		if ($line =~ /shorewall running/)
		{
			$shorewall_rc = 4;
		}
		if ($line =~ /shorewall started/)
		{
			$shorewall_rc = 5;
		}
		if ($line =~ /shorewall failed to start/)
		{
			$shorewall_rc = 6;
		}
		
		# iptables
		if ($line =~ /iptables not installed/)
		{
			$iptables_rc = 0;
		}
		if ($line =~ /iptables not running/)
		{
			$iptables_rc = 1;
		}
		if ($line =~ /iptables stopped/)
		{
			$iptables_rc = 2;
		}
		if ($line =~ /iptables failed to stop/)
		{
			$iptables_rc = 3;
		}
		if ($line =~ /iptables started/)
		{
			$iptables_rc = 4;
		}
		if ($line =~ /iptables running/)
		{
			$iptables_rc = 5;
		}
		
		# dhcpd
		if ($line =~ /dhcpd not installed/)
		{
			$dhcpd_rc = 0;
		}
		if ($line =~ /dhcpd not running/)
		{
			$dhcpd_rc = 1;
		}
		if ($line =~ /dhcpd stopped/)
		{
			$dhcpd_rc = 2;
		}
		if ($line =~ /dhcpd failed to stop/)
		{
			$dhcpd_rc = 3;
		}
		if ($line =~ /dhcpd started/)
		{
			$dhcpd_rc = 4;
		}
		if ($line =~ /dhcpd running/)
		{
			$dhcpd_rc = 5;
		}
		if ($line =~ /dhcpd failed to start/)
		{
			$dhcpd_rc = 6;
		}
	}
	close $file_handle;
	
	# dhcpd_rc:
	# 0 == not installed
	# 1 == not running
	# 2 == dhcpd stopped
	# 3 == failed to stop
	# 4 == dhcpd started
	# 5 == dhcpd running
	# 6 == dhcpd failed to start
	# 
	# libvirtd_rc:
	# 0 == not installed
	# 1 == installed but stopped
	# 2 == was running but stopped
	# 3 == running and failed to stop.
	# 
	# shorewall_rc:
	# 0 == not enabled
	# 1 == not running
	# 2 == stopped
	# 3 == running and failed to stop.
	# 4 == shorewall running
	# 5 == shorewall started
	# 6 == shorewall failed to start
	# 
	# iptables_rc:
	# 0 == not installed
	# 1 == not running
	# 2 == stopped
	# 3 == failed to stop.
	# 4 == iptables started
	# 5 == iptables running
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "dhcpd_ok",     value1 => $dhcpd_rc,
		name2 => "libvirtd_rc",  value2 => $libvirtd_rc,
		name3 => "shorewall_rc", value3 => $shorewall_rc,
		name4 => "iptables_rc",  value4 => $iptables_rc,
	}, file => $THIS_FILE, line => __LINE__});
	return($dhcpd_rc, $libvirtd_rc, $shorewall_rc, $iptables_rc);
}

# Show the "select Anvil!" menu and Striker config and control options.
sub show_anvil_selection_and_striker_options
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_anvil_selection_and_striker_options" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If I'm toggling the install target (dhcpd), process it first.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::install_target", value1 => $an->data->{cgi}{install_target},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{install_target})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::confirm", value1 => $an->data->{cgi}{confirm},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{cgi}{install_target} eq "start") && (not $an->data->{cgi}{confirm}))
		{
			# Warn the user about possible DHCPd conflicts and ask them to confirm.
			my $confirm_url = "/cgi-bin/configure?task=install_target&subtask=enable&confirm=true";
			print $an->Web->template({file => "select-anvil.html", template => "confirm-dhcpd-start", replace => { confirm_url => $confirm_url }});
		}
		elsif ($an->data->{cgi}{install_target} eq "start")
		{
			# Stop libvirtd, stop iptables, start shorewall, start dhcpd
			my ($dhcpd_rc, $libvirtd_rc, $shorewall_rc, $iptables_rc) = control_install_target($an, "start");
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "dhcpd_ok",     value1 => $dhcpd_rc,
				name2 => "libvirtd_rc",  value2 => $libvirtd_rc,
				name3 => "shorewall_rc", value3 => $shorewall_rc,
				name4 => "iptables_rc",  value4 => $iptables_rc,
			}, file => $THIS_FILE, line => __LINE__});
			
			# libvirtd_rc:
			# 0 == not installed
			# 1 == installed but stopped
			# 2 == was running but stopped
			# 3 == running and failed to stop.
			
			# If libvirtd was stopped (or failed to stop), warn the user.
# 			if ($libvirtd_rc eq "2")
# 			{
# 				# Warn the user that we turned off libvirtd.
# 				print $an->Web->template({file => "select-anvil.html", template => "control-dhcpd-results", replace => { 
# 					class	=>	"highlight_warning_bold",
# 					row	=>	"#!string!row_0044!#",
# 					message	=>	"#!string!message_0117!#",
# 				}});
# 			}
# 			elsif ($libvirtd_rc eq "3")
# 			{
# 				# Warn the user that we failed to turn off libvirtd.
# 				print $an->Web->template({file => "select-anvil.html", template => "control-dhcpd-results", replace => { 
# 					class	=>	"highlight_warning_bold",
# 					row	=>	"#!string!row_0044!#",
# 					message	=>	"#!string!message_0364!#",
# 				}});
# 			}
			
			# If shorewall is configured, tell the user that we toggled
# 			
# 			
# 			# DHCP message; Default message is 'not instaled'
# 			my $row     = "#!string!row_0133!#";
# 			my $message = "#!string!message_0410!#";
# 			my $class   = "highlight_warning_bold";
# 			if ($dhcpd_rc eq "4")
# 			{
# 				$row     = "#!string!row_0083!#";
# 				$message = "#!string!message_0411!#";
# 				$class   = "highlight_good_bold";
# 			}
# 			if ($dhcpd_rc eq "6")
# 			{
# 				$message = "#!string!message_0412!#";
# 			}
# 			print $an->Web->template({file => "select-anvil.html", template => "control-install-target-results", replace => { 
# 				class	=>	$class,
# 				row	=>	$row,
# 				message	=>	$message,
# 			}});
			
			# shorewall_rc:
			# 0 == not enabled
			# 1 == not running
			# 2 == stopped
			# 3 == running and failed to stop.
			# 4 == shorewall running
			# 5 == shorewall started
			# 6 == shorewall failed to start
			# 
			# iptables_rc:
			# 0 == not installed
			# 1 == not running
			# 2 == stopped
			# 3 == failed to stop.
			# 4 == iptables started
			# 5 == iptables running
			
			
			# dhcpd_rc:
			# 0 == not installed
			# 1 == not running
			# 2 == dhcpd stopped
			# 3 == failed to stop
			# 4 == dhcpd started
			# 5 == dhcpd running
			# 6 == dhcpd failed to start
			
			# DHCP message; Default message is 'not installed'
			my $row     = "#!string!row_0133!#";
			my $message = "#!string!message_0410!#";
			my $class   = "highlight_warning_bold";
			if ($dhcpd_rc eq "4")
			{
				$row     = "#!string!row_0083!#";
				$message = "#!string!message_0411!#";
				$class   = "highlight_good_bold";
			}
			if ($dhcpd_rc eq "6")
			{
				$message = "#!string!message_0412!#";
			}
			print $an->Web->template({file => "select-anvil.html", template => "control-install-target-results", replace => { 
				class	=>	$class,
				row	=>	$row,
				message	=>	$message,
			}});
		}
		elsif ($an->data->{cgi}{install_target} eq "stop")
		{
			# Disable it.
			my ($dhcpd_rc, $libvirtd_rc, $shorewall_rc, $iptables_rc) = control_install_target($an, "stop");
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "dhcpd_rc",     value1 => $dhcpd_rc,
				name2 => "libvirtd_rc",  value2 => $libvirtd_rc,
				name3 => "shorewall_rc", value3 => $shorewall_rc,
				name4 => "iptables_rc",  value4 => $iptables_rc,
			}, file => $THIS_FILE, line => __LINE__});
			# dhcpd_rc:
			# 0 == not installed
			# 1 == not running
			# 2 == dhcpd stopped
			# 3 == failed to stop
			# 4 == dhcpd started
			# 5 == dhcpd running
			# 6 == dhcpd failed to start
			# 
			# libvirtd_rc:
			# 0 == not installed
			# 1 == installed but stopped
			# 2 == was running but stopped
			# 3 == running and failed to stop.
			# 
			# shorewall_rc:
			# 0 == not enabled
			# 1 == not running
			# 2 == stopped
			# 3 == running and failed to stop.
			# 4 == shorewall running
			# 5 == shorewall started
			# 6 == shorewall failed to start
			# 
			# iptables_rc:
			# 0 == not installed
			# 1 == not running
			# 2 == stopped
			# 3 == failed to stop.
			# 4 == iptables started
			# 5 == iptables running
			
			my $row     = "#!string!row_0133!#";
			my $message = "#!string!message_0413!#";
			my $class   = "highlight_warning_bold";
			if ($dhcpd_rc eq "0")
			{
				$row     = "#!string!row_0024!#";
				$message = "#!string!message_0435!#";
			}
			if ($dhcpd_rc eq "2")
			{
				# Success!
				$row     = "#!string!row_0083!#";
				$message = "#!string!message_0414!#";
				$class   = "highlight_good_bold";
			}
			print $an->Web->template({file => "select-anvil.html", template => "control-install-target-results", replace => { 
				class	=>	$class,
				row	=>	$row,
				message	=>	$message,
			}});
		}
	}
	
	# Show the list of configured Anvil! systems.
	ask_which_cluster($an);
	
	# See if this machine is configured as a boot target and, if so, whether dhcpd is running or not (so
	# we can offer a toggle).
	my ($dhcpd_state) = get_dhcpd_state($an);
	# 0 == Running
	# 1 == Not running
	# 2 == Not a boot target
	# 3 == In an unknown state.
	# 4 == No access to /etc/dhcpd
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "dhcpd_state", value1 => $dhcpd_state,
	}, file => $THIS_FILE, line => __LINE__});
	
	# No decide what to show for the "Boot Target" button.
	my $install_target_template = "disabled-install-target-button";
	my $install_target_button   = "#!string!button_0056!#";
	my $install_target_message  = "#!string!message_0405!#";
	my $install_target_url      = "";
	if ($dhcpd_state eq "0")
	{
		# dhcpd is running, offer the button to disable it.
		$install_target_template = "enabled-install-target-button";
		$install_target_button   = "#!string!button_0058!#";
		$install_target_message  = "#!string!message_0406!#";
		$install_target_url      = "/cgi-bin/configure?task=install_target&subtask=disable";
	}
	elsif ($dhcpd_state eq "1")
	{
		# dhcpd is stopped, offer the button to enable it.
		$install_target_template = "enabled-install-target-button";
		$install_target_button   = "#!string!button_0057!#";
		$install_target_message  = "#!string!message_0407!#";
		$install_target_url      = "/cgi-bin/configure?task=install_target&subtask=enable";
	}
	elsif ($dhcpd_state eq "3")
	{
		# Unknown state, tell them to get help.
		$install_target_template = "disabled-install-target-button";
		$install_target_button   = "#!string!button_0056!#";
		$install_target_message  = "#!string!message_0408!#";
		$install_target_url      = "";
	}
	elsif ($dhcpd_state eq "4")
	{
		# DHCP directory is probably not readable
		$install_target_template = "disabled-install-target-button";
		$install_target_button   = "#!string!button_0056!#";
		$install_target_message  = "#!string!message_0416!#";
		$install_target_url      = "";
	}
	
	# Now show the other configuration options
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "install_target_template", value1 => $install_target_template,
		name2 => "install_target_button",   value2 => $install_target_button,
		name3 => "install_target_message",  value3 => $install_target_message,
		name4 => "install_target_url",      value4 => $install_target_url,
	}, file => $THIS_FILE, line => __LINE__});
	my $install_manifest_tr = $an->Web->template({file => "select-anvil.html", template => "$install_target_template", replace => { 
			install_target_button	=>	$install_target_button,
			install_target_message	=>	$install_target_message,
			install_target_url	=>	$install_target_url,
		}});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "install_manifest_tr", value1 => $install_manifest_tr,
	}, file => $THIS_FILE, line => __LINE__});
	print $an->Web->template({file => "select-anvil.html", template => "close-table", replace => { install_manifest_tr => $install_manifest_tr }});
	
	return(0);
}

# This checks to see if dhcpd is configured to be an install target target and,
# if so, see if dhcpd is running or not.
sub get_dhcpd_state
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_dhcpd_state" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# First, read the dhcpd.conf file, if it exists, and look for the
	# 'next-server' option.
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
		### NOTE: Don't use the setuid wrapper as 'root' isn't needed
		###       for a status check anyway.
		# See if dhcpd is running.
		my $shell_call = "/etc/init.d/dhcpd status; echo rc:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
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

# I need to convert the global configuration of the clusters to the format I use here.
sub convert_cluster_config
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "convert_cluster_config" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{cluster}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cluster", value1 => $id,
		}, file => $THIS_FILE, line => __LINE__});
		my $name = $an->data->{cluster}{$id}{name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "name",                  value1 => $name,
			name2 => "cluster::${id}::nodes", value2 => $an->data->{cluster}{$id}{nodes},
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{clusters}{$name}{nodes}       = [split/,/, $an->data->{cluster}{$id}{nodes}];
		$an->data->{clusters}{$name}{company}     = $an->data->{cluster}{$id}{company};
		$an->data->{clusters}{$name}{description} = $an->data->{cluster}{$id}{description};
		$an->data->{clusters}{$name}{url}         = $an->data->{cluster}{$id}{url};
		$an->data->{clusters}{$name}{ricci_pw}    = $an->data->{cluster}{$id}{ricci_pw};
		$an->data->{clusters}{$name}{root_pw}     = $an->data->{cluster}{$id}{root_pw} ? $an->data->{cluster}{$id}{root_pw} : $an->data->{cluster}{$id}{ricci_pw};
		$an->data->{clusters}{$name}{id}          = $id;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
			name1 => "ID",          value1 => $id,
			name2 => "name",        value2 => $name,
			name3 => "company",     value3 => $an->data->{clusters}{$name}{company},
			name4 => "description", value4 => $an->data->{clusters}{$name}{description},
			name5 => "ricci_pw",    value5 => $an->data->{clusters}{$name}{ricci_pw},
			name6 => "root_pw",     value6 => $an->data->{cluster}{$id}{root_pw},
		}, file => $THIS_FILE, line => __LINE__});
		
		for (my $i = 0; $i< @{$an->data->{clusters}{$name}{nodes}}; $i++)
		{
			@{$an->data->{clusters}{$name}{nodes}}[$i] =~ s/^\s+//;
			@{$an->data->{clusters}{$name}{nodes}}[$i] =~ s/\s+$//;
			my $node = @{$an->data->{clusters}{$name}{nodes}}[$i];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "$i - node", value1 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			if ($node =~ /^(.*?):(\d+)$/)
			{
				   $node = $1;
				my $port = $2;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "$i - node", value1 => $node,
					name2 => "port",      value2 => $port,
				}, file => $THIS_FILE, line => __LINE__});
				@{$an->data->{clusters}{$name}{nodes}}[$i] = $node;
				$an->data->{node}{$node}{port}             = $port;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "$i - clusters::${name}::nodes[$i]", value1 => @{$an->data->{clusters}{$name}{nodes}}[$i],
					name2 => "port",                              value2 => $an->data->{node}{$name}{port},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->data->{node}{$node}{port} = $an->data->{hosts}{$node}{port} ? $an->data->{hosts}{$node}{port} : 22;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "$i - node::${node}::port", value1 => $an->data->{node}{$node}{port},
					name2 => "hosts::${node}::port",     value2 => $an->data->{hosts}{$node}{port},
				}, file => $THIS_FILE, line => __LINE__});
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "$i - node", value1 => @{$an->data->{clusters}{$name}{nodes}}[$i],
				name2 => "port",      value2 => $an->data->{node}{$node}{port},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return (0);
}

sub header
{
	my ($an, $caller) = @_;
	$caller = "striker" if not $caller;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "header" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "caller", value1 => $caller, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Header buttons.
	my $say_back        = "&nbsp;";
	my $say_refresh     = "&nbsp;";
	
	my $back_image = $an->Web->template({file => "common.html", template => "image", replace => { 
		image_source	=>	$an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/back.png",
		alt_text	=>	"#!string!button_0001!#",
		id		=>	"back_icon",
	}});

	my $refresh_image = $an->Web->template({file => "common.html", template => "image", replace => { 
		image_source	=>	$an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/refresh.png",
		alt_text	=>	"#!string!button_0002!#",
		id		=>	"refresh_icon",
	}});
	
	if ($an->data->{cgi}{config})
	{
		$an->data->{sys}{cgi_string} =~ s/cluster=(.*?)&//;
		$an->data->{sys}{cgi_string} =~ s/cluster=(.*)$//;
		if ($an->data->{cgi}{save})
		{
			$say_refresh = "";
			$say_back    = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?config=true",
					button_text	=>	"$back_image",
					id		=>	"back",
				}});
			if (($an->data->{cgi}{anvil} eq "new") && ($an->data->{cgi}{cluster__new__name}))
			{
				$an->data->{cgi}{anvil} = $an->data->{cgi}{cluster__new__name};
			}
			if (($an->data->{cgi}{anvil}) && ($an->data->{cgi}{anvil} ne "new"))
			{
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?anvil=".$an->data->{cgi}{anvil}."&config=true",
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
		}
		elsif ($an->data->{cgi}{task})
		{
			$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?config=true",
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}});
			$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"/cgi-bin/configure",
					button_text	=>	"$back_image",
					id		=>	"back",
				}});
			
			if ($an->data->{cgi}{task} eq "load_config")
			{
				$say_refresh = "";
				my $back = "/cgi-bin/configure";
				if ($an->data->{cgi}{anvil})
				{
					$back = "?anvil=".$an->data->{cgi}{anvil}."&config=true";
				}
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	$back,
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
			elsif ($an->data->{cgi}{task} eq "push")
			{
				$say_refresh = "";
			}
			elsif ($an->data->{cgi}{task} eq "archive")
			{
				$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?config=true&task=archive",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}});
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"/cgi-bin/configure",
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
			elsif ($an->data->{cgi}{task} eq "create-install-manifest")
			{
				my $link =  $an->data->{sys}{cgi_string};
				   $link =~ s/generate=true//;
				   $link =~ s/anvil_password=.*?&//;
				   $link =~ s/anvil_password=.*?$//;	# Catch the password if it's the last variable in the URL
				   $link =~ s/&&+/&/g;
				if ($an->data->{cgi}{confirm})
				{
					if ($an->data->{cgi}{run})
					{
						my $back_url =  $an->data->{sys}{cgi_string};
						   $back_url =~ s/confirm=.*?&//; $back_url =~ s/confirm=.*$//;
						   
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "sys::cgi_string", value1 => $an->data->{sys}{cgi_string},
						}, file => $THIS_FILE, line => __LINE__});
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "back_url", value1 => $back_url,
						}, file => $THIS_FILE, line => __LINE__});
						$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
								button_link	=>	"$back_url",
								button_text	=>	"$back_image",
								id		=>	"back",
							}});
					}
					elsif ($an->data->{cgi}{'delete'})
					{
						my $back_url =  $an->data->{sys}{cgi_string};
						   $back_url =~ s/confirm=.*?&//; $back_url =~ s/confirm=.*$//;
						   $back_url =~ s/delete=.*?&//;  $back_url =~ s/delete=.*$//;
						   
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "sys::cgi_string", value1 => $an->data->{sys}{cgi_string},
						}, file => $THIS_FILE, line => __LINE__});
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "back_url", value1 => $back_url,
						}, file => $THIS_FILE, line => __LINE__});
						$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
								button_link	=>	"$back_url",
								button_text	=>	"$back_image",
								id		=>	"back",
							}});
					}
					else
					{
						$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
								button_link	=>	"$link",
								button_text	=>	"$back_image",
								id		=>	"back",
							}});
					}
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"?config=true&task=create-install-manifest",
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
				elsif ($an->data->{cgi}{generate})
				{
					$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"$link",
							button_text	=>	"$back_image",
							id		=>	"back",
						}});
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	$an->data->{sys}{cgi_string},
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
				elsif ($an->data->{cgi}{run})
				{
					$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"?config=true&task=create-install-manifest",
							button_text	=>	"$back_image",
							id		=>	"back",
						}});
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	$an->data->{sys}{cgi_string},
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
				else
				{
					$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"/cgi-bin/configure",
							button_text	=>	"$back_image",
							id		=>	"back",
						}});
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"?config=true&task=create-install-manifest",
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
			}
			elsif ($an->data->{cgi}{anvil})
			{
				$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?anvil=".$an->data->{cgi}{anvil}."&config=true",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}});
			}
		}
		else
		{
			$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	$an->data->{sys}{cgi_string},
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}});
			$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"/cgi-bin/configure",
					button_text	=>	"$back_image",
					id		=>	"back",
				}});
			if ($an->data->{cgi}{anvil})
			{
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?config=true",
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
		}
	}
	elsif ($an->data->{cgi}{task})
	{
		$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"?cluster=".$an->data->{cgi}{cluster},
				button_text	=>	"$back_image",
				id		=>	"back",
			}});
		if ($an->data->{cgi}{task} eq "manage_vm")
		{
			if ($an->data->{cgi}{change})
			{
				$say_refresh = "";
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&vm=".$an->data->{cgi}{vm}."&task=manage_vm",
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
			else
			{
				$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&vm=".$an->data->{cgi}{vm}."&task=manage_vm",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}});
			}
		}
		elsif ($an->data->{cgi}{task} eq "display_health")
		{
			$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health",
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}});
		}
	}
	elsif ($an->data->{cgi}{logo})
	{
		$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"/cgi-bin/configure",
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}});
		$say_back = "";
	}
	elsif ($caller eq "mediaLibrary")
	{
		$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"/cgi-bin/striker?cluster=".$an->data->{cgi}{cluster},
				button_text	=>	"$back_image",
				id		=>	"back",
			}});
		$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	$an->data->{sys}{cgi_string},
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}});
	}
	else
	{
		$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	$an->data->{sys}{cgi_string},
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}});
	}
	
	foreach my $key (sort {$a cmp $b} keys %ENV)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "key",        value1 => $key, 
			name2 => "ENV{\$key}", value2 => $ENV{$key},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# We only want the auto-refresh function to activate in certain pages.
	my $use_refresh = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::reload_page_timer", value1 => $an->data->{sys}{reload_page_timer},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{reload_page_timer})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::cgi_string",  value1 => $an->data->{sys}{cgi_string},
			name2 => "ENV{REQUEST_URI}", value2 => $ENV{REQUEST_URI},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{sys}{cgi_string} eq "?cluster=".$an->data->{cgi}{cluster}) && 
		    ($ENV{REQUEST_URI} !~ /mediaLibrary/i))
		{
			# Use refresh
			$an->Log->entry({log_level => 3, message_key => "log_0014", file => $THIS_FILE, line => __LINE__});
			$use_refresh = 1;
		}
		else
		{
			# Do not use refresh
			$an->Log->entry({log_level => 3, message_key => "log_0015", file => $THIS_FILE, line => __LINE__});
		}
		if ($an->data->{sys}{cgi_string} =~ /\?cluster=.*?&task=display_health&node=.*?&node_cluster_name=(.*)$/)
		{
			my $final = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "final", value1 => $final,
			}, file => $THIS_FILE, line => __LINE__});
			if ($final !~ /&/)
			{
				# Use refresh
				$an->Log->entry({log_level => 3, message_key => "log_0014", file => $THIS_FILE, line => __LINE__});
				$use_refresh = 1;
			}
			else
			{
				# Do not use refresh
				$an->Log->entry({log_level => 3, message_key => "log_0015", file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Now print the actual header.
	if ($use_refresh)
	{
		# Add the auto-reload function if requested by the user.
		print $an->Web->template({file => "common.html", template => "auto-refresh-header", replace => { 
			back		=>	$say_back,
			refresh		=>	$say_refresh,
		}});
	}
	else
	{
		print $an->Web->template({file => "common.html", template => "header", replace => { 
			back		=>	$say_back,
			refresh		=>	$say_refresh,
		}});
	}
	
	
	return (0);
}

# This builds an HTML select field.
sub build_select
{
	my ($an, $name, $sort, $blank, $width, $selected, $options) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "build_select" }, message_key => "an_variables_0006", message_variables => { 
		name1 => "name",     value1 => $name, 
		name2 => "sort",     value2 => $sort, 
		name3 => "blank",    value3 => $blank, 
		name4 => "width",    value4 => $width, 
		name5 => "selected", value5 => $selected, 
		name6 => "options",  value6 => $options, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $select = "<select name=\"$name\">\n";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select", value1 => $select,
	}, file => $THIS_FILE, line => __LINE__});
	if ($width)
	{
		$select = "<select name=\"$name\" id=\"$name\" style=\"width: ${width}px;\">\n";
	}
	
	# Insert a blank line.
	if ($blank)
	{
		$select .= "<option value=\"\"></option>\n";
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
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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

### TODO: Replace this with '$an->Get->shared_files(). See MediaLibrary.pm->read_shared() for the new way to 
###       use this.
# This looks for a node we have access to and returns the first one available.
sub read_files_on_shared
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_files_on_shared" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});

	my $connected = "";
	my $cluster   = $an->data->{cgi}{cluster};
	delete $an->data->{files} if exists $an->data->{files};
	foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$cluster}{nodes}})
	{
		next if $connected;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "trying to connect to node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my $fail       = 0;
		my $raw        = "";
		my $shell_call = "df -P && ls -l /shared/files/";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$an->data->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$raw .= "$line\n";
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			next if $fail;
			
			### TODO: Move these checks into a function. They duplicate gather_node_details().
			# This catches connectivity problems.
			if ($line =~ /No route to host/i)
			{
				my ($local_access, $target_ip)      = on_same_network($an, $node, $node);
				$an->data->{node}{$node}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0033!#</span>";
				if ($local_access)
				{
					# Local access, but not answering.
					$an->data->{node}{$node}{info}{note} = $an->String->get({key => "message_0019", variables => { node => $node }});
				}
				else
				{
					# Not on the same subnet.
					$an->data->{node}{$node}{info}{note} = $an->String->get({key => "message_0020", variables => { node => $node }});
				}
				$fail = 1;
				next;
			}
			elsif ($line =~ /host key verification failed/i)
			{
				$an->data->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0034!#</span>";
				$an->data->{node}{$node}{info}{note}    = $an->String->get({key => "message_0021", variables => { node => $node }});
				$fail = 1;
				next;
			}
			elsif ($line =~ /could not resolve hostname/i)
			{
				$an->data->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0035!#</span>";
				$an->data->{node}{$node}{info}{note}    = $an->String->get({key => "message_0022", variables => { node => $node }});
				$fail = 1;
				next;
			}
			elsif ($line =~ /permission denied/i)
			{
				$an->data->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0036!#</span>";
				$an->data->{node}{$node}{info}{note}    = $an->String->get({key => "message_0023", variables => { node => $node }});
				$fail = 1;
				next;
			}
			elsif ($line =~ /connection refused/i)
			{
				$an->data->{node}{$node}{info}{'state'} =  "<span class=\"highlight_bad\">#!string!row_0037!#</span>";
				$an->data->{node}{$node}{info}{note}    = $an->String->get({key => "message_0024", variables => { node => $node }});
				$fail = 1;
				next;
			}
			elsif ($line =~ /Connection timed out/i)
			{
				$an->data->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0038!#</span>";
				$an->data->{node}{$node}{info}{note}    = $an->String->get({key => "message_0025", variables => { node => $node }});
				$fail = 1;
				next;
			}
			elsif ($line =~ /Network is unreachable/i)
			{
				$an->data->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0039!#</span>";
				$an->data->{node}{$node}{info}{note}    = $an->String->get({key => "message_0026", variables => { node => $node }});
				$fail = 1;
				next;
			}
			elsif ($line =~ /\@\@\@\@/)
			{
				# When the host-key fails to match, a box made
				# of '@@@@' is displayed, and is the entire 
				# first line.
				$an->data->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0033!#</span>";
				$an->data->{node}{$node}{info}{note}    = $an->String->get({key => "message_0027", variables => { node => $node }});
				$fail = 1;
				next;
			}
			
			# If I made it this far, I've got a connection.
			$connected = $node;
			if ($line =~ /\s(\d+)-blocks\s/)
			{
				$an->data->{partition}{shared}{block_size} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "block_size", value1 => $an->data->{partition}{shared}{block_size},
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			if ($line =~ /^\/.*?\s+(\d+)\s+(\d+)\s+(\d+)\s(\d+)%\s+\/shared/)
			{
				$an->data->{partition}{shared}{total_space}  = $1;
				$an->data->{partition}{shared}{used_space}   = $2;
				$an->data->{partition}{shared}{free_space}   = $3;
				$an->data->{partition}{shared}{used_percent} = $4;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "total_space",  value1 => $an->data->{partition}{shared}{total_space},
					name2 => "used_space",   value2 => $an->data->{partition}{shared}{used_space},
					name3 => "used_percent", value3 => $an->data->{partition}{shared}{used_percent},
					name4 => "free_space",   value4 => $an->data->{partition}{shared}{free_space},
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
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
				$an->data->{files}{shared}{$file}{type}   = $type;
				$an->data->{files}{shared}{$file}{mode}   = $mode;
				$an->data->{files}{shared}{$file}{user}   = $user;
				$an->data->{files}{shared}{$file}{group}  = $group;
				$an->data->{files}{shared}{$file}{size}   = $size;
				$an->data->{files}{shared}{$file}{month}  = $month;
				$an->data->{files}{shared}{$file}{day}    = $day;
				$an->data->{files}{shared}{$file}{'time'} = $time; # might be a year, look for '\d+:\d+'.
				$an->data->{files}{shared}{$file}{target} = $target;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0010", message_variables => {
					name1  => "file",     value1  => $file,
					name2  => "type",     value2  => $an->data->{files}{shared}{$file}{type},
					name3  => "mode",     value3  => $an->data->{files}{shared}{$file}{mode},
					name4  => "user",     value4  => $an->data->{files}{shared}{$file}{user},
					name5  => "group",    value5  => $an->data->{files}{shared}{$file}{group},
					name6  => "size",     value6  => $an->data->{files}{shared}{$file}{size},
					name7  => "month",    value7  => $an->data->{files}{shared}{$file}{month}, 
					name8  => "day",      value8  => $an->data->{files}{shared}{$file}{day},
					name9  => "time",     value9  => $an->data->{files}{shared}{$file}{'time'},
					name10 => "target",   value10 => $an->data->{files}{shared}{$file}{target},
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
		}
	}
	
	if (not $connected)
	{
		# Open the "not connected" table
		my $title = $an->String->get({key => "title_0116", variables => { anvil => $cluster }});
		print $an->Web->template({file => "main-page.html", template => "connection-error-table-header", replace => { title => $title }});
		
		foreach my $node (sort {$a cmp $b} keys %{$an->data->{node}})
		{
			# Show each node's state.
			my $state = $an->data->{node}{$node}{info}{'state'};
			my $note  = $an->data->{node}{$node}{info}{note};
			print $an->Web->template({file => "main-page.html", template => "connection-error-node-entry", replace => { 
				node	=>	$node,
				'state'	=>	$state,
				note	=>	$node,
			}});
		}
		print $an->Web->template({file => "main-page.html", template => "connection-error-try-again", replace => { cgi_string => $an->data->{sys}{cgi_string} }});
	}
	#print $an->Web->template({file => "main-page.html", template => "close-table"});
	
	return ($connected);
}

# This sets all of the daemons to a given state.
sub set_daemons
{
	my ($an, $node, $state, $class) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "set_daemons" }, message_key => "an_variables_0003", message_variables => { 
		name1 => "node",  value1 => $node, 
		name2 => "state", value2 => $state, 
		name3 => "class", value3 => $class, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my @daemons = ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd");
	foreach my $daemon (@daemons)
	{
		$an->data->{node}{$node}{daemon}{$daemon}{status}    = "<span class=\"$class\">$state</span>";
		$an->data->{node}{$node}{daemon}{$daemon}{exit_code} = "";
	}
	return(0);
}

# This checks to see if the node's power is on, when possible.
sub check_if_on
{
	my ($an, $node) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_if_on" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the peer is on, use it to check the power.
	my $peer                       = "";
	   $an->data->{node}{$node}{is_on} = 9;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::up_nodes", value1 => $an->data->{sys}{up_nodes},
	}, file => $THIS_FILE, line => __LINE__});
	### TODO: This fails when node 1 is down because it has not yet looked for node 2 to see if it is on 
	###       or not. Check manually.
	if ($an->data->{sys}{up_nodes} == 1)
	{
		# It has to be the peer of this node.
		$peer = @{$an->data->{up_nodes}}[0];
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node,
		name2 => "peer", value2 => $peer,
	}, file => $THIS_FILE, line => __LINE__});
	if ($peer)
	{
		# Check the power state using the peer node.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node}::info::power_check_command", value1 => $an->data->{node}{$node}{info}{power_check_command},
		}, file => $THIS_FILE, line => __LINE__});
		if (not $an->data->{node}{$node}{info}{power_check_command})
		{
			my $error = $an->String->get({key => "message_0047", variables => { 
					node	=>	$node,
					peer	=>	$peer,
				}});
			error($an, $error);
		}
		my $shell_call = $an->data->{node}{$node}{info}{power_check_command}." -o status";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "peer",       value2 => $peer,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$peer,
			port		=>	$an->data->{node}{$peer}{port}, 
			password	=>	$an->data->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ / On$/i)
			{
				$an->data->{node}{$node}{is_on} = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node",  value1 => $node,
					name2 => "is on", value2 => $an->data->{node}{$node}{is_on},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ / Off$/i)
			{
				$an->data->{node}{$node}{is_on} = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node",  value1 => $node,
					name2 => "is on", value2 => $an->data->{node}{$node}{is_on},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		# Read the cache and check the power directly, if possible.
		read_node_cache($an, $node);
		$an->data->{node}{$node}{info}{power_check_command} = "" if not defined $an->data->{node}{$node}{info}{power_check_command};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node",                value1 => $node,
			name2 => "power check command", value2 => $an->data->{node}{$node}{info}{power_check_command},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node}{info}{power_check_command})
		{
			# Get the address from the command and see if it's in
			# one of my subnet.
			my ($target_host)              = ($an->data->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
			my ($local_access, $target_ip) = on_same_network($an, $target_host, $node);
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node",         value1 => $node,
				name2 => "local_access", value2 => $local_access,
			}, file => $THIS_FILE, line => __LINE__});
			if ($local_access)
			{
				# I can reach it directly
				my $shell_call = $an->data->{node}{$node}{info}{power_check_command}." -o status";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Calling", value1 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
				while(<$file_handle>)
				{
					chomp;
					my $line = $_;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "node", value1 => $node,
						name2 => "line", value2 => $line,
					}, file => $THIS_FILE, line => __LINE__});
					if ($line =~ / On$/i)
					{
						$an->data->{node}{$node}{is_on} = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "node",  value1 => $node,
							name2 => "is on", value2 => $an->data->{node}{$node}{is_on},
						}, file => $THIS_FILE, line => __LINE__});
					}
					if ($line =~ / Off$/i)
					{
						$an->data->{node}{$node}{is_on} = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "node",  value1 => $node,
							name2 => "is on", value2 => $an->data->{node}{$node}{is_on},
						}, file => $THIS_FILE, line => __LINE__});
					}
					if ($line =~ / Unknown$/i)
					{
						# Failed to get info from IPMI.
						$an->data->{node}{$node}{is_on} = 2;
						$an->Log->entry({log_level => 2, message_key => "log_0025", message_variables => {
							node  => $node, 
							is_in => $an->data->{node}{$node}{is_on}, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				close $file_handle;
			}
			else
			{
				# I can't reach it from here.
				$an->Log->entry({log_level => 3, message_key => "log_0026", message_variables => {
					target_host => $target_host, 
					node        => $node, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->data->{node}{$node}{is_on} = 3;
			}
		}
		else
		{
			# No power-check command
			$an->data->{node}{$node}{is_on} = 4;
			$an->Log->entry({log_level => 3, message_key => "log_0027", message_variables => {
				node  => $node, 
				is_on => $an->data->{node}{$node}{is_on}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node",  value1 => $node,
		name2 => "is on", value2 => $an->data->{node}{$node}{is_on},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{$node}{is_on} == 0)
	{
		# I need to preset the services as stopped because the little hack I have below doesn't echo 
		# when a service isn't running.
		$an->data->{node}{$node}{enable_poweron} = 1;
		$an->Log->entry({log_level => 2, message_key => "log_0028", file => $THIS_FILE, line => __LINE__});
		my $say_offline = $an->String->get({key => "state_0004"});
		set_daemons($an, $node, $say_offline, "highlight_unavailable");
	}
	
	return(0);
}

# This takes a host name (or IP) and sees if it's reachable from the machine running this program.
sub on_same_network
{
	my ($an, $target_host, $node) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "on_same_network" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "target_host", value1 => $target_host, 
		name2 => "node",        value2 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $local_access = 0;
	my $target_ip;
	
	my $shell_call = $an->data->{path}{gethostip}." -d $target_host";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "Calling", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /^(\d+\.\d+\.\d+\.\d+)$/)
		{
			$target_ip = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "target_ip", value1 => $target_ip,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /Unknown host/i)
		{
			# Failed to resolve directly, see if the target host
			# was read from the cache file.
			read_node_cache($an, $node);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node}::hosts::${target_host}::ip", value1 => $an->data->{node}{$node}{hosts}{$target_host}{ip},
			}, file => $THIS_FILE, line => __LINE__});
			if ((defined $an->data->{node}{$node}{hosts}{$target_host}{ip}) && ($an->data->{node}{$node}{hosts}{$target_host}{ip} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/))
			{
				$target_ip = $an->data->{node}{$node}{hosts}{$target_host}{ip};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "target_ip",                                value1 => $target_ip,
					name2 => "node::${node}::hosts::${target_host}::ip", value2 => $an->data->{node}{$node}{hosts}{$target_host}{ip},
				}, file => $THIS_FILE, line => __LINE__});
				
				# Convert the power check command's address to
				# use the raw IP.
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::info::power_check_command", value1 => $an->data->{node}{$node}{info}{power_check_command},
				}, file => $THIS_FILE, line => __LINE__});
				$an->data->{node}{$node}{info}{power_check_command} =~ s/-a (.*?) /-a $target_ip /;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::info::power_check_command", value1 => $an->data->{node}{$node}{info}{power_check_command},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				my $error = $an->String->get({key => "message_0048", variables => { target_host => $target_host }});
				error($an, $error);
			}
		}
		elsif ($line =~ /Usage: gethostip/i)
		{
			#No hostname parsed out.
			my $error = $an->String->get({key => "message_0049"});
			error($an, $error);
		}
	}
	close $file_handle;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "target_ip", value1 => $target_ip,
	}, file => $THIS_FILE, line => __LINE__});
	if ($target_ip)
	{
		# Find out my own IP(s) and subnet(s).
		my $in_dev     = "";
		my $this_ip    = "";
		my $this_nm    = "";
		my $shell_call = $an->data->{path}{ifconfig};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "Calling", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			if ($line =~ /^(.*?)\s+Link encap/)
			{
				$in_dev = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "in_dev", value1 => $in_dev,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			elsif ($line =~ /^(.*?): flags/)
			{
				$in_dev = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "in_dev", value1 => $in_dev,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			if (not $line)
			{
				# See if this network gives me access 
				# to the power check device.
				my $target_ip_range = $target_ip;
				my $this_ip_range   = $this_ip;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "target_ip_range", value1 => $target_ip_range,
					name2 => "this_ip",         value2 => $this_ip,
				}, file => $THIS_FILE, line => __LINE__});
				if ($this_nm eq "255.255.255.0")
				{
					# Match the first three octals.
					$target_ip_range =~ s/.\d+$//;
					$this_ip_range   =~ s/.\d+$//;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "target_ip_range", value1 => $target_ip_range,
						name2 => "this_ip_range",   value2 => $this_ip_range,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($this_nm eq "255.255.0.0")
				{
					# Match the first three octals.
					$target_ip_range =~ s/.\d+.\d+$//;
					$this_ip_range   =~ s/.\d+.\d+$//;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "target_ip_range", value1 => $target_ip_range,
						name2 => "this_ip_range",   value2 => $this_ip_range,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($this_nm eq "255.0.0.0")
				{
					# Match the first three octals.
					$target_ip_range =~ s/.\d+.\d+.\d+$//;
					$this_ip_range   =~ s/.\d+.\d+.\d+$//;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "target_ip_range", value1 => $target_ip_range,
						name2 => "this_ip_range",   value2 => $this_ip_range,
					}, file => $THIS_FILE, line => __LINE__});
				}
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "target_ip_range", value1 => $target_ip_range,
					name2 => "this_ip_range",   value2 => $this_ip_range,
				}, file => $THIS_FILE, line => __LINE__});
				if ($this_ip_range eq $target_ip_range)
				{
					# Match! I can reach it directly.
					$local_access = 1;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "local_access", value1 => $local_access,
					}, file => $THIS_FILE, line => __LINE__});
					last;
				}
				
				$in_dev = "";
				$this_ip = "";
				$this_nm = "";
				next;
			}
			
			if ($in_dev)
			{
				next if $line !~ /inet /;
				if ($line =~ /inet addr:(\d+\.\d+\.\d+\.\d+) /)
				{
					$this_ip = $1;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "this_ip", value1 => $this_ip,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ /inet (\d+\.\d+\.\d+\.\d+) /)
				{
					$this_ip = $1;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "this_ip", value1 => $this_ip,
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				if ($line =~ /Mask:(\d+\.\d+\.\d+\.\d+)/i)
				{
					$this_nm = $1;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "this_nm", value1 => $this_nm,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ /netmask (\d+\.\d+\.\d+\.\d+) /)
				{
					$this_nm = $1;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "this_nm", value1 => $this_nm,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		close $file_handle;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "local_access", value1 => $local_access,
	}, file => $THIS_FILE, line => __LINE__});
	return($local_access, $target_ip);
}

# This records this scan's data to the cache file.
sub write_node_cache
{
	my ($an, $node) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "write_node_cache" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# It's a program error to try and write the cache file when the node
	# is down.
	my @lines;
	my $cluster    = $an->data->{cgi}{cluster};
	my $cache_file = $an->data->{path}{'striker_cache'}."/cache_".$cluster."_".$node.".striker";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node}::info::host_name",           value1 => $an->data->{node}{$node}{info}{host_name},
		name2 => "node::${node}::info::power_check_command", value2 => $an->data->{node}{$node}{info}{power_check_command},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node}{info}{host_name}) && ($an->data->{node}{$node}{info}{power_check_command}))
	{
		# Write the command to disk so that I can check the power state
		# in the future when both nodes are offline.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node",                value1 => $node,
			name2 => "power check command", value2 => $an->data->{node}{$node}{info}{power_check_command},
		}, file => $THIS_FILE, line => __LINE__});
		push @lines, "host_name = $an->data->{node}{$node}{info}{host_name}\n";
		push @lines, "power_check_command = $an->data->{node}{$node}{info}{power_check_command}\n";
		push @lines, "fence_methods = $an->data->{node}{$node}{info}{fence_methods}\n";
	}
	
	my $print_header = 0;
	foreach my $this_host (sort {$a cmp $b} keys %{$an->data->{node}{$node}{hosts}})
	{
		next if not $this_host;
		next if not $an->data->{node}{$node}{hosts}{$this_host}{ip};
		if (not $print_header)
		{
			push @lines, "#! start hosts !#\n";
			$print_header = 1;
		}
		push @lines, $an->data->{node}{$node}{hosts}{$this_host}{ip}."\t$this_host\n";
	}
	if ($print_header)
	{
		push @lines, "#! end hosts !#\n";
	}
	
	if (@lines > 0)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "writing", value1 => $cache_file,
		}, file => $THIS_FILE, line => __LINE__});
		my $shell_call = "$cache_file";
		open (my $file_handle, ">", "$shell_call") or error($an, $an->String->get({key => "message_0050", variables => { 
				cache_file	=>	$cache_file,
				uid		=>	$<,
				error		=>	$!,
			}}));
		foreach my $line (@lines)
		{
			print $file_handle $line;
		}
		close $file_handle;
	}
	
	return(0);
}

# This reads the cached data for this node, if available.
sub read_node_cache
{
	my ($an, $node) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_node_cache" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Write the command to disk so that I can check the power state in the future when both nodes are
	# offline.
	my $cluster    = $an->data->{cgi}{cluster};
	my $cache_file = $an->data->{path}{'striker_cache'}."/cache_".$cluster."_".$node.".striker";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cluster",    value1 => $cluster,
		name2 => "cache file", value2 => $cache_file,
	}, file => $THIS_FILE, line => __LINE__});
	if (not -e $cache_file)
	{
		# See if there is a version with or without '<node>.remote'
		if ($node =~ /\.remote/)
		{
			# Strip it off
			$cache_file =~ s/\.remote//;
		}
		else
		{
			# Add the .remote suffix.
			$cache_file = $an->data->{path}{'striker_cache'}."/cache_".$cluster."_".$node.".remote.striker";
		}
	}
	if (-e $cache_file)
	{
		# It exists! Read it.
		my $in_hosts   = 0;
		my $shell_call = $cache_file;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "<$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "in_hosts", value1 => $in_hosts,
				name2 => "line",     value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line eq "#! start hosts !#")
			{
				$in_hosts = 1;
				next;
			}
			if ($line eq "#! end hosts !#")
			{
				$in_hosts = 1;
				next;
			}
			if (($in_hosts) && ($line =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(.*)/))
			{
				my $this_ip   = $1;
				my $this_host = $2;
				$an->data->{node}{$node}{hosts}{$this_host}{ip} = $this_ip;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::hosts::${this_host}::ip", value1 => $an->data->{node}{$node}{hosts}{$this_host}{ip},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				next if $line !~ /=/;
				my ($var, $val) = (split/=/, $line, 2);
				$var =~ s/^\s+//;
				$var =~ s/\s+$//;
				$val =~ s/^\s+//;
				$val =~ s/\s+$//;
				
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "var", value1 => $var,
					name2 => "val", value2 => $val,
				}, file => $THIS_FILE, line => __LINE__});
				$an->data->{node}{$node}{info}{$var} = $val;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::info::$var", value1 => $an->data->{node}{$node}{info}{$var}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		close $file_handle;
		$an->data->{clusters}{$cluster}{cache_exists} = 1;
	}
	else
	{
		$an->data->{clusters}{$cluster}{cache_exists} = 0;
		$an->data->{node}{$node}{info}{host_name}     = $node;
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "host name",           value1 => $an->data->{node}{$node}{info}{host_name},
		name2 => "power check command", value2 => $an->data->{node}{$node}{info}{power_check_command},
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

1;
