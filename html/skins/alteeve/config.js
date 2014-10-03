// Uses the 'prefix', anvil sequence and domain names to populate the rest of the form fiels.
$("#set_secondary_values").click(function(){
	var prefix     = $("#anvil_prefix").val();
	var sequence   = $("#anvil_sequence").val();
	var domain     = $("#anvil_domain").val();
	var bcn_prefix = $("#anvil_bcn_subnet_prefix").val();
	var sn_prefix  = $("#anvil_sn_subnet_prefix").val();
	var ifn_prefix = $("#anvil_ifn_subnet_prefix").val();
	
	// Make sure the sequence number is zero-padded if it's less than 10.
	sequence = pad(sequence, 2);
	$("#anvil_sequence").val(sequence);
	
	// Put together some values.
	// Host names
	var node1_name = prefix + '-a' + sequence + 'n01.' + domain;
	$("#anvil_node1_name").val(node1_name);
	var node2_name = prefix + '-a' + sequence + 'n02.' + domain;
	$("#anvil_node2_name").val(node2_name);
	
	// IPs; *if* prefixes are passed.
	if (/^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.*$/i.test(bcn_prefix))
	{
		var third = sequence;
		third = third.replace(/^0+/, '');
		third = third * 10;
		
		// Node 1
		var node1_ip = bcn_prefix + '.' + third + '.' + 1;
		node1_ip = node1_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (/^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)$/i.test(node1_ip))
		{
			$("#anvil_node1_ip").val(node1_ip);
		}
		
		// Node 2
		var node2_ip = bcn_prefix + '.' + third + '.' + 2;
		node2_ip = node2_ip.replace(/\.\./g, ".");
		// Make sure the generated IP is sane.
		if (/^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)$/i.test(node2_ip))
		{
			$("#anvil_node2_ip").val(node2_ip);
		}
	}
});
