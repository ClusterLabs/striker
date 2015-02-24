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
BuildArch:      x86_64
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Requires :      perl-Class-Tiny 
Requires :      perl-Clone
Requires :      perl-Const-Fast
Requires :      perl-DBI
Requires :      perl-List-MoreUtils
Requires :      perl-Net-SNMP
Requires :      perl-Net-SSH2
Requires :      perl-Proc-Background
Requires :      perl-TermReadKey
Requires :      perl-Test-Output
Requires :      perl-XML-Simple
Requires :      perl-YAML
BuildRequires:  perl

%description
'scanner' is a system-monitoring package for HA systems. On the servers
it runs the scanCore, 'scanner', which launches and monitors agents,
which report UPS, RAID, PDU, and system chassis temperatures and other
characteristics. ON the monitoring dashboard, it runs a dashboard monitor
which will attempt to resurrect failed servers when it becomes safe to
do so.

%define _binaries_in_noarch_packages_terminate_build   0
%define _unpackaged_files_terminate_build 0
   
   
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
%dir /var/log/striker
%dir /shared/status
%attr(777,root,root) /var/log/striker
%attr(777,root,root) /shared/status
%doc Docs/Writing_an_agent Docs/Writing_an_agent_by_extending_existing_perl_classes.
%config /etc/striker/Config/db.conf
%config /etc/striker/Config/ipmi.conf
%config /etc/striker/Config/raid.conf
%config /etc/striker/Config/scanner.conf
%config /etc/striker/Config/snmp_apc_ups.conf
%config /etc/striker/Config/dashboard.conf
%config /etc/striker/Config/nodemonitor.conf



%changelog
