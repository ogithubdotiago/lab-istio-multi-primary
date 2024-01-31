#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n# Install Calico\n"

# tshoot - disable eth1 interface "libvit default interface"
printc "\n# tshoot - disable eth1 interface "libvit default interface"\n"
    for N in {1..2}; do
        for i in istio-cluster-0${N} istio-cluster-0${N}-m02; do
            printc "\n# disable eth1 on $i\n" "yellow"
            minikube ssh -n $i "sudo ip link set eth1 down" -p istio-cluster-0${N}
        done
    done

# Install calico
printc "\n# Install calico\n"
    for ctx in $CTX_CLUSTER1 $CTX_CLUSTER2; do
        printc "\n# Install calico on ${ctx}\n" "yellow"
        kubectl create -f network/tigera-operator.yaml --context="${ctx}"
        kubectl apply -f network/custom-resources-${ctx}.yaml --context="${ctx}"
    done
