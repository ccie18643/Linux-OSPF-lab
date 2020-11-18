# Linux OSPF routing lab

Goal of this project is to create fully functional OSPF lab solely using Linux virtualization. It is going to use KVM to host the router VMs and the OVS to switch traffic between them. Also i want each of the router VMs to have separate management IP address connected to my home LAN so i can connect to them from my laptop. The LAN/management connectivity will use existing Linux Bridge and the Lab traffic will be contained in OVS. This hybrid solution is for couple reasons... First i need to use OVS for Lab because i don't want to be messing with creating a new Linux bridge for each lab vlan. With OVS i can just create single switch and plug a trunk port from each router in it. Why not to use OVS for home LAN connectivity then ? Well... technically i could, but i have already existing Linux bridge configuration that i have been using to share my LAN with VMs. On top of that (and this is the main reason) setting up OVS with Netplan is somewhat challenging and i simply have no time for it at the moment. This project is intended to be OSPF lab not OVS/Netplan lab after all :)

### So here we go... the quick and dirty way of making this happen

![Sample PyTCP log output](https://github.com/ccie18643/Linux-OSPF-lab/blob/main/pictures/linux_routing_lab.png)


## Plan of action

1. Install KVM - Thats already done and really all it takes its to use apt, multiple guides available on intenet on how to do it, i'll skip it here.
2. Install OVS - Pretty much the same story as KVM, 'fire apt and forget' type of process. After installation create switch named 'ovs-br0' that we will use for lab vlans.
3. Prepare the router template.
 - Regular Ubuntu server will do, nothing special about it. Name it 'template-router'. Put some management IP from LAN.
 - Install FRR (Why FRR ? Mainly because i was familiar with Zebra and Quagga already and FRR doesn't suck bad enough to discourage me from using it, it is quite annoying though at times so perhaps i replace it with something else later. In general choice of actual routing engine doesn't matter as long as it supports OSPF, u can even write your own if you like network programming. After installation make sure FRR is actually disabled as we are not going to use systemd to run it. Issue command 'systemctl disable frr'.
 - Create second network interface for the router template - This is somewhat tricky process so i will cover it in detail here.
   - Open router VM configuration, add new network 'shared device' interface. Easy enough right ? Too bad its not going to work just yet...
   - Edit router VM configuration (using 'virsh edit template-router' command) and add the highlited entiries. When you boot router VM it will autmagicaly plug it's second interface into the 'ovs-br0' switch we created earlier.
   - Now the fun part... we need to make our router VM to actually acts as a router... Best way to do so is basically to configure all the router related setup in separate network namespace. This little script we do it for us. It creates new namespace called 'router', configures it for traffic forwarding, plugs our second network interface into it and the ceates vlan interface for every subnet we want to have configured on this particular router. After that is done script will also start FRR and finally will give us shell in our router namespace. Call the script 'ruter.sh' and put it in '/root' directory, make sure its executable. Note here that since we are just preparing router VM template u dont need to run the script just yet.
   - Lets put some basic FRR configuration that we will use on all routers. Add following lines to '/etc/frr/frr.conf'. We use 'p' as password since its propably the least painfull way of entering password whenever we want to connect to FRR. This is one of anoyances of FRR, damn thing doesn't let you to login without entering password and then entering enable password... I mean honestly how stupid is that ? I can use single character as my password, but i cannot opt out from using login process whatsoever ??? Hello... we are talking about lab environment here, why do i need to type password twice to get to my lab device ???
   - At this point i would also suggest to configure your router VM Linux user with the RSA ssh key you will use to connect to it, then configuring this user to be able to run sudo without password and on top of that plug 'sudo su -' at the very end of your '.bsahrc' script so u get into root shell as soon as you connect to router VM. Trust me this will make your life easier when using lab...
   - Shut router VM, now you have router template that can be used to setup all the routers in our lab 
   
