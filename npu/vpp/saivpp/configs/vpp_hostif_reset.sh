#!/usr/bin/env bash

#
# Resetting VPP host interfaces needed for SAI-VPP to work properly
#

for num in $(seq 1 32); do
    vppctl delete host-interface name eth${num} 2>/dev/null || true
done

for num in $(seq 1 32); do
    vppctl create host-interface name eth${num}
    vppctl set interface state host-eth${num} up
done