#!/bin/bash
# 
# TODO: Make sure this in an EL6 release.
# TODO: Make this less stupid.
# TODO: Sign our repo and RPMs.
# TODO: Remove the 'apache' user SSH stuff once the new SSH system is better
#       tested.

# Change the following variables to suit your setup.
PASSWORD="secret"
HOSTNAME=$(hostname)
CUSTOMER="Alteeve's Niche!"
VERSION="1.1.4"
MAILSERVER="mail.alteeve.ca"
SMTPPORT="587"

clear;
echo ""
echo "##############################################################################"
echo "# AN!CDB - Alteeve's Niche! - Cluster Dashboard                              #"
echo "#                                                          Install Beginning #"
echo "##############################################################################"
echo ""
echo "What is the host name of this dashboard?"
echo -n "[$HOSTNAME] "
read NEWHOSTNAME
if [ "$NEWHOSTNAME" != "" ]; then
        HOSTNAME=$NEWHOSTNAME
fi
echo ""
echo "NOTE: The password you enter will be echoed back to you."
echo "What password do you want for the dashboard's 'admin' user? "
echo -n "[] "
read PASSWORD
echo ""
echo "What is the company or organization to use for the Dashboard password prompt?"
echo -n "[] "
read CUSTOMER
echo ""
echo "Using the following values:"
echo " - Host name: [$HOSTNAME]"
echo " - Customer:  [$CUSTOMER]"
echo " - Password:  [$PASSWORD]"
echo ""
echo "Shall I proceed? [y/N]"
read proceed
# Lower-case the answer.
proceed=${proceed,,}
if [ "$proceed" == "y" ] || [ "$proceed" == "yes" ]; then
        echo " - Beginning now.";
else
        echo " - Please re-run this script. Exiting."
        exit;
fi

echo "Adding AN!Repo."
if [ -e "/etc/yum.repos.d/an.repo" ]
then
        echo " - Already exists"
else
        curl https://alteeve.ca/repo/el6/an.repo > /etc/yum.repos.d/an.repo
        if [ -e "/etc/yum.repos.d/an.repo" ]
        then
                echo " - Added."
        else
                echo " - Failed to write: [/etc/yum.repos.d/an.repo]."
                exit
        fi
fi

yum clean all
yum -y update
yum -y install cpan perl-YAML-Tiny perl-Net-SSLeay perl-CGI fence-agents \
               syslinux openssl-devel httpd screen ccs vim mlocate wget man \
               perl-Test-Simple policycoreutils-python mod_ssl libcdio \
               perl-TermReadKey expect postfix cyrus-sasl cyrus-sasl-plain \
               tomcat6 guacd libguac-client-vnc libguac-client-ssh \
               libguac-client-rdp

# Stuff from our repo
yum -y install perl-Net-SSH2

if [ ! -e "/var/www/home" ]
then
        mkdir /var/www/home
fi
if [ ! -e "/var/www/home/archive" ]
then
        mkdir /var/www/home/archive
fi
if [ ! -e "/var/www/home/cache" ]
then
        mkdir /var/www/home/cache
fi
if [ ! -e "/var/www/home/media" ]
then
        mkdir /var/www/home/media
fi
if [ ! -e "/var/www/home/status" ]
then
        mkdir /var/www/home/status
fi
chown -R apache:apache /var/www/home

### TODO: Remove this and get selinux working ASAP.
if [ ! -e "/etc/selinux/config.anvil" ]
then
        sed -i.anvil 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
fi
if [ -e "/etc/sysconfig/network.anvil" ]
then
        sed -i "s/HOSTNAME=.*/HOSTNAME=$HOSTNAME/" /etc/sysconfig/network
else
        sed -i.anvil "s/HOSTNAME=.*/HOSTNAME=$HOSTNAME/" /etc/sysconfig/network
fi
if [ ! -e "/etc/passwd.anvil" ]
then
        sed -i.anvil 's/apache\(.*\)www:\/sbin\/nologin/apache\1www\/home:\/bin\/bash/g' /etc/passwd
fi
# If there is already a backup, just edit the customer's name
if [ -e "/etc/httpd/conf/httpd.conf.anvil" ]
then
        sed -i.anvil 's/Cluster Dashboard - .*/Striker Dashboard - $CUSTOMER/' /etc/httpd/conf/httpd.conf
else
        cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.anvil
        sed -i 's/Timeout 60/Timeout 60000/' /etc/httpd/conf/httpd.conf
        sed -i "/Directory \"\/var\/www\/cgi-bin\"/ a\    # Password login\n    AuthType Basic\n    AuthName \"Striker - $CUSTOMER\"\n    AuthUserFile /var/www/home/htpasswd\n    Require user admin" /etc/httpd/conf/httpd.conf
        sed -i "s|#</Proxy>|#</Proxy>\n<Location /guacamole/>\n    Order allow,deny\n    Allow from all\n    ProxyPass http://localhost:8080/guacamole/ max=20 flushpackets=on\n    ProxyPassReverse http://localhost:8080/guacamole/\n</Location>\nSetEnvIf Request_URI \"^/guacamole/tunnel\" dontlog\nCustomLog  /var/log/httpd/guac.log common env=!dontlog|" /etc/httpd/conf/httpd.conf
fi

if [ ! -e "/etc/tomcat6/server.xml.anvil" ]
then
        sed -i.anvil "s|Connector port=\"8080\" protocol=\"HTTP/1.1\"|Connector port=\"8080\" protocol=\"HTTP\\/1.1\"\n               URIEncoding=\"UTF-8\"|" /etc/tomcat6/server.xml
fi

if [ ! -e "/etc/ssh/sshd_config.anvil" ]
then
        # This prevents long delays logging in when the net is down.
        sed -i.anvil 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/'   /etc/ssh/sshd_config
        sed -i       's/GSSAPIAuthentication yes/#GSSAPIAuthentication yes/' /etc/ssh/sshd_config
        sed -i       's/#UseDNS yes/UseDNS no/'                              /etc/ssh/sshd_config
        /etc/init.d/sshd restart
fi


hostname $HOSTNAME

### TODO: Enable iptables support ASAP
chkconfig iptables off
chkconfig ip6tables off
chkconfig firstboot off
chkconfig iptables on
chkconfig httpd on
chkconfig acpid on

setenforce 0
/etc/init.d/ip6tables stop
/etc/init.d/httpd restart
/etc/init.d/tomcat6 restart
/etc/init.d/acpid start

if [ ! -e "/root/.ssh/id_rsa" ]
then
        ssh-keygen -t rsa -N "" -b 8191 -f ~/.ssh/id_rsa
fi
if [ ! -e "/var/www/home/.ssh/id_rsa" ]
then
        su apache -c "ssh-keygen -t rsa -N \"\" -b 8191 -f ~/.ssh/id_rsa"
fi

if [ ! -e "/etc/an" ]
then
        mkdir /etc/an
fi
if [ ! -e "/var/log/an-cdb.log" ]
then
        touch /var/log/an-cdb.log
fi
if [ ! -e "/var/log/an-mc.log" ]
then
        touch /var/log/an-mc.log
fi

# Remove the old file and recreate it in case the use changed the password.
if [ -e /var/www/home/htpasswd ]
then
        rm -f /var/www/home/htpasswd
fi
su apache -c "htpasswd -cdb /var/www/home/htpasswd admin '$PASSWORD'"
if [ ! -e "/var/www/tools/v${VERSION}.tar.gz" ]
then
        cd /root/
        wget -c https://github.com/digimer/an-cdb/archive/v${VERSION}.tar.gz
        tar -xvzf v${VERSION}.tar.gz
        rsync -av ./an-cdb-${VERSION}/html /var/www/
        rsync -av ./an-cdb-${VERSION}/cgi-bin /var/www/
        rsync -av ./an-cdb-${VERSION}/tools /var/www/
        rsync -av ./an-cdb-${VERSION}/an.conf /etc/an/
fi

# Install Guacamole
if [ -e "/etc/guacamole/noauth-config.xml" ]
then
        echo "Guacamole already installed."
else
        echo " - Verifying packages were installed."
        OK=1
        if [ -e "/var/lib/tomcat6" ]
        then
                echo "   - Tomcat installed."
        else
                echo "   - Tomcat not found."
                OK=0        
        fi
        if [ -e "/etc/rc.d/init.d/guacd" ]
        then
                echo "   - Guacamole installed."
        else
                echo "   - Guacamole not found."
                OK=0        
        fi

        if [ -e "/usr/lib64/libguac-client-vnc.so" ]
        then
                echo "   - Guacamole VNC client installed."
        else
                echo "   - Guacamole VNC client not found."
                OK=0        
        fi

        if [ -e "/usr/lib64/libguac-client-ssh.so" ]
        then
                echo "   - Guacamole SSH client installed."
        else
                echo "   - Guacamole SSH client not found."
                OK=0        
        fi

        if [ -e "/usr/lib64/libguac-client-rdp.so" ]
        then
                echo "   - Guacamole RDP client installed."
        else
                echo "   - Guacamole RDP client not found."
                OK=0        
        fi

        if [ $OK == 1 ]
        then
                echo " - Guacamole installed successfully!"
        else
                echo " - Guacamole failed to install."
                exit
        fi

        echo "Configuring Guacamole"
        if [ -e "/etc/guacamole" ]
        then
                echo " - Main configuration directory already exists"
        else
                mkdir /etc/guacamole
                if [ -e "/etc/guacamole" ]
                then
                        echo " - Main configuration directory created."
                else
                        echo " - Failed to create: [/etc/guacamole]."
                        exit
                fi
        fi

        if [ -e "/usr/share/tomcat6/.guacamole" ]
        then
                echo " - Tomcat configuration directory already exists"
        else
                mkdir -p /usr/share/tomcat6/.guacamole
                if [ -e "/usr/share/tomcat6/.guacamole" ]
                then
                        echo " - Tomcat configuration directory created."
                else
                        echo " - Failed to create: [/usr/share/tomcat6/.guacamole/]."
                        exit
                fi
        fi

        if [ -e "/var/lib/guacamole/classpath" ]
        then
                echo " - Library directory already exists"
        else
                mkdir -p /var/lib/guacamole/classpath
                if [ -e "/var/lib/guacamole/classpath" ]
                then
                        echo " - Library directory created."
                else
                        echo " - Failed to create: [/var/lib/guacamole/classpath]."
                        exit
                fi
        fi

        if [ -e "/var/lib/guacamole/classpath/guacamole-auth-noauth-0.9.2.jar" ]
        then
                echo " - noauth .jar already exists"
        else
                wget https://alteeve.ca/files/guacamole-auth-noauth-0.9.2.jar -O /var/lib/guacamole/classpath/guacamole-auth-noauth-0.9.2.jar
                if [ -e "/var/lib/guacamole/classpath/guacamole-auth-noauth-0.9.2.jar" ]
                then
                        echo " - noauth .jar downloaded."
                else
                        echo " - Failed to download or save: [/var/lib/guacamole/classpath/guacamole-auth-noauth-0.9.2.jar]."
                        exit
                fi
        fi

        echo "Downloading latest war file."
        if [ -e "/var/lib/guacamole/guacamole.war" ]
        then
                echo " - .war already downloaded."
        else
                echo " - Downloading .war file"
                wget -c https://alteeve.ca/files/guacamole-0.9.2.war -O /var/lib/guacamole/guacamole-0.9.2.war
                ln -s /var/lib/guacamole/guacamole-0.9.2.war /var/lib/guacamole/guacamole.war
        fi

        echo "Creating 'guacamole.properties'"
        if [ -e "/etc/guacamole/guacamole.properties" ]
        then
                echo " - Already exists"
        else
                cat > /etc/guacamole/guacamole.properties << EOF
# Hostname and port of guacamole proxy
guacd-hostname: localhost
guacd-port:     4822

# Location to read extra .jar's from
lib-directory:  /var/lib/guacamole/classpath

# Authentication provider class
auth-provider: net.sourceforge.guacamole.net.auth.noauth.NoAuthenticationProvider

# NoAuth properties
noauth-config: /etc/guacamole/noauth-config.xml
EOF
                if [ -e "/etc/guacamole/guacamole.properties" ]
                then
                        echo " - Created."
                else
                        echo " - Failed to write: [/etc/guacamole/guacamole.properties]."
                        exit
                fi
        fi

        echo "Creating symlinks."
        if [ -e "/var/lib/tomcat6/webapps/guacamole.war" ]
        then
                echo " - guacamole.war symlink already exists."
        else
                ln -s /var/lib/guacamole/guacamole.war /var/lib/tomcat6/webapps/
                if [ -e "/var/lib/tomcat6/webapps/guacamole.war" ]
                then
                        echo " - guacamole.war symlink created."
                else
                        echo " - Failed to create guacamole.war."
                        exit
                fi
        fi

        if [ -e "/usr/share/tomcat6/.guacamole/guacamole.properties" ]
        then
                echo " - guacamole.properties symlink already exists."
        else
                ln -s /etc/guacamole/guacamole.properties /usr/share/tomcat6/.guacamole/
                if [ -e "/usr/share/tomcat6/.guacamole/guacamole.properties" ]
                then
                        echo " - guacamole.properties symlink created."
                else
                        echo " - Failed to create guacamole.properties."
                        exit
                fi
        fi

        # Create the skeleton 'noauth-config.xml' file.
        echo "Creating base server configuration file."
        if [ -e "/etc/guacamole/noauth-config.xml" ]
        then
                echo " - Server configuration file already exists."
        else
                cat > /etc/guacamole/noauth-config.xml << EOF
<configs>
</configs>
EOF
                # This is needed to allow AN!CDB to create backups and modify the
                # config.
                chmod 777 /etc/guacamole
                chmod 666 /etc/guacamole/noauth-config.xml
                if [ -e "/etc/guacamole/noauth-config.xml" ]
                then
                        echo " - Server configuration file successfully created."
                else
                        echo " - Failed to create server configuration file."
                        exit
                fi
        fi

        echo "Configuring the daemons to start on boot."
        chkconfig tomcat6 on
        chkconfig guacd on
        echo " - Both 'guacd' and 'tomcat6' are now enabled on boot."
        /etc/init.d/tomcat6 restart
        /etc/init.d/guacd restart
        echo " - Daemons (re)started. Safe to ignore 'stop' errors above."
        echo "Guacamole install finished!"
fi

# Configure iptables.
iptables -I INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT
/etc/init.d/iptables save

chown -R apache:apache /var/www/*
chown apache:apache /var/log/an-cdb.log
chown apache:apache /var/log/an-*
chown root:apache -R /etc
chown root:apache -R /etc/an
chown root:apache -R /etc/ssh/ssh_config
chown root:apache -R /etc/hosts
chown root:root /var/www/tools/restart_tomcat6
chown root:root /var/www/tools/check_dvd
chown root:root /var/www/tools/do_dd
chown root:root /var/www/tools/call_gather-system-info
chmod 6755 /var/www/tools/check_dvd
chmod 6755 /var/www/tools/do_dd
chmod 6755 /var/www/tools/restart_tomcat6
chmod 6755 /var/www/tools/call_gather-system-info
chmod 770 /etc/an
chmod 660 /etc/an/*
chmod 664 /etc/ssh/ssh_config
chmod 664 /etc/hosts

### TODO: Make SSL default
# Instructions for adding signed certs:
# [root@an-cdb conf.d]# diff -U0 ssl.conf.original ssl.conf
# --- ssl.conf.original        2014-04-18 15:38:15.229000449 -0400
# +++ ssl.conf        2014-04-18 15:39:30.663000165 -0400
# @@ -105 +105 @@
# -SSLCertificateFile /etc/pki/tls/certs/localhost.crt
# +SSLCertificateFile /etc/pki/CA/wildcard_ssl_alteeve.ca.crt
# @@ -112 +112 @@
# -SSLCertificateKeyFile /etc/pki/tls/private/localhost.key
# +SSLCertificateKeyFile /etc/pki/CA/private/wildcard_alteeve.ca.key
# @@ -127,0 +128 @@
# +SSLCACertificateFile /etc/pki/CA/RapidSSL_CA_bundle.pem


echo ""
echo "##############################################################################"
echo "#                                                                            #"
echo "#                       Dashboard install is complete.                       #"
echo "#                                                                            #"
echo "##############################################################################"
echo ""
