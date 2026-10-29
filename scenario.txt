== 14:02:15 ready: 5.14.0-687.53.1.el9_8.x86_64
== 14:02:17 installed: pacemaker-2.1.10-3.el9_8.x86_64
== 14:02:17 start ctl-b, then ctl-a
== 14:02:44 DC: ctl-b
+ crm_attribute --type crm_config --name stonith-enabled --update true
+ crm_attribute --type crm_config --name no-quorum-policy --update ignore
+ crm_attribute --type crm_config --name join-finalization-timeout --update 5min
+ cibadmin --create --scope resources --xml-file /tmp/cib-rsc.xml
+ cibadmin --create --scope constraints --xml-file /tmp/cib-cons.xml
== 14:02:45 5 configuration changes
Cluster Summary:
  * Stack: corosync (Pacemaker is running)
  * Current DC: ctl-b (version 2.1.10-3.el9_8-5693eaeee) - partition with quorum
  * Last updated: Thu Oct 29 14:03:02 2026 on ctl-b
  * Last change:  Thu Oct 29 14:02:50 2026 by root via root on ctl-b
  * 2 nodes configured
  * 2 resource instances configured

Node List:
  * Online: [ ctl-a ctl-b ]

Active Resources:
  * fence-lab	(stonith:fence_lab):	 Started ctl-a
  * svc	(ocf:pacemaker:Dummy):	 Started ctl-a
== 14:03:02 kill corosync on ctl-a
sh: line 1: nft: command not found
