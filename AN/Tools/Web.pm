package AN::Tools::Web;
# 
# This module will be used to process anything to do with presenting data to a user's web browser.
# 

use strict;
use warnings;
use Data::Dumper;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Encode;

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

# This builds an HTML select field.
sub build_select
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Required
	my $name     = $parameter->{name};
	my $options  = $parameter->{options};
	# Optional
	my $id       = $parameter->{id}       ? $parameter->{id}       : $name;
	my $sort     = $parameter->{'sort'}   ? $parameter->{'sort'}   : 1;	# Sort the entries?
	my $width    = $parameter->{width}    ? $parameter->{width}    : 0;	# 0 = let the browser set the width
	my $blank    = $parameter->{blank}    ? $parameter->{blank}    : 0;	# Add a blank/null entry?
	my $selected = $parameter->{selected} ? $parameter->{selected} : "";	# Pre-select an option?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "name",     value1 => $name, 
		name2 => "options",  value2 => $options, 
		name3 => "sort",     value3 => $sort, 
		name4 => "width",    value4 => $width, 
		name5 => "blank",    value5 => $blank, 
		name6 => "selected", value6 => $selected, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $select = "<select name=\"$name\" id=\"$id\">\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "select", value1 => $select,
	}, file => $THIS_FILE, line => __LINE__});
	if ($width)
	{
		$select = "<select name=\"$name\" id=\"$id\" style=\"width: ${width}px;\">\n";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "select", value1 => $select,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Insert a blank line.
	if ($blank)
	{
		$select .= "<option value=\"\"></option>\n";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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

# This reads in data from CGI
sub get_cgi
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Make sure we have an array reference of variables to read.
	my $variables = ref($parameter->{variables}) eq "ARRAY" ? $parameter->{variables} : "";
	if (not $variables)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0069", code => 69, file => "$THIS_FILE", line => __LINE__});
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
		
		# I auto-select the 'anvil' variable if only one is checked. Because of this, I don't want
		# to overwrite the empty CGI value. This prevents that.
		if (($variable eq "anvil") && ($an->data->{cgi}{anvil}))
		{
			$an->data->{sys}{cgi_string} .= "$variable=$an->data->{cgi}{$variable}&";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "variable", value1 => $variable, 
				name2 => "value",    value2 => $an->data->{cgi}{$variable},
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		
		# Avoid "uninitialized" warning messages.
		$an->data->{cgi}{$variable} = "";
		if (defined $cgi->param($variable))
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi->param($variable)", value1 => $cgi->param($variable)
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
			
			# Add this to the sys::cgi_string
			$an->data->{sys}{cgi_string} .= "$variable=".$an->data->{cgi}{$variable}."&";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::cgi_string", value1 => $an->data->{cgi}{cgi_string}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Log the variable, if set
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::${variable}", value1 => $an->data->{cgi}{$variable}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{$variable})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::$variable", value1 => $an->data->{cgi}{$variable},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	# Clear the final '&' from sys::cgi_string
	$an->data->{sys}{cgi_string} =~ s/&$//;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::cgi_string", value1 => $an->data->{cgi}{cgi_string}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This returns a "More Info" link, *if* 'sys::disable_links' is not set.
sub more_info_link
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# TODO: Error if this is not set.
	my $url  = $parameter->{url} ? $parameter->{url} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "url", value1 => $url,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $link = $an->Web->template({file => "web.html", template => "more-info-link", replace => { url => $url }, no_comment => 1});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "link",               value1 => $link,
		name2 => "sys::disable_links", value2 => $an->data->{sys}{disable_links},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{disable_links})
	{
		$link = "&nbsp;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "link", value1 => $link,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
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
