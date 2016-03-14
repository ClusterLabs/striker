// Uses the 'prefix', anvil sequence and domain names to populate the rest of the form fiels.
$("#set_secondary_values").click(function(){
	var prefix      = $("#anvil_prefix").val();
	var sequence    = $("#anvil_sequence").val();
	var domain      = $("#anvil_domain").val();
	var bcn_network = $("#anvil_bcn_network").val();
	var bcn_subnet  = $("#anvil_bcn_subnet").val();
	var sn_network  = $("#anvil_sn_network").val();
	var sn_subnet   = $("#anvil_sn_subnet").val();
	var ifn_network = $("#anvil_ifn_network").val();
	var ifn_subnet  = $("#anvil_ifn_subnet").val();
	
	// If the subnet is '255.255.0.0', we'll preset the IPs.
	var regex_cidr16      = /^255\.255\.0\.0$/i;
	var regex_cidr24      = /^255\.255\.255\.0$/i;
	var regex_ipv4        = /^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)$/i;
	var regex_two_octal   = /^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.*$/i;
	var regex_three_octal = /^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.*$/i;
	
	// Pull out the subnet root.
	// Currently only /16 is supported.
	var bcn_root = "";
	var sn_root  = "";
	var ifn_root = "";
	if (regex_cidr16.test(bcn_subnet))
	{
		bcn_root = bcn_network.replace(/\.\d+\.\d+$/, ".");
	}
	if (regex_cidr16.test(sn_subnet))
	{
		sn_root = sn_network.replace(/\.\d+\.\d+$/, ".");
	}
	if (regex_cidr16.test(ifn_subnet))
	{
		ifn_root = ifn_network.replace(/\.\d+\.\d+$/, ".");
	}
	else if (regex_cidr24.test(ifn_subnet))
	{
		ifn_root = ifn_network.replace(/\.\d+$/, ".");
	}
	
	// Make sure the sequence number is zero-padded if it's less than 10.
	var padded_sequence  = pad(sequence, 2);
	var integer_sequence = sequence;
	    integer_sequence = integer_sequence.replace(/^0+/, '');

	$("#anvil_sequence").val(padded_sequence);
	
	// Put together some values.
	// Host names
	// Node 1
	if (!$("#anvil_node1_name").val())
	{
		var node1_name = prefix + '-a' + padded_sequence + 'n01.' + domain;
		if (!prefix)
		{
			var node1_name = 'node01.' + domain;
		}
		$("#anvil_node1_name").val(node1_name);
	}
	// Node 2
	if (!$("#anvil_node2_name").val())
	{
		var node2_name = prefix + '-a' + padded_sequence + 'n02.' + domain;
		if (!prefix)
		{
			var node2_name = 'node02.' + domain;
		}
		$("#anvil_node2_name").val(node2_name);
	}
	
	// Anvil! Name
	var anvil_cluster_name = $("#anvil_cluster_name").val();
	var anvil_name         = prefix + '-' + anvil_cluster_name + '-' + padded_sequence;
	if (!prefix)
	{
		var anvil_name = anvil_cluster_name + '-' + padded_sequence;
	}
	if (!$("#anvil_name").val())
	{
		$("#anvil_name").val(anvil_name);
	}
	
	// Switch 1
	var switch1_name = prefix + '-switch01.' + domain;
	if (!prefix)
	{
		var switch1_name = 'switch01.' + domain;
	}
	if (!$("#anvil_switch1_name").val())
	{
		$("#anvil_switch1_name").val(switch1_name);
	}
	// Switch 2
	var switch2_name = prefix + '-switch02.' + domain;
	if (!prefix)
	{
		var switch2_name = 'switch02.' + domain;
	}
	if (!$("#anvil_switch2_name").val())
	{
		$("#anvil_switch2_name").val(switch2_name);
	}
	
	// It's possible that there are two or four PDUs. If four, we set the
	// names to pdu1a, pdu1b, pdu2a and pdu2b. If only two, the host names
	// will be pdu01 and pdu02.
	var pdu4 = $("#anvil_pdu4_name").val();
	if (pdu4 != undefined)
	{
		//alert('Four PDUs: ['+pdu4+']');
		// PDU 1
		var pdu1_name = prefix + '-pdu1a.' + domain;
		if (!prefix)
		{
			var pdu1_name = 'pdu1a.' + domain;
		}
		if (!$("#anvil_pdu1_name").val())
		{
			$("#anvil_pdu1_name").val(pdu1_name);
		}
		// PDU 2
		var pdu2_name = prefix + '-pdu1b.' + domain;
		if (!prefix)
		{
			var pdu2_name = 'pdu1b.' + domain;
		}
		if (!$("#anvil_pdu2_name").val())
		{
			$("#anvil_pdu2_name").val(pdu2_name);
		}
		// PDU 3
		var pdu3_name = prefix + '-pdu2a.' + domain;
		if (!prefix)
		{
			var pdu3_name = 'pdu2a.' + domain;
		}
		if (!$("#anvil_pdu3_name").val())
		{
			$("#anvil_pdu3_name").val(pdu3_name);
		}
		// PDU 4
		var pdu4_name = prefix + '-pdu2b.' + domain;
		if (!prefix)
		{
			var pdu4_name = 'pdu2b.' + domain;
		}
		if (!$("#anvil_pdu4_name").val())
		{
			$("#anvil_pdu4_name").val(pdu4_name);
		}
	}
	else
	{
		//alert('Two PDUs: ['+pdu4+']');
		// PDU 1
		var pdu1_name = prefix + '-pdu01.' + domain;
		if (!prefix)
		{
			var pdu1_name = 'pdu01.' + domain;
		}
		if (!$("#anvil_pdu1_name").val())
		{
			$("#anvil_pdu1_name").val(pdu1_name);
		}
		// PDU 2
		var pdu2_name = prefix + '-pdu02.' + domain;
		if (!prefix)
		{
			var pdu2_name = 'pdu02.' + domain;
		}
		if (!$("#anvil_pdu2_name").val())
		{
			$("#anvil_pdu2_name").val(pdu2_name);
		}
	}
	// UPS 1
	var ups1_name = prefix + '-ups01.' + domain;
	if (!prefix)
	{
		var ups1_name = 'ups01.' + domain;
	}
	if (!$("#anvil_ups1_name").val())
	{
		$("#anvil_ups1_name").val(ups1_name);
	}
	// UPS 2
	var ups2_name = prefix + '-ups02.' + domain;
	if (!prefix)
	{
		var ups2_name = 'ups02.' + domain;
	}
	if (!$("#anvil_ups2_name").val())
	{
		$("#anvil_ups2_name").val(ups2_name);
	}
	// PTS 1
	var pts1_name = prefix + '-pts01.' + domain;
	if (!prefix)
	{
		var pts1_name = 'pts01.' + domain;
	}
	if (!$("#anvil_pts1_name").val())
	{
		$("#anvil_pts1_name").val(pts1_name);
	}
	// PTS 2
	var pts2_name = prefix + '-pts02.' + domain;
	if (!prefix)
	{
		var pts2_name = 'pts02.' + domain;
	}
	if (!$("#anvil_pts2_name").val())
	{
		$("#anvil_pts2_name").val(pts2_name);
	}
	// NTP doesn't have a name section (yet?), only IP.
	// NTP 1
	var ntp1_name = prefix + '-ntp01.' + domain;
	if (!prefix)
	{
		var ntp1_name = 'ntp01.' + domain;
	}
	if (!$("#anvil_ntp1_name").val())
	{
		$("#anvil_ntp1_name").val(ntp1_name);
	}
	// NTP 2
	var ntp2_name = prefix + '-ntp02.' + domain;
	if (!prefix)
	{
		var ntp2_name = 'ntp02.' + domain;
	}
	if (!$("#anvil_ntp2_name").val())
	{
		$("#anvil_ntp2_name").val(ntp2_name);
	}
	// Striker 1
	var striker1_name = prefix + '-striker01.' + domain;
	if (!prefix)
	{
		var striker1_name = 'striker01.' + domain;
	}
	if (!$("#anvil_striker1_name").val())
	{
		$("#anvil_striker1_name").val(striker1_name);
	}
	// Striker 2
	var striker2_name = prefix + '-striker02.' + domain;
	if (!prefix)
	{
		var striker2_name = 'striker02.' + domain;
	}
	if (!$("#anvil_striker2_name").val())
	{
		$("#anvil_striker2_name").val(striker2_name);
	}
	
	// Set the PDU outlet numbers
	if (pdu4 != undefined)
	{
		//alert('Four PDUs: ['+pdu4+']');
		// Four PDU configuration, which is much harder to predict what
		// outlets will be used. So for now, we do nothing.
	}
	else
	{
		//alert('Two PDUs: ['+pdu4+'], integer_sequence: ['+integer_sequence+']');
		// Two PDU configuration, both PDUs will be used for both
		// nodes and we can easily(ish) predict what outlets to use.
		var remainder = (integer_sequence % 4);
		if ((remainder == 1) || (!integer_sequence))
		{
			if (!$("#anvil_node1_pdu1_outlet").val())
			{
				$("#anvil_node1_pdu1_outlet").val(1);
			}
			if (!$("#anvil_node1_pdu2_outlet").val())
			{
				$("#anvil_node1_pdu2_outlet").val(1);
			}
			if (!$("#anvil_node2_pdu1_outlet").val())
			{
				$("#anvil_node2_pdu1_outlet").val(2);
			}
			if (!$("#anvil_node2_pdu2_outlet").val())
			{
				$("#anvil_node2_pdu2_outlet").val(2);
			}
		}
		else if (remainder == 2)
		{
			if (!$("#anvil_node1_pdu1_outlet").val())
			{
				$("#anvil_node1_pdu1_outlet").val(3);
			}
			if (!$("#anvil_node1_pdu2_outlet").val())
			{
				$("#anvil_node1_pdu2_outlet").val(3);
			}
			if (!$("#anvil_node2_pdu1_outlet").val())
			{
				$("#anvil_node2_pdu1_outlet").val(4);
			}
			if (!$("#anvil_node2_pdu2_outlet").val())
			{
				$("#anvil_node2_pdu2_outlet").val(4);
			}
		}
		else if (remainder == 3)
		{
			if (!$("#anvil_node1_pdu1_outlet").val())
			{
				$("#anvil_node1_pdu1_outlet").val(5);
			}
			if (!$("#anvil_node1_pdu2_outlet").val())
			{
				$("#anvil_node1_pdu2_outlet").val(5);
			}
			if (!$("#anvil_node2_pdu1_outlet").val())
			{
				$("#anvil_node2_pdu1_outlet").val(6);
			}
			if (!$("#anvil_node2_pdu2_outlet").val())
			{
				$("#anvil_node2_pdu2_outlet").val(6);
			}
		}
		else if (remainder == 0)
		{
			if (!$("#anvil_node1_pdu1_outlet").val())
			{
				$("#anvil_node1_pdu1_outlet").val(7);
			}
			if (!$("#anvil_node1_pdu2_outlet").val())
			{
				$("#anvil_node1_pdu2_outlet").val(7);
			}
			if (!$("#anvil_node2_pdu1_outlet").val())
			{
				$("#anvil_node2_pdu1_outlet").val(8);
			}
			if (!$("#anvil_node2_pdu2_outlet").val())
			{
				$("#anvil_node2_pdu2_outlet").val(8);
			}
		}
	}
	
	// IPs; *if* prefixes are passed.
	// BCN
	var third = integer_sequence * 10;
	//alert('bcn_root: ['+bcn_root+']');
	if (regex_two_octal.test(bcn_root))
	{
		//alert('bcn_subnet: ['+bcn_subnet+']');
		// IPMI third octal
		var ipmi_third = third + 1;
		//alert('ipmi_third: ['+ipmi_third+']');
		
		// Node 1
		var node1_bcn_ip  = bcn_root + '.' + third + '.' + 1;
		    node1_bcn_ip  = node1_bcn_ip.replace(/\.\./g, ".");
		var node1_ipmi_ip = bcn_root + '.' + ipmi_third + '.' + 1;
		    node1_ipmi_ip = node1_ipmi_ip.replace(/\.\./g, ".");
		    
		// Make sure the generated IPs are sane.
		if (regex_ipv4.test(node1_bcn_ip))
		{
			if (!$("#anvil_node1_bcn_ip").val())
			{
				$("#anvil_node1_bcn_ip").val(node1_bcn_ip);
			}
		}
		if (regex_ipv4.test(node1_ipmi_ip))
		{
			if (!$("#anvil_node1_ipmi_ip").val())
			{
				$("#anvil_node1_ipmi_ip").val(node1_ipmi_ip);
			}
		}
		//alert('node1_ipmi_ip: ['+node1_ipmi_ip+']');
		
		// Node 2
		var node2_bcn_ip  = bcn_root + '.' + third + '.' + 2;
		    node2_bcn_ip  = node2_bcn_ip.replace(/\.\./g, ".");
		var node2_ipmi_ip = bcn_root + '.' + ipmi_third + '.' + 2;
		    node2_ipmi_ip = node2_ipmi_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node2_bcn_ip))
		{
			if (!$("#anvil_node2_bcn_ip").val())
			{
				$("#anvil_node2_bcn_ip").val(node2_bcn_ip);
			}
		}
		if (regex_ipv4.test(node2_ipmi_ip))
		{
			if (!$("#anvil_node2_ipmi_ip").val())
			{
				$("#anvil_node2_ipmi_ip").val(node2_ipmi_ip);
			}
		}
		
		// Switches
		var switch1_ip = bcn_root + '.1.' + 1;
		    switch1_ip = switch1_ip.replace(/\.\./g, ".");
		var switch2_ip = bcn_root + '.1.' + 2;
		    switch2_ip = switch2_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(switch1_ip))
		{
			if (!$("#anvil_switch1_ip").val())
			{
				$("#anvil_switch1_ip").val(switch1_ip);
			}
		}
		if (regex_ipv4.test(switch2_ip))
		{
			if (!$("#anvil_switch2_ip").val())
			{
				$("#anvil_switch2_ip").val(switch2_ip);
			}
		}
		
		// PDUs
		var pdu1_ip = bcn_root + '.2.' + 1;
		    pdu1_ip = pdu1_ip.replace(/\.\./g, ".");
		var pdu2_ip = bcn_root + '.2.' + 2;
		    pdu2_ip = pdu2_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(pdu1_ip))
		{
			if (!$("#anvil_pdu1_ip").val())
			{
				$("#anvil_pdu1_ip").val(pdu1_ip);
			}
		}
		if (regex_ipv4.test(pdu2_ip))
		{
			if (!$("#anvil_pdu2_ip").val())
			{
				$("#anvil_pdu2_ip").val(pdu2_ip);
			}
		}
		
		// UPSes
		var ups1_ip = bcn_root + '.3.' + 1;
		    ups1_ip = ups1_ip.replace(/\.\./g, ".");
		var ups2_ip = bcn_root + '.3.' + 2;
		    ups2_ip = ups2_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(ups1_ip))
		{
			if (!$("#anvil_ups1_ip").val())
			{
				$("#anvil_ups1_ip").val(ups1_ip);
			}
		}
		if (regex_ipv4.test(ups2_ip))
		{
			if (!$("#anvil_ups2_ip").val())
			{
				$("#anvil_ups2_ip").val(ups2_ip);
			}
		}
		
		// PTSes
		var pts1_ip = bcn_root + '.5.' + 1;
		    pts1_ip = pts1_ip.replace(/\.\./g, ".");
		var pts2_ip = bcn_root + '.5.' + 2;
		    pts2_ip = pts2_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(pts1_ip))
		{
			if (!$("#anvil_pts1_ip").val())
			{
				$("#anvil_pts1_ip").val(pts1_ip);
			}
		}
		if (regex_ipv4.test(pts2_ip))
		{
			if (!$("#anvil_pts2_ip").val())
			{
				$("#anvil_pts2_ip").val(pts2_ip);
			}
		}
		
		// NTP doesn't have a name section, so for now, the input field doesn't use '_ip'
		// NTPes
		var ntp1_ip = bcn_root + '.6.' + 1;
		    ntp1_ip = ntp1_ip.replace(/\.\./g, ".");
		var ntp2_ip = bcn_root + '.6.' + 2;
		    ntp2_ip = ntp2_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(ntp1_ip))
		{
// 			if (!$("#anvil_ntp1_ip").val())
// 			{
// 				$("#anvil_ntp1_ip").val(ntp1_ip);
// 			}
			if (!$("#anvil_ntp1").val())
			{
				$("#anvil_ntp1").val(ntp1_ip);
			}
		}
		if (regex_ipv4.test(ntp2_ip))
		{
// 			if (!$("#anvil_ntp2_ip").val())
// 			{
// 				$("#anvil_ntp2_ip").val(ntp2_ip);
// 			}
			if (!$("#anvil_ntp2").val())
			{
				$("#anvil_ntp2").val(ntp2_ip);
			}
		}
		
		// Striker Dashboards
		var striker1_bcn_ip = bcn_root + '.4.' + 1;
		    striker1_bcn_ip = striker1_bcn_ip.replace(/\.\./g, ".");
		var striker2_bcn_ip = bcn_root + '.4.' + 2;
		    striker2_bcn_ip = striker2_bcn_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(striker1_bcn_ip))
		{
			if (!$("#anvil_striker1_bcn_ip").val())
			{
				$("#anvil_striker1_bcn_ip").val(striker1_bcn_ip);
			}
		}
		if (regex_ipv4.test(striker2_bcn_ip))
		{
			if (!$("#anvil_striker2_bcn_ip").val())
			{
				$("#anvil_striker2_bcn_ip").val(striker2_bcn_ip);
			}
		}
	}
	// SN
	//alert('sn_root: ['+sn_root+']');
	if (regex_two_octal.test(sn_root))
	{
		// Node 1
		var node1_sn_ip = sn_root + '.' + third + '.' + 1;
		    node1_sn_ip = node1_sn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node1_sn_ip))
		{
			if (!$("#anvil_node1_sn_ip").val())
			{
				$("#anvil_node1_sn_ip").val(node1_sn_ip);
			}
		}
		
		// Node 2
		var node2_sn_ip = sn_root + '.' + third + '.' + 2;
		    node2_sn_ip = node2_sn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node2_sn_ip))
		{
			if (!$("#anvil_node2_sn_ip").val())
			{
				$("#anvil_node2_sn_ip").val(node2_sn_ip);
			}
		}
	}
	// IFN
	//alert('ifn_root: ['+ifn_root+']');
	if (regex_two_octal.test(ifn_root))
	{
		// Node 1
		var node1_ifn_ip = ifn_root + '.' + third + '.' + 1;
		    node1_ifn_ip = node1_ifn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node1_ifn_ip))
		{
			if (!$("#anvil_node1_ifn_ip").val())
			{
				$("#anvil_node1_ifn_ip").val(node1_ifn_ip);
			}
		}
		
		// Node 2
		var node2_ifn_ip = ifn_root + '.' + third + '.' + 2;
		    node2_ifn_ip = node2_ifn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node2_ifn_ip))
		{
			if (!$("#anvil_node2_ifn_ip").val())
			{
				$("#anvil_node2_ifn_ip").val(node2_ifn_ip);
			}
		}
		
		// Striker Dashboards
		var striker1_ifn_ip = ifn_root + '.4.' + 1;
		    striker1_ifn_ip = striker1_ifn_ip.replace(/\.\./g, ".");
		var striker2_ifn_ip = ifn_root + '.4.' + 2;
		    striker2_ifn_ip = striker2_ifn_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(striker1_ifn_ip))
		{
			if (!$("#anvil_striker1_ifn_ip").val())
			{
				$("#anvil_striker1_ifn_ip").val(striker1_ifn_ip);
			}
		}
		if (regex_ipv4.test(striker2_ifn_ip))
		{
			if (!$("#anvil_striker2_ifn_ip").val())
			{
				$("#anvil_striker2_ifn_ip").val(striker2_ifn_ip);
			}
		}
		
		// IFN Default Gateway
		var ifn_gateway = ifn_root + '.255.254';
		    ifn_gateway = ifn_gateway.replace(/\.\./g, ".");
		//alert('ifn_gateway: ['+ifn_gateway+']');
		if (regex_ipv4.test(ifn_gateway))
		{
			if (!$("#anvil_ifn_gateway").val())
			{
				$("#anvil_ifn_gateway").val(ifn_gateway);
			}
		}
	}
	else if (regex_three_octal.test(ifn_root))
	{
		// Node 1
		var node1_ifn_ip = ifn_root + '.' + integer_sequence + 1;
		    node1_ifn_ip = node1_ifn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node1_ifn_ip))
		{
			if (!$("#anvil_node1_ifn_ip").val())
			{
				$("#anvil_node1_ifn_ip").val(node1_ifn_ip);
			}
		}
		
		// Node 2
		var node2_ifn_ip = ifn_root + '.' + integer_sequence + 2;
		    node2_ifn_ip = node2_ifn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node2_ifn_ip))
		{
			if (!$("#anvil_node2_ifn_ip").val())
			{
				$("#anvil_node2_ifn_ip").val(node2_ifn_ip);
			}
		}
		
		// Striker Dashboards
		var striker1_ifn_ip = ifn_root + integer_sequence + 3;
		    striker1_ifn_ip = striker1_ifn_ip.replace(/\.\./g, ".");
		var striker2_ifn_ip = ifn_root + integer_sequence + 4;
		    striker2_ifn_ip = striker2_ifn_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(striker1_ifn_ip))
		{
			if (!$("#anvil_striker1_ifn_ip").val())
			{
				$("#anvil_striker1_ifn_ip").val(striker1_ifn_ip);
			}
		}
		if (regex_ipv4.test(striker2_ifn_ip))
		{
			if (!$("#anvil_striker2_ifn_ip").val())
			{
				$("#anvil_striker2_ifn_ip").val(striker2_ifn_ip);
			}
		}
		
		// IFN Default Gateway
		var ifn_gateway = ifn_root + '.254';
		    ifn_gateway = ifn_gateway.replace(/\.\./g, ".");
		if (regex_ipv4.test(ifn_gateway))
		{
			if (!$("#anvil_ifn_gateway").val())
			{
				$("#anvil_ifn_gateway").val(ifn_gateway);
			}
		}
	}

});
