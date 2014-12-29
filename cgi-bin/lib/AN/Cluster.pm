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
our $VERSION  = "1.2.0 β";

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
	my $fh = IO::Handle->new();
	open ($fh, "$shell_call 2>&1 |") or AN::Common::hard_die($conf, $THIS_FILE, __LINE__, 14, "Failed to call the setuid root C-wrapper: [$shell_call]. The error was: $!\n");
	binmode $fh, ":utf8:";
	while (<$fh>)
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
	$fh->close();
	
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
	my $save       = 1;
	
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
				$conf->{hosts}{by_ip}{$this_nodes_1_ip} = "";
			}
			$conf->{hosts}{by_ip}{$this_nodes_1_ip} .= "$this_nodes_1_name ";
		}
		record($conf, "$THIS_FILE ".__LINE__."; this_nodes_2_name: [$this_nodes_2_name], this_nodes_2_ip: [$this_nodes_2_ip]\n");
		if (($this_nodes_2_name) && ($this_nodes_2_ip))
		{
			$conf->{hosts}{$this_nodes_2_name}{ip} = $this_nodes_2_ip;
			if (not exists $conf->{hosts}{by_ip}{$this_nodes_2_ip})
			{
				$conf->{hosts}{by_ip}{$this_nodes_2_ip} = "";
			}
			$conf->{hosts}{by_ip}{$this_nodes_2_ip} .= "$this_nodes_2_name ";
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
					$conf->{hosts}{by_ip}{$this_ip} =~ s/$nodes_1_name //;
					$conf->{hosts}{by_ip}{$this_ip} =~ s/$nodes_2_name //;
					if (not $conf->{hosts}{by_ip}{$this_ip})
					{
						delete $conf->{hosts}{by_ip}{$this_ip};
					}
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
	record($conf, "$THIS_FILE ".__LINE__."; cgi::$smtp__username_key: [$conf->{cgi}{$smtp__username_key}]\n");
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
	record($conf, "$THIS_FILE ".__LINE__."; cgi::$mail_data__to_key: [$conf->{cgi}{$mail_data__to_key}]\n");
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
	record($conf, "$THIS_FILE ".__LINE__."; cgi::$smtp__port_key: [$conf->{cgi}{$smtp__port_key}], cgi::$smtp__server_key: [$conf->{cgi}{$smtp__server_key}]\n");
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
			$conf->{hosts}{$this_nodes_1_name}{ip}  =  $this_nodes_1_ip;
			$conf->{hosts}{$this_nodes_2_name}{ip}  =  $this_nodes_2_ip;
			$conf->{hosts}{by_ip}{$this_nodes_1_ip} .= "$this_nodes_1_name ";
			$conf->{hosts}{by_ip}{$this_nodes_2_ip} .= "$this_nodes_2_name ";
			
			# Search in 'hosts' and 'ssh_config' for previous
			# entries with these names and delete them if found.
			foreach my $this_ip (sort {$a cmp $b} keys %{$conf->{hosts}{by_ip}})
			{
				my $say_node_1 = $conf->{cgi}{$nodes_1_name_key};
				my $say_node_2 = $conf->{cgi}{$nodes_2_name_key};
				if ($this_ip ne $this_nodes_1_ip)
				{
					$conf->{hosts}{by_ip}{$this_ip} =~ s/\s$say_node_1\s//;
					$conf->{hosts}{by_ip}{$this_ip} =~ s/\s$say_node_1$//;
					$conf->{hosts}{by_ip}{$this_ip} =~ s/^$say_node_1$//;
					$conf->{hosts}{by_ip}{$this_ip} =~ s/^$say_node_1\s//;
				}
				if ($this_ip ne $this_nodes_2_ip)
				{
					$conf->{hosts}{by_ip}{$this_ip} =~ s/\s$say_node_2\s//;
					$conf->{hosts}{by_ip}{$this_ip} =~ s/\s$say_node_2$//;
					$conf->{hosts}{by_ip}{$this_ip} =~ s/^$say_node_2$//;
					$conf->{hosts}{by_ip}{$this_ip} =~ s/^$say_node_2\s//;
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

	return ($save);
}

# This writes out the new striker.conf file.
sub write_new_striker_conf
{
	my ($conf, $say_date) = @_;
	
	# Tell the user where ready to go.
	print AN::Common::template($conf, "config.html", "general-row-good", {
		row	=>	"#!string!row_0018!#",
		message	=>	"#!string!message_0015!#",
	}); 
	
	# Start writing the config file.
	my $striker_conf = IO::Handle->new();
	open ($striker_conf, ">$conf->{path}{striker_conf}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{striker_conf}], error: $!\n";
	my $say_date_header = AN::Common::get_string($conf, {key => "text_0003", variables => {
		date	=>	$say_date,
	}});
	my $say_text = AN::Common::get_string($conf, {key => "text_0001"});
	print $striker_conf "$say_date_header\n";
	print $striker_conf "$say_text\n";

	# If saving the global values, check for a couple substitutions.
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
	print $striker_conf $say_body;
	
	# Now print the individual Anvil!s 
	foreach my $this_id (sort {$a cmp $b} keys %{$conf->{cluster}})
	{
		next if not $this_id;
		next if not $conf->{cluster}{$this_id}{name};
		
		# Main Anvil! values, always recorded, even when blank.
		print $striker_conf "\n# $conf->{cluster}{$this_id}{company} - $conf->{cluster}{$this_id}{description}\n";
		print $striker_conf "cluster::${this_id}::company\t\t\t=\t$conf->{cluster}{$this_id}{company}\n";
		print $striker_conf "cluster::${this_id}::description\t\t\t=\t$conf->{cluster}{$this_id}{description}\n";
		print $striker_conf "cluster::${this_id}::name\t\t\t=\t$conf->{cluster}{$this_id}{name}\n";
		print $striker_conf "cluster::${this_id}::nodes\t\t\t=\t$conf->{cluster}{$this_id}{nodes}\n";
		print $striker_conf "cluster::${this_id}::ricci_pw\t\t\t=\t$conf->{cluster}{$this_id}{ricci_pw}\n";
		print $striker_conf "cluster::${this_id}::root_pw\t\t\t=\t$conf->{cluster}{$this_id}{root_pw}\n";
		print $striker_conf "cluster::${this_id}::url\t\t\t\t=\t$conf->{cluster}{$this_id}{url}\n";
		
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
		print $striker_conf "cluster::${this_id}::smtp::server\t\t=\t$conf->{cluster}{$this_id}{smtp}{server}\n";
		print $striker_conf "cluster::${this_id}::smtp::port\t\t\t=\t$conf->{cluster}{$this_id}{smtp}{port}\n";
		print $striker_conf "cluster::${this_id}::smtp::username\t\t=\t$conf->{cluster}{$this_id}{smtp}{username}\n";
		print $striker_conf "cluster::${this_id}::smtp::password\t\t=\t$conf->{cluster}{$this_id}{smtp}{password}\n";
		print $striker_conf "cluster::${this_id}::smtp::security\t\t=\t$conf->{cluster}{$this_id}{smtp}{security}\n";
		print $striker_conf "cluster::${this_id}::smtp::encrypt_pass\t\t=\t$conf->{cluster}{$this_id}{smtp}{encrypt_pass}\n";
		print $striker_conf "cluster::${this_id}::smtp::helo_domain\t\t=\t$conf->{cluster}{$this_id}{smtp}{helo_domain}\n";
		print $striker_conf "cluster::${this_id}::mail_data::to\t\t=\t$conf->{cluster}{$this_id}{mail_data}{to}\n";
		print $striker_conf "cluster::${this_id}::mail_data::sending_domain\t=\t$conf->{cluster}{$this_id}{mail_data}{sending_domain}\n";
	}
	print $striker_conf "\n";
	$striker_conf->close();
	
	return(0);
}

# This reads in /etc/hosts and later will try to match host names to IPs
sub read_hosts
{
	my ($conf) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; read_hosts()\n");
	
	$conf->{raw}{hosts} = [];
	my $fh = IO::Handle->new();
	my $sc = "$conf->{path}{hosts}";
	open ($fh, "<$sc") or die "$THIS_FILE ".__LINE__."; Failed to read: [$sc], error was: $!\n";
	while (<$fh>)
	{
		chomp;
		my $line = $_;
		push @{$conf->{raw}{hosts}}, $line;
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
				$conf->{hosts}{$this_host}{ip} = $this_ip;
				if (not exists $conf->{hosts}{by_ip}{$this_ip})
				{
					$conf->{hosts}{by_ip}{$this_ip} = "";
				}
				$conf->{hosts}{by_ip}{$this_ip} .= "$this_host ";
				#record($conf, "$THIS_FILE ".__LINE__."; this_host: [$this_host] -> this_ip: [$conf->{hosts}{$this_host}{ip}] ($conf->{hosts}{by_ip}{$this_ip})\n");
			}
		}
	}
	$fh->close();
	
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
	my $fh = IO::Handle->new();
	my $sc = "$conf->{path}{ssh_config}";
	#record($conf, "$THIS_FILE ".__LINE__."; reading: [$sc]\n");
	open ($fh, "<$sc") or die "$THIS_FILE ".__LINE__."; Failed to read: [$sc], error was: $!\n";
	while (<$fh>)
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
	$fh->close();
	
	return(0);
}

# This copies a file from one place to another.
sub copy_file
{
	my ($conf, $source, $destination) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; copy_file(); source: [$source], destination: [$destination]\n");
	
	my $output = "";
	my $sc     = "$conf->{path}{cp} -f $source $destination; $conf->{path}{sync}";
	#record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc]\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		$output .= "$line\n";
		record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
	}
	$fh->close();
	
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
	
	my $ssh_config = IO::Handle->new();
	open ($ssh_config, ">$conf->{path}{ssh_config}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{ssh_config}], error: $!\n";
	#record($conf, "$THIS_FILE ".__LINE__."; << ssh_config line: [### Last updated: [$say_date]]\n");
	my $say_date_header = AN::Common::get_string($conf, {key => "text_0003", variables => {
		date	=>	$say_date,
	}});
	print $ssh_config "$say_date_header\n";
	
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
		print $ssh_config "$line\n";
	}
	
	# Print the header box that separates the main config from our 'Host ...' entries.
	my $say_host_header = AN::Common::get_string($conf, {key => "text_0004"});
	print $ssh_config "\n$say_host_header\n\n";
	
	# Now add any new entries.
	foreach my $this_host (sort {$a cmp $b} keys %{$conf->{hosts}})
	{
		#record($conf, "$THIS_FILE ".__LINE__."; this_host: [$this_host], port: [$conf->{hosts}{$this_host}{port}]\n");
		next if not $conf->{hosts}{$this_host}{port};
		print $ssh_config "Host $this_host\n";
		print $ssh_config "\tPort $conf->{hosts}{$this_host}{port}\n\n";
		#record($conf, "$THIS_FILE ".__LINE__."; << ssh_config line: [Host $this_host]\n");
		#record($conf, "$THIS_FILE ".__LINE__."; << ssh_config line: [\tPort $conf->{hosts}{$this_host}{port}]\n");
	}
	$ssh_config->close();

	return(0);
}

# Write out the new 'hosts' file. This is simple and doesn't preserve comments
# or formatting. It will preserve non-node related IPs.
sub write_new_hosts
{
	my ($conf, $say_date) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; write_new_hosts(); say_date: [$say_date]\n");
	
	# Open the file
	my $hosts_file = IO::Handle->new();
	open ($hosts_file, ">$conf->{path}{hosts}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{hosts}], error: $!\n";
	my $say_date_header = AN::Common::get_string($conf, {key => "text_0003", variables => {
		date	=>	$say_date,
	}});
	my $say_host_header = AN::Common::get_string($conf, {key => "text_0005"});
	print $hosts_file "$say_date_header\n";
	print $hosts_file "$say_host_header\n";

	# Cycle through the passed variables and add them to the hashed created
	# when the hosts file was last read.
	record($conf, "$THIS_FILE ".__LINE__."; cgi::ids: [$conf->{cgi}{ids}]\n");
	foreach my $this_ip (sort {$a cmp $b} keys %{$conf->{hosts}{by_ip}})
	{
		# A host can be one or more, separated by spaces.
		record($conf, "$THIS_FILE ".__LINE__."; this_ip: [$this_ip], hosts::by_ip::$this_ip: [$conf->{hosts}{by_ip}{$this_ip}]\n");
		my $hosts =  $conf->{hosts}{by_ip}{$this_ip};
		   $hosts =~ s/\s+$//;
		   $hosts =~ s/\s+/ /g;
		next if not $hosts;
		record($conf, "$THIS_FILE ".__LINE__."; hosts: [$hosts]\n");
		
		# Search for duplicates
		my $say_hosts = "";
		if ($hosts =~ / /)
		{
			my $last_host = "";
			record($conf, "$THIS_FILE ".__LINE__."; spliting hosts: [$say_hosts]\n");
			foreach my $this_host (sort {$a cmp $b} split/ /, $hosts)
			{
				record($conf, "$THIS_FILE ".__LINE__."; this_host: [$this_host]\n");
				next if not $this_host;
				record($conf, "$THIS_FILE ".__LINE__."; last_host: [$last_host]\n");
				next if $this_host eq $last_host;
				$last_host = $this_host;
				$say_hosts .= " $this_host ";
				record($conf, "$THIS_FILE ".__LINE__."; say_hosts: [$say_hosts]\n");
			}
			$say_hosts =~ s/\s+$//;
			record($conf, "$THIS_FILE ".__LINE__."; = say_hosts: [$say_hosts]\n");
		}
		else
		{
			$say_hosts = $hosts;
			record($conf, "$THIS_FILE ".__LINE__."; = say_hosts: [$say_hosts]\n");
		}
		record($conf, "$THIS_FILE ".__LINE__."; this_ip: [$this_ip], say_hosts: [$say_hosts]\n");
		print $hosts_file "$this_ip\t$say_hosts\n";
	}
	$hosts_file->close();
	
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
		#die "$THIS_FILE ".__LINE__."; Testing...\n";
		# Get the current date and time.
		my ($say_date) =  get_date($conf, time);
		my $date       =  $say_date;
		$date          =~ s/ /_/;
		$say_date      =~ s/ /, /;
		
		# Write out the new config file.
		copy_file($conf, $conf->{path}{striker_conf}, "$conf->{path}{home}/archive/striker.conf.$date");
		write_new_striker_conf($conf, $say_date);
		
		# Write out the 'hosts' file.
		copy_file($conf, $conf->{path}{hosts}, "$conf->{path}{home}/archive/hosts.$date");
		write_new_hosts($conf, $say_date);
		
		# Write out the 'ssh_config' file.
		copy_file($conf, $conf->{path}{ssh_config}, "$conf->{path}{home}/archive/ssh_config.$date");
		write_new_ssh_config($conf, $say_date);
		
		print AN::Common::template($conf, "config.html", "general-row-good", {
			row	=>	"#!string!row_0019!#",
			message	=>	"#!string!message_0017!#",
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
		#record($conf, "$THIS_FILE ".__LINE__."; cgi::$smtp__server_key: [$conf->{cgi}{$smtp__server_key}], cgi::$smtp__port_key: [$conf->{cgi}{$smtp__port_key}], cgi::$smtp__username_key: [$conf->{cgi}{$smtp__username_key}], cgi::$smtp__password_key: [$conf->{cgi}{$smtp__password_key}], cgi::$smtp__security_key: [$conf->{cgi}{$smtp__security_key}], cgi::$smtp__encrypt_pass_key: [$conf->{cgi}{$smtp__encrypt_pass_key}], cgi::$smtp__helo_domain_key: [$conf->{cgi}{$smtp__helo_domain_key}], cgi::$mail_data__to_key: [$conf->{cgi}{$mail_data__to_key}], cgi::$mail_data__sending_domain_key: [$conf->{cgi}{$mail_data__sending_domain_key}]\n");
	}
	
	# Show the right header.
	if ($this_cluster eq "new")
	{
		# New Anvil!
		$say_this_cluster = "";
		$clear_icon       = "";
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
	if ($conf->{cgi}{anvil})
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
		print "
";
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
	$conf->{cgi}{cluster}            = $conf->{cgi}{anvil};
	$conf->{'system'}{root_password} = $conf->{clusters}{$anvil}{root_pw};
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
		my $config_file = $conf->{path}{striker_conf};
		if (not -r $config_file)
		{
			die "Failed to read local: [$config_file]\n";
		}
		
		# We're going to want to backup each file before pushing the updates.
		my ($say_date) =  get_date($conf, time);
		my $date       =  $say_date;
		$date          =~ s/ /_/;
		$say_date      =~ s/ /, /;
		
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
			my $sc = "if [ ! -e '/etc/an' ]; then mkdir /etc/an; fi; ls /etc/an";
			record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
			my ($error, $ssh_fh, $output) = remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{'system'}{root_password},
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$sc,
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
			$error  = "";
			$output = "";
			$sc     = "";
			
			# Backup, but don't care if it fails.
			my $backup_file = "$config_file.$date";
			$sc = "if [ -e \"$config_file\" ]; then cp $config_file $backup_file; fi; ls $backup_file";
			record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
			($error, $ssh_fh, $output) = remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{'system'}{root_password},
				ssh_fh		=>	$ssh_fh,
				'close'		=>	1,
				shell_call	=>	$sc,
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
			$sc = "$conf->{path}{rsync} $conf->{args}{rsync} $config_file root\@$node:$config_file";
			# This is a dumb way to check, try a test upload and see if it fails.
			if ( -e "/usr/bin/expect" )
			{
				record($conf, "$THIS_FILE ".__LINE__."; Creating 'expect' rsync wrapper.");
				AN::Common::create_rsync_wrapper($conf, $node);
				$sc = "~/rsync.$node $conf->{args}{rsync} $config_file root\@$node:$config_file";
			}
			record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
			my $fh = IO::Handle->new();
			open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
			my $no_key = 0;
			while(<$fh>)
			{
				chomp;
				my $line = $_;
				print AN::Common::template($conf, "common.html", "shell-call-output", {
					line	=>	$line,
				});
			}
			$fh->close;
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
	
	# Read the three config files and write them out to a file.
	foreach my $file ($conf->{path}{striker_conf}, $conf->{path}{hosts}, $conf->{path}{ssh_config})
	{
		# Read in /etc/striker/striker.conf.
		record($conf, "$THIS_FILE ".__LINE__."; reading: [$file]\n");
		$config_data .= "<!-- start $file -->\n";
		my $fh = IO::Handle->new();
		my $sc = "$file";
		open ($fh, "<$sc") or die "$THIS_FILE ".__LINE__."; Failed to read: [$sc], error was: $!\n";
		while (<$fh>)
		{
			$config_data .= $_;
		}
		$fh->close();
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
	my $fh = IO::Handle->new();
	my $sc = "$backup_file";
	record($conf, "$THIS_FILE ".__LINE__."; Writing: [$sc]\n");
	open ($fh, ">$sc") or die "$THIS_FILE ".__LINE__."; Failed to write: [$sc], error was: $!\n";
	print $fh $config_data;
	$fh->close();
	
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
	my $this_file    = "";
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
		# If the first line of the file isn't '<!-- Striker Backup -->',
		# do not proceed.
		while (<$in_fh>)
		{
			chomp;
			my $line = $_;
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
					$this_file = "";
					next;
				}
				if ($line =~ /<!-- start (.*?) -->/)
				{
					$this_file = $1;
					next;
				}
				if ($this_file eq $conf->{path}{striker_conf})
				{
					$striker_conf .= "$line\n";
				}
				elsif ($this_file eq $conf->{path}{hosts})
				{
					$hosts .= "$line\n";
				}
				elsif ($this_file eq $conf->{path}{ssh_config})
				{
					$ssh_config .= "$line\n";
				}
				elsif ($this_file)
				{
					# Unknown file...
					record($conf, "$THIS_FILE ".__LINE__."; Unknown file: [$this_file], line: [$line]\n");
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
		my $an_fh = IO::Handle->new();
		open ($an_fh, ">$conf->{path}{striker_conf}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{striker_conf}], error: $!\n";
		print $an_fh $striker_conf;
		$an_fh->close();
		
		my $hosts_fh = IO::Handle->new();
		open ($hosts_fh, ">$conf->{path}{hosts}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{hosts}], error: $!\n";
		print $hosts_fh $hosts;
		$hosts_fh->close();
		
		my $ssh_fh = IO::Handle->new();
		open ($ssh_fh, ">$conf->{path}{ssh_config}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{ssh_config}], error: $!\n";
		print $ssh_fh $ssh_config;
		$ssh_fh->close();
		print AN::Common::template($conf, "config.html", "backup-file-loaded", {}, {
				file		=>	$conf->{cgi}{file},
			});
		footer($conf);
		exit;
	}
	
	return(0);
}

# This presents a form for the user to complete. When complete, an XML file
# with the install information for new nodes is created. This XML file is then
# passed to 'tools/anvil-configure-node' 
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
	$conf->{form}{anvil_ifn_dns1_star}          = "";
	$conf->{form}{anvil_ifn_dns2_star}          = "";
	$conf->{form}{anvil_switch1_name_star}      = "";
	$conf->{form}{anvil_switch1_ip_star}        = "";
	$conf->{form}{anvil_switch2_name_star}      = "";
	$conf->{form}{anvil_switch2_ip_star}        = "";
	$conf->{form}{anvil_pdu1_name_star}         = "";
	$conf->{form}{anvil_pdu1_ip_star}           = "";
	$conf->{form}{anvil_pdu2_name_star}         = "";
	$conf->{form}{anvil_pdu2_ip_star}           = "";
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
	$conf->{form}{anvil_node2_name_star}        = "";
	$conf->{form}{anvil_node2_bcn_ip_star}      = "";
	$conf->{form}{anvil_node2_ipmi_ip_star}     = "";
	$conf->{form}{anvil_node2_sn_ip_star}       = "";
	$conf->{form}{anvil_node2_ifn_ip_star}      = "";
	$conf->{form}{anvil_node2_pdu1_outlet_star} = "";
	$conf->{form}{anvil_node2_pdu2_outlet_star} = "";
	$conf->{form}{anvil_open_vnc_ports}         = "";
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
# 			if ($conf->{cgi}{'do'} eq "new")
# 			{
				# New install
				AN::InstallManifest::run_new_install_manifest($conf);
# 			}
# 			else
# 			{
# 				# Replacing a node.
# 			}
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
			if (not $conf->{cgi}{anvil_prefix})             { $conf->{cgi}{anvil_prefix}             = "xx"; }
			if (not $conf->{cgi}{anvil_domain})             { $conf->{cgi}{anvil_domain}             = "localdomain"; }
			if (not $conf->{cgi}{anvil_sequence})           { $conf->{cgi}{anvil_sequence}           = "01"; }
			if (not $conf->{cgi}{anvil_bcn_network})        { $conf->{cgi}{anvil_bcn_network}        = "10.20.0.0"; }
			if (not $conf->{cgi}{anvil_bcn_subnet})         { $conf->{cgi}{anvil_bcn_subnet}         = "255.255.0.0"; }
			if (not $conf->{cgi}{anvil_sn_network})         { $conf->{cgi}{anvil_sn_network}         = "10.10.0.0"; }
			if (not $conf->{cgi}{anvil_sn_subnet})          { $conf->{cgi}{anvil_sn_subnet}          = "255.255.0.0"; }
			if (not $conf->{cgi}{anvil_ifn_network})        { $conf->{cgi}{anvil_ifn_network}        = "10.255.0.0"; }
			if (not $conf->{cgi}{anvil_ifn_subnet})         { $conf->{cgi}{anvil_ifn_subnet}         = "255.255.0.0"; }
			if (not $conf->{cgi}{anvil_ifn_dns1})           { $conf->{cgi}{anvil_ifn_dns1}           = "8.8.8.8"; }
			if (not $conf->{cgi}{anvil_ifn_dns2})           { $conf->{cgi}{anvil_ifn_dns2}           = "8.8.4.4"; }
			if (not $conf->{cgi}{anvil_media_library_size}) { $conf->{cgi}{anvil_media_library_size} = "40"; }
			if (not $conf->{cgi}{anvil_media_library_unit}) { $conf->{cgi}{anvil_media_library_unit} = "GiB"; }
			if (not $conf->{cgi}{anvil_storage_pool1_size}) { $conf->{cgi}{anvil_storage_pool1_size} = "50"; }
			if (not $conf->{cgi}{anvil_storage_pool1_unit}) { $conf->{cgi}{anvil_storage_pool1_unit} = "%"; }
			if (not $conf->{cgi}{anvil_open_vnc_ports})     { $conf->{cgi}{anvil_open_vnc_ports}     = $conf->{sys}{open_vnc_ports}; }
		}
		
		# Show the manifest form.
		print AN::Common::template($conf, "config.html", "install-manifest-form", {
			form_file			=>	"/cgi-bin/striker",
			anvil_prefix			=>	$conf->{cgi}{anvil_prefix},
			anvil_prefix_star		=>	$conf->{form}{anvil_prefix_star},
			anvil_sequence			=>	$conf->{cgi}{anvil_sequence},
			anvil_sequence_star		=>	$conf->{form}{anvil_sequence_star},
			anvil_domain			=>	$conf->{cgi}{anvil_domain},
			anvil_domain_star		=>	$conf->{form}{anvil_domain_star},
			anvil_password			=>	$conf->{cgi}{anvil_password},
			anvil_password_star		=>	$conf->{form}{anvil_password_star},
			anvil_bcn_network		=>	$conf->{cgi}{anvil_bcn_network},
			anvil_bcn_network_star		=>	$conf->{form}{anvil_bcn_network_star},
			anvil_bcn_subnet		=>	$conf->{cgi}{anvil_bcn_subnet},
			anvil_sn_network		=>	$conf->{cgi}{anvil_sn_network},
			anvil_sn_subnet			=>	$conf->{cgi}{anvil_sn_subnet},
			anvil_sn_network_star		=>	$conf->{form}{anvil_sn_network_star},
			anvil_ifn_network		=>	$conf->{cgi}{anvil_ifn_network},
			anvil_ifn_network_star		=>	$conf->{form}{anvil_ifn_network_star},
			anvil_ifn_subnet		=>	$conf->{cgi}{anvil_ifn_subnet},
			anvil_media_library_size	=>	$conf->{cgi}{anvil_media_library_size},
			anvil_media_library_star	=>	$conf->{form}{anvil_media_library_star},
			say_anvil_media_library_unit	=>	build_select($conf, "anvil_media_library_unit", 0, 0, 60, $conf->{cgi}{anvil_media_library_unit}, ["GiB", "TiB"]),
			anvil_storage_pool1_size	=>	$conf->{cgi}{anvil_storage_pool1_size},
			anvil_storage_pool1_star	=>	$conf->{form}{anvil_storage_pool1_star},
			say_anvil_storage_pool1_unit	=>	build_select($conf, "anvil_storage_pool1_unit", 0, 0, 60, $conf->{cgi}{anvil_storage_pool1_unit}, ["%", "GiB", "TiB"]),
			anvil_repositories		=>	$conf->{cgi}{anvil_repositories},
			anvil_repositories_star		=>	$conf->{form}{anvil_repositories_star},
			anvil_name			=>	$conf->{cgi}{anvil_name},
			anvil_name_star			=>	$conf->{form}{anvil_name_star},
			anvil_node1_name		=>	$conf->{cgi}{anvil_node1_name},
			anvil_node1_name_star		=>	$conf->{form}{anvil_node1_name_star},
			anvil_node1_bcn_ip		=>	$conf->{cgi}{anvil_node1_bcn_ip},
			anvil_node1_bcn_ip_star		=>	$conf->{form}{anvil_node1_bcn_ip_star},
			anvil_node1_ipmi_ip		=>	$conf->{cgi}{anvil_node1_ipmi_ip},
			anvil_node1_ipmi_ip_star	=>	$conf->{form}{anvil_node1_ipmi_ip_star},
			anvil_node1_sn_ip		=>	$conf->{cgi}{anvil_node1_sn_ip},
			anvil_node1_sn_ip_star		=>	$conf->{form}{anvil_node1_sn_ip_star},
			anvil_node1_ifn_ip		=>	$conf->{cgi}{anvil_node1_ifn_ip},
			anvil_node1_ifn_ip_star		=>	$conf->{form}{anvil_node1_ifn_ip_star},
			anvil_node1_pdu1_outlet		=>	$conf->{cgi}{anvil_node1_pdu1_outlet},
			anvil_node1_pdu1_outlet_star	=>	$conf->{form}{anvil_node1_pdu1_outlet_star},
			anvil_node1_pdu2_outlet		=>	$conf->{cgi}{anvil_node1_pdu2_outlet},
			anvil_node1_pdu2_outlet_star	=>	$conf->{form}{anvil_node1_pdu2_outlet_star},
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
			anvil_ifn_gateway		=>	$conf->{cgi}{anvil_ifn_gateway},
			anvil_ifn_gateway_star		=>	$conf->{form}{anvil_ifn_gateway_star},
			anvil_ifn_dns1			=>	$conf->{cgi}{anvil_ifn_dns1},
			anvil_ifn_dns1_star		=>	$conf->{form}{anvil_ifn_dns1_star},
			anvil_ifn_dns2			=>	$conf->{cgi}{anvil_ifn_dns2},
			anvil_ifn_dns2_star		=>	$conf->{form}{anvil_ifn_dns2_star},
			anvil_ups1_name			=>	$conf->{cgi}{anvil_ups1_name},
			anvil_ups1_name_star		=>	$conf->{form}{anvil_ups1_name_star},
			anvil_ups1_ip			=>	$conf->{cgi}{anvil_ups1_ip},
			anvil_ups1_ip_star		=>	$conf->{form}{anvil_ups1_ip_star},
			anvil_ups2_name			=>	$conf->{cgi}{anvil_ups2_name},
			anvil_ups2_name_star		=>	$conf->{form}{anvil_ups2_name_star},
			anvil_ups2_ip			=>	$conf->{cgi}{anvil_ups2_ip},
			anvil_ups2_ip_star		=>	$conf->{form}{anvil_ups2_ip_star},
			anvil_pdu1_name			=>	$conf->{cgi}{anvil_pdu1_name},
			anvil_pdu1_name_star		=>	$conf->{form}{anvil_pdu1_name_star},
			anvil_pdu1_ip			=>	$conf->{cgi}{anvil_pdu1_ip},
			anvil_pdu1_ip_star		=>	$conf->{form}{anvil_pdu1_ip_star},
			anvil_pdu2_name			=>	$conf->{cgi}{anvil_pdu2_name},
			anvil_pdu2_name_star		=>	$conf->{form}{anvil_pdu2_name_star},
			anvil_pdu2_ip			=>	$conf->{cgi}{anvil_pdu2_ip},
			anvil_pdu2_ip_star		=>	$conf->{form}{anvil_pdu2_ip_star},
			anvil_switch1_name		=>	$conf->{cgi}{anvil_switch1_name},
			anvil_switch1_name_star		=>	$conf->{form}{anvil_switch1_name_star},
			anvil_switch1_ip		=>	$conf->{cgi}{anvil_switch1_ip},
			anvil_switch1_ip_star		=>	$conf->{form}{anvil_switch1_ip_star},
			anvil_switch2_name		=>	$conf->{cgi}{anvil_switch2_name},
			anvil_switch2_name_star		=>	$conf->{form}{anvil_switch2_name_star},
			anvil_switch2_ip		=>	$conf->{cgi}{anvil_switch2_ip},
			anvil_switch2_ip_star		=>	$conf->{form}{anvil_switch2_ip_star},
			anvil_striker1_name		=>	$conf->{cgi}{anvil_striker1_name},
			anvil_striker1_name_star	=>	$conf->{form}{anvil_striker1_name_star},
			anvil_striker1_bcn_ip		=>	$conf->{cgi}{anvil_striker1_bcn_ip},
			anvil_striker1_bcn_ip_star	=>	$conf->{form}{anvil_striker1_bcn_ip_star},
			anvil_striker1_ifn_ip		=>	$conf->{cgi}{anvil_striker1_ifn_ip},
			anvil_striker1_ifn_ip_star	=>	$conf->{form}{anvil_striker1_ifn_ip_star},
			anvil_striker2_name		=>	$conf->{cgi}{anvil_striker2_name},
			anvil_striker2_name_star	=>	$conf->{form}{anvil_striker2_name_star},
			anvil_striker2_bcn_ip		=>	$conf->{cgi}{anvil_striker2_bcn_ip},
			anvil_striker2_bcn_ip_star	=>	$conf->{form}{anvil_striker2_bcn_ip_star},
			anvil_striker2_ifn_ip		=>	$conf->{cgi}{anvil_striker2_ifn_ip},
			anvil_striker2_ifn_ip_star	=>	$conf->{form}{anvil_striker2_ifn_ip_star},
		});
	}
	
	return(0);
}

# This reads in the passed in install manifest file name and loads it into the
# appropriate cgi variables for use in the install manifest form.
sub load_install_manifest
{
	my ($conf, $file) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; load_install_manifest(); file: [$file]\n");
	
	# Read in the install manifest file.
	my $manifest_file = $conf->{path}{apache_manifests_dir}."/".$file;
	#record($conf, "$THIS_FILE ".__LINE__."; manifest_file: [$manifest_file]\n");
	if (-e $manifest_file)
	{
		# Load it!
		my $xml  = XML::Simple->new();
		my $data = $xml->XMLin($manifest_file, KeyAttr => {node => 'name'}, ForceArray => 1);
		
		# Nodes.
		foreach my $node (keys %{$data->{node}})
		{
			foreach my $a (keys %{$data->{node}{$node}})
			{
				if ($a eq "interfaces")
				{
					foreach my $b (keys %{$data->{node}{$node}{interfaces}->[0]})
					{
						foreach my $c (@{$data->{node}{$node}{interfaces}->[0]->{$b}})
						{
							my $name = $c->{name};
							my $mac  = $c->{mac};
							if (($mac) && ($mac =~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i))
							{
								$conf->{install_manifest}{$file}{node}{$node}{interface}{$name}{mac} = $mac;
							}
							else
							{
								# Malformed MAC
								record($conf, "$THIS_FILE ".__LINE__."; Install Manifest: [$file], Node: [$node], interface: [$name] has a malformed MAC address: [$mac], ignored. Format must be 'xx:xx:xx:xx:xx:xx'.\n");
							}
						}
					}
				}
				elsif ($a eq "network")
				{
					#print "a: [$a], -> b: [$data->{node}{$node}{network}->[0]]\n";
					#print Dumper $data->{node}{$node}{network}->[0];
					foreach my $network (keys %{$data->{node}{$node}{network}->[0]})
					{
						my $ip = $data->{node}{$node}{network}->[0]->{$network}->[0]->{ip};
						$conf->{install_manifest}{$file}{node}{$node}{network}{$network}{ip} = $ip;
						#print "Node: [$node], Network: [$network], IP: [$conf->{install_manifest}{$file}{node}{$node}{network}{$network}{ip}]\n";
					}
				}
				elsif ($a eq "pdu")
				{
					foreach my $b (@{$data->{node}{$node}{pdu}->[0]->{on}})
					{
						my $name     = $b->{name};
						my $port     = $b->{port};
						my $agent    = $b->{agent};
						my $user     = $b->{user};
						my $password = $b->{password};
						
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{port}     = $port;
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{agent}    = $agent;
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{user}     = $user;
						$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{password} = $password;
						
						#print "Node: [$node], PDU: [$name], Agent: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{agent}], Port: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{port}], User: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{user}], Password: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{password}]\n";
					}
				}
				elsif ($a eq "kvm")
				{
					foreach my $b (@{$data->{node}{$node}{kvm}->[0]->{on}})
					{
						my $name            = $b->{name}            ? $b->{name}            : "";
						my $port            = $b->{port}            ? $b->{port}            : "";
						my $agent           = $b->{agent}           ? $b->{agent}           : "";
						my $user            = $b->{user}            ? $b->{user}            : "";
						my $password        = $b->{password}        ? $b->{password}        : "";
						my $password_script = $b->{password_script} ? $b->{password_script} : "";
						
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$name}{port}            = $port;
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$name}{agent}           = $agent;
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$name}{user}            = $user;
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$name}{password}        = $password;
						$conf->{install_manifest}{$file}{node}{$node}{kvm}{$name}{password_script} = $password_script;
						
						#record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], KVM: [$name], Port: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{port}], User: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{user}], Password: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{password}], password_script: [$conf->{install_manifest}{$file}{node}{$node}{kvm}{$name}{password_script}]\n");
					}
				}
				elsif ($a eq "ipmi")
				{
					foreach my $b (@{$data->{node}{$node}{ipmi}->[0]->{on}})
					{
						my $name            = $b->{name}            ? $b->{name}            : "";
						my $ip              = $b->{ip}              ? $b->{ip}              : "";
						my $gateway         = $b->{gateway}         ? $b->{gateway}         : "";
						my $netmask         = $b->{netmask}         ? $b->{netmask}         : "";
						my $user            = $b->{user}            ? $b->{user}            : "";
						my $password        = $b->{password}        ? $b->{password}        : "";
						my $password_script = $b->{password_script} ? $b->{password_script} : "";
						
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{ip}              = $ip;
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{netmask}         = $netmask;
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{gateway}         = $gateway;
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{user}            = $user;
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{password}        = $password;
						$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{password_script} = $password_script;
						
						#record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], IPMI: [$name], IP: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{ip}/$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{netmask}, gw: $conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{gateway}], User: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{user}], Password: [$conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{password}], password_script: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{password_script}]\n");
					}
					
					my $name     = $data->{node}{$node}{$a}->[0]->{name};
					my $ip       = $data->{node}{$node}{$a}->[0]->{address}->[0]->{ip};
					my $user     = $data->{node}{$node}{$a}->[0]->{auth}->[0]->{user};
					my $password = $data->{node}{$node}{$a}->[0]->{auth}->[0]->{password};
					$conf->{install_manifest}{$file}{node}{$node}{ipmi}{name}     = $name;
					$conf->{install_manifest}{$file}{node}{$node}{ipmi}{ip}       = $ip;
					$conf->{install_manifest}{$file}{node}{$node}{ipmi}{user}     = $user;
					$conf->{install_manifest}{$file}{node}{$node}{ipmi}{password} = $password;
					#print "Node: [$node], IPMI: [$name], IP: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{ip}], user: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{user}], password: [$conf->{install_manifest}{$file}{node}{$node}{ipmi}{$name}{password}]\n";
				}
				else
				{
					# What's this?
					record($conf, "$THIS_FILE ".__LINE__."; Extra element in node: [$node]'s install manifest file: [$file]; a: [$a]\n");
					#foreach my $b (@{$data->{node}{$node}{$a}})
					#{
						#print "- b: [$b] -> [$data->{node}{$node}{$a}->[$b]]\n";
						#print Dumper $data->{node}{$node}{$a}->[$b];
					#}
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
					$conf->{install_manifest}{$file}{common}{anvil}{prefix}   = $a->{$b}->[0]->{prefix};
					$conf->{install_manifest}{$file}{common}{anvil}{domain}   = $a->{$b}->[0]->{domain};
					$conf->{install_manifest}{$file}{common}{anvil}{sequence} = $a->{$b}->[0]->{sequence};
					$conf->{install_manifest}{$file}{common}{anvil}{password} = $a->{$b}->[0]->{password};
				}
				elsif ($b eq "cluster")
				{
					# Cluster Name
					$conf->{install_manifest}{$file}{common}{cluster}{name} = $a->{$b}->[0]->{name};
					
					# Fencing stuff
					$conf->{install_manifest}{$file}{common}{cluster}{fence}{post_join_delay} = $a->{$b}->[0]->{fence}->[0]->{post_join_delay};
					$conf->{install_manifest}{$file}{common}{cluster}{fence}{order}           = $a->{$b}->[0]->{fence}->[0]->{order};
					$conf->{install_manifest}{$file}{common}{cluster}{fence}{delay}           = $a->{$b}->[0]->{fence}->[0]->{delay};
					$conf->{install_manifest}{$file}{common}{cluster}{fence}{delay_node}      = $a->{$b}->[0]->{fence}->[0]->{delay_node};
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
						
						$conf->{install_manifest}{$file}{common}{file}{$name}{mode}    = $mode;
						$conf->{install_manifest}{$file}{common}{file}{$name}{owner}   = $owner;
						$conf->{install_manifest}{$file}{common}{file}{$name}{group}   = $group;
						$conf->{install_manifest}{$file}{common}{file}{$name}{content} = $content;
					}
				}
				elsif ($b eq "iptables")
				{
					$conf->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports} = $a->{$b}->[0]->{vnc}->[0]->{ports};
					#record($conf, "$THIS_FILE ".__LINE__."; Firewall iptables; VNC port count: [$conf->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports}]\n");
				}
				elsif ($b eq "media_library")
				{
					$conf->{install_manifest}{$file}{common}{media_library}{size}  = $a->{$b}->[0]->{size};
					$conf->{install_manifest}{$file}{common}{media_library}{units} = $a->{$b}->[0]->{units};
				}
				elsif ($b eq "repository")
				{
					$conf->{install_manifest}{$file}{common}{anvil}{repositories} = $a->{$b}->[0]->{urls};
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
									$conf->{install_manifest}{$file}{common}{network}{bond}{options} = $a->{$b}->[0]->{$c}->[0]->{opts};
									#print "Common bonding options: [$conf->{install_manifest}{$file}{common}{network}{bonds}{options}]\n";
								}
								else
								{
									# Named network.
									my $name      = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{name};
									my $primary   = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{primary};
									my $secondary = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{secondary};
									$conf->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{primary}   = $primary;
									$conf->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{secondary} = $secondary;
									#print "Bond: [$name], Primary: [$conf->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{primary}], Secondary: [$conf->{install_manifest}{$file}{common}{network}{bond}{name}{$name}{secondary}]\n";
								}
							}
						}
						elsif ($c eq "bridges")
						{
							foreach my $d (@{$a->{$b}->[0]->{$c}->[0]->{bridge}})
							{
								my $name = $d->{name};
								my $on   = $d->{on};
								$conf->{install_manifest}{$file}{common}{network}{bridge}{$name}{on} = $on;
								#print "Bridge; name: [$name] on: [$conf->{install_manifest}{$file}{common}{network}{bridge}{$name}{on}]\n";
							}
						}
						else
						{
							my $netblock = $a->{$b}->[0]->{$c}->[0]->{netblock};
							my $netmask  = $a->{$b}->[0]->{$c}->[0]->{netmask};
							my $gateway  = $a->{$b}->[0]->{$c}->[0]->{gateway};
							my $defroute = $a->{$b}->[0]->{$c}->[0]->{defroute};
							my $dns1     = $a->{$b}->[0]->{$c}->[0]->{dns1};
							my $dns2     = $a->{$b}->[0]->{$c}->[0]->{dns2};
							
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{netblock} = $netblock;
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{netmask}  = $netmask;
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{gateway}  = $gateway;
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{defroute} = $defroute;
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{dns1}     = $dns1;
							$conf->{install_manifest}{$file}{common}{network}{name}{$c}{dns2}     = $dns2;
							
							#print "Network: [$c], netblock: [$conf->{install_manifest}{$file}{common}{network}{name}{bcn}{netblock}], netmask: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{netmask}], gateway [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{gateway}], defroute: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{defroute}], dns1: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{dns1}], dns2: [$conf->{install_manifest}{$file}{common}{network}{name}{$c}{dns2}]\n";
						}
					}
				}
				elsif ($b eq "pdu")
				{
					foreach my $c (@{$a->{$b}->[0]->{pdu}})
					{
						my $name            = $c->{name}            ? $c->{name}            : "";
						my $ip              = $c->{ip}              ? $c->{ip}              : "";
						my $user            = $c->{user}            ? $c->{user}            : "";
						my $password        = $c->{password}        ? $c->{password}        : "";
						my $password_script = $c->{password_script} ? $c->{password_script} : "";
						my $agent           = $c->{agent}           ? $c->{agent}           : "";
						
						$conf->{install_manifest}{$file}{common}{pdu}{$name}{ip}              = $ip;
						$conf->{install_manifest}{$file}{common}{pdu}{$name}{user}            = $user;
						$conf->{install_manifest}{$file}{common}{pdu}{$name}{password}        = $password;
						$conf->{install_manifest}{$file}{common}{pdu}{$name}{password_script} = $password_script;
						$conf->{install_manifest}{$file}{common}{pdu}{$name}{agent}           = $agent;
						#record($conf, "$THIS_FILE ".__LINE__."; PDU: [$name], IP: [$conf->{install_manifest}{$file}{common}{pdu}{$name}{ip}], user: [$conf->{install_manifest}{$file}{common}{pdu}{$name}{user}], password: [$conf->{install_manifest}{$file}{common}{pdu}{$name}{password}], password_script: [$conf->{install_manifest}{$file}{common}{pdu}{$name}{password_script}], agent: [$conf->{install_manifest}{$file}{common}{pdu}{$name}{agent}]\n");
					}
				}
				elsif ($b eq "kvm")
				{
					foreach my $c (@{$a->{$b}->[0]->{kvm}})
					{
						my $name            = $c->{name}            ? $c->{name}            : "";
						my $ip              = $c->{ip}              ? $c->{ip}              : "";
						my $user            = $c->{user}            ? $c->{user}            : "";
						my $password        = $c->{password}        ? $c->{password}        : "";
						my $password_script = $c->{password_script} ? $c->{password_script} : "";
						my $agent           = $c->{agent}           ? $c->{agent}           : "";
						
						$conf->{install_manifest}{$file}{common}{kvm}{$name}{ip}              = $ip;
						$conf->{install_manifest}{$file}{common}{kvm}{$name}{user}            = $user;
						$conf->{install_manifest}{$file}{common}{kvm}{$name}{password}        = $password;
						$conf->{install_manifest}{$file}{common}{kvm}{$name}{password_script} = $password_script;
						$conf->{install_manifest}{$file}{common}{kvm}{$name}{agent}           = $agent;
						#record($conf, "$THIS_FILE ".__LINE__."; KVM: [$name], IP: [$conf->{install_manifest}{$file}{common}{kvm}{$name}{ip}], user: [$conf->{install_manifest}{$file}{common}{kvm}{$name}{user}], password: [$conf->{install_manifest}{$file}{common}{kvm}{$name}{password}], password_script: [$conf->{install_manifest}{$file}{common}{kvm}{$name}{password_script}], agent: [$conf->{install_manifest}{$file}{common}{kvm}{$name}{agent}]\n");
					}
				}
				elsif ($b eq "ipmi")
				{
					foreach my $c (@{$a->{$b}->[0]->{ipmi}})
					{
						my $name            = $c->{name}            ? $c->{name}            : "";
						my $ip              = $c->{ip}              ? $c->{ip}              : "";
						my $user            = $c->{user}            ? $c->{user}            : "";
						my $password        = $c->{password}        ? $c->{password}        : "";
						my $password_script = $c->{password_script} ? $c->{password_script} : "";
						my $agent           = $c->{agent}           ? $c->{agent}           : "";
						
						$conf->{install_manifest}{$file}{common}{ipmi}{$name}{ip}              = $ip;
						$conf->{install_manifest}{$file}{common}{ipmi}{$name}{user}            = $user;
						$conf->{install_manifest}{$file}{common}{ipmi}{$name}{password}        = $password;
						$conf->{install_manifest}{$file}{common}{ipmi}{$name}{password_script} = $password_script;
						$conf->{install_manifest}{$file}{common}{ipmi}{$name}{agent}           = $agent;
						#record($conf, "$THIS_FILE ".__LINE__."; IPMI: [$name], IP: [$conf->{install_manifest}{$file}{common}{ipmi}{$name}{ip}], user: [$conf->{install_manifest}{$file}{common}{ipmi}{$name}{user}], password: [$conf->{install_manifest}{$file}{common}{ipmi}{$name}{password}], password_script: [$conf->{install_manifest}{$file}{common}{ipmi}{$name}{password_script}], agent: [$conf->{install_manifest}{$file}{common}{ipmi}{$name}{agent}]\n");
					}
				}
				elsif ($b eq "ssh")
				{
					$conf->{install_manifest}{$file}{common}{ssh}{keysize} = $a->{$b}->[0]->{keysize};
					#print "SSH keysize: [$conf->{install_manifest}{$file}{common}{ssh}{keysize}] bytes\n";
				}
				elsif ($b eq "storage_pool_1")
				{
					$conf->{install_manifest}{$file}{common}{storage_pool}{1}{size}  = $a->{$b}->[0]->{size};
					$conf->{install_manifest}{$file}{common}{storage_pool}{1}{units} = $a->{$b}->[0]->{units};
					#print "Storage Pool 1: [$conf->{install_manifest}{$file}{common}{storage_pool}{1}{size} $conf->{install_manifest}{$file}{common}{storage_pool}{1}{units}]\n";
				}
				elsif ($b eq "striker")
				{
					foreach my $c (@{$a->{$b}->[0]->{striker}})
					{
						my $name   = $c->{name};
						my $bcn_ip = $c->{bcn_ip};
						my $ifn_ip = $c->{ifn_ip};
						
						$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{bcn_ip} = $bcn_ip;
						$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{ifn_ip} = $ifn_ip;
						#print "Striker: [$name], BCN IP: [$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{bcn_ip}], IFN IP: [$conf->{install_manifest}{$file}{common}{striker}{name}{$name}{ifn_ip}]\n";
					}
				}
				elsif ($b eq "switch")
				{
					foreach my $c (@{$a->{$b}->[0]->{switch}})
					{
						my $name = $c->{name};
						my $ip   = $c->{ip};
						$conf->{install_manifest}{$file}{common}{switch}{$name}{ip} = $ip;
						#print "Switch: [$name], IP: [$conf->{install_manifest}{$file}{common}{switch}{$name}{ip}]\n";
					}
				}
				elsif ($b eq "update")
				{
					$conf->{install_manifest}{$file}{common}{update}{os} = $a->{$b}->[0]->{os};
					#print "Update OS: [$conf->{install_manifest}{$file}{common}{update}{os}]\n";
				}
				elsif ($b eq "ups")
				{
					foreach my $c (@{$a->{$b}->[0]->{ups}})
					{
						my $name = $c->{name};
						my $ip   = $c->{ip};
						my $type = $c->{type};
						my $port = $c->{port};
						$conf->{install_manifest}{$file}{common}{ups}{$name}{ip}   = $ip;
						$conf->{install_manifest}{$file}{common}{ups}{$name}{type} = $type;
						$conf->{install_manifest}{$file}{common}{ups}{$name}{port} = $port;
						#print "UPS: [$name], IP: [$conf->{install_manifest}{$file}{common}{ups}{$name}{ip}], type: [$conf->{install_manifest}{$file}{common}{ups}{$name}{type}], port: [$conf->{install_manifest}{$file}{common}{ups}{$name}{port}]\n";
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
		$conf->{cgi}{anvil_password}     = $conf->{install_manifest}{$file}{common}{anvil}{password}     ? $conf->{install_manifest}{$file}{common}{anvil}{password}     : $conf->{sys}{default_password};
		$conf->{cgi}{anvil_repositories} = $conf->{install_manifest}{$file}{common}{anvil}{repositories} ? $conf->{install_manifest}{$file}{common}{anvil}{repositories} : "";
		$conf->{cgi}{anvil_ssh_keysize}  = $conf->{install_manifest}{$file}{common}{ssh}{keysize}        ? $conf->{install_manifest}{$file}{common}{ssh}{keysize}        : 8191;
		
		# Media Library values
		$conf->{cgi}{anvil_media_library_size} = $conf->{install_manifest}{$file}{common}{media_library}{size};
		$conf->{cgi}{anvil_media_library_unit} = $conf->{install_manifest}{$file}{common}{media_library}{units};
		
		# Networks
		$conf->{cgi}{anvil_bcn_network} = $conf->{install_manifest}{$file}{common}{network}{name}{bcn}{netblock};
		$conf->{cgi}{anvil_bcn_subnet}  = $conf->{install_manifest}{$file}{common}{network}{name}{bcn}{netmask};
		$conf->{cgi}{anvil_sn_network}  = $conf->{install_manifest}{$file}{common}{network}{name}{sn}{netblock};
		$conf->{cgi}{anvil_sn_subnet}   = $conf->{install_manifest}{$file}{common}{network}{name}{sn}{netmask};
		$conf->{cgi}{anvil_ifn_network} = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{netblock};
		$conf->{cgi}{anvil_ifn_subnet}  = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{netmask};
		
		# iptables
		$conf->{cgi}{anvil_open_vnc_ports} = $conf->{install_manifest}{$file}{common}{cluster}{iptables}{vnc_ports};
		
		# Storage Pool 1
		$conf->{cgi}{anvil_storage_pool1_size} = $conf->{install_manifest}{$file}{common}{storage_pool}{1}{size};
		$conf->{cgi}{anvil_storage_pool1_unit} = $conf->{install_manifest}{$file}{common}{storage_pool}{1}{units};
		
		# Shared Variables
		$conf->{cgi}{anvil_name}        = $conf->{install_manifest}{$file}{common}{cluster}{name};
		$conf->{cgi}{anvil_ifn_gateway} = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{gateway};
		$conf->{cgi}{anvil_ifn_dns1}    = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{dns1};
		$conf->{cgi}{anvil_ifn_dns2}    = $conf->{install_manifest}{$file}{common}{network}{name}{ifn}{dns2};
		
		### Foundation Pack
		# Switches
		my $i = 1;
		foreach my $switch (sort {$a cmp $b} %{$conf->{install_manifest}{$file}{common}{switch}})
		{
			# Probably an autovivication bug or something... getting empty hash references.
			next if $switch =~ /^HASH/;
			my $name_key = "anvil_switch".$i."_name";
			my $ip_key   = "anvil_switch".$i."_ip";
			$conf->{cgi}{$name_key} = $switch;
			$conf->{cgi}{$ip_key}   = $conf->{install_manifest}{$file}{common}{switch}{$switch}{ip};
			#print "Switch: [$switch], name_key: [$name_key], ip_key: [$ip_key], CGI; Name: [$conf->{cgi}{$name_key}], IP: [$conf->{cgi}{$ip_key}]\n";
			$i++;
		}
		# PDUs
		$i = 1;
		foreach my $pdu (sort {$a cmp $b} %{$conf->{install_manifest}{$file}{common}{pdu}})
		{
			# Probably an autovivication bug or something... getting empty hash references.
			next if $pdu =~ /^HASH/;
			my $name_key = "anvil_pdu".$i."_name";
			my $ip_key   = "anvil_pdu".$i."_ip";
			$conf->{cgi}{$name_key} = $pdu;
			$conf->{cgi}{$ip_key}   = $conf->{install_manifest}{$file}{common}{pdu}{$pdu}{ip};
			#print "PDU: [$pdu], name_key: [$name_key], ip_key: [$ip_key], CGI; Name: [$conf->{cgi}{$name_key}], IP: [$conf->{cgi}{$ip_key}]\n";
			$i++;
		}
		# UPSes
		$i = 1;
		foreach my $ups (sort {$a cmp $b} %{$conf->{install_manifest}{$file}{common}{ups}})
		{
			# Probably an autovivication bug or something... getting empty hash references.
			next if $ups =~ /^HASH/;
			my $name_key = "anvil_ups".$i."_name";
			my $ip_key   = "anvil_ups".$i."_ip";
			$conf->{cgi}{$name_key} = $ups;
			$conf->{cgi}{$ip_key}   = $conf->{install_manifest}{$file}{common}{ups}{$ups}{ip};
			#print "UPS: [$ups], name_key: [$name_key], ip_key: [$ip_key], CGI; Name: [$conf->{cgi}{$name_key}], IP: [$conf->{cgi}{$ip_key}]\n";
			$i++;
		}
		# Striker Dashboards
		$i = 1;
		foreach my $striker (sort {$a cmp $b} %{$conf->{install_manifest}{$file}{common}{striker}{name}})
		{
			# Probably an autovivication bug or something... getting empty hash references.
			next if $striker =~ /^HASH/;
			my $name_key   = "anvil_striker".$i."_name";
			my $bcn_ip_key = "anvil_striker".$i."_bcn_ip";
			my $ifn_ip_key = "anvil_striker".$i."_ifn_ip";
			$conf->{cgi}{$name_key}   = $striker;
			$conf->{cgi}{$bcn_ip_key} = $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{bcn_ip};
			$conf->{cgi}{$ifn_ip_key} = $conf->{install_manifest}{$file}{common}{striker}{name}{$striker}{ifn_ip};
			$i++;
		}
		
		### Now the Nodes.
		$i = 1;
		foreach my $node (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}})
		{
			my $name_key          = "anvil_node".$i."_name";
			my $bcn_ip_key        = "anvil_node".$i."_bcn_ip";
			my $bcn_link1_mac_key = "anvil_node".$i."_bcn_link1_mac";
			my $bcn_link2_mac_key = "anvil_node".$i."_bcn_link2_mac";
			my $ipmi_ip_key       = "anvil_node".$i."_ipmi_ip";
			my $ipmi_netmask_key  = "anvil_node".$i."_ipmi_netmask",
			my $ipmi_gateway_key  = "anvil_node".$i."_ipmi_gateway",
			my $ipmi_password_key = "anvil_node".$i."_ipmi_password",
			my $ipmi_user_key     = "anvil_node".$i."_ipmi_user",
			my $sn_ip_key         = "anvil_node".$i."_sn_ip";
			my $sn_link1_mac_key  = "anvil_node".$i."_sn_link1_mac";
			my $sn_link2_mac_key  = "anvil_node".$i."_sn_link2_mac";
			my $ifn_ip_key        = "anvil_node".$i."_ifn_ip";
			my $ifn_link1_mac_key = "anvil_node".$i."_ifn_link1_mac";
			my $ifn_link2_mac_key = "anvil_node".$i."_ifn_link2_mac";
			my $pdu1_key          = "anvil_node".$i."_pdu1_outlet";
			my $pdu2_key          = "anvil_node".$i."_pdu2_outlet";
			my $pdu1_name         = $conf->{cgi}{anvil_pdu1_name};
			my $pdu2_name         = $conf->{cgi}{anvil_pdu2_name};
			
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
			
			$conf->{cgi}{$name_key}          = $node;
			$conf->{cgi}{$bcn_ip_key}        = $conf->{install_manifest}{$file}{node}{$node}{network}{bcn}{ip};
			$conf->{cgi}{$ipmi_ip_key}       = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{ip};
			$conf->{cgi}{$ipmi_netmask_key}  = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{netmask}  ? $conf->{install_manifest}{$file}{node}{$node}{ipmi}{netmask}  : $conf->{cgi}{anvil_bcn_subnet};
			$conf->{cgi}{$ipmi_gateway_key}  = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{gateway}  ? $conf->{install_manifest}{$file}{node}{$node}{ipmi}{gateway}  : 0;
			$conf->{cgi}{$ipmi_password_key} = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{password} ? $conf->{install_manifest}{$file}{node}{$node}{ipmi}{password} : $default_ipmi_pw;
			$conf->{cgi}{$ipmi_user_key}     = $conf->{install_manifest}{$file}{node}{$node}{ipmi}{user}     ? $conf->{install_manifest}{$file}{node}{$node}{ipmi}{user}     : "admin";
			$conf->{cgi}{$sn_ip_key}         = $conf->{install_manifest}{$file}{node}{$node}{network}{sn}{ip};
			$conf->{cgi}{$ifn_ip_key}        = $conf->{install_manifest}{$file}{node}{$node}{network}{ifn}{ip};
			$conf->{cgi}{$pdu1_key}          = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$pdu1_name}{port};
			$conf->{cgi}{$pdu2_key}          = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$pdu2_name}{port};
			
			# If the user remapped their network, we don't want to
			# undo the results.
			if (not $conf->{cgi}{perform_install})
			{
				$conf->{cgi}{$bcn_link1_mac_key} = $conf->{install_manifest}{$file}{node}{$node}{interface}{'bcn-link1'}{mac};
				$conf->{cgi}{$bcn_link2_mac_key} = $conf->{install_manifest}{$file}{node}{$node}{interface}{'bcn-link2'}{mac};
				$conf->{cgi}{$sn_link1_mac_key}  = $conf->{install_manifest}{$file}{node}{$node}{interface}{'sn-link1'}{mac};
				$conf->{cgi}{$sn_link2_mac_key}  = $conf->{install_manifest}{$file}{node}{$node}{interface}{'sn-link2'}{mac};
				$conf->{cgi}{$ifn_link1_mac_key} = $conf->{install_manifest}{$file}{node}{$node}{interface}{'ifn-link1'}{mac};
				$conf->{cgi}{$ifn_link2_mac_key} = $conf->{install_manifest}{$file}{node}{$node}{interface}{'ifn-link2'}{mac};
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::$bcn_link1_mac_key: [$conf->{cgi}{$bcn_link1_mac_key}], cgi::$bcn_link2_mac_key: [$conf->{cgi}{$bcn_link2_mac_key}], cgi::$sn_link1_mac_key: [$conf->{cgi}{$sn_link1_mac_key}], cgi::$sn_link2_mac_key: [$conf->{cgi}{$sn_link2_mac_key}], cgi::$ifn_link1_mac_key: [$conf->{cgi}{$ifn_link1_mac_key}], cgi::$ifn_link2_mac_key: [$conf->{cgi}{$ifn_link2_mac_key}].\n");
			}
			
			#print Dumper $conf->{install_manifest}{$file}{node}{$node};
			$i++;
		}
		
		### Now to build the fence strings.
		my $fence_order = $conf->{install_manifest}{$file}{common}{cluster}{fence}{order};
		
		# Nodes
		my $node1_name = $conf->{cgi}{anvil_node1_name};
		my $node2_name = $conf->{cgi}{anvil_node2_name};
		my $delay_set  = 0;
		my $delay_node = $conf->{install_manifest}{$file}{common}{cluster}{fence}{delay_node};
		my $delay_time = $conf->{install_manifest}{$file}{common}{cluster}{fence}{delay};
		foreach my $node ($conf->{cgi}{anvil_node1_name}, $conf->{cgi}{anvil_node2_name})
		{
			my $i = 1;
			foreach my $method (split/,/, $fence_order)
			{
				my $string = "";
				if ($method eq "kvm")
				{
					# Only ever one, but...
					my $j = 1;
					foreach my $name (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{kvm}})
					{
						my $device_name = $name;
						my $device_port = $conf->{install_manifest}{$file}{node}{$node}{kvm}{$name}{port};
						   $string      = "<device name=\"$device_name\" port=\"$device_port\" action=\"reboot\" />";
						if (($node eq $delay_node) && (not $delay_set))
						{
							$string    =~ s/ \/>/ delay="$delay_time" \/>/;
							$delay_set =  1;
						}
						$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
						record($conf, "$THIS_FILE ".__LINE__."; node: [$node], fence method: [$method ($i)], string: [$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} ($j)]\n");
						$j++;
					}
				}
				elsif ($method eq "ipmi")
				{
					# Only ever one, but...
					my $j = 1;
					foreach my $name (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{kvm}})
					{
						my $device_name = $name;
						   $string      = "<device name=\"$device_name\" action=\"reboot\" />";
						if (($node eq $delay_node) && (not $delay_set))
						{
							$string    =~ s/ \// delay="$delay_time" \/>/;
							$delay_set =  1;
						}
						$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], fence method: [$method ($i)], string: [$conf->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} ($j)]\n");
						$j++;
					}
				}
				elsif ($method eq "pdu")
				{
					# Here we can have > 1.
					my $j = 1;
					foreach my $name (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{node}{$node}{kvm}})
					{
						my $device_name = $name;
						my $device_port = $conf->{install_manifest}{$file}{node}{$node}{pdu}{$name}{port};
						   $string      = "<device name=\"$device_name\" port=\"$device_port\" action=\"reboot\" />";
						if (($node eq $delay_node) && (not $delay_set))
						{
							$string    =~ s/ \// delay="$delay_time" \/>/;
							$delay_set =  1;
						}
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
				foreach my $name (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{kvm}})
				{
					my $ip              = $conf->{install_manifest}{$file}{common}{kvm}{$name}{ip};
					my $user            = $conf->{install_manifest}{$file}{common}{kvm}{$name}{user};
					my $password        = $conf->{install_manifest}{$file}{common}{kvm}{$name}{password};
					my $password_script = $conf->{install_manifest}{$file}{common}{kvm}{$name}{password_script};
					my $agent           = $conf->{install_manifest}{$file}{common}{kvm}{$name}{agent}           ? $conf->{install_manifest}{$file}{common}{kvm}{$name}{agent} : "fence_virsh";
					my $string          = "<fencedevice name=\"$name\" agent=\"$agent\" ipaddr=\"$ip\" login=\"$user\" ";
					if ($password)
					{	
						$string .= "passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= "passwd_script=\"$password_script\"";
					}
					$string .= " />";
					$conf->{fence}{device}{$device}{name}{$name}{string} = $string;
					#record($conf, "$THIS_FILE ".__LINE__."; fence device: [$device], name: [$name], string: [$conf->{fence}{device}{$device}{name}{$name}{string}]\n");
				}
			}
			if ($device eq "ipmi")
			{
				foreach my $name (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{ipmi}})
				{
					my $ip              = $conf->{install_manifest}{$file}{common}{ipmi}{$name}{ip};
					my $user            = $conf->{install_manifest}{$file}{common}{ipmi}{$name}{user};
					my $password        = $conf->{install_manifest}{$file}{common}{ipmi}{$name}{password};
					my $password_script = $conf->{install_manifest}{$file}{common}{ipmi}{$name}{password_script};
					my $agent           = $conf->{install_manifest}{$file}{common}{ipmi}{$name}{agent}           ? $conf->{install_manifest}{$file}{common}{ipmi}{$name}{agent} : "fence_ipmilan";
					my $string          = "<fencedevice name=\"$name\" agent=\"$agent\" ipaddr=\"$ip\" login=\"$user\" ";
					if ($password)
					{	
						$string .= "passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= "passwd_script=\"$password_script\"";
					}
					$string .= " />";
					$conf->{fence}{device}{$device}{name}{$name}{string} = $string;
					#record($conf, "$THIS_FILE ".__LINE__."; fence device: [$device], name: [$name], string: [$conf->{fence}{device}{$device}{name}{$name}{string}]\n");
				}
			}
			if ($device eq "pdu")
			{
				foreach my $name (sort {$a cmp $b} keys %{$conf->{install_manifest}{$file}{common}{pdu}})
				{
					my $ip              = $conf->{install_manifest}{$file}{common}{pdu}{$name}{ip};
					my $user            = $conf->{install_manifest}{$file}{common}{pdu}{$name}{user};
					my $password        = $conf->{install_manifest}{$file}{common}{pdu}{$name}{password};
					my $password_script = $conf->{install_manifest}{$file}{common}{pdu}{$name}{password_script};
					my $agent           = $conf->{install_manifest}{$file}{common}{pdu}{$name}{agent}           ? $conf->{install_manifest}{$file}{common}{pdu}{$name}{agent} : "fence_apc_snmp";
					my $string          = "<fencedevice name=\"$name\" agent=\"$agent\" ipaddr=\"$ip\" login=\"$user\" ";
					if ($password)
					{	
						$string .= "passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= "passwd_script=\"$password_script\"";
					}
					$string .= " />";
					$conf->{fence}{device}{$device}{name}{$name}{string} = $string;
					#record($conf, "$THIS_FILE ".__LINE__."; fence device: [$device], name: [$name], string: [$conf->{fence}{device}{$device}{name}{$name}{string}]\n");
				}
			}
		}
		
		# Some system stuff.
		$conf->{sys}{post_join_delay} = $conf->{install_manifest}{$file}{common}{cluster}{fence}{post_join_delay};
		$conf->{sys}{update_os}       = $conf->{install_manifest}{$file}{common}{update}{os};
		if ((lc($conf->{install_manifest}{$file}{common}{update}{os}) eq "false") || (lc($conf->{install_manifest}{$file}{common}{update}{os}) eq "no"))
		{
			$conf->{sys}{update_os} = 0;
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
	
	print AN::Common::template($conf, "config.html", "install-manifest-header");
	local(*DIR);
	opendir(DIR, $conf->{path}{apache_manifests_dir}) or die "Failed to open the directory: [$conf->{path}{apache_manifests_dir}], error was: $!\n";
	while (my $file = readdir(DIR))
	{
		next if (($file eq ".") or ($file eq ".."));
		if ($file =~ /^install-manifest_(.*?)_(\d+-\d+-\d+)_(\d+:\d+:\d+).xml/)
		{
			my $anvil   = $1;
			my $date    = $2;
			my $time    = $3;
			$conf->{manifest_file}{$file}{anvil} = AN::Common::get_string($conf, { key => "message_0346", variables => {
									anvil	=>	$anvil,
									date	=>	$date,
									'time'	=>	$time,
								}});
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
	print AN::Common::template($conf, "config.html", "install-manifest-footer");
	
	return(0);
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
	<node name=\"$conf->{cgi}{anvil_node1_name}\">
		<network>
			<bcn ip=\"$conf->{cgi}{anvil_node1_bcn_ip}\" />
			<sn ip=\"$conf->{cgi}{anvil_node1_sn_ip}\" />
			<ifn ip=\"$conf->{cgi}{anvil_node1_ifn_ip}\" />
		</network>
		<ipmi>
			<on name=\"ipmi_n01\" ip=\"$conf->{cgi}{anvil_node1_ipmi_ip}\" netmask=\"$conf->{cgi}{anvil_bcn_subnet}\" user=\"$conf->{cgi}{anvil_node1_ipmi_user}\" password=\"$conf->{cgi}{anvil_node1_ipmi_password}\" gateway=\"\" />
		</ipmi>
		<pdu>
			<on port=\"$conf->{cgi}{anvil_node1_pdu1_outlet}\" />
			<on port=\"$conf->{cgi}{anvil_node1_pdu2_outlet}\" />
		</pdu>
		<kvm>
			<!-- port == virsh name of VM -->
			<on name=\"kvm_host\" port=\"\" />
		</kvm>
		<interfaces>
			<interface name=\"bcn-link1\" mac=\"$conf->{cgi}{anvil_node1_bcn_link1_mac}\" />
			<interface name=\"bcn-link2\" mac=\"$conf->{cgi}{anvil_node1_bcn_link2_mac}\" />
			<interface name=\"sn-link1\" mac=\"$conf->{cgi}{anvil_node1_sn_link1_mac}\" />
			<interface name=\"sn-link2\" mac=\"$conf->{cgi}{anvil_node1_sn_link2_mac}\" />
			<interface name=\"ifn-link1\" mac=\"$conf->{cgi}{anvil_node1_ifn_link1_mac}\" />
			<interface name=\"ifn-link2\" mac=\"$conf->{cgi}{anvil_node1_ifn_link2_mac}\" />
		</interfaces>
	</node>
	<node name=\"$conf->{cgi}{anvil_node2_name}\">
		<network>
			<bcn ip=\"$conf->{cgi}{anvil_node2_bcn_ip}\" />
			<sn ip=\"$conf->{cgi}{anvil_node2_sn_ip}\" />
			<ifn ip=\"$conf->{cgi}{anvil_node2_ifn_ip}\" />
		</network>
		<ipmi>
			<on name=\"ipmi_n02\" ip=\"$conf->{cgi}{anvil_node2_ipmi_ip}\" netmask=\"$conf->{cgi}{anvil_bcn_subnet}\" user=\"$conf->{cgi}{anvil_node2_ipmi_user}\" password=\"$conf->{cgi}{anvil_node2_ipmi_password}\" gateway=\"\" />
		</ipmi>
		<pdu>
			<on name=\"pdu01\" port=\"$conf->{cgi}{anvil_node2_pdu1_outlet}\" />
			<on name=\"pdu02\" port=\"$conf->{cgi}{anvil_node2_pdu2_outlet}\" />
		</pdu>
		<kvm>
			<on name=\"kvm_host\" port=\"\" />
		</kvm>
		<interfaces>
			<interface name=\"bcn-link1\" mac=\"$conf->{cgi}{anvil_node2_bcn_link1_mac}\" />
			<interface name=\"bcn-link2\" mac=\"$conf->{cgi}{anvil_node2_bcn_link2_mac}\" />
			<interface name=\"sn-link1\" mac=\"$conf->{cgi}{anvil_node2_sn_link1_mac}\" />
			<interface name=\"sn-link2\" mac=\"$conf->{cgi}{anvil_node2_sn_link2_mac}\" />
			<interface name=\"ifn-link1\" mac=\"$conf->{cgi}{anvil_node2_ifn_link1_mac}\" />
			<interface name=\"ifn-link2\" mac=\"$conf->{cgi}{anvil_node2_ifn_link2_mac}\" />
		</interfaces>
	</node>
	<common>
		<networks>
			<bcn netblock=\"$conf->{cgi}{anvil_bcn_network}\" netmask=\"$conf->{cgi}{anvil_bcn_subnet}\" gateway=\"\" dns1=\"\" dns2=\"\" defroute=\"no\" />
			<sn  netblock=\"$conf->{cgi}{anvil_sn_network}\" netmask=\"$conf->{cgi}{anvil_sn_subnet}\" gateway=\"\" dns1=\"\" dns2=\"\" defroute=\"no\" />
			<ifn netblock=\"$conf->{cgi}{anvil_ifn_network}\" netmask=\"$conf->{cgi}{anvil_ifn_subnet}\" gateway=\"$conf->{cgi}{anvil_ifn_gateway}\" dns1=\"$conf->{cgi}{anvil_ifn_dns1}\" dns2=\"$conf->{cgi}{anvil_ifn_dns2}\" defroute=\"yes\" />
			<bonding opts=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0\">
				<bcn name=\"bcn-bond1\" primary=\"bcn-link1\" secondary=\"bcn-link2\" />
				<sn name=\"sn-bond1\" primary=\"sn-link1\" secondary=\"sn-link2\" />
				<ifn name=\"ifn-bond1\" primary=\"ifn-link1\" secondary=\"ifn-link2\" />
			</bonding>
			<bridges>
				<bridge name=\"ifn-bridge1\" on=\"ifn\" />
			</bridges>
		</networks>
		<repository urls=\"$conf->{cgi}{anvil_repositories}\" />
		<media_library size=\"$conf->{cgi}{anvil_media_library_size}\" units=\"$conf->{cgi}{anvil_media_library_unit}\" />
		<storage_pool_1 size=\"$conf->{cgi}{anvil_storage_pool1_size}\" units=\"$conf->{cgi}{anvil_storage_pool1_unit}\" />
		<anvil prefix=\"$conf->{cgi}{anvil_prefix}\" sequence=\"$conf->{cgi}{anvil_sequence}\" domain=\"$conf->{cgi}{anvil_domain}\" password=\"$conf->{cgi}{anvil_password}\" />
		<ssh keysize=\"8191\" />
		<cluster name=\"$conf->{cgi}{anvil_name}\">
			<!-- Set the order to 'kvm' if building on KVM-backed VMs -->
			<fence order=\"ipmi,pdu\" post_join_delay=\"30\" delay=\"15\" delay_node=\"$conf->{cgi}{anvil_node1_name}\" />
		</cluster>
		<switch>
			<switch name=\"$conf->{cgi}{anvil_switch1_name}\" ip=\"$conf->{cgi}{anvil_switch1_ip}\" />
";
	if ($conf->{cgi}{anvil_switch2_name} ne "--")
	{
		print "			<switch name=\"$conf->{cgi}{anvil_switch2_name}\" ip=\"$conf->{cgi}{anvil_switch2_ip}\" />";
	}
	$xml .="
		</switch>
		<ups>
			<ups name=\"$conf->{cgi}{anvil_ups1_name}\" type=\"apc\" port=\"3551\" ip=\"$conf->{cgi}{anvil_ups1_ip}\" />
			<ups name=\"$conf->{cgi}{anvil_ups2_name}\" type=\"apc\" port=\"3552\" ip=\"$conf->{cgi}{anvil_ups2_ip}\" />
		</ups>
		<pdu>
			<pdu name=\"pdu01\" ip=\"$conf->{cgi}{anvil_pdu1_ip}\" agent=\"fence_apc_snmp\" />
			<pdu name=\"pdu02\" ip=\"$conf->{cgi}{anvil_pdu2_ip}\" agent=\"fence_apc_snmp\" />
		</pdu>
		<ipmi>
			<ipmi name=\"ipmi_n01\" agent=\"fence_ipmilan\" />
			<ipmi name=\"ipmi_n02\" agent=\"fence_ipmilan\" />
		</ipmi>
		<kvm>
			<kvm name=\"kvm_host\" ip=\"192.168.122.1\" user=\"root\" password_script=\"\" agent=\"fence_virsh\" />
		</kvm>
		<striker>
			<striker name=\"$conf->{cgi}{anvil_striker1_name}\" bcn_ip=\"$conf->{cgi}{anvil_striker1_bcn_ip}\" ifn_ip=\"$conf->{cgi}{anvil_striker1_ifn_ip}\" />
			<striker name=\"$conf->{cgi}{anvil_striker2_name}\" bcn_ip=\"$conf->{cgi}{anvil_striker2_bcn_ip}\" ifn_ip=\"$conf->{cgi}{anvil_striker2_ifn_ip}\" />
		</striker>
		<update os=\"true\" />
		<iptables>
			<vnc ports=\"$conf->{cgi}{anvil_open_vnc_ports}\" />
		</iptables>
	</common>
</config>
";
	
	# Write out the file.
	my $xml_file    = "install-manifest_".$conf->{cgi}{anvil_name}."_".$file_date.".xml";
	my $target_path = $conf->{path}{apache_manifests_dir}."/".$xml_file;
	my $target_url  = $conf->{path}{apache_manifests_url}."/".$xml_file;
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
	
	# Ask if we're replacing a failed node or doing a fresh install.
	if (not $conf->{cgi}{'do'})
	{
		print AN::Common::template($conf, "config.html", "ask-new-or-replace-run-install-manifest", {
			new_link	=>	"$conf->{'system'}{cgi_string}&do=new",
			replace_link	=>	"$conf->{'system'}{cgi_string}&do=replace",
		});
	}
	else
	{
		if ($conf->{cgi}{'do'} eq "new")
		{
			# Show the manifest form.
			$conf->{cgi}{anvil_node1_bcn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node1_bcn_link1_mac} eq "--";
			$conf->{cgi}{anvil_node1_bcn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node1_bcn_link2_mac} eq "--";
			$conf->{cgi}{anvil_node1_sn_link1_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node1_sn_link1_mac} eq "--";
			$conf->{cgi}{anvil_node1_sn_link2_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node1_sn_link2_mac} eq "--";
			$conf->{cgi}{anvil_node1_ifn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node1_ifn_link1_mac} eq "--";
			$conf->{cgi}{anvil_node1_ifn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node1_ifn_link2_mac} eq "--";
			$conf->{cgi}{anvil_node2_bcn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node2_bcn_link1_mac} eq "--";
			$conf->{cgi}{anvil_node2_bcn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node2_bcn_link2_mac} eq "--";
			$conf->{cgi}{anvil_node2_sn_link1_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node2_sn_link1_mac} eq "--";
			$conf->{cgi}{anvil_node2_sn_link2_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node2_sn_link2_mac} eq "--";
			$conf->{cgi}{anvil_node2_ifn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node2_ifn_link1_mac} eq "--";
			$conf->{cgi}{anvil_node2_ifn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if $conf->{cgi}{anvil_node2_ifn_link2_mac} eq "--";
			
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
			$conf->{cgi}{anvil_open_vnc_ports}         = $conf->{sys}{open_vnc_ports}     if not $conf->{cgi}{anvil_open_vnc_ports};
			my $say_repos =  $conf->{cgi}{anvil_repositories};
			   $say_repos =~ s/,/<br \/>/;
			   $say_repos =  "--" if not $say_repos;
			
			print AN::Common::template($conf, "config.html", "confirm-new-anvil-creation", {
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
				anvil_ifn_gateway		=>	$conf->{cgi}{anvil_ifn_gateway},
				anvil_ifn_dns1			=>	$conf->{cgi}{anvil_ifn_dns1},
				anvil_ifn_dns2			=>	$conf->{cgi}{anvil_ifn_dns2},
				anvil_pdu1_name			=>	$conf->{cgi}{anvil_pdu1_name},
				anvil_pdu2_name			=>	$conf->{cgi}{anvil_pdu2_name},
				anvil_open_vnc_ports		=>	$conf->{cgi}{anvil_open_vnc_ports},
				say_anvil_repos			=>	$say_repos,
				run				=>	$conf->{cgi}{run},
			});
		}
	}
	
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
	   $say_repos = "--" if not $say_repos;
	print AN::Common::template($conf, "config.html", "install-manifest-summay", {
		form_file			=>	"/cgi-bin/striker",
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
		anvil_node2_name		=>	$conf->{cgi}{anvil_node2_name},
		anvil_node2_bcn_ip		=>	$conf->{cgi}{anvil_node2_bcn_ip},
		anvil_node2_ipmi_ip		=>	$conf->{cgi}{anvil_node2_ipmi_ip},
		anvil_node2_sn_ip		=>	$conf->{cgi}{anvil_node2_sn_ip},
		anvil_node2_ifn_ip		=>	$conf->{cgi}{anvil_node2_ifn_ip},
		anvil_node2_pdu1_outlet		=>	$conf->{cgi}{anvil_node2_pdu1_outlet},
		anvil_node2_pdu2_outlet		=>	$conf->{cgi}{anvil_node2_pdu2_outlet},
		anvil_ifn_gateway		=>	$conf->{cgi}{anvil_ifn_gateway},
		anvil_ifn_dns1			=>	$conf->{cgi}{anvil_ifn_dns1},
		anvil_ifn_dns2			=>	$conf->{cgi}{anvil_ifn_dns2},
		anvil_ups1_name			=>	$conf->{cgi}{anvil_ups1_name},
		anvil_ups1_ip			=>	$conf->{cgi}{anvil_ups1_ip},
		anvil_ups2_name			=>	$conf->{cgi}{anvil_ups2_name},
		anvil_ups2_ip			=>	$conf->{cgi}{anvil_ups2_ip},
		anvil_pdu1_name			=>	$conf->{cgi}{anvil_pdu1_name},
		anvil_pdu1_ip			=>	$conf->{cgi}{anvil_pdu1_ip},
		anvil_pdu2_name			=>	$conf->{cgi}{anvil_pdu2_name},
		anvil_pdu2_ip			=>	$conf->{cgi}{anvil_pdu2_ip},
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
	
	# Make sure the Anvil! prefix is valid. This is used in the generated host's file.
# 	if (not $conf->{cgi}{anvil_prefix})
# 	{
# 		# Not allowed to be blank.
# 		$conf->{form}{anvil_prefix_star} = "#!string!symbol_0012!#";
# 		print AN::Common::template($conf, "config.html", "form-error", {
# 			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0159!#"}}),
# 		});
# 		$problem = 1;
# 	}
# 	elsif ($conf->{cgi}{anvil_prefix} =~ /\W/)
# 	{
# 		# Not allowed to be blank.
# 		$conf->{form}{anvil_prefix_star} = "#!string!symbol_0012!#";
# 		print AN::Common::template($conf, "config.html", "form-error", {
# 			message	=>	AN::Common::get_string($conf, {key => "explain_0101", variables => { field => "#!string!row_0159!#"}}),
# 		});
# 		$problem = 1;
# 	}
	
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

	# Check the gateway
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
	$conf->{cgi}{anvil_ifn_dns1}        = "" if $conf->{cgi}{anvil_ifn_dns1}        eq "--";
	$conf->{cgi}{anvil_ifn_dns2}        = "" if $conf->{cgi}{anvil_ifn_dns1}        eq "--";
	$conf->{cgi}{anvil_switch1_name}    = "" if $conf->{cgi}{anvil_switch1_name}    eq "--";
	$conf->{cgi}{anvil_switch1_ip}      = "" if $conf->{cgi}{anvil_switch1_ip}      eq "--";
	$conf->{cgi}{anvil_switch2_name}    = "" if $conf->{cgi}{anvil_switch2_name}    eq "--";
	$conf->{cgi}{anvil_switch2_ip}      = "" if $conf->{cgi}{anvil_switch2_ip}      eq "--";
	$conf->{cgi}{anvil_pdu1_name}       = "" if $conf->{cgi}{anvil_pdu1_name}       eq "--";
	$conf->{cgi}{anvil_pdu1_ip}         = "" if $conf->{cgi}{anvil_pdu1_ip}         eq "--";
	$conf->{cgi}{anvil_pdu2_name}       = "" if $conf->{cgi}{anvil_pdu2_name}       eq "--";
	$conf->{cgi}{anvil_pdu2_ip}         = "" if $conf->{cgi}{anvil_pdu2_ip}         eq "--";
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
	
	# Check DNS 1
	if (not $conf->{cgi}{anvil_ifn_dns1})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ifn_dns1_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0189!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_ifn_dns1}))
	{
		$conf->{form}{anvil_ifn_dns1_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0189!#"}}),
		});
		$problem = 1;
	}
	
	# Check DNS 2
	if (not $conf->{cgi}{anvil_ifn_dns2})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_ifn_dns2_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0190!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_ifn_dns2}))
	{
		$conf->{form}{anvil_ifn_dns2_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0190!#"}}),
		});
		$problem = 1;
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
	
	# Check that PDU #1's host name and IP are sane.
	if (not $conf->{cgi}{anvil_pdu1_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_pdu1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0174!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_pdu1_name}))
	{
		$conf->{form}{anvil_pdu1_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0174!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_pdu1_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_pdu1_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0175!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_pdu1_ip}))
	{
		$conf->{form}{anvil_pdu1_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0175!#"}}),
		});
		$problem = 1;
	}
	
	# Check that PDU #2's host name and IP are sane.
	if (not $conf->{cgi}{anvil_pdu2_name})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_pdu2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0176!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_domain_name($conf, $conf->{cgi}{anvil_pdu2_name}))
	{
		$conf->{form}{anvil_pdu2_name_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0103", variables => { field => "#!string!row_0176!#"}}),
		});
		$problem = 1;
	}
	if (not $conf->{cgi}{anvil_pdu2_ip})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_pdu2_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0100", variables => { field => "#!string!row_0177!#"}}),
		});
		$problem = 1;
	}
	elsif (not is_string_ipv4($conf, $conf->{cgi}{anvil_pdu2_ip}))
	{
		$conf->{form}{anvil_pdu2_ip_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0104", variables => { field => "#!string!row_0177!#"}}),
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
	# PDU 1 outlet
	if (not $conf->{cgi}{anvil_node1_pdu1_outlet})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node1_pdu1_outlet_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0192!#"
			}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_node1_pdu1_outlet} =~ /\D/)
	{
		$conf->{form}{anvil_node1_pdu1_outlet_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0108", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0192!#"
			}}),
		});
		$problem = 1;
	}
	# PDU 2 outlet
	if (not $conf->{cgi}{anvil_node1_pdu2_outlet})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node1_pdu2_outlet_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0193!#"
			}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_node1_pdu2_outlet} =~ /\D/)
	{
		$conf->{form}{anvil_node1_pdu2_outlet_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0108", variables => { 
				node	=>	"#!string!title_0156!#",
				field	=>	"#!string!row_0193!#"
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
	# PDU 1 outlet
	if (not $conf->{cgi}{anvil_node2_pdu1_outlet})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node2_pdu1_outlet_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0192!#"
			}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_node2_pdu1_outlet} =~ /\D/)
	{
		$conf->{form}{anvil_node2_pdu1_outlet_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0108", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0192!#"
			}}),
		});
		$problem = 1;
	}
	# PDU 2 outlet
	if (not $conf->{cgi}{anvil_node2_pdu2_outlet})
	{
		# Not allowed to be blank.
		$conf->{form}{anvil_node2_pdu2_outlet_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0106", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0193!#"
			}}),
		});
		$problem = 1;
	}
	elsif ($conf->{cgi}{anvil_node2_pdu2_outlet} =~ /\D/)
	{
		$conf->{form}{anvil_node2_pdu2_outlet_star} = "#!string!symbol_0012!#";
		print AN::Common::template($conf, "config.html", "form-error", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0108", variables => { 
				node	=>	"#!string!title_0157!#",
				field	=>	"#!string!row_0193!#"
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

### Not currently used, but leaving it as it's likely going to be useful later.
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
	#record($conf, "$THIS_FILE ".__LINE__."; configure_dashboard()\n");
	
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
	
	print AN::Common::template($conf, "select-anvil.html", "open-table");
	
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
	# Print the 'Manage' button.
	print AN::Common::template($conf, "select-anvil.html", "close-table");
	
	return (0);
}

# I need to convert the global configuration of the clusters to the format I use here.
sub convert_cluster_config
{
	my ($conf) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; convert_cluster_config()\n");
	
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
	
	#if ($conf->{'system'}{show_refresh})
	if ($conf->{cgi}{config})
	{
		$conf->{'system'}{cgi_string} =~ s/cluster=(.*?)&//;
		$conf->{'system'}{cgi_string} =~ s/cluster=(.*)$//;
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
				$say_back    = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
					button_link	=>	"?anvil=$conf->{cgi}{anvil}&config=true",
					button_text	=>	"$back_image",
					id		=>	"back",
				}, "", 1);
			}
			elsif ($conf->{cgi}{task} eq "push")
			{
				$say_refresh = "";
			}
			elsif ($conf->{cgi}{task} eq "create-install-manifest")
			{
				my $link =  $conf->{'system'}{cgi_string};
					$link =~ s/generate=true//;
					$link =~ s/anvil_password=.*?&//;
					$link =~ s/anvil_password=.*?$//;	# Catch the password if it's the last variable in the URL
					$link =~ s/&&/&/g;
				if ($conf->{cgi}{confirm})
				{
					if ($conf->{cgi}{run})
					{
						my $back_url =  $conf->{'system'}{cgi_string};
						   $back_url =~ s/confirm=.*?&//;
						   $back_url =~ s/confirm=.*$//;
						#record($conf, "$THIS_FILE ".__LINE__."; system::cgi_string: [$conf->{'system'}{cgi_string}]\n");
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
						button_link	=>	"$conf->{'system'}{cgi_string}",
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
						button_link	=>	"$conf->{'system'}{cgi_string}",
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
				button_link	=>	"$conf->{'system'}{cgi_string}",
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
			button_link	=>	"$conf->{'system'}{cgi_string}",
			button_text	=>	"$refresh_image",
			id		=>	"refresh",
		}, "", 1);
	}
	else
	{
		$say_refresh = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"$conf->{'system'}{cgi_string}",
			button_text	=>	"$refresh_image",
			id		=>	"refresh",
		}, "", 1);
	}
	print AN::Common::template($conf, "common.html", "header", {
		back	=>	$say_back,
		refresh	=>	$say_refresh,
	}); 
	
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
sub get_guacamole_link
{
	my ($conf, $node) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; get_guacamole_link(); node: [$node]\n");
	
	#foreach my $key (sort {$a cmp $b} keys %ENV) { record($conf, "$THIS_FILE ".__LINE__."; ENV{$key}: [$ENV{$key}].\n"); }
	my $guacamole_url;
	#record($conf, "$THIS_FILE ".__LINE__."; HTTP_REFERER: [$ENV{HTTP_REFERER}], ENV{HTTP_HOST}: [$ENV{HTTP_HOST}]\n");
	if ($ENV{HTTP_REFERER})
	{
		if ($guacamole_url =~ /cgi-bin/)
		{
			($guacamole_url) = ($ENV{HTTP_REFERER} =~ /^(.*?)\/cgi-bin/);
			#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
		}
		else
		{
			$guacamole_url = $ENV{HTTP_REFERER};
			#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
		}
		$guacamole_url =~ s/(\w)\/\w.*$/$1/;
		#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
	}
	elsif ($ENV{HTTP_HOST})
	{
		if ($ENV{SERVER_PORT} eq "443")
		{
			$guacamole_url = "https://".$ENV{HTTP_HOST};
			#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
		}
		else
		{
			$guacamole_url = "http://".$ENV{HTTP_HOST};
			#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
		}
	}
	#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
	
	my $cluster = $conf->{cgi}{cluster};
	#record($conf, "$THIS_FILE ".__LINE__."; cluster: [$cluster]\n");
	
	$guacamole_url .= "/guacamole/client.xhtml";
	#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");

	# No node specified, so return a link to the guacamole main page.
	if (not $node)
	{
		$guacamole_url =~ s/\/client.xhtml.*$/\//;
		#record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
	}
	
	record($conf, "$THIS_FILE ".__LINE__."; guacamole_url: [$guacamole_url]\n");
	return ($guacamole_url);
}

sub footer
{
	my ($conf) = @_;
	
	return(0) if $conf->{'system'}{footer_printed}; 
	my ($guacamole_url) = get_guacamole_link($conf, "");
	
	print AN::Common::template($conf, "common.html", "footer", {
		guacamole_url	=>	$guacamole_url,
	});
	
	$conf->{'system'}{footer_printed} = 1;
	
	return (0);
}

# This returns a 'YY-MM-DD_hh:mm:ss' formatted string based on the given time
# stamp
sub get_date
{
	my ($conf, $time) = @_;
	$time = time if not defined $time;
	
	my @time   = localtime($time);
	my $year   = ($time[5] + 1900);
	my $month  = sprintf("%.2d", ($time[4] + 1));
	my $day    = sprintf("%.2d", $time[3]);
	my $hour   = sprintf("%.2d", $time[2]);
	my $minute = sprintf("%.2d", $time[1]);
	my $second = sprintf("%.2d", $time[0]);
	
	# this returns "yyyy-mm-dd_hh:mm:ss".
	my $date = "$year-$month-$day $hour:$minute:$second";
	
	return ($date);
}

# The reads in any passed CGI variables
sub get_cgi_vars
{
	my ($conf, $vars) = @_;
	
	# Needed to read in passed CGI variables
	my $cgi = new CGI;
	
	# This will store the string I was passed.
	$conf->{'system'}{cgi_string} = "?";
	foreach my $var (@{$vars})
	{
		# A stray comma will cause a loop with no var name
		next if not $var;
		
		# I auto-select the 'cluster' variable if only one is checked.
		# Because of this, I don't want to overwrite the empty CGI 
		# value. This prevents that.
		if (($var eq "cluster") && ($conf->{cgi}{cluster}))
		{
			$conf->{'system'}{cgi_string} .= "$var=$conf->{cgi}{$var}&";
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
			$conf->{'system'}{cgi_string} .= "$var=$conf->{cgi}{$var}&";
		}
		record($conf, "$THIS_FILE ".__LINE__."; var: [$var] -> [$conf->{cgi}{$var}]\n") if $conf->{cgi}{$var};
	}
	$conf->{'system'}{cgi_string} =~ s/&$//;
	#AN::Common::to_log($conf, {file => $THIS_FILE, line => __LINE__, level => 2, message => "system::cgi_string: [$conf->{'system'}{cgi_string}]\n"});
	
	return (0);
}

# This reads in the configuration file.
sub read_conf
{
	my ($conf) = @_;
	
	$conf->{raw}{striker_conf} = [];
	my $fh = IO::Handle->new();
	my $sc = "$conf->{path}{striker_conf}";
	open ($fh, "<$sc") or die "$THIS_FILE ".__LINE__."; Failed to read: [$sc], error was: $!\n";
	while (<$fh>)
	{
		chomp;
		my $line = $_;
		push @{$conf->{raw}{striker_conf}}, $line;
		next if not $line;
		next if $line !~ /=/;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if $line =~ /^#/;
		next if not $line;
		my ($var, $val) = (split/=/, $line, 2);
		$var =~ s/^\s+//;
		$var =~ s/\s+$//;
		$val =~ s/^\s+//;
		$val =~ s/\s+$//;
		next if (not $var);
		AN::Common::_make_hash_reference($conf, $var, $val);
	}
	$fh->close();
	
	return(0);
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
			password	=>	$conf->{'system'}{root_password},
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
			cgi_string	=>	$conf->{'system'}{cgi_string},
		});
	}
	#print AN::Common::template($conf, "main-page.html", "close-table");
	
	return ($connected);
}

# Record a message to the log file.
sub record
{
	my ($conf, $message)=@_;

	my $fh = $conf->{handles}{'log'};
	if (not $fh)
	{
		$fh = IO::Handle->new();
		$conf->{handles}{'log'} = $fh;
		open ($fh, ">>$conf->{path}{'log'}") or die "$THIS_FILE ".__LINE__."; Can't write to: [$conf->{path}{'log'}], error: $!\n";
		print $fh "======\nOpening Anvil! Striker log at ".get_date($conf, time)."\n";
	}
	print $fh $message;
	$fh->flush;
	
	return (0);
}

# This gathers details on the cluster.
sub scan_cluster
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; scan_cluster()\n");
	
	AN::Striker::set_node_names ($conf);
	check_nodes    ($conf);
	#record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{'system'}{up_nodes}]\n");
	if ($conf->{'system'}{up_nodes} > 0)
	{
		AN::Striker::check_vms($conf);
	}

	return(0);
}

sub check_nodes
{
	my ($conf) = @_;
	record($conf, "$THIS_FILE ".__LINE__."; check_nodes()\n");
	
	# Show the 'scanning in progress' table.
	# variables hash feeds 'message_0272'.
	print AN::Common::template($conf, "common.html", "scanning-message", {}, {
		anvil	=>	$conf->{cgi}{cluster},
	});
	
	# Start your engines!
	check_node_status($conf);
	
	return (0);
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
	$conf->{'system'}{up_nodes}     = @{$conf->{up_nodes}};
	$conf->{'system'}{online_nodes} = @{$conf->{online_nodes}};
	#record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{'system'}{up_nodes}], online nodes: [$conf->{'system'}{online_nodes}]\n");
	if ($conf->{'system'}{up_nodes} < 1)
	{
		# Neither node is up. If I can power them on, then I will show
		# the node section to enable power up.
		if (not $conf->{'system'}{show_nodes})
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
	my $node1 = $conf->{'system'}{cluster}{node1_name};
	my $node2 = $conf->{'system'}{cluster}{node2_name};
	my $node1_long = $conf->{node}{$node1}{info}{host_name};
	my $node2_long = $conf->{node}{$node2}{info}{host_name};
	$conf->{'system'}{gfs2_down} = 0;
	if (($conf->{node}{$node1}{daemon}{gfs2}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{gfs2}{exit_code} ne "0"))
	{
		$conf->{'system'}{gfs2_down} = 1;
	}
	$conf->{'system'}{clvmd_down} = 0;
	if (($conf->{node}{$node1}{daemon}{clvmd}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{clvmd}{exit_code} ne "0"))
	{
		$conf->{'system'}{clvmd_down} = 1;
	}
	$conf->{'system'}{drbd_down} = 0;
	if (($conf->{node}{$node1}{daemon}{drbd}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{drbd}{exit_code} ne "0"))
	{
		$conf->{'system'}{drbd_down} = 1;
	}
	$conf->{'system'}{rgmanager_down} = 0;
	if (($conf->{node}{$node1}{daemon}{rgmanager}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{rgmanager}{exit_code} ne "0"))
	{
		$conf->{'system'}{rgmanager_down} = 1;
	}
	$conf->{'system'}{cman_down} = 0;
	if (($conf->{node}{$node1}{daemon}{cman}{exit_code} ne "0") && ($conf->{node}{$node2}{daemon}{cman}{exit_code} ne "0"))
	{
		$conf->{'system'}{cman_down} = 1;
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
	my $fh = IO::Handle->new;
	my $sc = "$conf->{path}{ping} -c 1 $node; echo ping:\$?";
	record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
	open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^ping:(\d+)/)
		{
			$exit = $1;
		}
	}
	$fh->close();
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
		my $sc = "$conf->{path}{ping} -c 1 $node; echo ping:\$?";
		record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
		open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^ping:(\d+)/)
			{
				$exit = $1;
			}
		}
		$fh->close();
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
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], port: [$conf->{node}{$node}{port}], user: [root], password: [$conf->{'system'}{root_password}]\n");
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], port: [$conf->{node}{$node}{port}], user: [root]\n");
	my ($error, $ssh_fh, $dmidecode) = remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{'system'}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	"dmidecode -t 4,16,17",
	});
	record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], dmidecode: [$dmidecode (".@{$dmidecode}." lines)]\n");

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
		$conf->{'system'}{show_nodes} = 1;
		$conf->{node}{$node}{up}      = 1;
		push @{$conf->{up_nodes}}, $node;
		record($conf, "$THIS_FILE ".__LINE__."; node::${node}::up: [$conf->{node}{$node}{up}], up_nodes: [".@{$conf->{up_nodes}}."]\n");
		
		### Get the rest of the shell calls done before starting to
		### parse.
		# Get meminfo
		($error, $ssh_fh, my $meminfo) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"cat /proc/meminfo",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], meminfo: [$meminfo (".@{$meminfo}." lines)]\n");
		
		# Get drbd info
		($error, $ssh_fh, my $proc_drbd) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"if [ -e /proc/drbd ]; then cat /proc/drbd; else echo 'drbd offline'; fi",
		});
		record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], proc_drbd: [$proc_drbd (".@{$proc_drbd}." lines)]\n");
		#foreach my $line (@{$proc_drbd}) { record($conf, "$THIS_FILE ".__LINE__."; proc_drbd line: [$line]\n"); }
		($error, $ssh_fh, my $parse_drbdadm_dumpxml) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"drbdadm dump-xml",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], drbd_res_file: [$parse_drbdadm_dumpxml (".@{$parse_drbdadm_dumpxml}." lines)]\n");
		
		# clustat info
		($error, $ssh_fh, my $clustat) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"clustat",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], clustat: [$clustat (".@{$clustat}." lines)]\n");
		
		# Read cluster.conf
		($error, $ssh_fh, my $cluster_conf) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"cat /etc/cluster/cluster.conf",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], cluster_conf: [$cluster_conf (".@{$cluster_conf}." lines)]\n");
		
		### TODO: Break these up into individual calls to be cleaner.
		# Read the daemon states
		($error, $ssh_fh, my $daemons) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"
				/etc/init.d/rgmanager status; echo striker:rgmanager:\$?; 
				/etc/init.d/cman status; echo striker:cman:\$?; 
				/etc/init.d/drbd status; echo striker:drbd:\$?; 
				/etc/init.d/clvmd status; echo striker:clvmd:\$?; 
				/etc/init.d/gfs2 status; echo striker:gfs2:\$?; 
				/etc/init.d/libvirtd status; echo striker:libvirtd:\$?;",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], daemons: [$daemons (".@{$daemons}." lines)]\n");
		
		# LVM data
		($error, $ssh_fh, my $lvm_scan) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"pvscan; vgscan; lvscan",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], lvm_scan: [$lvm_scan (".@{$lvm_scan}." lines)]\n");
		($error, $ssh_fh, my $lvm_data) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"
				pvs --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid; 
				vgs --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name; 
				lvs --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices;",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], lvm_data: [$lvm_data (".@{$lvm_data}." lines)]\n");
		
		# GFS2 data
		($error, $ssh_fh, my $gfs2) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"cat /etc/fstab | grep gfs2 && df -hP",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], gfs2: [$gfs2 (".@{$gfs2}." lines)]\n");
		
		# virsh data
		#record($conf, "$THIS_FILE ".__LINE__."; Calling: [virsh list --all]\n");
		($error, $ssh_fh, my $virsh) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"virsh list --all",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], virsh: [$virsh (".@{$virsh}." lines)]\n");
		
		# VM definitions
		($error, $ssh_fh, my $vm_defs) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	0,
			shell_call	=>	"cat /shared/definitions/*",
			#shell_call	=>	"for f in \$(ls /shared/definitions/); do cat /shared/definitions/\$f; done",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], vm_defs: [$vm_defs (".@{$vm_defs}." lines)]\n");
		
		# Host name, in case the cluster isn't configured yet.
		($error, $ssh_fh, my $hostname) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	"hostname",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], hostname->[0]: [$hostname->[0]]\n");
		if ($hostname->[0])
		{
			$conf->{node}{$node}{info}{host_name} = $hostname->[0]; 
			#record($conf, "$THIS_FILE ".__LINE__."; node::${node}::info::host_name: [$conf->{node}{$node}{info}{host_name}]\n");
		}
		
		# Read the node's host file.
		($error, $ssh_fh, my $hosts) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	"cat /etc/hosts",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], hosts: [$hosts]\n");
		
		# Read the node's dmesg.
		($error, $ssh_fh, my $dmesg) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	"dmesg",
		});
		#record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], dmesg: [$dmesg]\n");
		
		### Last call, close the door on our way out.
		# Bond data
		($error, $ssh_fh, my $bond) = remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	"if [ -e '/proc/net/bonding/ifn-bond1' ];
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
						fi;",
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
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
		if ($conf->{node}{$node}{is_on} == 0)
		{
			$conf->{'system'}{show_nodes}         = 1;
			$conf->{node}{$node}{enable_poweron}  = 1;
			$conf->{node}{$node}{enable_poweroff} = 0;
			$conf->{node}{$node}{enable_fence}    = 0;
			#$conf->{node}{$node}{info}{'state'} = "<span class=\"highlight_warning\">Powered Off</span>";
			#$conf->{node}{$node}{info}{note}    = "The node <span class=\"fixed_width\">$node</span> is powered down.";
		}
		elsif ($conf->{node}{$node}{is_on} == 1)
		{
			# The node is on but unreachable.
			$conf->{'system'}{show_nodes}         = 1;
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
			$conf->{'system'}{show_nodes}         = 0;
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
			$conf->{'system'}{show_nodes}         = 0;
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
		
		my $sc = "$conf->{path}{'ssh-keygen'} -t rsa -N \"\" -b 4095 -f $conf->{path}{'striker_files'}/.ssh/id_rsa";
		record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc]\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
		$fh->close();
		
		if (not -e $rsa_public_file)
		{
			record($conf, "$THIS_FILE ".__LINE__."; Failed to create a new SSH key.\n");
		}
	}
	
	my $sc = $rsa_public_file;
	record($conf, "$THIS_FILE ".__LINE__."; Reading: [$sc]\n");
	my $fh = IO::Handle->new();
	open ($fh, "<$sc") or die "$THIS_FILE ".__LINE__."; Failed to read: [$sc]. Error was: $!\n";
	while(<$fh>)
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
	#record($conf, "$THIS_FILE ".__LINE__."; get_hostname()\n");

	my $hostname;
	my $sc = "$conf->{path}{hostname}";
	#record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc]\n";
	while(<$fh>)
	{
		chomp;
		$hostname = $_;
		#record($conf, "$THIS_FILE ".__LINE__."; hostname: [$hostname]\n");
	}
	$fh->close();
	
	#record($conf, "$THIS_FILE ".__LINE__."; hostname: [$hostname]\n");
	return($hostname);
}

# This calls the target machine and runs a command.
sub remote_call
{
	my ($conf, $parameters) = @_;
	
	#record($conf, "$THIS_FILE ".__LINE__."; parameters->{password}: [$parameters->{password}], system::root_password: [$conf->{'system'}{root_password}]\n");
	my $cluster    = $conf->{cgi}{cluster};
	my $node       = $parameters->{node};
	my $port       = $parameters->{port}             ? $parameters->{port}     : 22;
	my $user       = $parameters->{user}             ? $parameters->{user}     : "root";
	my $password   = $parameters->{password}         ? $parameters->{password} : $conf->{'system'}{root_password};
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
				record($conf, "$THIS_FILE ".__LINE__."; SSH session opened to: [$node].\n");
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
						password	=>	$conf->{'system'}{root_password},
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
						password	=>	$conf->{'system'}{root_password},
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
						password	=>	$conf->{'system'}{root_password},
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
	#record($conf, "$THIS_FILE ".__LINE__."; in parse_cluster_conf(); node: [$node]\n");
	
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
			my $name   = $line =~ /name="(.*?)"/   ? $1 : "";
			my $port   = $line =~ /port="(.*?)"/   ? $1 : "";
			my $action = $line =~ /action="(.*?)"/ ? $1 : "";
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name}   = $name;
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port}   = $port;
			$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action} = $action;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$this_node], method: [$in_method], method count: [$device_count], name: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name}], port: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port}], action: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action}]\n");
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
			my $name     = $line =~ /name="(.*?)"/   ? $1 : "";
			my $agent    = $line =~ /agent="(.*?)"/  ? $1 : "";
			my $address  = $line =~ /ipaddr="(.*?)"/ ? $1 : "";
			my $login    = $line =~ /login="(.*?)"/  ? $1 : "";
			my $password = $line =~ /passwd="(.*?)"/ ? $1 : "";
			# If the password has a single-quote, ricci changes it to &apos;. We need to change it back.
			$password =~ s/&apos;/'/g;
			$conf->{fence}{$name}{agent}    = $agent;
			$conf->{fence}{$name}{address}  = $address;
			$conf->{fence}{$name}{login}    = $login;
			$conf->{fence}{$name}{password} = $password;
			#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], fence name: [$name], agent: [$conf->{fence}{$name}{agent}], address: [$conf->{fence}{$name}{address}], login: [$conf->{fence}{$name}{login}], password: [$conf->{fence}{$name}{password}]\n");
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
	#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], peer: [$peer]\n");
	foreach my $this_node ($node, $peer)
	{
		# This will contain possible fence methods.
		$conf->{node}{$this_node}{info}{fence_methods} = "";
		
		# This will contain the command needed to check the node's
		# power.
		$conf->{node}{$this_node}{info}{power_check_command} = "";
		
		#record($conf, "$THIS_FILE ".__LINE__."; this node: [$this_node]\n");
		foreach my $in_method (sort {$a cmp $b} keys %{$conf->{node}{$this_node}{fence}{method}})
		{
			#record($conf, "$THIS_FILE ".__LINE__."; this node: [$this_node], method: [$in_method]\n");
			my $fence_command = "$in_method: ";
			foreach my $device_count (sort {$a cmp $b} keys %{$conf->{node}{$this_node}{fence}{method}{$in_method}{device}})
			{
				#$fence_command .= " [$device_count]";
				#record($conf, "$THIS_FILE ".__LINE__."; this node: [$this_node], method: [$in_method], method count: [$device_count], name: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name}], port: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port}], action: [$conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action}]\n");
				#Find the matching fence device entry.
				foreach my $name (sort {$a cmp $b} keys %{$conf->{fence}})
				{
					if ($name eq $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name})
					{
						my $agent    = $conf->{fence}{$name}{agent};
						my $address  = $conf->{fence}{$name}{address};
						my $login    = $conf->{fence}{$name}{login};
						my $password = $conf->{fence}{$name}{password};
						my $port     = $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port};
						#my $action   = $conf->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action};
						#   $action   = "reboot" if not $action;
						my $command  = "$agent -a $address ";
						   $command .= "-l $login "        if $login;
						   $command .= "-p \"$password\" " if $password;	# quote the password in case it has spaces in it.
						   $command .= "-n $port "         if $port;
						   $command =~ s/ $//;
						$conf->{node}{$this_node}{fence_method}{$in_method}{device}{$device_count}{command} = $command;
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$this_node], fence command: [$conf->{node}{$this_node}{fence_method}{$in_method}{device}{$device_count}{command}]\n");
						if ($agent eq "fence_ipmilan")
						{
							$conf->{node}{$this_node}{info}{power_check_command} = $command;
							#record($conf, "$THIS_FILE ".__LINE__."; node: [$this_node]: power check command: [$conf->{node}{$this_node}{info}{power_check_command}]\n");
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
			# Uh oh...
			my $message = AN::Common::get_string($conf, {key => "message_0044", variables => {
				node	=>	$node,
			}});
			error($conf, $message); 
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
	#record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{'system'}{up_nodes}]\n");
	### TODO: This fails when node 1 is down because it has not yet looked
	###       for node 2 to see if it is on or not. Check manually.
	if ($conf->{'system'}{up_nodes} == 1)
	{
		# It has to be the peer of this node.
		$peer = @{$conf->{up_nodes}}[0];
	}
	
	record($conf, "$THIS_FILE ".__LINE__."; node: [$node], peer: [$peer]\n");
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
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	"",
			channel		=>	"",
			'close'		=>	0,
			shell_call	=>	"$conf->{node}{$node}{info}{power_check_command} -o status",
		});
		record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
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
				my $sc = "$conf->{node}{$node}{info}{power_check_command} -o status";
				record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
				my $fh = IO::Handle->new();
				open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc]\n";
				while(<$fh>)
				{
					chomp;
					my $line = $_;
					#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
					if ($line =~ / On$/i)
					{
						$conf->{node}{$node}{is_on} = 1;
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
					}
					if ($line =~ / Off$/i)
					{
						$conf->{node}{$node}{is_on} = 0;
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
					}
					if ($line =~ / Unknown$/i)
					{
						$conf->{node}{$node}{is_on} = 2;
						#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}] - Failed to get info from IPMI!\n");
					}
				}
				$fh->close();
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
	
	my $sc = "$conf->{path}{gethostip} -d $target_host";
	#record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc]\n";
	while(<$fh>)
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
	$fh->close();
	
	#record($conf, "$THIS_FILE ".__LINE__."; target_ip: [$target_ip]\n");
	if ($target_ip)
	{
		# Find out my own IP(s) and subnet(s).
		my $in_dev       = "";
		my $this_ip      = "";
		my $this_nm      = "";
		
		my $sc           = "$conf->{path}{ifconfig}";
		#record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc]\n";
		while(<$fh>)
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
		$fh->close();
	}
	
	#record($conf, "$THIS_FILE ".__LINE__."; local_access: [$local_access]\n");
	return($local_access, $target_ip);
}

# This records this scan's data to the cache file.
sub write_node_cache
{
	my ($conf, $node) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; in write_node_cache(); node: [$node]\n");
	
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
		#record($conf, "$THIS_FILE ".__LINE__."; node: [$node], power check command: [$conf->{node}{$node}{info}{power_check_command}]\n");
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
		my $fh         = IO::Handle->new();
		#record($conf, "$THIS_FILE ".__LINE__."; writing: [$cache_file]\n");
		open ($fh, "> $cache_file") or error($conf, AN::Common::get_string($conf, {key => "message_0050", variables => {
				cache_file	=>	$cache_file,
				uid		=>	$<,
				error		=>	$!,
			}}));
		foreach my $line (@lines)
		{
			print $fh $line;
		}
		$fh->close();
	}
	
	return(0);
}

# This reads the cached data for this node, if available.
sub read_node_cache
{
	my ($conf, $node) = @_;
	#record($conf, "$THIS_FILE ".__LINE__."; in read_node_cache(); node: [$node]\n");
	
	# Write the command to disk so that I can check the power state
	# in the future when both nodes are offline.
	my $cluster    = $conf->{cgi}{cluster};
	my $cache_file = "$conf->{path}{'striker_cache'}/cache_".$cluster."_".$node.".striker";
	#record($conf, "$THIS_FILE ".__LINE__."; cluster: [$cluster], cache file: [$cache_file]\n");
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
		my $in_hosts = 0;
		my $sc       = $cache_file;
		record($conf, "$THIS_FILE ".__LINE__."; Reading: [$sc]\n");
		my $fh = IO::Handle->new();
		open ($fh, "<$sc") or die "$THIS_FILE ".__LINE__."; Failed to read: [$sc]\n";
		while(<$fh>)
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
		$fh->close();
		$conf->{clusters}{$cluster}{cache_exists} = 1;
	}
	else
	{
		$conf->{clusters}{$cluster}{cache_exists} = 0;
		$conf->{node}{$node}{info}{host_name}     = $node;
	}
	#record($conf, "$THIS_FILE ".__LINE__."; host name: [$conf->{node}{$node}{info}{host_name}], power check command: [$conf->{node}{$node}{info}{power_check_command}]\n");
	
	return(0);
}

1;
