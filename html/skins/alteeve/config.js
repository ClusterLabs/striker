// Uses the 'prefix', anvil sequence and domain names to populate the rest of the form fiels.
$("#set_secondary_values").click(function(){
	var prefix     = $("#anvil_prefix").val();
	var sequence   = $("#anvil_sequence").val();
	var domain     = $("#anvil_domain").val();
	var bcn_prefix = $("#anvil_bcn_subnet_prefix").val();
	var sn_prefix  = $("#anvil_sn_subnet_prefix").val();
	var ifn_prefix = $("#anvil_ifn_subnet_prefix").val();
	var regex_ipv4 = /^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)$/i;
	
	// Make sure the sequence number is zero-padded if it's less than 10.
	sequence = pad(sequence, 2);
	$("#anvil_sequence").val(sequence);
	
	// Put together some values.
	// Host names
	// Node 1
	var node1_name = prefix + '-a' + sequence + 'n01.' + domain;
	$("#anvil_node1_name").val(node1_name);
	// Node 2
	var node2_name = prefix + '-a' + sequence + 'n02.' + domain;
	$("#anvil_node2_name").val(node2_name);
	// Anvil! Name
	var anvil_cluster_name = $("#anvil_cluster_name").val();
	var anvil_name         = prefix + '-' + anvil_cluster_name + '-' + sequence;
	$("#anvil_name").val(anvil_name);
	
	// Switch 1
	var switch1_name = prefix + '-switch01.' + domain;
	$("#anvil_switch1_name").val(switch1_name);
	// Switch 2
	var switch2_name = prefix + '-switch02.' + domain;
	$("#anvil_switch2_name").val(switch2_name);
	// PDU 1
	var pdu1_name = prefix + '-pdu01.' + domain;
	$("#anvil_pdu1_name").val(pdu1_name);
	// PDU 2
	var pdu2_name = prefix + '-pdu02.' + domain;
	$("#anvil_pdu2_name").val(pdu2_name);
	// UPS 1
	var ups1_name = prefix + '-ups01.' + domain;
	$("#anvil_ups1_name").val(ups1_name);
	// UPS 2
	var ups2_name = prefix + '-ups02.' + domain;
	$("#anvil_ups2_name").val(ups2_name);
	// Striker 1
	var striker1_name = prefix + '-striker01.' + domain;
	$("#anvil_striker1_name").val(striker1_name);
	// Striker 2
	var striker2_name = prefix + '-striker02.' + domain;
	$("#anvil_striker2_name").val(striker2_name);
	
	// IPs; *if* prefixes are passed.
	// BCN
	var third = sequence;
	    third = third.replace(/^0+/, '');
	    third = third * 10;
	if (/^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.*$/i.test(bcn_prefix))
	{
		// IPMI third octal
		var ipmi_third = third + 1;
		
		// Node 1
		var node1_bcn_ip  = bcn_prefix + '.' + third + '.' + 1;
		    node1_bcn_ip  = node1_bcn_ip.replace(/\.\./g, ".");
		var node1_ipmi_ip = bcn_prefix + '.' + ipmi_third + '.' + 1;
		    node1_ipmi_ip = node1_ipmi_ip.replace(/\.\./g, ".");
		    
		// Make sure the generated IPs are sane.
		if (regex_ipv4.test(node1_bcn_ip))
		{
			node1_bcn_ip = node1_bcn_ip + '/255.255.0.0';
			$("#anvil_node1_bcn_ip").val(node1_bcn_ip);
		}
		if (regex_ipv4.test(node1_ipmi_ip))
		{
			node1_ipmi_ip = node1_ipmi_ip + '/255.255.0.0';
			$("#anvil_node1_ipmi_ip").val(node1_ipmi_ip);
		}
		
		// Node 2
		var node2_bcn_ip = bcn_prefix + '.' + third + '.' + 2;
		    node2_bcn_ip = node2_bcn_ip.replace(/\.\./g, ".");
		var node2_ipmi_ip = bcn_prefix + '.' + ipmi_third + '.' + 1;
		    node2_ipmi_ip = node2_ipmi_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node2_bcn_ip))
		{
			node2_bcn_ip = node2_bcn_ip + '/255.255.0.0';
			$("#anvil_node2_bcn_ip").val(node2_bcn_ip);
		}
		if (regex_ipv4.test(node2_ipmi_ip))
		{
			node2_ipmi_ip = node2_ipmi_ip + '/255.255.0.0';
			$("#anvil_node2_ipmi_ip").val(node2_ipmi_ip);
		}
		
		// Switches
		var switch1_ip = bcn_prefix + '.1.' + 1;
		    switch1_ip = switch1_ip.replace(/\.\./g, ".");
		var switch2_ip = bcn_prefix + '.1.' + 1;
		    switch2_ip = switch2_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(switch1_ip))
		{
			switch1_ip = switch1_ip + '/255.255.0.0';
			$("#anvil_switch1_ip").val(switch1_ip);
		}
		if (regex_ipv4.test(switch2_ip))
		{
			switch2_ip = switch2_ip + '/255.255.0.0';
			$("#anvil_switch2_ip").val(switch2_ip);
		}
		
		// PDUs
		var pdu1_ip = bcn_prefix + '.2.' + 1;
		    pdu1_ip = pdu1_ip.replace(/\.\./g, ".");
		var pdu2_ip = bcn_prefix + '.2.' + 1;
		    pdu2_ip = pdu2_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(pdu1_ip))
		{
			pdu1_ip = pdu1_ip + '/255.255.0.0';
			$("#anvil_pdu1_ip").val(pdu1_ip);
		}
		if (regex_ipv4.test(pdu2_ip))
		{
			pdu2_ip = pdu2_ip + '/255.255.0.0';
			$("#anvil_pdu2_ip").val(pdu2_ip);
		}
		
		// UPSes
		var ups1_ip = bcn_prefix + '.3.' + 1;
		    ups1_ip = ups1_ip.replace(/\.\./g, ".");
		var ups2_ip = bcn_prefix + '.3.' + 1;
		    ups2_ip = ups2_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(ups1_ip))
		{
			ups1_ip = ups1_ip + '/255.255.0.0';
			$("#anvil_ups1_ip").val(ups1_ip);
		}
		if (regex_ipv4.test(ups2_ip))
		{
			ups2_ip = ups2_ip + '/255.255.0.0';
			$("#anvil_ups2_ip").val(ups2_ip);
		}
		
		// Striker Dashboards
		var striker1_bcn_ip = bcn_prefix + '.4.' + 1;
		    striker1_bcn_ip = striker1_bcn_ip.replace(/\.\./g, ".");
		var striker2_bcn_ip = bcn_prefix + '.4.' + 1;
		    striker2_bcn_ip = striker2_bcn_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(striker1_bcn_ip))
		{
			striker1_bcn_ip = striker1_bcn_ip + '/255.255.0.0';
			$("#anvil_striker1_bcn_ip").val(striker1_bcn_ip);
		}
		if (regex_ipv4.test(striker2_bcn_ip))
		{
			striker2_bcn_ip = striker2_bcn_ip + '/255.255.0.0';
			$("#anvil_striker2_bcn_ip").val(striker2_bcn_ip);
		}
	}
	// SN
	if (/^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.*$/i.test(sn_prefix))
	{
		// Node 1
		var node1_sn_ip = sn_prefix + '.' + third + '.' + 1;
		    node1_sn_ip = node1_sn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node1_sn_ip))
		{
			node1_sn_ip = node1_sn_ip + '/255.255.0.0';
			$("#anvil_node1_sn_ip").val(node1_sn_ip);
		}
		
		// Node 2
		var node2_sn_ip = sn_prefix + '.' + third + '.' + 2;
		    node2_sn_ip = node2_sn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node2_sn_ip))
		{
			node2_sn_ip = node2_sn_ip + '/255.255.0.0';
			$("#anvil_node2_sn_ip").val(node2_sn_ip);
		}
	}
	// IFN
	if (/^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.*$/i.test(ifn_prefix))
	{
		// Node 1
		var node1_ifn_ip = ifn_prefix + '.' + third + '.' + 1;
		    node1_ifn_ip = node1_ifn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node1_ifn_ip))
		{
			node1_ifn_ip = node1_ifn_ip + '/255.255.0.0';
			$("#anvil_node1_ifn_ip").val(node1_ifn_ip);
		}
		
		// Node 2
		var node2_ifn_ip = ifn_prefix + '.' + third + '.' + 2;
		    node2_ifn_ip = node2_ifn_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (regex_ipv4.test(node2_ifn_ip))
		{
			node2_ifn_ip = node2_ifn_ip + '/255.255.0.0';
			$("#anvil_node2_ifn_ip").val(node2_ifn_ip);
		}
		
		// Striker Dashboards
		var striker1_ifn_ip = ifn_prefix + '.4.' + 1;
		    striker1_ifn_ip = striker1_ifn_ip.replace(/\.\./g, ".");
		var striker2_ifn_ip = ifn_prefix + '.4.' + 1;
		    striker2_ifn_ip = striker2_ifn_ip.replace(/\.\./g, ".");
		if (regex_ipv4.test(striker1_ifn_ip))
		{
			striker1_ifn_ip = striker1_ifn_ip + '/255.255.0.0';
			$("#anvil_striker1_ifn_ip").val(striker1_ifn_ip);
		}
		if (regex_ipv4.test(striker2_ifn_ip))
		{
			striker2_ifn_ip = striker2_ifn_ip + '/255.255.0.0';
			$("#anvil_striker2_ifn_ip").val(striker2_ifn_ip);
		}
		
		// IFN Default Gateway
		var ifn_gateway = ifn_prefix + '.255.254';
		    ifn_gateway = ifn_gateway.replace(/\.\./g, ".");
		if (regex_ipv4.test(ifn_gateway))
		{
			$("#anvil_ifn_gateway").val(ifn_gateway);
		}
	}
});
