#!/bin/bash

source $(dirname $0)/00-include.sh

# Delete minikube clusters
printc "\n# Delete minikube clusters\n"
    minikube delete --all

# Delete libvirt net
printc "\n# Delete libvirt net\n"
    sudo virsh net-destroy istio-cluster
    sudo virsh net-undefine istio-cluster

# Delete routes 
printc "\n# Delete routes\n"
    sudo ip route del 172.21.0.0/16
    sudo ip route del 172.22.0.0/16

# Delete certificates
printc "\n# Delete certificates\n"
    rm -rf certs/
    rm -rf istio/
    rm -rf bin/