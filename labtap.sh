#!/bin/bash

ip link add name labtap type dummy

ip link set labtap up

ovs-vsctl add-port ovs-br0 labtap

ovs-vsctl -- --id=@labtap get Port labtap \
          -- --id=@m create mirror name=0 select-all=true output-port=@labtap \
          -- set Bridge ovs-br0 mirrors=@m

