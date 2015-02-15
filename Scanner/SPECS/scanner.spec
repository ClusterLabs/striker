#
# spec file for package scanner from Anvil!
#
# Copyright (c) 2015 Alteeve's Niche! Inc., Toronto, Ontario, Canada
# This software is released under the terms of the GN GPL version 2.
#
# https://alteeve.ca
#

Name:           Scanner
Version:        1.0
Release:        1.0
Summary:        System to monitor HA system resources
License:        GPL-2.0
Group:          Development/Libraries/Perl
Url:            https://alteeve.ca
#Source:         http://github.com/digimer/striker/tree/scanner/Scanner
Source:         scanner.tar.gz
PACKAGER:       Tom Legrady <tom@alteeve.ca> 
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Requires :      Class::Tiny 
Requires :      Clone
Requires :      Const::Fast
Requires :      DBI
Requires :      List::MoreUtils
Requires :      Net::SNMP
Requires :      Net::SSH2
Requires :      Proc::Background
Requires :      Term::ReadKey
Requires :      Test::Output
Requires :      XML::Simple
Requires :      YAML
BuildRequires:  perl
BuildRequires:  perl-macros

%description
'scanner' is a system-monitoring package for HA systems. On the servers
it runs the scanCore, 'scanner', which launches and monitors agents,
which report UPS, RAID, PDU, and system chassis temperatures and other
characteristics. ON the monitoring dashboard, it runs a dashboard monitor
which will attempt to resurrect failed servers when it becomes safe to
do so.

%prep
%setup -c -q -n %{name}

%build
%{__make} wrapper

%check
%{__make} test

%install
%{__make} install

%files -f %{name}.files
%defattr(-,root,root,755)
%attr(777,root,root) /var/log/striker
%doc Doc/Writing_an_agent Doc/Writing_an_agent_by_extending_existing_perl_classes.
%config /etc/striker/Config/db.conf
%config /etc/striker/Config/ipmi.conf
%config /etc/striker/Config/raid.conf
%config /etc/striker/Config/scanner.conf
%config /etc/striker/Config/snmp_apc_ups.conf
%config /etc/striker/Config/dashboard.conf
%config /etc/striker/Config/nodemonitor.conf



%changelog
