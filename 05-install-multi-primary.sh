#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n# Install Istio Multi-Primary\n"
    mkdir istio
    for ctx in $CTX_CLUSTER1 $CTX_CLUSTER2; do
        printc "\n# Configure cluster ${ctx}\n" "yellow"
        cat <<-EOF | sudo tee istio/${ctx}.yaml
        apiVersion: install.istio.io/v1alpha1
        kind: IstioOperator
        spec:
          values:
            global:
              meshID: mesh1
              multiCluster:
                clusterName: ${ctx}
              network: network1
		EOF
        printc "$(ls -1 istio/${ctx}.yaml)\n" "yellow"
        istioctl install --context="${ctx}" -f istio/${ctx}.yaml -y
    done

printc "\n# Install remote secret\n"
    printc "\nInstall a remote secret in ${CTX_CLUSTER2} that provides access to ${CTX_CLUSTER1} API server\n" "yellow"
    istioctl create-remote-secret \
        --context="${CTX_CLUSTER1}" \
        --name=${CTX_CLUSTER1} | \
        kubectl apply -f - --context="${CTX_CLUSTER2}"
    printc "\nInstall a remote secret in ${CTX_CLUSTER1} that provides access to ${CTX_CLUSTER2} API server\n" "yellow"
    istioctl create-remote-secret \
        --context="${CTX_CLUSTER2}" \
        --name=${CTX_CLUSTER2} | \
        kubectl apply -f - --context="${CTX_CLUSTER1}"