package AN::Tools::ScanCore;
# 
# This module contains methods use to get data from the ScanCore database.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "ScanCore.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Storage->new()\n";
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

# Get a list of Anvil! Owners as an array of hash references
sub get_owners
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $query = "
SELECT 
    owner_uuid, 
    owner_name, 
    owner_note, 
    modified_date 
FROM 
    owners
;";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $owner_uuid    = $row->[0];
		my $owner_name    = $row->[1];
		my $owner_note    = $row->[2] ? $row->[2] : "";
		my $modified_date = $row->[3];
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "owner_uuid",    value1 => $owner_uuid, 
			name2 => "owner_name",    value2 => $owner_name, 
			name3 => "owner_note",    value3 => $owner_note, 
			name4 => "modified_date", value4 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			owner_uuid	=>	$owner_uuid,
			owner_name	=>	$owner_name, 
			owner_note	=>	$owner_note, 
			modified_date	=>	$modified_date, 
		};
	}
	
	return($return);
}

1;
