AN!CDB v1.0.0
=============

  This program is a "Cluster Dashboard" designed for simple management of
AN!Clusters[1]. It is a simple, web-based application designed to be browser
agnostic and tablet friendly.

  It is designed to be used by people with little computer experience. It's
goal is to easy and reliable use of VM clusters by small companies and
organizations with little to no in-house IT staff.

  Fundamentally, the dashboard provides 3 main functions;

 > a. Cluster and VM management
 > b. VM provisioning and removal
 > c. Media and resource management for existing VMs


Online Documentation
--------------------
- https://alteeve.ca/w/AN!CDB_-_Cluster_Dashboard

 
Cluster and VM management
-------------------------

  This covers the daily care and feeding of the cluster.

  The dashboard allows users to easily power up the cluster nodes and start the
cluster stack.

  Once the cluster is up and running, the option to boot,
live-migrate, gracefully shut down and force-off virtual machines.

  Individual nodes can be withdrwan from the cluster and powered off to enable
planned maintenance and emergency service. Once service is completed, the node
can be powered back on and rejoin the cluster.

  With all VMs shut down, the dashboard can be used to cold-stop the cluster
entirely.


VM Provisioning and Removal
---------------------------

  The dashboard allows users to create new virtual servers on the cluster.
Installation media can be added to the cluster in one of three ways;

 > a. Create an image from a DVD or CD disc mounted in the dashboard server
 > b. Upload an ISO from the user's computer/tablet
 > c. Direct download to the cluster from a website or ftp site

  Once the media is on the cluster, users can use it to create a new virtual
server. The user simply names the new VM, chooses the OS type from a drop-down
list, chooses the installation and, if needed, driver disc image, sets the
number of CPUs and the amount of RAM.

  The primary node, failover group and storage configuration is all selected
and managed automatically for the user.


  Existing virtual servers can be deleted from the cluster. Once removed, the
resources formally consumed by that VM are released back into the cluster's
resource pools, making them immediately available for use by existing or new
VMs.


Media and Resource Management for Existing VMs
----------------------------------------------

  The dashboard allows for easy management of existing VMs. A user can "insert"
or "eject" a CD or DVD. This allows users to easily install applications that
they have on physical media.

  Existing VMs can change the number of CPUs and the amount of RAM allocated to
a virtual server. If the VM's operating system supports it, this change will be
instantly reflected in the VM. Otherwise, the changes take effect when the
client next powers off and restarts their VM.


Usage
-----

  The AN! Cluster Dashboard is designed to be easy to use by the users. In
order to achieve this, the dashboard requires certain naming conventions be
used in the clusters.


Cluster Node Name:

  The cluster node names must use the suffix `nXX`, where `XX` indicates the
node's number. For example, the node names `an-c01n01` and `an-c01n02` would
work fine.


Failover Domain Names:

  The failover domains used for the VM resource must have matching 'nXX'
suffixes. Continuing the earlier example, the FOD names `primary_n01` and
`primary_n02` would be good.


Clustered LVM Volume Group Names:

  The volume groups must have the *prefix* of `nXX`, again matching the nodes
numbers. Continuing again our example, `n01_vg0` and `n02_vg0` are good names.


  The trick here is that the `nXX` is used to map the storage and failover
domains to the preferred host for a given VM.

Screenshots
-----------

![An cdb cluster stack started](https://alteeve.ca/w/File:An-cdb-cluster-stack-started.png)
![An cdb cluster stack running](https://alteeve.ca/images/d/d7/An-cdb-cluster-stack-running.png)
\*All screen shots shown here were taken in late July 2013\*

Links
-----

1. - https://alteeve.ca/w/AN!Cluster_Tutorial_2