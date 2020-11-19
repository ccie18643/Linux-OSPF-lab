#!/bin/bash
ovs-vsctl set port r1 trunks=16,19,123
ovs-vsctl set port r2 trunks=123,245
ovs-vsctl set port r3 trunks=35,37,123
ovs-vsctl set port r4 trunks=49,245
ovs-vsctl set port r5 trunks=35,245
ovs-vsctl set port r6 trunks=16,67,68
ovs-vsctl set port r7 trunks=37,67,78
ovs-vsctl set port r8 trunks=68,78
ovs-vsctl set port r9 trunks=19,49
