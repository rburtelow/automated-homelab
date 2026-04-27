#!/bin/bash

# qemu, scsi, linux-tools
image="factory.talos.dev/nocloud-installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.13.0"

# force is used due to 2 controlplanes, can be omitted if 3 controlplanes are used
for i in `kubectl get nodes -o wide | grep 192 | awk '{ print $6 }'`;
    do echo $i;
        talosctl upgrade --talosconfig ~/.talos/config -n $i --force --image $image;
done

