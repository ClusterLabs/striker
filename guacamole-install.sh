#!/bin/bash

echo "Installing Guacamole"
if [ -e "/etc/yum.repos.d/epel.repo" ]
then
	echo " - EPEL repo is already installed."
else
	echo " - Installing EPEL"
	if [ -e "/tmp/epel-release.html" ]
	then
		echo "   - Old epel-release.html' file found, removing it."
		rm -f /tmp/epel-release.html
	fi
	echo "   - Downloading latest html page."
	wget http://www.muug.mb.ca/pub/epel/6/i386/repoview/epel-release.html -O /tmp/epel-release.html

	if [ -e "/tmp/epel-release.html" ]
	then
		echo "   - Parsing epel-release.html to build URL"
		RPM=$(cat /tmp/epel-release.html |grep rpm | sed 's/.*\(epel-release-.*.noarch.rpm\).*/\1/')
		URL="http://www.muug.mb.ca/pub/epel/6/i386/$RPM"
		echo "   - Installing: $URL"
		rpm -Uvh $URL
	else
		echo "   - Failed to download EPEL latest HTML page."
		exit
	fi
	if [ -e "/etc/yum.repos.d/epel.repo" ]
	then
		echo "   - EPEL repo installed."
	else
		echo "   - EPEL repo failed to install."
		exit
	fi
fi

echo " - Installing packages (this will do nothing if already installed)"
yum -y install tomcat6 guacd libguac-client-vnc libguac-client-ssh libguac-client-rdp
echo " - Verifying packages were installed."
OK=1
if [ -e "/etc/tomcat6" ]
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
if [ -e "/var/lib/guacamole/classpath/guacamole-auth-noauth-0.8.0.jar" ]
then
	echo " - noauth .jar already exists"
else
	wget https://alteeve.ca/files/guacamole-auth-noauth-0.8.0.jar -O /var/lib/guacamole/classpath/guacamole-auth-noauth-0.8.0.jar
	if [ -e "/var/lib/guacamole/classpath/guacamole-auth-noauth-0.8.0.jar" ]
	then
		echo " - noauth .jar downloaded."
	else
		echo " - Failed to download or save: [/var/lib/guacamole/classpath/guacamole-auth-noauth-0.8.0.jar]."
		exit
	fi
fi

echo "Downloading latest war file."
if [ -e "/var/lib/guacamole/guacamole.war" ]
then
	echo " - .war already downloaded."
else
	echo " - Downloading .war file"
	if [ -e "/tmp/sf.html" ]
	then
		echo "   - Old sf.html' file found, removing it."
		rm -f /tmp/sf.html
	fi
	echo "   - Downloading latest fs html page."
	wget wget http://sourceforge.net/projects/guacamole/files/current/binary -O /tmp/sf.html

	if [ -e "/tmp/sf.html" ]
	then
		echo "   - Parsing sf.html to build URL"
		WAR=$(cat /tmp/foo.html |grep guacamole | grep "war/down" | sed 's/.*\(guacamole-0\..*\.war\)\/.*/\1/' | tr '\n' ' ' | awk '{print $1}')
		URL="http://sourceforge.net/projects/guacamole/files/current/binary/$WAR"
		echo "   - Downloading: $URL"
		wget -c $URL -O /var/lib/guacamole/$WAR
	else
		echo "   - Failed to download guacamole WAR file."
		exit
	fi
	if ls /var/lib/guacamole/guacamole-* &>/dev/null
	then
		echo "   - Guacamole $WAR downloaded successfully. Moving to 'guacamole.war'"
		mv /var/lib/guacamole/$WAR /var/lib/guacamole/guacamole.war
		if [ -e "/var/lib/guacamole/guacamole.war" ]
		then
			echo "   - Successfully moved to guacamole.war'"
		else
			echo "   - Failed to move $WAR to 'guacamole.war'"
			exit
		fi
			
	else
		echo "   - Failed to download $WAR file."
		exit
	fi
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
echo "Install finished!"

# Please now create: [/etc/guacamole/user-mapping.xml] defined for your servers.
echo '
If you are not using AN!CDB, then please modify the server configuration file:
[/etc/guacamole/noauth-config.xml] and add your servers manually.

Sample configuration:
====
<configs>
	<!-- Server: vm01-foo, listening on port: 5900 -->
	<!--Host: an-c05n01 -->
	<config name="r1server1-n01" protocol="vnc">
		<param name="hostname" value="an-c05n01" />
		<param name="port" value="5900" />
	</config>
	<!--Host: an-c05n02 -->
	<config name="r1server1-n02" protocol="vnc">
		<param name="hostname" value="an-c05n02" />
		<param name="port" value="5900" />
	</config>
	
	<!-- Server: vm02-bar, listening on port: 5901 -->
	<!--Host: an-c05n01 -->
	<config name="r2server1-n01" protocol="vnc">
		<param name="hostname" value="an-c05n01" />
		<param name="port" value="5901" />
	</config>
	<!--Host: an-c05n02 -->
	<config name="r2server1-n02" protocol="vnc">
		<param name="hostname" value="an-c05n02" />
		<param name="port" value="5901" />
	</config>
</configs>
====

Then (re)start tomcat6 and guacd.
/etc/init.d/tomcat6 restart
/etc/init.d/guacd restart
'
