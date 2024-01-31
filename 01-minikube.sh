#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n# Install k8s cluster by minikube\n"

# Define libvirt network
printc "\n# Define libvirt network\n"
    sudo virsh net-define network/istio-cluster.xml

# Enable libvirt network
printc "\n# Enable libvirt network\n"
    sudo virsh net-start istio-cluster

# Validate libvirt network
printc "\n# Validate libvirt network\n"
    sudo virsh net-list

# Install clusters
printc "\n# Install clusters\n"
    for N in {1..2}; do
        printc "\n# Install istio-cluster-0${N}\n" "yellow"
        minikube start \
        -p istio-cluster-0${N} \
        --nodes=2 \
        --driver=kvm2 \
        --memory=8192 \
        --cpus=8 \
        --network=istio-cluster \
        --cni=false \
        --network-plugin=cni \
        --service-cluster-ip-range=192.168.${N}.0/24 \
        --extra-config=kubeadm.pod-network-cidr=172.2${N}.0.0/16
    done

# List minikube profiles
printc "\n# List minikube profiles\n"
    minikube profile list

# Create pod range route
printc "\n# Create pod range route\n"
    IP_ISTIO_CLUSTER_01=$(minikube profile list -o json |\
        jq -r '.valid[].Config | select( .Name | contains("istio-cluster-01")).Nodes[].IP' |\
        awk '{ print NR, $1 }' |egrep '^1' |cut -d ' ' -f2)
    IP_ISTIO_CLUSTER_02=$(minikube profile list -o json |\
        jq -r '.valid[].Config | select( .Name | contains("istio-cluster-02")).Nodes[].IP' |\
        awk '{ print NR, $1 }' |egrep '^1' |cut -d ' ' -f2)
    declare -A pod_cidr=(
        ["$IP_ISTIO_CLUSTER_01"]="172.21.0.0/16"
        ["$IP_ISTIO_CLUSTER_02"]="172.22.0.0/16")
    for ip_cluster in "${!pod_cidr[@]}"; do
        echo "route: sudo ip route add ${pod_cidr[$ip_cluster]} via ${ip_cluster}"
        sudo ip route add ${pod_cidr[$ip_cluster]} via ${ip_cluster}
    done

# Enable metallb
printc "\n# Enable metallb\n"
declare -A ip=( 
    ["istio-cluster-01"]="0"
    ["istio-cluster-02"]="9")
for ctx in "${!ip[@]}"; do
printc "\n# Enable metallb on ${ctx}\n" "yellow"
if [[ ${ctx} == "istio-cluster-01" ]]; then N="1"; else N="2"; fi
minikube addons enable metallb -p ${ctx} 
expect << _EOF_
spawn minikube addons configure metallb -p ${ctx}
expect "Enter Load Balancer Start IP:" { send "192.168.39.${N}0\\r" }
expect "Enter Load Balancer End IP:" { send "192.168.39.${N}9\\r" }
expect eof
_EOF_
done
