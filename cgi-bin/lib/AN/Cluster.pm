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
# - https://github.com/digimer/striker
#
# Author;
# Alteeve's Niche!  -  https://alteeve.ca
# Madison Kelly     -  mkelly@alteeve.ca
# 

use strict;
use warnings;
use IO::Handle;
use Net::SSH2;

use AN::Common;
use AN::InstallManifest;
use AN::Striker;

# Setup for UTF-8 mode.
binmode STDOUT, ":utf8:";
$ENV{'PERL_UNICODE'}=1;
my $THIS_FILE = "AN::Cluster.pm";
our $VERSION  = "1.2.0b";

# This shows the user the local hostname and IP addresses. It also provides a
# link to update the underlying OS, if updates are available.
sub configure_local_system
{
	my ($conf) = @_;
	
	# Show the 'scanning in progress' table.
	# variables hash feeds 'message_0272'.
	print AN::Common::template($conf, "common.html", "scanning-message", {}, {
		anvil	=>	$conf->{cgi}{cluster},
	});
	
	# Get the current hostname
	my $hostname = get_hostname($conf);
	
	# Read the network configurations.
	read_network_settings($conf);
	
	# Check for OS updates
	check_for_updates($conf);
	
	return(0);
}

# This checks to see if there are any OS updates available.
sub check_for_updates
{
	my ($conf) = @_;
	
	
	return(0);
}

# This reads the local network cards and their configurations.
sub read_network_settings
{
	my ($conf) = @_;
	
	call_gather_system_info($conf);
	
	
	return(0);
}

# This calls 'gather-system-info' and parses the returned CSV.
sub call_gather_system_info
{
	my ($conf) = @_;
	
	my $shell_call = $conf->{path}{'call_gather-system-info'};
	#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or AN::Common::hard_die($conf, $THIS_FILE, __LINE__, 14, "Failed to call the setuid root C-wrapper: [$shell_call]. The error was: $!\n");
	binmode $file_handle, ":utf8:";
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /hostname,(.*)/)
		{
			$conf->{sys}{hostname} = $1;
		}
		elsif ($line =~ /interface,(.*?),(.*?),(.*)/)
		{
			my $interface = $1;
			my $key       = $2;
			my $value     = $3;
			$conf->{interface}{$interface}{$key} = $value;
			#record($conf, "$THIS_FILE ".__LINE__."; interface::${interface}::$key: [$conf->{interface}{$interface}{$key}]\n");
		}
	}
	close $file_handle;
	
	record($conf, "$THIS_FILE ".__LINE__."; sys::hostname: [$conf->{sys}{hostname}]\n");
	foreach my $interface (sort {$a cmp $b} keys %{$conf->{interface}})
	{
		if (lc($conf->{interface}{$interface}{type}) eq "wireless")
		{
			delete $conf->{interface}{$interface};
			next;
		}
		if (not $conf->{interface}{$interface}{seen_in_ethtool})
		{
			delete $conf->{interface}{$interface};
			next;
		}
		if (($interface =~ /virbr/) or ($interface =~ /vnet/))
		{
			delete $conf->{interface}{$interface};
			next;
		}
	}
	foreach my $interface (sort {$a cmp $b} keys %{$conf->{interface}})
	{
		record($conf, "$THIS_FILE ".__LINE__."; interface: [$interface]\n");
		foreach my $key (sort {$a cmp $b} keys %{$conf->{interface}{$interface}})
		{
			record($conf, "$THIS_FILE ".__LINE__."; - $key:\t[$conf->{interface}{$interface}{$key}]\n");
		}
	}
	
	return(0);
}

# This sanity-checks striker.conf values before saving.
sub sanity_check_striker_conf
{
	my ($conf, $sections) = @_;
	
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
	record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_id: [$conf->{cgi}{anvil_id}]\n");
	if ($conf->{cgi}{anvil_id})
	{
		# Switch out the global keys to this Anvil!'s keys.
		$this_id          = $conf->{cgi}{anvil_id};
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
		
		my $this_name         =  $conf->{cgi}{$name_key};
		   $this_cluster      =  $this_name;
		record($conf, "$THIS_FILE ".__LINE__."; this_cluster: [$this_cluster]\n");
		my $this_description  =  $conf->{cgi}{$description_key};
		my $this_url          =  $conf->{cgi}{$url_key};
		my $this_company      =  $conf->{cgi}{$company_key};
		my $this_ricci_pw     =  $conf->{cgi}{$ricci_pw_key};
		my $this_root_pw      =  $conf->{cgi}{$root_pw_key};
		   $this_nodes_1_name =  $conf->{cgi}{$nodes_1_name_key};
		   $this_nodes_1_ip   =  $conf->{cgi}{$nodes_1_ip_key};
		   $this_nodes_1_port =  $conf->{cgi}{$nodes_1_port_key};
		   $this_nodes_1_port =~ s/,//g;
		   $this_nodes_2_name =  $conf->{cgi}{$nodes_2_name_key};
		   $this_nodes_2_ip   =  $conf->{cgi}{$nodes_2_ip_key};
		   $this_nodes_2_port =  $conf->{cgi}{$nodes_2_port_key};
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
		record($conf, "$THIS_FILE ".__LINE__."; this_nodes_1_name: [$this_nodes_1_name], this_nodes_1_ip: [$this_nodes_1_ip]\n");
		if (($this_nodes_1_name) && ($this_nodes_1_ip))
		{
			$conf->{hosts}{$this_nodes_1_name}{ip} = $this_nodes_1_ip;
			if (not exists $conf->{hosts}{by_ip}{$this_nodes_1_ip})
			{
				$conf->{hosts}{by_ip}{$this_nodes_1_ip} = [];
			}
			push @{$conf->{hosts}{by_ip}{$this_nodes_1_ip}}, $this_nodes_1_name;
		}
		record($conf, "$THIS_FILE ".__LINE__."; this_nodes_2_name: [$this_nodes_2_name], this_nodes_2_ip: [$this_nodes_2_ip]\n");
		if (($this_nodes_2_name) && ($this_nodes_2_ip))
		{
			$conf->{hosts}{$this_nodes_2_name}{ip} = $this_nodes_2_ip;
			if (not exists $conf->{hosts}{by_ip}{$this_nodes_2_ip})
			{
				$conf->{hosts}{by_ip}{$this_nodes_2_ip} = [];
			}
			push @{$conf->{hosts}{by_ip}{$this_nodes_2_ip}}, $this_nodes_2_name;
		}
		record($conf, "$THIS_FILE ".__LINE__."; this_nodes_1_name: [$this_nodes_1_name], this_nodes_1_port: [$this_nodes_1_port]\n");
		if (($this_nodes_1_name) && ($this_nodes_1_port))
		{
			$conf->{hosts}{$this_nodes_1_name}{port} = $this_nodes_1_port;
		}
		record($conf, "$THIS_FILE ".__LINE__."; this_nodes_2_name: [$this_nodes_2_name], this_nodes_2_port: [$this_nodes_2_port]\n");
		if (($this_nodes_2_name) && ($this_nodes_2_port))
		{
			$conf->{hosts}{$this_nodes_2_name}{port} = $this_nodes_2_port;
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
			record($conf, "$THIS_FILE ".__LINE__."; Deleted or empty Anvil!\n");
			if ($this_id ne "new")
			{
				# Delete entries from the hosts and ssh_config
				# files for this Anvil!, too.
				my ($nodes_1_name, $nodes_2_name) = ($conf->{cluster}{$this_id}{name} =~ /(.*?),(.*)/);
				$nodes_1_name =~ s/^\s+//;
				$nodes_1_name =~ s/\s+$//;
				$nodes_2_name =~ s/^\s+//;
				$nodes_2_name =~ s/\s+$//;
				record($conf, "$THIS_FILE ".__LINE__."; Deleting Anvil!: [$conf->{cluster}{$this_id}{name}], company: [$conf->{cluster}{$this_id}{company} ($conf->{cluster}{$this_id}{description})], node 1: [$nodes_1_name], node 2: [$nodes_2_name]\n");
				
				# Delete this from hosts and ssh_config
				delete $conf->{hosts}{$nodes_1_name};
				delete $conf->{hosts}{$nodes_2_name};
				foreach my $this_ip (keys %{$conf->{hosts}{by_ip}})
				{
					# Delete the nodes (empty values are
					# skipped later)
					delete_string_from_array($conf, $nodes_1_name, $conf->{hosts}{by_ip}{$this_ip});
					delete_string_from_array($conf, $nodes_2_name, $conf->{hosts}{by_ip}{$this_ip});
				}
				
				# Now delete the Anvil! from memory.
				delete $conf->{clusters}{$this_id};
			}
			else
			{
				# Not sure why a user is trying to save an empty Anvil!...
				$save = 0;
				print AN::Common::template($conf, "config.html", "form-value-warning", {
					row	=>	"#!string!row_0004!#",
					message	=>	"#!string!message_0004!#",
				}); 
			}
		}
		else
		{
			# Something is defined, make sure it's sane.
			record($conf, "$THIS_FILE ".__LINE__."; this_name: [$this_name], this_nodes_1_name: [$this_nodes_1_name], this_nodes_2_name: [$this_nodes_2_name]\n");
			if ((not $this_name) || (not $this_nodes_1_name) || (not $this_nodes_2_name))
			{
				$save = 0;
				# The second hash passes in the variables for
				# the 'message' string.
				print AN::Common::template($conf, "config.html", "form-value-warning", {
					row	=>	"#!string!row_0004!#",
					message	=>	"#!string!message_0005!#",
				}, {
					id	=>	$this_id,
				});
			}
			else
			{
				# The minimum information is present,
				# now make sure the set values are
				# sane.
				# IPs sane?
				record($conf, "$THIS_FILE ".__LINE__."; this_nodes_1_ip: [$this_nodes_1_ip]\n");
				if (($this_nodes_1_ip) && ($this_nodes_1_ip !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/))
				{
					$save = 0;
					print AN::Common::template($conf, "config.html", "form-value-warning", {
						row	=>	"#!string!row_0008!#",
						message	=>	"#!string!message_0006!#",
					}, {
						name	=>	$this_name,
						node	=>	$this_nodes_1_name,
					}); 
				}
				record($conf, "$THIS_FILE ".__LINE__."; this_nodes_2_ip: [$this_nodes_2_ip]\n");
				if (($this_nodes_2_ip) && ($this_nodes_2_ip !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/))
				{
					$save = 0;
					print AN::Common::template($conf, "config.html", "form-value-warning", {
						row	=>	"#!string!row_0009!#",
						message	=>	"#!string!message_0006!#",
					}, {
						name	=>	$this_name,
						node	=>	$this_nodes_2_name,
					}); 
				}
				# Ports sane?
				record($conf, "$THIS_FILE ".__LINE__."; this_nodes_1_port: [$this_nodes_1_port]\n");
				if (($this_nodes_1_port) && (($this_nodes_1_port =~ /\D/) || ($this_nodes_1_port < 1) || ($this_nodes_1_port > 65535)))
				{
					$save = 0;
					print AN::Common::template($conf, "config.html", "form-value-warning", {
						row	=>	"#!string!row_0010!#",
						message	=>	"#!string!message_0007!#",
					}, {
						name	=>	$this_name,
						node	=>	$this_nodes_1_name,
					}); 
				}
				record($conf, "$THIS_FILE ".__LINE__."; this_nodes_2_port: [$this_nodes_2_port]\n");
				if (($this_nodes_2_port) && (($this_nodes_2_port =~ /\D/) || ($this_nodes_2_port < 1) || ($this_nodes_2_port > 65535)))
				{
					$save = 0;
					print AN::Common::template($conf, "config.html", "form-value-warning", {
						row	=>	"#!string!row_0011!#",
						message	=>	"#!string!message_0007!#",
					}, {
						name	=>	$this_name,
						node	=>	$this_nodes_2_name,
					}); 
				}
				# If there is an IP or Port, but no 
				# node name, well that's just not good.
				record($conf, "$THIS_FILE ".__LINE__."; this_nodes_1_name: [$this_nodes_1_name], this_nodes_1_ip: [$this_nodes_1_ip], this_nodes_1_port: [$this_nodes_1_port]\n");
				if ((not $this_nodes_1_name) && (($this_nodes_1_ip) || ($this_nodes_1_port)))
				{
					$save = 0;
					print AN::Common::template($conf, "config.html", "form-value-warning", {
						row	=>	"#!string!row_0012!#",
						message	=>	"#!string!message_0008!#",
					}, {
						name	=>	$this_name,
					}); 
				}
				record($conf, "$THIS_FILE ".__LINE__."; this_nodes_2_name: [$this_nodes_2_name], this_nodes_2_ip: [$this_nodes_2_ip], this_nodes_2_port: [$this_nodes_2_port]\n");
				if ((not $this_nodes_2_name) && (($this_nodes_2_ip) || ($this_nodes_2_port)))
				{
					$save = 0;
					print AN::Common::template($conf, "config.html", "form-value-warning", {
						row	=>	"#!string!row_0012!#",
						message	=>	"#!string!message_0009!#",
					}, {
						name	=>	$this_name,
					}); 
				}
			}
		}
	}
	record($conf, "$THIS_FILE ".__LINE__."; save: [$save]\n");
	
	# Now Sanity check the global (or Anvil! override) values.
	print AN::Common::template($conf, "config.html", "sanity-check-global-header"); 
	
	# Make sure email addresses are.
	#record($conf, "$THIS_FILE ".__LINE__."; cgi::$smtp__username_key: [$conf->{cgi}{$smtp__username_key}]\n");
	if (($conf->{cgi}{$smtp__username_key}) && ($conf->{cgi}{$smtp__username_key} ne "#!inherit!#") && ($conf->{cgi}{$smtp__username_key} !~ /^\w[\w\.\-]*\w\@\w[\w\.\-]*\w(\.\w+)$/))
	{
		$save = 0;
		print AN::Common::template($conf, "config.html", "form-value-warning", {
			row	=>	"#!string!row_0014!#",
			message	=>	"#!string!message_0011!#",
		}, {
			email	=>	$conf->{cgi}{$smtp__username_key},
		}); 
	}
	#record($conf, "$THIS_FILE ".__LINE__."; cgi::$mail_data__to_key: [$conf->{cgi}{$mail_data__to_key}]\n");
	if (($conf->{cgi}{$mail_data__to_key}) && ($conf->{cgi}{$mail_data__to_key} ne "#!inherit!#"))
	{
		foreach my $email (split /,/, $conf->{cgi}{$mail_data__to_key})
		{
			next if not $email;
			if ($email !~ /^\w[\w\.\-]*\w\@\w[\w\.\-]*\w(\.\w+)$/)
			{
				$save = 0;
				print AN::Common::template($conf, "config.html", "form-value-warning", {
					row	=>	"#!string!row_0015!#",
					message	=>	"#!string!message_0011!#",
				}, {
					email	=>	$email,
				}); 
			}
		}
	}
	
	# Make sure values that should be numerical are.
	#record($conf, "$THIS_FILE ".__LINE__."; cgi::$smtp__port_key: [$conf->{cgi}{$smtp__port_key}], cgi::$smtp__server_key: [$conf->{cgi}{$smtp__server_key}]\n");
	if (($conf->{cgi}{$smtp__port_key}) && ($conf->{cgi}{$smtp__port_key} ne "#!inherit!#"))
	{
		$conf->{cgi}{$smtp__port_key} =~ s/,//;
		if (($conf->{cgi}{$smtp__port_key} =~ /\D/) || ($conf->{cgi}{$smtp__port_key} < 1) || ($conf->{cgi}{$smtp__port_key} > 65535))
		{
			$save = 0;
			print AN::Common::template($conf, "config.html", "form-value-warning", {
				row	=>	"#!string!row_0016!#",
				message	=>	"#!string!message_0012!#",
			});
		}
	}
	elsif (($conf->{cgi}{$smtp__server_key}) && ($conf->{cgi}{$smtp__server_key} ne "#!inherit!#"))
	{
		$save = 0;
		my $say_row     = AN::Common::get_string($conf, {key => "row_0016"});
		my $say_message = AN::Common::get_string($conf, {key => "message_0013"});
		print AN::Common::template($conf, "config.html", "form-value-warning", {
			row	=>	"#!string!row_0016!#",
			message	=>	"#!string!message_0013!#",
		});
	}

	record($conf, "$THIS_FILE ".__LINE__."; save: [$save], cgi::anvil_id: [$conf->{cgi}{anvil_id}]\n");
	if ($save)
	{
		if ($conf->{cgi}{anvil_id})
		{
			# Find a free ID after populating the keys above because
			# they're going to come in from CGI as '...__new__...'.
			record($conf, "$THIS_FILE ".__LINE__."; this_id: [$this_id]\n");
			if ($this_id eq "new")
			{
				# Find the next free ID number.
				my $free_id = 1;
				foreach my $existing_id (sort {$a cmp $b} keys %{$conf->{cluster}})
				{
					record($conf, "$THIS_FILE ".__LINE__."; free_id: [$free_id], existing_id: [$existing_id]\n");
					if ($existing_id eq $free_id)
					{
						$free_id++;
						record($conf, "$THIS_FILE ".__LINE__."; Used.\n");
						next;
					}
					else
					{
						# Got a free one.
						record($conf, "$THIS_FILE ".__LINE__."; free; free_id: [$free_id]\n");
						last;
					}
				}
				$this_id = $free_id;
				record($conf, "$THIS_FILE ".__LINE__."; this_id: [$this_id]\n");
			}
			
			# If I'm still alive, push the passed in keys into $conf->{cluster}...
			# so that they get written out in the next step.
			$conf->{cluster}{$this_id}{name}        = $conf->{cgi}{$name_key};
			$conf->{cluster}{$this_id}{description} = $conf->{cgi}{$description_key};
			$conf->{cluster}{$this_id}{url}         = $conf->{cgi}{$url_key};
			$conf->{cluster}{$this_id}{company}     = $conf->{cgi}{$company_key};
			$conf->{cluster}{$this_id}{ricci_pw}    = $conf->{cgi}{$ricci_pw_key};
			$conf->{cluster}{$this_id}{root_pw}     = $conf->{cgi}{$root_pw_key};
			$conf->{cluster}{$this_id}{nodes}       = "$conf->{cgi}{$nodes_1_name_key}, $conf->{cgi}{$nodes_2_name_key}";
			
			# Record overrides, if any.
			$conf->{cluster}{$this_id}{smtp}{server}              = $conf->{cgi}{$smtp__server_key};
			$conf->{cluster}{$this_id}{smtp}{port}                = $conf->{cgi}{$smtp__port_key};
			$conf->{cluster}{$this_id}{smtp}{username}            = $conf->{cgi}{$smtp__username_key};
			$conf->{cluster}{$this_id}{smtp}{password}            = $conf->{cgi}{$smtp__password_key};
			$conf->{cluster}{$this_id}{smtp}{security}            = $conf->{cgi}{$smtp__security_key};
			$conf->{cluster}{$this_id}{smtp}{encrypt_pass}        = $conf->{cgi}{$smtp__encrypt_pass_key};
			$conf->{cluster}{$this_id}{smtp}{helo_domain}         = $conf->{cgi}{$smtp__helo_domain_key};
			$conf->{cluster}{$this_id}{mail_data}{to}             = $conf->{cgi}{$mail_data__to_key};
			$conf->{cluster}{$this_id}{mail_data}{sending_domain} = $conf->{cgi}{$mail_data__sending_domain_key};
			
			# Record hosts
			$conf->{hosts}{$this_nodes_1_name}{ip} = $this_nodes_1_ip;
			$conf->{hosts}{$this_nodes_2_name}{ip} = $this_nodes_2_ip;
			
			# Create empty arrays, if needed.
			$conf->{hosts}{by_ip}{$this_nodes_1_ip} = [] if not $conf->{hosts}{by_ip}{$this_nodes_1_ip};
			$conf->{hosts}{by_ip}{$this_nodes_2_ip} = [] if not $conf->{hosts}{by_ip}{$this_nodes_2_ip};
			push @{$conf->{hosts}{by_ip}{$this_nodes_1_ip}}, $this_nodes_1_name;
			push @{$conf->{hosts}{by_ip}{$this_nodes_2_ip}}, $this_nodes_2_name;
			
			# Search in 'hosts' and 'ssh_config' for previous
			# entries with these names and delete them if found.
			foreach my $this_ip (sort {$a cmp $b} keys %{$conf->{hosts}{by_ip}})
			{
				my $say_node_1 = $conf->{cgi}{$nodes_1_name_key};
				my $say_node_2 = $conf->{cgi}{$nodes_2_name_key};
				if ($this_ip ne $this_nodes_1_ip)
				{
					delete_string_from_array($conf, $say_node_1, $conf->{hosts}{by_ip}{$this_ip});
				}
				if ($this_ip ne $this_nodes_2_ip)
				{
					delete_string_from_array($conf, $say_node_2, $conf->{hosts}{by_ip}{$this_ip});
				}
			}
			foreach my $this_host (sort {$a cmp $b} keys %{$conf->{hosts}})
			{
				if ($this_host eq $conf->{cgi}{$nodes_1_name_key})
				{
					$conf->{hosts}{$this_host}{port} = $this_nodes_1_port ? $this_nodes_1_port : "";
				}
				if ($this_host eq $conf->{cgi}{$nodes_2_name_key})
				{
					$conf->{hosts}{$this_host}{port} = $this_nodes_2_port ? $this_nodes_2_port : "";
				}
			}
		}
		else
		{
			# Modifying global, copy CGI to main variables.
			$conf->{smtp}{server}              = $conf->{cgi}{smtp__server};
			$conf->{smtp}{port}                = $conf->{cgi}{smtp__port};
			$conf->{smtp}{username}            = $conf->{cgi}{smtp__username};
			$conf->{smtp}{password}            = $conf->{cgi}{smtp__password};
			$conf->{smtp}{security}            = $conf->{cgi}{smtp__security};
			$conf->{smtp}{encrypt_pass}        = $conf->{cgi}{smtp__encrypt_pass};
			$conf->{smtp}{helo_domain}         = $conf->{cgi}{smtp__helo_domain};
			$conf->{mail_data}{to}             = $conf->{cgi}{mail_data__to};
			$conf->{mail_data}{sending_domain} = $conf->{cgi}{mail_data__sending_domain};
		}
	}

	record($conf, "$THIS_FILE ".__LINE__."; save: [$save]\n");
	return ($save);
}

# This deletes an entry from an array by blanking it's value if it's existing
# value matches the string passed in.
sub delete_string_from_array
{
	my ($conf, $string, $array) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; delete_string_from_array(); string: [$string]\n");
	
	# Delete the nodes (empty values are
	# skipped later)
	for (my $i = 0; $i < @{$array}; $i++)
	{
		#record($conf, "$THIS_FILE ".__LINE__."; i: [$i], value: [$array->[$i]], string: [$string]\n");
		if ($array->[$i] eq $string)
		{
			#record($conf, "$THIS_FILE ".__LINE__."; Value matches, blanking.\n");
			$array->[$i] = "";
		}
	}
	
	return($array);
}

# This writes out the new striker.conf file.
sub write_new_striker_conf
{
	my ($conf, $say_date) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; write_new_striker_conf(); say_date: [$say_date]\n");
	
	# Tell the user where ready to go.
	print AN::Common::template($conf, "config.html", "general-row-good", {
		row	=>	"#!string!row_0018!#",
		message	=>	"#!string!message_0015!#",
	});
	
	# Tweak some values, if needed
	if (not $conf->{cgi}{anvil_id})
	{
		# If the sending domain or helo domain are 
		# 'example.com', make them the short version of the
		# sending email, if defined, or else the smtp server.
		if ($conf->{cgi}{mail_data__sending_domain} eq "example.com")
		{
			if ($conf->{cgi}{smtp__username} =~ /.*?\@(.*)/)
			{
				$conf->{cgi}{mail_data__sending_domain} = $1;
			}
			else
			{
				$conf->{cgi}{mail_data__sending_domain} =  $conf->{cgi}{smtp__server};
				$conf->{cgi}{mail_data__sending_domain} =~ s/^.*?\.(.*?\..*?)$/$1/;
			}
		}
		if ($conf->{cgi}{smtp__helo_domain} eq "example.com")
		{
			if ($conf->{cgi}{smtp__username} =~ /.*?\@(.*)/)
			{
				$conf->{cgi}{smtp__helo_domain} = $1;
			}
			else
			{
				$conf->{cgi}{smtp__helo_domain} =  $conf->{cgi}{smtp__server};
				$conf->{cgi}{smtp__helo_domain} =~ s/^.*?\.(.*?\..*?)$/$1/;
			}
		}
	}
	
	# Read in the existing config file.
	my $new_config = "";
	if (-e $conf->{path}{config_file})
	{
		my $anvil_id   = $conf->{cgi}{anvil_id};
		my $shell_call = $conf->{path}{config_file};
		open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			
			# We don't want to munge the config any more than
			# necessary as the user may have customizations we
			# don't want to clobber.
			if (($line =~ /^#/) || ($line =~ /^\s+#/))
			{
				# This just makes sure we don't parse commented
				# out example variable=value pairs
			}
			elsif ($line =~ /(.*?)=(.*)$/)
			{
				# Looks like a variable. Even if it's not
				# though, that should be OK because we won't
				# alter any variables we're not explicitely
				# checking for.
				my $variable = $1;
				my $value    = $2;
				
				# Strip white spaces
				$variable =~ s/^\s+//;
				$variable =~ s/\s+$//;
				$value    =~ s/^\s+//;
				$value    =~ s/\s+$//;
				#record($conf, "$THIS_FILE ".__LINE__."; variable: [$variable], value: [$value]\n");
				
				# We're setting certain values. If this
				# variable matches on of the ones we're
				# setting, overwrite the current value. 
				# Otherwise, leave it as-is.
				
				if (($variable eq "smtp::encrypt_pass")        && ($conf->{cgi}{smtp__encrypt_pass}))        { $line =~ s/=.*$/=\t$conf->{cgi}{smtp__encrypt_pass}/; }
				if (($variable eq "smtp::helo_domain")         && ($conf->{cgi}{smtp__helo_domain}))         { $line =~ s/=.*$/=\t$conf->{cgi}{smtp__helo_domain}/; }
				if (($variable eq "smtp::password")            && ($conf->{cgi}{smtp__password}))            { $line =~ s/=.*$/=\t$conf->{cgi}{smtp__password}/; }
				if (($variable eq "smtp::port")                && ($conf->{cgi}{smtp__port}))                { $line =~ s/=.*$/=\t$conf->{cgi}{smtp__port}/; }
				if (($variable eq "smtp::security")            && ($conf->{cgi}{smtp__security}))            { $line =~ s/=.*$/=\t$conf->{cgi}{smtp__security}/; }
				if (($variable eq "smtp::server")              && ($conf->{cgi}{smtp__server}))              { $line =~ s/=.*$/=\t$conf->{cgi}{smtp__server}/; }
				if (($variable eq "smtp::username")            && ($conf->{cgi}{smtp__username}))            { $line =~ s/=.*$/=\t$conf->{cgi}{smtp__username}/; }
				if (($variable eq "mail_data::to")             && ($conf->{cgi}{mail_data__to}))             { $line =~ s/=.*$/=\t$conf->{cgi}{mail_data__to}/; }
				if (($variable eq "mail_data::sending_domain") && ($conf->{cgi}{mail_data__sending_domain})) { $line =~ s/=.*$/=\t$conf->{cgi}{mail_data__sending_domain}/; }
				
				# If I am saving a new or edited Anvil!
				# definition, check to see if it already exists
				# in the config file. If so, edit it in place.
				# If the Anvil! is not seen, it will be
				# appended at the end.
				if (($anvil_id) && ($anvil_id ne "new"))
				{
					$conf->{seen_anvil}{$anvil_id} = 1;
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
					
					# If the anvil has been deleted, simply
					# skip this line.
					next if ((not $conf->{cgi}{$name_key}) && ($line =~ /cluster::$anvil_id::/));
					
					# Anvil! details
					if ($variable eq "cluster::${anvil_id}::company")     { $line =~ s/=.*$/=\t$conf->{cgi}{$company_key}/; }
					if ($variable eq "cluster::${anvil_id}::description") { $line =~ s/=.*$/=\t$conf->{cgi}{$description_key}/; }
					if ($variable eq "cluster::${anvil_id}::name")        { $line =~ s/=.*$/=\t$conf->{cgi}{$name_key}/; }
					if ($variable eq "cluster::${anvil_id}::nodes")       { $line =~ s/=.*$/=\t$conf->{cgi}{$node1_name_key} $conf->{cgi}{$node2_name_key}/; }
					if ($variable eq "cluster::${anvil_id}::ricci_pw")    { $line =~ s/=.*$/=\t$conf->{cgi}{$ricci_pw_key}/; }
					if ($variable eq "cluster::${anvil_id}::root_pw")     { $line =~ s/=.*$/=\t$conf->{cgi}{$root_pw_key}/; }
					if ($variable eq "cluster::${anvil_id}::url")         { $line =~ s/=.*$/=\t$conf->{cgi}{$url_key}/; }
					
					# Mail variables
					if ($variable eq "cluster::${anvil_id}::smtp::server")              { $line =~ s/=.*$/=\t$conf->{cgi}{$smtp_server_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::port")                { $line =~ s/=.*$/=\t$conf->{cgi}{$smtp_port_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::username")            { $line =~ s/=.*$/=\t$conf->{cgi}{$smtp_username_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::password")            { $line =~ s/=.*$/=\t$conf->{cgi}{$smtp_password_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::security")            { $line =~ s/=.*$/=\t$conf->{cgi}{$smtp_security_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::encrypt_pass")        { $line =~ s/=.*$/=\t$conf->{cgi}{$smtp_encrypt_pass_key}/; }
					if ($variable eq "cluster::${anvil_id}::smtp::helo_domain")         { $line =~ s/=.*$/=\t$conf->{cgi}{$smtp_helo_domain_key}/; }
					if ($variable eq "cluster::${anvil_id}::mail_data::to")             { $line =~ s/=.*$/=\t$conf->{cgi}{$mail_data_to_key}/; }
					if ($variable eq "cluster::${anvil_id}::mail_data::sending_domain") { $line =~ s/=.*$/=\t$conf->{cgi}{$mail_data_sending_domain_key}/; }
				}
			}
			$new_config .= "$line\n";
		}
		close $file_handle;
		
		### TODO: Look for and remove comments for now-deleted Anvil!
		###       systems.
		# If a new Anvil! has been created, add it.
		# Now print the individual Anvil!s 
		foreach my $this_id (sort {$a cmp $b} keys %{$conf->{cluster}})
		{
			next if not $this_id;
			next if not $conf->{cluster}{$this_id}{name};
			next if $conf->{seen_anvil}{$this_id};
			
			# If I am still here, this is an unrecorded Anvil!.
			$new_config .= generate_anvil_entry_for_striker_conf($conf, $this_id);
		}
	}
	else
	{
		# No existing config, write it new.
		my $say_date_header = AN::Common::get_string($conf, {key => "text_0003", variables => {
			date	=>	$say_date,
		}});
		my $say_text = AN::Common::get_string($conf, {key => "text_0001"});
		$new_config .= "$say_date_header\n";
		$new_config .= "$say_text\n";
		
		# The user doesn't currently set the 'smtp::helo_domain' or 
		# 'mail_data::sending_domain', so for now we'll devine it from the user's 
		# 'smtp::username'.
		record($conf, "$THIS_FILE ".__LINE__."; smtp::helo_domain: [$conf->{smtp}{helo_domain}], mail_data::sending_domain: [$conf->{mail_data}{sending_domain}]\n");
		if ($conf->{smtp}{helo_domain} eq "example.com")
		{
			my $domain = ($conf->{smtp}{username} =~ /.*@(.*)$/)[0];
			$conf->{smtp}{helo_domain} = $domain if $domain;
			record($conf, "$THIS_FILE ".__LINE__."; smtp::helo_domain: [$conf->{smtp}{helo_domain}], domain: [$domain]\n");
		}
		if ($conf->{mail_data}{sending_domain} eq "example.com")
		{
			my $domain = ($conf->{smtp}{username} =~ /.*@(.*)$/)[0];
			$conf->{mail_data}{sending_domain} = $domain if $domain;
			record($conf, "$THIS_FILE ".__LINE__."; mail_data::sending_domain: [$conf->{mail_data}{sending_domain}]: domain: [$domain]\n");
		}
		
		# Write out the global values.
		my $say_body = AN::Common::get_string($conf, {key => "text_0002", variables => {
			smtp__server			=>	$conf->{smtp}{server},
			smtp__port			=>	$conf->{smtp}{port},
			smtp__username			=>	$conf->{smtp}{username},
			smtp__password			=>	$conf->{smtp}{password},
			smtp__security			=>	$conf->{smtp}{security},
			smtp__encrypt_pass		=>	$conf->{smtp}{encrypt_pass},
			smtp__helo_domain		=>	$conf->{smtp}{helo_domain},
			mail_data__to			=>	$conf->{mail_data}{to},
			mail_data__sending_domain	=>	$conf->{mail_data}{sending_domain},
		}});
		$new_config .= $say_body;
		
		# Now print the individual Anvil!s 
		foreach my $this_id (sort {$a cmp $b} keys %{$conf->{cluster}})
		{
			next if not $this_id;
			next if not $conf->{cluster}{$this_id}{name};
			
			my ($new_anvil_data) = generate_anvil_entry_for_striker_conf($conf, $this_id);
		}
	}
	
	# Save the file.
	my $shell_call = $conf->{path}{config_file};
	#my $shell_call = "/tmp/striker.conf";
	open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write: [$shell_call], error was: $!\n";
	print $file_handle $new_config;
	close $file_handle;
	
	return(0);
}

# This generates the raw text entry lines for an Anvil! that can be added to
# striker.conf.
sub generate_anvil_entry_for_striker_conf
{
	my ($conf, $this_id) = @_;
	
	my $data = "";
	# Main Anvil! values, always recorded, even when blank.
	$data .= "\n# $conf->{cluster}{$this_id}{company} - $conf->{cluster}{$this_id}{description}\n";
	$data .= "cluster::${this_id}::company\t\t\t=\t$conf->{cluster}{$this_id}{company}\n";
	$data .= "cluster::${this_id}::description\t\t\t=\t$conf->{cluster}{$this_id}{description}\n";
	$data .= "cluster::${this_id}::name\t\t\t=\t$conf->{cluster}{$this_id}{name}\n";
	$data .= "cluster::${this_id}::nodes\t\t\t=\t$conf->{cluster}{$this_id}{nodes}\n";
	$data .= "cluster::${this_id}::ricci_pw\t\t\t=\t$conf->{cluster}{$this_id}{ricci_pw}\n";
	$data .= "cluster::${this_id}::root_pw\t\t\t=\t$conf->{cluster}{$this_id}{root_pw}\n";
	$data .= "cluster::${this_id}::url\t\t\t\t=\t$conf->{cluster}{$this_id}{url}\n";
	
	# Set any undefined values to '#!inherit!#'
	$conf->{cluster}{$this_id}{smtp}{server}              = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{smtp}{server};
	$conf->{cluster}{$this_id}{smtp}{port}                = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{smtp}{port};
	$conf->{cluster}{$this_id}{smtp}{username}            = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{smtp}{username};
	$conf->{cluster}{$this_id}{smtp}{password}            = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{smtp}{password};
	$conf->{cluster}{$this_id}{smtp}{security}            = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{smtp}{security};
	$conf->{cluster}{$this_id}{smtp}{encrypt_pass}        = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{smtp}{encrypt_pass};
	$conf->{cluster}{$this_id}{smtp}{helo_domain}         = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{smtp}{helo_domain};
	$conf->{cluster}{$this_id}{mail_data}{to}             = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{mail_data}{to};
	$conf->{cluster}{$this_id}{mail_data}{sending_domain} = "#!inherit!#" if not exists $conf->{cluster}{$this_id}{mail_data}{sending_domain};
	
	# Record this Anvil!'s overrides (or that it doesn't override,
	# as the case may be).
	$data .= "cluster::${this_id}::smtp::server\t\t=\t$conf->{cluster}{$this_id}{smtp}{server}\n";
	$data .= "cluster::${this_id}::smtp::port\t\t\t=\t$conf->{cluster}{$this_id}{smtp}{port}\n";
	$data .= "cluster::${this_id}::smtp::username\t\t=\t$conf->{cluster}{$this_id}{smtp}{username}\n";
	$data .= "cluster::${this_id}::smtp::password\t\t=\t$conf->{cluster}{$this_id}{smtp}{password}\n";
	$data .= "cluster::${this_id}::smtp::security\t\t=\t$conf->{cluster}{$this_id}{smtp}{security}\n";
	$data .= "cluster::${this_id}::smtp::encrypt_pass\t\t=\t$conf->{cluster}{$this_id}{smtp}{encrypt_pass}\n";
	$data .= "cluster::${this_id}::smtp::helo_domain\t\t=\t$conf->{cluster}{$this_id}{smtp}{helo_domain}\n";
	$data .= "cluster::${this_id}::mail_data::to\t\t=\t$conf->{cluster}{$this_id}{mail_data}{to}\n";
	$data .= "cluster::${this_id}::mail_data::sending_domain\t=\t$conf->{cluster}{$this_id}{mail_data}{sending_domain}\n";
	$data .= "\n";
	
	return($data);
}
	

# This reads in /etc/hosts and later will try to match host names to IPs
sub read_hosts
{
	my ($conf) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; read_hosts()\n");
	
	my $shell_call = "$conf->{path}{hosts}";
	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
	while (<$file_handle>)
	{
		chomp;
		my $line =  $_;
		   $line =~ s/^\s+//;
		   $line =~ s/#.*$//;
		   $line =~ s/\s+$//;
		next if not $line;
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		
		my ($this_ip, $these_hosts);
		### NOTE: We don't support IPv6 yet
		if ($line =~ /^(\d+\.\d+\.\d+\.\d+)\s+(.*)/)
		{
			$this_ip     = $1;
			$these_hosts = $2;
			foreach my $this_host (split/ /, $these_hosts)
			{
				$conf->{hosts}{$this_host}{ip} = $this_ip;
				if (not exists $conf->{hosts}{by_ip}{$this_ip})
				{
					$conf->{hosts}{by_ip}{$this_ip} = [];
				}
				push @{$conf->{hosts}{by_ip}{$this_ip}}, $this_host;
				#record($conf, "$THIS_FILE ".__LINE__."; Added this_host: [$this_host] to array: [$conf->{hosts}{by_ip}{$this_ip}]\n");
			}
		}
	}
	close $file_handle;
	
	# Debug
	foreach my $this_ip (sort {$a cmp $b} keys %{$conf->{hosts}{by_ip}})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; $this_ip\n");
		foreach my $this_host (sort {$a cmp $b} @{$conf->{hosts}{by_ip}{$this_ip}})
		{
			#record($conf, "$THIS_FILE ".__LINE__."; - this_host: [$this_host]\n");
		}
	}
	
	return(0);
}

# This reads /etc/ssh/ssh_config and later will try to match host names to
# port forwards.
sub read_ssh_config
{
	my ($conf) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; read_ssh_config()\n");
	
	$conf->{raw}{ssh_config} = [];
	my $this_host;
	my $shell_call = "$conf->{path}{ssh_config}";
	#record($conf, "$THIS_FILE ".__LINE__."; reading: [$shell_call]\n");
	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		# I skip this to avoid multiple 'Last updated...' lines at the
		# top of the file when I rewrite this.
		next if $line =~ /^### Last updated: /;
		#record($conf, "$THIS_FILE ".__LINE__."; >> line: [$line]\n");
		push @{$conf->{raw}{ssh_config}}, $line;
		$line =~ s/#.*$//;
		$line =~ s/\s+$//;
		next if not $line;
		#record($conf, "$THIS_FILE ".__LINE__."; << line: [$line]\n");
		
		if ($line =~ /^host (.*)/i)
		{
			$this_host = $1;
			next;
		}
		next if not $this_host;
		if ($line =~ /port (\d+)/i)
		{
			my $port = $1;
			$conf->{hosts}{$this_host}{port} = $port;
			#record($conf, "$THIS_FILE ".__LINE__."; this_host: [$this_host] -> port: [$conf->{hosts}{$this_host}{port}]\n");
		}
	}
	close $file_handle;
	
	return(0);
}

# This copies a file from one place to another.
sub copy_file
{
	my ($conf, $source, $destination) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; copy_file(); source: [$source], destination: [$destination]\n");
	
	my $output     = "";
	my $shell_call = "$conf->{path}{cp} -f $source $destination; $conf->{path}{sync}";
	#record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$output .= "$line\n";
		record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
	}
	close $file_handle;
	
	if (not -e $destination)
	{
		$output =~ s/\n$//;
		my $say_message = AN::Common::get_string($conf, {key => "message_0016", variables => {
			file		=>	$source,
			destination	=>	$destination,
			output		=>	$output,
		}});
		error($conf, $say_message, 1);
	}
	
	return(0);
}

sub write_new_ssh_config
{
	my ($conf, $say_date) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; write_new_ssh_config(); say_date: [$say_date]\n");
	
	my $shell_call = $conf->{path}{ssh_config};
	open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write to: [$shell_call], error was: $!\n";
	my $say_date_header = AN::Common::get_string($conf, {key => "text_0003", variables => {
		date	=>	$say_date,
	}});
	print $file_handle "$say_date_header\n";
	
	# Re print the ssh_config, but skip 'Host' sections for now.
	my $last_line_was_blank = 0;
	foreach my $line (@{$conf->{raw}{ssh_config}})
	{
		$say_date_header =~ s/\[.*?\]/\[\]/;
		next if $line =~ /$say_date_header/;
		
		#record($conf, "$THIS_FILE ".__LINE__."; >> ssh_config line: [$line]\n");
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
	my $say_host_header = AN::Common::get_string($conf, {key => "text_0004"});
	print $file_handle "\n$say_host_header\n\n";
	
	# Now add any new entries.
	foreach my $this_host (sort {$a cmp $b} keys %{$conf->{hosts}})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; this_host: [$this_host], port: [$conf->{hosts}{$this_host}{port}]\n");
		next if not $conf->{hosts}{$this_host}{port};
		print $file_handle "Host $this_host\n";
		print $file_handle "\tPort $conf->{hosts}{$this_host}{port}\n\n";
		#record($conf, "$THIS_FILE ".__LINE__."; << ssh_config line: [Host $this_host]\n");
		#record($conf, "$THIS_FILE ".__LINE__."; << ssh_config line: [\tPort $conf->{hosts}{$this_host}{port}]\n");
	}
	close $file_handle;

	return(0);
}

# Write out the new 'hosts' file. This is simple and doesn't preserve comments
# or formatting. It will preserve non-node related IPs.
sub write_new_hosts
{
	my ($conf, $say_date) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; write_new_hosts(); say_date: [$say_date]\n");
	
	# Open the file
	my $shell_call = $conf->{path}{hosts};
	#my $shell_call = "/tmp/hosts";
	open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write to: [$shell_call], error was: $!\n";
	my $say_date_header = AN::Common::get_string($conf, {key => "text_0003", variables => {
		date	=>	$say_date,
	}});
	my $say_host_header = AN::Common::get_string($conf, {key => "text_0005"});
	print $file_handle "$say_date_header\n";
	print $file_handle "$say_host_header\n";
	
	# Print 127.0.0.1 first to keep things cleaner.
	my $hosts      = "";
	my $seen_hosts = {};
	my $this_ip    = "127.0.0.1";
	foreach my $this_host (sort {$a cmp $b} @{$conf->{hosts}{by_ip}{$this_ip}})
	{
		# Avoid dupes
		next if $seen_hosts->{$this_ip}{$this_host};
		$seen_hosts->{$this_ip}{$this_host} = 1;
		$hosts .= "$this_host ";
		#record($conf, "$THIS_FILE ".__LINE__."; hosts: [$hosts]\n");
	}
	   $hosts =~ s/ $//;
	my $line  =  "$this_ip\t$hosts";
	#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
	print $file_handle "$line\n";
	delete $conf->{hosts}{by_ip}{"127.0.0.1"};
	
	# Push the IPs into an array for sorting.
	my @ip;
	foreach my $this_ip (sort {$a cmp $b} keys %{$conf->{hosts}{by_ip}})
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
		foreach my $this_host (sort {$a cmp $b} @{$conf->{hosts}{by_ip}{$this_ip}})
		{
			# Avoid dupes
			next if $seen_hosts->{$this_ip}{$this_host};
			$seen_hosts->{$this_ip}{$this_host} = 1;
			$hosts .= "$this_host ";
			#record($conf, "$THIS_FILE ".__LINE__."; hosts: [$hosts]\n");
		}
		$hosts =~ s/ $//;
		
		# Add a space if the first three octals have changed.
		my $start_octals = ($this_ip =~ /^(\d+\.\d+\.\d+)\./)[0];
		if ($start_octals ne $last_start_octals)
		{
			$last_start_octals = $start_octals;
			print $file_handle "\n";
		}
		
		my $line  =  "$this_ip\t$hosts";
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		print $file_handle "$line\n";
	}
	close $file_handle;
	
	return(0);
}

# Verify and then save the global dashboard configuration.
sub save_dashboard_configure
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; save_dashboard_configure()\n");
	
	my ($save) = sanity_check_striker_conf($conf, $conf->{cgi}{section});
	if ($save)
	{
		# Get the current date and time.
		my ($say_date) =  get_date($conf, time);
		#record($conf, "$THIS_FILE ".__LINE__."; say_date: [$say_date]\n");
		my $date       =  $say_date;
		   $date       =~ s/ /_/g;
		   $date       =~ s/:/-/g;
		   $say_date   =~ s/ /, /g;
		#record($conf, "$THIS_FILE ".__LINE__."; say_date: [$say_date], date: [$date]\n");
		
		# Write out the new config file.
		record($conf, "$THIS_FILE ".__LINE__."; Backing up: [$conf->{path}{config_file}] to: [$conf->{path}{home}/archive/striker.conf.$date]\n");
		copy_file($conf, $conf->{path}{config_file}, "$conf->{path}{home}/archive/striker.conf.$date");
		write_new_striker_conf($conf, $say_date);
		
		# Write out the 'hosts' file.
		record($conf, "$THIS_FILE ".__LINE__."; Backing up: [$conf->{path}{hosts}] to: [$conf->{path}{home}/archive/hosts.$date]\n");
		copy_file($conf, $conf->{path}{hosts}, "$conf->{path}{home}/archive/hosts.$date");
		write_new_hosts($conf, $say_date);
		
		# Write out the 'ssh_config' file.
		copy_file($conf, $conf->{path}{ssh_config}, "$conf->{path}{home}/archive/ssh_config.$date");
		write_new_ssh_config($conf, $say_date);
		
		# If requested in the config, add the user's SSH keys to the
		# new anvil!.
		my $anvil_id               = $conf->{cgi}{anvil_id};
		my $anvil_name_key         = "cluster__${anvil_id}__name";
		my $anvil_name             = $conf->{cgi}{$anvil_name_key};
		my $root_root_password_key = "cluster__${anvil_id}__root_pw";
		my $root_ricci_key         = "cluster__${anvil_id}__ricci_pw";
		my $root_password          = $conf->{cgi}{$root_root_password_key} ? $conf->{cgi}{$root_root_password_key} : $conf->{cgi}{$root_ricci_key};
		my $node1_name_key         = "cluster__${anvil_id}__nodes_1_name";
		my $node1_name             = $conf->{cgi}{$node1_name_key};
		my $node2_name_key         = "cluster__${anvil_id}__nodes_2_name";
		my $node2_name             = $conf->{cgi}{$node2_name_key};
		if (($anvil_id eq "new") && ($conf->{sys}{auto_populate_ssh_users}))
		{
			# For each user, check to see if the 
			# '/home/<user>/populate_remote_authorized_keys' script
			# exists and, if so, run it.
			foreach my $user (split/,/, $conf->{sys}{auto_populate_ssh_users})
			{
				next if not $user;
				my $user_home   = "/home/$user";
				my $script_path = "$user_home/call_populate_remote_authorized_keys";
				record($conf, "$THIS_FILE ".__LINE__."; Trying to run: [$script_path]...\n");
				if (not -e $user_home)
				{
					# User doesn't appear to exist at all.
					record($conf, "$THIS_FILE ".__LINE__."; [ Warning ] - User: [$user] doesn't appear to have a home directory.\n");
				}
				elsif (not -e $script_path)
				{
					# Script doesn't exist.
					record($conf, "$THIS_FILE ".__LINE__."; [ Warning ] - Failed to find: [$script_path], the setuid C-wrapper may not have been created properly\n");
				}
				elsif (not -x $script_path)
				{
					# Script isn't executable
					record($conf, "$THIS_FILE ".__LINE__."; [ Warning ] - The program: [$script_path] isn't executable. Try running: [chown $user:$user $script_path && chmod 6755 $script_path].\n");
				}
				else
				{
					# Try running it against node 1
					my $shell_call = "$script_path -p $root_password -r $node1_name";
					record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
					open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
					while(<$file_handle>)
					{
						chomp;
						my $line = $_;
						record($conf, "$THIS_FILE ".__LINE__."; [ Debug ] - line: [$line]\n");
					}
					close $file_handle;
					
					# Now node 2
					$shell_call = "$script_path -p $root_password -r $node2_name";
					record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
					open ($file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
					while(<$file_handle>)
					{
						chomp;
						my $line = $_;
						record($conf, "$THIS_FILE ".__LINE__."; [ Debug ] - line: [$line]\n");
					}
					close $file_handle;
				}
			}
		}
		
		# Which message to show will depend on whether we're saving an
		# Anvil! or the global config. The 'message_0017' provides a
		# link to the user's Anvil!, which is non-existent when saving
		# global values.
		my $message = AN::Common::get_string($conf, {key => "message_0377"});
		if ($anvil_name)
		{
			$message = AN::Common::get_string($conf, {key => "message_0017", variables => {
					url	=>	"?cluster=$anvil_name"
				}});
		}
		print AN::Common::template($conf, "config.html", "general-row-good", {
			row	=>	"#!string!row_0019!#",
			message	=>	$message,
		});
		print AN::Common::template($conf, "config.html", "close-table");
		footer($conf);
		exit(0);
	}
	else
	{
		# Problem
		print AN::Common::template($conf, "config.html", "form-value-warning", {
			row	=>	"#!string!row_0020!#",
			message	=>	"#!string!message_0018!#",
		});
	}
	record($conf, "$THIS_FILE ".__LINE__."; cgi::cluster__new__name: [$conf->{cgi}{cluster__new__name}]\n");
	
	print AN::Common::template($conf, "config.html", "close-table");

	return(0);
}

# This uses the data from the config files to pre-fill configuration form data.
sub load_configuration_defaults
{
	my ($conf) = @_;
	
	# In all cases, load the global values.
	#record($conf, "$THIS_FILE ".__LINE__."; cgi::smtp__server: [$conf->{cgi}{cgi}{smtp__server}], smtp::server: [$conf->{smtp}{server}]\n");
	$conf->{cgi}{smtp__server}              = defined $conf->{smtp}{server}              ? $conf->{smtp}{server}              : "";
	$conf->{cgi}{smtp__port}                = defined $conf->{smtp}{port}                ? $conf->{smtp}{port}                : "";
	$conf->{cgi}{smtp__username}            = defined $conf->{smtp}{username}            ? $conf->{smtp}{username}            : "";
	$conf->{cgi}{smtp__password}            = defined $conf->{smtp}{password}            ? $conf->{smtp}{password}            : "";
	$conf->{cgi}{smtp__security}            = defined $conf->{smtp}{security}            ? $conf->{smtp}{security}            : "";
	$conf->{cgi}{smtp__encrypt_pass}        = defined $conf->{smtp}{encrypt_pass}        ? $conf->{smtp}{encrypt_pass}        : "";
	$conf->{cgi}{smtp__helo_domain}         = defined $conf->{smtp}{helo_domain}         ? $conf->{smtp}{helo_domain}         : "";
	$conf->{cgi}{mail_data__to}             = defined $conf->{mail_data}{to}             ? $conf->{mail_data}{to}             : "";
	$conf->{cgi}{mail_data__sending_domain} = defined $conf->{mail_data}{sending_domain} ? $conf->{mail_data}{sending_domain} : "";
	
	# If I've been passed an anvil name, load it's data.
	if ($conf->{cgi}{anvil})
	{
		# Details on the Anvil!.
		my $this_cluster     = $conf->{cgi}{anvil};
		my $this_id          = defined $conf->{clusters}{$this_cluster}{id} ? $conf->{clusters}{$this_cluster}{id} : "new";
		my $name_key         = "cluster__${this_id}__name";
		my $company_key      = "cluster__${this_id}__company";
		my $description_key  = "cluster__${this_id}__description";
		my $url_key          = "cluster__${this_id}__url";
		my $ricci_pw_key     = "cluster__${this_id}__ricci_pw";
		my $root_pw_key      = "cluster__${this_id}__root_pw";
		my $nodes_1_name_key = "cluster__${this_id}__nodes_1_name";
		my $nodes_1_ip_key   = "cluster__${this_id}__nodes_1_ip";
		my $nodes_1_port_key = "cluster__${this_id}__nodes_1_port";
		my $nodes_2_name_key = "cluster__${this_id}__nodes_2_name";
		my $nodes_2_ip_key   = "cluster__${this_id}__nodes_2_ip";
		my $nodes_2_port_key = "cluster__${this_id}__nodes_2_port";
		
		$conf->{cgi}{$name_key}         = defined $conf->{clusters}{$this_cluster}{name}        ? $conf->{clusters}{$this_cluster}{name}        : "";
		$conf->{cgi}{$company_key}      = defined $conf->{clusters}{$this_cluster}{company}     ? $conf->{clusters}{$this_cluster}{company}     : "";
		$conf->{cgi}{$company_key}      = convert_text_to_html($conf, $conf->{cgi}{$company_key});
		$conf->{cgi}{$description_key}  = defined $conf->{clusters}{$this_cluster}{description} ? $conf->{clusters}{$this_cluster}{description} : "";
		$conf->{cgi}{$description_key}  = convert_text_to_html($conf, $conf->{cgi}{$description_key});
		$conf->{cgi}{$url_key}          = defined $conf->{clusters}{$this_cluster}{url}         ? $conf->{clusters}{$this_cluster}{url}         : "";
		$conf->{cgi}{$ricci_pw_key}     = defined $conf->{clusters}{$this_cluster}{ricci_pw}    ? $conf->{clusters}{$this_cluster}{ricci_pw}    : "";
		$conf->{cgi}{$root_pw_key}      = defined $conf->{clusters}{$this_cluster}{root_pw}     ? $conf->{clusters}{$this_cluster}{root_pw}     : "";
		$conf->{cgi}{$nodes_1_name_key} = defined $conf->{clusters}{$this_cluster}{nodes}[0]    ? $conf->{clusters}{$this_cluster}{nodes}[0]    : "";
		my $this_nodes_1_name           = $conf->{cgi}{$nodes_1_name_key};
		$conf->{cgi}{$nodes_1_ip_key}   = defined $conf->{hosts}{$this_nodes_1_name}{ip}        ? $conf->{hosts}{$this_nodes_1_name}{ip}        : "";
		$conf->{cgi}{$nodes_1_port_key} = defined $conf->{hosts}{$this_nodes_1_name}{port}      ? $conf->{hosts}{$this_nodes_1_name}{port}      : "";
		$conf->{cgi}{$nodes_2_name_key} = defined $conf->{clusters}{$this_cluster}{nodes}[0]    ? $conf->{clusters}{$this_cluster}{nodes}[0]    : "";
		my $this_nodes_2_name           = $conf->{cgi}{$nodes_2_name_key};
		$conf->{cgi}{$nodes_2_ip_key}   = defined $conf->{hosts}{$this_nodes_2_name}{ip}        ? $conf->{hosts}{$this_nodes_2_name}{ip}        : "";
		$conf->{cgi}{$nodes_2_port_key} = defined $conf->{hosts}{$this_nodes_2_name}{port}      ? $conf->{hosts}{$this_nodes_2_name}{port}      : "";
		
		# Now set/load global overrides.
		### an empty value is valid. To use global, these need to be
		### set to '#!inherit!# to have them be deleted 
		my $smtp__server_key              = "cluster__${this_id}__smtp__server";
		my $smtp__port_key                = "cluster__${this_id}__smtp__port";
		my $smtp__username_key            = "cluster__${this_id}__smtp__username";
		my $smtp__password_key            = "cluster__${this_id}__smtp__password";
		my $smtp__security_key            = "cluster__${this_id}__smtp__security";
		my $smtp__encrypt_pass_key        = "cluster__${this_id}__smtp__encrypt_pass";
		my $smtp__helo_domain_key         = "cluster__${this_id}__smtp__helo_domain";
		my $mail_data__to_key             = "cluster__${this_id}__mail_data__to";
		my $mail_data__sending_domain_key = "cluster__${this_id}__mail_data__sending_domain";
		
		$conf->{cgi}{$smtp__server_key}              = defined $conf->{cluster}{$this_id}{smtp}{server}              ? $conf->{cluster}{$this_id}{smtp}{server}              : "#!inherit!#";
		$conf->{cgi}{$smtp__port_key}                = defined $conf->{cluster}{$this_id}{smtp}{port}                ? $conf->{cluster}{$this_id}{smtp}{port}                : "#!inherit!#";
		$conf->{cgi}{$smtp__username_key}            = defined $conf->{cluster}{$this_id}{smtp}{username}            ? $conf->{cluster}{$this_id}{smtp}{username}            : "#!inherit!#";
		$conf->{cgi}{$smtp__password_key}            = defined $conf->{cluster}{$this_id}{smtp}{password}            ? $conf->{cluster}{$this_id}{smtp}{password}            : "#!inherit!#";
		$conf->{cgi}{$smtp__security_key}            = defined $conf->{cluster}{$this_id}{smtp}{security}            ? $conf->{cluster}{$this_id}{smtp}{security}            : "#!inherit!#";
		$conf->{cgi}{$smtp__encrypt_pass_key}        = defined $conf->{cluster}{$this_id}{smtp}{encrypt_pass}        ? $conf->{cluster}{$this_id}{smtp}{encrypt_pass}        : "#!inherit!#";
		$conf->{cgi}{$smtp__helo_domain_key}         = defined $conf->{cluster}{$this_id}{smtp}{helo_domain}         ? $conf->{cluster}{$this_id}{smtp}{helo_domain}         : "#!inherit!#";
		$conf->{cgi}{$mail_data__to_key}             = defined $conf->{cluster}{$this_id}{mail_data}{to}             ? $conf->{cluster}{$this_id}{mail_data}{to}             : "#!inherit!#";
		$conf->{cgi}{$mail_data__sending_domain_key} = defined $conf->{cluster}{$this_id}{mail_data}{sending_domain} ? $conf->{cluster}{$this_id}{mail_data}{sending_domain} : "#!inherit!#";
	}
	
	return(0);
}

# This prepares and displays the header section of an Anvil! configuration
# page.
sub show_anvil_config_header
{
	my ($conf) = @_;
	
	my $this_cluster          = $conf->{cgi}{anvil};
	my $say_this_cluster      = $this_cluster;
	my $this_id               = defined $conf->{clusters}{$this_cluster}{id}               ? $conf->{clusters}{$this_cluster}{id}               : "new";
	my $clear_icon            = AN::Common::template($conf, "common.html", "image_with_js", {
		image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_clear-fields_16x16.png",
		javascript	=>	"onclick=\"\$('#cluster__${this_id}__name, #cluster__${this_id}__description, #cluster__${this_id}__company, #cluster__${this_id}__ricci_pw, #cluster__${this_id}__root_pw, #cluster__${this_id}__url, #cluster__${this_id}__nodes_1_name, #cluster__${this_id}__nodes_1_ip, #cluster__${this_id}__nodes_1_port, #cluster__${this_id}__nodes_2_name, #cluster__${this_id}__nodes_2_ip, #cluster__${this_id}__nodes_2_port').val('')\"",
		alt_text	=>	"",
		id		=>	"clear",
	}, "", 1);
	my $this_name             = defined $conf->{clusters}{$this_cluster}{name}             ? $conf->{clusters}{$this_cluster}{name}             : "";
	my $this_company          = defined $conf->{clusters}{$this_cluster}{company}          ? $conf->{clusters}{$this_cluster}{company}          : "";
	   $this_company          = convert_text_to_html($conf, $this_company);
	my $this_description      = defined $conf->{clusters}{$this_cluster}{description}      ? $conf->{clusters}{$this_cluster}{description}      : "";
	   $this_description      = convert_text_to_html($conf, $this_description);
	my $this_url              = defined $conf->{clusters}{$this_cluster}{url}              ? $conf->{clusters}{$this_cluster}{url}              : "";
	my $this_ricci_pw         = defined $conf->{clusters}{$this_cluster}{ricci_pw}         ? $conf->{clusters}{$this_cluster}{ricci_pw}         : "";
	my $this_root_pw          = defined $conf->{clusters}{$this_cluster}{root_pw}          ? $conf->{clusters}{$this_cluster}{root_pw}          : "";
	my $this_nodes_1_name     = defined $conf->{clusters}{$this_cluster}{nodes}[0]         ? $conf->{clusters}{$this_cluster}{nodes}[0]         : "";
	my $this_nodes_1_ip       = defined $conf->{hosts}{$this_nodes_1_name}{ip}             ? $conf->{hosts}{$this_nodes_1_name}{ip}             : "";
	my $this_nodes_1_port     = defined $conf->{hosts}{$this_nodes_1_name}{port}           ? $conf->{hosts}{$this_nodes_1_name}{port}           : "";
	my $this_nodes_2_name     = defined $conf->{clusters}{$this_cluster}{nodes}[1]         ? $conf->{clusters}{$this_cluster}{nodes}[1]         : "";
	my $this_nodes_2_ip       = defined $conf->{hosts}{$this_nodes_2_name}{ip}             ? $conf->{hosts}{$this_nodes_2_name}{ip}             : "";
	my $this_nodes_2_port     = defined $conf->{hosts}{$this_nodes_2_name}{port}           ? $conf->{hosts}{$this_nodes_2_name}{port}           : "";
	my $this_node_1_ipmi_name = defined $conf->{clusters}{$this_cluster}{node_1_ipmi_name} ? $conf->{clusters}{$this_cluster}{node_1_ipmi_name} : "";
	my $this_node_1_ipmi_ip   = defined $conf->{hosts}{$this_node_1_ipmi_name}{ip}         ? $conf->{hosts}{$this_node_1_ipmi_name}{ip}         : "";
	my $this_node_2_ipmi_name = defined $conf->{clusters}{$this_cluster}{node_2_ipmi_name} ? $conf->{clusters}{$this_cluster}{node_2_ipmi_name} : "";
	my $this_node_2_ipmi_ip   = defined $conf->{hosts}{$this_node_2_ipmi_name}{ip}         ? $conf->{hosts}{$this_node_2_ipmi_name}{ip}         : "";
	
	# If this is the first time loading the config, pre-populate the values
	# for the overrides with the data from the config file.
	if (not $conf->{cgi}{save})
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
		$conf->{cgi}{$smtp__server_key}              = defined $conf->{cluster}{$this_id}{smtp}{server}              ? $conf->{cluster}{$this_id}{smtp}{server}              : "#!inherit!#";
		$conf->{cgi}{$smtp__port_key}                = defined $conf->{cluster}{$this_id}{smtp}{port}                ? $conf->{cluster}{$this_id}{smtp}{port}                : "#!inherit!#";
		$conf->{cgi}{$smtp__username_key}            = defined $conf->{cluster}{$this_id}{smtp}{username}            ? $conf->{cluster}{$this_id}{smtp}{username}            : "#!inherit!#";
		$conf->{cgi}{$smtp__password_key}            = defined $conf->{cluster}{$this_id}{smtp}{password}            ? $conf->{cluster}{$this_id}{smtp}{password}            : "#!inherit!#";
		$conf->{cgi}{$smtp__security_key}            = defined $conf->{cluster}{$this_id}{smtp}{security}            ? $conf->{cluster}{$this_id}{smtp}{security}            : "#!inherit!#";
		$conf->{cgi}{$smtp__encrypt_pass_key}        = defined $conf->{cluster}{$this_id}{smtp}{encrypt_pass}        ? $conf->{cluster}{$this_id}{smtp}{encrypt_pass}        : "#!inherit!#";
		$conf->{cgi}{$smtp__helo_domain_key}         = defined $conf->{cluster}{$this_id}{smtp}{helo_domain}         ? $conf->{cluster}{$this_id}{smtp}{helo_domain}         : "#!inherit!#";
		$conf->{cgi}{$mail_data__to_key}             = defined $conf->{cluster}{$this_id}{mail_data}{to}             ? $conf->{cluster}{$this_id}{mail_data}{to}             : "#!inherit!#";
		$conf->{cgi}{$mail_data__sending_domain_key} = defined $conf->{cluster}{$this_id}{mail_data}{sending_domain} ? $conf->{cluster}{$this_id}{mail_data}{sending_domain} : "#!inherit!#";
		record($conf, "$THIS_FILE ".__LINE__."; cgi::$smtp__server_key: [$conf->{cgi}{$smtp__server_key}], cgi::$smtp__port_key: [$conf->{cgi}{$smtp__port_key}], cgi::$smtp__username_key: [$conf->{cgi}{$smtp__username_key}], cgi::$smtp__password_key: [$conf->{cgi}{$smtp__password_key}], cgi::$smtp__security_key: [$conf->{cgi}{$smtp__security_key}], cgi::$smtp__encrypt_pass_key: [$conf->{cgi}{$smtp__encrypt_pass_key}], cgi::$smtp__helo_domain_key: [$conf->{cgi}{$smtp__helo_domain_key}], cgi::$mail_data__to_key: [$conf->{cgi}{$mail_data__to_key}], cgi::$mail_data__sending_domain_key: [$conf->{cgi}{$mail_data__sending_domain_key}]\n");
	}
	
	# Show the right header.
	if ($this_cluster eq "new")
	{
		# New Anvil! If the user is finishing an Install Manifest run,
		# some values will be set.
		$say_this_cluster  = $conf->{cgi}{cluster__new__name}         if $conf->{cgi}{cluster__new__name};
		$this_description  = $conf->{cgi}{cluster__new__description}  if $conf->{cgi}{cluster__new__description};
		$this_url          = $conf->{cgi}{cluster__new__url}          if $conf->{cgi}{cluster__new__url};
		$this_company      = $conf->{cgi}{cluster__new__company}      if $conf->{cgi}{cluster__new__company};
		$this_ricci_pw     = $conf->{cgi}{cluster__new__ricci_pw}     if $conf->{cgi}{cluster__new__ricci_pw};
		$this_root_pw      = $conf->{cgi}{cluster__new__root_pw}      if $conf->{cgi}{cluster__new__root_pw};
		$this_nodes_1_name = $conf->{cgi}{cluster__new__nodes_1_name} if $conf->{cgi}{cluster__new__nodes_1_name};
		$this_nodes_2_name = $conf->{cgi}{cluster__new__nodes_2_name} if $conf->{cgi}{cluster__new__nodes_2_name};
		$this_nodes_1_ip   = $conf->{cgi}{cluster__new__nodes_1_ip}   if $conf->{cgi}{cluster__new__nodes_1_ip};
		$this_nodes_2_ip   = $conf->{cgi}{cluster__new__nodes_2_ip}   if $conf->{cgi}{cluster__new__nodes_2_ip};
		$this_nodes_1_port = $conf->{cgi}{cluster__new__nodes_1_port} if $conf->{cgi}{cluster__new__nodes_1_port};
		$this_nodes_2_port = $conf->{cgi}{cluster__new__nodes_2_port} if $conf->{cgi}{cluster__new__nodes_2_port};
		$clear_icon        = "";
		print AN::Common::template($conf, "config.html", "config-header", {
			title_1	=>	"#!string!title_0003!#",
			title_2	=>	"#!string!title_0004!#",
		});
	}
	else
	{
		# Existing Anvil!
		print AN::Common::template($conf, "config.html", "config-header", {
			title_1	=>	"#!string!title_0005!#",
			title_2	=>	"#!string!title_0006!#",
		});
	}
	
	# Print the body of the global/overrides section.
	print AN::Common::template($conf, "config.html", "anvil-variables", {
		anvil_id			=>	$this_id,
		anvil				=>	$conf->{cgi}{anvil},
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
	}); 
	
	return(0);
}

# This shows the header of the global configuration section.
sub show_global_config_header
{
	my ($conf) = @_;
	
	print AN::Common::template($conf, "config.html", "config-header", {
		title_1	=>	"#!string!title_0011!#",
		title_2	=>	"#!string!title_0012!#",
	});

	return(0);
}

# This shows all the mail settings that are common to both the global and 
# per-anvil config sections.
sub show_common_config_section
{
	my ($conf) = @_;
	
	# We display the global values or the per-Anvil! ones below. Load the
	# global, the override with the Anvil! if needed.
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
	#record($conf, "$THIS_FILE ".__LINE__."; smtp__server_key: [$smtp__server_key], smtp__port_key: [$smtp__port_key], smtp__username_key: [$smtp__username_key], smtp__password_key: [$smtp__password_key], smtp__security_key: [$smtp__security_key], smtp__encrypt_pass_key: [$smtp__encrypt_pass_key], smtp__helo_domain_key: [$smtp__helo_domain_key], mail_data__to_key: [$mail_data__to_key], mail_data__sending_domain_key: [$mail_data__sending_domain_key]\n");
	if (not $conf->{cgi}{save})
	{
		# First time loading the config, so pre-populate the values
		# with the data from the config file.
		$conf->{cgi}{smtp__server}              = defined $conf->{smtp}{server}              ? $conf->{smtp}{server}              : ""; 
		$conf->{cgi}{smtp__port}                = defined $conf->{smtp}{port}                ? $conf->{smtp}{port}                : "";
		$conf->{cgi}{smtp__username}            = defined $conf->{smtp}{username}            ? $conf->{smtp}{username}            : "";
		$conf->{cgi}{smtp__password}            = defined $conf->{smtp}{password}            ? $conf->{smtp}{password}            : "";
		$conf->{cgi}{smtp__security}            = defined $conf->{smtp}{security}            ? $conf->{smtp}{security}            : "";
		$conf->{cgi}{smtp__encrypt_pass}        = defined $conf->{smtp}{encrypt_pass}        ? $conf->{smtp}{encrypt_pass}        : "";
		$conf->{cgi}{smtp__helo_domain}         = defined $conf->{smtp}{helo_domain}         ? $conf->{smtp}{helo_domain}         : "";
		$conf->{cgi}{mail_data__to}             = defined $conf->{mail_data}{to}             ? $conf->{mail_data}{to}             : "";
		$conf->{cgi}{mail_data__sending_domain} = defined $conf->{mail_data}{sending_domain} ? $conf->{mail_data}{sending_domain} : "";
		#record($conf, "$THIS_FILE ".__LINE__."; cgi::smtp__server: [$conf->{cgi}{smtp__server}], cgi::smtp__port: [$conf->{cgi}{smtp__port}], cgi::smtp__username: [$conf->{cgi}{smtp__username}], cgi::smtp__password: [$conf->{cgi}{smtp__password}], cgi::smtp__security: [$conf->{cgi}{smtp__security}], cgi::smtp__encrypt_pass: [$conf->{cgi}{smtp__encrypt_pass}], cgi::smtp__helo_domain: [$conf->{cgi}{smtp__helo_domain}], cgi::mail_data__to: [$conf->{cgi}{mail_data__to}], cgi::mail_data__sending_domain: [$conf->{cgi}{mail_data__sending_domain}]\n");
	}
	
	# Switch to the per-Anvil! values if an Anvil! is defined.
	my $this_cluster = "";
	my $this_id      = "";
	record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil: [$conf->{cgi}{anvil}]\n");
	if ($conf->{cgi}{anvil})
	{
		$this_cluster                  = $conf->{cgi}{anvil};
		$this_id                       = defined $conf->{clusters}{$this_cluster}{id} ? $conf->{clusters}{$this_cluster}{id} : "new";
		$smtp__server_key              = "cluster__${this_id}__smtp__server";
		$smtp__port_key                = "cluster__${this_id}__smtp__port";
		$smtp__username_key            = "cluster__${this_id}__smtp__username";
		$smtp__password_key            = "cluster__${this_id}__smtp__password";
		$smtp__security_key            = "cluster__${this_id}__smtp__security";
		$smtp__encrypt_pass_key        = "cluster__${this_id}__smtp__encrypt_pass";
		$smtp__helo_domain_key         = "cluster__${this_id}__smtp__helo_domain";
		$mail_data__to_key             = "cluster__${this_id}__mail_data__to";
		$mail_data__sending_domain_key = "cluster__${this_id}__mail_data__sending_domain";
		#record($conf, "$THIS_FILE ".__LINE__."; smtp__server_key: [$smtp__server_key], smtp__port_key: [$smtp__port_key], smtp__username_key: [$smtp__username_key], smtp__password_key: [$smtp__password_key], smtp__security_key: [$smtp__security_key], smtp__encrypt_pass_key: [$smtp__encrypt_pass_key], smtp__helo_domain_key: [$smtp__helo_domain_key], mail_data__to_key: [$mail_data__to_key], mail_data__sending_domain_key: [$mail_data__sending_domain_key]\n");
		
		# Add the 'inherit' options.
		push @{$security_select_options},     "#!inherit!#";
		push @{$encrypt_pass_select_options}, "#!inherit!#";
	}
	
	my $say_smtp__server              = $conf->{cgi}{$smtp__server_key}; 
	my $say_smtp__port                = $conf->{cgi}{$smtp__port_key};
	my $say_smtp__username            = $conf->{cgi}{$smtp__username_key};
	my $say_smtp__password            = $conf->{cgi}{$smtp__password_key};
	my $say_smtp__security            = $conf->{cgi}{$smtp__security_key};
	my $say_smtp__encrypt_pass        = $conf->{cgi}{$smtp__encrypt_pass_key};
	my $say_smtp__helo_domain         = $conf->{cgi}{$smtp__helo_domain_key};
	my $say_mail_data__to             = $conf->{cgi}{$mail_data__to_key};
	my $say_mail_data__sending_domain = $conf->{cgi}{$mail_data__sending_domain_key};
	#record($conf, "$THIS_FILE ".__LINE__."; say_smtp__server: [$say_smtp__server], say_smtp__port: [$say_smtp__port], say_smtp__username: [$say_smtp__username], say_smtp__password: [$say_smtp__password], say_smtp__security: [$say_smtp__security], say_smtp__encrypt_pass: [$say_smtp__encrypt_pass], say_smtp__helo_domain: [$say_smtp__helo_domain], say_mail_data__to: [$say_mail_data__to], say_mail_data__sending_domain: [$say_mail_data__sending_domain]\n");
	
	# Build the security and encrypt password select boxes.
	my $say_security_select     = build_select($conf, "$smtp__security_key",     0, 0, 300, $conf->{cgi}{$smtp__security_key},     $security_select_options);
	my $say_encrypt_pass_select = build_select($conf, "$smtp__encrypt_pass_key", 0, 0, 300, $conf->{cgi}{$smtp__encrypt_pass_key}, $encrypt_pass_select_options);
	$say_security_select     =~ s/<select name=/<select tabindex="18" name=/;
	$say_encrypt_pass_select =~ s/<select name=/<select tabindex="19" name=/;
	#record($conf, "$THIS_FILE ".__LINE__."; say_security_select: [$say_security_select]\n");
	#record($conf, "$THIS_FILE ".__LINE__."; say_encrypt_pass_select: [$say_encrypt_pass_select]\n");
	# If both nodes are up, enable the 'Push' button.
	my $push_button = "";
	if (($conf->{cgi}{anvil}) && ($conf->{cgi}{anvil} ne "new"))
	{
		$push_button =  "&nbsp; ";
		$push_button .= AN::Common::template($conf, "common.html", "enabled-button", {
			button_class	=>	"bold_button",
			button_link	=>	"?config=true&anvil=$conf->{cgi}{anvil}&task=push",
			button_text	=>	"#!string!button_0039!#",
			id		=>	"push",
		}, "", 1);
	}
	else
	{
		$push_button =  "&nbsp; ";
# 		$push_button .= AN::Common::template($conf, "common.html", "enabled-button", {
# 			button_class	=>	"bold_button",
# 			button_link	=>	"?config=true&task=archive",
# 			button_text	=>	"#!string!button_0040!#",
# 			id		=>	"archive",
# 		}, "", 1);
	}
	
	print AN::Common::template($conf, "config.html", "global-variables", {
		anvil_id			=>	$this_id,
		smtp__server_name		=>	$smtp__server_key,
		smtp__server_id			=>	$smtp__server_key,
		smtp__server_value		=>	$conf->{cgi}{$smtp__server_key},
		mail_data__sending_domain_name	=>	$mail_data__sending_domain_key,
		mail_data__sending_domain_id	=>	$mail_data__sending_domain_key,
		mail_data__sending_domain_value	=>	$conf->{cgi}{$mail_data__sending_domain_key},
		smtp__helo_domain_name		=>	$smtp__helo_domain_key,
		smtp__helo_domain_id		=>	$smtp__helo_domain_key,
		smtp__helo_domain_value		=>	$conf->{cgi}{$smtp__helo_domain_key},
		smtp__port_name			=>	$smtp__port_key,
		smtp__port_id			=>	$smtp__port_key,
		smtp__port_value		=>	$conf->{cgi}{$smtp__port_key},
		smtp__username_name		=>	$smtp__username_key,
		smtp__username_id		=>	$smtp__username_key,
		smtp__username_value		=>	$conf->{cgi}{$smtp__username_key},
		smtp__password_name		=>	$smtp__password_key,
		smtp__password_id		=>	$smtp__password_key,
		smtp__password_value		=>	$conf->{cgi}{$smtp__password_key},
		security_select			=>	$say_security_select,
		encrypt_pass_select		=>	$say_encrypt_pass_select,
		mail_data__to_name		=>	$mail_data__to_key,
		mail_data__to_id		=>	$mail_data__to_key,
		mail_data__to_value		=>	$conf->{cgi}{$mail_data__to_key},
		push_button			=>	$push_button,
	}); 
	
	return(0);
}

# This displays a list of all Anvil!s for the global configuration page.
sub show_global_anvil_list
{
	my ($conf) = @_;
	
	print AN::Common::template($conf, "config.html", "config-header", {
		title_1	=>	"#!string!title_0009!#",
		title_2	=>	"#!string!title_0010!#",
	});
	print AN::Common::template($conf, "config.html", "anvil-column-header");
	my $ids = "";
	foreach my $this_cluster ("new", (sort {$a cmp $b} keys %{$conf->{clusters}}))
	{
		#record($conf, "$THIS_FILE ".__LINE__."; this_cluster: [$this_cluster], clusters:${this_cluster}::name: [$conf->{clusters}{$this_cluster}{name}]\n");
		my $this_id           = defined $conf->{clusters}{$this_cluster}{id}          ? $conf->{clusters}{$this_cluster}{id}          : "new";
		my $this_company      = defined $conf->{clusters}{$this_cluster}{company}     ? $conf->{clusters}{$this_cluster}{company}     : "--";
		$this_company      = convert_text_to_html($conf, $this_company);
		my $this_description  = defined $conf->{clusters}{$this_cluster}{description} ? $conf->{clusters}{$this_cluster}{description} : "--";
		$this_description  = convert_text_to_html($conf, $this_description);
		my $this_url          = defined $conf->{clusters}{$this_cluster}{url}         ? $conf->{clusters}{$this_cluster}{url}         : "";
		if ($this_url)
		{
			my $image = AN::Common::template($conf, "common.html", "image", {
				image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/anvil-url_16x16.png",
				alt_text	=>	"",
				id		=>	"url_icon",
			}, "", 1);
			$this_url = AN::Common::template($conf, "common.html", "enabled-button-no-class-new-tab", {
				button_link	=>	"$this_url",
				button_text	=>	"$image",
				id		=>	"url_$this_cluster",
			}, "", 1);
		}
		
		print AN::Common::template($conf, "config.html", "anvil-column-entry", {
			anvil		=>	$this_cluster,
			company		=>	$this_company,
			description	=>	$this_description,
			url		=>	$this_url,
		});
	}

	print AN::Common::template($conf, "config.html", "anvil-column-footer");
	
	return(0);
}

# This checks to see if the Anvil! is online and, if both nodes are, pushes the
# config to the nods.
sub push_config_to_anvil
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; push_config_to_anvil()\n");
	
	my $anvil = $conf->{cgi}{anvil};
	record($conf, "$THIS_FILE ".__LINE__."; anvil: [$anvil]\n");
	
	# Make sure both nodes are up.
	$conf->{cgi}{cluster}       = $conf->{cgi}{anvil};
	$conf->{sys}{root_password} = $conf->{clusters}{$anvil}{root_pw};
	scan_cluster($conf);
	
	my $up = @{$conf->{up_nodes}};
	record($conf, "$THIS_FILE ".__LINE__."; online nodes: [$up]\n");
	if ($up == 0)
	{
		# Neither node is reachable or online.
		print AN::Common::template($conf, "config.html", "can-not-push-config-no-access");
	}
	elsif ($up == 1)
	{
		# Only one node online, don't update to prevent divergent
		# configs.
		print AN::Common::template($conf, "config.html", "can-not-push-config-only-one-node");
	}
	else
	{
		# Push!
		my $config_file = $conf->{path}{config_file};
		if (not -r $config_file)
		{
			die "Failed to read local: [$config_file]\n";
		}
		
		# We're going to want to backup each file before pushing the updates.
		my ($say_date) =  get_date($conf, time);
		record($conf, "$THIS_FILE ".__LINE__."; say_date: [$say_date]\n");
		my $date       =  $say_date;
		   $date       =~ s/ /_/g;
		   $date       =~ s/:/-/g;
		   $say_date   =~ s/ /, /g;
		record($conf, "$THIS_FILE ".__LINE__."; say_date: [$say_date], date: [$date]\n");
		
		print AN::Common::template($conf, "config.html", "open-push-table");
		foreach my $node (@{$conf->{up_nodes}})
		{
			my $message = AN::Common::get_string($conf, {key => "message_0280", variables => {
					node		=>	$node,
					source		=>	$config_file,
					destination	=>	"$config_file.$date",
				}});
			print AN::Common::template($conf, "config.html", "open-push-entry", {
				row	=>	"#!string!row_0130!#",
				message	=>	"$message",
			});
			
			# Make sure there is an '/etc/an' directory on the node
			# and create it, if not.
			my $striker_directory = ($conf->{path}{config_file} =~ /^(.*)\/.*$/)[0];
			record($conf, "$THIS_FILE ".__LINE__."; striker_directory: [$striker_directory]\n");
			my $shell_call        = "if [ ! -e '$striker_directory' ]; 
						then 
							mkdir -p $striker_directory;
							echo 'Create: [$striker_directory]';
						fi;
						ls $striker_directory";
			record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
			my ($error, $ssh_fh, $output) = remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				## This will show all the files in the directory, which isn't needed.
				## So instead we just look for the config file in the output and
				## report 'Found' if so.
				record($conf, "$THIS_FILE ".__LINE__."; conf: [$config_file]\n");
				record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($config_file =~ /$line$/)
				{
					$line = AN::Common::get_string($conf, {key => "message_0283"});
					print AN::Common::template($conf, "common.html", "shell-call-output", {
						line	=>	$line,
					});
				}
			}
			$error      = "";
			$output     = "";
			$shell_call = "";
			
			# Backup, but don't care if it fails.
			my $backup_file = "$config_file.$date";
			   $shell_call  = "if [ -e \"$config_file\" ]; 
					then 
						cp $config_file $backup_file; 
					fi; 
					ls $backup_file";
			record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
			($error, $ssh_fh, $output) = remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	$ssh_fh,
				'close'		=>	1,
				shell_call	=>	$shell_call,
			});
			record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				record($conf, "$THIS_FILE ".__LINE__."; backup: [$backup_file]\n");
				record($conf, "$THIS_FILE ".__LINE__."; line:   [$line]\n");
				if ($backup_file =~ /$line$/)
				{
					$line = AN::Common::get_string($conf, {key => "message_0284"});
				}
				if ($line =~ /No such file or directory/)
				{
					$line = AN::Common::get_string($conf, {key => "message_0285"});
				}
				print AN::Common::template($conf, "common.html", "shell-call-output", {
					line	=>	$line,
				});
			}
			print AN::Common::template($conf, "config.html", "close-push-entry");
			
			# See if I need to add the target node to the
			# dashboard's '~/.ssh/known_hosts' file.
			AN::Common::test_ssh_fingerprint($conf, $node);
			
			# Now push the actual config file.
			$message = AN::Common::get_string($conf, {key => "message_0281", variables => {
					node		=>	$node,
					config_file	=>	"$config_file",
				}});
			print AN::Common::template($conf, "config.html", "open-push-entry", {
				row	=>	"#!string!row_0131!#",
				message	=>	"$message",
			});
			$shell_call = "$conf->{path}{rsync} $conf->{args}{rsync} $config_file root\@$node:$config_file";
			# This is a dumb way to check, try a test upload and see if it fails.
			if ( -e "/usr/bin/expect" )
			{
				record($conf, "$THIS_FILE ".__LINE__."; Creating 'expect' rsync wrapper.");
				AN::Common::create_rsync_wrapper($conf, $node);
				$shell_call = "~/rsync.$node $conf->{args}{rsync} $config_file root\@$node:$config_file";
			}
			record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
			open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
			my $no_key = 0;
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				print AN::Common::template($conf, "common.html", "shell-call-output", {
					line	=>	$line,
				});
			}
			close $file_handle;
			print AN::Common::template($conf, "config.html", "close-push-entry");
		}
		print AN::Common::template($conf, "config.html", "close-table");
	}
	
	return(0);
}

# This offers an option for the user to either download the current config or
# upload a past backup.
sub show_archive_options
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; show_archive_options()\n");
	
	# First up, collect the config files and make them available for download.
	my $backup_url = create_backup_file($conf);
	
	print AN::Common::template($conf, "config.html", "archive-menu", {
		form_file	=>	"/cgi-bin/striker",
	});
	
	return(0);
}

# This gathers up the config files into a single bzip2 file and returns a URL
# where the user can click to download.
sub create_backup_file
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; create_backup_file()\n");
	
	my $config_data =  "<!-- Striker Backup -->\n";
	   $config_data .= "<!-- Striker version $conf->{sys}{version} -->\n";
	   $config_data .= "<!-- Backup created ".get_date($conf, time)." -->\n\n";
	
	# Get a list of install manifests on this machine.
	my @manifests;
	my $manifest_directory =  $conf->{path}{apache_manifests_dir};
	   $manifest_directory =~ s/\/$//g;
	record($conf, "$THIS_FILE ".__LINE__."; manifest_directory: [$manifest_directory]\n");
	local(*DIRECTORY);
	opendir(DIRECTORY, $manifest_directory);
	while(my $file = readdir(DIRECTORY))
	{
		record($conf, "$THIS_FILE ".__LINE__."; file: [$file]\n");
		if ($file =~ /^install-manifest_(.*?).xml$/)
		{
			my $full_path = "$manifest_directory/$file";
			push @manifests, $full_path;
			record($conf, "$THIS_FILE ".__LINE__."; full_path: [$full_path]\n");
		}
	}
	   
	# Read the three config files and write them out to a file.
	foreach my $file ($conf->{path}{config_file}, $conf->{path}{hosts}, $conf->{path}{ssh_config}, @manifests)
	{
		# Read in /etc/striker/striker.conf.
		record($conf, "$THIS_FILE ".__LINE__."; reading: [$file]\n");
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
	#record($conf, "$THIS_FILE ".__LINE__."; config_data: [\n$config_data]\n");

	# Modify the backup file and URL file names to insert this dashboard's hostname.
	my $date                    =  get_date($conf);
	   $date                    =~ s/ /_/;
	my $backup_file             =  "$conf->{path}{backup_config}";
	my $hostname                =  get_hostname($conf);
	   $backup_file             =~ s/#!hostname!#/$hostname/;
	   $backup_file             =~ s/#!date!#/$date/;
	   $conf->{sys}{backup_url} =~ s/#!hostname!#/$hostname/;
	   $conf->{sys}{backup_url} =~ s/#!date!#/$date/;
	
	# Now write out the file.
	my $shell_call = "$backup_file";
	record($conf, "$THIS_FILE ".__LINE__."; Writing: [$shell_call]\n");
	open (my $file_handle, ">", $shell_call) or die "Failed to write: [$shell_call], the error was: $!\n";
	print $file_handle $config_data;
	close $file_handle;
	
	return(0);
}

# This checks the user's uploaded file and, if it is a valid backup file, uses
# it's data to overwrite the existing config files.
sub load_backup_configuration
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; load_backup_configuration()\n");
	
	# This file handle will contain the uploaded file, so be careful.
	my $in_fh = $conf->{cgi_fh}{file};
	
	# Some variables.
	my $file         = "";
	my $striker_conf = "";
	my $hosts        = "";
	my $ssh_config   = "";
	my $valid        = 0;
	
	### NOTE: If this fails, we want to re-display the archive page.
	# If the file handle is empty, nothing was uploaded.
	record($conf, "$THIS_FILE ".__LINE__."; in_fh: [$in_fh], cgi_mimetype::file: [$conf->{cgi_mimetype}{file}]\n");
	if (not $in_fh)
	{
		print AN::Common::template($conf, "config.html", "no-backup-file-uploaded");
		show_archive_options($conf);
		return(1);
	}
	elsif ($conf->{cgi_mimetype}{file} ne "text/plain")
	{
		# The variable hash feeds 'explain_0039' and 'explain_0040'.
		print AN::Common::template($conf, "config.html", "backup-file-bad-mimetype", {}, {
				file		=>	$conf->{cgi}{file},
				mimetype	=>	$conf->{cgi_mimetype}{file},
			});
		show_archive_options($conf);
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
				# The variable hash feeds 'explain_0039'.
				print AN::Common::template($conf, "config.html", "invalid-backup-file-uploaded", {}, {
					file	=>	$conf->{cgi}{file},
				});
				show_archive_options($conf);
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
						$conf->{install_manifest}{$file}{config} = "";
					}
					next;
				}
				if ($file eq $conf->{path}{config_file})
				{
					$striker_conf .= "$line\n";
				}
				elsif ($file eq $conf->{path}{hosts})
				{
					$hosts .= "$line\n";
				}
				elsif ($file eq $conf->{path}{ssh_config})
				{
					$ssh_config .= "$line\n";
				}
				elsif ($file =~ /install-manifest/)
				{
					$conf->{install_manifest}{$file}{config} .= "$line\n";
				}
				elsif ($file)
				{
					# Unknown file...
					record($conf, "$THIS_FILE ".__LINE__."; Unknown file: [$file], line: [$line]\n");
				}
			}
		}
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; striker.conf contents: [\n$striker_conf]\n");
	#record($conf, "$THIS_FILE ".__LINE__."; hosts contents: [\n$hosts]\n");
	#record($conf, "$THIS_FILE ".__LINE__."; ssh_config contents: [\n$ssh_config]\n");
	if (($striker_conf) && ($hosts) && ($ssh_config))
	{
		### TODO: examine the contents of each file to ensure it looks sane.
		# Looks good, write them out.
		open (my $an_fh, ">", "$conf->{path}{config_file}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{config_file}], error: $!\n";
		print $an_fh $striker_conf;
		close $an_fh;
		
		open (my $hosts_fh, ">", "$conf->{path}{hosts}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{hosts}], error: $!\n";
		print $hosts_fh $hosts;
		close $hosts_fh;
		
		open (my $ssh_fh, ">", "$conf->{path}{ssh_config}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{ssh_config}], error: $!\n";
		print $ssh_fh $ssh_config;
		close $ssh_fh;
		
		# Load any manifests.
		foreach my $file (sort {$a cmp $b} keys %{$conf->{install_manifest}})
		{
			record($conf, "$THIS_FILE ".__LINE__."; writing manifest file: [$file]\n");
			open (my $manifest_fh, ">", "$file") or die "$THIS_FILE ".__LINE__."; Can't write to: [$file], error: $!\n";
			print $manifest_fh $conf->{install_manifest}{$file}{config};
			close $manifest_fh;
		}
		
		print AN::Common::template($conf, "config.html", "backup-file-loaded", {}, {
				file		=>	$conf->{cgi}{file},
			});
		footer($conf);
		exit;
	}
	
	return(0);
}

# This presents a form for the user to complete. When complete, an XML file
# with the install information for new nodes is created.
sub create_install_manifest
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; create_install_manifest();\n");
	
	my $show_form = 1;
	record($conf, "$THIS_FILE ".__LINE__."; cgi::do: [$conf->{cgi}{'do'}]\n");
	$conf->{form}{anvil_prefix_star}            = "";
	$conf->{form}{anvil_sequence_star}          = "";
	$conf->{form}{anvil_domain_star}            = "";
	$conf->{form}{anvil_name_star}              = "";
	$conf->{form}{anvil_password_star}          = "";
	$conf->{form}{anvil_bcn_network_star}       = "";
	$conf->{form}{anvil_sn_network_star}        = "";
	$conf->{form}{anvil_ifn_network_star}       = "";
	$conf->{form}{anvil_ifn_gateway_star}       = "";
	$conf->{form}{anvil_dns1_star}              = "";
	$conf->{form}{anvil_dns2_star}              = "";
	$conf->{form}{anvil_ntp1_star}              = "";
	$conf->{form}{anvil_ntp2_star}              = "";
	$conf->{form}{anvil_switch1_name_star}      = "";
	$conf->{form}{anvil_switch1_ip_star}        = "";
	$conf->{form}{anvil_switch2_name_star}      = "";
	$conf->{form}{anvil_switch2_ip_star}        = "";
	$conf->{form}{anvil_pdu1_name_star}         = "";
	$conf->{form}{anvil_pdu1_ip_star}           = "";
	$conf->{form}{anvil_pdu1_agent_star}        = "";
	$conf->{form}{anvil_pdu2_name_star}         = "";
	$conf->{form}{anvil_pdu2_ip_star}           = "";
	$conf->{form}{anvil_pdu2_agent_star}        = "";
	$conf->{form}{anvil_pdu3_name_star}         = "";
	$conf->{form}{anvil_pdu3_ip_star}           = "";
	$conf->{form}{anvil_pdu3_agent_star}        = "";
	$conf->{form}{anvil_pdu4_name_star}         = "";
	$conf->{form}{anvil_pdu4_ip_star}           = "";
	$conf->{form}{anvil_pdu4_agent_star}        = "";
	$conf->{form}{anvil_ups1_name_star}         = "";
	$conf->{form}{anvil_ups1_ip_star}           = "";
	$conf->{form}{anvil_ups2_name_star}         = "";
	$conf->{form}{anvil_ups2_ip_star}           = "";
	$conf->{form}{anvil_striker1_name_star}     = "";
	$conf->{form}{anvil_striker1_bcn_ip_star}   = "";
	$conf->{form}{anvil_striker1_ifn_ip_star}   = "";
	$conf->{form}{anvil_striker2_name_star}     = "";
	$conf->{form}{anvil_striker2_bcn_ip_star}   = "";
	$conf->{form}{anvil_striker2_ifn_ip_star}   = "";
	$conf->{form}{anvil_media_library_star}     = "";
	$conf->{form}{anvil_storage_pool1_star}     = "";
	$conf->{form}{anvil_repositories_star}      = "";
	$conf->{form}{anvil_node1_name_star}        = "";
	$conf->{form}{anvil_node1_bcn_ip_star}      = "";
	$conf->{form}{anvil_node1_ipmi_ip_star}     = "";
	$conf->{form}{anvil_node1_sn_ip_star}       = "";
	$conf->{form}{anvil_node1_ifn_ip_star}      = "";
	$conf->{form}{anvil_node1_pdu1_outlet_star} = "";
	$conf->{form}{anvil_node1_pdu2_outlet_star} = "";
	$conf->{form}{anvil_node1_pdu3_outlet_star} = "";
	$conf->{form}{anvil_node1_pdu4_outlet_star} = "";
	$conf->{form}{anvil_node2_name_star}        = "";
	$conf->{form}{anvil_node2_bcn_ip_star}      = "";
	$conf->{form}{anvil_node2_ipmi_ip_star}     = "";
	$conf->{form}{anvil_node2_sn_ip_star}       = "";
	$conf->{form}{anvil_node2_ifn_ip_star}      = "";
	$conf->{form}{anvil_node2_pdu1_outlet_star} = "";
	$conf->{form}{anvil_node2_pdu2_outlet_star} = "";
	$conf->{form}{anvil_node2_pdu3_outlet_star} = "";
	$conf->{form}{anvil_node2_pdu4_outlet_star} = "";
	$conf->{form}{anvil_open_vnc_ports}         = "";
	$conf->{form}{striker_user}                 = "";
	$conf->{form}{striker_database}             = "";
	$conf->{form}{anvil_striker1_user}          = "";
	$conf->{form}{anvil_striker1_password}      = "";
	$conf->{form}{anvil_striker1_database}      = "";
	$conf->{form}{anvil_striker2_user}          = "";
	$conf->{form}{anvil_striker2_password}      = "";
	$conf->{form}{anvil_striker2_database}      = "";
	$conf->{form}{anvil_mtu_size}               = "";
	
	if ($conf->{cgi}{'delete'})
	{
		if ($conf->{cgi}{confirm})
		{
			# Make sure that the file exists and that it is in the
			# manifests directory.
			my $file = $conf->{path}{apache_manifests_dir}."/".$conf->{cgi}{'delete'};
			if (-e $file)
			{
				# OK to proceed.
				unlink $file or die "Failed to delete: [$conf->{cgi}{'delete'}], error was: $!\n";
				my $message = AN::Common::get_string($conf, { key => "message_0349", variables => {
					file		=>	$file,
				}});
				print AN::Common::template($conf, "config.html", "delete-manifest-success", {
					message	=>	$message,
				});
			}
			else
			{
				# File is gone...
				my $message = AN::Common::get_string($conf, { key => "message_0348", variables => {
					file		=>	$conf->{cgi}{'delete'},
					manifest_dir	=>	$conf->{path}{apache_manifests_dir},
				}});
				print AN::Common::template($conf, "config.html", "delete-manifest-failure", {
					message	=>	$message,
				});
			}
		}
		else
		{
			$show_form = 0;
			my $message = AN::Common::get_string($conf, { key => "message_0347", variables => { file => $conf->{cgi}{'delete'} }});
			print AN::Common::template($conf, "config.html", "manifest-confirm-delete", {
				message	=>	$message,
				confirm	=>	"?config=true&task=create-install-manifest&delete=$conf->{cgi}{'delete'}&confirm=true",
			});
		}
	}
	if ($conf->{cgi}{generate})
	{
		# Sanity check the user's answers and, if OK, returns 0. Any
		# problem detected returns 1.
		if (not sanity_check_manifest_answers($conf))
		{
			# No errors, write out the manifest and create the
			# download link.
			if (not $conf->{cgi}{confirm})
			{
				$show_form = 0;
				show_summary_manifest($conf);
			}
			else
			{
				# The form will redisplay after this.
				my ($target_url, $xml_file) = generate_install_manifest($conf);
				print AN::Common::template($conf, "config.html", "manifest-created", {
					message	=>	AN::Common::get_string($conf, {
						key => "explain_0124", variables => {
							url	=>	"$target_url",
							file	=>	"$xml_file",
						}
					}),
				});
			}
		}
	}
	elsif ($conf->{cgi}{run})
	{
		# Read in the install manifest.
		load_install_manifest($conf, $conf->{cgi}{run});
		if ($conf->{cgi}{confirm})
		{
			# Do it.
			$show_form = 0;
			my ($return_code) = AN::InstallManifest::run_new_install_manifest($conf);
			# 0 == success
			# 1 == failed
			# 2 == failed, but don't show the error footer.
			if ($return_code eq "1")
			{
				# Something went wrong.
				my $button = AN::Common::template($conf, "common.html", "form-button", {
					class	=>	"bold_button", 
					name	=>	"confirm",
					id	=>	"confirm",
					value	=>	"#!string!button_0063!#",
				});
				my $message = AN::Common::get_string($conf, {
					key	=>	"message_0432", variables => {
						try_again_button	=>	$button,
					},
				});
				record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_bcn_link1_mac: [$conf->{cgi}{anvil_node1_bcn_link1_mac}], cgi::anvil_node1_bcn_link2_mac: [$conf->{cgi}{anvil_node1_bcn_link2_mac}]\n");
				record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_sn_link1_mac: [$conf->{cgi}{anvil_node1_sn_link1_mac}], cgi::anvil_node1_sn_link2_mac: [$conf->{cgi}{anvil_node1_sn_link2_mac}]\n");
				record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_ifn_link1_mac: [$conf->{cgi}{anvil_node1_ifn_link1_mac}], cgi::anvil_node1_ifn_link2_mac: [$conf->{cgi}{anvil_node1_ifn_link2_mac}]\n");
				record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_bcn_link1_mac: [$conf->{cgi}{anvil_node2_bcn_link1_mac}], cgi::anvil_node2_bcn_link2_mac: [$conf->{cgi}{anvil_node2_bcn_link2_mac}]\n");
				record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_sn_link1_mac: [$conf->{cgi}{anvil_node2_sn_link1_mac}], cgi::anvil_node2_sn_link2_mac: [$conf->{cgi}{anvil_node2_sn_link2_mac}]\n");
				record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_ifn_link1_mac: [$conf->{cgi}{anvil_node2_ifn_link1_mac}], cgi::anvil_node2_ifn_link2_mac: [$conf->{cgi}{anvil_node2_ifn_link2_mac}]\n");
				my $restart_html = AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed-footer", {
					form_file			=>	"/cgi-bin/striker",
					button_class			=>	"bold_button", 
					button_name			=>	"confirm",
					button_id			=>	"confirm",
					button_value			=>	"#!string!button_0063!#",
					message				=>	$message, 
					anvil_node1_current_ip		=>	$conf->{cgi}{anvil_node1_current_ip},
					anvil_node1_current_password	=>	$conf->{cgi}{anvil_node1_current_password},
					anvil_node2_current_ip		=>	$conf->{cgi}{anvil_node2_current_ip},
					anvil_node2_current_password	=>	$conf->{cgi}{anvil_node2_current_password},
					anvil_open_vnc_ports		=>	$conf->{cgi}{anvil_open_vnc_ports},
					run				=>	$conf->{cgi}{run},
					try_again_button		=>	$button,
					anvil_node1_bcn_link1_mac	=>	$conf->{cgi}{anvil_node1_bcn_link1_mac},
					anvil_node1_bcn_link2_mac	=>	$conf->{cgi}{anvil_node1_bcn_link2_mac},
					anvil_node1_ifn_link1_mac	=>	$conf->{cgi}{anvil_node1_ifn_link1_mac},
					anvil_node1_ifn_link2_mac	=>	$conf->{cgi}{anvil_node1_ifn_link2_mac},
					anvil_node1_sn_link1_mac	=>	$conf->{cgi}{anvil_node1_sn_link1_mac},
					anvil_node1_sn_link2_mac	=>	$conf->{cgi}{anvil_node1_sn_link2_mac},
					anvil_node2_bcn_link1_mac	=>	$conf->{cgi}{anvil_node2_bcn_link1_mac},
					anvil_node2_bcn_link2_mac	=>	$conf->{cgi}{anvil_node2_bcn_link2_mac},
					anvil_node2_ifn_link1_mac	=>	$conf->{cgi}{anvil_node2_ifn_link1_mac},
					anvil_node2_ifn_link2_mac	=>	$conf->{cgi}{anvil_node2_ifn_link2_mac},
					anvil_node2_sn_link1_mac	=>	$conf->{cgi}{anvil_node2_sn_link1_mac},
					anvil_node2_sn_link2_mac	=>	$conf->{cgi}{anvil_node2_sn_link2_mac},
					rhn_user			=>	$conf->{cgi}{rhn_user},
					rhn_password			=>	$conf->{cgi}{rhn_password},
				});
				record($conf, "$THIS_FILE ".__LINE__."; restart_html:\n======\n$restart_html\n======\n");
				print $restart_html;
			}
		}
		else
		{
			# Confirm
			$show_form = 0;
			confirm_install_manifest_run($conf);
		}
	}
	
	record($conf, "$THIS_FILE ".__LINE__."; show_form: [$show_form]\n");
	if ($show_form)
	{
		# Show the existing install manifest files.
		show_existing_install_manifests($conf);
		
		# Set some default values if 'save' isn't set.
		if ($conf->{cgi}{load})
		{
			load_install_manifest($conf, $conf->{cgi}{load});
		}
		elsif (not $conf->{cgi}{generate})
		{
			# This function uses sys::install_manifest::default::x if set.
			my ($default_prefix, $default_demain) = get_striker_prefix_and_domain($conf);
			
			# Primary Config values
			if (not $conf->{cgi}{anvil_prefix})             { $conf->{cgi}{anvil_prefix}             = $default_prefix; }
			if (not $conf->{cgi}{anvil_sequence})           { $conf->{cgi}{anvil_sequence}           = $conf->{sys}{install_manifest}{'default'}{sequence}; }
			if (not $conf->{cgi}{anvil_domain})             { $conf->{cgi}{anvil_domain}             = $default_demain; }
			if (not $conf->{cgi}{anvil_password})           { $conf->{cgi}{anvil_password}           = $conf->{sys}{install_manifest}{'default'}{password}; }
			if (not $conf->{cgi}{anvil_bcn_network})        { $conf->{cgi}{anvil_bcn_network}        = $conf->{sys}{install_manifest}{'default'}{bcn_network}; }
			if (not $conf->{cgi}{anvil_bcn_subnet})         { $conf->{cgi}{anvil_bcn_subnet}         = $conf->{sys}{install_manifest}{'default'}{bcn_subnet}; }
			if (not $conf->{cgi}{anvil_sn_network})         { $conf->{cgi}{anvil_sn_network}         = $conf->{sys}{install_manifest}{'default'}{sn_network}; }
			if (not $conf->{cgi}{anvil_sn_subnet})          { $conf->{cgi}{anvil_sn_subnet}          = $conf->{sys}{install_manifest}{'default'}{sn_subnet}; }
			if (not $conf->{cgi}{anvil_ifn_network})        { $conf->{cgi}{anvil_ifn_network}        = $conf->{sys}{install_manifest}{'default'}{ifn_network}; }
			if (not $conf->{cgi}{anvil_ifn_subnet})         { $conf->{cgi}{anvil_ifn_subnet}         = $conf->{sys}{install_manifest}{'default'}{ifn_subnet}; }
			if (not $conf->{cgi}{anvil_media_library_size}) { $conf->{cgi}{anvil_media_library_size} = $conf->{sys}{install_manifest}{'default'}{library_size}; }
			if (not $conf->{cgi}{anvil_media_library_unit}) { $conf->{cgi}{anvil_media_library_unit} = $conf->{sys}{install_manifest}{'default'}{library_unit}; }
			if (not $conf->{cgi}{anvil_storage_pool1_size}) { $conf->{cgi}{anvil_storage_pool1_size} = $conf->{sys}{install_manifest}{'default'}{pool1_size}; }
			if (not $conf->{cgi}{anvil_storage_pool1_unit}) { $conf->{cgi}{anvil_storage_pool1_unit} = $conf->{sys}{install_manifest}{'default'}{pool1_unit}; }
			if (not $conf->{cgi}{anvil_repositories})       { $conf->{cgi}{anvil_repositories}       = $conf->{sys}{install_manifest}{'default'}{repositories}; }
			
			# Hidden fields for now.
			if (not $conf->{cgi}{anvil_cluster_name})       { $conf->{cgi}{anvil_cluster_name}       = $conf->{sys}{install_manifest}{'default'}{cluster_name}; }
			if (not $conf->{cgi}{anvil_open_vnc_ports})     { $conf->{cgi}{anvil_open_vnc_ports}     = $conf->{sys}{install_manifest}{'default'}{open_vnc_ports}; }
			record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_mtu_size: [$conf->{cgi}{anvil_mtu_size}], sys::install_manifest::default::mtu: [$conf->{sys}{install_manifest}{'default'}{mtu}]\n");
			if (not $conf->{cgi}{anvil_mtu_size})           { $conf->{cgi}{anvil_mtu_size}           = $conf->{sys}{install_manifest}{'default'}{mtu}; }
			record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_mtu_size: [$conf->{cgi}{anvil_mtu_size}]\n");
			
			# It's possible for the user to set default values in
			# the install manifest.
			if (not $conf->{cgi}{anvil_name})               { $conf->{cgi}{anvil_name}               = $conf->{sys}{install_manifest}{'default'}{name}; }
			if (not $conf->{cgi}{anvil_ifn_gateway})        { $conf->{cgi}{anvil_ifn_gateway}        = $conf->{sys}{install_manifest}{'default'}{ifn_gateway}; }
			if (not $conf->{cgi}{anvil_dns1})               { $conf->{cgi}{anvil_dns1}               = $conf->{sys}{install_manifest}{'default'}{dns1}; }
			if (not $conf->{cgi}{anvil_dns2})               { $conf->{cgi}{anvil_dns2}               = $conf->{sys}{install_manifest}{'default'}{dns2}; }
			if (not $conf->{cgi}{anvil_ntp1})               { $conf->{cgi}{anvil_ntp1}               = $conf->{sys}{install_manifest}{'default'}{ntp1}; }
			if (not $conf->{cgi}{anvil_ntp2})               { $conf->{cgi}{anvil_ntp2}               = $conf->{sys}{install_manifest}{'default'}{ntp2}; }
			
			# Foundation Pack
			if (not $conf->{cgi}{anvil_switch1_name})       { $conf->{cgi}{anvil_switch1_name}       = $conf->{sys}{install_manifest}{'default'}{switch1_name}; }
			if (not $conf->{cgi}{anvil_switch1_ip})         { $conf->{cgi}{anvil_switch1_ip}         = $conf->{sys}{install_manifest}{'default'}{switch1_ip}; }
			if (not $conf->{cgi}{anvil_switch2_name})       { $conf->{cgi}{anvil_switch2_name}       = $conf->{sys}{install_manifest}{'default'}{switch2_name}; }
			if (not $conf->{cgi}{anvil_switch2_ip})         { $conf->{cgi}{anvil_switch2_ip}         = $conf->{sys}{install_manifest}{'default'}{switch2_ip}; }
			if (not $conf->{cgi}{anvil_ups1_name})          { $conf->{cgi}{anvil_ups1_name}          = $conf->{sys}{install_manifest}{'default'}{ups1_name}; }
			if (not $conf->{cgi}{anvil_ups1_ip})            { $conf->{cgi}{anvil_ups1_ip}            = $conf->{sys}{install_manifest}{'default'}{ups1_ip}; }
			if (not $conf->{cgi}{anvil_ups2_name})          { $conf->{cgi}{anvil_ups2_name}          = $conf->{sys}{install_manifest}{'default'}{ups2_name}; }
			if (not $conf->{cgi}{anvil_ups2_ip})            { $conf->{cgi}{anvil_ups2_ip}            = $conf->{sys}{install_manifest}{'default'}{ups2_ip}; }
			if (not $conf->{cgi}{anvil_pdu1_name})          { $conf->{cgi}{anvil_pdu1_name}          = $conf->{sys}{install_manifest}{'default'}{pdu1_name}; }
			if (not $conf->{cgi}{anvil_pdu1_ip})            { $conf->{cgi}{anvil_pdu1_ip}            = $conf->{sys}{install_manifest}{'default'}{pdu1_ip}; }
			if (not $conf->{cgi}{anvil_pdu2_name})          { $conf->{cgi}{anvil_pdu2_name}          = $conf->{sys}{install_manifest}{'default'}{pdu2_name}; }
			if (not $conf->{cgi}{anvil_pdu2_ip})            { $conf->{cgi}{anvil_pdu2_ip}            = $conf->{sys}{install_manifest}{'default'}{pdu2_ip}; }
			if (not $conf->{cgi}{anvil_pdu3_name})          { $conf->{cgi}{anvil_pdu3_name}          = $conf->{sys}{install_manifest}{'default'}{pdu3_name}; }
			if (not $conf->{cgi}{anvil_pdu3_ip})            { $conf->{cgi}{anvil_pdu3_ip}            = $conf->{sys}{install_manifest}{'default'}{pdu3_ip}; }
			if (not $conf->{cgi}{anvil_pdu4_name})          { $conf->{cgi}{anvil_pdu4_name}          = $conf->{sys}{install_manifest}{'default'}{pdu4_name}; }
			if (not $conf->{cgi}{anvil_pdu4_ip})            { $conf->{cgi}{anvil_pdu4_ip}            = $conf->{sys}{install_manifest}{'default'}{pdu4_ip}; }
			if (not $conf->{cgi}{anvil_striker1_name})      { $conf->{cgi}{anvil_striker1_name}      = $conf->{sys}{install_manifest}{'default'}{striker1_name}; }
			if (not $conf->{cgi}{anvil_striker1_bcn_ip})    { $conf->{cgi}{anvil_striker1_bcn_ip}    = $conf->{sys}{install_manifest}{'default'}{striker1_bcn_ip}; }
			if (not $conf->{cgi}{anvil_striker1_ifn_ip})    { $conf->{cgi}{anvil_striker1_ifn_ip}    = $conf->{sys}{install_manifest}{'default'}{striker1_ifn_ip}; }
			if (not $conf->{cgi}{anvil_striker2_name})      { $conf->{cgi}{anvil_striker2_name}      = $conf->{sys}{install_manifest}{'default'}{striker2_name}; }
			if (not $conf->{cgi}{anvil_striker2_bcn_ip})    { $conf->{cgi}{anvil_striker2_bcn_ip}    = $conf->{sys}{install_manifest}{'default'}{striker2_bcn_ip}; }
			if (not $conf->{cgi}{anvil_striker2_ifn_ip})    { $conf->{cgi}{anvil_striker2_ifn_ip}    = $conf->{sys}{install_manifest}{'default'}{striker2_ifn_ip}; }
			
			# Node 1 variables
			if (not $conf->{cgi}{anvil_node1_name})         { $conf->{cgi}{anvil_node1_name}         = $conf->{sys}{install_manifest}{'default'}{node1_name}; }
			if (not $conf->{cgi}{anvil_node1_bcn_ip})       { $conf->{cgi}{anvil_node1_bcn_ip}       = $conf->{sys}{install_manifest}{'default'}{node1_bcn_ip}; }
			if (not $conf->{cgi}{anvil_node1_ipmi_ip})      { $conf->{cgi}{anvil_node1_ipmi_ip}      = $conf->{sys}{install_manifest}{'default'}{node1_ipmi_ip}; }
			if (not $conf->{cgi}{anvil_node1_sn_ip})        { $conf->{cgi}{anvil_node1_sn_ip}        = $conf->{sys}{install_manifest}{'default'}{node1_sn_ip}; }
			if (not $conf->{cgi}{anvil_node1_ifn_ip})       { $conf->{cgi}{anvil_node1_ifn_ip}       = $conf->{sys}{install_manifest}{'default'}{node1_ifn_ip}; }
			if (not $conf->{cgi}{anvil_node1_pdu1_outlet})  { $conf->{cgi}{anvil_node1_pdu1_outlet}  = $conf->{sys}{install_manifest}{'default'}{node1_pdu1_outlet}; }
			if (not $conf->{cgi}{anvil_node1_pdu2_outlet})  { $conf->{cgi}{anvil_node1_pdu2_outlet}  = $conf->{sys}{install_manifest}{'default'}{node1_pdu2_outlet}; }
			if (not $conf->{cgi}{anvil_node1_pdu3_outlet})  { $conf->{cgi}{anvil_node1_pdu3_outlet}  = $conf->{sys}{install_manifest}{'default'}{node1_pdu3_outlet}; }
			if (not $conf->{cgi}{anvil_node2_pdu4_outlet})  { $conf->{cgi}{anvil_node2_pdu4_outlet}  = $conf->{sys}{install_manifest}{'default'}{node2_pdu4_outlet}; }
			
			# Node 2 variables
			if (not $conf->{cgi}{anvil_node2_name})         { $conf->{cgi}{anvil_node2_name}         = $conf->{sys}{install_manifest}{'default'}{node2_name}; }
			if (not $conf->{cgi}{anvil_node2_bcn_ip})       { $conf->{cgi}{anvil_node2_bcn_ip}       = $conf->{sys}{install_manifest}{'default'}{node2_bcn_ip}; }
			if (not $conf->{cgi}{anvil_node2_ipmi_ip})      { $conf->{cgi}{anvil_node2_ipmi_ip}      = $conf->{sys}{install_manifest}{'default'}{node2_ipmi_ip}; }
			if (not $conf->{cgi}{anvil_node2_sn_ip})        { $conf->{cgi}{anvil_node2_sn_ip}        = $conf->{sys}{install_manifest}{'default'}{node2_sn_ip}; }
			if (not $conf->{cgi}{anvil_node2_ifn_ip})       { $conf->{cgi}{anvil_node2_ifn_ip}       = $conf->{sys}{install_manifest}{'default'}{node2_ifn_ip}; }
			if (not $conf->{cgi}{anvil_node2_pdu1_outlet})  { $conf->{cgi}{anvil_node2_pdu1_outlet}  = $conf->{sys}{install_manifest}{'default'}{node2_pdu1_outlet}; }
			if (not $conf->{cgi}{anvil_node2_pdu2_outlet})  { $conf->{cgi}{anvil_node2_pdu2_outlet}  = $conf->{sys}{install_manifest}{'default'}{node2_pdu2_outlet}; }
			if (not $conf->{cgi}{anvil_node2_pdu3_outlet})  { $conf->{cgi}{anvil_node2_pdu3_outlet}  = $conf->{sys}{install_manifest}{'default'}{node2_pdu3_outlet}; }
			if (not $conf->{cgi}{anvil_node1_pdu4_outlet})  { $conf->{cgi}{anvil_node1_pdu4_outlet}  = $conf->{sys}{install_manifest}{'default'}{node1_pdu4_outlet}; }
		}
		
		# Print the header
		print AN::Common::template($conf, "config.html", "install-manifest-form-header", {
			form_file	=>	"/cgi-bin/striker",
		});
		
		# Anvil! prefix
		if (not $conf->{sys}{install_manifest}{show}{prefix_field})
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_prefix",
				id		=>	"anvil_prefix",
				value		=>	$conf->{cgi}{anvil_prefix},
			});
		}
		else
		{
			my $anvil_prefix_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0159!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0061!#" : "#!string!explain_0061!#",
				name		=>	"anvil_prefix",
				id		=>	"anvil_prefix",
				value		=>	$conf->{cgi}{anvil_prefix},
				star		=>	$conf->{form}{anvil_prefix_star},
				more_info	=>	"$anvil_prefix_more_info",
			});
		}
		
		# Anvil! sequence
		if (not $conf->{sys}{install_manifest}{show}{sequence_field})
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_sequence",
				id		=>	"anvil_sequence",
				value		=>	$conf->{cgi}{anvil_sequence},
			});
		}
		else
		{
			my $anvil_sequence_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0161!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0063!#" : "#!string!explain_0063!#",
				name		=>	"anvil_sequence",
				id		=>	"anvil_sequence",
				value		=>	$conf->{cgi}{anvil_sequence},
				star		=>	$conf->{form}{anvil_sequence_star},
				more_info	=>	"$anvil_sequence_more_info",
			});
		}
		
		# Anvil! domain name
		if (not $conf->{sys}{install_manifest}{show}{domain_field})
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_domain",
				id		=>	"anvil_domain",
				value		=>	$conf->{cgi}{anvil_domain},
			});
		}
		else
		{
			my $anvil_domain_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0160!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0062!#" : "#!string!explain_0062!#",
				name		=>	"anvil_domain",
				id		=>	"anvil_domain",
				value		=>	$conf->{cgi}{anvil_domain},
				star		=>	$conf->{form}{anvil_domain_star},
				more_info	=>	"$anvil_domain_more_info",
			});
		}
		
		# Anvil! password - Skip if set and hidden.
		if (($conf->{sys}{install_manifest}{'default'}{password}) && (not $conf->{sys}{install_manifest}{show}{password_field}))
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_password",
				id		=>	"anvil_password",
				value		=>	$conf->{cgi}{anvil_password},
			});
		}
		else
		{
			my $anvil_password_more_info = "";
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0194!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0110!#" : "#!string!explain_0110!#",
				name		=>	"anvil_password",
				id		=>	"anvil_password",
				value		=>	$conf->{cgi}{anvil_password},
				star		=>	$conf->{form}{anvil_password_star},
				more_info	=>	"$anvil_password_more_info",
			});
		}
		
		# Anvil! BCN Network definition
		if (($conf->{sys}{install_manifest}{'default'}{bcn_network}) && 
		    ($conf->{sys}{install_manifest}{'default'}{bcn_subnet}) && 
		    (not $conf->{sys}{install_manifest}{show}{bcn_network_fields}))
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_bcn_network",
				id		=>	"anvil_bcn_network",
				value		=>	$conf->{cgi}{anvil_bcn_network},
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_bcn_subnet",
				id		=>	"anvil_bcn_subnet",
				value		=>	$conf->{cgi}{anvil_bcn_subnet},
			});
		}
		else
		{
			my $anvil_bcn_network_more_info = "";
			print AN::Common::template($conf, "config.html", "install-manifest-form-subnet-entry", {
				row		=>	"#!string!row_0162!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0065!#" : "#!string!explain_0065!#",
				network_name	=>	"anvil_bcn_network",
				network_id	=>	"anvil_bcn_network",
				network_value	=>	$conf->{cgi}{anvil_bcn_network},
				subnet_name	=>	"anvil_bcn_subnet",
				subnet_id	=>	"anvil_bcn_subnet",
				subnet_value	=>	$conf->{cgi}{anvil_bcn_subnet},
				star		=>	$conf->{form}{anvil_bcn_network_star},
				more_info	=>	"$anvil_bcn_network_more_info",
			});
		}
		
		# Anvil! SN Network definition
		if (($conf->{sys}{install_manifest}{'default'}{sn_network}) && 
		    ($conf->{sys}{install_manifest}{'default'}{sn_subnet}) && 
		    (not $conf->{sys}{install_manifest}{show}{sn_network_fields}))
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_sn_network",
				id		=>	"anvil_sn_network",
				value		=>	$conf->{cgi}{anvil_sn_network},
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_sn_subnet",
				id		=>	"anvil_sn_subnet",
				value		=>	$conf->{cgi}{anvil_sn_subnet},
			});
		}
		else
		{
			my $anvil_sn_network_more_info = "";
			print AN::Common::template($conf, "config.html", "install-manifest-form-subnet-entry", {
				row		=>	"#!string!row_0163!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0066!#" : "#!string!explain_0066!#",
				network_name	=>	"anvil_sn_network",
				network_id	=>	"anvil_sn_network",
				network_value	=>	$conf->{cgi}{anvil_sn_network},
				subnet_name	=>	"anvil_sn_subnet",
				subnet_id	=>	"anvil_sn_subnet",
				subnet_value	=>	$conf->{cgi}{anvil_sn_subnet},
				star		=>	$conf->{form}{anvil_sn_network_star},
				more_info	=>	"$anvil_sn_network_more_info",
			});
		}
		
		# Anvil! IFN Network definition
		if (($conf->{sys}{install_manifest}{'default'}{ifn_network}) && 
		    ($conf->{sys}{install_manifest}{'default'}{ifn_subnet}) && 
		    (not $conf->{sys}{install_manifest}{show}{ifn_network_fields}))
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_ifn_network",
				id		=>	"anvil_ifn_network",
				value		=>	$conf->{cgi}{anvil_ifn_network},
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_ifn_subnet",
				id		=>	"anvil_ifn_subnet",
				value		=>	$conf->{cgi}{anvil_ifn_subnet},
			});
		}
		else
		{
			my $anvil_ifn_network_more_info = "";
			print AN::Common::template($conf, "config.html", "install-manifest-form-subnet-entry", {
				row		=>	"#!string!row_0164!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0067!#" : "#!string!explain_0067!#",
				network_name	=>	"anvil_ifn_network",
				network_id	=>	"anvil_ifn_network",
				network_value	=>	$conf->{cgi}{anvil_ifn_network},
				subnet_name	=>	"anvil_ifn_subnet",
				subnet_id	=>	"anvil_ifn_subnet",
				subnet_value	=>	$conf->{cgi}{anvil_ifn_subnet},
				star		=>	$conf->{form}{anvil_ifn_network_star},
				more_info	=>	"$anvil_ifn_network_more_info",
			});
		}
		
		# Anvil! Media Library size
		if (($conf->{sys}{install_manifest}{'default'}{library_size}) && 
		    ($conf->{sys}{install_manifest}{'default'}{library_unit}) && 
		    (not $conf->{sys}{install_manifest}{show}{library_fields}))
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_media_library_size",
				id		=>	"anvil_media_library_size",
				value		=>	$conf->{cgi}{anvil_media_library_size},
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_media_library_unit",
				id		=>	"anvil_media_library_unit",
				value		=>	$conf->{cgi}{anvil_media_library_unit},
			});
		}
		else
		{
			my $anvil_media_library_more_info = "";
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-and-select-entry", {
				row		=>	"#!string!row_0191!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0114!#" : "#!string!explain_0114!#",
				name		=>	"anvil_media_library_size",
				id		=>	"anvil_media_library_size",
				value		=>	$conf->{cgi}{anvil_media_library_size},
				'select'	=>	build_select($conf, "anvil_media_library_unit", 0, 0, 60, $conf->{cgi}{anvil_media_library_unit}, ["GiB", "TiB"]),
				star		=>	$conf->{form}{anvil_media_library_star},
				more_info	=>	"$anvil_media_library_more_info",
			});
		}
		
		# Anvil! Storage Pools
		if (($conf->{sys}{install_manifest}{'default'}{pool1_size}) && 
		    ($conf->{sys}{install_manifest}{'default'}{pool1_unit}) && 
		    (not $conf->{sys}{install_manifest}{show}{pool1_fields}))
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_storage_pool1_size",
				id		=>	"anvil_storage_pool1_size",
				value		=>	$conf->{cgi}{anvil_storage_pool1_size},
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_storage_pool1_unit",
				id		=>	"anvil_storage_pool1_unit",
				value		=>	$conf->{cgi}{anvil_storage_pool1_unit},
			});
		}
		else
		{
			my $anvil_storage_pool1_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-and-select-entry", {
				row		=>	"#!string!row_0199!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0115!#" : "#!string!explain_0115!#",
				name		=>	"anvil_storage_pool1_size",
				id		=>	"anvil_storage_pool1_size",
				value		=>	$conf->{cgi}{anvil_storage_pool1_size},
				'select'	=>	build_select($conf, "anvil_storage_pool1_unit", 0, 0, 60, $conf->{cgi}{anvil_storage_pool1_unit}, ["%", "GiB", "TiB"]),
				star		=>	$conf->{form}{anvil_storage_pool1_star},
				more_info	=>	"$anvil_storage_pool1_more_info",
			});
		}
		
		# Anvil! extra repos
		if (not $conf->{sys}{install_manifest}{show}{repository_field})
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_repositories",
				id		=>	"anvil_repositories",
				value		=>	$conf->{cgi}{anvil_repositories},
			});
		}
		else
		{
			my $anvil_repositories_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"https://en.wikipedia.org/wiki/RPM_Package_Manager#Repositories",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0244!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0139!#" : "#!string!explain_0139!#",
				name		=>	"anvil_repositories",
				id		=>	"anvil_repositories",
				value		=>	$conf->{cgi}{anvil_repositories},
				star		=>	$conf->{form}{anvil_repositories_star},
				more_info	=>	"$anvil_repositories_more_info",
			});
		}
		
		# Button to pre-populate the rest of the form.
		print AN::Common::template($conf, "config.html", "install-manifest-form-spacer");
		print AN::Common::template($conf, "config.html", "install-manifest-form-set-values");
		print AN::Common::template($conf, "config.html", "install-manifest-form-spacer");
		
		# The header for the "Secondary" section (all things below
		# *should* populate properly for most users)
		print AN::Common::template($conf, "config.html", "install-manifest-form-secondary-header");
		print AN::Common::template($conf, "config.html", "install-manifest-form-spacer");
		
		# Now show the header for the Common section.
		print AN::Common::template($conf, "config.html", "install-manifest-form-common-header");
		
		# Anvil! (cman cluster) Name
		if (($conf->{sys}{install_manifest}{'default'}{name}) && 
		    (not $conf->{sys}{install_manifest}{show}{name_field}))
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_name",
				id		=>	"anvil_name",
				value		=>	$conf->{cgi}{anvil_name},
			});
		}
		else
		{
			my $anvil_name_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#The_First_cluster.conf_Foundation_Configuration",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0005!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0095!#" : "#!string!explain_0095!#",
				name		=>	"anvil_name",
				id		=>	"anvil_name",
				value		=>	$conf->{cgi}{anvil_name},
				star		=>	$conf->{form}{anvil_name_star},
				more_info	=>	"$anvil_name_more_info",
			});
		}
		# The "anvil_name" is stored as a hidden field.
		print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
			name		=>	"anvil_cluster_name",
			id		=>	"anvil_cluster_name",
			value		=>	$conf->{cgi}{anvil_cluster_name},
		});
		
		# The "mtu" is stored as a hidden field.
		print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
			name		=>	"anvil_mtu_size",
			id		=>	"anvil_mtu_size",
			value		=>	$conf->{cgi}{anvil_mtu_size},
		});
		
		# Anvil! IFN Gateway
		if (not $conf->{sys}{install_manifest}{show}{ifn_network_fields})
		{
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_ifn_gateway",
				id		=>	"anvil_ifn_gateway",
				value		=>	$conf->{cgi}{anvil_ifn_gateway},
			});
		}
		else
		{
			my $anvil_ifn_gateway_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0188!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0092!#" : "#!string!explain_0092!#",
				name		=>	"anvil_ifn_gateway",
				id		=>	"anvil_ifn_gateway",
				value		=>	$conf->{cgi}{anvil_ifn_gateway},
				star		=>	$conf->{form}{anvil_ifn_gateway_star},
				more_info	=>	"$anvil_ifn_gateway_more_info",
			});
		}
		
		# DNS
		if (not $conf->{sys}{install_manifest}{show}{dns_fields})
		{
			# Anvil! Primary DNS
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_dns1",
				id		=>	"anvil_dns1",
				value		=>	$conf->{cgi}{anvil_dns1},
			});
			
			# Anvil! Secondary DNS
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_dns2",
				id		=>	"anvil_dns2",
				value		=>	$conf->{cgi}{anvil_dns2},
			});
		}
		else
		{
			# Anvil! Primary DNS
			my $anvil_dns1_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"http://en.wikipedia.org/wiki/Domain_Name_System",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0189!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0093!#" : "#!string!explain_0093!#",
				name		=>	"anvil_dns1",
				id		=>	"anvil_dns1",
				value		=>	$conf->{cgi}{anvil_dns1},
				star		=>	$conf->{form}{anvil_dns1_star},
				more_info	=>	"$anvil_dns1_more_info",
			});
			
			# Anvil! Secondary DNS
			my $anvil_dns2_more_info = "";
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0190!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0094!#" : "#!string!explain_0094!#",
				name		=>	"anvil_dns2",
				id		=>	"anvil_dns2",
				value		=>	$conf->{cgi}{anvil_dns2},
				star		=>	$conf->{form}{anvil_dns2_star},
				more_info	=>	"$anvil_dns2_more_info",
			});
		}
		
		# NTP
		if (not $conf->{sys}{install_manifest}{show}{ntp_fields})
		{
			# Anvil! Primary NTP
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_ntp1",
				id		=>	"anvil_ntp1",
				value		=>	$conf->{cgi}{anvil_ntp1},
			});
			
			# Anvil! Secondary NTP
			print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
				name		=>	"anvil_ntp2",
				id		=>	"anvil_ntp2",
				value		=>	$conf->{cgi}{anvil_ntp2},
			});
		}
		else
		{
			# Anvil! Primary NTP
			my $anvil_ntp1_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
				url	=>	"https://en.wikipedia.org/wiki/Network_Time_Protocol",
			});
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0192!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0097!#" : "#!string!explain_0097!#",
				name		=>	"anvil_ntp1",
				id		=>	"anvil_ntp1",
				value		=>	$conf->{cgi}{anvil_ntp1},
				star		=>	$conf->{form}{anvil_ntp1_star},
				more_info	=>	"$anvil_ntp1_more_info",
			});
			
			# Anvil! Secondary NTP
			my $anvil_ntp2_more_info = "";
			print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
				row		=>	"#!string!row_0193!#",
				explain		=>	$conf->{sys}{expert_ui} ? "#!string!terse_0098!#" : "#!string!explain_0098!#",
				name		=>	"anvil_ntp2",
				id		=>	"anvil_ntp2",
				value		=>	$conf->{cgi}{anvil_ntp2},
				star		=>	$conf->{form}{anvil_ntp2_star},
				more_info	=>	"$anvil_ntp2_more_info",
			});
		}
		
		# Now show the header for the Foundation pack section.
		print AN::Common::template($conf, "config.html", "install-manifest-form-foundation-pack-header");
		
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
				$say_name_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0082!#" : "#!string!explain_0082!#";
				$say_name_url     = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_ip_row       = "#!string!row_0179!#";
				$say_ip_explain   = $conf->{sys}{expert_ui} ? "#!string!terse_0083!#" : "#!string!explain_0083!#";
				$say_ip_url       = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Network_Switches";
			}
			elsif ($i == 2)
			{
				$say_name_row     = "#!string!row_0180!#";
				$say_name_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0084!#" : "#!string!explain_0084!#";
				$say_name_url     = "";
				$say_ip_row       = "#!string!row_0181!#";
				$say_ip_explain   = $conf->{sys}{expert_ui} ? "#!string!terse_0085!#" : "#!string!explain_0085!#";
				$say_ip_url       = "";
			}
			
			# Switches
			if (not $conf->{sys}{install_manifest}{show}{switch_fields})
			{
				# Switch name
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$conf->{cgi}{$name_key},
				});
				
				# Switch IP
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$conf->{cgi}{$ip_key},
				});
			}
			else
			{
				# Switch name
				my $network_switch_name_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_name_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_name_row",
					explain		=>	"$say_name_explain",
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$conf->{cgi}{$name_key},
					star		=>	$conf->{form}{$name_star_key},
					more_info	=>	"$network_switch_name_more_info",
				});
				
				# Switch IP
				my $network_switch_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_ip_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_ip_row",
					explain		=>	"$say_ip_explain",
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$conf->{cgi}{$ip_key},
					star		=>	$conf->{form}{$ip_star_key},
					more_info	=>	"$network_switch_ip_more_info",
				});
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
				$say_name_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0074!#" : "#!string!explain_0074!#";
				$say_name_url     = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_ip_row       = "#!string!row_0171!#";
				$say_ip_explain   = $conf->{sys}{expert_ui} ? "#!string!terse_0075!#" : "#!string!explain_0075!#";
				$say_ip_url       = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Network_Managed_UPSes_Are_Worth_It";
			}
			elsif ($i == 2)
			{
				$say_name_row     = "#!string!row_0172!#";
				$say_name_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0076!#" : "#!string!explain_0076!#";
				$say_name_url     = "";
				$say_ip_row       = "#!string!row_0173!#";
				$say_ip_explain   = $conf->{sys}{expert_ui} ? "#!string!terse_0077!#" : "#!string!explain_0077!#";
				$say_ip_url       = "";
			}
			
			# UPSes
			if (not $conf->{sys}{install_manifest}{show}{ups_fields})
			{
				# UPS name
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$conf->{cgi}{$name_key},
				});
				
				# UPS IP
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$conf->{cgi}{$ip_key},
				});
			}
			else
			{
				# UPS name
				my $network_ups_name_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_name_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_name_row",
					explain		=>	"$say_name_explain",
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$conf->{cgi}{$name_key},
					star		=>	$conf->{form}{$name_star_key},
					more_info	=>	"$network_ups_name_more_info",
				});
				
				# UPS IP
				my $network_ups_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_ip_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_ip_row",
					explain		=>	"$say_ip_explain",
					name		=>	"$ip_key",
					id		=>	"$ip_key",
					value		=>	$conf->{cgi}{$ip_key},
					star		=>	$conf->{form}{$ip_star_key},
					more_info	=>	"$network_ups_ip_more_info",
				});
			}
		}
		
		# Ask the user which model of PDU they're using.
		my $say_apc     = AN::Common::get_string($conf, {key => "brand_0017"});
		my $say_raritan = AN::Common::get_string($conf, {key => "brand_0018"});
		
		# Build the two or four PDU form entries.
		foreach my $i (1..$conf->{sys}{install_manifest}{pdu_count})
		{
			next if ($i > $conf->{sys}{install_manifest}{pdu_count});
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
			$conf->{cgi}{$pdu_agent_key} = $conf->{sys}{install_manifest}{pdu_agent} if not $conf->{cgi}{$pdu_agent_key};
			
			# Build the select.
			my $pdu_list  = ["fence_apc_snmp#!#$say_apc", "fence_raritan_snmp#!#$say_raritan"];
			my $pdu_model = build_select($conf, "$pdu_agent_key", 0, 0, 220, $conf->{cgi}{$pdu_agent_key}, $pdu_list);
			
			if ($i == 1)
			{
				$say_pdu           = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#"  : "#!string!device_0007!#";
				$say_name_explain  = $conf->{sys}{expert_ui} ? "#!string!terse_0078!#" : "#!string!explain_0078!#";
				$say_name_url      = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_ip_explain    = $conf->{sys}{expert_ui} ? "#!string!terse_0079!#" : "#!string!explain_0079!#";
				$say_ip_url        = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Why_Switched_PDUs.3F";
				$say_agent_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0150!#" : "#!string!explain_0150!#";
			}
			elsif ($i == 2)
			{
				$say_pdu           = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#";
				$say_name_explain  = $conf->{sys}{expert_ui} ? "#!string!terse_0080!#" : "#!string!explain_0080!#";
				$say_ip_explain    = $conf->{sys}{expert_ui} ? "#!string!terse_0081!#" : "#!string!explain_0081!#";
				$say_agent_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0151!#" : "#!string!explain_0151!#";
			}
			elsif ($i == 3)
			{
				$say_pdu           = "#!string!device_0009!#";
				$say_name_explain  = $conf->{sys}{expert_ui} ? "#!string!terse_0146!#" : "#!string!explain_0146!#";
				$say_ip_explain    = $conf->{sys}{expert_ui} ? "#!string!terse_0147!#" : "#!string!explain_0147!#";
				$say_agent_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0152!#" : "#!string!explain_0152!#";
			}
			elsif ($i == 4)
			{
				$say_pdu           = "#!string!device_0010!#";
				$say_name_explain  = $conf->{sys}{expert_ui} ? "#!string!terse_0148!#" : "#!string!explain_0148!#";
				$say_ip_explain    = $conf->{sys}{expert_ui} ? "#!string!terse_0149!#" : "#!string!explain_0149!#";
				$say_agent_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0153!#" : "#!string!explain_0153!#";
			}
			my $say_pdu_name  = AN::Common::get_string($conf, {key => "row_0174", variables => { 
						say_pdu	=>	"$say_pdu",
					}});
			my $say_pdu_ip    = AN::Common::get_string($conf, {key => "row_0175", variables => { 
						say_pdu	=>	"$say_pdu",
					}});
			my $say_pdu_agent = AN::Common::get_string($conf, {key => "row_0177", variables => { 
						say_pdu	=>	"$say_pdu",
					}});
			
			# PDUs
			my $default_pdu_name_key = "pdu${i}_name";
			my $default_pdu_ip_key   = "pdu${i}_ip";
			if (($conf->{sys}{install_manifest}{'default'}{$default_pdu_name_key}) && 
			    ($conf->{sys}{install_manifest}{'default'}{$default_pdu_ip_key}) && 
			    (not $conf->{sys}{install_manifest}{show}{pdu_fields}))
			{
				# PDU name
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$pdu_name_key",
					id		=>	"$pdu_name_key",
					value		=>	$conf->{cgi}{$pdu_name_key},
				});
				
				# PDU IP
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$pdu_ip_key",
					id		=>	"$pdu_ip_key",
					value		=>	$conf->{cgi}{$pdu_ip_key},
				});
				
				# PDU Brand
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$pdu_agent_key",
					id		=>	"$pdu_agent_key",
					value		=>	$conf->{cgi}{$pdu_agent_key},
				});
			}
			else
			{
				# PDU Name
				my $pdu_name_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_name_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_pdu_name",
					explain		=>	"$say_name_explain",
					name		=>	"$pdu_name_key",
					id		=>	"$pdu_name_key",
					value		=>	$conf->{cgi}{$pdu_name_key},
					star		=>	$conf->{form}{$pdu_star_name_key},
					more_info	=>	"$pdu_name_more_info",
				});
				
				# PDU IP
				my $pdu_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_ip_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_pdu_ip",
					explain		=>	"$say_ip_explain",
					name		=>	"$pdu_ip_key",
					id		=>	"$pdu_ip_key",
					value		=>	$conf->{cgi}{$pdu_ip_key},
					star		=>	$conf->{form}{$pdu_star_ip_key},
					more_info	=>	"$pdu_ip_more_info",
				});
				
				# PDU Brand
				my $pdu_agent_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_agent_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-select-entry", {
					row		=>	"$say_pdu_agent",
					explain		=>	"$say_agent_explain",
					'select'	=>	$pdu_model,
					star		=>	$conf->{form}{$pdu_star_agent_key},
					more_info	=>	"$pdu_agent_more_info",
				});
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
				$say_name_explain   = $conf->{sys}{expert_ui} ? "#!string!terse_0086!#" : "#!string!explain_0086!#";
				$say_name_url       = "https://alteeve.ca/w/AN!Cluster_Tutorial_2#Foundation_Pack_Host_Names";
				$say_bcn_ip_row     = "#!string!row_0183!#";
				$say_bcn_ip_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0087!#" : "#!string!explain_0087!#";
				$say_bcn_ip_url     = "https://alteeve.ca/w/Striker";
				$say_ifn_ip_row     = "#!string!row_0184!#";
				$say_ifn_ip_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0088!#" : "#!string!explain_0088!#";
				$say_ifn_ip_url     = "https://alteeve.ca/w/Striker";
			}
			elsif ($i == 2)
			{
				$say_name_row       = "#!string!row_0185!#";
				$say_name_explain   = $conf->{sys}{expert_ui} ? "#!string!terse_0089!#" : "#!string!explain_0089!#";
				$say_name_url       = "";
				$say_bcn_ip_row     = "#!string!row_0186!#";
				$say_bcn_ip_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0090!#" : "#!string!explain_0090!#";
				$say_bcn_ip_url     = "";
				$say_ifn_ip_row     = "#!string!row_0187!#";
				$say_ifn_ip_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0091!#" : "#!string!explain_0091!#";
				$say_ifn_ip_url     = "";
			}
			
			# Dashboards
			if (not $conf->{sys}{install_manifest}{show}{dashboard_fields})
			{
				# Striker name
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$conf->{cgi}{$name_key},
				});
				
				# Striker BCN IP
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$bcn_ip_key",
					id		=>	"$bcn_ip_key",
					value		=>	$conf->{cgi}{$bcn_ip_key},
				});
				
				# Striker IFN IP
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	"$ifn_ip_key",
					id		=>	"$ifn_ip_key",
					value		=>	$conf->{cgi}{$ifn_ip_key},
				});
			}
			else
			{
				# Striker name
				my $striker_name_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_name_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_name_row",
					explain		=>	"$say_name_explain",
					name		=>	"$name_key",
					id		=>	"$name_key",
					value		=>	$conf->{cgi}{$name_key},
					star		=>	$conf->{form}{$name_star_key},
					more_info	=>	"$striker_name_more_info",
				});
				
				# Striker BCN IP
				my $striker_bcn_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_bcn_ip_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_bcn_ip_row",
					explain		=>	"$say_bcn_ip_explain",
					name		=>	"$bcn_ip_key",
					id		=>	"$bcn_ip_key",
					value		=>	$conf->{cgi}{$bcn_ip_key},
					star		=>	$conf->{form}{$bcn_ip_star_key},
					more_info	=>	"$striker_bcn_ip_more_info",
				});
				
				# Striker IFN IP
				my $striker_ifn_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"$say_ifn_ip_url",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"$say_ifn_ip_row",
					explain		=>	"$say_ifn_ip_explain",
					name		=>	"$ifn_ip_key",
					id		=>	"$ifn_ip_key",
					value		=>	$conf->{cgi}{$ifn_ip_key},
					star		=>	$conf->{form}{$ifn_ip_star_key},
					more_info	=>	"$striker_ifn_ip_more_info",
				});
			}
		}
		
		# Spacer
		print AN::Common::template($conf, "config.html", "install-manifest-form-spacer");
		
		### Nodes are a little more complicated, too, as we might have
		### two or four PDUs that each node might be plugged into.
		foreach my $j (1, 2)
		{
			# Print the node header
			my $title = AN::Common::get_string($conf, { key => "title_0152", variables => {
				node_number	=>	$j,
			}});
			print AN::Common::template($conf, "config.html", "install-manifest-form-nodes-header", {
				title	=>	$title,
			});
			
			my $name_key        = "anvil_node${j}_name";
			my $explain_name    = "";
			my $explain_bcn_ip  = $conf->{sys}{expert_ui} ? "#!string!terse_0070!#" : "#!string!explain_0070!#";
			my $explain_ipmi_ip = $conf->{sys}{expert_ui} ? "#!string!terse_0073!#" : "#!string!explain_0073!#";
			my $explain_sn_ip   = $conf->{sys}{expert_ui} ? "#!string!terse_0071!#" : "#!string!explain_0071!#";
			my $explain_ifn_ip  = $conf->{sys}{expert_ui} ? "#!string!terse_0072!#" : "#!string!explain_0072!#";
			if ($j == 1)
			{
				$explain_name    = $conf->{sys}{expert_ui} ? "#!string!terse_0068!#" : "#!string!explain_0068!#";
			}
			elsif ($j == 2)
			{
				$explain_name    = $conf->{sys}{expert_ui} ? "#!string!terse_0069!#" : "#!string!explain_0069!#";
			}
			
			# Node's hostname
			my $anvil_node_name_key      = "anvil_node${j}_name";
			my $anvil_node_name_star_key = "anvil_node${j}_name_star";
			my $default_node_name_key    = "node${j}_name";
			if (($conf->{sys}{install_manifest}{'default'}{$default_node_name_key}) && 
			    (not $conf->{sys}{install_manifest}{show}{nodes_name_field}))
			{
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	$anvil_node_name_key,
					id		=>	$anvil_node_name_key,
					value		=>	$conf->{cgi}{$anvil_node_name_key},
				});
			}
			else
			{
				my $anvil_node_name_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Node_Host_Names",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"#!string!row_0165!#",
					explain		=>	$explain_name,
					name		=>	$anvil_node_name_key,
					id		=>	$anvil_node_name_key,
					value		=>	$conf->{cgi}{$anvil_node_name_key},
					star		=>	$conf->{form}{$anvil_node_name_star_key},
					more_info	=>	"$anvil_node_name_more_info",
				});
			}
			
			# Node's BCN IP address
			my $anvil_node_bcn_ip_key      = "anvil_node${j}_bcn_ip";
			my $anvil_node_bcn_ip_star_key = "anvil_node${j}_bcn_ip_star";
			my $default_node_bcn_ip_key    = "node${j}_bcn_ip";
			if (($conf->{sys}{install_manifest}{'default'}{$default_node_bcn_ip_key}) && 
			    (not $conf->{sys}{install_manifest}{show}{nodes_bcn_field}))
			{
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	$anvil_node_bcn_ip_key,
					id		=>	$anvil_node_bcn_ip_key,
					value		=>	$conf->{cgi}{$anvil_node_bcn_ip_key},
				});
			}
			else
			{
				my $anvil_node_bcn_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Subnets",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"#!string!row_0166!#",
					explain		=>	$explain_bcn_ip,
					name		=>	$anvil_node_bcn_ip_key,
					id		=>	$anvil_node_bcn_ip_key,
					value		=>	$conf->{cgi}{$anvil_node_bcn_ip_key},
					star		=>	$conf->{form}{$anvil_node_bcn_ip_star_key},
					more_info	=>	"$anvil_node_bcn_ip_more_info",
				});
			}
			
			# Node's IPMI IP address
			my $anvil_node_ipmi_ip_key      = "anvil_node${j}_ipmi_ip";
			my $anvil_node_ipmi_ip_star_key = "anvil_node${j}_ipmi_ip_star";
			my $default_node_ipmi_ip_key    = "node${j}_ipmi_ip";
			if (($conf->{sys}{install_manifest}{'default'}{$default_node_ipmi_ip_key}) && 
			    (not $conf->{sys}{install_manifest}{show}{nodes_ipmi_field}))
			{
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	$anvil_node_ipmi_ip_key,
					id		=>	$anvil_node_ipmi_ip_key,
					value		=>	$conf->{cgi}{$anvil_node_ipmi_ip_key},
				});
			}
			else
			{
				my $anvil_node_ipmi_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#What_is_IPMI",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"#!string!row_0168!#",
					explain		=>	$explain_ipmi_ip,
					name		=>	$anvil_node_ipmi_ip_key,
					id		=>	$anvil_node_ipmi_ip_key,
					value		=>	$conf->{cgi}{$anvil_node_ipmi_ip_key},
					star		=>	$conf->{form}{$anvil_node_ipmi_ip_star_key},
					more_info	=>	"$anvil_node_ipmi_ip_more_info",
				});
			}
			
			# Node's SN IP address
			my $anvil_node_sn_ip_key      = "anvil_node${j}_sn_ip";
			my $anvil_node_sn_ip_star_key = "anvil_node${j}_sn_ip_star";
			my $default_node_sn_ip_key    = "node${j}_sn_ip";
			if (($conf->{sys}{install_manifest}{'default'}{$default_node_sn_ip_key}) && 
			   (not $conf->{sys}{install_manifest}{show}{nodes_sn_field}))
			{
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	$anvil_node_sn_ip_key,
					id		=>	$anvil_node_sn_ip_key,
					value		=>	$conf->{cgi}{$anvil_node_sn_ip_key},
				});
			}
			else
			{
				my $anvil_node_sn_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Subnets",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"#!string!row_0167!#",
					explain		=>	$explain_sn_ip,
					name		=>	$anvil_node_sn_ip_key,
					id		=>	$anvil_node_sn_ip_key,
					value		=>	$conf->{cgi}{$anvil_node_sn_ip_key},
					star		=>	$conf->{form}{$anvil_node_sn_ip_star_key},
					more_info	=>	"$anvil_node_sn_ip_more_info",
				});
			}
			
			# Node's IFN IP address
			my $anvil_node_ifn_ip_key      = "anvil_node${j}_ifn_ip";
			my $anvil_node_ifn_ip_star_key = "anvil_node${j}_ifn_ip_star";
			my $default_node_ifn_ip_key    = "node${j}_ifn_ip";
			if (($conf->{sys}{install_manifest}{'default'}{$default_node_ifn_ip_key}) && 
			   (not $conf->{sys}{install_manifest}{show}{nodes_ifn_field}))
			{
				print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
					name		=>	$anvil_node_ifn_ip_key,
					id		=>	$anvil_node_ifn_ip_key,
					value		=>	$conf->{cgi}{$anvil_node_ifn_ip_key},
				});
			}
			else
			{
				my $anvil_node_ifn_ip_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
					url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Subnets",
				});
				print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
					row		=>	"#!string!row_0169!#",
					explain		=>	$explain_ifn_ip,
					name		=>	$anvil_node_ifn_ip_key,
					id		=>	$anvil_node_ifn_ip_key,
					value		=>	$conf->{cgi}{$anvil_node_ifn_ip_key},
					star		=>	$conf->{form}{$anvil_node_ifn_ip_star_key},
					more_info	=>	"$anvil_node_ifn_ip_more_info",
				});
			}
			
			# Now we create an entry for each possible PDU (2 to 4).
			foreach my $i (1..4)
			{
				next if ($i > $conf->{sys}{install_manifest}{pdu_count});
				my $say_pdu     = "";
				my $say_explain = "";
				if    ($i == 1)
				{
					$say_pdu     = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#"  : "#!string!device_0007!#";
					$say_explain = $conf->{sys}{expert_ui} ? "#!string!terse_0096!#" : "#!string!explain_0096!#";
				}
				elsif ($i == 2)
				{
					$say_pdu = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#";
				}
				elsif ($i == 3)
				{
					$say_pdu = "#!string!device_0009!#";
				}
				elsif ($i == 4)
				{
					$say_pdu = "#!string!device_0010!#";
				}
				my $say_pdu_name = AN::Common::get_string($conf, {key => "row_0176", variables => { say_pdu => "$say_pdu" }});
				
				# PDU entry.
				my $pdu_outlet_key       = "anvil_node${j}_pdu${i}_outlet";
				my $pdu_outlet_star_key  = "anvil_node${j}_pdu${i}_outlet_star";
				if (not $conf->{sys}{install_manifest}{show}{nodes_ifn_field})
				{
					print AN::Common::template($conf, "config.html", "install-manifest-form-hidden-entry", {
						name		=>	$pdu_outlet_key,
						id		=>	$pdu_outlet_key,
						value		=>	$conf->{cgi}{$pdu_outlet_key},
					});
				}
				else
				{
					my $pdu_outlet_more_info = $conf->{sys}{disable_links} ? "" : AN::Common::template($conf, "config.html", "install-manifest-more-info-url", {
						url	=>	"https://alteeve.ca/w/AN!Cluster_Tutorial_2#Why_Switched_PDUs.3F",
					});
					print AN::Common::template($conf, "config.html", "install-manifest-form-text-entry", {
						row		=>	"$say_pdu_name",
						explain		=>	$say_explain,
						name		=>	$pdu_outlet_key,
						id		=>	$pdu_outlet_key,
						value		=>	$conf->{cgi}{$pdu_outlet_key},
						star		=>	$conf->{form}{$pdu_outlet_star_key},
						more_info	=>	"$pdu_outlet_more_info",
					});
				}
			}
			
			print AN::Common::template($conf, "config.html", "install-manifest-form-nodes", {

				anvil_node2_name		=>	$conf->{cgi}{anvil_node2_name},
				anvil_node2_name_star		=>	$conf->{form}{anvil_node2_name_star},
				anvil_node2_bcn_ip		=>	$conf->{cgi}{anvil_node2_bcn_ip},
				anvil_node2_bcn_ip_star		=>	$conf->{form}{anvil_node2_bcn_ip_star},
				anvil_node2_ipmi_ip		=>	$conf->{cgi}{anvil_node2_ipmi_ip},
				anvil_node2_ipmi_ip_star	=>	$conf->{form}{anvil_node2_ipmi_ip_star},
				anvil_node2_sn_ip		=>	$conf->{cgi}{anvil_node2_sn_ip},
				anvil_node2_sn_ip_star		=>	$conf->{form}{anvil_node2_sn_ip_star},
				anvil_node2_ifn_ip		=>	$conf->{cgi}{anvil_node2_ifn_ip},
				anvil_node2_ifn_ip_star		=>	$conf->{form}{anvil_node2_ifn_ip_star},
				anvil_node2_pdu1_outlet		=>	$conf->{cgi}{anvil_node2_pdu1_outlet},
				anvil_node2_pdu1_outlet_star	=>	$conf->{form}{anvil_node2_pdu1_outlet_star},
				anvil_node2_pdu2_outlet		=>	$conf->{cgi}{anvil_node2_pdu2_outlet},
				anvil_node2_pdu2_outlet_star	=>	$conf->{form}{anvil_node2_pdu2_outlet_star},
				anvil_node2_pdu3_outlet		=>	$conf->{cgi}{anvil_node2_pdu3_outlet},
				anvil_node2_pdu3_outlet_star	=>	$conf->{form}{anvil_node2_pdu3_outlet_star},
				anvil_node2_pdu4_outlet		=>	$conf->{cgi}{anvil_node2_pdu4_outlet},
				anvil_node2_pdu4_outlet_star	=>	$conf->{form}{anvil_node2_pdu4_outlet_star},
			});
		}
		
		# Footer.
		print AN::Common::template($conf, "config.html", "install-manifest-form-footer");
	}
	
	return(0);
}

# This parses this Striker dashboard's hostname and returns the prefix and
# domain name.
sub get_striker_prefix_and_domain
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; get_striker_prefix_and_domain()\n");
	
	my ($hostname) = get_hostname($conf);
	record($conf, "$THIS_FILE ".__LINE__."; hostname: [$hostname]\n");
	
	my $default_prefix = "";
	if ($hostname =~ /^(\w+)-/)
	{
		$default_prefix = $1;
		record($conf, "$THIS_FILE ".__LINE__."; default_prefix: [$default_prefix]\n");
	}
	my $default_demain = ($hostname =~ /\.(.*)$/)[0];
	record($conf, "$THIS_FILE ".__LINE__."; default_prefix: [$default_prefix], default_demain: [$default_demain]\n");
	
	# If the user has defined default prefix and/or domain, use them instead.
	if ($conf->{sys}{install_manifest}{'default'}{prefix}) { $default_prefix = $conf->{sys}{install_manifest}{'default'}{prefix}; }
	if ($conf->{sys}{install_manifest}{'default'}{domain}) { $default_demain = $conf->{sys}{install_manifest}{'default'}{domain}; }
	
	record($conf, "$THIS_FILE ".__LINE__."; default_prefix: [$default_prefix], default_demain: [$default_demain]\n");
	return($default_prefix, $default_demain);
}

# This reads in the passed in install manifest file name and loads it into the
# appropriate cgi variables for use in the install manifest form.
sub load_install_manifest
{
	my ($conf, $file) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; load_install_manifest(); file: [$file]\n");
	
	# Read in the install manifest file.
	my $manifest_file = $conf->{path}{apache_manifests_dir}."/".$file;
	record($conf, "$THIS_FILE ".__LINE__."; manifest_file: [$manifest_file]\n");
	if (-e $manifest_file)
	{
		# Load it!
		my $xml  = XML::Simple->new();
		my $data = $xml->XMLin($manifest_file, KeyAttr => {node => 'name'}, ForceArray => 1);
		
		# Nodes.
		foreach my $node (keys %{$data->{node}})
		{
			#print "<pre>\n";
			#use Data::Dumper;
			#print Dumper $data;
			#print "</pre>\n";
			#die;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node]\n");
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
							$conf->{install_manifest}{$file}{node}{$node}{interface}{$name}{mac} = "";
							if (($mac) && ($mac =~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i))
							{
								$conf->{install_manifest}{$file}{node}{$node}{interface}{$name}{mac} = $mac;
							}
							elsif ($mac)
							{
								# Malformed MAC
								record($conf, "$THIS_FILE ".__LINE__."; Install Manifest: [$file], Node: [$node], interface: [$name] has a malformed MAC address: [$mac], ignored. Format must be 'xx:xx:xx:xx:xx:xx'.\n");
							}
						}
					}
				}
				elsif ($a eq "network")
				{
					#record($conf, "$THIS_FILE ".__LINE__."; a: [$a], -> b: [$data->{node}{$node}{network}->[0]]\n");
					foreach my $network (keys %{$data->{node}{$node}{network}->[0]})
					{
						my $ip = $data->{node}{$node}{network}->[0]->{$network}->[0]->{ip};
						$conf->{install_manifest}{$file}{node}{$node}{network}{$network}{ip} = $ip ? $ip : "";
						#record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], Network: [$network], IP: [$conf->{install_manifest}{$file}{node}{$node}{network}{$network}{ip}]\n");
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
						
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{name}            = $name            ? $name            : "";
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{port}            = $port            ? $port            : ""; 
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{user}            = $user            ? $user            : "";
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password}        = $password        ? $password        : "";
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password_script} = $password_script ? $password_script : "";
						#record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], PDU: [$reference], Name: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{name}], Port: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{port}], User: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{user}], Password: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password}], Password Script: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password_script}]\n");
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
						
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{name}            = $name            ? $name            : "";
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{port}            = $port            ? $port            : "";
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{user}            = $user            ? $user            : "";
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password}        = $password        ? $password        : "";
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password_script} = $password_script ? $password_script : "";
						#record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], KVM: [$reference], Name: [$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{name}], Port: [$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{port}], User: [$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{user}], Password: [$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password}], password_script: [$conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password_script}]\n");
					}
				}
				elsif ($a eq "ipmi")
				{
					foreach my $b (@{$data->{node}{$node}{ipmi}->[0]->{on}})
					{
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], ipmi b: [$b]\n");
						#foreach my $key (keys %{$b}) { record($conf, "$THIS_FILE ".__LINE__."; node: [$node], ipmi b: [$b], key: [$key] -> [$b->{$key}]\n"); }
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
						#record($conf, "$THIS_FILE ".__LINE__."; >> password: [$password], length: [".length($password)."]\n");
						if (length($password) > 16)
						{
							$password = substr($password, 0, 16);
							#record($conf, "$THIS_FILE ".__LINE__."; << password: [$password], length: [".length($password)."]\n");
						}
						
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{name}            = $name            ? $name            : "";
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{ip}              = $ip              ? $ip              : "";
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{gateway}         = $gateway         ? $gateway         : "";
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{netmask}         = $netmask         ? $netmask         : "";
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{user}            = $user            ? $user            : "";
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password}        = $password        ? $password        : "";
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password_script} = $password_script ? $password_script : "";
						#record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], IPMI: [$reference], Name: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{name}], IP: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{ip}/$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{netmask}, gw: $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{gateway}], User: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{user}], Password: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password}], password_script: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password_script}]\n");
					}
				}
				elsif ($a eq "uuid")
				{
					my $uuid = $data->{node}{$node}{uuid};
					$conf->{install_manifest}{$file}{node}{$node}{uuid} = $uuid ? $uuid : "";
					record($conf, "$THIS_FILE ".__LINE__."; node: [$node], uuid: [$uuid], install_manifest::${file}::node::${node}::uuid: [$conf->{install_manifest}{$file}{node}{$node}{uuid}]\n");
				}
				else
				{
					# What's this?
					record($conf, "$THIS_FILE ".__LINE__."; Extra element in node: [$node]'s install manifest file: [$file]; a: [$a]\n");
					foreach my $b (@{$data->{node}{$node}{$a}})
					{
						record($conf, "$THIS_FILE ".__LINE__."; - b: [$b] -> [$data->{node}{$node}{$a}->[$b]]\n");
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
					$conf->{install_manifest}{$file}{common}{anvil}{prefix}           = $prefix           ? $prefix           : "";
					$conf->{install_manifest}{$file}{common}{anvil}{domain}           = $domain           ? $domain           : "";
					$conf->{install_manifest}{$file}{common}{anvil}{sequence}         = $sequence         ? $sequence         : "";
					$conf->{install_manifest}{$file}{common}{anvil}{password}         = $password         ? $password         : "";
					$conf->{install_manifest}{$file}{common}{anvil}{striker_user}     = $striker_user     ? $striker_user     : "";
					$conf->{install_manifest}{$file}{common}{anvil}{striker_database} = $striker_database ? $striker_database : "";
				}
				elsif ($b eq "cluster")
				{
					# Cluster Name
					my $name = $a->{$b}->[0]->{name};
					$conf->{install_manifest}{$file}{common}{cluster}{name} = $name ? $name : "";
					
					# Fencing stuff
					my $post_join_delay = $a->{$b}->[0]->{fence}->[0]->{post_join_delay};
					my $order           = $a->{$b}->[0]->{fence}->[0]->{order};
					my $delay           = $a->{$b}->[0]->{fence}->[0]->{delay};
					my $delay_node      = $a->{$b}->[0]->{fence}->[0]->{delay_node};
					$conf->{install_manifest}{$file}{common}{cluster}{fence}{post_join_delay} = $post_join_delay ? $post_join_delay : "";
					$conf->{install_manifest}{$file}{common}{cluster}{fence}{order}           = $order           ? $order           : "";
					$conf->{install_manifest}{$file}{common}{cluster}{fence}{delay}           = $delay           ? $delay           : "";
					$conf->{install_manifest}{$file}{common}{cluster}{fence}{delay_node}      = $delay_node      ? $delay_node      : "";
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
						
						$conf->{install_manifest}{$file}{common}{file}{$name}{mode}    = $mode    ? $mode    : "";
						$conf->{install_manifest}{$file}{common}{file}{$name}{owner}   = $owner   ? $owner   : "";
						$conf->{install_manifest}{$file}{common}{file}{$name}{group}   = $group   ? $group   : "";
						$conf->{install_manifest}{$file}{common}{file}{$name}{content} = $content ? $content : "";
					}
				}
				elsif ($b eq "iptables")
				{
					my $ports = $a->{$b}->[0]->{vnc}->[0]->{ports};
					$conf->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports} = $ports ? $ports : 100;
					#record($conf, "$THIS_FILE ".__LINE__."; Firewall iptables; VNC port count: [$conf->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports}]\n");
				}
				elsif ($b eq "servers")
				{
					# I may use this later for other things.
					#my $use_spice_graphics = $a->{$b}->[0]->{provision}->[0]->{use_spice_graphics};
					#$conf->{install_manifest}{$file}{common}{cluster}{servers}{provision}{use_spice_graphics} = $use_spice_graphics ? $use_spice_graphics : "0";
					#record($conf, "$THIS_FILE ".__LINE__."; Server provisioning; Use spice graphics: [$conf->{install_manifest}{$file}{common}{cluster}{servers}{provision}{use_spice_graphics}]\n");
				}
				elsif ($b eq "tools")
				{
					# Used to control which Anvil! tools are used and how to use them.
					my $safe_anvil_start   = $a->{$b}->[0]->{'use'}->[0]->{safe_anvil_start};
					my $anvil_kick_apc_ups = $a->{$b}->[0]->{'use'}->[0]->{'anvil-kick-apc-ups'};
					my $scancore           = $a->{$b}->[0]->{'use'}->[0]->{scancore};
					
					$safe_anvil_start   = 1 if $safe_anvil_start   eq "true";
					$anvil_kick_apc_ups = 1 if $anvil_kick_apc_ups eq "true";
					$scancore           = 1 if $scancore           eq "true";
					
					$conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{safe_anvil_start}     = defined $safe_anvil_start   ? $safe_anvil_start   : $conf->{sys}{install_manifest}{'default'}{use_safe_anvil_start};
					$conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} = defined $anvil_kick_apc_ups ? $anvil_kick_apc_ups : $conf->{sys}{install_manifest}{'default'}{'use_anvil-kick-apc-ups'};
					$conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{scancore}             = defined $scancore           ? $scancore           : $conf->{sys}{install_manifest}{'default'}{use_scancore};
					record($conf, "$THIS_FILE ".__LINE__."; Tools; use 'safe_anvil_start': [$conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{safe_anvil_start}], use: 'anvil-kick-apc-ups': [$conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'}], use: 'scancore': [$conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{scancore}]\n");
				}
				elsif ($b eq "media_library")
				{
					my $size  = $a->{$b}->[0]->{size};
					my $units = $a->{$b}->[0]->{units};
					$conf->{install_manifest}{$file}{common}{media_library}{size}  = $size  ? $size  : "";
					$conf->{install_manifest}{$file}{common}{media_library}{units} = $units ? $units : "";
				}
				elsif ($b eq "repository")
				{
					my $urls = $a->{$b}->[0]->{urls};
					$conf->{install_manifest}{$file}{common}{anvil}{repositories} = $urls ? $urls : "";
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
									$conf->{install_manifest}{$file}{common}{network}{bond}{options} = $options ? $options : "";
									#record($conf, "$THIS_FILE ".__LINE__."; Common bonding options: [$conf->{install_manifest}{$file}{common}{network}{bonds}{options}]\n");
								}
								else
								{
									# Named network.
									my $name      = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{name};
									my $primary   = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{primary};
									my $secondary = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{secondary};
									$conf->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{primary}   = $primary   ? $primary   : "";
									$conf->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{secondary} = $secondary ? $secondary : "";
									#record($conf, "$THIS_FILE ".__LINE__."; Bond: [$name], Primary: [$conf->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{primary}], Secondary: [$conf->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{secondary}]\n");
								}
							}
						}
						elsif ($c eq "bridges")
						{
							foreach my $d (@{$a->{$b}->[0]->{$c}->[0]->{bridge}})
							{
								my $name = $d->{name};
								my $on   = $d->{on};
								$conf->{install_manifest}{$file}{common}{network}{bridge}{$name}{on} = $on ? $on : "";
								#record($conf, "$THIS_FILE ".__LINE__."; Bridge; name: [$name] on: [$conf->{install_manifest}{$file}{common}{network}{bridge}{$name}{on}]\n");
							}
						}
						elsif ($c eq "mtu")
						{
							#<mtu size=\"$conf->{cgi}{anvil_mtu_size}\" />
							my $size = $a->{$b}->[0]->{$c}->[0]->{size};
							$conf->{install_manifest}{$file}{common}{network}{mtu}{size} = $size ? $size : 1500;
						}
						else
						{
							my $netblock = $a->{$b}->[0]->{$c}->[0]->{netblock};
							my $netmask  = $a->{$b}->[0]->{$c}->[0]->{netmask};
							my $gateway  = $a->{$b}->[0]->{$c}->[0]->{gateway};
							my $defroute = $a->{$b}->[0]->{$c}->[0]->{defroute};
							my $dns1     = $a->{$b}->[0]->{$c}->[0]->{dns1};
							my $dns2     = $a->{$b}->[0]->{$c}->[0]->{dns2};
							my $ntp1     = $a->{$b}->[0]->{$c}->[0]->{ntp1};
							my $ntp2     = $a->{$b}->[0]->{$c}->[0]->{ntp2};
							
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{netblock} = $netblock ? $netblock : "";
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{netmask}  = $netmask  ? $netmask  : "";
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{gateway}  = $gateway  ? $gateway  : "";
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{defroute} = $defroute ? $defroute : "";
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{dns1}     = $dns1     ? $dns1     : "";
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{dns2}     = $dns2     ? $dns2     : "";
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{ntp1}     = $ntp1     ? $ntp1     : "";
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{ntp2}     = $ntp2     ? $ntp2     : "";
							#record($conf, "$THIS_FILE ".__LINE__."; Network: [$c], netblock: [$conf->{install_manifest}{$file}{common}{network}{name}{bcn}{netblock}], netmask: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{netmask}], gateway [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{gateway}], defroute: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{defroute}], dns1: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{dns1}], dns2: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{dns2}], ntp1: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{ntp1}], ntp2: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{ntp2}]\n");
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
						
						$conf->{install_manifest}{$file}{common}{pdu}{$reference}{name}            = $name            ? $name            : "";
						$conf->{install_manifest}{$file}{common}{pdu}{$reference}{ip}              = $ip              ? $ip              : "";
						$conf->{install_manifest}{$file}{common}{pdu}{$reference}{user}            = $user            ? $user            : "";
						$conf->{install_manifest}{$file}{common}{pdu}{$reference}{password}        = $password        ? $password        : "";
						$conf->{install_manifest}{$file}{common}{pdu}{$reference}{password_script} = $password_script ? $password_script : "";
						$conf->{install_manifest}{$file}{common}{pdu}{$reference}{agent}           = $agent           ? $agent           : $conf->{sys}{install_manifest}{pdu_agent};
						#record($conf, "$THIS_FILE ".__LINE__."; PDU reference: [$reference], Name: [$conf->{install_manifest}{$file}{common}{pdu}{$reference}{name}], IP: [$conf->{install_manifest}{$file}{common}{pdu}{$reference}{ip}], user: [$conf->{install_manifest}{$file}{common}{pdu}{$reference}{user}], password: [$conf->{install_manifest}{$file}{common}{pdu}{$reference}{password}], password_script: [$conf->{install_manifest}{$file}{common}{pdu}{$reference}{password_script}], agent: [$conf->{install_manifest}{$file}{common}{pdu}{$reference}{agent}]\n");
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
						
						$conf->{install_manifest}{$file}{common}{kvm}{$reference}{name}            = $name            ? $name            : "";
						$conf->{install_manifest}{$file}{common}{kvm}{$reference}{ip}              = $ip              ? $ip              : "";
						$conf->{install_manifest}{$file}{common}{kvm}{$reference}{user}            = $user            ? $user            : "";
						$conf->{install_manifest}{$file}{common}{kvm}{$reference}{password}        = $password        ? $password        : "";
						$conf->{install_manifest}{$file}{common}{kvm}{$reference}{password_script} = $password_script ? $password_script : "";
						$conf->{install_manifest}{$file}{common}{kvm}{$reference}{agent}           = $agent           ? $agent           : "fence_virsh";
						#record($conf, "$THIS_FILE ".__LINE__."; KVM: [$reference], Name: [$conf->{install_manifest}{$file}{common}{kvm}{$reference}{name}], IP: [$conf->{install_manifest}{$file}{common}{kvm}{$reference}{ip}], user: [$conf->{install_manifest}{$file}{common}{kvm}{$reference}{user}], password: [$conf->{install_manifest}{$file}{common}{kvm}{$reference}{password}], password_script: [$conf->{install_manifest}{$file}{common}{kvm}{$reference}{password_script}], agent: [$conf->{install_manifest}{$file}{common}{kvm}{$reference}{agent}]\n");
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
						
						# If the password is more than
						# 16 characters long, truncate
						# it so that nodes with IPMI
						# v1.5 don't spazz out.
						#record($conf, "$THIS_FILE ".__LINE__."; >> password: [$password], length: [".length($password)."]\n");
						if (length($password) > 16)
						{
							$password = substr($password, 0, 16);
							#record($conf, "$THIS_FILE ".__LINE__."; << password: [$password], length: [".length($password)."]\n");
						}
						
						$conf->{install_manifest}{$file}{common}{namemi}{$reference}{name}          = $name            ? $name            : "";
						$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{ip}              = $ip              ? $ip              : "";
						$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{netmask}         = $netmask         ? $netmask         : "";
						$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{gateway}         = $gateway         ? $gateway         : "";
						$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{user}            = $user            ? $user            : "";
						$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{password}        = $password        ? $password        : "";
						$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{password_script} = $password_script ? $password_script : "";
						$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{agent}           = $agent           ? $agent           : "fence_ipmilan";
						
						record($conf, "$THIS_FILE ".__LINE__."; IPMI: [$reference], Name: [$conf->{install_manifest}{$file}{common}{namemi}{$reference}{name}], IP: [$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{ip}], Netmask: [$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{netmask}], Gateway: [$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{gateway}], user: [$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{user}], password: [$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{password}], password_script: [$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{password_script}], agent: [$conf->{install_manifest}{$file}{common}{ipmi}{$reference}{agent}]\n");
					}
				}
				elsif ($b eq "ssh")
				{
					my $keysize = $a->{$b}->[0]->{keysize};
					$conf->{install_manifest}{$file}{common}{ssh}{keysize} = $keysize ? $keysize : "";
					#record($conf, "$THIS_FILE ".__LINE__."; SSH keysize: [$conf->{install_manifest}{$file}{common}{ssh}{keysize}] bytes\n");
				}
				elsif ($b eq "storage_pool_1")
				{
					my $size  = $a->{$b}->[0]->{size};
					my $units = $a->{$b}->[0]->{units};
					$conf->{install_manifest}{$file}{common}{storage_pool}{1}{size}  = $size  ? $size  : "";
					$conf->{install_manifest}{$file}{common}{storage_pool}{1}{units} = $units ? $units : "";
					#record($conf, "$THIS_FILE ".__LINE__."; Storage Pool 1: [$conf->{install_manifest}{$file}{common}{storage_pool}{1}{size} $conf->{install_manifest}{$file}{common}{storage_pool}{1}{units}]\n");
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
						
						$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{bcn_ip}   = $bcn_ip   ? $bcn_ip   : "";
						$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{ifn_ip}   = $ifn_ip   ? $ifn_ip   : "";
						$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{password} = $password ? $password : "";
						$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{user}     = $user     ? $user     : "";
						$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{database} = $database ? $database : "";
						#record($conf, "$THIS_FILE ".__LINE__."; Striker: [$name], BCN IP: [$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{bcn_ip}], IFN IP: [$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{ifn_ip}], install_manifest${file}::common::striker::name::${name}::password: [$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{password}], install_manifest::${file}::common::striker::name::${name}::user: [$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{user}], install_manifest::${file}::common::striker::name::${name}::database: [$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{database}]\n");
					}
				}
				elsif ($b eq "switch")
				{
					foreach my $c (@{$a->{$b}->[0]->{switch}})
					{
						my $name = $c->{name};
						my $ip   = $c->{ip};
						$conf->{install_manifest}{$file}{common}{switch}{$name}{ip} = $ip ? $ip : "";
						#record($conf, "$THIS_FILE ".__LINE__."; Switch: [$name], IP: [$conf->{install_manifest}{$file}{common}{switch}{$name}{ip}]\n");
					}
				}
				elsif ($b eq "update")
				{
					my $os = $a->{$b}->[0]->{os};
					$conf->{install_manifest}{$file}{common}{update}{os} = $os ? $os : "";
					#record($conf, "$THIS_FILE ".__LINE__."; Update OS: [$conf->{install_manifest}{$file}{common}{update}{os}]\n");
				}
				elsif ($b eq "ups")
				{
					foreach my $c (@{$a->{$b}->[0]->{ups}})
					{
						my $name = $c->{name};
						my $ip   = $c->{ip};
						my $type = $c->{type};
						my $port = $c->{port};
						$conf->{install_manifest}{$file}{common}{ups}{$name}{ip}   = $ip   ? $ip   : "";
						$conf->{install_manifest}{$file}{common}{ups}{$name}{type} = $type ? $type : "";
						$conf->{install_manifest}{$file}{common}{ups}{$name}{port} = $port ? $port : "";
						#record($conf, "$THIS_FILE ".__LINE__."; UPS: [$name], IP: [$conf->{install_manifest}{$file}{common}{ups}{$name}{ip}], type: [$conf->{install_manifest}{$file}{common}{ups}{$name}{type}], port: [$conf->{install_manifest}{$file}{common}{ups}{$name}{port}]\n");
					}
				}
				else
				{
					record($conf, "$THIS_FILE ".__LINE__."; Extra element in install manifest file: [$file]; b: [$b] -> [$a->{$b}]\n");
				}
			}
		}
		
		# Load the common variables.
		$conf->{cgi}{anvil_prefix}       = $conf->{install_manifest}{$file}{common}{anvil}{prefix};
		$conf->{cgi}{anvil_domain}       = $conf->{install_manifest}{$file}{common}{anvil}{domain};
		$conf->{cgi}{anvil_sequence}     = $conf->{install_manifest}{$file}{common}{anvil}{sequence};
		$conf->{cgi}{anvil_password}     = $conf->{install_manifest}{$file}{common}{anvil}{password}         ? $conf->{install_manifest}{$file}{common}{anvil}{password}         : $conf->{sys}{install_manifest}{'default'}{password};
		$conf->{cgi}{anvil_repositories} = $conf->{install_manifest}{$file}{common}{anvil}{repositories};
		$conf->{cgi}{anvil_ssh_keysize}  = $conf->{install_manifest}{$file}{common}{ssh}{keysize}            ? $conf->{install_manifest}{$file}{common}{ssh}{keysize}            : $conf->{sys}{install_manifest}{'default'}{ssh_keysize};
		$conf->{cgi}{anvil_mtu_size}     = $conf->{install_manifest}{$file}{common}{network}{mtu}{size}      ? $conf->{install_manifest}{$file}{common}{network}{mtu}{size}      : $conf->{sys}{install_manifest}{'default'}{mtu};
		$conf->{cgi}{striker_user}       = $conf->{install_manifest}{$file}{common}{anvil}{striker_user}     ? $conf->{install_manifest}{$file}{common}{anvil}{striker_user}     : $conf->{sys}{install_manifest}{'default'}{striker_user};
		$conf->{cgi}{striker_database}   = $conf->{install_manifest}{$file}{common}{anvil}{striker_database} ? $conf->{install_manifest}{$file}{common}{anvil}{striker_database} : $conf->{sys}{install_manifest}{'default'}{striker_database};
		record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_prefix: [$conf->{cgi}{anvil_prefix}], cgi::anvil_domain: [$conf->{cgi}{anvil_domain}], cgi::anvil_sequence: [$conf->{cgi}{anvil_sequence}], cgi::anvil_password: [$conf->{cgi}{anvil_password}], cgi::anvil_repositories: [$conf->{cgi}{anvil_repositories}], cgi::anvil_ssh_keysize: [$conf->{cgi}{anvil_ssh_keysize}], cgi::striker_database: [$conf->{cgi}{striker_database}]\n");
		
		# Media Library values
		$conf->{cgi}{anvil_media_library_size} = $conf->{install_manifest}{$file}{common}{media_library}{size};
		$conf->{cgi}{anvil_media_library_unit} = $conf->{install_manifest}{$file}{common}{media_library}{units};
		#record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_media_library_size: [$conf->{cgi}{anvil_media_library_size}], cgi::anvil_media_library_unit: [$conf->{cgi}{anvil_media_library_unit}]\n");
		
		# Networks
		$conf->{cgi}{anvil_bcn_network} = $conf->{install_manifest}{$file}{common}{network}{name}{bcn}{netblock};
		$conf->{cgi}{anvil_bcn_subnet}  = $conf->{install_manifest}{$file}{common}{network}{name}{bcn}{netmask};
		$conf->{cgi}{anvil_sn_network}  = $conf->{install_manifest}{$file}{common}{network}{name}{sn}{netblock};
		$conf->{cgi}{anvil_sn_subnet}   = $conf->{install_manifest}{$file}{common}{network}{name}{sn}{netmask};
		$conf->{cgi}{anvil_ifn_network} = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{netblock};
		$conf->{cgi}{anvil_ifn_subnet}  = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{netmask};
		#record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_bcn_network: [$conf->{cgi}{anvil_bcn_network}], cgi::anvil_bcn_subnet: [$conf->{cgi}{anvil_bcn_subnet}], cgi::anvil_sn_network: [$conf->{cgi}{anvil_sn_network}], cgi::anvil_sn_subnet: [$conf->{cgi}{anvil_sn_subnet}], cgi::anvil_ifn_network: [$conf->{cgi}{anvil_ifn_network}], cgi::anvil_ifn_subnet: [$conf->{cgi}{anvil_ifn_subnet}]\n");
		
		# iptables
		$conf->{cgi}{anvil_open_vnc_ports} = $conf->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports};
		#record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_open_vnc_ports: [$conf->{cgi}{anvil_open_vnc_ports}]\n");
		
		# Storage Pool 1
		$conf->{cgi}{anvil_storage_pool1_size} = $conf->{install_manifest}{$file}{common}{storage_pool}{1}{size};
		$conf->{cgi}{anvil_storage_pool1_unit} = $conf->{install_manifest}{$file}{common}{storage_pool}{1}{units};
		#record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool1_size: [$conf->{cgi}{anvil_storage_pool1_size}], cgi::anvil_storage_pool1_unit: [$conf->{cgi}{anvil_storage_pool1_unit}]\n");
		
		# Tools
		$conf->{sys}{install_manifest}{use_safe_anvil_start}     = defined $conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{safe_anvil_start}     ? $conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{safe_anvil_start}     : $conf->{sys}{install_manifest}{'default'}{use_safe_anvil_start};
		$conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'} = defined $conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} ? $conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} : $conf->{sys}{install_manifest}{'default'}{'use_anvil-kick-apc-ups'};
		$conf->{sys}{install_manifest}{use_scancore}             = defined $conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{scancore}             ? $conf->{install_manifest}{$file}{common}{cluster}{tools}{'use'}{scancore}             : $conf->{sys}{install_manifest}{'default'}{use_scancore};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sys::install_manifest::use_safe_anvil_start: [$conf->{sys}{install_manifest}{use_safe_anvil_start}], sys::install_manifest::use_anvil-kick-apc-ups: [$conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'}], sys::install_manifest::use_scancore: [$conf->{sys}{install_manifest}{use_scancore}]\n");
		
		# Shared Variables
		$conf->{cgi}{anvil_name}        = $conf->{install_manifest}{$file}{common}{cluster}{name};
		$conf->{cgi}{anvil_ifn_gateway} = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{gateway};
		$conf->{cgi}{anvil_dns1}        = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{dns1};
		$conf->{cgi}{anvil_dns2}        = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{dns2};
		$conf->{cgi}{anvil_ntp1}        = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{ntp1};
		$conf->{cgi}{anvil_ntp2}        = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{ntp2};
		#record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_name: [$conf->{cgi}{anvil_name}], cgi::anvil_ifn_gateway: [$conf->{cgi}{anvil_ifn_gateway}], cgi::anvil_dns1: [$conf->{cgi}{anvil_dns1}], cgi::anvil_dns2: [$conf->{cgi}{anvil_dns2}], cgi::anvil_ntp1: [$conf->{cgi}{anvil_ntp1}], cgi::anvil_ntp2: [$conf->{cgi}{anvil_ntp2}]\n");
		
		### Foundation Pack
		# Switches
		my $i = 1;
		foreach my $switch (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{switch}})
		{
			my $name_key = "anvil_switch".$i."_name";
			my $ip_key   = "anvil_switch".$i."_ip";
			$conf->{cgi}{$name_key} = $switch;
			$conf->{cgi}{$ip_key}   = $conf->{install_manifest}{$file}{common}{switch}{$switch}{ip};
			#record($conf, "$THIS_FILE ".__LINE__."; Switch: [$switch], name_key: [$name_key], ip_key: [$ip_key], CGI; Name: [$conf->{cgi}{$name_key}], IP: [$conf->{cgi}{$ip_key}]\n");
			$i++;
		}
		# PDUs
		$i = 1;
		foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{pdu}})
		{
			my $name_key = "anvil_pdu".$i."_name";
			my $ip_key   = "anvil_pdu".$i."_ip";
			my $name     = $conf->{install_manifest}{$file}{common}{pdu}{$reference}{name};
			my $ip       = $conf->{install_manifest}{$file}{common}{pdu}{$reference}{ip};
			$conf->{cgi}{$name_key} = $name ? $name : "";
			$conf->{cgi}{$ip_key}   = $ip   ? $ip   : "";
			#record($conf, "$THIS_FILE ".__LINE__."; PDU reference: [$reference], name_key: [$name_key], ip_key: [$ip_key], CGI; Name: [$conf->{cgi}{$name_key}], IP: [$conf->{cgi}{$ip_key}]\n");
			$i++;
		}
		# UPSes
		$i = 1;
		foreach my $ups (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{ups}})
		{
			my $name_key = "anvil_ups".$i."_name";
			my $ip_key   = "anvil_ups".$i."_ip";
			$conf->{cgi}{$name_key} = $ups;
			$conf->{cgi}{$ip_key}   = $conf->{install_manifest}{$file}{common}{ups}{$ups}{ip};
			#record($conf, "$THIS_FILE ".__LINE__."; UPS: [$ups], name_key: [$name_key], ip_key: [$ip_key], CGI; Name: [$conf->{cgi}{$name_key}], IP: [$conf->{cgi}{$ip_key}]\n");
			$i++;
		}
		# Striker Dashboards
		$i = 1;
		foreach my $striker (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{striker}{name}})
		{
			my $name_key     =  "anvil_striker".$i."_name";
			my $bcn_ip_key   =  "anvil_striker".$i."_bcn_ip";
			my $ifn_ip_key   =  "anvil_striker".$i."_ifn_ip";
			my $user_key     =  "anvil_striker".$i."_user";
			my $password_key =  "anvil_striker".$i."_password";
			my $database_key =  "anvil_striker".$i."_database";
			$conf->{cgi}{$name_key}     = $striker;
			$conf->{cgi}{$bcn_ip_key}   = $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{bcn_ip};
			$conf->{cgi}{$ifn_ip_key}   = $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{ifn_ip};
			$conf->{cgi}{$user_key}     = $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{user}     ? $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{user}     : $conf->{cgi}{striker_user};
			$conf->{cgi}{$password_key} = $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{password} ? $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{password} : $conf->{cgi}{anvil_password};
			$conf->{cgi}{$database_key} = $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{database} ? $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{database} : $conf->{cgi}{striker_database};
			record($conf, "$THIS_FILE ".__LINE__."; cgi::$name_key: [$conf->{cgi}{$name_key}], cgi::$bcn_ip_key: [$conf->{cgi}{$bcn_ip_key}], cgi::$ifn_ip_key: [$conf->{cgi}{$ifn_ip_key}], cgi::$user_key: [$conf->{cgi}{$user_key}], cgi::$password_key: [$conf->{cgi}{$password_key}], cgi::$database_key: [$conf->{cgi}{$database_key}]\n");
			$i++;
		}
		
		### Now the Nodes.
		$i = 1;
		foreach my $node (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}})
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], i: [$i]\n");
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
			
			# IPMI is, by default, tempremental about passwords. If
			# the manifest doesn't specify the password to use, 
			# we'll copy the cluster password but then strip out
			# special characters and shorten it to 16 characters or
			# less.
			my $default_ipmi_pw =  $conf->{cgi}{anvil_password};
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
			foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{ipmi}})
			{
				# There should only be one entry
				$ipmi_reference = $reference;
			}
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ipmi_reference: [$ipmi_reference]\n");
			my $j = 1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; j: [$j], install_manifest::${file}::node::${node}::pdu: [$conf->{install_manifest}{$file}{node}{$node}{pdu}]\n");
			foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{pdu}})
			{
				# There should be two or four PDUs
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; j: [$j], reference: [$reference]\n");
				if ($j == 1)
				{
					$pdu1_reference = $reference;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pdu1_reference: [$pdu1_reference]\n");
				}
				elsif ($j == 2)
				{
					$pdu2_reference = $reference;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pdu2_reference: [$pdu2_reference]\n");
				}
				elsif ($j == 3)
				{
					$pdu3_reference = $reference;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pdu3_reference: [$pdu3_reference]\n");
				}
				elsif ($j == 4)
				{
					$pdu4_reference = $reference;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pdu4_reference: [$pdu4_reference]\n");
				}
				$j++;
			}
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pdu1_reference: [$pdu1_reference], pdu2_reference: [$pdu2_reference], pdu3_reference: [$pdu3_reference], pdu4_reference: [$pdu4_reference]\n");
			foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{kvm}})
			{
				# There should only be one entry
				$kvm_reference = $reference;
			}
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; kvm_reference: [$kvm_reference]\n");
			
			$conf->{cgi}{$name_key}          = $node;
			$conf->{cgi}{$bcn_ip_key}        = $conf->{install_manifest}{$file}{node}{$node}{network}{bcn}{ip};
			$conf->{cgi}{$sn_ip_key}         = $conf->{install_manifest}{$file}{node}{$node}{network}{sn}{ip};
			$conf->{cgi}{$ifn_ip_key}        = $conf->{install_manifest}{$file}{node}{$node}{network}{ifn}{ip};
			
			$conf->{cgi}{$ipmi_ip_key}       = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{ip};
			$conf->{cgi}{$ipmi_netmask_key}  = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{netmask}  ? $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{netmask}  : $conf->{cgi}{anvil_bcn_subnet};
			$conf->{cgi}{$ipmi_gateway_key}  = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{gateway}  ? $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{gateway}  : "";
			$conf->{cgi}{$ipmi_password_key} = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{password} ? $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{password} : $default_ipmi_pw;
			$conf->{cgi}{$ipmi_user_key}     = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{user}     ? $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$ipmi_reference}{user}     : "admin";
			$conf->{cgi}{$pdu1_key}          = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$pdu1_reference}{port};
			$conf->{cgi}{$pdu2_key}          = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$pdu2_reference}{port};
			$conf->{cgi}{$pdu3_key}          = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$pdu3_reference}{port};
			$conf->{cgi}{$pdu4_key}          = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$pdu4_reference}{port};
			$conf->{cgi}{$uuid_key}          = $conf->{install_manifest}{$file}{node}{$node}{uuid}                            ? $conf->{install_manifest}{$file}{node}{$node}{uuid}                            : "";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::$name_key: [$conf->{cgi}{$name_key}], cgi::$bcn_ip_key: [$conf->{cgi}{$bcn_ip_key}], cgi::$ipmi_ip_key: [$conf->{cgi}{$ipmi_ip_key}], cgi::$ipmi_netmask_key: [$conf->{cgi}{$ipmi_netmask_key}], cgi::$ipmi_gateway_key: [$conf->{cgi}{$ipmi_gateway_key}], cgi::$ipmi_password_key: [$conf->{cgi}{$ipmi_password_key}], cgi::$ipmi_user_key: [$conf->{cgi}{$ipmi_user_key}], cgi::$sn_ip_key: [$conf->{cgi}{$sn_ip_key}], cgi::$ifn_ip_key: [$conf->{cgi}{$ifn_ip_key}], cgi::$pdu1_key: [$conf->{cgi}{$pdu1_key}], cgi::$pdu2_key: [$conf->{cgi}{$pdu2_key}], cgi::$pdu3_key: [$conf->{cgi}{$pdu3_key}], cgi::$pdu4_key: [$conf->{cgi}{$pdu4_key}], cgi::$uuid_key: [$conf->{cgi}{$uuid_key}]\n");
			
			# If the user remapped their network, we don't want to
			# undo the results.
			if (not $conf->{cgi}{perform_install})
			{
				$conf->{cgi}{$bcn_link1_mac_key} = $conf->{install_manifest}{$file}{node}{$node}{interface}{bcn_link1}{mac};
				$conf->{cgi}{$bcn_link2_mac_key} = $conf->{install_manifest}{$file}{node}{$node}{interface}{bcn_link2}{mac};
				$conf->{cgi}{$sn_link1_mac_key}  = $conf->{install_manifest}{$file}{node}{$node}{interface}{sn_link1}{mac};
				$conf->{cgi}{$sn_link2_mac_key}  = $conf->{install_manifest}{$file}{node}{$node}{interface}{sn_link2}{mac};
				$conf->{cgi}{$ifn_link1_mac_key} = $conf->{install_manifest}{$file}{node}{$node}{interface}{ifn_link1}{mac};
				$conf->{cgi}{$ifn_link2_mac_key} = $conf->{install_manifest}{$file}{node}{$node}{interface}{ifn_link2}{mac};
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::$bcn_link1_mac_key: [$conf->{cgi}{$bcn_link1_mac_key}], cgi::$bcn_link2_mac_key: [$conf->{cgi}{$bcn_link2_mac_key}], cgi::$sn_link1_mac_key: [$conf->{cgi}{$sn_link1_mac_key}], cgi::$sn_link2_mac_key: [$conf->{cgi}{$sn_link2_mac_key}], cgi::$ifn_link1_mac_key: [$conf->{cgi}{$ifn_link1_mac_key}], cgi::$ifn_link2_mac_key: [$conf->{cgi}{$ifn_link2_mac_key}].\n");
			}
			$i++;
		}
		
		### Now to build the fence strings.
		my $fence_order = $conf->{install_manifest}{$file}{common}{cluster}{fence}{order};
		$conf->{cgi}{anvil_fence_order} = $fence_order;
		
		# Nodes
		#record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_name: [$conf->{cgi}{anvil_node1_name}], cgi::anvil_node2_name: [$conf->{cgi}{anvil_node2_name}]\n");
		my $node1_name = $conf->{cgi}{anvil_node1_name};
		my $node2_name = $conf->{cgi}{anvil_node2_name};
		my $delay_set  = 0;
		my $delay_node = $conf->{install_manifest}{$file}{common}{cluster}{fence}{delay_node};
		my $delay_time = $conf->{install_manifest}{$file}{common}{cluster}{fence}{delay};
		foreach my $node ($conf->{cgi}{anvil_node1_name}, $conf->{cgi}{anvil_node2_name})
		{
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node]\n");
			my $i = 1;
			foreach my $method (split/,/, $fence_order)
			{
				if ($method eq "kvm")
				{
					# Only ever one, but...
					my $j = 1;
					foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{kvm}})
					{
						my $port            = $conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{port};
						my $user            = $conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{user};
						my $password        = $conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password};
						my $password_script = $conf->{install_manifest}{$file}{node}{$node}{kvm}{$reference}{password_script};
						
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
						$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
						record($conf, "$THIS_FILE ".__LINE__."; node: [$node], fence method: [$method ($i)], string: [$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} ($j)]\n");
						$j++;
					}
				}
				elsif ($method eq "ipmi")
				{
					# Only ever one, but...
					my $j = 1;
					foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{ipmi}})
					{
						my $name            = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{name};
						my $ip              = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{ip};
						my $user            = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{user};
						my $password        = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password};
						my $password_script = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$reference}{password_script};
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
						$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], fence method: [$method ($i)], string: [$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} ($j)]\n");
						$j++;
					}
				}
				elsif ($method eq "pdu")
				{
					# Here we can have > 1.
					my $j = 1;
					foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{pdu}})
					{
						my $port            = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{port};
						my $user            = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{user};
						my $password        = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password};
						my $password_script = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$reference}{password_script};
						
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
						$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], fence method: [$method ($i)], string: [$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} ($j)]\n");
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
				foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{kvm}})
				{
					my $name            = $conf->{install_manifest}{$file}{common}{kvm}{$reference}{name};
					my $ip              = $conf->{install_manifest}{$file}{common}{kvm}{$reference}{ip};
					my $user            = $conf->{install_manifest}{$file}{common}{kvm}{$reference}{user};
					my $password        = $conf->{install_manifest}{$file}{common}{kvm}{$reference}{password};
					my $password_script = $conf->{install_manifest}{$file}{common}{kvm}{$reference}{password_script};
					my $agent           = $conf->{install_manifest}{$file}{common}{kvm}{$reference}{agent};
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
					$conf->{fence}{device}{$device}{name}{$reference}{string} = $string;
					record($conf, "$THIS_FILE ".__LINE__."; fence device: [$device], name: [$name], string: [$conf->{fence}{device}{$device}{name}{$reference}{string}]\n");
				}
			}
			if ($device eq "ipmi")
			{
				foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{ipmi}})
				{
					my $name            = $conf->{install_manifest}{$file}{common}{ipmi}{$reference}{name};
					my $ip              = $conf->{install_manifest}{$file}{common}{ipmi}{$reference}{ip};
					my $user            = $conf->{install_manifest}{$file}{common}{ipmi}{$reference}{user};
					my $password        = $conf->{install_manifest}{$file}{common}{ipmi}{$reference}{password};
					my $password_script = $conf->{install_manifest}{$file}{common}{ipmi}{$reference}{password_script};
					my $agent           = $conf->{install_manifest}{$file}{common}{ipmi}{$reference}{agent};
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
					$conf->{fence}{device}{$device}{name}{$reference}{string} = $string;
					#record($conf, "$THIS_FILE ".__LINE__."; fence device: [$device], name: [$name], string: [$conf->{fence}{device}{$device}{name}{$reference}{string}]\n");
				}
			}
			if ($device eq "pdu")
			{
				foreach my $reference (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{pdu}})
				{
					my $name            = $conf->{install_manifest}{$file}{common}{pdu}{$reference}{name};
					my $ip              = $conf->{install_manifest}{$file}{common}{pdu}{$reference}{ip};
					my $user            = $conf->{install_manifest}{$file}{common}{pdu}{$reference}{user};
					my $password        = $conf->{install_manifest}{$file}{common}{pdu}{$reference}{password};
					my $password_script = $conf->{install_manifest}{$file}{common}{pdu}{$reference}{password_script};
					my $agent           = $conf->{install_manifest}{$file}{common}{pdu}{$reference}{agent};
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
					$conf->{fence}{device}{$device}{name}{$reference}{string} = $string;
					#record($conf, "$THIS_FILE ".__LINE__."; fence device: [$device], name: [$name], string: [$conf->{fence}{device}{$device}{name}{$reference}{string}]\n");
				}
			}
		}
		
		# Some system stuff.
		$conf->{sys}{post_join_delay} = $conf->{install_manifest}{$file}{common}{cluster}{fence}{post_join_delay};
		$conf->{sys}{update_os}       = $conf->{install_manifest}{$file}{common}{update}{os};
		#record($conf, "$THIS_FILE ".__LINE__."; sys::post_join_delay: [$conf->{sys}{post_join_delay}], sys::update_os: [$conf->{sys}{update_os}]\n");
		if ((lc($conf->{install_manifest}{$file}{common}{update}{os}) eq "false") || (lc($conf->{install_manifest}{$file}{common}{update}{os}) eq "no"))
		{
			$conf->{sys}{update_os} = 0;
			record($conf, "$THIS_FILE ".__LINE__."; sys::update_os: [$conf->{sys}{update_os}]\n");
		}
	}
	else
	{
		# File is gone. ;_;
		my $message = AN::Common::get_string($conf, { key => "message_0350", variables => {
			manifest_file	=>	$manifest_file,
		}});
		print AN::Common::template($conf, "config.html", "load-manifest-failure", {
			message	=>	$message,
		});
	}
	
	return(0);
}

# This looks for existing install manifest files and displays those it finds.
sub show_existing_install_manifests
{
	my ($conf) = @_;
	
	my $header_printed = 0;
	local(*DIR);
	opendir(DIR, $conf->{path}{apache_manifests_dir}) or die "Failed to open the directory: [$conf->{path}{apache_manifests_dir}], error was: $!\n";
	while (my $file = readdir(DIR))
	{
		next if (($file eq ".") or ($file eq ".."));
		if ($file =~ /^install-manifest_(.*?)_(\d+-\d+-\d+)_(\d+-\d+-\d+).xml/)
		{
			my $anvil =  $1;
			my $date  =  $2;
			my $time  =  $3;
			   $time  =~ s/-/:/g;
			record($conf, "$THIS_FILE ".__LINE__."; anvil: [$anvil], date: [$date], time: [$time]\n");
			$conf->{manifest_file}{$file}{anvil} = AN::Common::get_string($conf, { key => "message_0346", variables => {
									anvil	=>	$anvil,
									date	=>	$date,
									'time'	=>	$time,
								}});
			if (not $header_printed)
			{
				print AN::Common::template($conf, "config.html", "install-manifest-header");
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
			record($conf, "$THIS_FILE ".__LINE__."; anvil: [$anvil], date: [$date], time: [$time]\n");
			$conf->{manifest_file}{$file}{anvil} = AN::Common::get_string($conf, { key => "message_0346", variables => {
									anvil	=>	$anvil,
									date	=>	$date,
									'time'	=>	$time,
								}});
			if (not $header_printed)
			{
				print AN::Common::template($conf, "config.html", "install-manifest-header");
				$header_printed = 1;
			}
		}
	}
	foreach my $file (sort {$b cmp $a} keys %{$conf->{manifest_file}})
	{
		print AN::Common::template($conf, "config.html", "install-manifest-entry", {
			description	=>	$conf->{manifest_file}{$file}{anvil},
			load		=>	"?config=true&task=create-install-manifest&load=$file",
			download	=>	$conf->{path}{apache_manifests_url}."/".$file,
			run		=>	"?config=true&task=create-install-manifest&run=$file",
			'delete'	=>	"?config=true&task=create-install-manifest&delete=$file",
		});
	}
	if ($header_printed)
	{
		print AN::Common::template($conf, "config.html", "install-manifest-footer");
	}
	
	return(0);
}

# This takes an IP, compares it to the BCN, SN and IFN networks and returns the
# netmask from the matched network.
sub get_netmask_from_ip
{
	my ($conf, $ip) = @_;
	
	### TODO: Make this support all possible subnet masks.
	my $netmask = "";
	
	# Create short versions of the three networks that I can use in the
	# regex.
	my $short_bcn = "";
	my $short_sn = "";
	my $short_ifn = "";
	
	# BCN
	if ($conf->{cgi}{anvil_bcn_subnet} eq "255.0.0.0")
	{
		$short_bcn = ($conf->{cgi}{anvil_bcn_network} =~ /^(\d+\.)/)[0];
	}
	elsif ($conf->{cgi}{anvil_bcn_subnet} eq "255.255.0.0")
	{
		$short_bcn = ($conf->{cgi}{anvil_bcn_network} =~ /^(\d+\.\d+\.)/)[0];
	}
	elsif ($conf->{cgi}{anvil_bcn_subnet} eq "255.255.255.0")
	{
		$short_bcn = ($conf->{cgi}{anvil_bcn_network} =~ /^(\d+\.\d+\.\d+\.)/)[0];
	}
	
	# SN
	if ($conf->{cgi}{anvil_sn_subnet} eq "255.0.0.0")
	{
		$short_sn = ($conf->{cgi}{anvil_sn_network} =~ /^(\d+\.)/)[0];
	}
	elsif ($conf->{cgi}{anvil_sn_subnet} eq "255.255.0.0")
	{
		$short_sn = ($conf->{cgi}{anvil_sn_network} =~ /^(\d+\.\d+\.)/)[0];
	}
	elsif ($conf->{cgi}{anvil_sn_subnet} eq "255.255.255.0")
	{
		$short_sn = ($conf->{cgi}{anvil_sn_network} =~ /^(\d+\.\d+\.\d+\.)/)[0];
	}
	
	# IFN 
	if ($conf->{cgi}{anvil_ifn_subnet} eq "255.0.0.0")
	{
		$short_ifn = ($conf->{cgi}{anvil_ifn_network} =~ /^(\d+\.)/)[0];
	}
	elsif ($conf->{cgi}{anvil_ifn_subnet} eq "255.255.0.0")
	{
		$short_ifn = ($conf->{cgi}{anvil_ifn_network} =~ /^(\d+\.\d+\.)/)[0];
	}
	elsif ($conf->{cgi}{anvil_ifn_subnet} eq "255.255.255.0")
	{
		$short_ifn = ($conf->{cgi}{anvil_ifn_network} =~ /^(\d+\.\d+\.\d+\.)/)[0];
	}
	record($conf, "$THIS_FILE ".__LINE__."; short_bcn: [$short_bcn], short_sn: [$short_sn], short_ifn: [$short_ifn]\n");
	
	if ($ip =~ /^$short_bcn/)
	{
		$netmask = $conf->{cgi}{anvil_bcn_subnet};
		record($conf, "$THIS_FILE ".__LINE__."; netmask: [$netmask]\n");
	}
	elsif ($ip =~ /^$short_sn/)
	{
		$netmask = $conf->{cgi}{anvil_sn_subnet};
		record($conf, "$THIS_FILE ".__LINE__."; netmask: [$netmask]\n");
	}
	elsif ($ip =~ /^$short_ifn/)
	{
		$netmask = $conf->{cgi}{anvil_ifn_subnet};
		record($conf, "$THIS_FILE ".__LINE__."; netmask: [$netmask]\n");
	}
	
	record($conf, "$THIS_FILE ".__LINE__."; netmask: [$netmask]\n");
	return($netmask);
}

# Generates a UUID
sub generate_uuid
{
	my ($conf) = @_;
	
	my $uuid = "";
	my $shell_call = "$conf->{path}{uuidgen} -r";
	open(my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		$uuid = lc($_);
		last;
	}
	
	# Did we get a sane value?
	if ($uuid !~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)
	{
		# derp
		die "Generated UUID: [$uuid] does not appear to be valie.\n";
		$uuid = "";
	}
	
	return($uuid);
}

# This takes the (sanity-checked) form data and generates the XML manifest file
# and then returns the download URL.
sub generate_install_manifest
{
	my ($conf) = @_;
	
	# Break up hostsnames
	my ($node1_short_name)    = ($conf->{cgi}{anvil_node1_name}    =~ /^(.*?)\./);
	my ($node2_short_name)    = ($conf->{cgi}{anvil_node2_name}    =~ /^(.*?)\./);
	my ($switch1_short_name)  = ($conf->{cgi}{anvil_switch1_name}  =~ /^(.*?)\./);
	my ($switch2_short_name)  = ($conf->{cgi}{anvil_switch2_name}  =~ /^(.*?)\./);
	my ($pdu1_short_name)     = ($conf->{cgi}{anvil_pdu1_name}     =~ /^(.*?)\./);
	my ($pdu2_short_name)     = ($conf->{cgi}{anvil_pdu2_name}     =~ /^(.*?)\./);
	my ($pdu3_short_name)     = ($conf->{cgi}{anvil_pdu3_name}     =~ /^(.*?)\./);
	my ($pdu4_short_name)     = ($conf->{cgi}{anvil_pdu4_name}     =~ /^(.*?)\./);
	my ($ups1_short_name)     = ($conf->{cgi}{anvil_ups1_name}     =~ /^(.*?)\./);
	my ($ups2_short_name)     = ($conf->{cgi}{anvil_ups2_name}     =~ /^(.*?)\./);
	my ($striker1_short_name) = ($conf->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
	my ($striker2_short_name) = ($conf->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
	my $date      =  get_date($conf);
	my $file_date =  $date;
	   $file_date =~ s/ /_/g;
	
	# Note yet supported but will be later.
	$conf->{cgi}{anvil_node1_ipmi_password} = $conf->{cgi}{anvil_node1_ipmi_password} ? $conf->{cgi}{anvil_node1_ipmi_password} : $conf->{cgi}{anvil_password};
	$conf->{cgi}{anvil_node1_ipmi_user}     = $conf->{cgi}{anvil_node1_ipmi_user}     ? $conf->{cgi}{anvil_node1_ipmi_user}     : "admin";
	$conf->{cgi}{anvil_node2_ipmi_password} = $conf->{cgi}{anvil_node2_ipmi_password} ? $conf->{cgi}{anvil_node2_ipmi_password} : $conf->{cgi}{anvil_password};
	$conf->{cgi}{anvil_node2_ipmi_user}     = $conf->{cgi}{anvil_node2_ipmi_user}     ? $conf->{cgi}{anvil_node2_ipmi_user}     : "admin";
	
	# Generate UUIDs if needed.
	$conf->{cgi}{anvil_node1_uuid}          = generate_uuid($conf) if not $conf->{cgi}{anvil_node1_uuid};
	$conf->{cgi}{anvil_node2_uuid}          = generate_uuid($conf) if not $conf->{cgi}{anvil_node2_uuid};
	
	### TODO: This isn't set for some reason, fix
	$conf->{cgi}{anvil_open_vnc_ports} = $conf->{sys}{install_manifest}{open_vnc_ports} if not $conf->{cgi}{anvil_open_vnc_ports};
	
	# This is currently not set by the program, but will be later.
	$conf->{cgi}{anvil_mtu_size} = $conf->{sys}{install_manifest}{'default'}{mtu_size} if not $conf->{cgi}{anvil_mtu_size};
	
	# Use the subnet mask of the IPMI devices by comparing their IP to that
	# of the BCN and IFN, and use the netmask of the matching network.
	my $node1_ipmi_netmask = get_netmask_from_ip($conf, $conf->{cgi}{anvil_node1_ipmi_ip});
	my $node2_ipmi_netmask = get_netmask_from_ip($conf, $conf->{cgi}{anvil_node2_ipmi_ip});
	
	### TODO: Get the node and dashboard UUIDs if not yet set.
	
	### KVM-based fencing is supported but not documented. Sample entries
	### are here for those who might ask for it when building test Anvil!
	### systems later.
	# Many things are currently static but might be made configurable later.
	my $xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>

<!--
Generated on:    $date
Striker Version: $conf->{sys}{version}
-->

<config>
	<node name=\"$conf->{cgi}{anvil_node1_name}\" uuid=\"$conf->{cgi}{anvil_node1_uuid}\">
		<network>
			<bcn ip=\"$conf->{cgi}{anvil_node1_bcn_ip}\" />
			<sn ip=\"$conf->{cgi}{anvil_node1_sn_ip}\" />
			<ifn ip=\"$conf->{cgi}{anvil_node1_ifn_ip}\" />
		</network>
		<ipmi>
			<on reference=\"ipmi_n01\" ip=\"$conf->{cgi}{anvil_node1_ipmi_ip}\" netmask=\"$node1_ipmi_netmask\" user=\"$conf->{cgi}{anvil_node1_ipmi_user}\" password=\"$conf->{cgi}{anvil_node1_ipmi_password}\" gateway=\"\" />
		</ipmi>
		<pdu>
			<on reference=\"pdu01\" port=\"$conf->{cgi}{anvil_node1_pdu1_outlet}\" />
			<on reference=\"pdu02\" port=\"$conf->{cgi}{anvil_node1_pdu2_outlet}\" />
			<on reference=\"pdu03\" port=\"$conf->{cgi}{anvil_node1_pdu3_outlet}\" />
			<on reference=\"pdu04\" port=\"$conf->{cgi}{anvil_node1_pdu4_outlet}\" />
		</pdu>
		<kvm>
			<!-- port == virsh name of VM -->
			<on reference=\"kvm_host\" port=\"\" />
		</kvm>
		<interfaces>
			<interface name=\"bcn_link1\" mac=\"$conf->{cgi}{anvil_node1_bcn_link1_mac}\" />
			<interface name=\"bcn_link2\" mac=\"$conf->{cgi}{anvil_node1_bcn_link2_mac}\" />
			<interface name=\"sn_link1\" mac=\"$conf->{cgi}{anvil_node1_sn_link1_mac}\" />
			<interface name=\"sn_link2\" mac=\"$conf->{cgi}{anvil_node1_sn_link2_mac}\" />
			<interface name=\"ifn_link1\" mac=\"$conf->{cgi}{anvil_node1_ifn_link1_mac}\" />
			<interface name=\"ifn_link2\" mac=\"$conf->{cgi}{anvil_node1_ifn_link2_mac}\" />
		</interfaces>
	</node>
	<node name=\"$conf->{cgi}{anvil_node2_name}\" uuid=\"$conf->{cgi}{anvil_node2_uuid}\">
		<network>
			<bcn ip=\"$conf->{cgi}{anvil_node2_bcn_ip}\" />
			<sn ip=\"$conf->{cgi}{anvil_node2_sn_ip}\" />
			<ifn ip=\"$conf->{cgi}{anvil_node2_ifn_ip}\" />
		</network>
		<ipmi>
			<on reference=\"ipmi_n02\" ip=\"$conf->{cgi}{anvil_node2_ipmi_ip}\" netmask=\"$node2_ipmi_netmask\" user=\"$conf->{cgi}{anvil_node2_ipmi_user}\" password=\"$conf->{cgi}{anvil_node2_ipmi_password}\" gateway=\"\" />
		</ipmi>
		<pdu>
			<on reference=\"pdu01\" port=\"$conf->{cgi}{anvil_node2_pdu1_outlet}\" />
			<on reference=\"pdu02\" port=\"$conf->{cgi}{anvil_node2_pdu2_outlet}\" />
			<on reference=\"pdu03\" port=\"$conf->{cgi}{anvil_node2_pdu3_outlet}\" />
			<on reference=\"pdu04\" port=\"$conf->{cgi}{anvil_node2_pdu4_outlet}\" />
		</pdu>
		<kvm>
			<on reference=\"kvm_host\" port=\"\" />
		</kvm>
		<interfaces>
			<interface name=\"bcn_link1\" mac=\"$conf->{cgi}{anvil_node2_bcn_link1_mac}\" />
			<interface name=\"bcn_link2\" mac=\"$conf->{cgi}{anvil_node2_bcn_link2_mac}\" />
			<interface name=\"sn_link1\" mac=\"$conf->{cgi}{anvil_node2_sn_link1_mac}\" />
			<interface name=\"sn_link2\" mac=\"$conf->{cgi}{anvil_node2_sn_link2_mac}\" />
			<interface name=\"ifn_link1\" mac=\"$conf->{cgi}{anvil_node2_ifn_link1_mac}\" />
			<interface name=\"ifn_link2\" mac=\"$conf->{cgi}{anvil_node2_ifn_link2_mac}\" />
		</interfaces>
	</node>
	<common>
		<networks>
			<bcn netblock=\"$conf->{cgi}{anvil_bcn_network}\" netmask=\"$conf->{cgi}{anvil_bcn_subnet}\" gateway=\"\" defroute=\"no\" />
			<sn  netblock=\"$conf->{cgi}{anvil_sn_network}\" netmask=\"$conf->{cgi}{anvil_sn_subnet}\" gateway=\"\" defroute=\"no\" />
			<ifn netblock=\"$conf->{cgi}{anvil_ifn_network}\" netmask=\"$conf->{cgi}{anvil_ifn_subnet}\" gateway=\"$conf->{cgi}{anvil_ifn_gateway}\" dns1=\"$conf->{cgi}{anvil_dns1}\" dns2=\"$conf->{cgi}{anvil_dns2}\" ntp1=\"$conf->{cgi}{anvil_ntp1}\" ntp2=\"$conf->{cgi}{anvil_ntp2}\" defroute=\"yes\" />
			<bonding opts=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0\">
				<bcn name=\"bcn_bond1\" primary=\"bcn_link1\" secondary=\"bcn_link2\" />
				<sn name=\"sn_bond1\" primary=\"sn_link1\" secondary=\"sn_link2\" />
				<ifn name=\"ifn_bond1\" primary=\"ifn_link1\" secondary=\"ifn_link2\" />
			</bonding>
			<bridges>
				<bridge name=\"ifn_bridge1\" on=\"ifn\" />
			</bridges>
			<mtu size=\"$conf->{cgi}{anvil_mtu_size}\" />
		</networks>
		<repository urls=\"$conf->{cgi}{anvil_repositories}\" />
		<media_library size=\"$conf->{cgi}{anvil_media_library_size}\" units=\"$conf->{cgi}{anvil_media_library_unit}\" />
		<storage_pool_1 size=\"$conf->{cgi}{anvil_storage_pool1_size}\" units=\"$conf->{cgi}{anvil_storage_pool1_unit}\" />
		<anvil prefix=\"$conf->{cgi}{anvil_prefix}\" sequence=\"$conf->{cgi}{anvil_sequence}\" domain=\"$conf->{cgi}{anvil_domain}\" password=\"$conf->{cgi}{anvil_password}\" striker_user=\"$conf->{cgi}{striker_user}\" striker_databas=\"$conf->{cgi}{striker_database}\" />
		<ssh keysize=\"8191\" />
		<cluster name=\"$conf->{cgi}{anvil_name}\">
			<!-- Set the order to 'kvm' if building on KVM-backed VMs -->
			<fence order=\"ipmi,pdu\" post_join_delay=\"30\" delay=\"15\" delay_node=\"$conf->{cgi}{anvil_node1_name}\" />
		</cluster>
		<switch>
			<switch name=\"$conf->{cgi}{anvil_switch1_name}\" ip=\"$conf->{cgi}{anvil_switch1_ip}\" />
";
	record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_switch2_name: [$conf->{cgi}{anvil_switch2_name}]\n");
	if (($conf->{cgi}{anvil_switch2_name}) && ($conf->{cgi}{anvil_switch2_name} ne "--"))
	{
		$xml .= "\t\t\t<switch name=\"$conf->{cgi}{anvil_switch2_name}\" ip=\"$conf->{cgi}{anvil_switch2_ip}\" />";
	}
	$xml .= "
		</switch>
		<ups>
			<ups name=\"$conf->{cgi}{anvil_ups1_name}\" type=\"apc\" port=\"3551\" ip=\"$conf->{cgi}{anvil_ups1_ip}\" />
			<ups name=\"$conf->{cgi}{anvil_ups2_name}\" type=\"apc\" port=\"3552\" ip=\"$conf->{cgi}{anvil_ups2_ip}\" />
		</ups>
		<pdu>";
	# PDU 1 and 2 always exist.
	my $pdu1_agent = $conf->{cgi}{anvil_pdu1_agent} ? $conf->{cgi}{anvil_pdu1_agent} : $conf->{sys}{install_manifest}{anvil_pdu_agent};
	$xml .= "
			<pdu reference=\"pdu01\" name=\"$conf->{cgi}{anvil_pdu1_name}\" ip=\"$conf->{cgi}{anvil_pdu1_ip}\" agent=\"$pdu1_agent\" />";
	my $pdu2_agent = $conf->{cgi}{anvil_pdu2_agent} ? $conf->{cgi}{anvil_pdu2_agent} : $conf->{sys}{install_manifest}{anvil_pdu_agent};
	$xml .= "
			<pdu reference=\"pdu02\" name=\"$conf->{cgi}{anvil_pdu2_name}\" ip=\"$conf->{cgi}{anvil_pdu2_ip}\" agent=\"$pdu2_agent\" />";
	if ($conf->{cgi}{anvil_pdu3_name})
	{
		my $pdu3_agent = $conf->{cgi}{anvil_pdu3_agent} ? $conf->{cgi}{anvil_pdu3_agent} : $conf->{sys}{install_manifest}{anvil_pdu_agent};
		$xml .= "
			<pdu reference=\"pdu03\" name=\"$conf->{cgi}{anvil_pdu3_name}\" ip=\"$conf->{cgi}{anvil_pdu3_ip}\" agent=\"$pdu3_agent\" />";
	}
	if ($conf->{cgi}{anvil_pdu4_name})
	{
		my $pdu4_agent = $conf->{cgi}{anvil_pdu4_agent} ? $conf->{cgi}{anvil_pdu4_agent} : $conf->{sys}{install_manifest}{anvil_pdu_agent};
		$xml .= "
			<pdu reference=\"pdu04\" name=\"$conf->{cgi}{anvil_pdu4_name}\" ip=\"$conf->{cgi}{anvil_pdu4_ip}\" agent=\"$pdu4_agent\" />";
	}
	
	record($conf, "$THIS_FILE ".__LINE__."; sys::install_manifest::use_anvil-kick-apc-ups: [$conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'}], sys::install_manifest::use_safe_anvil_start: [$conf->{sys}{install_manifest}{use_safe_anvil_start}], sys::install_manifest::use_scancore: [$conf->{sys}{install_manifest}{use_scancore}]\n");
	my $say_use_anvil_kick_apc_ups = $conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'} ? "true" : "false";
	my $say_use_safe_anvil_start   = $conf->{sys}{install_manifest}{use_safe_anvil_start}     ? "true" : "false";
	my $say_use_scancore           = $conf->{sys}{install_manifest}{use_scancore}             ? "true" : "false";
	record($conf, "$THIS_FILE ".__LINE__."; say_use_anvil_kick_apc_ups: [$say_use_anvil_kick_apc_ups], say_use_safe_anvil_start: [$say_use_safe_anvil_start], say_use_scancore: [$say_use_scancore]\n");
	
	$xml .= "
		</pdu>
		<ipmi>
			<ipmi reference=\"ipmi_n01\" agent=\"fence_ipmilan\" />
			<ipmi reference=\"ipmi_n02\" agent=\"fence_ipmilan\" />
		</ipmi>
		<kvm>
			<kvm reference=\"kvm_host\" ip=\"192.168.122.1\" user=\"root\" password_script=\"\" agent=\"fence_virsh\" />
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
			<striker name=\"$conf->{cgi}{anvil_striker1_name}\" bcn_ip=\"$conf->{cgi}{anvil_striker1_bcn_ip}\" ifn_ip=\"$conf->{cgi}{anvil_striker1_ifn_ip}\" database=\"\" user=\"\" password=\"\" uuid=\"\" />
			<striker name=\"$conf->{cgi}{anvil_striker2_name}\" bcn_ip=\"$conf->{cgi}{anvil_striker2_bcn_ip}\" ifn_ip=\"$conf->{cgi}{anvil_striker2_ifn_ip}\" database=\"\" user=\"\" password=\"\" uuid=\"\" />
		</striker>
		<update os=\"true\" />
		<iptables>
			<vnc ports=\"$conf->{cgi}{anvil_open_vnc_ports}\" />
		</iptables>
		<servers>
			<!-- This isn't used anymore, but this section may be useful for other things in the future, -->
			<!-- <provision use_spice_graphics=\"0\" /> -->
		</servers>
		<tools>
			<use safe_anvil_start=\"$say_use_safe_anvil_start\" anvil-kick-apc-ups=\"$say_use_anvil_kick_apc_ups\" scancore=\"$say_use_scancore\" />
		</tools>
	</common>
</config>
";
	
	# Write out the file.
	my $xml_file    =  "install-manifest_".$conf->{cgi}{anvil_name}."_".$file_date.".xml";
	   $xml_file    =~ s/:/-/g;	# Make the filename FAT-compatible.
	my $target_path =  $conf->{path}{apache_manifests_dir}."/".$xml_file;
	my $target_url  =  $conf->{path}{apache_manifests_url}."/".$xml_file;
	open (my $file_handle, ">", $target_path) or die "Failed to write: [$target_path], the error was: $!\n";
	print $file_handle $xml;
	close $file_handle;
	
	return($target_url, $xml_file);
}

# This shows a summary of the install manifest and asks the user to choose a
# node to run it against (verifying they want to do it in the process).
sub confirm_install_manifest_run
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; confirm_install_manifest_run()\n");
	
	# Show the manifest form.
	$conf->{cgi}{anvil_node1_bcn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node1_bcn_link1_mac};
	$conf->{cgi}{anvil_node1_bcn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node1_bcn_link2_mac};
	$conf->{cgi}{anvil_node1_sn_link1_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node1_sn_link1_mac};
	$conf->{cgi}{anvil_node1_sn_link2_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node1_sn_link2_mac};
	$conf->{cgi}{anvil_node1_ifn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node1_ifn_link1_mac};
	$conf->{cgi}{anvil_node1_ifn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node1_ifn_link2_mac};
	$conf->{cgi}{anvil_node2_bcn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node2_bcn_link1_mac};
	$conf->{cgi}{anvil_node2_bcn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node2_bcn_link2_mac};
	$conf->{cgi}{anvil_node2_sn_link1_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node2_sn_link1_mac};
	$conf->{cgi}{anvil_node2_sn_link2_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node2_sn_link2_mac};
	$conf->{cgi}{anvil_node2_ifn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node2_ifn_link1_mac};
	$conf->{cgi}{anvil_node2_ifn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $conf->{cgi}{anvil_node2_ifn_link2_mac};
	
	$conf->{cgi}{anvil_node1_pdu1_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_node1_pdu1_outlet};
	$conf->{cgi}{anvil_node1_pdu2_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_node1_pdu2_outlet};
	$conf->{cgi}{anvil_node1_pdu3_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_node1_pdu3_outlet};
	$conf->{cgi}{anvil_node1_pdu4_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_node1_pdu4_outlet};
	$conf->{cgi}{anvil_node2_pdu1_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_node2_pdu1_outlet};
	$conf->{cgi}{anvil_node2_pdu2_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_node2_pdu2_outlet};
	$conf->{cgi}{anvil_node2_pdu3_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_node2_pdu3_outlet};
	$conf->{cgi}{anvil_node2_pdu4_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_node2_pdu4_outlet};
	$conf->{cgi}{anvil_dns1}                = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_dns1};
	$conf->{cgi}{anvil_dns2}                = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_dns2};
	$conf->{cgi}{anvil_ntp1}                = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_ntp1};
	$conf->{cgi}{anvil_ntp2}                = "<span class=\"highlight_unavailable\">--</span>" if not $conf->{cgi}{anvil_ntp2};
	
	# If the first storage pool is a percentage, calculate
	# the percentage of the second. Otherwise, set storage
	# pool 2 to just same 'remainder'.
	my $say_storage_pool_1 = "$conf->{cgi}{anvil_storage_pool1_size} $conf->{cgi}{anvil_storage_pool1_unit}";
	my $say_storage_pool_2 = "<span class=\"highlight_unavailable\">#!string!message_0357!#</span>";
	if ($conf->{cgi}{anvil_storage_pool1_unit} eq "%")
	{
		$say_storage_pool_2 = (100 - $conf->{cgi}{anvil_storage_pool1_size})." %";
	}
	
	# If this is the first load, the use the current IP and
	# password.
	$conf->{cgi}{anvil_node1_current_ip}       = $conf->{cgi}{anvil_node1_bcn_ip} if not $conf->{cgi}{anvil_node1_current_ip};;
	$conf->{cgi}{anvil_node1_current_password} = $conf->{cgi}{anvil_password}     if not $conf->{cgi}{anvil_node1_current_password};
	$conf->{cgi}{anvil_node2_current_ip}       = $conf->{cgi}{anvil_node2_bcn_ip} if not $conf->{cgi}{anvil_node2_current_ip};
	$conf->{cgi}{anvil_node2_current_password} = $conf->{cgi}{anvil_password}     if not $conf->{cgi}{anvil_node2_current_password};
	# I don't ask the user for the port range at this time,
	# so it's possible the number of ports to open isn't in
	# the manifest.
	$conf->{cgi}{anvil_open_vnc_ports} = $conf->{sys}{install_manifest}{open_vnc_ports} if not $conf->{cgi}{anvil_open_vnc_ports};
	my $say_repos =  $conf->{cgi}{anvil_repositories};
		$say_repos =~ s/,/<br \/>/;
		$say_repos =  "--" if not $say_repos;
	
	record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_name: [$conf->{cgi}{anvil_node1_name}], cgi::anvil_node2_name: [$conf->{cgi}{anvil_node2_name}]\n");
	print AN::Common::template($conf, "config.html", "confirm-anvil-manifest-run", {
		form_file			=>	"/cgi-bin/striker",
		say_storage_pool_1		=>	$say_storage_pool_1,
		say_storage_pool_2		=>	$say_storage_pool_2,
		anvil_node1_current_ip		=>	$conf->{cgi}{anvil_node1_current_ip},
		anvil_node1_current_password	=>	$conf->{cgi}{anvil_node1_current_password},
		anvil_node2_current_ip		=>	$conf->{cgi}{anvil_node2_current_ip},
		anvil_node2_current_password	=>	$conf->{cgi}{anvil_node2_current_password},
		anvil_password			=>	$conf->{cgi}{anvil_password},
		anvil_bcn_network		=>	$conf->{cgi}{anvil_bcn_network},
		anvil_bcn_subnet		=>	$conf->{cgi}{anvil_bcn_subnet},
		anvil_sn_network		=>	$conf->{cgi}{anvil_sn_network},
		anvil_sn_subnet			=>	$conf->{cgi}{anvil_sn_subnet},
		anvil_ifn_network		=>	$conf->{cgi}{anvil_ifn_network},
		anvil_ifn_subnet		=>	$conf->{cgi}{anvil_ifn_subnet},
		anvil_media_library_size	=>	$conf->{cgi}{anvil_media_library_size},
		anvil_media_library_unit	=>	$conf->{cgi}{anvil_media_library_unit},
		anvil_storage_pool1_size	=>	$conf->{cgi}{anvil_storage_pool1_size},
		anvil_storage_pool1_unit	=>	$conf->{cgi}{anvil_storage_pool1_unit},
		anvil_name			=>	$conf->{cgi}{anvil_name},
		anvil_node1_name		=>	$conf->{cgi}{anvil_node1_name},
		anvil_node1_bcn_ip		=>	$conf->{cgi}{anvil_node1_bcn_ip},
		anvil_node1_bcn_link1_mac	=>	$conf->{cgi}{anvil_node1_bcn_link1_mac},
		anvil_node1_bcn_link2_mac	=>	$conf->{cgi}{anvil_node1_bcn_link2_mac},
		anvil_node1_ipmi_ip		=>	$conf->{cgi}{anvil_node1_ipmi_ip},
		anvil_node1_sn_ip		=>	$conf->{cgi}{anvil_node1_sn_ip},
		anvil_node1_sn_link1_mac	=>	$conf->{cgi}{anvil_node1_sn_link1_mac},
		anvil_node1_sn_link2_mac	=>	$conf->{cgi}{anvil_node1_sn_link2_mac},
		anvil_node1_ifn_ip		=>	$conf->{cgi}{anvil_node1_ifn_ip},
		anvil_node1_ifn_link1_mac	=>	$conf->{cgi}{anvil_node1_ifn_link1_mac},
		anvil_node1_ifn_link2_mac	=>	$conf->{cgi}{anvil_node1_ifn_link2_mac},
		anvil_node1_pdu1_outlet		=>	$conf->{cgi}{anvil_node1_pdu1_outlet},
		anvil_node1_pdu2_outlet		=>	$conf->{cgi}{anvil_node1_pdu2_outlet},
		anvil_node1_pdu3_outlet		=>	$conf->{cgi}{anvil_node1_pdu3_outlet},
		anvil_node1_pdu4_outlet		=>	$conf->{cgi}{anvil_node1_pdu4_outlet},
		anvil_node2_name		=>	$conf->{cgi}{anvil_node2_name},
		anvil_node2_bcn_ip		=>	$conf->{cgi}{anvil_node2_bcn_ip},
		anvil_node2_bcn_link1_mac	=>	$conf->{cgi}{anvil_node2_bcn_link1_mac},
		anvil_node2_bcn_link2_mac	=>	$conf->{cgi}{anvil_node2_bcn_link2_mac},
		anvil_node2_ipmi_ip		=>	$conf->{cgi}{anvil_node2_ipmi_ip},
		anvil_node2_sn_ip		=>	$conf->{cgi}{anvil_node2_sn_ip},
		anvil_node2_sn_link1_mac	=>	$conf->{cgi}{anvil_node2_sn_link1_mac},
		anvil_node2_sn_link2_mac	=>	$conf->{cgi}{anvil_node2_sn_link2_mac},
		anvil_node2_ifn_ip		=>	$conf->{cgi}{anvil_node2_ifn_ip},
		anvil_node2_ifn_link1_mac	=>	$conf->{cgi}{anvil_node2_ifn_link1_mac},
		anvil_node2_ifn_link2_mac	=>	$conf->{cgi}{anvil_node2_ifn_link2_mac},
		anvil_node2_pdu1_outlet		=>	$conf->{cgi}{anvil_node2_pdu1_outlet},
		anvil_node2_pdu2_outlet		=>	$conf->{cgi}{anvil_node2_pdu2_outlet},
		anvil_node2_pdu3_outlet		=>	$conf->{cgi}{anvil_node2_pdu3_outlet},
		anvil_node2_pdu4_outlet		=>	$conf->{cgi}{anvil_node2_pdu4_outlet},
		anvil_ifn_gateway		=>	$conf->{cgi}{anvil_ifn_gateway},
		anvil_dns1			=>	$conf->{cgi}{anvil_dns1},
		anvil_dns2			=>	$conf->{cgi}{anvil_dns2},
		anvil_ntp1			=>	$conf->{cgi}{anvil_ntp1},
		anvil_ntp2			=>	$conf->{cgi}{anvil_ntp2},
		anvil_pdu1_name			=>	$conf->{cgi}{anvil_pdu1_name},
		anvil_pdu2_name			=>	$conf->{cgi}{anvil_pdu2_name},
		anvil_pdu3_name			=>	$conf->{cgi}{anvil_pdu3_name},
		anvil_pdu4_name			=>	$conf->{cgi}{anvil_pdu4_name},
		anvil_open_vnc_ports		=>	$conf->{cgi}{anvil_open_vnc_ports},
		say_anvil_repos			=>	$say_repos,
		run				=>	$conf->{cgi}{run},
		striker_user			=>	$conf->{cgi}{striker_user},
		striker_database		=>	$conf->{cgi}{striker_database},
		anvil_striker1_user		=>	$conf->{cgi}{anvil_striker1_user},
		anvil_striker1_password		=>	$conf->{cgi}{anvil_striker1_password},
		anvil_striker1_database		=>	$conf->{cgi}{anvil_striker1_database},
		anvil_striker2_user		=>	$conf->{cgi}{anvil_striker2_user},
		anvil_striker2_password		=>	$conf->{cgi}{anvil_striker2_password},
		anvil_striker2_database		=>	$conf->{cgi}{anvil_striker2_database},
		anvil_mtu_size			=>	$conf->{cgi}{anvil_mtu_size},
	});
	
	return(0);
}

# This shows a summary of what the user selected and asks them to confirm that
# they are happy.
sub show_summary_manifest
{
	my ($conf) = @_;
	
	# Show the manifest form.
	my $say_repos =  $conf->{cgi}{anvil_repositories};
	   $say_repos =~ s/,/<br \/>/;
	   $say_repos = "#!string!symbol_0011!#" if not $say_repos;
	record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_name: [$conf->{cgi}{anvil_node1_name}], cgi::anvil_node2_name: [$conf->{cgi}{anvil_node2_name}]\n");

	# Open the table.
	print AN::Common::template($conf, "config.html", "install-manifest-summay-header", {
		form_file	=>	"/cgi-bin/striker",
	});
	
	# Nodes header
	print AN::Common::template($conf, "config.html", "install-manifest-summay-title", {
		title		=>	"#!string!title_0159!#",
	});
	
	# Node colum header.
	print AN::Common::template($conf, "config.html", "install-manifest-summay-column-header", {
		column1		=>	"#!string!header_0001!#",
		column2		=>	"#!string!header_0002!#",
	});
	
	# Node names
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0165!#",
		column1		=>	$conf->{cgi}{anvil_node1_name},
		column2		=>	$conf->{cgi}{anvil_node2_name},
	});
	
	# Node BCN IPs
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0166!#",
		column1		=>	$conf->{cgi}{anvil_node1_bcn_ip},
		column2		=>	$conf->{cgi}{anvil_node2_bcn_ip},
	});
	
	# Node IPMI BMC IPs
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0168!#",
		column1		=>	$conf->{cgi}{anvil_node1_ipmi_ip},
		column2		=>	$conf->{cgi}{anvil_node2_ipmi_ip},
	});
	
	# Node SN IPs
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0167!#",
		column1		=>	$conf->{cgi}{anvil_node1_sn_ip},
		column2		=>	$conf->{cgi}{anvil_node2_sn_ip},
	});
	
	# Node IFN IPs
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0169!#",
		column1		=>	$conf->{cgi}{anvil_node1_ifn_ip},
		column2		=>	$conf->{cgi}{anvil_node2_ifn_ip},
	});
	
	### PDUs are a little more complicated.
	foreach my $i (1..$conf->{sys}{install_manifest}{pdu_count})
	{
		my $say_pdu = "";
		if ($i == 1)    { $say_pdu = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
		elsif ($i == 2) { $say_pdu = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
		elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
		elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
		#record($conf, "$THIS_FILE ".__LINE__."; i: [$i], say_pdu: [$say_pdu]\n");
		
		my $say_pdu_name         = AN::Common::get_string($conf, {key => "row_0176", variables => { say_pdu => "$say_pdu" }});
		my $node1_pdu_outlet_key = "anvil_node1_pdu${i}_outlet";
		my $node2_pdu_outlet_key = "anvil_node2_pdu${i}_outlet";
		
		# PDUs
		print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
			row		=>	"$say_pdu_name",
			column1		=>	$conf->{cgi}{$node1_pdu_outlet_key} ? $conf->{cgi}{$node1_pdu_outlet_key} : "#!string!symbol_0011!#",
			column2		=>	$conf->{cgi}{$node2_pdu_outlet_key} ? $conf->{cgi}{$node2_pdu_outlet_key} : "#!string!symbol_0011!#",
		});
	}
	print AN::Common::template($conf, "config.html", "install-manifest-summay-spacer");
	
	# Strikers header
	print AN::Common::template($conf, "config.html", "install-manifest-summay-title", {
		title		=>	"#!string!title_0161!#",
	});
	
	# Striker colum header.
	print AN::Common::template($conf, "config.html", "install-manifest-summay-column-header", {
		column1		=>	"#!string!header_0014!#",
		column2		=>	"#!string!header_0015!#",
	});
	
	# Striker names
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0165!#",
		column1		=>	$conf->{cgi}{anvil_striker1_name},
		column2		=>	$conf->{cgi}{anvil_striker2_name},
	});
	
	# Striker BCN IP
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0166!#",
		column1		=>	$conf->{cgi}{anvil_striker1_bcn_ip},
		column2		=>	$conf->{cgi}{anvil_striker2_bcn_ip},
	});
	
	# Striker IFN IP
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0169!#",
		column1		=>	$conf->{cgi}{anvil_striker1_ifn_ip},
		column2		=>	$conf->{cgi}{anvil_striker2_ifn_ip},
	});
	print AN::Common::template($conf, "config.html", "install-manifest-summay-spacer");
	
	# Foundation Pack Header
	print AN::Common::template($conf, "config.html", "install-manifest-summay-title", {
		title		=>	"#!string!title_0160!#",
	});
	
	# Striker 2 colum header.
	print AN::Common::template($conf, "config.html", "install-manifest-summay-column-header", {
		column1		=>	"#!string!header_0003!#",
		column2		=>	"#!string!header_0004!#",
	});
	
	# Striker 4 column header.
	print AN::Common::template($conf, "config.html", "install-manifest-summay-four-column-header", {
		column1		=>	"#!string!header_0006!#",
		column2		=>	"#!string!header_0007!#",
		column3		=>	"#!string!header_0006!#",
		column4		=>	"#!string!header_0007!#",
	});
	
	# Switches
	print AN::Common::template($conf, "config.html", "install-manifest-summay-four-column-entry", {
		row		=>	"#!string!row_0195!#",
		column1		=>	$conf->{cgi}{anvil_switch1_name},
		column2		=>	$conf->{cgi}{anvil_switch1_ip},
		column3		=>	$conf->{cgi}{anvil_switch2_name},
		column4		=>	$conf->{cgi}{anvil_switch2_ip},
	});
	
	# UPSes
	print AN::Common::template($conf, "config.html", "install-manifest-summay-four-column-entry", {
		row		=>	"#!string!row_0197!#",
		column1		=>	$conf->{cgi}{anvil_ups1_name},
		column2		=>	$conf->{cgi}{anvil_ups1_ip},
		column3		=>	$conf->{cgi}{anvil_ups2_name},
		column4		=>	$conf->{cgi}{anvil_ups2_ip},
	});
	
	### PDUs are, surprise, a little more complicated.
	my $say_apc        = AN::Common::get_string($conf, {key => "brand_0017"});
	my $say_raritan    = AN::Common::get_string($conf, {key => "brand_0018"});
	record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_pdu1_agent: [$conf->{cgi}{anvil_pdu1_agent}], cgi::anvil_pdu2_agent: [$conf->{cgi}{anvil_pdu2_agent}], cgi::anvil_pdu3_agent: [$conf->{cgi}{anvil_pdu3_agent}], cgi::anvil_pdu4_agent: [$conf->{cgi}{anvil_pdu4_agent}]\n");
	my $say_pdu1_brand = $conf->{cgi}{anvil_pdu1_agent} eq "fence_raritan_snmp" ? $say_raritan : $say_apc;
	my $say_pdu2_brand = $conf->{cgi}{anvil_pdu2_agent} eq "fence_raritan_snmp" ? $say_raritan : $say_apc;
	my $say_pdu3_brand = $conf->{cgi}{anvil_pdu3_agent} eq "fence_raritan_snmp" ? $say_raritan : $say_apc;
	my $say_pdu4_brand = $conf->{cgi}{anvil_pdu4_agent} eq "fence_raritan_snmp" ? $say_raritan : $say_apc;
	record($conf, "$THIS_FILE ".__LINE__."; say_pdu1_brand: [$say_pdu1_brand], say_pdu2_brand: [$say_pdu2_brand], say_pdu3_brand: [$say_pdu3_brand], say_pdu4_brand: [$say_pdu4_brand]\n");
	if ($conf->{sys}{install_manifest}{pdu_count} == 2)
	{
		### Two PDU setup 
		# PDUs
		print AN::Common::template($conf, "config.html", "install-manifest-summay-four-column-entry", {
			row		=>	"#!string!row_0196!#",
			column1		=>	$conf->{cgi}{anvil_pdu1_name} ? "$conf->{cgi}{anvil_pdu1_name} ($say_pdu1_brand)" : "--",
			column2		=>	$conf->{cgi}{anvil_pdu1_ip}   ? $conf->{cgi}{anvil_pdu1_ip}                       : "--",
			column3		=>	$conf->{cgi}{anvil_pdu2_name} ? "$conf->{cgi}{anvil_pdu2_name} ($say_pdu2_brand)" : "--",
			column4		=>	$conf->{cgi}{anvil_pdu2_ip}   ? $conf->{cgi}{anvil_pdu2_ip}                       : "--",
		});
	}
	else
	{
		### Four PDU setup
		# 'PDU 1' will be for '1A' and '1B'.
		print AN::Common::template($conf, "config.html", "install-manifest-summay-four-column-entry", {
			row		=>	"#!string!row_0276!#",
			column1		=>	$conf->{cgi}{anvil_pdu1_name} ? "$conf->{cgi}{anvil_pdu1_name} ($say_pdu1_brand)" : "--",
			column2		=>	$conf->{cgi}{anvil_pdu1_ip}   ? $conf->{cgi}{anvil_pdu1_ip}                       : "--",
			column3		=>	$conf->{cgi}{anvil_pdu3_name} ? "$conf->{cgi}{anvil_pdu3_name} ($say_pdu3_brand)" : "--",
			column4		=>	$conf->{cgi}{anvil_pdu3_ip}   ? $conf->{cgi}{anvil_pdu3_ip}                       : "--",
		});
		# 'PDU 2' will be for '2A' and '2B'.
		print AN::Common::template($conf, "config.html", "install-manifest-summay-four-column-entry", {
			row		=>	"#!string!row_0277!#",
			column1		=>	$conf->{cgi}{anvil_pdu2_name} ? "$conf->{cgi}{anvil_pdu2_name} ($say_pdu2_brand)" : "--",
			column2		=>	$conf->{cgi}{anvil_pdu2_ip}   ? $conf->{cgi}{anvil_pdu2_ip}                       : "--",
			column3		=>	$conf->{cgi}{anvil_pdu4_name} ? "$conf->{cgi}{anvil_pdu4_name} ($say_pdu4_brand)" : "--",
			column4		=>	$conf->{cgi}{anvil_pdu4_ip}   ? $conf->{cgi}{anvil_pdu4_ip}                       : "--",
		});
	}
	print AN::Common::template($conf, "config.html", "install-manifest-summay-spacer");
	
	# Shared Variables Header
	print AN::Common::template($conf, "config.html", "install-manifest-summay-title", {
		title		=>	"#!string!title_0154!#",
	});
	
	# Anvil! name
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0005!#",
		column1		=>	$conf->{cgi}{anvil_name},
		column2		=>	"&nbsp;",
	});
	
	# Anvil! Password
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0194!#",
		column1		=>	$conf->{cgi}{anvil_password},
		column2		=>	"&nbsp;",
	});
	
	# Media Library size
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0191!#",
		column1		=>	"$conf->{cgi}{anvil_media_library_size} $conf->{cgi}{anvil_media_library_unit}",
		column2		=>	"&nbsp;",
	});
	
	# Storage Pool 1 size
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0199!#",
		column1		=>	"$conf->{cgi}{anvil_storage_pool1_size} $conf->{cgi}{anvil_storage_pool1_unit}",
		column2		=>	"&nbsp;",
	});
	
	# BCN Network Mask
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0200!#",
		column1		=>	"$conf->{cgi}{anvil_bcn_subnet}",
		column2		=>	"&nbsp;",
	});
	
	# SN Network Mask
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0201!#",
		column1		=>	"$conf->{cgi}{anvil_sn_subnet}",
		column2		=>	"&nbsp;",
	});
	
	# IFN Network Mask
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0202!#",
		column1		=>	"$conf->{cgi}{anvil_ifn_subnet}",
		column2		=>	"&nbsp;",
	});
	
	# Default Gateway
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0188!#",
		column1		=>	"$conf->{cgi}{anvil_ifn_gateway}",
		column2		=>	"&nbsp;",
	});
	
	# DNS 1
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0189!#",
		column1		=>	$conf->{cgi}{anvil_dns1} ? $conf->{cgi}{anvil_dns1} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	});
	
	# DNS 2
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0189!#",
		column1		=>	$conf->{cgi}{anvil_dns2} ? $conf->{cgi}{anvil_dns2} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	});
	
	# NTP 1
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0192!#",
		column1		=>	$conf->{cgi}{anvil_ntp1} ? $conf->{cgi}{anvil_ntp1} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	});
	
	# NTP 2
	print AN::Common::template($conf, "config.html", "install-manifest-summay-entry", {
		row		=>	"#!string!row_0193!#",
		column1		=>	$conf->{cgi}{anvil_ntp2} ? $conf->{cgi}{anvil_ntp2} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	});
	
	# Repositories.
	print AN::Common::template($conf, "config.html", "install-manifest-summay-one-column-entry", {
		row		=>	"#!string!row_0244!#",
		column1		=>	"$say_repos",
	});
	print AN::Common::template($conf, "config.html", "install-manifest-summay-spacer");
	
	# The footer has all the values recorded as hidden values for the form.
	print AN::Common::template($conf, "config.html", "install-manifest-summay-footer", {
		anvil_prefix			=>	$conf->{cgi}{anvil_prefix},
		anvil_sequence			=>	$conf->{cgi}{anvil_sequence},
		anvil_domain			=>	$conf->{cgi}{anvil_domain},
		anvil_password			=>	$conf->{cgi}{anvil_password},
		anvil_bcn_network		=>	$conf->{cgi}{anvil_bcn_network},
		anvil_bcn_subnet		=>	$conf->{cgi}{anvil_bcn_subnet},
		anvil_sn_network		=>	$conf->{cgi}{anvil_sn_network},
		anvil_sn_subnet			=>	$conf->{cgi}{anvil_sn_subnet},
		anvil_ifn_network		=>	$conf->{cgi}{anvil_ifn_network},
		anvil_ifn_subnet		=>	$conf->{cgi}{anvil_ifn_subnet},
		anvil_media_library_size	=>	$conf->{cgi}{anvil_media_library_size},
		anvil_media_library_unit	=>	$conf->{cgi}{anvil_media_library_unit},
		anvil_storage_pool1_size	=>	$conf->{cgi}{anvil_storage_pool1_size},
		anvil_storage_pool1_unit	=>	$conf->{cgi}{anvil_storage_pool1_unit},
		anvil_name			=>	$conf->{cgi}{anvil_name},
		anvil_node1_name		=>	$conf->{cgi}{anvil_node1_name},
		anvil_node1_bcn_ip		=>	$conf->{cgi}{anvil_node1_bcn_ip},
		anvil_node1_ipmi_ip		=>	$conf->{cgi}{anvil_node1_ipmi_ip},
		anvil_node1_sn_ip		=>	$conf->{cgi}{anvil_node1_sn_ip},
		anvil_node1_ifn_ip		=>	$conf->{cgi}{anvil_node1_ifn_ip},
		anvil_node1_pdu1_outlet		=>	$conf->{cgi}{anvil_node1_pdu1_outlet},
		anvil_node1_pdu2_outlet		=>	$conf->{cgi}{anvil_node1_pdu2_outlet},
		anvil_node1_pdu3_outlet		=>	$conf->{cgi}{anvil_node1_pdu3_outlet},
		anvil_node1_pdu4_outlet		=>	$conf->{cgi}{anvil_node1_pdu4_outlet},
		anvil_node2_name		=>	$conf->{cgi}{anvil_node2_name},
		anvil_node2_bcn_ip		=>	$conf->{cgi}{anvil_node2_bcn_ip},
		anvil_node2_ipmi_ip		=>	$conf->{cgi}{anvil_node2_ipmi_ip},
		anvil_node2_sn_ip		=>	$conf->{cgi}{anvil_node2_sn_ip},
		anvil_node2_ifn_ip		=>	$conf->{cgi}{anvil_node2_ifn_ip},
		anvil_node2_pdu1_outlet		=>	$conf->{cgi}{anvil_node2_pdu1_outlet},
		anvil_node2_pdu2_outlet		=>	$conf->{cgi}{anvil_node2_pdu2_outlet},
		anvil_node2_pdu3_outlet		=>	$conf->{cgi}{anvil_node2_pdu3_outlet},
		anvil_node2_pdu4_outlet		=>	$conf->{cgi}{anvil_node2_pdu4_outlet},
		anvil_ifn_gateway		=>	$conf->{cgi}{anvil_ifn_gateway},
		anvil_dns1			=>	$conf->{cgi}{anvil_dns1},
		anvil_dns2			=>	$conf->{cgi}{anvil_dns2},
		anvil_ntp1			=>	$conf->{cgi}{anvil_ntp1},
		anvil_ntp2			=>	$conf->{cgi}{anvil_ntp2},
		anvil_ups1_name			=>	$conf->{cgi}{anvil_ups1_name},
		anvil_ups1_ip			=>	$conf->{cgi}{anvil_ups1_ip},
		anvil_ups2_name			=>	$conf->{cgi}{anvil_ups2_name},
		anvil_ups2_ip			=>	$conf->{cgi}{anvil_ups2_ip},
		anvil_pdu1_name			=>	$conf->{cgi}{anvil_pdu1_name},
		anvil_pdu1_ip			=>	$conf->{cgi}{anvil_pdu1_ip},
		anvil_pdu1_agent		=>	$conf->{cgi}{anvil_pdu1_agent},
		anvil_pdu2_name			=>	$conf->{cgi}{anvil_pdu2_name},
		anvil_pdu2_ip			=>	$conf->{cgi}{anvil_pdu2_ip},
		anvil_pdu2_agent		=>	$conf->{cgi}{anvil_pdu2_agent},
		anvil_pdu3_name			=>	$conf->{cgi}{anvil_pdu3_name},
		anvil_pdu3_ip			=>	$conf->{cgi}{anvil_pdu3_ip},
		anvil_pdu3_agent		=>	$conf->{cgi}{anvil_pdu3_agent},
		anvil_pdu4_name			=>	$conf->{cgi}{anvil_pdu4_name},
		anvil_pdu4_ip			=>	$conf->{cgi}{anvil_pdu4_ip},
		anvil_pdu4_agent		=>	$conf->{cgi}{anvil_pdu4_agent},
		anvil_switch1_name		=>	$conf->{cgi}{anvil_switch1_name},
		anvil_switch1_ip		=>	$conf->{cgi}{anvil_switch1_ip},
		anvil_switch2_name		=>	$conf->{cgi}{anvil_switch2_name},
		anvil_switch2_ip		=>	$conf->{cgi}{anvil_switch2_ip},
		anvil_striker1_name		=>	$conf->{cgi}{anvil_striker1_name},
		anvil_striker1_bcn_ip		=>	$conf->{cgi}{anvil_striker1_bcn_ip},
		anvil_striker1_ifn_ip		=>	$conf->{cgi}{anvil_striker1_ifn_ip},
		anvil_striker2_name		=>	$conf->{cgi}{anvil_striker2_name},
		anvil_striker2_bcn_ip		=>	$conf->{cgi}{anvil_striker2_bcn_ip},
		anvil_striker2_ifn_ip		=>	$conf->{cgi}{anvil_striker2_ifn_ip},
		anvil_repositories		=>	$conf->{cgi}{anvil_repositories},
		anvil_mtu_size			=>	$conf->{cgi}{anvil_mtu_size},
		say_anvil_repositories		=>	$say_repos,
	});
	
	return(0);
}

# This sanity-checks the user's answers.
sub sanity_check_manifest_answers
{
	my ($conf) = @_;
	
	# Clear all variables.
	my $problem = 0;
	
	# Make sure the sequence number is valid.
	if (not $conf->{cgi}{anvil_sequence})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_sequence_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0161!#"}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_sequence} =~ /\D/)
	{
		$conf->{form}{anvil_sequence_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0102", variables => { field => "#!string!row_0161!#"}}),
		});
		$problem = 1;
	}
	
	# Now check the domain
	if (not $conf->{cgi}{anvil_domain})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_domain_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0160!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_domain}))
	{
		$conf->{form}{anvil_domain_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0160!#"}}),
		});
		$problem = 1;
	}
	
	# The password can not be blank, that's all we check for though.
	if (not $conf->{cgi}{anvil_password})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_password_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0194!#"}}),
		});
		$problem = 1;
	}
	
	### Start testing common stuff.
	# BCN network block and subnet mask
	if (not $conf->{cgi}{anvil_bcn_network})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0116", variables => { field => "#!string!row_0162!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_bcn_network}))
	{
		$conf->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0118", variables => { field => "#!string!row_0162!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_bcn_subnet})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0117", variables => { field => "#!string!row_0162!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_bcn_subnet}))
	{
		$conf->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0119", variables => { field => "#!string!row_0162!#"}}),
		});
		$problem = 1;
	}
	
	# SN network block and subnet mask
	if (not $conf->{cgi}{anvil_sn_network})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0116", variables => { field => "#!string!row_0163!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_sn_network}))
	{
		$conf->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0118", variables => { field => "#!string!row_0163!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_sn_subnet})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0117", variables => { field => "#!string!row_0163!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_sn_subnet}))
	{
		$conf->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0119", variables => { field => "#!string!row_0163!#"}}),
		});
		$problem = 1;
	}
	
	# IFN network block and subnet mask
	if (not $conf->{cgi}{anvil_ifn_network})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0116", variables => { field => "#!string!row_0164!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_ifn_network}))
	{
		$conf->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0118", variables => { field => "#!string!row_0164!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_ifn_subnet})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0117", variables => { field => "#!string!row_0164!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_ifn_subnet}))
	{
		$conf->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0119", variables => { field => "#!string!row_0164!#"}}),
		});
		$problem = 1;
	}
	
	### TODO: Worth checking the select box values?
	# Check the /shared and node 1 storage sizes.
	if (not $conf->{cgi}{anvil_media_library_size})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_media_library_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0191!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_integer_or_unsigned_float($conf, $conf->{cgi}{anvil_media_library_size}))
	{
		$conf->{form}{anvil_media_library_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0121", variables => { field => "#!string!row_0191!#"}}),
		});
		$problem = 1;
	}
	
	# Check the size of the node 1 storage pool.
	if (not $conf->{cgi}{anvil_storage_pool1_size})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0199!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_integer_or_unsigned_float($conf, $conf->{cgi}{anvil_storage_pool1_size}))
	{
		$conf->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0121", variables => { field => "#!string!row_0199!#"}}),
		});
		$problem = 1;
	} # Make sure the percentage is between 0 and 100.
	elsif (($conf->{cgi}{anvil_storage_pool1_unit} eq "%") && (($conf->{cgi}{anvil_storage_pool1_size} < 0) || ($conf->{cgi}{anvil_storage_pool1_size} > 100)))
	{
		$conf->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0120", variables => { field => "#!string!row_0199!#"}}),
		});
		$problem = 1;
	}
	
	# Check the repositor{y,ies} if passed.
	if ($conf->{cgi}{anvil_repositories})
	{
		foreach my $url (split/,/, $conf->{cgi}{anvil_repositories})
		{
			$url =~ s/^\s+//;
			$url =~ s/\s+$//;
			if (not is_string_url($conf, $url))
			{
				$conf->{form}{anvil_repositories_star} = "#!string!symbol_0012!#";
				print AN::Common::template($conf, "config.html", "form-error", {
					message	=>	AN::Common::get_string($conf, {key => "explain_0140", variables => { field => "#!string!row_0244!#"}}),
				});
				$problem = 1;
			}
		}
	}

	# Check the anvil!'s cluster name.
	if (not $conf->{cgi}{anvil_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0005!#"}}),
		});
		$problem = 1;
	} # cman only allows 1-15 characters
	elsif (length($conf->{cgi}{anvil_name}) > 15)
	{
		$conf->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0122", variables => { field => "#!string!row_0005!#"}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_name} =~ /[^a-zA-Z0-9\-]/)
	{
		$conf->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0123", variables => { field => "#!string!row_0005!#"}}),
		});
		$problem = 1;
	}
	
	### Convery anything with the value '--' to ''.
	$conf->{cgi}{anvil_ifn_gateway}     = "" if $conf->{cgi}{anvil_ifn_gateway}     eq "--";
	$conf->{cgi}{anvil_dns1}            = "" if $conf->{cgi}{anvil_dns1}            eq "--";
	$conf->{cgi}{anvil_dns2}            = "" if $conf->{cgi}{anvil_dns1}            eq "--";
	$conf->{cgi}{anvil_ntp1}            = "" if $conf->{cgi}{anvil_ntp1}            eq "--";
	$conf->{cgi}{anvil_ntp2}            = "" if $conf->{cgi}{anvil_ntp1}            eq "--";
	$conf->{cgi}{anvil_switch1_name}    = "" if $conf->{cgi}{anvil_switch1_name}    eq "--";
	$conf->{cgi}{anvil_switch1_ip}      = "" if $conf->{cgi}{anvil_switch1_ip}      eq "--";
	$conf->{cgi}{anvil_switch2_name}    = "" if $conf->{cgi}{anvil_switch2_name}    eq "--";
	$conf->{cgi}{anvil_switch2_ip}      = "" if $conf->{cgi}{anvil_switch2_ip}      eq "--";
	$conf->{cgi}{anvil_pdu1_name}       = "" if $conf->{cgi}{anvil_pdu1_name}       eq "--";
	$conf->{cgi}{anvil_pdu1_ip}         = "" if $conf->{cgi}{anvil_pdu1_ip}         eq "--";
	$conf->{cgi}{anvil_pdu2_name}       = "" if $conf->{cgi}{anvil_pdu2_name}       eq "--";
	$conf->{cgi}{anvil_pdu2_ip}         = "" if $conf->{cgi}{anvil_pdu2_ip}         eq "--";
	$conf->{cgi}{anvil_pdu3_name}       = "" if $conf->{cgi}{anvil_pdu3_name}       eq "--";
	$conf->{cgi}{anvil_pdu3_ip}         = "" if $conf->{cgi}{anvil_pdu3_ip}         eq "--";
	$conf->{cgi}{anvil_pdu4_name}       = "" if $conf->{cgi}{anvil_pdu4_name}       eq "--";
	$conf->{cgi}{anvil_pdu4_ip}         = "" if $conf->{cgi}{anvil_pdu4_ip}         eq "--";
	$conf->{cgi}{anvil_ups1_name}       = "" if $conf->{cgi}{anvil_ups1_name}       eq "--";
	$conf->{cgi}{anvil_ups1_ip}         = "" if $conf->{cgi}{anvil_ups1_ip}         eq "--";
	$conf->{cgi}{anvil_ups2_name}       = "" if $conf->{cgi}{anvil_ups2_name}       eq "--";
	$conf->{cgi}{anvil_ups2_ip}         = "" if $conf->{cgi}{anvil_ups2_ip}         eq "--";
	$conf->{cgi}{anvil_striker1_name}   = "" if $conf->{cgi}{anvil_striker1_name}   eq "--";
	$conf->{cgi}{anvil_striker1_bcn_ip} = "" if $conf->{cgi}{anvil_striker1_bcn_ip} eq "--";
	$conf->{cgi}{anvil_striker1_ifn_ip} = "" if $conf->{cgi}{anvil_striker1_ifn_ip} eq "--";
	$conf->{cgi}{anvil_striker2_name}   = "" if $conf->{cgi}{anvil_striker2_name}   eq "--";
	$conf->{cgi}{anvil_striker2_bcn_ip} = "" if $conf->{cgi}{anvil_striker2_bcn_ip} eq "--";
	$conf->{cgi}{anvil_striker2_ifn_ip} = "" if $conf->{cgi}{anvil_striker2_ifn_ip} eq "--";
	$conf->{cgi}{anvil_node1_ipmi_ip}   = "" if $conf->{cgi}{anvil_node1_ipmi_ip}   eq "--";
	$conf->{cgi}{anvil_node2_ipmi_ip}   = "" if $conf->{cgi}{anvil_node2_ipmi_ip}   eq "--";
	$conf->{cgi}{anvil_open_vnc_ports}  = "" if $conf->{cgi}{anvil_open_vnc_ports}  eq "--";
	
	## Check the common IFN values.
	# Check the gateway
	if (not $conf->{cgi}{anvil_ifn_gateway})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ifn_gateway_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0188!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_ifn_gateway}))
	{
		$conf->{form}{anvil_ifn_gateway_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0188!#"}}),
		});
		$problem = 1;
	}
	
	### DNS is allowed to be blank but, if it is set, it must be IPv4.
	# Check DNS 1
	if (($conf->{cgi}{anvil_dns1}) && (not is_string_ipv4($conf, $conf->{cgi}{anvil_dns1})))
	{
		$conf->{form}{anvil_dns1_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0189!#"}}),
		});
		$problem = 1;
	}
	
	# Check DNS 2
	if (($conf->{cgi}{anvil_dns2}) && (not is_string_ipv4($conf, $conf->{cgi}{anvil_dns2})))
	{
		$conf->{form}{anvil_dns2_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0190!#"}}),
		});
		$problem = 1;
	}
	
	### NTP is allowed to be blank, but if it is set, if must be IPv4 or a
	### domain name.
	# Check NTP 1
	if ($conf->{cgi}{anvil_ntp1})
	{
		# It's defined, so it has to be either a domain name or an
		# IPv4 IP.
		if ((not is_string_ipv4($conf, $conf->{cgi}{anvil_ntp1})) && (not is_domain_name($conf, $conf->{cgi}{anvil_ntp1})))
		{
			$conf->{form}{anvil_ntp1_star} = "#!string!symbol_0012!#";
			print AN::Common::template($conf, "config.html", "form-error", {
				message	=>	AN::Common::get_string($conf, {key => "explain_0099", variables => { field => "#!string!row_0192!#"}}),
			});
			$problem = 1;
		}
	}
	
	# Check NTP 2
	if ($conf->{cgi}{anvil_ntp2})
	{
		# It's defined, so it has to be either a domain name or an
		# IPv4 IP.
		if ((not is_string_ipv4($conf, $conf->{cgi}{anvil_ntp2})) && (not is_domain_name($conf, $conf->{cgi}{anvil_ntp2})))
		{
			$conf->{form}{anvil_ntp2_star} = "#!string!symbol_0012!#";
			print AN::Common::template($conf, "config.html", "form-error", {
				message	=>	AN::Common::get_string($conf, {key => "explain_0099", variables => { field => "#!string!row_0193!#"}}),
			});
			$problem = 1;
		}
	}
	
	### Foundation Pack
	# Check that switch #1's host name and IP are sane, if set. The
	# switches are allowed to be blank in case the user has unmanaged
	# switches.
	if (not $conf->{cgi}{anvil_switch1_name})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($conf->{cgi}{anvil_switch1_ip}) && ($conf->{cgi}{anvil_switch1_ip} ne "--"))
		{
			# IP set, so host name is needed.
			$conf->{form}{anvil_switch1_name_star} = "#!string!symbol_0012!#";
			print AN::Common::template($conf, "config.html", "form-error", {
				message	=>	AN::Common::get_string($conf, {key => "explain_0111", variables => { field => "#!string!row_0178!#"}}),
			});
			$problem = 1;
		}
		else
		{
			# Is OK
			$conf->{cgi}{anvil_switch1_name} = "--";
		}
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_switch1_name}))
	{
		$conf->{form}{anvil_switch1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0178!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_switch1_ip})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($conf->{cgi}{anvil_switch1_name}) && ($conf->{cgi}{anvil_switch1_name} ne "--"))
		{
			# Host name set, so IP is needed.
			$conf->{form}{anvil_switch1_ip_star} = "#!string!symbol_0012!#";
			print AN::Common::template($conf, "config.html", "form-error", {
				message	=>	AN::Common::get_string($conf, {key => "explain_0112", variables => { field => "#!string!row_0179!#"}}),
			});
			$problem = 1;
		}
		else
		{
			# Is OK
			$conf->{cgi}{anvil_switch1_ip} = "--";
		}
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_switch1_ip}))
	{
		$conf->{form}{anvil_switch1_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0179!#"}}),
		});
		$problem = 1;
	}
	
	# Check that switch #2's host name and IP are sane.
	if (not $conf->{cgi}{anvil_switch2_name})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($conf->{cgi}{anvil_switch2_ip}) && ($conf->{cgi}{anvil_switch2_ip} ne "--"))
		{
			# IP set, so host name is needed.
			$conf->{form}{anvil_switch2_name_star} = "#!string!symbol_0012!#";
			print AN::Common::template($conf, "config.html", "form-error", {
				message	=>	AN::Common::get_string($conf, {key => "explain_0111", variables => { field => "#!string!row_0178!#"}}),
			});
			$problem = 1;
		}
		else
		{
			# Is OK
			$conf->{cgi}{anvil_switch2_name} = "--";
		}
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_switch2_name}))
	{
		$conf->{form}{anvil_switch2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0180!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_switch2_ip})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($conf->{cgi}{anvil_switch2_name}) && ($conf->{cgi}{anvil_switch2_name} ne "--"))
		{
			# Host name set, so IP is needed.
			$conf->{form}{anvil_switch2_ip_star} = "#!string!symbol_0012!#";
			print AN::Common::template($conf, "config.html", "form-error", {
				message	=>	AN::Common::get_string($conf, {key => "explain_0112", variables => { field => "#!string!row_0181!#"}}),
			});
			$problem = 1;
		}
		else
		{
			# Is OK
			$conf->{cgi}{anvil_switch2_ip} = "--";
		}
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_switch2_ip}))
	{
		$conf->{form}{anvil_switch2_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0181!#"}}),
		});
		$problem = 1;
	}
	
	### At least two PDUs must be defined.
	# Check that PDU #1's host name and IP are sane.
	my $defined_pdus = 0;
	my $pdus         = [0, 0, 0, 0];
	#record($conf, "$THIS_FILE ".__LINE__."; defined_pdus: [$defined_pdus], pdus: [$pdus] ($pdus->[0], $pdus->[1], $pdus->[2], $pdus->[3])\n");
	foreach my $i (1..4)
	{
		my $name_key      = "anvil_pdu${i}_name";
		my $ip_key        = "anvil_pdu${i}_ip";
		my $name_star_key = "anvil_pdu${i}_name_star";
		my $ip_star_key   = "anvil_pdu${i}_ip_star";
		#record($conf, "$THIS_FILE ".__LINE__."; i: [$i], name_key: [$name_key], ip_key: [$ip_key], name_star_key: [$name_star_key], ip_star_key: [$ip_star_key]\n");
		
		# Some clients/users want PDUs name '1,2,3,4', others 
		# '1A,1B,2A,2B'. This allows for that.
		my $say_pdu = "";
		if ($i == 1)    { $say_pdu = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
		elsif ($i == 2) { $say_pdu = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
		elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
		elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
		#record($conf, "$THIS_FILE ".__LINE__."; i: [$i], say_pdu: [$say_pdu]\n");
		my $say_pdu_name = AN::Common::get_string($conf, {key => "row_0174", variables => { 
					say_pdu	=>	"$say_pdu",
				}});
		my $say_pdu_ip   = AN::Common::get_string($conf, {key => "row_0175", variables => { 
					say_pdu	=>	"$say_pdu",
				}});
		#record($conf, "$THIS_FILE ".__LINE__."; i: [$i], say_pdu_name: [$say_pdu_name], say_pdu_ip: [$say_pdu_ip]\n");
		
		# If either the IP or name is set, validate.
		#record($conf, "$THIS_FILE ".__LINE__."; i: [$i], cgi::$name_key: [$conf->{cgi}{$name_key}], cgi::$ip_key: [$conf->{cgi}{$ip_key}]\n");
		if (($conf->{cgi}{$name_key}) || ($conf->{cgi}{$ip_key}))
		{
			$defined_pdus++;
			#record($conf, "$THIS_FILE ".__LINE__."; i: [$i], defined_pdus: [$defined_pdus], pdus: [$pdus]\n");
			$pdus->[$i] = 1;
			#record($conf, "$THIS_FILE ".__LINE__."; pdus->[$i]: [$pdus->[$i]]\n");
			if (not $conf->{cgi}{$name_key})
			{
				# Not allowed to be blank.
				$conf->{form}{$name_star_key} = "#!string!symbol_0012!#";
				print AN::Common::template($conf, "config.html", "form-error", {
					message	=>	AN::Common::get_string($conf, {key => "explain_0142", variables => { 
						field 		=>	"$say_pdu_name",
						dependent_field	=>	"$say_pdu_ip",
					}}),
				});
				$problem = 1;
			}
			elsif (not is_domain_name($conf, $conf->{cgi}{$name_key}))
			{
				$conf->{form}{$name_star_key} = "#!string!symbol_0012!#";
				print AN::Common::template($conf, "config.html", "form-error", {
					message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "$say_pdu_name"}}),
				});
				$problem = 1;
			}
			if (not $conf->{cgi}{$ip_key})
			{
				# Not allowed to be blank.
				$conf->{form}{$ip_star_key} = "#!string!symbol_0012!#";
				print AN::Common::template($conf, "config.html", "form-error", {
					message	=>	AN::Common::get_string($conf, {key => "explain_0142", variables => { 
						field 		=>	"$say_pdu_ip",
						dependent_field	=>	"$say_pdu_name",
					}}),
				});
				$problem = 1;
			}
			elsif (not is_string_ipv4($conf, $conf->{cgi}{$ip_key}))
			{
				$conf->{form}{$ip_star_key} = "#!string!symbol_0012!#";
				print AN::Common::template($conf, "config.html", "form-error", {
					message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "$say_pdu_ip"}}),
				});
				$problem = 1;
			}
		}
	}
	
	# Each node has to have an outlet defined for at least two PDUs.
	foreach my $j (1, 2)
	{
		my $node_pdu_count = 0;
		my $say_node       = AN::Common::get_string($conf, {key => "title_0156", variables => { node_number => $j }});
		foreach my $i (1..4)
		{
			my $outlet_key      = "anvil_node${j}_pdu${i}_outlet";
			my $outlet_star_key = "anvil_node${j}_pdu${i}_outlet_star";
			my $say_pdu         = "";
			if ($i == 1)    { $say_pdu = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
			elsif ($i == 2) { $say_pdu = $conf->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
			elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
			elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
			my $say_pdu_name = AN::Common::get_string($conf, {key => "row_0174", variables => { 
						say_pdu	=>	"$say_pdu",
					}});
			if ($conf->{cgi}{$outlet_key})
			{
				$node_pdu_count++;
				if ($conf->{cgi}{$outlet_key} =~ /\D/)
				{
					$conf->{form}{$outlet_star_key} = "#!string!symbol_0012!#";
					print AN::Common::template($conf, "config.html", "form-error", {
						message	=>	AN::Common::get_string($conf, {key => "explain_0108", variables => { 
							node	=>	"$say_node",
							field	=>	"$say_pdu_name"
						}}),
					});
					$problem = 1;
				}
				# Make sure this PDU is defined.
				if (not $pdus->[$i])
				{
					# It's not.
					$conf->{form}{$outlet_star_key} = "#!string!symbol_0012!#";
					print AN::Common::template($conf, "config.html", "form-error", {
						message	=>	AN::Common::get_string($conf, {key => "explain_0144", variables => { 
							node	=>	"$say_node",
							field	=>	"$say_pdu_name"
						}}),
					});
					$problem = 1;
				}
			}
		}
		
		# If there isn't at least 2 outlets defined, bail.
		if ($node_pdu_count < 2)
		{
			print AN::Common::template($conf, "config.html", "form-error", {
				message	=>	AN::Common::get_string($conf, {key => "explain_0145", variables => { 
					node	=>	"$say_node",
				}}),
			});
			$problem = 1;
		}
	}
	
	# Make sure at least two PDUs were defined.
	if ($defined_pdus < 2)
	{
		# Not allowed!
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	"#!string!explain_0143!#",
		});
		$problem = 1;
	}
	
	# Check that UPS #1's host name and IP are sane.
	if (not $conf->{cgi}{anvil_ups1_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ups1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0170!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_ups1_name}))
	{
		$conf->{form}{anvil_ups1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0170!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_ups1_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ups1_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0171!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_ups1_ip}))
	{
		$conf->{form}{anvil_ups1_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0171!#"}}),
		});
		$problem = 1;
	}
	
	# Check that UPS #2's host name and IP are sane.
	if (not $conf->{cgi}{anvil_ups2_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ups2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0172!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_ups2_name}))
	{
		$conf->{form}{anvil_ups2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0172!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_ups2_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ups2_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0173!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_ups2_ip}))
	{
		$conf->{form}{anvil_ups2_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0173!#"}}),
		});
		$problem = 1;
	}
	
	# Check that Striker #1's host name and BCN and IFN IPs are sane.
	if (not $conf->{cgi}{anvil_striker1_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0182!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_striker1_name}))
	{
		$conf->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0182!#"}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_striker1_name} !~ /\./)
	{
		# Must be a FQDN
		$conf->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0042", variables => { field => "#!string!row_0182!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_striker1_bcn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0183!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_striker1_bcn_ip}))
	{
		$conf->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0183!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_striker1_ifn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_striker1_ifn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0184!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_striker1_bcn_ip}))
	{
		$conf->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0184!#"}}),
		});
		$problem = 1;
	}
	
	# Check that Striker #2's host name and BCN and IFN IPs are sane.
	if (not $conf->{cgi}{anvil_striker2_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0185!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_striker2_name}))
	{
		$conf->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0185!#"}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_striker2_name} !~ /\./)
	{
		# Must be a FQDN
		$conf->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0042", variables => { field => "#!string!row_0182!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_striker2_bcn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0186!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_striker2_bcn_ip}))
	{
		$conf->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0186!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_striker2_ifn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_striker2_ifn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0187!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_striker2_bcn_ip}))
	{
		$conf->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0187!#"}}),
		});
		$problem = 1;
	}
	
	### Node specific values.
	# Node 1
	# Host name
	if (not $conf->{cgi}{anvil_node1_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0165!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_node1_name}))
	{
		$conf->{form}{anvil_node1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0107", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0165!#"
			}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_node2_name} !~ /\./)
	{
		# Must be a FQDN
		$conf->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0042", variables => { field => "#!string!row_0182!#"}}),
		});
		$problem = 1;
	}
	# BCN IP address
	if (not $conf->{cgi}{anvil_node1_bcn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node1_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0166!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_node1_bcn_ip}))
	{
		$conf->{form}{anvil_node1_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0109", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0166!#"
			}}),
		});
		$problem = 1;
	}
	# IPMI IP address
	if (not $conf->{cgi}{anvil_node1_ipmi_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node1_ipmi_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0168!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_node1_ipmi_ip}))
	{
		$conf->{form}{anvil_node1_ipmi_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0109", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0168!#"
			}}),
		});
		$problem = 1;
	}
	# SN IP address
	if (not $conf->{cgi}{anvil_node1_sn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node1_sn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0167!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_node1_sn_ip}))
	{
		$conf->{form}{anvil_node1_sn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0109", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0167!#"
			}}),
		});
		$problem = 1;
	}
	# IFN IP address
	if (not $conf->{cgi}{anvil_node1_ifn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node1_ifn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0167!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_node1_ifn_ip}))
	{
		$conf->{form}{anvil_node1_ifn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0109", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0167!#"
			}}),
		});
		$problem = 1;
	}
	
	# Node 2
	# Host name
	if (not $conf->{cgi}{anvil_node2_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0165!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_node2_name}))
	{
		$conf->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0107", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0165!#"
			}}),
		});
		$problem = 1;
	}
	# BCN IP address
	if (not $conf->{cgi}{anvil_node2_bcn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node2_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0166!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_node2_bcn_ip}))
	{
		$conf->{form}{anvil_node2_bcn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0109", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0166!#"
			}}),
		});
		$problem = 1;
	}
	# IPMI IP address
	if (not $conf->{cgi}{anvil_node2_ipmi_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node2_ipmi_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0168!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_node2_ipmi_ip}))
	{
		$conf->{form}{anvil_node2_ipmi_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0109", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0168!#"
			}}),
		});
		$problem = 1;
	}
	# SN IP address
	if (not $conf->{cgi}{anvil_node2_sn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node2_sn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0167!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_node2_sn_ip}))
	{
		$conf->{form}{anvil_node2_sn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0109", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0167!#"
			}}),
		});
		$problem = 1;
	}
	# IFN IP address
	if (not $conf->{cgi}{anvil_node2_ifn_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node2_ifn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0167!#"
			}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_node2_ifn_ip}))
	{
		$conf->{form}{anvil_node2_ifn_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0109", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0167!#"
			}}),
		});
		$problem = 1;
	}
	
	return($problem);
}

# Checks to see if the passed string is a URL or not.
sub is_string_url
{   
	my ($conf, $string) = @_;
	my $valid = 1;
	
	if ($string =~ /^(.*?):\/\/(.*?)\/(.*)$/)
	{
		my $protocol = $1;
		my $host     = $2;
		my $path     = $3;
		my $port     = "";
		#print "[ Debug ] - >> protocol: [$protocol], host: [$host], path: [$path], port: [$port]\n";
		if ($protocol eq "http")
		{
			$port = 80;
		}
		elsif ($protocol eq "https")
		{
			$port = 443;
		}
		elsif ($protocol eq "ftp")
		{
			$port = 21;
		}
		else
		{
			# Invalid protocol
			$valid = 0;
		}
		if ($host =~ /^(.*?):(\d+)$/)
		{
			$host = $1;
			$port = $2;
		}
		if ($host =~ /^\d+\.\d+\.\d+\.\d+/)
		{
			if (not is_string_ipv4($conf, $host))
			{
				$valid = 0;
			}
		}
		else
		{
			if (not is_domain_name($conf, $host))
			{
				$valid = 0;
			}
		}
		#print "[ Debug ] - << protocol: [$protocol], host: [$host], path: [$path], port: [$port]\n";
	}
	else
	{   
		$valid = 0;
	}
	
	return($valid);
}

# Check if the passed string is an unsigned floating point number. A whole
# number is allowed.
sub is_string_integer_or_unsigned_float
{
	my ($conf, $string) = @_;
	my $valid = 1;
	
	if ($string =~ /^\D/)
	{
		# Non-digit could mean it's signed or just garbage.
		$valid = 0;
	}
	elsif (($string !~ /^\d+$/) && ($string != /^\d+\.\d+$/))
	{
		# Not an integer or float
		$valid = 0;
	}
	
	return($valid);
}

# Check to see if the string looks like a valid hostname
sub is_domain_name
{
	my ($conf, $name) = @_;
	my $valid = 1;
	
	if (not $name)
	{
		$valid = 0;
	}
	elsif (($name !~ /^((([a-z]|[0-9]|\-)+)\.)+([a-z])+$/i) && (($name !~ /^\w+$/) && ($name !~ /-/)))
	{
		# Doesn't appear to be valid.
		$valid = 0;
	}
	
	return($valid);
}

# Check if the passed string is a valid IP address and subnet mask (CIDR or
# dotted-decimal).
sub is_string_ipv4_with_subnet
{
	my ($conf, $ip) = @_;
	my $subnet = "";
	my $valid  = 1;
	
	# Make sure the string has a subnet after it.
	if ($ip =~ /^(.*?)\/(.*)$/)
	{
		$ip     = $1;
		$subnet = $2;
		
		# Check the IP
		if (is_string_ipv4($conf, $ip))
		{
			# IP is ok, not convert to dotted decimal if needed.
			if ($subnet =~ /^\d+$/)
			{
				($subnet) = AN::Common::convert_cidr_to_dotted_decimal($conf, $subnet);
			}
			# Should be dotted-decimal now, check it.
			if (not is_string_ipv4($conf, $subnet))
			{
				# No luck.
				$valid = 0;
			}
		}
		else
		{
			# IP isn't valid, no sense checking the subnet
			$valid = 0;
		}
	}
	else
	{
		# This isn't an 'ip/nm' string at all.
		$valid = 0;
	}
	
	return($valid);
}

# Checks if the passed-in string is an IPv4 address (with or without a subnet
# mask). Returns '1' if OK, 0 if not.
sub is_string_ipv4
{
	my ($conf, $ip) = @_;
	my $valid  = 1;
	
	if ($ip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)
	{
		# It's in the right format.
		my $first_octal  = $1;
		my $second_octal = $2;
		my $third_octal  = $3;
		my $fourth_octal = $4;
		
		if (($first_octal  < 0) || ($first_octal  > 255) ||
		    ($second_octal < 0) || ($second_octal > 255) ||
		    ($third_octal  < 0) || ($third_octal  > 255) ||
		    ($fourth_octal < 0) || ($fourth_octal > 255))
		{
			# One of the octals is out of range.
			$valid = 0;
		}
	}
	else
	{
		# Not in the right format.
		$valid = 0;
	}
	
	return($valid);
}

# This allows the user to configure their dashboard.
sub configure_dashboard
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; configure_dashboard()\n");
	
	read_hosts($conf);
	read_ssh_config($conf);
	
	record($conf, "$THIS_FILE ".__LINE__."; cgi::save: [$conf->{cgi}{save}], cgi::task: [$conf->{cgi}{task}]\n");
	if ($conf->{cgi}{save})
	{
		save_dashboard_configure($conf);
	}
	elsif ($conf->{cgi}{task} eq "push")
	{
		push_config_to_anvil($conf);
	}
	elsif ($conf->{cgi}{task} eq "archive")
	{
		show_archive_options($conf);
	}
	elsif ($conf->{cgi}{task} eq "load_config")
	{
		load_backup_configuration($conf);
	}
	elsif ($conf->{cgi}{task} eq "create-install-manifest")
	{
		create_install_manifest($conf);
		return(0);
	}
	
	### Header section
	### If showing the main page, it's global settings and then the list of Anvil!s.
	### If showing an Anvil!, it's the Anvil!'s details and then the overrides.

	print AN::Common::template($conf, "config.html", "open-form-table", {
		form_file	=>	"/cgi-bin/striker",
	});
	
	# If showing an Anvil!, display it's details first.
	record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil: [$conf->{cgi}{anvil}]\n");
	if ($conf->{cgi}{anvil})
	{
		# Show Anvil! header and node settings.
		show_anvil_config_header($conf);
	}
	else
	{
		# Show the global header only. We'll show the settings in a minute.
		show_global_config_header($conf);
	}
	
	# Show the common options (whether global or anvil-specific will have been sorted out above.
	show_common_config_section($conf);
	
	my $say_section = "global";
	if ($conf->{cgi}{anvil})
	{
		$say_section = "anvil";
	}
	else
	{
		# Show the list of Anvil!s if this is the global section.
		#show_global_anvil_list($conf);
	}
	# Close out the form.
	print AN::Common::template($conf, "config.html", "close-form-table");

	return(0);
}

# This takes a plain text string and escapes special characters for displaying
# in HTML.
sub convert_text_to_html
{
	my ($conf, $string) = @_;
	$string = "" if not defined $string;

	
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
	$string =~ s/\s/&nbsp;/g;	# Non-breaking Space
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
	
	return ($string);
}

# This takes a string with (possible) HTML escape codes and converts them to
# plain-text.
sub convert_html_to_text
{
	my ($conf, $string) = @_;
	$string = "" if not defined $string;

	$string =~ s/&quot;/"/g;
	$string =~ s/&#09;/\t/g;	# Horizontal tab
	$string =~ s/&#10;/\n/g;	# Line feed
	$string =~ s/&#13;/\r/g;	# Carriage Return
	$string =~ s/&#32;/ /g;		# Space
	$string =~ s/&#33;/!/g;		# Exclamation mark
	$string =~ s/&#34;/"/g;		# Quotation mark
	$string =~ s/&#36;/\$/g;	# Dollar sign
	$string =~ s/&#37;/\%/g;	# Percent sign
	$string =~ s/&#38;/&/g;		# (Alt) Ampersand
	$string =~ s/&#39;/'/g;		# Apostrophe
	$string =~ s/&#40;/\(/g;	# Left parenthesis
	$string =~ s/&#41;/\)/g;	# Right parenthesis
	$string =~ s/&#42;/\*/g;	# Asterisk
	$string =~ s/&#43;/\+/g;	# Plus sign
	$string =~ s/&#44;/,/g;		# Comma
	$string =~ s/&#45;/-/g;		# Hyphen
	$string =~ s/&#46;/\./g;	# Period (fullstop)
	$string =~ s/&#47;/\//g;	# Solidus (slash)
	$string =~ s/&#58;/:/g;		# Colon
	$string =~ s/&lt;/</g;		# Less than
	$string =~ s/&#60;/</g;		# (Alt) Less than
	$string =~ s/&#61;/=/g;		# Equals sign
	$string =~ s/&gt;/>/g;		# Greater than
	$string =~ s/&#62;/>/g;		# (Alt) Greater than
	$string =~ s/&#63;/\?/g;	# Question mark
	$string =~ s/&#64;/\@/g;	# Commercial at
	$string =~ s/&#91;/\[/g;	# Left square bracket
	$string =~ s/&#92;/\\/g;	# Reverse solidus (backslash)
	$string =~ s/&#93;/\]/g;	# Right square bracket
	$string =~ s/&#94;/\^/g;	# Caret
	$string =~ s/&#95;/_/g;		# Horizontal bar (underscore)
	$string =~ s/&#96;/`/g;		# Acute accent
	$string =~ s/&#123;/{/g;	# Left curly brace
	$string =~ s/&#124;/\|/g;	# Vertical bar
	$string =~ s/&#125;/}/g;	# Right curly brace
	$string =~ s/&#126;/~/g;	# Tilde
	$string =~ s/&nbsp;/ /g;	# Non-breaking Space
	$string =~ s/&#160;/ /g;	# (Alt) Non-breaking Space
	$string =~ s/&#161;/¡/g;	# Inverted exclamation
	$string =~ s/&#162;/¢/g;	# Cent sign
	$string =~ s/&#163;/£/g;	# Pound sterling
	$string =~ s/&#164;/¤/g;	# General currency sign
	$string =~ s/&#165;/¥/g;	# Yen sign
	$string =~ s/&#166;/¦/g;	# Broken vertical bar
	$string =~ s/&#167;/§/g;	# Section sign
	$string =~ s/&#168;/¨/g;	# Umlaut (dieresis)
	$string =~ s/&copy;/©/g;	# Copyright
	$string =~ s/&#169;/©/g;	# (Alt) Copyright
	$string =~ s/&#170;/ª/g;	# Feminine ordinal
	$string =~ s/&#171;/«/g;	# Left angle quote, guillemotleft
	$string =~ s/&#172;/¬/g;	# Not sign
	$string =~ s/&#173;/­/g;		# Soft hyphen
	$string =~ s/&#174;/®/g;	# Registered trademark
	$string =~ s/&#175;/¯/g;	# Macron accent
	$string =~ s/&#176;/°/g;	# Degree sign
	$string =~ s/&#177;/±/g;	# Plus or minus
	$string =~ s/&#178;/²/g;	# Superscript two
	$string =~ s/&#179;/³/g;	# Superscript three
	$string =~ s/&#180;/´/g;	# Acute accent
	$string =~ s/&#181;/µ/g;	# Micro sign
	$string =~ s/&#182;/¶/g;	# Paragraph sign
	$string =~ s/&#183;/·/g;	# Middle dot
	$string =~ s/&#184;/¸/g;	# Cedilla
	$string =~ s/&#185;/¹/g;	# Superscript one
	$string =~ s/&#186;/º/g;	# Masculine ordinal
	$string =~ s/&#187;/»/g;	# Right angle quote, guillemotright
	$string =~ s/&frac14;/¼/g;	# Fraction one-fourth
	$string =~ s/&#188;/¼/g;	# (Alt) Fraction one-fourth
	$string =~ s/&frac12;/½/g;	# Fraction one-half
	$string =~ s/&#189;/½/g;	# (Alt) Fraction one-half
	$string =~ s/&frac34;/¾/g;	# Fraction three-fourths
	$string =~ s/&#190;/¾/g;	# (Alt) Fraction three-fourths
	$string =~ s/&#191;/¿/g;	# Inverted question mark
	$string =~ s/&#192;/À/g;	# Capital A, grave accent
	$string =~ s/&#193;/Á/g;	# Capital A, acute accent
	$string =~ s/&#194;/Â/g;	# Capital A, circumflex accent
	$string =~ s/&#195;/Ã/g;	# Capital A, tilde
	$string =~ s/&#196;/Ä/g;	# Capital A, dieresis or umlaut mark
	$string =~ s/&#197;/Å/g;	# Capital A, ring
	$string =~ s/&#198;/Æ/g;	# Capital AE dipthong (ligature)
	$string =~ s/&#199;/Ç/g;	# Capital C, cedilla
	$string =~ s/&#200;/È/g;	# Capital E, grave accent
	$string =~ s/&#201;/É/g;	# Capital E, acute accent
	$string =~ s/&#202;/Ê/g;	# Capital E, circumflex accent
	$string =~ s/&#203;/Ë/g;	# Capital E, dieresis or umlaut mark
	$string =~ s/&#204;/Ì/g;	# Capital I, grave accent
	$string =~ s/&#205;/Í/g;	# Capital I, acute accent
	$string =~ s/&#206;/Î/g;	# Capital I, circumflex accent
	$string =~ s/&#207;/Ï/g;	# Capital I, dieresis or umlaut mark
	$string =~ s/&#208;/Ð/g;	# Capital Eth, Icelandic
	$string =~ s/&#209;/Ñ/g;	# Capital N, tilde
	$string =~ s/&#210;/Ò/g;	# Capital O, grave accent
	$string =~ s/&#211;/Ó/g;	# Capital O, acute accent
	$string =~ s/&#212;/Ô/g;	# Capital O, circumflex accent
	$string =~ s/&#213;/Õ/g;	# Capital O, tilde
	$string =~ s/&#214;/Ö/g;	# Capital O, dieresis or umlaut mark
	$string =~ s/&#215;/×/g;	# Multiply sign
	$string =~ s/&#216;/Ø/g;	# Capital O, slash
	$string =~ s/&#217;/Ù/g;	# Capital U, grave accent
	$string =~ s/&#218;/Ú/g;	# Capital U, acute accent
	$string =~ s/&#219;/Û/g;	# Capital U, circumflex accent
	$string =~ s/&#220;/Ü/g;	# Capital U, dieresis or umlaut mark
	$string =~ s/&#221;/Ý/g;	# Capital Y, acute accent
	$string =~ s/&#222;/Þ/g;	# Capital THORN, Icelandic
	$string =~ s/&#223;/ß/g;	# Small sharp s, German (sz ligature)
	$string =~ s/&#224;/à/g;	# Small a, grave accent
	$string =~ s/&#225;/á/g;	# Small a, acute accent
	$string =~ s/&#226;/â/g;	# Small a, circumflex accent
	$string =~ s/&#227;/ã/g;	# Small a, tilde
	$string =~ s/&#228;/ä/g;	# Small a, dieresis or umlaut mark
	$string =~ s/&#229;/å/g;	# Small a, ring
	$string =~ s/&#230;/æ/g;	# Small ae dipthong (ligature)
	$string =~ s/&#231;/ç/g;	# Small c, cedilla
	$string =~ s/&#232;/è/g;	# Small e, grave accent
	$string =~ s/&#233;/é/g;	# Small e, acute accent
	$string =~ s/&#234;/ê/g;	# Small e, circumflex accent
	$string =~ s/&#235;/ë/g;	# Small e, dieresis or umlaut mark
	$string =~ s/&#236;/ì/g;	# Small i, grave accent
	$string =~ s/&#237;/í/g;	# Small i, acute accent
	$string =~ s/&#238;/î/g;	# Small i, circumflex accent
	$string =~ s/&#239;/ï/g;	# Small i, dieresis or umlaut mark
	$string =~ s/&#240;/ð/g;	# Small eth, Icelandic
	$string =~ s/&#241;/ñ/g;	# Small n, tilde
	$string =~ s/&#242;/ò/g;	# Small o, grave accent
	$string =~ s/&#243;/ó/g;	# Small o, acute accent
	$string =~ s/&#244;/ô/g;	# Small o, circumflex accent
	$string =~ s/&#245;/õ/g;	# Small o, tilde
	$string =~ s/&#246;/ö/g;	# Small o, dieresis or umlaut mark
	$string =~ s/&#247;/÷/g;	# Division sign
	$string =~ s/&#248;/ø/g;	# Small o, slash
	$string =~ s/&#249;/ù/g;	# Small u, grave accent
	$string =~ s/&#250;/ú/g;	# Small u, acute accent
	$string =~ s/&#251;/û/g;	# Small u, circumflex accent
	$string =~ s/&#252;/ü/g;	# Small u, dieresis or umlaut mark
	$string =~ s/&#253;/ý/g;	# Small y, acute accent
	$string =~ s/&#254;/þ/g;	# Small thorn, Icelandic
	$string =~ s/&#255;/ÿ/g;	# Small y, dieresis or umlaut mark
	$string =~ s/&#35;/#/g;		# Number sign - Must be third to last! \
	$string =~ s/&amp;/&/g;		# Ampersand - Must be second to last!   |- These are used in other escape codes.
	$string =~ s/&#59;/;/g;		# Semi-colon - Must be last!            /
	
	return ($string);
}

# This asks the user which cluster they want to work with.
sub ask_which_cluster
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; ask_which_cluster()\n");
	
	print AN::Common::template($conf, "select-anvil.html", "open-table");
	
	# Now see if we have any Anvil! systems configured.
	my $anvil_count = 0;
	foreach my $cluster (sort {$a cmp $b} keys %{$conf->{clusters}})
	{
		$anvil_count++;
	}
	if (not $anvil_count)
	{
		print AN::Common::template($conf, "select-anvil.html", "no-anvil-configured");
	}
	else
	{
		foreach my $cluster (sort {$a cmp $b} keys %{$conf->{clusters}})
		{
			next if not $cluster;
			my $say_url = "&nbsp;";
			
			# Create the 'Configure' link.
			my $image = AN::Common::template($conf, "common.html", "image", {
				image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_edit-anvil_16x16.png",
				alt_text	=>	"#!string!button_0044!#",
				id		=>	"configure_icon",
			}, "", 1);
			my $say_configure = AN::Common::template($conf, "common.html", "enabled-button-no-class-new-tab", {
				button_link	=>	"?config=true&anvil=$cluster",
				button_text	=>	$image,
				id		=>	"configure_$cluster",
			}, "", 1);
			
			# If an info link has been specified, show it.
			if ($conf->{clusters}{$cluster}{url})
			{
				my $image = AN::Common::template($conf, "common.html", "image", {
					image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/anvil-url_16x16.png",
					alt_text	=>	"",
				id		=>	"url_icon",
				}, "", 1);
				$say_url = AN::Common::template($conf, "common.html", "enabled-button-no-class-new-tab", {
					button_link	=>	"$conf->{clusters}{$cluster}{url}",
					button_text	=>	$image,
					id		=>	"url_$cluster",
				}, "", 1);
			}
			print AN::Common::template($conf, "select-anvil.html", "anvil-entry", {
				anvil		=>	$cluster,
				company		=>	$conf->{clusters}{$cluster}{company},
				description	=>	$conf->{clusters}{$cluster}{description},
				configure	=>	$say_configure,
				url		=>	$say_url,
			});
		}
	}
	
	# See if the global options have been configured yet.
	my ($global_set) = AN::Common::check_global_settings($conf);
	record($conf, "$THIS_FILE ".__LINE__."; global_set: [$global_set]\n");
	if (not $global_set)
	{
		# Looks like the user hasn't configured the global values yet.
		print AN::Common::template($conf, "select-anvil.html", "global-not-configured");
	}
	
	return (0);
}

# This toggles the dhcpd server and shorewall/iptables to turn the Install
# Target feature on and off.
sub control_install_target
{
	my ($conf, $action) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; control_install_target(); action: [$action]\n");
	
	### TODO: Track what was running and start back up things we turned off
	###       only.
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
if [ -e '$conf->{path}{initd_libvirtd}' ];
then
    $conf->{path}{control_libvirtd} status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'libvirtd running, stopping it'
        $conf->{path}{control_libvirtd} stop
        $conf->{path}{control_libvirtd} status
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
    if [ -e '$conf->{path}{initd_iptables}' ];
    then
        $conf->{path}{control_iptables} status;
        if [ \"\$?\" -eq \"0\" ];
        then 
            echo 'iptables running, stopping it'
            $conf->{path}{control_iptables} stop
            $conf->{path}{control_iptables} status
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

    $conf->{path}{control_shorewall} status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'shorewall running'
    else
        echo 'shorewall stopped, starting it'
        $conf->{path}{control_shorewall} restart
        $conf->{path}{control_shorewall} status
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

if [ -e '$conf->{path}{control_dhcpd}' ];
then
    $conf->{path}{control_dhcpd} status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'dhcpd running'
    else
        echo 'dhcpd running, starting it'
        $conf->{path}{control_dhcpd} restart
        $conf->{path}{control_dhcpd} status
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
		# We don't start libvirtd, period.
		# Stop shorewall and start iptables
		$shell_call .= "
if [ -e '$conf->{path}{initd_libvirtd}' ];
then
    $conf->{path}{control_libvirtd} status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'libvirtd running, stopping it'
        $conf->{path}{control_libvirtd} stop
        $conf->{path}{control_libvirtd} status
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
    $conf->{path}{control_shorewall} status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'shorewall running, stopping it'
        $conf->{path}{control_shorewall} stop
        $conf->{path}{control_shorewall} status
        if [ \"\$?\" -eq \"3\" ];
        then 
            echo 'shorewall stopped'
            echo 'Restarting iptables now'
            $conf->{path}{control_iptables} stop;
            $conf->{path}{control_iptables} start;
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

if [ -e '$conf->{path}{control_dhcpd}' ];
then
    $conf->{path}{control_dhcpd} status;
    if [ \"\$?\" -eq \"0\" ];
    then 
        echo 'dhcpd running, stopping it'
        $conf->{path}{control_dhcpd} restart
        $conf->{path}{control_dhcpd} status
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
	$shell_call .= "$conf->{path}{control_dhcpd} $action; echo rc:\$?";
	record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
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
	
	record($conf, "$THIS_FILE ".__LINE__."; dhcpd_ok: [$dhcpd_rc], libvirtd_rc: [$libvirtd_rc], shorewall_rc: [$shorewall_rc], iptables_rc: [$iptables_rc]\n");
	return($dhcpd_rc, $libvirtd_rc, $shorewall_rc, $iptables_rc);
}

# Show the "select Anvil!" menu and Striker config and control options.
sub show_anvil_selection_and_striker_options
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; show_anvil_selection_and_striker_options()\n");
	
	# If I'm toggling the install target (dhcpd), process it first.
	record($conf, "$THIS_FILE ".__LINE__."; cgi::install_target: [$conf->{cgi}{install_target}]\n");
	if ($conf->{cgi}{install_target})
	{
		record($conf, "$THIS_FILE ".__LINE__."; cgi::confirm: [$conf->{cgi}{confirm}]\n");
		if (($conf->{cgi}{install_target} eq "start") && (not $conf->{cgi}{confirm}))
		{
			# Warn the user about possible DHCPd conflicts and ask
			# them to confirm.
			my $confirm_url = "?logo=true&install_target=start&confirm=true";
			print AN::Common::template($conf, "select-anvil.html", "confirm-dhcpd-start", {
				confirm_url	=>	$confirm_url,
			});
		}
		elsif ($conf->{cgi}{install_target} eq "start")
		{
			# Stop libvirtd, stop iptables, start shorewall, start dhcpd
			my ($dhcpd_rc, $libvirtd_rc, $shorewall_rc, $iptables_rc) = control_install_target($conf, "start");
			record($conf, "$THIS_FILE ".__LINE__."; dhcpd_ok: [$dhcpd_rc], libvirtd_rc: [$libvirtd_rc], shorewall_rc: [$shorewall_rc], iptables_rc: [$iptables_rc]\n");
			
			# libvirtd_rc:
			# 0 == not installed
			# 1 == installed but stopped
			# 2 == was running but stopped
			# 3 == running and failed to stop.
			
			# If libvirtd was stopped (or failed to stop), warn the
			# user.
# 			if ($libvirtd_rc eq "2")
# 			{
# 				# Warn the user that we turned off libvirtd.
# 				print AN::Common::template($conf, "select-anvil.html", "control-dhcpd-results", {
# 					class	=>	"highlight_warning_bold",
# 					row	=>	"#!string!row_0044!#",
# 					message	=>	"#!string!message_0117!#",
# 				});
# 			}
# 			elsif ($libvirtd_rc eq "3")
# 			{
# 				# Warn the user that we failed to turn off libvirtd.
# 				print AN::Common::template($conf, "select-anvil.html", "control-dhcpd-results", {
# 					class	=>	"highlight_warning_bold",
# 					row	=>	"#!string!row_0044!#",
# 					message	=>	"#!string!message_0364!#",
# 				});
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
# 			print AN::Common::template($conf, "select-anvil.html", "control-install-target-results", {
# 				class	=>	$class,
# 				row	=>	$row,
# 				message	=>	$message,
# 			});
			
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
			
			# DHCP message; Default message is 'not instaled'
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
			print AN::Common::template($conf, "select-anvil.html", "control-install-target-results", {
				class	=>	$class,
				row	=>	$row,
				message	=>	$message,
			});
		}
		elsif ($conf->{cgi}{install_target} eq "stop")
		{
			# Disable it.
			my ($dhcpd_rc, $libvirtd_rc, $shorewall_rc, $iptables_rc) = control_install_target($conf, "stop");
			record($conf, "$THIS_FILE ".__LINE__."; dhcpd_ok: [$dhcpd_rc], libvirtd_rc: [$libvirtd_rc], shorewall_rc: [$shorewall_rc], iptables_rc: [$iptables_rc]\n");
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
				$row     = "#!string!row_0083!#";
				$message = "#!string!message_0414!#";
				$class   = "highlight_good_bold";
			}
			if ($dhcpd_rc eq "2")
			{
				$message = "#!string!message_0415!#";
			}
			print AN::Common::template($conf, "select-anvil.html", "control-dhcpd-results", {
				row	=>	$row,
				class	=>	$class,
				message	=>	$message,
			});
			
			### NOTE: At this time, 'stop' action should never stop
			###       libvirtd, so this *should* always return 0.
			# If libvirtd was stopped (or failed to stop), warn the
			# user.
			if ($libvirtd_rc eq "2")
			{
				# Warn the user that we turned off libvirtd.
				print AN::Common::template($conf, "select-anvil.html", "control-dhcpd-results", {
					class	=>	"highlight_warning_bold",
					row	=>	"#!string!row_0044!#",
					message	=>	"#!string!message_0117!#",
				});
			}
			elsif ($libvirtd_rc eq "3")
			{
				# Warn the user that we failed to turn off libvirtd.
				print AN::Common::template($conf, "select-anvil.html", "control-dhcpd-results", {
					class	=>	"highlight_warning_bold",
					row	=>	"#!string!row_0044!#",
					message	=>	"#!string!message_0364!#",
				});
			}
		}
	}
	
	# Show the list of configured Anvil! systems.
	ask_which_cluster($conf);
	
	# See if this machine is configured as a boot target and, if so,
	# whether dhcpd is running or not (so we can offer a toggle.
	my ($dhcpd_state) = get_dhcpd_state($conf);
	# 0 == Running
	# 1 == Not running
	# 2 == Not a boot target
	# 3 == In an unknown state.
	# 4 == No access to /etc/dhcpd
	record($conf, "$THIS_FILE ".__LINE__."; dhcpd_state: [$dhcpd_state]\n");
	
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
		$install_target_url      = "?logo=true&install_target=stop";
	}
	elsif ($dhcpd_state eq "1")
	{
		# dhcpd is stopped, offer the button to enable it.
		$install_target_template = "enabled-install-target-button";
		$install_target_button   = "#!string!button_0057!#";
		$install_target_message  = "#!string!message_0407!#";
		$install_target_url      = "?logo=true&install_target=start";
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
	#record($conf, "$THIS_FILE ".__LINE__."; install_target_template: [$install_target_template], install_target_button: [$install_target_button], install_target_message: [$install_target_message], install_target_url: [$install_target_url]\n");
	my $install_manifest_tr = AN::Common::template($conf, "select-anvil.html", $install_target_template, {
		install_target_button	=>	$install_target_button,
		install_target_message	=>	$install_target_message,
		install_target_url	=>	$install_target_url,
	});
	#record($conf, "$THIS_FILE ".__LINE__."; install_manifest_tr: [$install_manifest_tr]\n");
	print AN::Common::template($conf, "select-anvil.html", "close-table", {
		install_manifest_tr	=>	$install_manifest_tr,
	});
	
	return(0);
}

# This checks to see if dhcpd is configured to be an install target target and,
# if so, see if dhcpd is running or not.
sub get_dhcpd_state
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; get_dhcpd_state()\n");
	
	# First, read the dhcpd.conf file, if it exists, and look for the
	# 'next-server' option.
	my $dhcpd_state = 2;
	my $boot_target = 0;
	record($conf, "$THIS_FILE ".__LINE__."; path::dhcpd_conf: [$conf->{path}{dhcpd_conf}]\n");
	if (-e $conf->{path}{dhcpd_conf})
	{
		record($conf, "$THIS_FILE ".__LINE__."; Parsing dhcpd.conf\n");
		my $shell_call = "$conf->{path}{dhcpd_conf}";
		record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		open (my $file_handle, "<", "$shell_call") || die "Failed to read: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			   $line =~ s/^\s+//;
			#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /next-server \d+\.\d+\.\d+\.\d+;/)
			{
				$boot_target = 1;
				record($conf, "$THIS_FILE ".__LINE__."; We're an install target!\n");
				last;
			}
		}
		close $file_handle;
	}
	else
	{
		record($conf, "$THIS_FILE ".__LINE__."; DHCP daemon config file: [$conf->{path}{dhcpd_conf}] not found or not readable. Is '/etc/dhcp' readable by UID: [$<]?\n");
		$dhcpd_state = 4;
	}
	record($conf, "$THIS_FILE ".__LINE__."; boot_target: [$boot_target]\n");
	if ($boot_target)
	{
		### NOTE: Don't use the setuid wrapper as 'root' isn't needed
		###       for a status check anyway.
		# See if dhcpd is running.
		my $shell_call = "/etc/init.d/dhcpd status; echo rc:\$?";
		record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /rc:(\d+)/)
			{
				my $rc = $1;
				record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc]\n");
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
	record($conf, "$THIS_FILE ".__LINE__."; dhcpd_state: [$dhcpd_state]\n");
	return($dhcpd_state);
}

# I need to convert the global configuration of the clusters to the format I use here.
sub convert_cluster_config
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; convert_cluster_config()\n");
	
	foreach my $id (sort {$a cmp $b} keys %{$conf->{cluster}})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; cluster: [$id]\n");
		my $name = $conf->{cluster}{$id}{name};
		#record($conf, "$THIS_FILE ".__LINE__."; name: [$name], cluster::${id}::nodes: [$conf->{cluster}{$id}{nodes}]\n");
		$conf->{clusters}{$name}{nodes}       = [split/,/, $conf->{cluster}{$id}{nodes}];
		$conf->{clusters}{$name}{company}     = $conf->{cluster}{$id}{company};
		$conf->{clusters}{$name}{description} = $conf->{cluster}{$id}{description};
		$conf->{clusters}{$name}{url}         = $conf->{cluster}{$id}{url};
		$conf->{clusters}{$name}{ricci_pw}    = $conf->{cluster}{$id}{ricci_pw};
		$conf->{clusters}{$name}{root_pw}     = $conf->{cluster}{$id}{root_pw} ? $conf->{cluster}{$id}{root_pw} : $conf->{cluster}{$id}{ricci_pw};
		$conf->{clusters}{$name}{id}          = $id;
		#record($conf, "$THIS_FILE ".__LINE__."; ID: [$id], name: [$name], company: [$conf->{clusters}{$name}{company}], description: [$conf->{clusters}{$name}{description}], ricci_pw: [$conf->{clusters}{$name}{ricci_pw}], root_pw: [$conf->{cluster}{$id}{root_pw}]\n");
		
		for (my $i = 0; $i< @{$conf->{clusters}{$name}{nodes}}; $i++)
		{
			@{$conf->{clusters}{$name}{nodes}}[$i] =~ s/^\s+//;
			@{$conf->{clusters}{$name}{nodes}}[$i] =~ s/\s+$//;
			my $node = @{$conf->{clusters}{$name}{nodes}}[$i];
			#record($conf, "$THIS_FILE ".__LINE__."; $i - node: [$node]\n");
			if ($node =~ /^(.*?):(\d+)$/)
			{
				   $node = $1;
				my $port = $2;
				#record($conf, "$THIS_FILE ".__LINE__."; $i - node: [$node], port: [$port]\n");
				@{$conf->{clusters}{$name}{nodes}}[$i] = $node;
				$conf->{node}{$node}{port}             = $port;
				#record($conf, "$THIS_FILE ".__LINE__."; $i - clusters::${name}::nodes[$i]: [@{$conf->{clusters}{$name}{nodes}}[$i]], port: [$conf->{node}{$name}{port}]\n");
			}
			else
			{
				$conf->{node}{$node}{port} = $conf->{hosts}{$node}{port} ? $conf->{hosts}{$node}{port} : 22;
				#record($conf, "$THIS_FILE ".__LINE__."; $i - node::${node}::port: [$conf->{node}{$node}{port}], hosts::${node}::port: [$conf->{hosts}{$node}{port}]\n");
			}
			#record($conf, "$THIS_FILE ".__LINE__."; $i - node: [@{$conf->{clusters}{$name}{nodes}}[$i]], port: [$conf->{node}{$node}{port}]\n");
		}
	}
	
	return (0);
}

# This prints an error and exits.
sub error
{
	my ($conf, $message, $fatal) = @_;
	$fatal = 1 if not defined $fatal;
	
	print AN::Common::template($conf, "common.html", "error-table", {
		message	=>	$message,
	});
	footer($conf) if $fatal;
	
	exit(1) if $fatal;
	return(1);
}

sub header
{
	my ($conf, $caller) = @_;
	$caller = "striker" if not $caller;
	
	# Header buttons.
	my $say_back        = "&nbsp;";
	my $say_refresh     = "&nbsp;";
	
	my $back_image = AN::Common::template($conf, "common.html", "image", {
		image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/back.png",
		alt_text	=>	"#!string!button_0001!#",
		id		=>	"back_icon",
	}, "", 1);
	my $refresh_image = AN::Common::template($conf, "common.html", "image", {
		image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/refresh.png",
		alt_text	=>	"#!string!button_0002!#",
		id		=>	"refresh_icon",
	}, "", 1);
	
	if ($conf->{cgi}{config})
	{
		$conf->{sys}{cgi_string} =~ s/cluster=(.*?)&//;
		$conf->{sys}{cgi_string} =~ s/cluster=(.*)$//;
		if ($conf->{cgi}{save})
		{
			$say_refresh = "";
			$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?config=true",
				button_text	=>	"$back_image",
				id		=>	"back",
			}, "", 1);
			if (($conf->{cgi}{anvil} eq "new") && ($conf->{cgi}{cluster__new__name}))
			{
				$conf->{cgi}{anvil} = $conf->{cgi}{cluster__new__name};
			}
			if (($conf->{cgi}{anvil}) && ($conf->{cgi}{anvil} ne "new"))
			{
				$say_back = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
					button_link	=>	"?anvil=$conf->{cgi}{anvil}&config=true",
					button_text	=>	"$back_image",
					id		=>	"back",
				}, "", 1);
			}
		}
		elsif ($conf->{cgi}{task})
		{
			$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?config=true",
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}, "", 1);
			$say_back = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?logo=true",
				button_text	=>	"$back_image",
				id		=>	"back",
			}, "", 1);
			
			if ($conf->{cgi}{task} eq "load_config")
			{
				$say_refresh = "";
				my $back = "?logo=true";
				if ($conf->{cgi}{anvil})
				{
					$back = "?anvil=$conf->{cgi}{anvil}&config=true";
				}
				$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
					button_link	=>	$back,
					button_text	=>	"$back_image",
					id		=>	"back",
				}, "", 1);
			}
			elsif ($conf->{cgi}{task} eq "push")
			{
				$say_refresh = "";
			}
			elsif ($conf->{cgi}{task} eq "archive")
			{
				$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
					button_link	=>	"?config=true&task=archive",
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}, "", 1);
				$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
					button_link	=>	"?logo=true",
					button_text	=>	"$back_image",
					id		=>	"back",
				}, "", 1);
			}
			elsif ($conf->{cgi}{task} eq "create-install-manifest")
			{
				my $link =  $conf->{sys}{cgi_string};
					$link =~ s/generate=true//;
					$link =~ s/anvil_password=.*?&//;
					$link =~ s/anvil_password=.*?$//;	# Catch the password if it's the last variable in the URL
					$link =~ s/&&/&/g;
				if ($conf->{cgi}{confirm})
				{
					if ($conf->{cgi}{run})
					{
						my $back_url =  $conf->{sys}{cgi_string};
						   $back_url =~ s/confirm=.*?&//; $back_url =~ s/confirm=.*$//;
						   
						#record($conf, "$THIS_FILE ".__LINE__."; sys::cgi_string: [$conf->{sys}{cgi_string}]\n");
						#record($conf, "$THIS_FILE ".__LINE__."; back_url:           [$back_url]\n");
						$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
							button_link	=>	"$back_url",
							button_text	=>	"$back_image",
							id		=>	"back",
						}, "", 1);
					}
					elsif ($conf->{cgi}{'delete'})
					{
						my $back_url =  $conf->{sys}{cgi_string};
						   $back_url =~ s/confirm=.*?&//; $back_url =~ s/confirm=.*$//;
						   $back_url =~ s/delete=.*?&//;  $back_url =~ s/delete=.*$//;
						   
						#record($conf, "$THIS_FILE ".__LINE__."; sys::cgi_string: [$conf->{sys}{cgi_string}]\n");
						#record($conf, "$THIS_FILE ".__LINE__."; back_url:           [$back_url]\n");
						$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
							button_link	=>	"$back_url",
							button_text	=>	"$back_image",
							id		=>	"back",
						}, "", 1);
					}
					else
					{
						$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
							button_link	=>	"$link",
							button_text	=>	"$back_image",
							id		=>	"back",
						}, "", 1);
					}
					$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
						button_link	=>	"?config=true&task=create-install-manifest",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}, "", 1);
				}
				elsif ($conf->{cgi}{generate})
				{
					$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
						button_link	=>	"$link",
						button_text	=>	"$back_image",
						id		=>	"back",
					}, "", 1);
					$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
						button_link	=>	"$conf->{sys}{cgi_string}",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}, "", 1);
				}
				elsif ($conf->{cgi}{run})
				{
					$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
						button_link	=>	"?config=true&task=create-install-manifest",
						button_text	=>	"$back_image",
						id		=>	"back",
					}, "", 1);
					$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
						button_link	=>	"$conf->{sys}{cgi_string}",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}, "", 1);
				}
				else
				{
					$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
						button_link	=>	"?config=true&task=create-install-manifest",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}, "", 1);
				}
			}
			elsif ($conf->{cgi}{anvil})
			{
				$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
					button_link	=>	"?anvil=$conf->{cgi}{anvil}&config=true",
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}, "", 1);
			}
		}
		else
		{
			$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"$conf->{sys}{cgi_string}",
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}, "", 1);
			$say_back = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?logo=true",
				button_text	=>	"$back_image",
				id		=>	"back",
			}, "", 1);
			if ($conf->{cgi}{anvil})
			{
				$say_back = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
					button_link	=>	"?config=true",
					button_text	=>	"$back_image",
					id		=>	"back",
				}, "", 1);
			}
		}
	}
	elsif ($conf->{cgi}{task})
	{
		$say_back = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"?cluster=$conf->{cgi}{cluster}",
			button_text	=>	"$back_image",
			id		=>	"back",
		}, "", 1);
		if ($conf->{cgi}{task} eq "manage_vm")
		{
			$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&vm=$conf->{cgi}{vm}&task=manage_vm",
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}, "", 1);
		}
		elsif ($conf->{cgi}{task} eq "display_health")
		{
			$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health",
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}, "", 1);
		}
	}
	elsif ($conf->{cgi}{logo})
	{
		$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"?logo=true",
			button_text	=>	"$refresh_image",
			id		=>	"refresh",
		}, "", 1);
		$say_back    = "";
	}
	elsif ($caller eq "mediaLibrary")
	{
		$say_back = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"/cgi-bin/striker?cluster=$conf->{cgi}{cluster}",
			button_text	=>	"$back_image",
			id		=>	"back",
		}, "", 1);
		$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"$conf->{sys}{cgi_string}",
			button_text	=>	"$refresh_image",
			id		=>	"refresh",
		}, "", 1);
	}
	else
	{
		$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"$conf->{sys}{cgi_string}",
			button_text	=>	"$refresh_image",
			id		=>	"refresh",
		}, "", 1);
	}
	
	#foreach my $key (sort {$a cmp $b} keys %ENV) { record($conf, "$THIS_FILE ".__LINE__."; ENV key: [$key]\t->\t[$ENV{$key}]\n"); }
	#$conf->{sys}{reload_page_timer} = 1;
	
	# We only want the auto-refresh function to activate in certain pages.
	my $use_refresh = 0;
	record($conf, "$THIS_FILE ".__LINE__."; sys::reload_page_timer: [$conf->{sys}{reload_page_timer}]\n");
	if ($conf->{sys}{reload_page_timer})
	{
		record($conf, "$THIS_FILE ".__LINE__."; sys::cgi_string: [$conf->{sys}{cgi_string}], ENV{REQUEST_URI}: [$ENV{REQUEST_URI}]\n");
		if (($conf->{sys}{cgi_string} eq "?cluster=$conf->{cgi}{cluster}") && 
		    ($ENV{REQUEST_URI} !~ /mediaLibrary/i))
		{
			record($conf, "$THIS_FILE ".__LINE__."; use refresh.\n");
			$use_refresh = 1;
		}
		else
		{
			record($conf, "$THIS_FILE ".__LINE__."; do not use refresh.\n");
		}
		if ($conf->{sys}{cgi_string} =~ /\?cluster=.*?&task=display_health&node=.*?&node_cluster_name=(.*)$/)
		{
			my $final = $1;
			record($conf, "$THIS_FILE ".__LINE__."; final: [$final]\n");
			if ($final !~ /&/)
			{
				record($conf, "$THIS_FILE ".__LINE__."; use refresh.\n");
				$use_refresh = 1;
			}
			else
			{
				record($conf, "$THIS_FILE ".__LINE__."; do not use refresh.\n");
			}
		}
	}
	
	# Now print the actual header.
	if ($use_refresh)
	{
		# Add the auto-reload function if requested by the user.
		print AN::Common::template($conf, "common.html", "auto-refresh-header", {
			back		=>	$say_back,
			refresh		=>	$say_refresh,
		});
	}
	else
	{
		print AN::Common::template($conf, "common.html", "header", {
			back		=>	$say_back,
			refresh		=>	$say_refresh,
		});
	}
	
	
	return (0);
}

# This looks for an executable.
sub find_executables
{
	my ($conf) = @_;
	
	my $search = $ENV{'PATH'};
	#print "Searching in: [$search] for programs.\n";
	foreach my $prog (keys %{$conf->{path}})
	{
		#print "Seeing if: [$prog] is really at: [$conf->{path}{$prog}]: ";
		if ( -e $conf->{path}{$prog} )
		{
			#print "Found it.\n";
		}
		else
		{
			#print "Not found, searching for it now.\n";
			foreach my $dir (split /:/, $search)
			{
				my $full_path = "$dir/$prog";
				if ( -e $full_path )
				{
					$conf->{path}{$prog} = $full_path;
					#print "Found it in: [$full_path]\n";
				}
			}
		}
	}
	
	return (0);
}

# This is the new 'get_guacamole_link()' that assumes 'mod_proxy' is in use.
# sub get_guacamole_link
# {
# 	my ($conf, $node) = @_;
# 	#record($conf, "$THIS_FILE ".__LINE__."; get_guacamole_link(); node: [$node]\n");
# 	
# 	#foreach my $key (sort {$a cmp $b} keys %ENV) { record($conf, "$THIS_FILE ".__LINE__."; ENV{$key}: [$ENV{$key}].\n"); }
# 	my $guacamole_url;
# 	#record($conf, "$THIS_FILE ".__LINE__."; HTTP_REFERER: [$ENV{HTTP_REFERER}], ENV{HTTP_HOST}: [$ENV{HTTP_HOST}]\n");
# 	if ($ENV{HTTP_REFERER})
# 	{
# 		if ($guacamole_url =~ /cgi-bin/)
# 		{
# 			($guacamole_url) = ($ENV{HTTP_REFERER} =~ /^(.*?)\/cgi-bin/);
# 			#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 		}
# 		else
# 		{
# 			$guacamole_url = $ENV{HTTP_REFERER};
# 			#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 		}
# 		$guacamole_url =~ s/(\w)\/\w.*$/$1/;
# 		#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 	}
# 	elsif ($ENV{HTTP_HOST})
# 	{
# 		if ($ENV{SERVER_PORT} eq "443")
# 		{
# 			$guacamole_url = "https://".$ENV{HTTP_HOST};
# 			#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 		}
# 		else
# 		{
# 			$guacamole_url = "http://".$ENV{HTTP_HOST};
# 			#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 		}
# 	}
# 	#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 	
# 	my $cluster = $conf->{cgi}{cluster};
# 	#record($conf, "$THIS_FILE ".__LINE__."; cluster: [$cluster]\n");
# 	
# 	$guacamole_url .= "/guacamole/client.xhtml";
# 	#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 
# 	# No node specified, so return a link to the guacamole main page.
# 	if (not $node)
# 	{
# 		$guacamole_url =~ s/\/client.xhtml.*$/\//;
# 		#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 	}
# 	
# 	#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
# 	return ($guacamole_url);
# }

### Old footer with guacamole support.
# sub old_footer
# {
# 	my ($conf) = @_;
# 	
# 	return(0) if $conf->{sys}{footer_printed}; 
# 	my ($guacamole_url) = get_guacamole_link($conf, "");
# 	
# 	print AN::Common::template($conf, "common.html", "footer", {
# 		guacamole_url	=>	$guacamole_url,
# 	});
# 	
# 	$conf->{sys}{footer_printed} = 1;
# 	
# 	return (0);
# }

# Footer that closes out all pages.
sub footer
{
	my ($conf) = @_;
	
	return(0) if $conf->{sys}{footer_printed}; 
	
	print AN::Common::template($conf, "common.html", "footer");
	$conf->{sys}{footer_printed} = 1;
	
	return (0);
}

# This returns a 'YY-MM-DD_hh:mm:ss' formatted string based on the given time
# stamp
sub get_date
{
	my ($conf, $time, $time_only) = @_;
	$time      = time if not defined $time;
	$time_only = 0 if not $time_only;
	
	my @time   = localtime($time);
	my $year   = ($time[5] + 1900);
	my $month  = sprintf("%.2d", ($time[4] + 1));
	my $day    = sprintf("%.2d", $time[3]);
	my $hour   = sprintf("%.2d", $time[2]);
	my $minute = sprintf("%.2d", $time[1]);
	my $second = sprintf("%.2d", $time[0]);
	
	# this returns "yyyy-mm-dd_hh:mm:ss".
	my $date = $time_only ? "$hour:$minute:$second" : "$year-$month-$day $hour:$minute:$second";
	
	return ($date);
}

# The reads in any passed CGI variables
sub get_cgi_vars
{
	my ($conf, $vars) = @_;
	
	# Needed to read in passed CGI variables
	my $cgi = new CGI;
	
	# This will store the string I was passed.
	$conf->{sys}{cgi_string} = "?";
	foreach my $var (@{$vars})
	{
		# A stray comma will cause a loop with no var name
		next if not $var;
		
		# I auto-select the 'cluster' variable if only one is checked.
		# Because of this, I don't want to overwrite the empty CGI 
		# value. This prevents that.
		if (($var eq "cluster") && ($conf->{cgi}{cluster}))
		{
			$conf->{sys}{cgi_string} .= "$var=$conf->{cgi}{$var}&";
			record($conf, "$THIS_FILE ".__LINE__."; var: [$var] -> [$conf->{cgi}{$var}]\n");
			next;
		}
		
		# Avoid "uninitialized" warning messages.
		$conf->{cgi}{$var} = "";
		if (defined $cgi->param($var))
		{
			if ($var eq "file")
			{
				record($conf, "$THIS_FILE ".__LINE__."; var: [$var]\n");
				if (not $cgi->upload($var))
				{
					record($conf, "$THIS_FILE ".__LINE__."; Empty file passed, looks like the user forgot to select a file to upload.\n");
				}
				else
				{
					$conf->{cgi_fh}{$var}       = $cgi->upload($var);
					my $file                    = $conf->{cgi_fh}{$var};
					$conf->{cgi_mimetype}{$var} = $cgi->uploadInfo($file)->{'Content-Type'};
					record($conf, "$THIS_FILE ".__LINE__."; cgi FH: [$var] -> [$conf->{cgi_fh}{$var}], mimetype: [$conf->{cgi_mimetype}{$var}]\n");
				}
			}
			$conf->{cgi}{$var} = $cgi->param($var);
			# Make this UTF8 if it isn't already.
			if (not Encode::is_utf8($conf->{cgi}{$var}))
			{
				$conf->{cgi}{$var} = Encode::decode_utf8( $conf->{cgi}{$var} );
			}
			$conf->{sys}{cgi_string} .= "$var=$conf->{cgi}{$var}&";
		}
		record($conf, "$THIS_FILE ".__LINE__."; var: [$var] -> [$conf->{cgi}{$var}]\n") if $conf->{cgi}{$var};
	}
	$conf->{sys}{cgi_string} =~ s/&$//;
	#AN::Common::to_log($conf, {file => $THIS_FILE, line => __LINE__, level => 2, message => "sys::cgi_string: [$conf->{sys}{cgi_string}]\n"});
	
	return (0);
}

# This builds an HTML select field.
sub build_select
{
	my ($conf, $name, $sort, $blank, $width, $selected, $options) = @_;
	
	my $select = "<select name=\"$name\">\n";
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
	if ($sort)
	{
		foreach my $entry (sort {$a cmp $b} @{$options})
		{
			next if not $entry;
			if ($entry =~ /^(.*?)#!#(.*)$/)
			{
				my $value = $1;
				my $desc  = $2;
				$select .= "<option value=\"$value\">$desc</option>\n";
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
			if ($entry =~ /^(.*?)#!#(.*)$/)
			{
				my $value = $1;
				my $desc  = $2;
				$select .= "<option value=\"$value\">$desc</option>\n";
			}
			else
			{
				$select .= "<option value=\"$entry\">$entry</option>\n";
			}
		}
	}
	
	if ($selected)
	{
		$select =~ s/value=\"$selected\">/value=\"$selected\" selected>/m;
	}
	
	$select .= "</select>\n";
	
	return ($select);
}

# This looks for a node we have access to and returns the first one available.
sub read_files_on_shared
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; read_files_on_shared()\n");

	my $connected = "";
	my $cluster   = $conf->{cgi}{cluster};
	delete $conf->{files} if exists $conf->{files};
	foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
	{
		next if $connected;
		record($conf, "$THIS_FILE ".__LINE__."; trying to connect to node: [$node].\n");
		my $fail = 0;
		my ($error, $ssh_fh, $output) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	"df -P && ls -l /shared/files/",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		
		my $raw = "";
		foreach my $line (@{$output})
		{
			$raw .= "$line\n";
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
			next if $fail;
			
			### TODO: Move these checks into a function. They duplicate gather_node_details().
			# This catches connectivity problems.
			if ($line =~ /No route to host/i)
			{
				my ($local_access, $target_ip)      = on_same_network($conf, $node, $node);
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0033!#</span>";
				if ($local_access)
				{
					# Local access, but not answering.
					$conf->{node}{$node}{info}{note} = AN::Common::get_string($conf, {key => "message_0019", variables => {
						node	=>	$node,
					}});
				}
				else
				{
					# Not on the same subnet.
					$conf->{node}{$node}{info}{note} = AN::Common::get_string($conf, {key => "message_0020", variables => {
						node	=>	$node,
					}});
				}
				$fail = 1;
				next;
			}
			elsif ($line =~ /host key verification failed/i)
			{
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0034!#</span>";
				$conf->{node}{$node}{info}{note}    = AN::Common::get_string($conf, {key => "message_0021", variables => {
					node	=>	$node,
				}});
				$fail = 1;
				next;
			}
			elsif ($line =~ /could not resolve hostname/i)
			{
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0035!#</span>";
				$conf->{node}{$node}{info}{note}    = AN::Common::get_string($conf, {key => "message_0022", variables => {
					node	=>	$node,
				}});
				$fail = 1;
				next;
			}
			elsif ($line =~ /permission denied/i)
			{
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0036!#</span>";
				$conf->{node}{$node}{info}{note}    = AN::Common::get_string($conf, {key => "message_0023", variables => {
					node		=>	$node,
				}});
				$fail = 1;
				next;
			}
			elsif ($line =~ /connection refused/i)
			{
				$conf->{node}{$node}{info}{'state'} =  "<span class=\"highlight_bad\">#!string!row_0037!#</span>";
				$conf->{node}{$node}{info}{note}    = AN::Common::get_string($conf, {key => "message_0024", variables => {
					node		=>	$node,
				}});
				$fail = 1;
				next;
			}
			elsif ($line =~ /Connection timed out/i)
			{
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0038!#</span>";
				$conf->{node}{$node}{info}{note}    = AN::Common::get_string($conf, {key => "message_0025", variables => {
					node		=>	$node,
				}});
				$fail = 1;
				next;
			}
			elsif ($line =~ /Network is unreachable/i)
			{
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0039!#</span>";
				$conf->{node}{$node}{info}{note}    = AN::Common::get_string($conf, {key => "message_0026", variables => {
					node		=>	$node,
				}});
				$fail = 1;
				next;
			}
			elsif ($line =~ /\@\@\@\@/)
			{
				# When the host-key fails to match, a box made
				# of '@@@@' is displayed, and is the entire 
				# first line.
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_bad\">#!string!row_0033!#</span>";
				$conf->{node}{$node}{info}{note}    = AN::Common::get_string($conf, {key => "message_0027", variables => {
					node		=>	$node,
				}});
				$fail = 1;
				next;
			}
			
			# If I made it this far, I've got a connection.
			$connected = $node;
			if ($line =~ /\s(\d+)-blocks\s/)
			{
				$conf->{partition}{shared}{block_size} = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; block_size: [$conf->{partition}{shared}{block_size}]\n");
				next;
			}
			if ($line =~ /^\/.*?\s+(\d+)\s+(\d+)\s+(\d+)\s(\d+)%\s+\/shared/)
			{
				$conf->{partition}{shared}{total_space}  = $1;
				$conf->{partition}{shared}{used_space}   = $2;
				$conf->{partition}{shared}{free_space}   = $3;
				$conf->{partition}{shared}{used_percent} = $4;
				#record($conf, "$THIS_FILE ".__LINE__."; total_space: [$conf->{partition}{shared}{total_space}], used_space: [$conf->{partition}{shared}{used_space} / $conf->{partition}{shared}{used_percent}%], free_space: [$conf->{partition}{shared}{free_space}]\n");
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
				$conf->{files}{shared}{$file}{type}   = $type;
				$conf->{files}{shared}{$file}{mode}   = $mode;
				$conf->{files}{shared}{$file}{user}   = $user;
				$conf->{files}{shared}{$file}{group}  = $group;
				$conf->{files}{shared}{$file}{size}   = $size;
				$conf->{files}{shared}{$file}{month}  = $month;
				$conf->{files}{shared}{$file}{day}    = $day;
				$conf->{files}{shared}{$file}{'time'} = $time; # might be a year, look for '\d+:\d+'.
				$conf->{files}{shared}{$file}{target} = $target;
				#record($conf, "$THIS_FILE ".__LINE__."; file: [$file], mode: [$conf->{files}{shared}{$file}{type}, $conf->{files}{shared}{$file}{mode}], owner: [$conf->{files}{shared}{$file}{user} / $conf->{files}{shared}{$file}{group}], size: [$conf->{files}{shared}{$file}{size}], modified: [$conf->{files}{shared}{$file}{month} $conf->{files}{shared}{$file}{day} $conf->{files}{shared}{$file}{'time'}], target: [$conf->{files}{shared}{$file}{target}]\n");
				next;
			}
		}
	}
	
	if (not $connected)
	{
		# Open the "not connected" table
		# Variable hash feeds into 'title_0116'
		print AN::Common::template($conf, "main-page.html", "connection-error-table-header", {}, {
			anvil	=>	$cluster,
		});
		
		foreach my $node (sort {$a cmp $b} keys %{$conf->{node}})
		{
			# Show each node's state.
			my $state = $conf->{node}{$node}{info}{'state'};
			my $note  = $conf->{node}{$node}{info}{note};
			print AN::Common::template($conf, "main-page.html", "connection-error-node-entry", {
				node	=>	$node,
				'state'	=>	$state,
				note	=>	$node,
			});
		}
		print AN::Common::template($conf, "main-page.html", "connection-error-try-again", {
			cgi_string	=>	$conf->{sys}{cgi_string},
		});
	}
	#print AN::Common::template($conf, "main-page.html", "close-table");
	
	return ($connected);
}

### TODO: Switch to 'to_log'
# Record a message to the log file.
sub record
{
	my ($conf, $message)=@_;
	
	my $file_handle = $conf->{handles}{'log'} ? $conf->{handles}{'log'} : "";
	#print "[ Debug ] $THIS_FILE ".__LINE__."; - file_handle: [$file_handle]\n";
	if (not $file_handle)
	{
		# Touch the file if it doesn't exist yet.
		#print "[ Debug ] $THIS_FILE ".__LINE__."; - Checking if: [$conf->{path}{log_file}] is writable...\n";
		if (not -w $conf->{path}{log_file})
		{
			# NOTE: The setuid '$conf->{path}{'touch_striker.log'}'
			#       is hard-coded to use '/var/log/striker.log'.
			#print "[ Debug ] - It is not. Running: [$conf->{path}{'touch_striker.log'}]\n";
			my $shell_call = $conf->{path}{'touch_striker.log'};
			open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				#print "[ Debug ] - Output: [$line]\n";
			}
			close $file_handle;
			
			#print "[ Debug ] - Checking if it is writable now...\n";
			if (not -w $conf->{path}{log_file})
			{
				#print "[ Error ] - Failed to make: [$conf->{path}{log_file}] writable! Is: [$conf->{path}{'touch_striker.log'}] setuid root?\n";
				exit(1);
			}
		}
		
		my $shell_call = $conf->{path}{log_file};
		# I need to call 'IO::handle' here.
		$file_handle = IO::Handle->new();
		$file_handle->autoflush(1);
		open ($file_handle, ">>", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write to: [$shell_call], error was: $!\n";
		#print "[ Debug ] $THIS_FILE ".__LINE__."; - file_handle: [$file_handle]\n";
		print $file_handle "======\nOpening Striker log at ".get_date($conf, time)."\n";
		
		# Store the handle.
		$conf->{handles}{'log'} = $file_handle;
		#print "[ Debug ] $THIS_FILE ".__LINE__."; - handles::log: [$conf->{handles}{'log'}]\n";
	}
	my $time = get_date($conf, time, 1);
	#print "[ Debug ] $THIS_FILE ".__LINE__."; - file_handle: [$file_handle]\n";
	print $file_handle "$time $message";
	
	return (0);
}

# This gathers details on the cluster.
sub scan_cluster
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; scan_cluster()\n");
	
	AN::Striker::set_node_names ($conf);
	
	# Show the 'scanning in progress' table.
	# variables hash feeds 'message_0272'.
	print AN::Common::template($conf, "common.html", "scanning-message", {}, {
		anvil	=>	$conf->{cgi}{cluster},
	});
	
	# Start your engines!
	check_node_status($conf);
	
	#record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{sys}{up_nodes}]\n");
	if ($conf->{sys}{up_nodes} > 0)
	{
		AN::Striker::check_vms($conf);
	}

	return(0);
}

# This attempts to gather all information about a node in one SSH call. It's
# done to minimize the ssh overhead on slow links.
sub check_node_status
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; check_node_status()\n");
	
	my $cluster = $conf->{cgi}{cluster};
	#record($conf, "$THIS_FILE ".__LINE__."; In check_node_status() checking nodes in cluster: [$cluster].\n");
	foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; setting daemon states to 'Unknown'.\n");
		set_daemons($conf, $node, "Unknown", "highlight_unavailable");
		#record($conf, "$THIS_FILE ".__LINE__."; Gathering details on: [$node].\n");
		gather_node_details($conf, $node);
		push @{$conf->{online_nodes}}, $node if AN::Striker::check_node_daemons($conf, $node);
	}
	
	# If I have no nodes up, exit.
	$conf->{sys}{up_nodes}     = @{$conf->{up_nodes}};
	$conf->{sys}{online_nodes} = @{$conf->{online_nodes}};
	#record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{sys}{up_nodes}], online nodes: [$conf->{sys}{online_nodes}]\n");
	if ($conf->{sys}{up_nodes} < 1)
	{
		# Neither node is up. If I can power them on, then I will show
		# the node section to enable power up.
		if (not $conf->{sys}{online_nodes})
		{
			if ($conf->{clusters}{$cluster}{cache_exists})
			{
				print AN::Common::template($conf, "main-page.html", "no-access-message", {
					anvil	=>	$conf->{cgi}{cluster},
					message	=>	"#!string!message_0028!#",
				});
			}
			else
			{
				print AN::Common::template($conf, "main-page.html", "no-access-message", {
					anvil	=>	$conf->{cgi}{cluster},
					message	=>	"#!string!message_0029!#",
				});
			}
		}
	}
	else
	{
		post_scan_calculations($conf);
	}
	
	return (0);
}

# This sorts out some stuff after both nodes have been scanned.
sub post_scan_calculations
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; post_scan_calculations()\n");
	
	$conf->{resources}{total_ram}     = 0;
	$conf->{resources}{total_cores}   = 0;
	$conf->{resources}{total_threads} = 0;
	foreach my $node (sort {$a cmp $b} @{$conf->{up_nodes}})
	{
		# Record this node's RAM and CPU as the maximum available if
		# the max cores and max ram is 0 or greater than that on this
		# node.
		#record($conf, "$THIS_FILE ".__LINE__."; >> node: [$node], res. total RAM: [$conf->{resources}{total_ram}], hardware total memory: [$conf->{node}{$node}{hardware}{total_memory}]\n");
		if ((not $conf->{resources}{total_ram}) || ($conf->{node}{$node}{hardware}{total_memory} < $conf->{resources}{total_ram}))
		{
			$conf->{resources}{total_ram} = $conf->{node}{$node}{hardware}{total_memory};
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], res. total RAM: [$conf->{resources}{total_ram}]\n");
		}
		#record($conf, "$THIS_FILE ".__LINE__."; << node: [$node], res. total RAM: [$conf->{resources}{total_ram}]\n");
		
		# Set by meminfo, if less (needed to catch mirrored RAM)
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], meminfo total memory: [$conf->{node}{$node}{hardware}{meminfo}{memtotal}]\n");
		if ($conf->{node}{$node}{hardware}{meminfo}{memtotal} < $conf->{resources}{total_ram})
		{
			$conf->{resources}{total_ram} = $conf->{node}{$node}{hardware}{meminfo}{memtotal};
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], res. total RAM: [$conf->{resources}{total_ram}]\n");
		}
		
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], res. total cores: [$conf->{resources}{total_cores}], hardware total node cores: [$conf->{node}{$node}{hardware}{total_node_cores}]\n");
		if ((not $conf->{resources}{total_cores}) || ($conf->{node}{$node}{hardware}{total_node_cores} < $conf->{resources}{total_cores}))
		{
			$conf->{resources}{total_cores} = $conf->{node}{$node}{hardware}{total_node_cores};
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], res. total cores: [$conf->{resources}{total_cores}]\n");
		}
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], res. total threads: [$conf->{resources}{total_threads}], hardware total node threads: [$conf->{node}{$node}{hardware}{total_node_cores}]\n");
		if ((not $conf->{resources}{total_threads}) || ($conf->{node}{$node}{hardware}{total_node_threads} < $conf->{resources}{total_threads}))
		{
			$conf->{resources}{total_threads} = $conf->{node}{$node}{hardware}{total_node_threads};
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], res. total threads: [$conf->{resources}{total_threads}]\n");
		}
		
		# Record the VG info. I only record the first node I see as I
		# only care about clustered VGs and they are, by definition,
		# identical.
		foreach my $vg (sort {$a cmp $b} keys %{$conf->{node}{$node}{hardware}{lvm}{vg}})
		{
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], VG: [$vg], clustered: [$conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{clustered}], size: [$conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{size}], used: [$conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{used_space}], free: [$conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{free_space}], PV: [$conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{pv_name}]\n");
			$conf->{resources}{vg}{$vg}{clustered}  = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{clustered}  if not $conf->{resources}{vg}{$vg}{clustered};
			$conf->{resources}{vg}{$vg}{pe_size}    = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{pe_size}    if not $conf->{resources}{vg}{$vg}{pe_size};
			$conf->{resources}{vg}{$vg}{total_pe}   = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{total_pe}   if not $conf->{resources}{vg}{$vg}{total_pe};
			$conf->{resources}{vg}{$vg}{pe_size}    = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{pe_size}    if not $conf->{resources}{vg}{$vg}{pe_size};
			$conf->{resources}{vg}{$vg}{size}       = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{size}       if not $conf->{resources}{vg}{$vg}{size};
			$conf->{resources}{vg}{$vg}{used_pe}    = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{used_pe}    if not $conf->{resources}{vg}{$vg}{used_pe};
			$conf->{resources}{vg}{$vg}{used_space} = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{used_space} if not $conf->{resources}{vg}{$vg}{used_space};
			$conf->{resources}{vg}{$vg}{free_pe}    = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{free_pe}    if not $conf->{resources}{vg}{$vg}{free_pe};
			$conf->{resources}{vg}{$vg}{free_space} = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{free_space} if not $conf->{resources}{vg}{$vg}{free_space};
			$conf->{resources}{vg}{$vg}{pv_name}    = $conf->{node}{$node}{hardware}{lvm}{vg}{$vg}{pv_name}    if not $conf->{resources}{vg}{$vg}{pv_name};
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], VG: [$vg], clustered: [$conf->{resources}{vg}{$vg}{clustered}], size: [$conf->{resources}{vg}{$vg}{size}], used: [$conf->{resources}{vg}{$vg}{used_space}], free: [$conf->{resources}{vg}{$vg}{free_space}], PV: [$conf->{resources}{vg}{$vg}{pv_name}]\n");
		}
	}
	
	# If both nodes have a given daemon down, then some data may be
	# unavailable. This saves logic when such checks are needed.
	my $this_cluster = $conf->{cgi}{cluster};
	my $node1 = $conf->{sys}{cluster}{node1_name};
	my $node2 = $conf->{sys}{cluster}{node2_name};
	my $node1_long = $conf->{node}{$node1}{info}{host_name};
	my $node2_long = $conf->{node}{$node2}{info}{host_name};
	$conf->{sys}{gfs2_down} = 0;
	if (($conf->{node}{$node1}{daemon}{gfs2}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{gfs2}{exit_code} ne "0"))
	{
		$conf->{sys}{gfs2_down} = 1;
	}
	$conf->{sys}{clvmd_down} = 0;
	if (($conf->{node}{$node1}{daemon}{clvmd}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{clvmd}{exit_code} ne "0"))
	{
		$conf->{sys}{clvmd_down} = 1;
	}
	$conf->{sys}{drbd_down} = 0;
	if (($conf->{node}{$node1}{daemon}{drbd}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{drbd}{exit_code} ne "0"))
	{
		$conf->{sys}{drbd_down} = 1;
	}
	$conf->{sys}{rgmanager_down} = 0;
	if (($conf->{node}{$node1}{daemon}{rgmanager}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{rgmanager}{exit_code} ne "0"))
	{
		$conf->{sys}{rgmanager_down} = 1;
	}
	$conf->{sys}{cman_down} = 0;
	if (($conf->{node}{$node1}{daemon}{cman}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{cman}{exit_code} ne "0"))
	{
		$conf->{sys}{cman_down} = 1;
	}
	
	# I want to map storage service to nodes for the "Withdraw" buttons.
# 	foreach my $service (sort {$a cmp $b} keys %{$conf->{service}})
# 	{
# 		#record($conf, "$THIS_FILE ".__LINE__."; service: [$service]\n");
# 		my $service_host  = $conf->{service}{$service}{host};
# 		my $service_state = $conf->{service}{$service}{'state'};
# 		next if $service !~ /storage/;
# 		#record($conf, "$THIS_FILE ".__LINE__."; service_host: [$service_host], service_state: [$service_state]\n");
# 
# 		my $short_host_name =  $service_host;
# 		   $short_host_name =~ s/\..*?//;
# 		#record($conf, "$THIS_FILE ".__LINE__."; short_host_name: [$short_host_name]\n");
# 		#record($conf, "$THIS_FILE ".__LINE__."; node1:           [$conf->{node}{$node1}{info}{short_host_name}]\n");
# 		#record($conf, "$THIS_FILE ".__LINE__."; node2:           [$conf->{node}{$node2}{info}{short_host_name}]\n");
# 		if ($short_host_name eq $conf->{node}{$node1}{info}{short_host_name})
# 		{
# 			$conf->{node}{$node1}{storage_service_name}  = $service;
# 			$conf->{node}{$node1}{storage_service_state} = $service_state;
# 			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node1], storage service: [$conf->{node}{$node1}{storage_service_name}], state: [$conf->{node}{$node1}{storage_service_state}]\n");
# 		}
# 		elsif ($short_host_name eq $conf->{node}{$node2}{info}{short_host_name})
# 		{
# 			$conf->{node}{$node2}{storage_service_name}  = $service;
# 			$conf->{node}{$node2}{storage_service_state} = $service_state;
# 			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node1], storage service: [$conf->{node}{$node2}{storage_service_name}], state: [$conf->{node}{$node2}{storage_service_state}]\n");
# 		}
# 	}

	return (0);
}

# This sorts out some values once the parsing is collected.
sub post_node_calculations
{
	my ($conf, $node) = @_;
	
	# If I have no $conf->{node}{$node}{hardware}{total_memory} value, use the 'meminfo' size.
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], hardware total memory: [$conf->{node}{$node}{hardware}{total_memory}], meminfo total memory: [$conf->{node}{$node}{hardware}{meminfo}{memtotal}]\n");
	#if ((not $conf->{node}{$node}{hardware}{total_memory}) || ($conf->{node}{$node}{hardware}{total_memory} > $conf->{node}{$node}{hardware}{meminfo}{memtotal}))
	if (not $conf->{node}{$node}{hardware}{total_memory})
	{
		$conf->{node}{$node}{hardware}{total_memory} = $conf->{node}{$node}{hardware}{meminfo}{memtotal};
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], total memory: [$conf->{node}{$node}{hardware}{total_memory}]\n");
	}
	
	# If the host name was set, then I can trust that I had good data.
	if ($conf->{node}{$node}{info}{host_name})
	{
		# Find out if the nodes are powered up or not.
		write_node_cache($conf, $node);
	}

	
	return (0);
}

# This takes a large number and inserts commas every three characters left of
# the decimal place. This method doesn't take a parameter hash reference.
sub comma
{
	my ($conf, $number) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; >> comma(); number: [$number]\n");
	
	# Return if nothing passed.
	return undef if not defined $number;

	# Strip out any existing commas.
	$number =~ s/,//g;
	$number =~ s/^\+//g;
	#record($conf, "$THIS_FILE ".__LINE__."; 1. number: [$number]\n");

	# Split on the left-most period.
	my ($whole, $decimal) = split/\./, $number, 2;
	#record($conf, "$THIS_FILE ".__LINE__."; >> whole: [$whole], decimal: [$decimal]\n");
	$whole   = "" if not defined $whole;
	$decimal = "" if not defined $decimal;
	#record($conf, "$THIS_FILE ".__LINE__."; << whole: [$whole], decimal: [$decimal]\n");

	# Now die if either number has a non-digit character in it.
	if (($whole =~ /\D/) || ($decimal =~ /\D/))
	{
		my $message = AN::Common::get_string($conf, {key => "message_0030", variables => {
			number	=>	$number,
		}});
		error($conf, $message, 1);
	}

	local($_) = $whole ? $whole : "";

	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	$whole = $_;

	my $return = $decimal ? "$whole.$decimal" : $whole;

	#record($conf, "$THIS_FILE ".__LINE__."; << comma(); number: [$number]\n");
	return ($return);
}

# This takes a raw number of bytes and returns a base-2 human-readible value.
# Takes a raw number of bytes (whole integer).
sub bytes_to_hr
{
	my ($conf, $size) = @_;

	# Expand exponential numbers.
	if ($size =~ /(\d+)e\+(\d+)/)
	{
		my $base = $1;
		my $exp  = $2;
		$size    = $base;
		for (1..$exp)
		{
			$size .= "0";
		}
	}

	# Setup my variables.
	my $suffix  = "";
	my $hr_size = $size;

	# Store and strip the sign
	my $sign = "";
	if ( $hr_size =~ /^-/ )
	{
		$sign    =  "-";
		$hr_size =~ s/^-//;
	}
	$hr_size =~ s/,//g;
	$hr_size =~ s/^\+//g;

	# Die if either the 'time' or 'float' has a non-digit character in it.  
	if ($hr_size =~ /\D/)
	{
		return("--");
		my $message = AN::Common::get_string($conf, {key => "message_0031", variables => {
			size	=>	$size,
		}});
		error($conf, $message, 1);
	}
	
	# Do the math.
	if ( $hr_size >= (2 ** 80) )
	{
		# Yebibyte
		$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 80)));
		$hr_size = comma($conf, $hr_size);
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0001"});
	}
	elsif ( $hr_size >= (2 ** 70) )
	{
		# Zebibyte
		$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 70)));
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0002"});
	}
	elsif ( $hr_size >= (2 ** 60) )
	{
		# Exbibyte
		$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 60)));
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0003"});
	}
	elsif ( $hr_size >= (2 ** 50) )
	{
		# Pebibyte
		$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 50)));
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0004"});
	}
	elsif ( $hr_size >= (2 ** 40) )
	{
		# Tebibyte
		$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 40)));
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0005"});
	}
	elsif ( $hr_size >= (2 ** 30) )
	{
		# Gibibyte
		$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 30)));
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0006"});
	}
	elsif ( $hr_size >= (2 ** 20) )
	{
		# Mebibyte
		$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 20)));
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0007"});
	}
	elsif ( $hr_size >= (2 ** 10) )
	{
		# Kibibyte
		$hr_size = sprintf("%.1f", ($hr_size /= (2 ** 10)));
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0008"});
	}
	else
	{
		### TODO: I don't know why, but $hr_size is being set to "" 
		###       when comma() returns 0. Fix this.
		#record($conf, "$THIS_FILE ".__LINE__."; >> bytes_to_hr; hr_size: [$hr_size]\n");
		$hr_size = comma($conf, $hr_size);
		$hr_size = 0 if $hr_size eq "";
		#record($conf, "$THIS_FILE ".__LINE__."; << bytes_to_hr; hr_size: [$hr_size]\n");
		$suffix  = AN::Common::get_string($conf, {key => "suffix_0009"});
	}

	# Restore the sign.
	if ( $sign eq "-" )
	{
		$hr_size = $sign.$hr_size;
	}
	$hr_size .= " $suffix";

	return($hr_size);
}

# This takes a "human readable" size with an ISO suffix and converts it back to
# a base byte size as accurately as possible.
sub hr_to_bytes
{
	my ($conf, $size, $type, $use_base2) = @_;
	# use_base2 will be set automatically *if* not passed by the caller.
	
	$type =  "" if not defined $type;
	$size =~ s/ //g;
	$type =~ s/ //g;
	#record($conf, "$THIS_FILE ".__LINE__."; size: [$size], type: [$type], use_base2: [$use_base2]\n");
	
	# Store and strip the sign
	my $sign = "";
	if ( $size =~ /^-/ )
	{
		$sign =  "-";
		$size =~ s/^-//;
	}
	$size =~ s/,//g;
	$size =~ s/^\+//g;
	
	# If I don't have a passed type, see if there is a letter or letters
	# after the size to hack off.
	if ((not $type) && ($size =~ /[a-zA-Z]$/))
	{
		($size, $type) = ($size =~ /^(.*\d)(\D+)/);
	}
	$type = lc($type);
	#record($conf, "$THIS_FILE ".__LINE__."; size: [$size], type: [$type], use_base2: [$use_base2]\n");
	
	# Make sure that 'size' is now an integer or float.
	if ($size !~ /\d+[\.\d+]?/)
	{
		# The variables will fill in the values in 'message_0029'.
		print AN::Common::template($conf, "common.html", "hr_to_bytes-error", {
			message	=>	"#!string!message_0032!#",
		}, {
			size	=>	$size,
			sign	=>	$sign,
			type	=>	$type,
			file	=>	$THIS_FILE,
			line	=>	__LINE__,
		});
		return (undef);
	}

	# If 'type' is still blank, set it to 'b'.
	$type = "b" if not $type;
	
	# If the "type" is "Xib", make sure we're running in Base2 notation.
	# Conversly, if the type is "Xb", make sure that we're running in
	# Base10 notation. In either case, shorten the 'type' to just the first
	# letter to make the next sanity check simpler.
	if ($type =~ /^(\w)ib$/)
	{
		# Make sure we're running in Base2.
		$use_base2 = 1 if not defined $use_base2;
		$type      = $1;
	}
	elsif ($type =~ /^(\w)b$/)
	{
		# Make sure we're running in Base2.
		$use_base2 = 0 if not defined $use_base2;
		$type      = $1;
	}
	#record($conf, "$THIS_FILE ".__LINE__."; size: [$size], type: [$type], use_base2: [$use_base2]\n");
	
	# Check if we have a valid '$type' and that 'Math::BigInt' is loaded,
	# if the size is big enough to require it.
	if (( $type eq "p" ) || ( $type eq "e" ) || ( $type eq "z" ) || ( $type eq "y" ))
	{
		# If this is a big size needing "Math::BigInt", check if it's loaded
		# yet and load it, if not.
		record($conf, "$THIS_FILE ".__LINE__."; Large number, loading Math::BigInt.\n");
		use Math::BigInt;
	}
	elsif (( $type ne "t" ) && ( $type ne "g" ) && ( $type ne "m" ) && ( $type ne "k" ))
	{
		# If we're here, we didn't match one of the large sizes or any
		# of the other sizes, so die.
		print AN::Common::template($conf, "common.html", "hr_to_bytes-error", {
			message	=>	"#!string!message_0033!#",
		}, {
			size	=>	$size,
			type	=>	$type,
			file	=>	$THIS_FILE,
			line	=>	__LINE__,
		});
		return (undef);
	}
	
	# Now the magic... lame magic, true, but still.
	my $bytes;
	if ($use_base2)
	{
		#record($conf, "$THIS_FILE ".__LINE__."; << type: [$type], size:  [$size].\n");
		if ( $type eq "y" ) { $bytes=Math::BigInt->new('2')->bpow('80')->bmul($size); }		# Yobibyte
		elsif ( $type eq "z" ) { $bytes=Math::BigInt->new('2')->bpow('70')->bmul($size); }	# Zibibyte
		elsif ( $type eq "e" ) { $bytes=Math::BigInt->new('2')->bpow('60')->bmul($size); }	# Exbibyte
		elsif ( $type eq "p" ) { $bytes=Math::BigInt->new('2')->bpow('50')->bmul($size); }	# Pebibyte
		elsif ( $type eq "t" ) { $bytes=($size*(2**40)) }					# Tebibyte
		elsif ( $type eq "g" ) { $bytes=($size*(2**30)) }					# Gibibyte
		elsif ( $type eq "m" ) { $bytes=($size*(2**20)) }					# Mebibyte
		elsif ( $type eq "k" ) { $bytes=($size*(2**10)) }					# Kibibyte
		#record($conf, "$THIS_FILE ".__LINE__."; >> type: [$type], bytes: [$bytes].\n");
	}
	else
	{
		if ( $type eq "y" ) { $bytes=Math::BigInt->new('10')->bpow('24')->bmul($size); }	# Yottabyte
		elsif ( $type eq "z" ) { $bytes=Math::BigInt->new('10')->bpow('21')->bmul($size); }	# Zettabyte
		elsif ( $type eq "e" ) { $bytes=Math::BigInt->new('10')->bpow('18')->bmul($size); }	# Exabyte
		elsif ( $type eq "p" ) { $bytes=Math::BigInt->new('10')->bpow('15')->bmul($size); }	# Petabyte
		elsif ( $type eq "t" ) { $bytes=($size*(10**12)) }					# Terabyte
		elsif ( $type eq "g" ) { $bytes=($size*(10**9)) }					# Gigabyte
		elsif ( $type eq "m" ) { $bytes=($size*(10**6)) }					# Megabyte
		elsif ( $type eq "k" ) { $bytes=($size*(10**3)) }					# Kilobyte
	}
	
	# Last, round off the byte size if it's a float.
	if ( $bytes =~ /\./ )
	{
		$bytes =~ s/\..*$//;
	}
	
	return ($sign.$bytes);
}

# This tries to ping a node given it's name. If it doesn't answer, it tries 
# again after adding/subtracting the '.remote' suffix. If that works, it will
# change the node name.
sub ping_node
{
	my ($conf, $node) = @_;
	
	my $exit;
	my $shell_call = "$conf->{path}{ping} -c 1 $node; echo ping:\$?";
	record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^ping:(\d+)/)
		{
			$exit = $1;
		}
	}
	close $file_handle;
	record($conf, "$THIS_FILE ".__LINE__."; exit: [$exit]\n");
	
	if ($exit)
	{
		my $old_node = $node;
		if ($node =~ /\.remote/)
		{
			$node =~ s/\.remote//;
		}
		else
		{
			$node .= ".remote";
		}
		my $shell_call = "$conf->{path}{ping} -c 1 $node; echo ping:\$?";
		record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
		open ($file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^ping:(\d+)/)
			{
				$exit = $1;
			}
		}
		close $file_handle;
		record($conf, "$THIS_FILE ".__LINE__."; exit: [$exit]\n");
		
		if ($exit)
		{
			record($conf, "$THIS_FILE ".__LINE__."; Unable to ping the node: [$old_node] at alternate name: [$node]\n");
			$node = $old_node;
		}
		else
		{
			record($conf, "$THIS_FILE ".__LINE__."; The node: [$old_node] appears to be available at: [$node], renaming.\n");
		}
	}
	else
	{
		record($conf, "$THIS_FILE ".__LINE__."; The node: [$node] is ping-able.\n");
	}
	
	record($conf, "$THIS_FILE ".__LINE__."; Returning node: [$node].\n");
	return ($node);
}

# This does the actual calls out to get the data and parse the returned data.
sub gather_node_details
{
	my ($conf, $node) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; in gather_node_details() for node: [$node]\n");
	
	# This will flip true if I see dmidecode data, the first command I call
	# on the node.
	$conf->{node}{$node}{connected}      = 0;
	$conf->{node}{$node}{info}{'state'}  = "<span class=\"highlight_unavailable\">#!string!row_0003!#</span>";
	$conf->{node}{$node}{info}{note}     = "";
	$conf->{node}{$node}{up}             = 0;
	$conf->{node}{$node}{enable_poweron} = 0;
	
	my $cluster                     = $conf->{cgi}{cluster};
	$conf->{node}{$node}{connected} = 0;
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], port: [$conf->{node}{$node}{port}], user: [root], password: [$conf->{sys}{root_password}]\n");
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], port: [$conf->{node}{$node}{port}], user: [root]\n");
	my $shell_call = "dmidecode -t 4,16,17";
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	my ($error, $ssh_fh, $dmidecode) = remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], dmidecode: [$dmidecode (".@{$dmidecode}." lines)]\n");
	if ($error)
	{
		record($conf, "$THIS_FILE ".__LINE__."; Error: [$error], setting daemon states to 'Unknown'.\n");
		$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_warning_bold\">#!string!row_0041!#</span>";
		$conf->{node}{$node}{info}{note}    = $error;
		set_daemons($conf, $node, "Unknown", "highlight_unavailable");
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; \@{$dmidecode}: [".@{$dmidecode}."]\n");
	if ((ref($dmidecode)) && (@{$dmidecode} > 0))
	{
		$conf->{node}{$node}{connected} = 1;
	}
	
	record($conf, "$THIS_FILE ".__LINE__."; connected: [$conf->{node}{$node}{connected}], ssh_fh: [$ssh_fh]\n");
	if ($conf->{node}{$node}{connected})
	{
		# Record that this node is up.
		$conf->{sys}{online_nodes} = 1;
		$conf->{node}{$node}{up}   = 1;
		push @{$conf->{up_nodes}}, $node;
		record($conf, "$THIS_FILE ".__LINE__."; node::${node}::up: [$conf->{node}{$node}{up}], up_nodes: [".@{$conf->{up_nodes}}."]\n");
		
		### Get the rest of the shell calls done before starting to
		### parse.
		# Get meminfo
		my $shell_call = "cat /proc/meminfo";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $meminfo) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], meminfo: [$meminfo (".@{$meminfo}." lines)]\n");
		
		# Get drbd info
		$shell_call = "if [ -e /proc/drbd ]; then cat /proc/drbd; else echo 'drbd offline'; fi";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $proc_drbd) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], proc_drbd: [$proc_drbd (".@{$proc_drbd}." lines)]\n");
		#foreach my $line (@{$proc_drbd}) { record($conf, "$THIS_FILE ".__LINE__."; proc_drbd line: [$line]\n"); }
		
		$shell_call = "drbdadm dump-xml";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $parse_drbdadm_dumpxml) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], drbd_res_file: [$parse_drbdadm_dumpxml (".@{$parse_drbdadm_dumpxml}." lines)]\n");
		
		# clustat info
		$shell_call = "clustat";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $clustat) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], clustat: [$clustat (".@{$clustat}." lines)]\n");
		
		# Read cluster.conf
		$shell_call = "cat /etc/cluster/cluster.conf";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $cluster_conf) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], cluster_conf: [$cluster_conf (".@{$cluster_conf}." lines)]\n");
		
		### TODO: Break these up into individual calls to be cleaner.
		# Read the daemon states
		$shell_call = "
/etc/init.d/rgmanager status; echo striker:rgmanager:\$?; 
/etc/init.d/cman status; echo striker:cman:\$?; 
/etc/init.d/drbd status; echo striker:drbd:\$?; 
/etc/init.d/clvmd status; echo striker:clvmd:\$?; 
/etc/init.d/gfs2 status; echo striker:gfs2:\$?; 
/etc/init.d/libvirtd status; echo striker:libvirtd:\$?;";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $daemons) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], daemons: [$daemons (".@{$daemons}." lines)]\n");
		
		# LVM data
		$shell_call = "pvscan; vgscan; lvscan";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $lvm_scan) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], lvm_scan: [$lvm_scan (".@{$lvm_scan}." lines)]\n");
		$shell_call = "
pvs --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid; 
vgs --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name; 
lvs --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices;",
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $lvm_data) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], lvm_data: [$lvm_data (".@{$lvm_data}." lines)]\n");
		
		# GFS2 data
		$shell_call = "cat /etc/fstab | grep gfs2 && df -hP";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $gfs2) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], gfs2: [$gfs2 (".@{$gfs2}." lines)]\n");
		
		# virsh data
		#record($conf, "$THIS_FILE ".__LINE__."; Calling: [virsh list --all]\n");
		$shell_call = "virsh list --all";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $virsh) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], virsh: [$virsh (".@{$virsh}." lines)]\n");
		
		# VM definitions - from file
		$shell_call = "cat /shared/definitions/*";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $vm_defs) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], vm_defs: [$vm_defs (".@{$vm_defs}." lines)]\n");
		
		# VM definitions - in memory
		$shell_call = "
for server in \$(virsh list | grep running | awk '{print \$2}'); 
do 
    virsh dumpxml \$server; 
done
";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $vm_defs_in_mem) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], vm_defs: [$vm_defs (".@{$vm_defs}." lines)]\n");
		
		# Host name, in case the cluster isn't configured yet.
		$shell_call = "hostname";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $hostname) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], hostname->[0]: [$hostname->[0]]\n");
		if ($hostname->[0])
		{
			$conf->{node}{$node}{info}{host_name} = $hostname->[0]; 
			#record($conf, "$THIS_FILE ".__LINE__."; node::${node}::info::host_name: [$conf->{node}{$node}{info}{host_name}]\n");
		}
		
		# Read the node's host file.
		$shell_call = "cat /etc/hosts";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $hosts) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], hosts: [$hosts]\n");
		
		# Read the node's dmesg.
		$shell_call = "dmesg";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $dmesg) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], dmesg: [$dmesg]\n");
		
		### Last call, close the door on our way out.
		# Bond data
		$shell_call = "
if [ -e '/proc/net/bonding/ifn_bond1' ];
then
    for i in \$(ls /proc/net/bonding/); 
    do 
        if [ \$i != 'bond0' ];
        then
            echo 'start: \$i';
            cat /proc/net/bonding/\$i;
        fi
    done
else
    for i in \$(ls /proc/net/bonding/bond*);
    do
        echo 'start: \$i';
        cat \$i;
    done;
fi;";
		#record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, my $bond) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], bond: [$bond (".@{$bond}." lines)]\n");
		
		parse_dmidecode      ($conf, $node, $dmidecode);
		parse_meminfo        ($conf, $node, $meminfo);
		parse_drbdadm_dumpxml($conf, $node, $parse_drbdadm_dumpxml);
		parse_proc_drbd      ($conf, $node, $proc_drbd);
		parse_clustat        ($conf, $node, $clustat);
		parse_cluster_conf   ($conf, $node, $cluster_conf);
		parse_daemons        ($conf, $node, $daemons);
		parse_lvm_scan       ($conf, $node, $lvm_scan);
		parse_lvm_data       ($conf, $node, $lvm_data);
		parse_gfs2           ($conf, $node, $gfs2);
		parse_virsh          ($conf, $node, $virsh);
		parse_vm_defs        ($conf, $node, $vm_defs);
		parse_vm_defs_in_mem ($conf, $node, $vm_defs_in_mem);	# Always parse this after 'parse_vm_defs()' so that we overwrite it.
		parse_bonds          ($conf, $node, $bond);
		parse_hosts          ($conf, $node, $hosts);
		parse_dmesg          ($conf, $node, $dmesg);
		# Some stuff, like setting the system memory, needs some
		# post-scan math.
		post_node_calculations($conf, $node);
	}
	else
	{
		check_if_on($conf, $node);
		record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
		if ($conf->{node}{$node}{is_on} == 0)
		{
			$conf->{sys}{online_nodes}            = 1;
			$conf->{node}{$node}{enable_poweron}  = 1;
			$conf->{node}{$node}{enable_poweroff} = 0;
			$conf->{node}{$node}{enable_fence}    = 0;
			#$conf->{node}{$node}{info}{'state'}   = "<span class=\"highlight_warning\">Powered Off</span>";
			#$conf->{node}{$node}{info}{note}      = "The node <span class=\"fixed_width\">$node</span> is powered down.";
		}
		elsif ($conf->{node}{$node}{is_on} == 1)
		{
			# The node is on but unreachable.
			$conf->{sys}{online_nodes}         = 1;
			$conf->{node}{$node}{enable_poweron}  = 0;
			$conf->{node}{$node}{enable_poweroff} = 1;
			# Disable poweroff if I wasn't able to SSH into the
			# node.
			if (not $conf->{node}{$node}{connected})
			{
				$conf->{node}{$node}{enable_poweroff} = 0;
			}
			$conf->{node}{$node}{enable_fence} = 1;
			if (not $conf->{node}{$node}{info}{'state'})
			{
				# No access
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0033!#</span>";
			}
			if (not $conf->{node}{$node}{info}{note})
			{
				# Unable to log into node.
				$conf->{node}{$node}{info}{note} = AN::Common::get_string($conf, {key => "message_0034", variables => {
					node	=>	$node,
				}});
			}
			record($conf, "$THIS_FILE ".__LINE__."; setting daemon states to 'Unknown'.\n");
			set_daemons($conf, $node, "Unknown", "highlight_unavailable");
		}
		elsif ($conf->{node}{$node}{is_on} == 2)
		{
			# The node is on but unreachable.
			$conf->{sys}{online_nodes}         = 0;
			$conf->{node}{$node}{enable_poweron}  = 0;
			$conf->{node}{$node}{enable_poweroff} = 0;
			if (not $conf->{node}{$node}{info}{'state'})
			{
				# Inaccessible
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0042!#</span>";
			}
			if (not $conf->{node}{$node}{info}{note})
			{
				# Unable to log into the node or contact it's
				# out of band management interface.
				$conf->{node}{$node}{info}{note} = AN::Common::get_string($conf, {key => "message_0035", variables => {
					node	=>	$node,
				}});
			}
			record($conf, "$THIS_FILE ".__LINE__."; setting daemon states to 'Unknown'.\n");
			set_daemons($conf, $node, "Unknown", "highlight_unavailable");
		}
		elsif ($conf->{node}{$node}{is_on} == 3)
		{
			# The node is on but unreachable.
			$conf->{sys}{online_nodes}         = 0;
			$conf->{node}{$node}{enable_poweron}  = 0;
			$conf->{node}{$node}{enable_poweroff} = 0;
			if (not $conf->{node}{$node}{info}{'state'})
			{
				# Inaccessible
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0042!#</span>";
			}
			if (not $conf->{node}{$node}{info}{note})
			{
				# Unable to log into the node, can't connect to
				# it's IPMI interface and not on the same
				# subnet.
				$conf->{node}{$node}{info}{note} = AN::Common::get_string($conf, {key => "message_0036", variables => {
					node	=>	$node,
				}});
			}
			record($conf, "$THIS_FILE ".__LINE__."; setting daemon states to 'Unknown'.\n");
			set_daemons($conf, $node, "Unknown", "highlight_unavailable");
		}
		else
		{
			# Unable to determine node state.
			$conf->{node}{$node}{enable_poweron}  = 0;
			$conf->{node}{$node}{enable_poweroff} = 0;
			$conf->{node}{$node}{enable_fence}    = 0;
			if (not $conf->{node}{$node}{info}{'state'})
			{
				# No access
				$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0033!#</span>";
			}
			if (not $conf->{node}{$node}{info}{note})
			{
				$conf->{node}{$node}{info}{note} = AN::Common::get_string($conf, {key => "message_0037", variables => {
					node	=>	$node,
				}});
			}
			record($conf, "$THIS_FILE ".__LINE__."; setting daemon states to 'Unknown'.\n");
			set_daemons($conf, $node, "Unknown", "highlight_unavailable");
		}
		
		# If I have confirmed the node is powered off, don't display this.
		#record($conf, "$THIS_FILE ".__LINE__."; enable power on: [$conf->{node}{$node}{enable_poweron}], task: [$conf->{cgi}{task}]\n");
		if ((not $conf->{node}{$node}{enable_poweron}) && (not $conf->{cgi}{task}))
		{
			print AN::Common::template($conf, "main-page.html", "node-state-table", {
				'state'	=>	$conf->{node}{$node}{info}{'state'},
				note	=>	$conf->{node}{$node}{info}{note},
			}); 
		}
	}
	
	return (0);
}

# This reads in the rsa public key for the dashboard user.
sub get_rsa_public_key
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; get_rsa_public_key()\n");
	
	my $rsa_public_key  = "";
	my $rsa_public_file = "$conf->{path}{'striker_files'}/.ssh/id_rsa.pub";
	if (not -e $rsa_public_file)
	{
		record($conf, "$THIS_FILE ".__LINE__."; rsa_public_file: [$rsa_public_file] doesn't exist, trying to create it now.\n");
		
		my $shell_call = "$conf->{path}{'ssh-keygen'} -t rsa -N \"\" -b 4095 -f $conf->{path}{'striker_files'}/.ssh/id_rsa";
		record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
		close $file_handle;
		
		if (not -e $rsa_public_file)
		{
			record($conf, "$THIS_FILE ".__LINE__."; Failed to create a new SSH key.\n");
		}
	}
	
	my $shell_call = $rsa_public_file;
	record($conf, "$THIS_FILE ".__LINE__."; Reading: [$shell_call]\n");
	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line =  $_;
		   $line =~ s/^\s+//;
		   $line =~ s/\s+$//;
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		next if $line =~ /^#/;
		$rsa_public_key = $line;
		#record($conf, "$THIS_FILE ".__LINE__."; rsa_public_key: [$rsa_public_key]\n");
		last;
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; rsa_public_key: [$rsa_public_key]\n");
	return($rsa_public_key);
}

# This gets this machine's hostname.
sub get_hostname
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; get_hostname()\n");

	my $hostname;
	my $shell_call = "$conf->{path}{hostname}";
	record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
	open (my $file_handle, "<$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		$hostname = $_;
		record($conf, "$THIS_FILE ".__LINE__."; hostname: [$hostname]\n");
	}
	close $file_handle;
	
	record($conf, "$THIS_FILE ".__LINE__."; hostname: [$hostname]\n");
	return($hostname);
}

# This calls the target machine and runs a command.
sub remote_call
{
	my ($conf, $parameters) = @_;
	
	#record($conf, "$THIS_FILE ".__LINE__."; parameters->{password}: [$parameters->{password}], sys::root_password: [$conf->{sys}{root_password}]\n");
	my $cluster    = $conf->{cgi}{cluster};
	my $node       = $parameters->{node};
	my $port       = $parameters->{port}             ? $parameters->{port}     : 22;
	my $user       = $parameters->{user}             ? $parameters->{user}     : "root";
	my $password   = $parameters->{password}         ? $parameters->{password} : $conf->{sys}{root_password};
	my $ssh_fh     = $parameters->{ssh_fh}           ? $parameters->{ssh_fh}   : "";
	my $close      = defined $parameters->{'close'}  ? $parameters->{'close'}  : 1;
	my $shell_call = $parameters->{shell_call};
	#record($conf, "$THIS_FILE ".__LINE__."; cluster: [$cluster], node: [$node], port: [$port], user: [$user], password: [$password], ssh_fh: [$ssh_fh], close: [$close], shell_call: [$shell_call]\n");
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], ssh_fh: [$ssh_fh], close: [$close], shell_call: [$shell_call]\n");
	
	### TODO: Make this a better looking error.
	if (not $node)
	{
		# No node...
		my $say_error = AN::Common::get_string($conf, {key => "message_0274", variables => {
				shell_call	=>	$shell_call,
			}});
		error($conf, "$say_error\n");
	}
	
	# Break out the port, if needed.
	my $state;
	my $error;
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node]\n");
	if ($node =~ /^(.*):(\d+)$/)
	{
		#record($conf, "$THIS_FILE ".__LINE__."; >> node: [$node], port: [$port]\n");
		$node = $1;
		$port = $2;
		#record($conf, "$THIS_FILE ".__LINE__."; << node: [$node], port: [$port]\n");
		if (($port < 0) || ($port > 65536))
		{
			# Variables for 'message_0373'.
			$error = AN::Common::get_string($conf, {key => "message_0373", variables => {
				node	=>	"$node",
				port	=>	"$port",
			}});
			record($conf, "$THIS_FILE ".__LINE__."; $error\n");
		}
	}
	else
	{
		# In case the user is using ports in /etc/ssh/ssh_config,
		# we'll want to check for an entry.
		#record($conf, "$THIS_FILE ".__LINE__."; reading ssh_config...\n");
		read_ssh_config($conf);
		#record($conf, "$THIS_FILE ".__LINE__."; hosts::${node}::port: [$conf->{hosts}{$node}{port}]\n");
		if ($conf->{hosts}{$node}{port})
		{
			$port = $conf->{hosts}{$node}{port};
			#record($conf, "$THIS_FILE ".__LINE__."; port: [$port]\n");
		}
	}
	
	# These will be merged into a single 'output' array before returning.
	my $stdout_output = [];
	my $stderr_output = [];
	#record($conf, "$THIS_FILE ".__LINE__."; ssh_fh: [$ssh_fh]\n");
	if ($ssh_fh !~ /^Net::SSH2/)
	{
		#record($conf, "$THIS_FILE ".__LINE__."; Opening an SSH connection to: [$user\@$node:$port].\n");
		$ssh_fh = Net::SSH2->new();
		if (not $ssh_fh->connect($node, $port, Timeout => 10))
		{
			record($conf, "$THIS_FILE ".__LINE__."; error: [$@]\n");
			if ($@ =~ /Bad hostname/)
			{
				$error = AN::Common::get_string($conf, {key => "message_0038", variables => {
					node	=>	$node,
				}});
				record($conf, "$THIS_FILE ".__LINE__."; $error\n");
			}
			elsif ($@ =~ /Connection refused/)
			{
				$error = AN::Common::get_string($conf, {key => "message_0039", variables => {
					node	=>	$node,
					port	=>	$port,
					user	=>	$user,
				}});
				record($conf, "$THIS_FILE ".__LINE__."; $error\n");
			}
			elsif ($@ =~ /No route to host/)
			{
				$error = AN::Common::get_string($conf, {key => "message_0040", variables => {
					node	=>	$node,
				}});
				record($conf, "$THIS_FILE ".__LINE__."; $error\n");
			}
			elsif ($@ =~ /timeout/)
			{
				$error = AN::Common::get_string($conf, {key => "message_0041", variables => {
					node	=>	$node,
				}});
				record($conf, "$THIS_FILE ".__LINE__."; $error\n");
			}
			else
			{
				$error = AN::Common::get_string($conf, {key => "message_0042", variables => {
					node	=>	$node,
					error	=>	$@,
				}});
				record($conf, "$THIS_FILE ".__LINE__."; $error\n");
			}
		}
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh]\n");
		if (not $error)
		{
			#record($conf, "$THIS_FILE ".__LINE__."; user: [$user], password: [$password]\n");
			if (not $ssh_fh->auth_password($user, $password)) 
			{
				$error = AN::Common::get_string($conf, {key => "message_0043"});
				record($conf, "$THIS_FILE ".__LINE__."; $error\n");
			}
			else
			{
				#record($conf, "$THIS_FILE ".__LINE__."; SSH session opened to: [$node].\n");
			}
		}
	}
	
	### Special thanks to Rafael Kitover (rkitover@gmail.com), maintainer
	### of Net::SSH2, for helping me sort out the polling and data
	### collection in this section.
	#
	# Open a channel and make the call.
	#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh]\n");
	if (($ssh_fh =~ /^Net::SSH2/) && (not $error))
	{
		# We need to open a channel every time for 'exec' calls. We
		# want to keep blocking off, but we need to enable it for the
		# channel() call.
		$ssh_fh->blocking(1);
		my $channel = $ssh_fh->channel();
		$ssh_fh->blocking(0);
		
		# Make the shell call
		if (not $channel)
		{
			$error  = "Failed to establish channel to node: [$node] for shell call: [$shell_call]\n";
			$ssh_fh = "";
		}
		else
		{
			#record($conf, "$THIS_FILE ".__LINE__."; channel: [$channel], shell_call: [$shell_call]\n");
			$channel->exec("$shell_call");
			
			# This keeps the connection open when the remote side is slow
			# to return data, like in '/etc/init.d/rgmanager stop'.
			my @poll = {
				handle => $channel,
				events => [qw/in err/],
			};
			
			# We'll store the STDOUT and STDERR data here.
			my $stdout = "";
			my $stderr = "";
			
			# Not collect the data.
			while(1)
			{
				$ssh_fh->poll(250, \@poll);
				
				# Read in anything from STDOUT
				while($channel->read(my $chunk, 80))
				{
					$stdout .= $chunk;
				}
				while ($stdout =~ s/^(.*)\n//)
				{
					my $line = $1;
					#record($conf, "$THIS_FILE ".__LINE__."; STDOUT: [$line].\n");
					push @{$stdout_output}, $line;
				}
				
				# Read in anything from STDERR
				while($channel->read(my $chunk, 80, 1))
				{
					$stderr .= $chunk;
				}
				while ($stderr =~ s/^(.*)\n//)
				{
					my $line = $1;
					#record($conf, "$THIS_FILE ".__LINE__."; STDERR: [$line].\n");
					push @{$stderr_output}, $line;
				}
				
				# Exit when we get the end-of-file.
				last if $channel->eof;
			}
			if ($stdout)
			{
				#record($conf, "$THIS_FILE ".__LINE__."; stdout: [$stdout].\n");
				push @{$stdout_output}, $stdout;
			}
			if ($stderr)
			{
				#record($conf, "$THIS_FILE ".__LINE__."; stderr: [$stderr].\n");
				push @{$stderr_output}, $stderr;
			}
		}
	}
	
	# Merge the STDOUT and STDERR
	my $output = [];
	
	foreach my $line (@{$stderr_output}, @{$stdout_output})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; Merge; line: [$line]\n");
		push @{$output}, $line;
	}
	
	# Close the connection if requested.
	if ($close)
	{
		#record($conf, "$THIS_FILE ".__LINE__."; Disconnecting from: [$node]\n");
		$ssh_fh->disconnect();
		
		# For good measure, blank both variables.
		$conf->{node}{$node}{ssh_fh} = "";
		$ssh_fh                      = "";
	}
	
	$error = "" if not defined $error;
	#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	return($error, $ssh_fh, $output);
}

# This parses the node's /etc/hosts file so that it can pull out the IPs for
# anything matching the node's short name and record it in the local cache.
sub parse_hosts
{
	my ($conf, $node, $array) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; parse_hosts(); node: [$node], array: [$array (".@{$array}." lines)]\n");
	
	foreach my $line (@{$array})
	{
		# This code is copy-pasted from read_hosts(), save for the hash is records to.
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		$line =~ s/#.*$//;
		$line =~ s/\s+$//;
		next if not $line;
		next if $line =~ /^127.0.0.1\s/;
		next if $line =~ /^::1\s/;
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		
		my ($this_ip, $these_hosts);
		if ($line =~ /^(\d+\.\d+\.\d+\.\d+)\s+(.*)/)
		{
			$this_ip     = $1;
			$these_hosts = $2;
			foreach my $this_host (split/ /, $these_hosts)
			{
				next if not $this_host;
				$conf->{node}{$node}{hosts}{$this_host}{ip} = $this_ip;
				if (not exists $conf->{node}{$node}{hosts}{by_ip}{$this_ip})
				{
					$conf->{node}{$node}{hosts}{by_ip}{$this_ip} = "";
				}
				$conf->{node}{$node}{hosts}{by_ip}{$this_ip} .= "$this_host,";
				#record($conf, "$THIS_FILE ".__LINE__."; this_host: [$this_host] -> this_ip: [$conf->{node}{$node}{hosts}{$this_host}{ip}] ($conf->{node}{$node}{hosts}{by_ip}{$this_ip})\n");
			}
		}
	}
	
	return(0);
}

### TODO: Finish this and get a better view of the system
# This parses dmesg
sub parse_dmesg
{
	my ($conf, $node, $array) = @_;
	
	foreach my $line (@{$array})
	{
		# Parse out the real RAM total and reserved RAM total.
		if ($line =~ /Memory: (.*)/)
		{
			my $memory = $1;
			
		}
	}
	
	
	return(0);
}


### TODO: Finish this and add it to the node management
# This parse bond data
sub parse_bonds
{
	my ($conf, $node, $array) = @_;
	
	my $this_bond;
	foreach my $line (@{$array})
	{
		# Find the start of a domain.
		if ($line =~ /start: \/proc\/net\/bonding\/bond(\d+)/)
		{
			$this_bond = $1;
		}
		next if not $this_bond;
		#record($conf, "$THIS_FILE ".__LINE__."; this_bond: [$this_bond], line: [$line]\n");
	}
	
	return (0);
}

# This (tries to) parse the VM definitions as they are in memory.
sub parse_vm_defs_in_mem
{
	my ($conf, $node, $array) = @_;
	
	record($conf, "$THIS_FILE ".__LINE__."; in parse_vm_defs_in_mem() for node: [$node]\n");
	my $this_vm    = "";
	my $in_domain  = 0;
	my $this_array = [];
	foreach my $line (@{$array})
	{
		record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		# Find the start of a domain.
		if ($line =~ /<domain/)
		{
			$in_domain = 1;
		}
		
		# Get this name of the current domain
		if ($line =~ /<name>(.*?)<\/name>/)
		{
			$this_vm = $1;
		}
		
		# Push all lines into the current domain array.
		if ($in_domain)
		{
			push @{$this_array}, $line;
		}
		
		# When the end of a domain is found, push the array over to
		# $conf.
		if ($line =~ /<\/domain>/)
		{
			my $vm_key = "vm:$this_vm";
			#record($conf, "$THIS_FILE ".__LINE__."; vm: [$this_vm], array: [$this_array], lines: [".@{$this_array}."]\n");
			$conf->{vm}{$vm_key}{xml} = $this_array;
			$in_domain  = 0;
			$this_array = [];
		}
	}
	
	return (0);
}

# This (tries to) parse the VM definitions files.
sub parse_vm_defs
{
	my ($conf, $node, $array) = @_;
	
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_vm_defs() for node: [$node]\n");
	my $this_vm    = "";
	my $in_domain  = 0;
	my $this_array = [];
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		# Find the start of a domain.
		if ($line =~ /<domain/)
		{
			$in_domain = 1;
		}
		
		# Get this name of the current domain
		if ($line =~ /<name>(.*?)<\/name>/)
		{
			$this_vm = $1;
		}
		
		# Push all lines into the current domain array.
		if ($in_domain)
		{
			push @{$this_array}, $line;
		}
		
		# When the end of a domain is found, push the array over to
		# $conf.
		if ($line =~ /<\/domain>/)
		{
			my $vm_key = "vm:$this_vm";
			#record($conf, "$THIS_FILE ".__LINE__."; vm: [$this_vm], array: [$this_array], lines: [".@{$this_array}."]\n");
			$conf->{vm}{$vm_key}{xml} = $this_array;
			$in_domain  = 0;
			$this_array = [];
		}
	}
	
	return (0);
}

# Parse the dmidecode data.
sub parse_dmidecode
{
	my ($conf, $node, $array) = @_;
	
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_dmidecode() for node: [$node]\n");
	#foreach my $line (@{$array}) { record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	# Some variables I will need.
	my $in_cpu           = 0;
	my $in_system_ram    = 0;
	my $in_dimm_module   = 0;
	
	# On SMP machines, the CPU socket becomes important. This 
	# tracks which CPU I am looking at.
	my $this_socket      = "";
	
	# Same deal with volume groups.
	my $this_vg          = "";
	
	# RAM is all over the place, so I need to record all the bits
	# in strings and push to the hash when I see a blank line.
	my $dimm_locator     = "";
	my $dimm_bank        = "";
	my $dimm_size        = "";
	my $dimm_type        = "";
	my $dimm_speed       = "";
	my $dimm_form_factor = "";
	
	# This will be set to the values I find on this node.
	$conf->{node}{$node}{hardware}{total_node_cores}   = 0;
	$conf->{node}{$node}{hardware}{total_node_threads} = 0;
	$conf->{node}{$node}{hardware}{total_memory}       = 0;
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], total cores: [$conf->{node}{$node}{hardware}{total_node_cores}], total threads: [$conf->{node}{$node}{hardware}{total_node_threads}], total memory: [$conf->{node}{$node}{hardware}{total_memory}]\n");
	
	# These will be set to the lowest available RAM, and CPU core
	# available.
	$conf->{resources}{total_cores}   = 0;
	$conf->{resources}{total_threads} = 0;
	$conf->{resources}{total_ram}     = 0;
	#record($conf, "$THIS_FILE ".__LINE__."; Cluster; total cores: [$conf->{resources}{total_cores}], total threads: [$conf->{resources}{total_threads}], total memory: [$conf->{resources}{total_ram}]\n");
	
	foreach my $line (@{$array})
	{
		if ($line =~ /dmidecode: command not found/)
		{
			die "$THIS_FILE ".__LINE__."; Unable to read system information on node: [$node]. Is 'dmidecode' installed?";
		}
		
		# Find out what I am looking at.
		if (not $line)
		{
			# Blank lines break sections.
			# If I had been reading DIMM info, push it into
			# the hash.
			if ($in_dimm_module)
			{
				$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{bank}        = $dimm_bank;
				$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{size}        = $dimm_size;
				$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{type}        = $dimm_type;
				$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{speed}       = $dimm_speed;
				$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{form_factor} = $dimm_form_factor;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], dimm: [$dimm_locator], bank: [$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{bank}], size: [$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{size}], type: [$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{type}], speed: [$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{speed}], form factor: [$conf->{node}{$node}{hardware}{dimm}{$dimm_locator}{form_factor}]\n");
			}
			$in_cpu         = 0;
			$in_system_ram  = 0;
			$in_dimm_module = 0;
			$this_socket    = "";
			$this_vg        = "";
			next;
		}
		if ($line =~ /Processor Information/)
		{
			$in_cpu         = 1;
			next;
		}
		if ($line =~ /Physical Memory Array/)
		{
			$in_system_ram  = 1;
			next;
		}
		if ($line =~ /Memory Device/)
		{
			$in_dimm_module = 1;
			next;
		}
		if ((not $in_cpu) && (not $in_system_ram) && (not $in_dimm_module))
		{
			next;
		}
		
		# Now pull out data based on where I am.
		if ($in_cpu)
		{
			# The socket is the first line, so I can safely
			# assume that 'this_socket' will be populated
			# after this.
			if ($line =~ /Socket Designation: (.*)/)
			{
				$this_socket = $1;
				next;
			}
			
			# Grab some deets!
			if ($line =~ /Family: (.*)/)
			{
				$conf->{node}{$node}{hardware}{cpu}{$this_socket}{family}    = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], socket: [$this_socket], cpu family: [$conf->{node}{$node}{hardware}{cpu}{$this_socket}{family}]\n");
			}
			if ($line =~ /Manufacturer: (.*)/)
			{
				$conf->{node}{$node}{hardware}{cpu}{$this_socket}{oem}       = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], socket: [$this_socket], cpu oem: [$conf->{node}{$node}{hardware}{cpu}{$this_socket}{oem}]\n");
			}
			if ($line =~ /Version: (.*)/)
			{
				$conf->{node}{$node}{hardware}{cpu}{$this_socket}{version}   = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], socket: [$this_socket], cpu version: [$conf->{node}{$node}{hardware}{cpu}{$this_socket}{version}]\n");
			}
			if ($line =~ /Max Speed: (.*)/)
			{
				$conf->{node}{$node}{hardware}{cpu}{$this_socket}{max_speed} = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], socket: [$this_socket], cpu max speed: [$conf->{node}{$node}{hardware}{cpu}{$this_socket}{max_speed}]\n");
			}
			if ($line =~ /Status: (.*)/)
			{
				$conf->{node}{$node}{hardware}{cpu}{$this_socket}{status}    = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], socket: [$this_socket], cpu status: [$conf->{node}{$node}{hardware}{cpu}{$this_socket}{status}]\n");
			}
			if ($line =~ /Core Count: (.*)/)
			{
				$conf->{node}{$node}{hardware}{cpu}{$this_socket}{cores} =  $1;
				$conf->{node}{$node}{hardware}{total_node_cores}         += $conf->{node}{$node}{hardware}{cpu}{$this_socket}{cores};
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], socket: [$this_socket], socket cores: [$conf->{node}{$node}{hardware}{cpu}{$this_socket}{cores}], total cores: [$conf->{node}{$node}{hardware}{total_node_cores}]\n");
			}
			if ($line =~ /Thread Count: (.*)/)
			{
				$conf->{node}{$node}{hardware}{cpu}{$this_socket}{threads} =  $1;
				$conf->{node}{$node}{hardware}{total_node_threads}         += $conf->{node}{$node}{hardware}{cpu}{$this_socket}{threads};
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], socket: [$this_socket], socket threads: [$conf->{node}{$node}{hardware}{cpu}{$this_socket}{threads}], total threads: [$conf->{node}{$node}{hardware}{total_node_threads}]\n");
			}
		}
		if ($in_system_ram)
		{
			# Not much in system RAM, but good to know stuff.
			if ($line =~ /Error Correction Type: (.*)/)
			{
				$conf->{node}{$node}{hardware}{ram}{ecc_support} = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], RAM ECC: [$conf->{node}{$node}{hardware}{ram}{ecc_support}]\n");
			}
			if ($line =~ /Number Of Devices: (.*)/)
			{
				$conf->{node}{$node}{hardware}{ram}{slots}       = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], RAM slots: [$conf->{node}{$node}{hardware}{ram}{slots}]\n");
			}
			# This needs to be converted to bytes.
			if ($line =~ /Maximum Capacity: (\d+) (.*)$/)
			{
				my $size   = $1;
				my $suffix = $2;
				$conf->{node}{$node}{hardware}{ram}{max_support} = hr_to_bytes($conf, $size, $suffix, 1);
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], max. supported RAM: [$conf->{node}{$node}{hardware}{ram}{max_support}]\n");
			}
			if ($line =~ /Maximum Capacity: (.*)/)
			{
				$conf->{node}{$node}{hardware}{ram}{max_support} = $1;
				$conf->{node}{$node}{hardware}{ram}{max_support} = hr_to_bytes($conf, $conf->{node}{$node}{hardware}{ram}{max_support}, "", 1);
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], max. supported RAM: [$conf->{node}{$node}{hardware}{ram}{max_support}]\n");
			}
		}
		if ($in_dimm_module)
		{
			if ($line =~ /Locator: (.*)/)      { $dimm_locator     = $1; }
			if ($line =~ /Bank Locator: (.*)/) { $dimm_bank        = $1; }
			if ($line =~ /Type: (.*)/)         { $dimm_type        = $1; }
			if ($line =~ /Speed: (.*)/)        { $dimm_speed       = $1; }
			if ($line =~ /Form Factor: (.*)/)  { $dimm_form_factor = $1; }
			if ($line =~ /Size: (.*)/)
			{
				$dimm_size = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], DIMM Size: [$dimm_size]\n");
				# If the DIMM couldn't be read, it will
				# show "Unknown". I set this to 0 in 
				# that case.
				if ($dimm_size !~ /^\d/)
				{
					$dimm_size = 0;
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], DIMM Size: [$dimm_size]\n");
				}
				else
				{
					$dimm_size                                   =  hr_to_bytes($conf, $dimm_size, "", 1);
					$conf->{node}{$node}{hardware}{total_memory} += $dimm_size;
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], DIMM Size: [$dimm_size], total memory: [$conf->{node}{$node}{hardware}{total_memory}]\n");
				}
			}
		}
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], total cores: [$conf->{node}{$node}{hardware}{total_node_cores}], total threads: [$conf->{node}{$node}{hardware}{total_node_threads}], total memory: [$conf->{node}{$node}{hardware}{total_memory}]\n");
	#record($conf, "$THIS_FILE ".__LINE__."; Cluster; total cores: [$conf->{resources}{total_cores}], total threads: [$conf->{resources}{total_threads}], total memory: [$conf->{resources}{total_ram}]\n");
	return(0);
}

# Parse the memory information.
sub parse_meminfo
{
	my ($conf, $node, $array) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_meminfo() for node: [$node]\n");
	
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /MemTotal:\s+(.*)/)
		{
			$conf->{node}{$node}{hardware}{meminfo}{memtotal} = $1;
			$conf->{node}{$node}{hardware}{meminfo}{memtotal} = hr_to_bytes($conf, $conf->{node}{$node}{hardware}{meminfo}{memtotal}, "", 1);
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], meminfo total memory: [$conf->{node}{$node}{hardware}{meminfo}{memtotal}]\n");
		}
	}
	
	return(0);
}

# Parse the DRBD status.
sub parse_proc_drbd
{
	my ($conf, $node, $array) = @_;
	
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_proc_drbd() for node: [$node]\n");
	my $resource     = "";
	my $minor_number = "";
	foreach my $line (@{$array})
	{
		if ($line =~ /drbd offline/)
		{
			record($conf, "$THIS_FILE ".__LINE__."; DRBD does not appear to be running on node: [$node]\n");
			last;
		}
		#record($conf, "$THIS_FILE ".__LINE__."; >> line: [$line]\n");
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		if ($line =~ /version: (.*?) \(/)
		{
			$conf->{node}{$node}{drbd}{version} = $1;
			record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], DRBD version: [$conf->{node}{$node}{drbd}{version}]\n");
			next;
		}
		elsif ($line =~ /GIT-hash: (.*?) build by (.*?), (\S+) (.*)$/)
		{
			$conf->{node}{$node}{drbd}{git_hash}   = $1;
			$conf->{node}{$node}{drbd}{builder}    = $2;
			$conf->{node}{$node}{drbd}{build_date} = $3;
			$conf->{node}{$node}{drbd}{build_time} = $4;
			#record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], DRBD git hash: [$conf->{node}{$node}{drbd}{git_hash}], build by: [$conf->{node}{$node}{drbd}{builder}] on: [$conf->{node}{$node}{drbd}{build_date}] at: [$conf->{node}{$node}{drbd}{build_time}]\n");
		}
		else
		{
			# This is just for hash key consistency
			#record($conf, "$THIS_FILE ".__LINE__."; >> line: [$line]\n");
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
				   $resource         = $conf->{node}{$node}{drbd}{minor_number}{$minor_number}{resource};
				#record($conf, "$THIS_FILE ".__LINE__."; == node: [$node], resource: [$resource], minor: [$conf->{node}{$node}{drbd}{resource}{$resource}{minor_number}], connection state: [$conf->{node}{$node}{drbd}{resource}{$resource}{connection_state}]\n");
				   
				$conf->{node}{$node}{drbd}{resource}{$resource}{minor_number}     = $minor_number;
				$conf->{node}{$node}{drbd}{resource}{$resource}{connection_state} = $connection_state;
				$conf->{node}{$node}{drbd}{resource}{$resource}{my_role}          = $my_role;
				$conf->{node}{$node}{drbd}{resource}{$resource}{peer_role}        = $peer_role;
				$conf->{node}{$node}{drbd}{resource}{$resource}{my_disk_state}    = $my_disk_state;
				$conf->{node}{$node}{drbd}{resource}{$resource}{peer_disk_state}  = $peer_disk_state;
				$conf->{node}{$node}{drbd}{resource}{$resource}{drbd_protocol}    = $drbd_protocol;
				$conf->{node}{$node}{drbd}{resource}{$resource}{io_flags}         = $io_flags;
				#record($conf, "$THIS_FILE ".__LINE__."; == node: [$node], resource: [$resource], minor: [$conf->{node}{$node}{drbd}{resource}{$resource}{minor_number}], connection state: [$conf->{node}{$node}{drbd}{resource}{$resource}{connection_state}]\n");
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor: [$minor_number], cs: [$conf->{node}{$node}{drbd}{resource}{$resource}{connection_state}], my ro: [$conf->{node}{$node}{drbd}{resource}{$resource}{my_role}], peer ro: [$conf->{node}{$node}{drbd}{resource}{$resource}{peer_role}], my ds: [$conf->{node}{$node}{drbd}{resource}{$resource}{my_disk_state}], peer ds: [$conf->{node}{$node}{drbd}{resource}{$resource}{peer_disk_state}], protocol: [$conf->{node}{$node}{drbd}{resource}{$resource}{drbd_protocol}], io flags: [$conf->{node}{$node}{drbd}{resource}{$resource}{io_flags}]\n");
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
				if    ($write_order eq "b") { $write_order = "barrier"; }
				elsif ($write_order eq "f") { $write_order = "flush"; }
				elsif ($write_order eq "d") { $write_order = "drain"; }
				elsif ($write_order eq "n") { $write_order = "none"; }
				
				$conf->{node}{$node}{drbd}{resource}{$resource}{network_sent}            = hr_to_bytes($conf, $network_sent, "KiB", 1);
				$conf->{node}{$node}{drbd}{resource}{$resource}{network_received}        = hr_to_bytes($conf, $network_received, "KiB", 1);
				$conf->{node}{$node}{drbd}{resource}{$resource}{disk_write}              = hr_to_bytes($conf, $disk_write, "KiB", 1);
				$conf->{node}{$node}{drbd}{resource}{$resource}{disk_read}               = hr_to_bytes($conf, $disk_read, "KiB", 1);
				$conf->{node}{$node}{drbd}{resource}{$resource}{activity_log_updates}    = $activity_log_updates;
				$conf->{node}{$node}{drbd}{resource}{$resource}{bitmap_updates}          = $bitmap_updates;
				$conf->{node}{$node}{drbd}{resource}{$resource}{local_count}             = $local_count;
				$conf->{node}{$node}{drbd}{resource}{$resource}{pending_requests}        = $pending_requests;
				$conf->{node}{$node}{drbd}{resource}{$resource}{unacknowledged_requests} = $unacknowledged_requests;
				$conf->{node}{$node}{drbd}{resource}{$resource}{app_pending_requests}    = $app_pending_requests;
				$conf->{node}{$node}{drbd}{resource}{$resource}{epoch_objects}           = $epoch_objects;
				$conf->{node}{$node}{drbd}{resource}{$resource}{write_order}             = $write_order;
				$conf->{node}{$node}{drbd}{resource}{$resource}{out_of_sync}             = hr_to_bytes($conf, $out_of_sync, "KiB", 1);
				
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor: [$minor_number], network sent: [$conf->{node}{$node}{drbd}{resource}{$resource}{network_sent} bytes], network received: [$conf->{node}{$node}{drbd}{resource}{$resource}{network_received} bytes], disk write: [$conf->{node}{$node}{drbd}{resource}{$resource}{disk_write} bytes], disk read: [$conf->{node}{$node}{drbd}{resource}{$resource}{disk_read} bytes], activity log updates: [$conf->{node}{$node}{drbd}{resource}{$resource}{activity_log_updates}], bitmap updates: [$conf->{node}{$node}{drbd}{resource}{$resource}{bitmap_updates}], local count: [$conf->{node}{$node}{drbd}{resource}{$resource}{local_count}], pending requests: [$conf->{node}{$node}{drbd}{resource}{$resource}{pending_requests}], unacknowledged requests: [$conf->{node}{$node}{drbd}{resource}{$resource}{unacknowledged_requests}], application pending requests: [$conf->{node}{$node}{drbd}{resource}{$resource}{app_pending_requests}], epoch objects: [$conf->{node}{$node}{drbd}{resource}{$resource}{epoch_objects}], write order: [$conf->{node}{$node}{drbd}{resource}{$resource}{write_order}], out of sync: [$conf->{node}{$node}{drbd}{resource}{$resource}{out_of_sync} bytes]\n");
			}
			else
			{
				# The resync lines aren't consistent, so I pull out data one piece at a time.
				#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /sync'ed: (.*?)%/)
				{
					my $percent_synced = $1;
					$conf->{node}{$node}{drbd}{resource}{$resource}{syncing}        = 1;
					$conf->{node}{$node}{drbd}{resource}{$resource}{percent_synced} = $percent_synced;
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor: [$minor_number], percent synced: [$conf->{node}{$node}{drbd}{resource}{$resource}{percent_synced} %]\n");
				}
				if ($line =~ /\((\d+)\/(\d+)\)M/)
				{
					# The 'M' is 'Mibibyte'
					my $left_to_sync  = $1;
					my $total_to_sync = $2;
					
					$conf->{node}{$node}{drbd}{resource}{$resource}{left_to_sync}  = hr_to_bytes($conf, $left_to_sync, "MiB", 1);
					$conf->{node}{$node}{drbd}{resource}{$resource}{total_to_sync} = hr_to_bytes($conf, $total_to_sync, "MiB", 1);
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor: [$minor_number], left to sync: [$conf->{node}{$node}{drbd}{resource}{$resource}{left_to_sync} bytes], total to sync: [$conf->{node}{$node}{drbd}{resource}{$resource}{total_to_sync} bytes]\n");
				}
				if ($line =~ /finish: (\d+):(\d+):(\d+)/)
				{
					my $hours   = $1;
					my $minutes = $2;
					my $seconds = $3;
					$conf->{node}{$node}{drbd}{resource}{$resource}{eta_to_sync} = ($hours * 3600) + ($minutes * 60) + $seconds;
					
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor: [$minor_number], eta to sync: [$conf->{node}{$node}{drbd}{resource}{$resource}{eta_to_sync} seconds ($hours:$minutes:$seconds)]\n");
				}
				if ($line =~ /speed: (.*?) \((.*?)\)/)
				{
					my $current_speed =  $1;
					my $average_speed =  $2;
					   $current_speed =~ s/,//g;
					   $average_speed =~ s/,//g;
					$conf->{node}{$node}{drbd}{resource}{$resource}{current_speed} = hr_to_bytes($conf, $current_speed, "KiB", 1);
					$conf->{node}{$node}{drbd}{resource}{$resource}{average_speed} = hr_to_bytes($conf, $average_speed, "KiB", 1);
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor: [$minor_number], current_speed: [$conf->{node}{$node}{drbd}{resource}{$resource}{current_speed} bytes/sec], average_speed: [$conf->{node}{$node}{drbd}{resource}{$resource}{average_speed} bytes/sec]\n");
				}
				if ($line =~ /want: (.*?) K/)
				{
					# The 'want' line is only calculated on the sync target
					my $want_speed =  $1;
					   $want_speed =~ s/,//g;
					$conf->{node}{$node}{drbd}{resource}{$resource}{want_speed} = hr_to_bytes($conf, $want_speed, "KiB", 1);
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor: [$minor_number], want_speed: [$conf->{node}{$node}{drbd}{resource}{$resource}{want_speed} bytes]\n");
				}
			}
		}
	}
	
	foreach my $resource (sort {$a cmp $b} keys %{$conf->{node}{$node}{drbd}{resource}})
	{
		next if not $resource;
		#record($conf, "$THIS_FILE ".__LINE__."; -- node: [$node], resource: [$resource], minor: [$conf->{node}{$node}{drbd}{resource}{$resource}{minor_number}], connection state: [$conf->{node}{$node}{drbd}{resource}{$resource}{connection_state}]\n");
		
		$conf->{drbd}{$resource}{node}{$node}{minor}            = $conf->{node}{$node}{drbd}{resource}{$resource}{minor_number}     ? $conf->{node}{$node}{drbd}{resource}{$resource}{minor_number}     : "--";
		$conf->{drbd}{$resource}{node}{$node}{connection_state} = $conf->{node}{$node}{drbd}{resource}{$resource}{connection_state} ? $conf->{node}{$node}{drbd}{resource}{$resource}{connection_state} : "--";
		$conf->{drbd}{$resource}{node}{$node}{role}             = $conf->{node}{$node}{drbd}{resource}{$resource}{my_role}          ? $conf->{node}{$node}{drbd}{resource}{$resource}{my_role}          : "--";
		$conf->{drbd}{$resource}{node}{$node}{disk_state}       = $conf->{node}{$node}{drbd}{resource}{$resource}{my_disk_state}    ? $conf->{node}{$node}{drbd}{resource}{$resource}{my_disk_state}    : "--";
		$conf->{drbd}{$resource}{node}{$node}{device}           = $conf->{node}{$node}{drbd}{resource}{$resource}{drbd_device}      ? $conf->{node}{$node}{drbd}{resource}{$resource}{drbd_device}      : "--";
		$conf->{drbd}{$resource}{node}{$node}{resync_percent}   = $conf->{node}{$node}{drbd}{resource}{$resource}{percent_synced}   ? $conf->{node}{$node}{drbd}{resource}{$resource}{percent_synced}   : "--";
#		record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor: [$conf->{drbd}{$resource}{node}{$node}{minor}], connection state: [$conf->{drbd}{$resource}{node}{$node}{connection_state}], role: [$conf->{drbd}{$resource}{node}{$node}{role}], disk_state: [$conf->{drbd}{$resource}{node}{$node}{device}], device: [$conf->{drbd}{$resource}{node}{$node}{device}], resync percent: [$conf->{drbd}{$resource}{node}{$node}{resync_percent} %]\n");
	}
	
	return(0);
}

# Parse the DRBD status.
sub old_parse_drbd_status
{
	my ($conf, $node, $array) = @_;
	
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_drbd_status() for node: [$node]\n");
	my $resources = 0;
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if $line !~ /^<resource /;
		$resources++;
		
		# Make sure I only display "unknown" or the read value.
		my $minor = "--";
		my $res   = "--";
		my $cs    = "--";
		my $ro    = "--";
		my $ds    = "--";
		my $dev   = "--";
		my $sync  = "";
		($minor) = ($line =~ /minor="(.*?)"/);
		($res)   = ($line =~ /name="(.*?)"/);
		($cs)    = ($line =~ /cs="(.*?)"/);
		($ro)    = ($line =~ /ro1="(.*?)"/);
		($ds)    = ($line =~ /ds1="(.*?)"/);
		if ($line =~ /resynced_percent="(.*?)"/)
		{
			$sync = $1;
		}
		$dev = "/dev/drbd$minor" if $minor =~ /^\d+$/;
		
		# This is the new way of recording.
		$conf->{drbd}{$res}{node}{$node}{minor}            = $minor ? $minor : "--";
		$conf->{drbd}{$res}{node}{$node}{connection_state} = $cs    ? $cs    : "--";
		$conf->{drbd}{$res}{node}{$node}{role}             = $ro    ? $ro    : "--";
		$conf->{drbd}{$res}{node}{$node}{disk_state}       = $ds    ? $ds    : "--";
		$conf->{drbd}{$res}{node}{$node}{device}           = $dev   ? $dev   : "--";
		$conf->{drbd}{$res}{node}{$node}{resync_percent}   = $sync  ? $sync  : "--";
		
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], New - res: [$res], minor: [$conf->{drbd}{$res}{node}{$node}{minor}], cs: [$conf->{drbd}{$res}{node}{$node}{connection_state}], ro: [$conf->{drbd}{$res}{node}{$node}{role}], ds: [$conf->{drbd}{$res}{node}{$node}{disk_state}], dev: [$conf->{drbd}{$res}{node}{$node}{device}]\n");
	}
	if (not $resources)
	{
		# DRBD isn't running.
		#record($conf, "$THIS_FILE ".__LINE__."; DRBD does not appear to be running on node: [$node]\n");
	}
	
	return(0);
}

# This reads the DRBD resource details from the resource definition files.
sub parse_drbdadm_dumpxml
{
	my ($conf, $node, $array) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_drbdadm_dumpxml() for node: [$node], array: [$array]\n");
	
	# Some variables we will fill later.
	my $xml_data  = "";
	
	# Convert the XML array into a string.
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		$xml_data .= "$line\n";
	}
	
	# Now feed the string into XML::Simple.
	#record($conf, "$THIS_FILE ".__LINE__."; xml_data: ====\n$xml_data\n====\n");
	if ($xml_data)
	{
		my $xml  = XML::Simple->new();
		my $data = $xml->XMLin($xml_data, KeyAttr => {node => 'name'}, ForceArray => 1);
		#record($conf, "$THIS_FILE ".__LINE__."; data: [$data]\n");
		
		foreach my $a (keys %{$data})
		{
			#print "a: [$a]\n";
			if ($a eq "file")
			{
				# This is just "/dev/drbd.conf", not needed.
			}
			elsif ($a eq "common")
			{
				$conf->{node}{$node}{drbd}{protocol} = $data->{common}->[0]->{protocol};
				#print "Node: [$node], Common: [$data->{common}->[0]], Protocol: [$conf->{node}{$node}{drbd}{protocol}]\n";
				foreach my $b (@{$data->{common}->[0]->{section}})
				{
					my $name = $b->{name};
					#print "b: [$b], name: [$name]\n";
					if ($name eq "handlers")
					{
						$conf->{node}{$node}{drbd}{fence}{handler}{name} = $b->{option}->[0]->{name};
						$conf->{node}{$node}{drbd}{fence}{handler}{path} = $b->{option}->[0]->{value};
						#print "Node: [$node], Fence handler: [$conf->{node}{$node}{drbd}{fence}{handler}{name}], path: [$conf->{node}{$node}{drbd}{fence}{handler}{path}]\n";
					}
					elsif ($name eq "disk")
					{
						$conf->{node}{$node}{drbd}{fence}{policy} = $b->{option}->[0]->{value};
						#print "Node: [$node], Fence policy: [$conf->{node}{$node}{drbd}{fence}{policy}]\n";
					}
					elsif ($name eq "syncer")
					{
						$conf->{node}{$node}{drbd}{syncer}{rate} = $b->{option}->[0]->{value};
						#print "Node: [$node], Sync rate: [$conf->{node}{$node}{drbd}{syncer}{rate}]\n";
					}
					elsif ($name eq "startup")
					{
						foreach my $c (@{$b->{option}})
						{
							my $name  = $c->{name};
							my $value = $c->{value} ? $c->{value} : "--";
							$conf->{node}{$node}{drbd}{startup}{$name} = $value;
							#print "Node: [$node], Startup; name: [$name] -> [$conf->{node}{$node}{drbd}{startup}{$name}]\n";
						}
					}
					elsif ($name eq "net")
					{
						foreach my $c (@{$b->{option}})
						{
							my $name  = $c->{name};
							my $value = $c->{value} ? $c->{value} : "--";
							$conf->{node}{$node}{drbd}{startup}{$name} = $value;
							#print "Node: [$node], Network; name: [$name] -> [$conf->{node}{$node}{drbd}{startup}{$name}]\n";
						}
					}
					else
					{
						record($conf, "$THIS_FILE ".__LINE__."; Unexpected element: [$b] while parsing node: [$node]'s 'drbdadm dump-xml' data.\n");
					}
				}
			}
			elsif ($a eq "resource")
			{
				#print "node: [$node], resource; [$data->{resource}]\n";
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
							$backing_device = $c->{device}->[0]->{content};
						}
						else
						{
							### DRBD 8.4 data
							# TODO: This will have problems with multi-volume DRBD! Make it smarter.
							#print "DRBD 8.4\n";
							$metadisk       = $c->{volume}->[0]->{'meta-disk'}->[0];
							$minor_number   = $c->{volume}->[0]->{device}->[0]->{minor};
							$drbd_device    = $c->{volume}->[0]->{device}->[0]->{content};
							$backing_device = $c->{volume}->[0]->{device}->[0]->{content};
						}
						
						# This is used for locating a resource by it's minor number
						$conf->{node}{$node}{drbd}{minor_number}{$minor_number}{resource} = $resource;
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], minor_number: [$minor_number], resource: [$conf->{node}{$node}{drbd}{minor_number}{$minor_number}{resource}].\n");
						
						# This is where the data itself is stored.
						$conf->{node}{$node}{drbd}{resource}{$resource}{metadisk}       = $metadisk;
						$conf->{node}{$node}{drbd}{resource}{$resource}{minor_number}   = $minor_number;
						$conf->{node}{$node}{drbd}{resource}{$resource}{drbd_device}    = $drbd_device;
						$conf->{node}{$node}{drbd}{resource}{$resource}{backing_device} = $backing_device;
						
						# These entries are per-host.
						$conf->{node}{$node}{drbd}{resource}{$resource}{hostname}{$hostname}{ip_address} = $ip_address;
						$conf->{node}{$node}{drbd}{resource}{$resource}{hostname}{$hostname}{ip_type}    = $ip_type;
						$conf->{node}{$node}{drbd}{resource}{$resource}{hostname}{$hostname}{tcp_port}   = $tcp_port;
						
						# These are needed for the display.
						$conf->{node}{$node}{drbd}{res_file}{$resource}{device}           = $conf->{node}{$node}{drbd}{resource}{$resource}{drbd_device};
						$conf->{drbd}{$resource}{node}{$node}{res_file}{device}           = $conf->{node}{$node}{drbd}{resource}{$resource}{drbd_device};
						$conf->{drbd}{$resource}{node}{$node}{res_file}{connection_state} = "--";
						$conf->{drbd}{$resource}{node}{$node}{res_file}{role}             = "--";
						$conf->{drbd}{$resource}{node}{$node}{res_file}{disk_state}       = "--";

						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [$resource], minor number: [$minor_number], metadisk: [$conf->{node}{$node}{drbd}{resource}{$resource}{metadisk}], DRBD device: [$conf->{node}{$node}{drbd}{resource}{$resource}{drbd_device}], backing device: [$conf->{node}{$node}{drbd}{resource}{$resource}{backing_device}], hostname: [$hostname], IP: [$conf->{node}{$node}{drbd}{resource}{$resource}{hostname}{$hostname}{ip_address}:$conf->{node}{$node}{drbd}{resource}{$resource}{hostname}{$hostname}{tcp_port} ($conf->{node}{$node}{drbd}{resource}{$resource}{hostname}{$hostname}{ip_type})]\n");
					}
				}
			}
			else
			{
				record($conf, "$THIS_FILE ".__LINE__."; Unexpected element: [$a] while parsing node: [$node]'s 'drbdadm dump-xml' data.\n");
			}
		}
	}
	
	return(0);
}

# Parse the cluster status.
sub parse_clustat
{
	my ($conf, $node, $array) = @_;
	
	# Setup some variables.
	my $in_member  = 0;
	my $in_service = 0;
	my $line_num   = 0;
	
	# Default is 'unknown'
	my $host_name                         = AN::Common::get_string($conf, {key => "state_0001"});
	my $storage_name                      = AN::Common::get_string($conf, {key => "state_0001"});
	my $storage_state                     = AN::Common::get_string($conf, {key => "state_0001"});
	$conf->{node}{$node}{me}{cman}        = 0;
	$conf->{node}{$node}{me}{rgmanager}   = 0;
	$conf->{node}{$node}{peer}{cman}      = 0;
	$conf->{node}{$node}{peer}{rgmanager} = 0;
	$conf->{node}{$node}{enable_join}     = 0;
	$conf->{node}{$node}{get_host_from_cluster_conf} = 0;

	### NOTE: This check seems odd, but I've run intp cases where a node,
	###       otherwise behaving fine, simple returns nothing when cman is
	###       off. Couldn't reproduce on the command line.
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_clustat() for node: [$node]\n");
	my $line_count = @{$array};
	if (not $line_count)
	{
		# CMAN isn't running.
		record($conf, "$THIS_FILE ".__LINE__."; The cluster manager, cman, does not appear to be running on node: [$node] (nothing returned by the 'clustat' call).\n");
		$conf->{node}{$node}{get_host_from_cluster_conf} = 1;
		$conf->{node}{$node}{enable_join}                = 1;
	}
	#record($conf, "$THIS_FILE ".__LINE__."; Will parse: [$line_count] lines.\n");
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		if ($line =~ /Could not connect to CMAN/i)
		{
			# CMAN isn't running.
			#record($conf, "$THIS_FILE ".__LINE__."; CMAN does not appear to be running on node: [$node]\n");
			$conf->{node}{$node}{get_host_from_cluster_conf} = 1;
			$conf->{node}{$node}{enable_join}                = 1;
		}
		next if not $line;
		next if $line =~ /^-/;
		
		if ($line =~ /^Member Name/)
		{
			$in_member  = 1;
			$in_service = 0;
			next;
		}
		elsif ($line =~ /^Service Name/)
		{
			$in_member  = 0;
			$in_service = 1;
			next;
		}
		if ($in_member)
		{
			#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /Local/)
			{
				($conf->{node}{$node}{me}{name}, undef, my $services) = (split/ /, $line, 3);
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - me: [$conf->{node}{$node}{me}{name}], services: [$services]\n");
				$services =~ s/local//;
				$services =~ s/ //g;
				$services =~ s/,,/,/g;
				$conf->{node}{$node}{me}{cman}      =  1 if $services =~ /Online/;
				$conf->{node}{$node}{me}{rgmanager} =  1 if $services =~ /rgmanager/;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - Me   -> [$conf->{node}{$node}{me}{name}]; cman: [$conf->{node}{$node}{me}{cman}], rgmanager: [$conf->{node}{$node}{me}{rgmanager}]\n");
			}
			else
			{
				($conf->{node}{$node}{peer}{name}, undef, my $services) = split/ /, $line, 3;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - peer: [$conf->{node}{$node}{peer}{name}], services: [$services]\n");
				$services =~ s/ //g;
				$services =~ s/,,/,/g;
				$conf->{node}{peer}{cman}      = 1 if $services =~ /Online/;
				$conf->{node}{peer}{rgmanager} = 1 if $services =~ /rgmanager/;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - Peer -> [$conf->{node}{$node}{peer}{name}]; cman: [$conf->{node}{peer}{cman}], rgmanager: [$conf->{node}{peer}{rgmanager}]\n");
			}
		}
		elsif ($in_service)
		{
			if ($line =~ /^vm:/)
			{
				my ($vm, $host, $state) = split/ /, $line, 3;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], vm: [$vm], host: [$host], state: [$state]\n");
				if (($state eq "disabled") || ($state eq "stopped"))
				{
					# Set host to 'none'.
					$host = AN::Common::get_string($conf, {key => "state_0002"});
				}
				if ($state eq "failed")
				{
					# Disable the VM.
					my ($error, $ssh_fh, $output) = remote_call($conf, {
						node		=>	$node,
						port		=>	$conf->{node}{$node}{port},
						user		=>	"root",
						password	=>	$conf->{sys}{root_password},
						ssh_fh		=>	"",
						'close'		=>	1,
						shell_call	=>	"clusvcadm -d $vm",
					});
					record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
					foreach my $line (@{$output})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					}
				}
				
				# If the service is disabled, it will 
				# have '()' which I need to remove.
				$host =~ s/\(//g;
				$host =~ s/\)//g;
				
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], vm: [$vm], host: [$host]\n");
				$host = "none" if not $host;
				$conf->{vm}{$vm}{host}    = $host;
				$conf->{vm}{$vm}{'state'} = $state;
				# TODO: If the state is "failed", call 
				# 'virsh list --all' against both nodes. If the
				# VM is found, try to recover the service.
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], vm: [$vm], host: [$conf->{vm}{$vm}{host}], state: [$conf->{vm}{$vm}{'state'}]\n");
				
				# Pick out who the peer node is.
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], host: [$host], me: [$conf->{node}{$node}{me}{name}]\n");
				if ($host eq $conf->{node}{$node}{me}{name})
				{
					$conf->{vm}{$vm}{peer} = $conf->{node}{$node}{peer}{name};
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], vm: [$vm], peer: [$conf->{vm}{$vm}{peer}]\n");
				}
				else
				{
					$conf->{vm}{$vm}{peer} = $conf->{node}{$node}{me}{name};
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], vm: [$vm], peer: [$conf->{vm}{$vm}{peer}]\n");
				}
			}
			elsif ($line =~ /^service:(.*?)\s+(.*?)\s+(.*)$/)
			{
				my $name  = $1;
				my $host  = $2;
				my $state = $3;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - service name: [$name], host: [$host], state: [$state]\n");
				
				if ($state eq "failed")
				{
					# Disable the service and then call a
					# start against it.
					# Disable the VM.
					my ($error, $ssh_fh, $output) = remote_call($conf, {
						node		=>	$node,
						port		=>	$conf->{node}{$node}{port},
						user		=>	"root",
						password	=>	$conf->{sys}{root_password},
						ssh_fh		=>	"",
						'close'		=>	0,
						shell_call	=>	"clusvcadm -d service:$name",
					});
					record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
					foreach my $line (@{$output})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					}
					sleep 5;
					($error, $ssh_fh, $output) = remote_call($conf, {
						node		=>	$node,
						port		=>	$conf->{node}{$node}{port},
						user		=>	"root",
						password	=>	$conf->{sys}{root_password},
						ssh_fh		=>	$ssh_fh,
						'close'		=>	1,
						shell_call	=>	"clusvcadm -e service:$name",
					});
					record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
					foreach my $line (@{$output})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					}
				}
				
				# If the service is disabled, it will 
				# have '()' which I need to remove.
				$host =~ s/\(//g;
				$host =~ s/\)//g;
				
				$conf->{service}{$name}{host}    = $host;
				$conf->{service}{$name}{'state'} = $state;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - service name: [$name], host: [$conf->{service}{$name}{host}], state: [$conf->{service}{$name}{'state'}]\n");
			}
		}
	}
	
	# If this is set, the cluster isn't running.
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], get host from cluster.conf: [$conf->{node}{$node}{get_host_from_cluster_conf}]\n");
	if (not $conf->{node}{$node}{get_host_from_cluster_conf})
	{
		$host_name = $conf->{node}{$node}{me}{name};
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], host name: [$host_name]\n");
		foreach my $name (sort {$a cmp $b} keys %{$conf->{service}})
		{
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - service name: [$name]\n");
			next if $conf->{service}{$name}{host} ne $host_name;
			next if $name !~ /storage/;
			$storage_name  = $name;
			$storage_state = $conf->{service}{$name}{'state'};
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - storage name: [$storage_name], storage state: [$storage_state]\n");
		}
		
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], host name: [$host_name]\n");
		if ($host_name)
		{
			$conf->{node}{$node}{info}{host_name}            =  $host_name;
			$conf->{node}{$node}{info}{short_host_name}      =  $host_name;
			$conf->{node}{$node}{info}{short_host_name}      =~ s/\..*$//;
			$conf->{node}{$node}{get_host_from_cluster_conf} = 0;
		}
		else
		{
			$conf->{node}{$node}{get_host_from_cluster_conf} = 1;
		}
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], get host from cluster.conf: [$conf->{node}{$node}{get_host_from_cluster_conf}]\n");
		$conf->{node}{$node}{info}{storage_name}    = $storage_name;
		$conf->{node}{$node}{info}{storage_state}   = $storage_state;
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node] - host name: [$conf->{node}{$node}{info}{host_name}], short host name: [$conf->{node}{$node}{info}{short_host_name}], storage name: [$conf->{node}{$node}{info}{storage_name}], storage state: [$conf->{node}{$node}{info}{storage_state}]\n");
	}
	
	return(0);
}

# Parse the cluster configuration.
sub parse_cluster_conf
{
	my ($conf, $node, $array) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; in parse_cluster_conf(); node: [$node]\n");
	
	my $in_fod          = 0;
	my $current_fod     = "";
	my $in_node         = "";
	my $in_fence        = 0;
	my $in_method       = "";
	my $device_count    = 0;
	my $in_fence_device = 0;
	my $this_host_name  = "";
	my $this_node       = "";
	my $method_counter  = 0;
	
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
		
		# Find failover domains.
		if ($line =~ /<failoverdomain /)
		{
			$current_fod = ($line =~ /name="(.*?)"/)[0];
			#record($conf, "$THIS_FILE ".__LINE__."; current_fod: [$current_fod]\n");
			$in_fod      = 1;
			next;
		}
		if ($line =~ /<\/failoverdomain>/)
		{
			$current_fod = "";
			$in_fod      = 0;
			next;
		}
		if ($in_fod)
		{
			next if $line !~ /failoverdomainnode/;
			my $node     = ($line =~ /name="(.*?)"/)[0];
			my $priority = ($line =~ /priority="(.*?)"/)[0] ? $1 : 0;
			$conf->{failoverdomain}{$current_fod}{priority}{$priority}{node} = $node;
			#record($conf, "$THIS_FILE ".__LINE__."; failover domain: [$current_fod], node: [$conf->{failoverdomain}{$current_fod}{priority}{$priority}{node}], priority: [$priority]\n");
		}
		
		# If I didn't get the hostname from clustat, try to find it here.
		if ($line =~ /<clusternode.*?name="(.*?)"/)
		{
			   $this_host_name  =  $1;
			my $short_host_name =  $this_host_name;
			   $short_host_name =~ s/\..*$//;
			my $short_node_name =  $node;
			   $short_node_name =~ s/\..*$//;
			   
			# If I need to record the host name from cluster.conf,
			# do so here.
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], short host name: [$short_host_name], short node name: [$short_node_name], get host from cluster.conf: [$conf->{node}{$node}{get_host_from_cluster_conf}]\n");
			if ($short_host_name eq $short_node_name)
			{
				# Found it.
				if ($conf->{node}{$node}{get_host_from_cluster_conf})
				{
					$conf->{node}{$node}{info}{host_name}            = $this_host_name;
					$conf->{node}{$node}{info}{short_host_name}      = $short_host_name;
					$conf->{node}{$node}{get_host_from_cluster_conf} = 0;
				}
				$this_node = $node;
			}
			else
			{
				$this_node = AN::Striker::get_peer_node($conf, $node);
				if (not $conf->{node}{$this_node}{host_name})
				{
					$conf->{node}{$this_node}{info}{host_name}       = $this_host_name;
					$conf->{node}{$this_node}{info}{short_host_name} = $short_host_name;
				}
			}
			
			# Mark that I am in a node child element.
			$in_node = $node;
		}
		if ($line =~ /<\/clusternode>/)
		{
			# Record my fence findings.
			$in_node        = "";
			$this_node      = "";
			$method_counter = 0;
		}
		
		if (($in_node) && ($line =~ /<fence>/))
		{
			$in_fence = 1;
		}
		if ($line =~ /<\/fence>/)
		{
			$in_fence = 0;
		}
		if (($in_fence) && ($line =~ /<method.*name="(.*?)"/))
		{
			# The method counter ensures ordered use of the fence
			# devices.
			$in_method = "$method_counter:$1";
			$method_counter++;
		}
		if ($line =~ /<\/method>/)
		{
			$in_method    = "";
			$device_count = 0;
		}
		if (($in_method) && ($line =~ /<device\s/))
		{
			my $name            = $line =~ /name="(.*?)"/          ? $1 : "";
			my $port            = $line =~ /port="(.*?)"/          ? $1 : "";
			my $action          = $line =~ /action="(.*?)"/        ? $1 : "";
			my $address         = $line =~ /ipaddr="(.*?)"/        ? $1 : "";
			my $login           = $line =~ /login="(.*?)"/         ? $1 : "";
			my $password        = $line =~ /passwd="(.*?)"/        ? $1 : "";
			my $password_script = $line =~ /passwd_script="(.*?)"/ ? $1 : "";
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name}            = $name;
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port}            = $port;
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action}          = $action;
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{address}         = $address;
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{login}           = $login;
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password}        = $password;
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password_script} = $password_script;
			record($conf, "$THIS_FILE ".__LINE__."; node: [$this_node], method: [$in_method], method count: [$device_count], name: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name}], port: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port}], action: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action}], address: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{address}], login: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{login}], password: [".length($conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password})." characters long], password_script: [$password_script]\n");
			$device_count++;
		}
		
		# Parse out the fence device details.
		if ($line =~ /<fencedevices>/)
		{
			$in_fence_device = 1;
		}
		if ($line =~ /<\/fencedevices>/)
		{
			$in_fence_device = 0;
		}
		# This could be duplicated, but I don't care as cluster.conf
		# has to be the same on both nodes, anyway.
		if ($in_fence_device)
		{
			my $name            = $line =~ /name="(.*?)"/          ? $1 : "";
			my $agent           = $line =~ /agent="(.*?)"/         ? $1 : "";
			my $action          = $line =~ /action="(.*?)"/        ? $1 : "";
			my $address         = $line =~ /ipaddr="(.*?)"/        ? $1 : "";
			my $login           = $line =~ /login="(.*?)"/         ? $1 : "";
			my $password        = $line =~ /passwd="(.*?)"/        ? $1 : "";
			my $password_script = $line =~ /passwd_script="(.*?)"/ ? $1 : "";
			# If the password has a single-quote, ricci changes it to &apos;. We need to change it back.
			$password =~ s/&apos;/'/g;
			$conf->{fence}{$name}{agent}           = $agent;
			$conf->{fence}{$name}{action}          = $action;
			$conf->{fence}{$name}{address}         = $address;
			$conf->{fence}{$name}{login}           = $login;
			$conf->{fence}{$name}{password}        = $password;
			$conf->{fence}{$name}{password_script} = $password_script;
			record($conf, "$THIS_FILE ".__LINE__."; node: [$node], fence name: [$name], agent: [$conf->{fence}{$name}{agent}], address: [$conf->{fence}{$name}{address}], login: [$conf->{fence}{$name}{login}], password: [$conf->{fence}{$name}{password}], action: [$conf->{fence}{$name}{action}], password_script: [$conf->{fence}{$name}{password_script}]\n");
		}
		
		# Find VMs.
		if ($line =~ /<vm.*?name="(.*?)"/)
		{
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
			my $vm     = $1;
			my $vm_key = "vm:$vm";
			my $def    = ($line =~ /path="(.*?)"/)[0].$vm.".xml";
			my $domain = ($line =~ /domain="(.*?)"/)[0];
			# I need to set the host to 'none' to avoid triggering
			# the error caused by seeing and foo.xml VM def outside
			# of here.
			#record($conf, "$THIS_FILE ".__LINE__."; vm_key: [$vm_key], def: [$def], domain: [$domain]\n");
			$conf->{vm}{$vm_key}{definition_file} = $def;
			$conf->{vm}{$vm_key}{failover_domain} = $domain;
			$conf->{vm}{$vm_key}{host}            = "none" if not $conf->{vm}{$vm_key}{host};
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], vm_key: [$vm_key], definition: [$conf->{vm}{$vm_key}{definition_file}], host: [$conf->{vm}{$vm_key}{host}]\n");
		}
	}
	
	# See if I got the fence details for both nodes.
	my $peer = AN::Striker::get_peer_node($conf, $node);
	record($conf, "$THIS_FILE ".__LINE__."; node: [$node], peer: [$peer]\n");
	foreach my $this_node ($node, $peer)
	{
		# This will contain possible fence methods.
		$conf->{node}{$this_node}{info}{fence_methods} = "";
		
		# This will contain the command needed to check the node's
		# power.
		$conf->{node}{$this_node}{info}{power_check_command} = "";
		
		record($conf, "$THIS_FILE ".__LINE__."; this node: [$this_node]\n");
		foreach my $in_method (sort {$a cmp $b} keys %{$conf->{node}{$this_node}{fence}{method}})
		{
			record($conf, "$THIS_FILE ".__LINE__."; this node: [$this_node], method: [$in_method]\n");
			my $fence_command = "$in_method: ";
			foreach my $device_count (sort {$a cmp $b} keys %{$conf->{node}{$this_node}{fence}{method}{$in_method}{device}})
			{
				#$fence_command .= " [$device_count]";
				record($conf, "$THIS_FILE ".__LINE__."; this node: [$this_node], method: [$in_method], method count: [$device_count], name: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name}], port: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port}], action: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action}]\n");
				#Find the matching fence device entry.
				foreach my $name (sort {$a cmp $b} keys %{$conf->{fence}})
				{
					if ($name eq $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name})
					{
						my $agent           = $conf->{fence}{$name}{agent};
						my $address         = $conf->{fence}{$name}{address};
						my $login           = $conf->{fence}{$name}{login};
						my $password        = $conf->{fence}{$name}{password};
						my $password_script = $conf->{fence}{$name}{password_script};
						my $port            = $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port};
						
						# See if we need to use values from the per-node definitions.
						# These override the general fence device configs if needed.
						if ($conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{address})
						{
							$address = $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{address};
						}
						if ($conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{login})
						{
							$login = $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{login};
						}
						if ($conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password})
						{
							$password = $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password};
						}
						if ($conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password_script})
						{
							$password_script = $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password_script};
						}
						
						# If we have a password script but no password, we
						# need to call the script and record the output 
						# because we probably don't have the script on the
						# dashboard.
						if (($password_script) && (not $password))
						{
							# Convert the script to a password.
							my $shell_call = $password_script;
							record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
							my ($error, $ssh_fh, $output) = remote_call($conf, {
								node		=>	$node,
								port		=>	$conf->{node}{$node}{port},
								user		=>	"root",
								password	=>	$conf->{sys}{root_password},
								ssh_fh		=>	"",
								'close'		=>	0,
								shell_call	=>	$shell_call,
							});
							record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
							foreach my $line (@{$output})
							{
								$password = $line;
								record($conf, "$THIS_FILE ".__LINE__."; password: [$password]\n");
								last;
							}
						}
						
						#my $action   = $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action};
						#   $action   = "reboot" if not $action;
						my $command  = "$agent -a $address ";
						   $command .= "-l $login "           if $login;
						   $command .= "-p \"$password\" "    if $password;		# quote the password in case it has spaces in it.
						   $command .= "-n $port "            if $port;
						   $command =~ s/ $//;
						$conf->{node}{$this_node}{fence_method}{$in_method}{device}{$device_count}{command} = $command;
						record($conf, "$THIS_FILE ".__LINE__."; node: [$this_node], fence command: [$conf->{node}{$this_node}{fence_method}{$in_method}{device}{$device_count}{command}]\n");
						if (($agent eq "fence_ipmilan") || ($agent eq "fence_virsh"))
						{
							$conf->{node}{$this_node}{info}{power_check_command} = $command;
							record($conf, "$THIS_FILE ".__LINE__."; node: [$this_node]: power check command: [$conf->{node}{$this_node}{info}{power_check_command}]\n");
						}
						$fence_command .= "$command -o #!action!#; ";
					}
				}
			}
			# Record the fence command.
			$fence_command =~ s/ $/. /;
			if ($node eq $this_node)
			{
				$conf->{node}{$node}{info}{fence_methods} .= "$fence_command";
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$this_node]: fence command: $conf->{node}{$node}{info}{fence_methods}\n");
			}
			else
			{
				$conf->{node}{$peer}{info}{fence_methods} .= "$fence_command";
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$this_node]: peer: [$peer], fence command: $conf->{node}{$peer}{info}{fence_methods}\n");
			}
		}
		$conf->{node}{$this_node}{info}{fence_methods} =~ s/\s+$//;
	}
	### NOTE: These expose passwords!
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], fence command: [$conf->{node}{$node}{info}{fence_methods}]\n");
	#record($conf, "$THIS_FILE ".__LINE__."; peer: [$peer], fence command: [$conf->{node}{$peer}{info}{fence_methods}]\n");
	
	return(0);
}

# Parse the daemon statuses.
sub parse_daemons
{
	my ($conf, $node, $array) = @_;
	
	# If all daemons are down, record here that I can shut down
	# this VM. If any are up, enable withdrawl.
	$conf->{node}{$node}{enable_poweroff} = 0;
	$conf->{node}{$node}{enable_withdraw} = 0;
	
	# I need to pre-set the services as stopped because the little
	# hack I have below doesn't echo when a service isn't running.
	#record($conf, "$THIS_FILE ".__LINE__."; setting daemon states to 'Stopped'.\n");
	set_daemons($conf, $node, "Stopped", "highlight_bad");
	
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_daemons() for node: [$node]\n");
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if $line !~ /^striker:/;
		my ($daemon, $exit_code) = ($line =~ /^.*?:(.*?):(.*?)$/);
		$exit_code = "" if not defined $exit_code;
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], exit_code: [$exit_code]\n");
		if ($exit_code eq "0")
		{
			$conf->{node}{$node}{daemon}{$daemon}{status} = "<span class=\"highlight_good\">#!string!state_0003!#</span>";
			$conf->{node}{$node}{enable_poweroff}         = 0;
		}
		$conf->{node}{$node}{daemon}{$daemon}{exit_code} = defined $exit_code ? $exit_code : "";
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], exit code: [$conf->{node}{$node}{daemon}{$daemon}{exit_code}], status: [$conf->{node}{$node}{daemon}{$daemon}{status}]\n");
	}
	
	# If cman is running, enable withdrawl. If not, enable shut down.
	my $cman_exit      = $conf->{node}{$node}{daemon}{cman}{exit_code};
	my $rgmanager_exit = $conf->{node}{$node}{daemon}{rgmanager}{exit_code};
	my $drbd_exit      = $conf->{node}{$node}{daemon}{drbd}{exit_code};
	my $clvmd_exit     = $conf->{node}{$node}{daemon}{clvmd}{exit_code};
	my $gfs2_exit      = $conf->{node}{$node}{daemon}{gfs2}{exit_code};
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], cman_exit:      [$cman_exit]\n");
	if ($cman_exit eq "0")
	{
		$conf->{node}{$node}{enable_withdraw} = 1;
	}
	else
	{
		# If something went wrong, one of the storage resources might still be running.
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], rgmanager_exit: [$rgmanager_exit]\n");
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], drbd_exit:      [$drbd_exit]\n");
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], clvmd_exit:     [$clvmd_exit]\n");
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], gfs2_exit:      [$gfs2_exit]\n");
		if (($rgmanager_exit eq "0") ||
		    ($drbd_exit eq "0") ||
		    ($clvmd_exit eq "0") ||
		    ($gfs2_exit eq "0"))
		{
			# This can happen if the user loads the page (or it
			# auto-loads) while the storage is coming online.
			#my $message = AN::Common::get_string($conf, {key => "message_0044", variables => {
			#	node	=>	$node,
			#}});
			#error($conf, $message); 
		}
		else
		{
			# Ready to power off the node, if I was actually able
			# to connect to the node.
			if ($conf->{node}{$node}{connected})
			{
				$conf->{node}{$node}{enable_poweroff} = 1;
			}
		}
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], enable poweroff: [$conf->{node}{$node}{enable_poweroff}], enable withdrawl: [$conf->{node}{$node}{enable_withdraw}]\n");
	#foreach my $daemon (@daemons) { record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], status: [$conf->{node}{$node}{daemon}{$daemon}{status}], exit_code: [$conf->{node}{$node}{daemon}{$daemon}{exit_code}]\n"); }
	
	return(0);
}

# Parse the LVM scan output.
sub parse_lvm_scan
{
	my ($conf, $node, $array) = @_;
	
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_lvm_scan() for node: [$node]\n");
	foreach my $line (@{$array})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /(.*?)\s+'(.*?)'\s+\[(.*?)\]/)
		{
			my $state     = $1;
			my $lv        = $2;
			my $size      = $3;
			my $bytes     = hr_to_bytes($conf, $size);
			my $vg        = ($lv =~ /^\/dev\/(.*?)\//)[0];
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], state: [$state], vg: [$vg], lv: [$lv], size: [$size], bytes: [$bytes]\n");
			
			if (lc($state) eq "inactive")
			{
				# The variables here pass onto 'message_0045'.
				print AN::Common::template($conf, "main-page.html", "lv-inactive-error", {}, {
					lv	=>	$lv,
					node	=>	$node,
				}); 
			}
			
			if (exists $conf->{resources}{lv}{$lv})
			{
				if (($conf->{resources}{lv}{$lv}{on_vg} ne $vg) || ($conf->{resources}{lv}{$lv}{size} ne $bytes))
				{
					my $error = AN::Common::get_string($conf, {key => "message_0046", variables => {
						lv	=>	$lv,
						size	=>	$conf->{resources}{lv}{$lv}{size},
						'bytes'	=>	$bytes,
						vg_1	=>	$conf->{resources}{lv}{$lv}{on_vg},
						vg_2	=>	$vg,
					}});
					error($conf, $error, 1);
				}
				
			}
			else
			{
				$conf->{resources}{lv}{$lv}{on_vg} = $vg;
				$conf->{resources}{lv}{$lv}{size}  = $bytes;
				#record($conf, "$THIS_FILE ".__LINE__."; lv: [$lv], vg: [$conf->{resources}{lv}{$lv}{on_vg}], size: [$conf->{resources}{lv}{$lv}{size}]\n");
			}
		}
	}
	
	return(0);
}

# Parse the LVM data.
sub parse_lvm_data
{
	my ($conf, $node, $array) = @_;
	
	my $in_pvs = 0;
	my $in_vgs = 0;
	my $in_lvs = 0;
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_lvm_data() for node: [$node]\n");
	foreach my $line (@{$array})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line], in_pvs: [$in_pvs], in_vgs: [$in_vgs], in_lvs: [$in_lvs]\n");
		if ($line =~ /^PV/)
		{
			$in_pvs = 1;
			$in_vgs = 0;
			$in_lvs = 0;
			next;
		}
		if ($line =~ /^VG/)
		{
			$in_pvs = 0;
			$in_vgs = 1;
			$in_lvs = 0;
			next;
		}
		if ($line =~ /^LV/)
		{
			$in_pvs = 0;
			$in_vgs = 0;
			$in_lvs = 1;
			next;
		}
		
		if ($in_pvs)
		{
			# pvs --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid
			#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			#   pv_name,  vg_name,     pv_fmt,  pv_attr,     pv_size,     pv_free,   pv_used,     pv_uuid
			my ($this_pv, $used_by_vg, $format, $attributes, $total_size, $free_size, $used_size, $uuid) = (split /#!#/, $line);
			$total_size =~ s/B$//;
			$free_size  =~ s/B$//;
			$used_size  =~ s/B$//;
			#record($conf, "$THIS_FILE ".__LINE__."; PV: [$this_pv], used by VG: [$used_by_vg], format: [$format], attributes: [$attributes], total size: [$total_size], free size: [$free_size], used size: [$used_size], uuid: [$uuid]\n");
			$conf->{node}{$node}{lvm}{pv}{$this_pv}{used_by_vg} = $used_by_vg;
			$conf->{node}{$node}{lvm}{pv}{$this_pv}{attributes} = $attributes;
			$conf->{node}{$node}{lvm}{pv}{$this_pv}{total_size} = $total_size;
			$conf->{node}{$node}{lvm}{pv}{$this_pv}{free_size}  = $free_size;
			$conf->{node}{$node}{lvm}{pv}{$this_pv}{used_size}  = $used_size;
			$conf->{node}{$node}{lvm}{pv}{$this_pv}{uuid}       = $uuid;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], PV: [$this_pv], used by VG: [$conf->{node}{$node}{lvm}{pv}{$this_pv}{used_by_vg}], attributes: [$conf->{node}{$node}{lvm}{pv}{$this_pv}{attributes}], total size: [$conf->{node}{$node}{lvm}{pv}{$this_pv}{total_size}], free size: [$conf->{node}{$node}{lvm}{pv}{$this_pv}{free_size}], used size: [$conf->{node}{$node}{lvm}{pv}{$this_pv}{used_size}], uuid: [$conf->{node}{$node}{lvm}{pv}{$this_pv}{uuid}]\n");
		}
		elsif ($in_vgs)
		{
			# vgs --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name
			#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			#   vg_name,  vg_attr,     vg_extent_size, vg_extent_count, vg_uuid, vg_size,  vg_free_count, vg_free,  pv_name
			my ($this_vg, $attributes, $pe_size,       $total_pe,       $uuid,   $vg_size, $free_pe,      $vg_free, $pv_name) = split /#!#/, $line;
			$pe_size    = "" if not defined $pe_size;
			$vg_size    = "" if not defined $vg_size;
			$vg_free    = "" if not defined $vg_free;
			$attributes = "" if not defined $attributes;
			$pe_size =~ s/B$//;
			$vg_size =~ s/B$//;
			$vg_free =~ s/B$//;
			my $used_pe    = $total_pe - $free_pe if (($total_pe) && ($free_pe));
			my $used_space = $vg_size - $vg_free  if (($vg_size) && ($vg_free));
			#record($conf, "$THIS_FILE ".__LINE__."; VG: [$this_vg], attributes: [$attributes], PE size: [$pe_size], total PE: [$total_pe], uuid: [$uuid], VG size: [$vg_size], used PE: [$used_pe], used space: [$used_space], free PE: [$free_pe], free space: [$vg_free], VG free: [$vg_free], pv_name: [$pv_name]\n");
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{clustered}  = $attributes =~ /c$/ ? 1 : 0;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{pe_size}    = $pe_size;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{total_pe}   = $total_pe;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{uuid}       = $uuid;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{size}       = $vg_size;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{used_pe}    = $used_pe;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{used_space} = $used_space;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{free_pe}    = $free_pe;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{free_space} = $vg_free;
			$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{pv_name}    = $pv_name;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], VG: [$this_vg], clustered: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{clustered}], pe size: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{pe_size}], total pe: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{total_pe}], uuid: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{uuid}], size: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{size}], used pe: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{used_pe}], used space: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{used_space}], free pe: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{free_pe}], free space: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{free_space}], PV name: [$conf->{node}{$node}{hardware}{lvm}{vg}{$this_vg}{pv_name}]\n");
		}
		elsif ($in_lvs)
		{
			# lvs --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices
			#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			my ($lv_name, $on_vg, $attributes, $total_size, $uuid, $path, $devices) = (split /#!#/, $line);
			#record($conf, "$THIS_FILE ".__LINE__."; LV name: [$lv_name], on VG: [$on_vg], attributes: [$attributes], total size: [$total_size], uuid: [$uuid], path: [$path], device(s): [$devices]\n");
			$total_size =~ s/B$//;
			$devices    =~ s/\(\d+\)//g;	# Strip the starting PE number
			$conf->{node}{$node}{lvm}{lv}{$path}{name}       = $lv_name;
			$conf->{node}{$node}{lvm}{lv}{$path}{on_vg}      = $on_vg;
			$conf->{node}{$node}{lvm}{lv}{$path}{active}     = ($attributes =~ /.{4}(.{1})/)[0] eq "a" ? 1 : 0;
			$conf->{node}{$node}{lvm}{lv}{$path}{attributes} = $attributes;
			$conf->{node}{$node}{lvm}{lv}{$path}{total_size} = $total_size;
			$conf->{node}{$node}{lvm}{lv}{$path}{uuid}       = $uuid;
			$conf->{node}{$node}{lvm}{lv}{$path}{on_devices} = $devices;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], path: [$path], name: [$conf->{node}{$node}{lvm}{lv}{$path}{name}], on VG: [$conf->{node}{$node}{lvm}{lv}{$path}{on_vg}], active: [$conf->{node}{$node}{lvm}{lv}{$path}{active}], attribute: [$conf->{node}{$node}{lvm}{lv}{$path}{attributes}], total size: [$conf->{node}{$node}{lvm}{lv}{$path}{total_size}], uuid: [$conf->{node}{$node}{lvm}{lv}{$path}{uuid}], on device(s): [$conf->{node}{$node}{lvm}{lv}{$path}{on_devices}]\n");
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], path: [$path], name: [$conf->{node}{$node}{lvm}{lv}{$path}{name}], on VG: [$conf->{node}{$node}{lvm}{lv}{$path}{on_vg}], total size: [$conf->{node}{$node}{lvm}{lv}{$path}{total_size}], on device(s): [$conf->{node}{$node}{lvm}{lv}{$path}{on_devices}]\n");
		}
	}
	
	return(0);
}

# Parse the virsh data.
sub parse_virsh
{
	my ($conf, $node, $array) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_virsh(), node: [$node], array: [$array (".@{$array}." lines)]\n");
	
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if $line !~ /^\d/;
		
		my ($id, $say_vm, $state) = split/ /, $line, 3;
		#record($conf, "$THIS_FILE ".__LINE__."; id: [$id], saw vm: [$say_vm], state: [$state]\n");
		
		my $vm = "vm:$say_vm";
		$conf->{vm}{$vm}{node}{$node}{virsh}{'state'} = $state;
		#record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::node::${node}::virsh::state: [$conf->{vm}{$vm}{node}{$node}{virsh}{'state'}]\n");
		
		if ($state eq "paused")
		{
			# This VM is being migrated here, disable withdrawl of
			# this node and migration of this VM.
			$conf->{node}{$node}{enable_withdraw} = 0;
			$conf->{vm}{$vm}{can_migrate}         = 0;
			$conf->{node}{$node}{enable_poweroff} = 0;
		}
	}
	
	return(0);
}

# Parse the GFS2 data.
sub parse_gfs2
{
	my ($conf, $node, $array) = @_;
	
	my $in_fs = 0;
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_gfs2() for node: [$node]\n");
	foreach my $line (@{$array})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /Filesystem/)
		{
			$in_fs = 1;
			next;
		}
		
		if ($in_fs)
		{
			next if $line !~ /^\//;
			my ($device_path, $total_size, $used_space, $free_space, $percent_used, $mount_point) = ($line =~ /^(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)$/);
			next if not $mount_point;
			$total_size   = "" if not defined $total_size;
			$used_space   = "" if not defined $used_space;
			$free_space   = "" if not defined $free_space;
			$percent_used = "" if not defined $percent_used;
			next if not exists $conf->{node}{$node}{gfs}{$mount_point};
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], device path: [$device_path], total size: [$total_size], used space: [$used_space], free space: [$free_space], percent used: [$percent_used], mount point: [$mount_point]\n");
			$conf->{node}{$node}{gfs}{$mount_point}{device_path}  = $device_path;
			$conf->{node}{$node}{gfs}{$mount_point}{total_size}   = $total_size;
			$conf->{node}{$node}{gfs}{$mount_point}{used_space}   = $used_space;
			$conf->{node}{$node}{gfs}{$mount_point}{free_space}   = $free_space;
			$conf->{node}{$node}{gfs}{$mount_point}{percent_used} = $percent_used;
			$conf->{node}{$node}{gfs}{$mount_point}{mounted}      = 1;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], mount point: [$mount_point], device path: [$conf->{node}{$node}{gfs}{$mount_point}{device_path}], total size: [$conf->{node}{$node}{gfs}{$mount_point}{total_size}], used space: [$conf->{node}{$node}{gfs}{$mount_point}{used_space}], free space: [$conf->{node}{$node}{gfs}{$mount_point}{free_space}], percent used: [$conf->{node}{$node}{gfs}{$mount_point}{percent_used}], mounted: [$conf->{node}{$node}{gfs}{$mount_point}{mounted}]\n");
		}
		else
		{
			# Read the GFS info.
			next if $line !~ /gfs2/;
			my (undef, $mount_point, $fs) = ($line =~ /^(.*?)\s+(.*?)\s+(.*?)\s/);
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], mount point: [$mount_point], fs: [$fs]\n");
			$conf->{node}{$node}{gfs}{$mount_point}{device_path}  = "--";
			$conf->{node}{$node}{gfs}{$mount_point}{total_size}   = "--";
			$conf->{node}{$node}{gfs}{$mount_point}{used_space}   = "--";
			$conf->{node}{$node}{gfs}{$mount_point}{free_space}   = "--";
			$conf->{node}{$node}{gfs}{$mount_point}{percent_used} = "--";
			$conf->{node}{$node}{gfs}{$mount_point}{mounted}      = 0;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], mount point: [$mount_point], device path: [$conf->{node}{$node}{gfs}{$mount_point}{device_path}], total size: [$conf->{node}{$node}{gfs}{$mount_point}{total_size}], used space: [$conf->{node}{$node}{gfs}{$mount_point}{used_space}], free space: [$conf->{node}{$node}{gfs}{$mount_point}{free_space}], percent used: [$conf->{node}{$node}{gfs}{$mount_point}{percent_used}], mounted: [$conf->{node}{$node}{gfs}{$mount_point}{mounted}]\n");
		}
	}
	
	return(0);
}

# This sets all of the daemons to a given state.
sub set_daemons
{
	my ($conf, $node, $state, $class) = @_;
	
	my @daemons = ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd");
	foreach my $daemon (@daemons)
	{
		$conf->{node}{$node}{daemon}{$daemon}{status}    = "<span class=\"$class\">$state</span>";
		$conf->{node}{$node}{daemon}{$daemon}{exit_code} = "";
	}
	return(0);
}

# This checks to see if the node's power is on, when possible.
sub check_if_on
{
	my ($conf, $node) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; in check_if_on(); node: [$node]\n");
	
	# If the peer is on, use it to check the power.
	my $peer                    = "";
	$conf->{node}{$node}{is_on} = 9;
	#record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{sys}{up_nodes}]\n");
	### TODO: This fails when node 1 is down because it has not yet looked
	###       for node 2 to see if it is on or not. Check manually.
	if ($conf->{sys}{up_nodes} == 1)
	{
		# It has to be the peer of this node.
		$peer = @{$conf->{up_nodes}}[0];
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], peer: [$peer]\n");
	if ($peer)
	{
		# Check the power state using the peer node.
		if (not $conf->{node}{$node}{info}{power_check_command})
		{
			my $error = AN::Common::get_string($conf, {key => "message_0047", variables => {
				node	=>	$node,
				peer	=>	$peer,
			}});
			error($conf, $error);
		}
		else
		{
			### NOTE: Not needed with the new SSH method.
			# Escape out password double-quotes.
			#$conf->{node}{$node}{info}{power_check_command} =~ s/-p \"(.*?)\"/-p \\\"$1\\\"/g;
			#record($conf, "$THIS_FILE ".__LINE__."; node::${node}::info::power_check_command: [$conf->{node}{$node}{info}{power_check_command}]\n");
		}
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], power check command: [$conf->{node}{$node}{info}{power_check_command}]\n");
		record($conf, "$THIS_FILE ".__LINE__."; node: [$node], calling: [$conf->{node}{$node}{info}{power_check_command} -o status]\n");
		my ($error, $ssh_fh, $output) = remote_call($conf, {
			node		=>	$peer,
			port		=>	$conf->{node}{$peer}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			channel		=>	"",
			'close'		=>	0,
			shell_call	=>	"$conf->{node}{$node}{info}{power_check_command} -o status",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
			if ($line =~ / On$/i)
			{
				$conf->{node}{$node}{is_on} = 1;
				record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
			}
			if ($line =~ / Off$/i)
			{
				$conf->{node}{$node}{is_on} = 0;
				record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
			}
		}
	}
	else
	{
		# Read the cache and check the power directly, if possible.
		read_node_cache($conf, $node);
		$conf->{node}{$node}{info}{power_check_command} = "" if not defined $conf->{node}{$node}{info}{power_check_command};
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], power check command: [$conf->{node}{$node}{info}{power_check_command}]\n");
		if ($conf->{node}{$node}{info}{power_check_command})
		{
			# Get the address from the command and see if it's in
			# one of my subnet.
			my ($target_host)              = ($conf->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
			my ($local_access, $target_ip) = on_same_network($conf, $target_host, $node);
			
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], local_access: [$local_access]\n");
			if ($local_access)
			{
				# I can reach it directly
				my $shell_call = "$conf->{node}{$node}{info}{power_check_command} -o status";
				record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
				open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
				while(<$file_handle>)
				{
					chomp;
					my $line = $_;
					record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
					if ($line =~ / On$/i)
					{
						$conf->{node}{$node}{is_on} = 1;
						record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
					}
					if ($line =~ / Off$/i)
					{
						$conf->{node}{$node}{is_on} = 0;
						record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
					}
					if ($line =~ / Unknown$/i)
					{
						$conf->{node}{$node}{is_on} = 2;
						record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}] - Failed to get info from IPMI!\n");
					}
				}
				close $file_handle;
			}
			else
			{
				# I can't reach it from here.
				#record($conf, "$THIS_FILE ".__LINE__."; This machine is not on the same network out of band management interface: [$target_host] for node: [$node], unable to check power state.\n");
				$conf->{node}{$node}{is_on} = 3;
			}
		}
		else
		{
			# No power-check command
			$conf->{node}{$node}{is_on} = 4;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}] - Unable to find power check command!\n");
		}
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
	if ($conf->{node}{$node}{is_on} == 0)
	{
		# I need to preset the services as stopped because the little
		# hack I have below doesn't echo when a service isn't running.
		$conf->{node}{$node}{enable_poweron} = 1;
		record($conf, "$THIS_FILE ".__LINE__."; setting daemon states to 'Offline'.\n");
		my $say_offline = AN::Common::get_string($conf, {key => "state_0004"});
		set_daemons($conf, $node, $say_offline, "highlight_unavailable");
	}
	
	return(0);
}

# This takes a host name (or IP) and sees if it's reachable from the machine
# running this program.
sub on_same_network
{
	my ($conf, $target_host, $node) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; in on_same_network(); target host: [$target_host], node: [$node]\n");
	
	my $local_access = 0;
	my $target_ip;
	
	my $shell_call = "$conf->{path}{gethostip} -d $target_host";
	#record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^(\d+\.\d+\.\d+\.\d+)$/)
		{
			$target_ip = $1;
			#record($conf, "$THIS_FILE ".__LINE__."; target_ip: [$target_ip]\n");
		}
		elsif ($line =~ /Unknown host/i)
		{
			# Failed to resolve directly, see if the target host
			# was read from the cache file.
			read_node_cache($conf, $node);
			#record($conf, "$THIS_FILE ".__LINE__."; node::${node}::hosts::${target_host}::ip: [$conf->{node}{$node}{hosts}{$target_host}{ip}]\n");
			if ((defined $conf->{node}{$node}{hosts}{$target_host}{ip}) && ($conf->{node}{$node}{hosts}{$target_host}{ip} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/))
			{
				$target_ip = $conf->{node}{$node}{hosts}{$target_host}{ip};
				#record($conf, "$THIS_FILE ".__LINE__."; target_ip: [$target_ip], node::${node}::hosts::${target_host}::ip: [$conf->{node}{$node}{hosts}{$target_host}{ip}]\n");
				
				# Convert the power check command's address to
				# use the raw IP.
				#record($conf, "$THIS_FILE ".__LINE__."; > node::${node}::info::power_check_command: [$conf->{node}{$node}{info}{power_check_command}]\n");
				$conf->{node}{$node}{info}{power_check_command} =~ s/-a (.*?) /-a $target_ip /;
				#record($conf, "$THIS_FILE ".__LINE__."; < node::${node}::info::power_check_command: [$conf->{node}{$node}{info}{power_check_command}]\n");
			}
			else
			{
				my $error = AN::Common::get_string($conf, {key => "message_0048", variables => {
					target_host	=>	$target_host,
				}});
				error($conf, $error);
			}
		}
		elsif ($line =~ /Usage: gethostip/i)
		{
			#No hostname parsed out.
			my $error = AN::Common::get_string($conf, {key => "message_0049"});
			error($conf, $error);
		}
	}
	close $file_handle;
	
	#record($conf, "$THIS_FILE ".__LINE__."; target_ip: [$target_ip]\n");
	if ($target_ip)
	{
		# Find out my own IP(s) and subnet(s).
		my $in_dev     = "";
		my $this_ip    = "";
		my $this_nm    = "";
		my $shell_call = "$conf->{path}{ifconfig}";
		#record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			if ($line =~ /^(.*?)\s+Link encap/)
			{
				$in_dev = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; in_dev: [$in_dev]\n");
				next;
			}
			elsif ($line =~ /^(.*?): flags/)
			{
				$in_dev = $1;
				#record($conf, "$THIS_FILE ".__LINE__."; in_dev: [$in_dev]\n");
				next;
			}
			if (not $line)
			{
				# See if this network gives me access 
				# to the power check device.
				my $target_ip_range = $target_ip;
				my $this_ip_range   = $this_ip;
				#record($conf, "$THIS_FILE ".__LINE__."; target_ip_range: [$target_ip_range], this_ip: [$this_ip]\n");
				if ($this_nm eq "255.255.255.0")
				{
					# Match the first three octals.
					$target_ip_range =~ s/.\d+$//;
					$this_ip_range   =~ s/.\d+$//;
					#record($conf, "$THIS_FILE ".__LINE__."; target_ip_range: [$target_ip_range], this_ip_range: [$this_ip_range]\n");
				}
				if ($this_nm eq "255.255.0.0")
				{
					# Match the first three octals.
					$target_ip_range =~ s/.\d+.\d+$//;
					$this_ip_range   =~ s/.\d+.\d+$//;
					#record($conf, "$THIS_FILE ".__LINE__."; target_ip_range: [$target_ip_range], this_ip_range: [$this_ip_range]\n");
				}
				if ($this_nm eq "255.0.0.0")
				{
					# Match the first three octals.
					$target_ip_range =~ s/.\d+.\d+.\d+$//;
					$this_ip_range   =~ s/.\d+.\d+.\d+$//;
					#record($conf, "$THIS_FILE ".__LINE__."; target_ip_range: [$target_ip_range], this_ip_range: [$this_ip_range]\n");
				}
				#record($conf, "$THIS_FILE ".__LINE__."; target_ip_range: [$target_ip_range], this_ip_range: [$this_ip_range]\n");
				if ($this_ip_range eq $target_ip_range)
				{
					# Match! I can reach it directly.
					$local_access = 1;
					#record($conf, "$THIS_FILE ".__LINE__."; local_access: [$local_access]\n");
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
					#record($conf, "$THIS_FILE ".__LINE__."; this_ip: [$this_ip]\n");
				}
				elsif ($line =~ /inet (\d+\.\d+\.\d+\.\d+) /)
				{
					$this_ip = $1;
					#record($conf, "$THIS_FILE ".__LINE__."; this_ip: [$this_ip]\n");
				}
				
				if ($line =~ /Mask:(\d+\.\d+\.\d+\.\d+)/i)
				{
					$this_nm = $1;
					#record($conf, "$THIS_FILE ".__LINE__."; this_nm: [$this_nm]\n");
				}
				elsif ($line =~ /netmask (\d+\.\d+\.\d+\.\d+) /)
				{
					$this_nm = $1;
					#record($conf, "$THIS_FILE ".__LINE__."; this_nm: [$this_nm]\n");
				}
			}
		}
		close $file_handle;
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; local_access: [$local_access]\n");
	return($local_access, $target_ip);
}

# This records this scan's data to the cache file.
sub write_node_cache
{
	my ($conf, $node) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; in write_node_cache(); node: [$node]\n");
	
	# It's a program error to try and write the cache file when the node
	# is down.
	my @lines;
	my $cluster    = $conf->{cgi}{cluster};
	my $cache_file = "$conf->{path}{'striker_cache'}/cache_".$cluster."_".$node.".striker";
	#record($conf, "$THIS_FILE ".__LINE__."; node::${node}::info::host_name: [$conf->{node}{$node}{info}{host_name}], node::${node}::info::power_check_command: [$conf->{node}{$node}{info}{power_check_command}]\n");
	if (($conf->{node}{$node}{info}{host_name}) && ($conf->{node}{$node}{info}{power_check_command}))
	{
		# Write the command to disk so that I can check the power state
		# in the future when both nodes are offline.
		record($conf, "$THIS_FILE ".__LINE__."; node: [$node], power check command: [$conf->{node}{$node}{info}{power_check_command}]\n");
		push @lines, "host_name = $conf->{node}{$node}{info}{host_name}\n";
		push @lines, "power_check_command = $conf->{node}{$node}{info}{power_check_command}\n";
		push @lines, "fence_methods = $conf->{node}{$node}{info}{fence_methods}\n";
	}
	
	my $print_header = 0;
	foreach my $this_host (sort {$a cmp $b} keys %{$conf->{node}{$node}{hosts}})
	{
		next if not $this_host;
		next if not $conf->{node}{$node}{hosts}{$this_host}{ip};
		if (not $print_header)
		{
			push @lines, "#! start hosts !#\n";
			$print_header = 1;
		}
		push @lines, "$conf->{node}{$node}{hosts}{$this_host}{ip}\t$this_host\n";
	}
	if ($print_header)
	{
		push @lines, "#! end hosts !#\n";
	}
	
	if (@lines > 0)
	{
		record($conf, "$THIS_FILE ".__LINE__."; writing: [$cache_file]\n");
		my $shell_call = "$cache_file";
		open (my $file_handle, ">", "$shell_call") or error($conf, AN::Common::get_string($conf, {key => "message_0050", variables => {
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
	my ($conf, $node) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; in read_node_cache(); node: [$node]\n");
	
	# Write the command to disk so that I can check the power state
	# in the future when both nodes are offline.
	my $cluster    = $conf->{cgi}{cluster};
	my $cache_file = "$conf->{path}{'striker_cache'}/cache_".$cluster."_".$node.".striker";
	record($conf, "$THIS_FILE ".__LINE__."; cluster: [$cluster], cache file: [$cache_file]\n");
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
			$cache_file = "$conf->{path}{'striker_cache'}/cache_".$cluster."_".$node.".remote.striker";
		}
	}
	if (-e $cache_file)
	{
		# It exists! Read it.
		my $in_hosts   = 0;
		my $shell_call = $cache_file;
		record($conf, "$THIS_FILE ".__LINE__."; Reading: [$shell_call]\n");
		open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$line =~ s/\s+/ /g;
			#record($conf, "$THIS_FILE ".__LINE__."; in_hosts: [$in_hosts], line: [$line]\n");
			
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
				$conf->{node}{$node}{hosts}{$this_host}{ip} = $this_ip;
				#record($conf, "$THIS_FILE ".__LINE__."; node::${node}::hosts::${this_host}::ip: [$conf->{node}{$node}{hosts}{$this_host}{ip}]\n");
			}
			else
			{
				next if $line !~ /=/;
				my ($var, $val) = (split/=/, $line, 2);
				$var =~ s/^\s+//;
				$var =~ s/\s+$//;
				$val =~ s/^\s+//;
				$val =~ s/\s+$//;
				
				#record($conf, "$THIS_FILE ".__LINE__."; var: [$var], val: [$val]\n");
				$conf->{node}{$node}{info}{$var} = $val;
				#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], var: [$var] -> [$conf->{node}{$node}{info}{$var}]\n");
			}
		}
		close $file_handle;
		$conf->{clusters}{$cluster}{cache_exists} = 1;
	}
	else
	{
		$conf->{clusters}{$cluster}{cache_exists} = 0;
		$conf->{node}{$node}{info}{host_name}     = $node;
	}
	record($conf, "$THIS_FILE ".__LINE__."; host name: [$conf->{node}{$node}{info}{host_name}], power check command: [$conf->{node}{$node}{info}{power_check_command}]\n");
	
	return(0);
}

1;
