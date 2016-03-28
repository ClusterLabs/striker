package AN::Tools::Web;
# 
# This module will be used to process anything to do with presenting data to a user's web browser.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Web.pm";


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

# This is presented when no access to a ScanCore database is available.
sub no_db_access
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
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

# This takes the name of a template file, the name of a template section within the file, an optional hash
# containing replacement variables to feed into the template and an optional hash containing variables to
# pass into strings, and generates a page to display formatted according to the page.
sub template
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Make sure we got a file and template name.
	if (not $parameter->{file})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0073", code => 73, file => "$THIS_FILE", line => __LINE__});
	}
	if (not $parameter->{template})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0074", code => 74, file => "$THIS_FILE", line => __LINE__});
	}
	
	my $file       = $parameter->{file};
	my $template   = $parameter->{template};
	my $replace    = $parameter->{replace}    ? $parameter->{replace}    : {};
	my $no_comment = $parameter->{no_comment} ? $parameter->{no_comment} : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "file",       value1 => $file,
		name2 => "template",   value2 => $template,
		name3 => "no_comment", value3 => $no_comment,
	}, file => $THIS_FILE, line => __LINE__});
	
	my @contents;
	my $template_file = $an->data->{path}{skins}."/".$an->data->{sys}{skin}."/".$file;
	
	# Make sure the file exists.
	if (not -e $template_file)
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0075", message_variables => { file => $template_file }, code => 75, file => "$THIS_FILE", line => __LINE__});
	}
	elsif (not -r $template_file)
	{
		my $user = getpwuid($<);
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0075", message_variables => { 
			file => $template_file,
			user => $user,
		}, code => 75, file => "$THIS_FILE", line => __LINE__});
	}
	
	# Read in the raw template.
	my $in_template = 0;
	my $shell_call  = $template_file;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
	#binmode $file_handle, ":utf8:";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "comment", value1 => $comment,
		}, file => $THIS_FILE, line => __LINE__});
		$page .= "<!-- $comment -->\n";
	}
	foreach my $string (@contents)
	{
		# Replace the '#!replace!...!#' substitution keys.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => ">> string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "comment", value1 => $comment,
		}, file => $THIS_FILE, line => __LINE__});
		$page .= "<!-- $comment -->\n";
	}
	
	return($page);
}

1;
