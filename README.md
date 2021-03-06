# Linux OSPF routing lab

Goal of this project is to create fully functional OSPF lab solely using Linux virtualization. It is going to use KVM to host the router VMs and the OVS to switch traffic between them. Also i want each of the router VMs to have separate management IP address connected to my home LAN so i can connect to them from my laptop. The LAN connectivity will use existing Linux Bridge and the lab traffic will be contained in OVS. This hybrid solution is used for couple reasons... First i need to use OVS for lab because i don't want to be wasting time on creating new Linux bridge for each of the lab vlans i want to use for OSPF. With OVS i can just create single switch and plug trunk port from each router inyo it. Why not to use OVS for home LAN connectivity as well then ? Well... technically i could, but i have already existing Linux bridge configuration that i have been using to share my LAN with regular VMs. On top of that (and this is the main reason) setting up OVS with Netplan is somewhat challenging and i simply have no time for it at the moment. This project is intended to be OSPF lab not OVS/Netplan lab after all :)

### So here we go... The quick and dirty way of making this happen

![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/linux_routing_lab.png)


### Plan of action

1. Install KVM - That's already done and really all it takes its to use apt command. Multiple guides available on internet on how to do it, i'll skip it here.
2. Install OVS - Pretty much the same story as KVM. The 'fire apt and forget' type of process. After installation create switch named 'ovs-br0' that we will use for lab vlans.

3. Prepare the router template - Regular Ubuntu server will do, nothing special about it. Name it 'template-router'. Put some management IP from LAN.
 - Install FRR - Why FRR ? Mainly because i am familiar with Zebra and Quagga already and FRR doesn't suck bad enough to discourage me from using it. In general choice of actual routing engine doesn't matter as long as it supports OSPF. U can even write your own OSPF implementation if you like network programming. After installation make sure FRR is actually disabled as we are not going to use systemd to run it. Issue command 'systemctl disable frr'.
 - Create second network interface for the router template - This is somewhat tricky process so i will cover it in detail here.
   - Open router VM configuration, add new network 'shared device' interface. Easy enough right ? Too bad its not going to work just yet...
   ![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/kvm_add_if.png)
   - Edit router VM configuration (using 'virsh edit template-router' command) and add the highlighted entries. When you boot router VM it will autmagicaly plug it's second interface into the 'ovs-br0' switch we created earlier.
   ![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/kvm_mod_if.png)
 - Now the fun part... we need to make our router VM to actually acts as a router... Best way to do so is basically to configure all the router related setup in separate network namespace. This little script will take care of it. It creates new namespace called 'router', configures it for traffic forwarding, plugs our second network interface into it and then creates vlan interface for every subnet we want to have configured on this particular router. Scrpt will also create lo0 interface with router id IP configured on it for convenience. Eg. for r1 it will be 1.1.1.1/32. After that is done script will start FRR and finally will give us the FRR's cli. Call the script 'ruter.sh' and put it in '/root' directory, make sure its executable. Note here that since we are just preparing router VM template u don't need to run the script just yet.
  ![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/router_script.png)
 - I would also suggest to configure your router VM Linux user with the RSA ssh key you will use to connect to it. Then configure this user to be able to run sudo without password and on top of that plug 'sudo su -' at the very end of your '.bsahrc' script so u get into root shell as soon as you connect to router VM. Trust me this will make your life easier when using lab...
 - Shut down the router VM. Now you have router template that can be used to setup all of the routers in our lab.

### Using the template we can relatively quickly deploy our OSPF lab 

![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/linux_ospf_lab.png)

#### I am going to explain in detail setting up one of the routers

1. Clone template, name new VM as 'r1'. I assume i don't need to explain here how to do it.
2. Edit configuration of new VM (using 'virsh edit r1' command) and change the name of interface from 'template-router' to 'r1'. This step is important as you really want to be able to easily distinguish between your virtual router interfaces when using Wireshark.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/r1_kvm_mod_if.png)
3. Boot the 'r1' VM and connect to it. It is using the IP we put in template. Change it by editing config file in '/etc/netplan' folder and change the hostname by editing '/etc/hostname' file. Also add router startup script into root's '.profile' file ('echo "~/router.sh 16 19 123" >> /.profile' command). Script takes network numbers as parameters to autmagicaly create vlan interfaces that will be later populated into FRR configuration..
4. Reboot router VM and connect to it. You will be placed directly into FFR's command line. You can see the interface list i mentioned earlier.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/r1_second_boot.png)
5. At this point we are done with r1. I have also configured couple more routers to show the routing table and OSPF peering forming up.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/r1_ospf_nei.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/r1_ospf_nei_pcap.png)
6. It didn't occur to me earlier but there is certain configuration that needs to be done on OVS to prevent multicast traffic from all vlans to show on every router port. This will not effect the FRR as FRR uses the vlan intefaces not the actual trunk port, but it will show up on Wireshark when listening on router port. I am not sure about permannt solution just yet but quick fix for this problem is defining vlans that can be trunked on each router port attached to OVS.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/ovs_trunk_setup.png)
7. Perhaps even better idea for hooking up Wireshark is to create dummy interface on host machine and confguring it as mirror port for all vlans on OVS. This little script will do it for us. Then we can filter the exact vlan we want to see using vlan id filtereing under Wireshark.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/labtap.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/ws_tag_filter.png)

### Let's take a look at some OSPF packets then...

- **Hello** packets are being sent periodically by all OSPF routers to indicate they are alive, to share basic OSPF parameters and to form peerings. Below example of r1 sending out hello packet on segment 123. Since this is multiaccess segment the hello packet additionally contains information about DR (Designated Router) and BDR (Backup Designated Router) that are present on this segment. This information on point-to-point link would be all 0s.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/hello_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/hello_pcap_2.png)
- **Database Description** packets are being sent out by routers to inform their neighbors about content of the originating router's database. They do not contain full LSAs just LSA's headers with information required to identify particular LSA. Here i have just rebooted r5 and r3 is informing it what LSAs it has in it's database. Based on this information r5 can ask r3 to send it the specific LSAs that r5 doesn't yet have in its own database (although r5 just rebooted it might already learn some or even all of them  from r2).
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/dbdes_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/dbdes_pcap_2.png)
- **Link State Request** packets are being sent out by routers to request information from peer routers that will help to build (or fill the gaps in) their own database. Here r5 is requesting r3 to send it couple LSAs based on the information r5 received in the Database Description packet from r3 earlier.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/dbreq_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/dbreq_pcap_2.png)
- **Link State Update** packets are being sent out by routers in response to Link State Requests. Here r3 is responding with some of the information that has been earlier requested by r5. At this point it seems to me that r3 is sending much more information that what r5 requested but perhaps its trying to fill r5's database also based on recently received r5's Database Description packet. This is something i need to read more about in OSPF RFC and perhaps look at FRR source code to figure out the exact mechanism being used in this case.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/dbres_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/dbres_pcap_2.png)
- **Link State Acknowledgment** packets are being sent out by routers in response to Link State Updates. Here r5 is responding to the Link State Update packet it received earlier from r3. Packet contains only LSA headers.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/dback_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/dback_pcap_2.png)

### Now let's take a look at actual OSPF LSAs being careied in the Link State Update packets...

- **Type 1** (Router) LSA advertised from r8 to r7 over point-to-point link. It describes three of the r8's links (8.8.8.8/32, 10.0.68.0/24, 10.0.68.0/24) and two point-to-point peerings (6.6.6.6 and 7.7.7.7). The same LSA can obviously be found on any router that is part of area 1. Screenshot of OSPF database taken from r1.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa1_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa1_pcap_2.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa1_db_r1.png)
- **Type 2** (Network) LSA advertised from DR (Designated Router) to all other routers on the same network segment. It advertises segment's subnet mask and lists all the OSPF routers connected to this segment. Same LSA visible in OSPF database of any router in area 0. Screenshot of OSPF database taken from r1.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa2_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa2_pcap_2.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa2_db_r1.png)
- **Type 3** (Network Summary) LSA advertised from ABR (Area Border Route) to all routers in the area. It advertises prefixes received from other areas (in a distance-vector manner) into area 1. Screenshot of OSFP database taken from r8.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa3_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa3_pcap_2.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa3_db_r8.png)
- **Type 4** (ASBR Summary) LSA advertised from ABR (Area Border Route) to all routers in the area. It advertises all known (to r1 in this case) ASBR routers (in a distance-vector manner again) into area 1. Type 4 LSAs are needed because routers in different areas otherwise wouldn't be able to figure out how to get to ASBR since Type 1 LSA do not pass area boundaries. Screenshot of OSFP database taken from r8 shows the same information advrtised into area 1 by r1 and r3.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa4_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa4_pcap_2.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa4_db_r8.png)
- **Type 5** (External) LSA advertised from r9 to r1. I have configured three 172.16.9[1-3].0/24 static routes on r9 and redistributed them into OSPF. That essentially made r9 and ASBR (Autonomous System Border Router). We can see those prefixes being advertised from r9 to r1. Since i don't have configured any filtering, summarization or stub areas those three prefixes are being advertised (and again a distance-vector thing) to every router in lab network. Screenshot of OSPF database taken form r8.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa5_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa5_pcap_2.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa5_db_r8.png)
- **Type 7** (NSSA-External) LSA advertised from r9 to r1. At this point I have configured area 2 as NSSA (Not So Stubby Araea) which essentially prohibited it from using Type 5 LSAs so instead Type 7 LSA need to be used to deliver the information about external prefixes from r9 to r1 and r4. Router r1 is also converting that Type 7 LSA into regular Type 5 LSA and advertising it into other areas. First OSPF database screenshot show prefix 172.16.91.0/24 being kept as LSA 7 on r1. Second screenshot shows the same prefix being kept as Type 5 in r8's database. In matter of fact the Type 5 LSA for the same traffic can obviously be also found in r1's database. Router r1 will keep both Type 5 and Type 7 LSAs for the 172.16.91.0/24 prefix.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa7_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa7_pcap_2.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa7_db_r1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/lsa7_db_r8.png)

#### At this point we can clearly see that out of six standard (and any non standard) LSAs only two have anything to do with link state nature of OSPF protocol. Basically only types 1 and 2 are being fed to the Dijkstra algorithm. Well... can't really blame OSPF for that since it's more serious brother, the ISIS does exactly the same :)

### Some other interesting cases and scenarios...

- **Virtual link** set up between routers r4 and r3 for the purpose of keeping are 2 connected to area 0 in case link between r1 and r9 died. Capture shows unicast packet exchange between those two routers.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/vlink_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/vlink_db_r3.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/vlink_db_r4.png)

### Troubleshooting...

- **MTU mismatch** introduced between r7 and r8. I have lowered the r7's vlan78 interface mtu to 1400. This caused both routers to get stuck in Exstart OSPF FSM state. In this state routers are making attempt to synchronize their databases by sending Database Description packets. Those packets contain the link mtu value of the sender router and in case they do not match the peerng will not be fully formed. Here is the packet exchange between both routers showing the mtu values in their Database DEscription packets. One thing to note here is that mtu mismatch is not being detected during the initial Hello packet exchange (like any other parameter mismatch would) simply because hello packets do not carry router's link mtu value.
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/mtu_pcap_1.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/mtu_pcap_2.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/mtu_pcap_2.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/mtu_r7.png)
![Screenshot](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/mtu_r8.png)

