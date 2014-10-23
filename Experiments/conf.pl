
my $conf = { clusters => { a => 1, b => 2, c => 3 } };

my @cluster_name;
foreach my $cluster (keys %{$conf->{clusters}})
{
	push @cluster_name, $cluster;
}
if (@cluster_name == 1)
{
	$conf->{cgi}{cluster} = $cluster_name[0];
}


print scalar @cluster_name, " clusters found.\n";
