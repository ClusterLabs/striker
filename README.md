Striker v1.1.6
=============

  This program is a "Anvil! Dashboard" designed for simple management of the
Anvil! High Availability Platform[1]. It is a simple, web-based application 
designed to be browser agnostic and tablet friendly.

  It is designed to be used by people with little computer experience. It's
goal is to provide easy and reliable use of the Anvil! and the 
highly-available servers you install on it. It puts these advanced platforms
within reach of small organizations with little to no in-house IT staff.

  Fundamentally, the dashboard provides 3 main functions;

 > a. Node and Server management
 > b. Server provisioning, management and removal
 > c. A media library for OS install and driver disks


Online Documentation
--------------------
- https://alteeve.ca/w/Striker

 
Anvil! and Server management
----------------------------

  This covers the daily care and feeding of the cluster.

  The dashboard allows users to easily power up the cluster nodes and start the
cluster stack.

  Once the cluster is up and running, the option to boot,
live-migrate, gracefully shut down and force-off virtual machines.

  Individual nodes can be withdrawn from the cluster and powered off to enable
planned maintenance and emergency service. Once service is completed, the node
can be powered back on and rejoin the cluster.

  With all Servers shut down, the dashboard can be used to cold-stop the cluster
entirely.


Server Provisioning and Removal
-------------------------------

  The dashboard allows users to create new virtual servers on the cluster.
Installation media can be added to the cluster in one of three ways;

 > a. Create an image from a DVD or CD disc mounted in the dashboard server
 > b. Upload an ISO from the user's computer/tablet
 > c. Direct download to the cluster from a website or ftp site

  Once the media is on the cluster, users can use it to create a new virtual
server. The user simply names the new Server, chooses the OS type from a drop-down
list, chooses the installation and, if needed, driver disc image, sets the
number of CPUs and the amount of RAM.

  The primary node, failover group and storage configuration is all selected
and managed automatically for the user.


  Existing virtual servers can be deleted from the cluster. Once removed, the
resources formally consumed by that Server are released back into the cluster's
resource pools, making them immediately available for use by existing or new
Servers.


Media and Resource Management for Existing Servers
--------------------------------------------------

  The dashboard allows for easy management of existing Servers. A user can "insert"
or "eject" a CD or DVD. This allows users to easily install applications that
they have on physical media.

  Existing Servers can change the number of CPUs and the amount of RAM allocated to
a virtual server. If the Server's operating system supports it, this change will be
instantly reflected in the Server. Otherwise, the changes take effect when the
client next powers off and restarts their Server.


Screenshots
-----------

![An cdb cluster stack started](https://alteeve.ca/images/0/09/An-cdb-splash.png)
![An cdb cluster stack running](https://alteeve.ca/images/d/d7/An-cdb-cluster-stack-running.png)
\*All screen shots shown here were taken in late July 2013\*

Links
-----

1. - https://alteeve.ca/w/AN!Anvil!_Tutorial_2
