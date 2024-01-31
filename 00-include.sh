#!/bin/bash

## https://istio.io/latest/docs/setup/install/multicluster/before-you-begin/
## https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/
## https://istio.io/latest/docs/setup/install/multicluster/multi-primary/

#contexts
CTX_CLUSTER1=istio-cluster-01
CTX_CLUSTER2=istio-cluster-02

#custom_print
printc() {
    if [ "$2" == "yellow" ]; then
        COLOR="93m" #yellow
    else
        COLOR="92m" #green
    fi
    STARTCOLOR="\e[$COLOR"
    ENDCOLOR="\e[0m"
    printf "$STARTCOLOR%b$ENDCOLOR" "$1"
}
