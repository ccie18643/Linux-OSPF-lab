# Linux OSPF routing lab

Goal of this project is to create fully functinal OSPF lab solely using Linux virtualization. It is going to use KVM to host the router VMs and the OVS to switch traffic between them. Also i want each of the router VMs to have separate management IP address connected to my home LAN so i can connect to them from my laptop. The LAN/management connectivity will use existing Linux Bridge and the Lab traffic will be contained in OVS. This hybrid solution is for couple reasons... First i need to use OVS for Lab because i dont' want to be messing with creating a new Linux bridge for each Lab vlan. With OVS i can just create single switch and plug a tunk port from each router in it. Why not to use OVS for home LAN connectivity then ? Well... technically i could, but i have already existing Linux bridge configuration that i have been using to share my LAN with VMs. On top of that (and this is the main reason) setting up OVS with Netplan is somewhat challenging and i simply have no time for it at the moment. This project is intended to be OSPF lab not OVS/NEtplan lab after all :) 

So here we go... i'll cover in detail only the interesting parts:

1. Install KVM - Thats already done and really all it takes its to use apt, multiple guides available on intenet on how to do it, i'll skip it here.
2. Install OVS - Pretty much the same story as KVM, 'fire apt and forget' type of process. After installation create switch named 'ovs-br0' that we will use for lab vlans.
3. Prepare the router template.
 - Regular Ubuntu server will do, nothing special about it. Name it 'template-router'. Put some management IP from LAN.
 - Install FRR (Why FRR ? Mainly because i was familiar with Zebra and Quagga already and FRR doesn't suck bad enough to discourage me from using it, it is quite annoying though at times so perhaps i replace it with something else later. In general choice of actual routing engine doesn't matter as long as it supports OSPF, u can even write your own if you like network programming.
 - Create second network interface for the router template - This is somewhat tricky process so i will cover it in detail here.
   - Open router VM configuration, add new network 'shared device' interface. Easy enough right ? Too bad its not going to work just yet...
   - Edit router VM configuration (using 'virsh edit template-router' command) and add the highlited entiries:
   
