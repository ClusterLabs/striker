# ----------------------------------------------------------------------
# 8 Modules from RPMs


yum install perl-Time-HiRes.x86_64
yum install perl-Sub-Exporter.noarch
yum install perl-Clone.x86_64 
yum install perl-TermReadKey.x86_64 
yum install perl-DBI.x86_64
yum install perl-List-MoreUtils.x86_64 
yum install perl-XML-Simple.noarch
yum install perl-Test-Output

# ----------------------------------------------------------------------
# Local modules

# /root/rpmbuild/RPMS/x86_64:
#
rpm -ivh ./perl-DBD-Pg-3.4.2-1.el6.x86_64.rpm
rpm -ivh ./perl-DBD-Pg-debuginfo-3.4.2-1.el6.x86_64.rpm
rpm -ihv ./perl-Net-SSH2-0.53-1.el6.x86_64.rpm
rpm -ihv ./perl-Net-SSH2-debuginfo-0.53-1.el6.x86_64.rpm
rpm -ihb ./perl-Devel-GlobalDestruction-XS-0.01-1.el6.x86_64.rpm

# /root/noarch:
#

rpm -ivh ./perl-Const-Fast-0.006-1.el6.noarch.rpm
rpm -ivh ./perl-Exporter-Tiny-0.042-1.el6.noarch.rpm
rpm -ivh ./perl-Sub-Exporter-Progressive-0.001011-1.el6.noarch.rpm
rpm -ivh ./perl-Proc-Background-1.10-1.el6.noarch.rpm
rpm -ihv ./perl-Devel-GlobalDestruction-0.13-1.el6.noarch.rpm
rpm -ihv ./perl-Class-Tiny-1.000-1.rhel6.noarch.rpm
# ----------------------------------------------------------------------
# SNMP components 
#
yum install perl-Digest-SHA1.x86_64
yum install perl-Digest-SHA.x86_64
yum install perl-Digest-HMAC.noarch

rpm -ihv perl-Crypt-CBC-2.33-1.el6.noarch.rpm
rpm -ihv perl-Crypt-DES-2.07-1.el6.x86_64.rpm
rpm -ihv perl-Crypt-DES-debuginfo-2.07-1.el6.x86_64.rpm
rpm -ihv perl-Net-SNMP-v6.0.1-1.el6.noarch.rpm
