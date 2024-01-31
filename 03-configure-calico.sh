#!/bin/bash

source $(dirname $0)/00-include.sh

# Get nodes ips
printc "\n# Get nodes ips\n"
IP_ISTIO_CLUSTER_01=$(minikube profile list -o json |\
    jq -r '.valid[].Config | select( .Name | contains("istio-cluster-01")).Nodes[].IP' |\
    awk '{ print NR, $1 }' |egrep '^1' |cut -d ' ' -f2)
    echo $IP_ISTIO_CLUSTER_01
IP_ISTIO_CLUSTER_01_M02=$(minikube profile list -o json |\
    jq -r '.valid[].Config | select( .Name | contains("istio-cluster-01")).Nodes[].IP' |\
    awk '{ print NR, $1 }' |egrep '^2' |cut -d ' ' -f2)
    echo $IP_ISTIO_CLUSTER_01_M02
IP_ISTIO_CLUSTER_02=$(minikube profile list -o json |\
   jq -r '.valid[].Config | select( .Name | contains("istio-cluster-02")).Nodes[].IP' |\
   awk '{ print NR, $1 }' |egrep '^1' |cut -d ' ' -f2)
   echo $IP_ISTIO_CLUSTER_02
IP_ISTIO_CLUSTER_02_M02=$(minikube profile list -o json |\
    jq -r '.valid[].Config | select( .Name | contains("istio-cluster-02")).Nodes[].IP' |\
    awk '{ print NR, $1 }' |egrep '^2' |cut -d ' ' -f2)
    echo $IP_ISTIO_CLUSTER_02_M02

# Install calicoctl
printc "\n# Install calicoctl\n"
    mkdir bin
    curl -L https://github.com/projectcalico/calico/releases/download/v3.27.0/calicoctl-linux-amd64 -o bin/calicoctl
    for N in {1..2}; do
        for i in istio-cluster-0${N} istio-cluster-0${N}-m02; do
            printc "\n# Install calicoctl on $i\n" "yellow"
            minikube cp bin/calicoctl $i:/tmp/calicoctl -p istio-cluster-0${N}
            minikube ssh -n $i "sudo mv /tmp/calicoctl /usr/bin/calicoctl && sudo chmod +x /usr/bin/calicoctl" -p istio-cluster-0${N}
        done
    done

# Apply BGPConfiguration
printc "\n# Apply BGPConfiguration\n"
    kubectl apply -f network/bgp-configuration-istio-cluster-01.yaml --cluster=istio-cluster-01
    kubectl apply -f network/bgp-configuration-istio-cluster-02.yaml --cluster=istio-cluster-02

# Drain ebgp node
printc "\n# Drain ebgp nodes\n"
    printc "\n# Drain node istio-cluster-01-m02\n" "yellow"
    kubectl --cluster=istio-cluster-01 drain --ignore-daemonsets istio-cluster-01-m02 --force
    printc "\n# Drain node istio-cluster-02-m02\n" "yellow"
    kubectl --cluster=istio-cluster-02 drain --ignore-daemonsets istio-cluster-02-m02 --force

# Enable route reflector
printc "\n# Enable route reflector\n"
    kubectl config use-context istio-cluster-01 
    calicoctl patch node istio-cluster-01-m02 -p '{"spec": {"bgp": {"routeReflectorClusterID": "244.0.0.1"}}}' --allow-version-mismatch
    kubectl config use-context istio-cluster-02
    calicoctl patch node istio-cluster-02-m02 -p '{"spec": {"bgp": {"routeReflectorClusterID": "244.0.0.2"}}}' --allow-version-mismatch
    kubectl --cluster=istio-cluster-01 label node istio-cluster-01-m02 route-reflector=true
    kubectl --cluster=istio-cluster-02 label node istio-cluster-02-m02 route-reflector=true

# Apply BGPPeer
printc "\n# Apply BGPPeer\n"
    kubectl config use-context istio-cluster-01
    calicoctl apply -f network/bgp-rr-configuration.yaml --allow-version-mismatch
    kubectl config use-context istio-cluster-02
    calicoctl apply -f network/bgp-rr-configuration.yaml --allow-version-mismatch

# Disable nodeToNodeMesh
printc "\n# Disable nodeToNodeMesh\n"
    kubectl config use-context istio-cluster-01
    calicoctl patch bgpconfiguration default -p '{"spec": {"nodeToNodeMeshEnabled": false}}' --allow-version-mismatch
    kubectl config use-context istio-cluster-02
    calicoctl patch bgpconfiguration default -p '{"spec": {"nodeToNodeMeshEnabled": false}}' --allow-version-mismatch

# Uncordon nodes
printc "\n# Uncordon nodes\n"
    kubectl --cluster=istio-cluster-01 uncordon istio-cluster-01-m02
    kubectl --cluster=istio-cluster-02 uncordon istio-cluster-02-m02

# Apply eBGP peerings
printc "\n# Apply eBGP peerings\n"
    kubectl config use-context istio-cluster-01
    cat network/bgp-peer-istio-cluster-01.yaml |sed "s/peerIP: CMD_SED_SET_IP/peerIP: $IP_ISTIO_CLUSTER_02_M02/" | calicoctl apply --allow-version-mismatch -f - 
    kubectl config use-context istio-cluster-02
    cat network/bgp-peer-istio-cluster-02.yaml |sed "s/peerIP: CMD_SED_SET_IP/peerIP: $IP_ISTIO_CLUSTER_01_M02/" | calicoctl apply --allow-version-mismatch -f -

# Disable ippool
printc "\n# Disable ippool\n"
    kubectl config use-context istio-cluster-01
    calicoctl apply -f network/ippool-istio-cluster-01.yaml --allow-version-mismatch
    kubectl config use-context istio-cluster-02
    calicoctl apply -f network/ippool-istio-cluster-02.yaml --allow-version-mismatch

# Configure netshoot pod
printc "\n# Configure netshoot pod\n"
    for ctx in $CTX_CLUSTER1 $CTX_CLUSTER2; do
        kubectl config use-context ${ctx}
        cat network/pod-netshoot.yaml |sed "s/{{CMD_SED_CTX}}/${ctx}/" | kubectl apply  -f -
    done
