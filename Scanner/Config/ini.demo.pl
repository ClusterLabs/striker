#!/usr/bin/perl 
# ini.demo.pl --- Demo reading .ini file
# Author: Tom Legrady <legrady@legrady-iMac>
# Created: 20 Nov 2014
# Version: 0.01

use warnings;
use strict;

use Config::Tiny;
use Data::Dumper;

my $cfg = Config::Tiny->read( 'db.ini' );
print Data::Dumper->Dump( [$cfg], ['cfg'] );


__END__

=head1 NAME

ini.demo.pl - Describe the usage of script briefly

=head1 SYNOPSIS

ini.demo.pl [options] args

      -opt --long      Option description

=head1 DESCRIPTION

Stub documentation for ini.demo.pl, 

=head1 AUTHOR

Tom Legrady, E<lt>legrady@legrady-iMacE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Tom Legrady

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
