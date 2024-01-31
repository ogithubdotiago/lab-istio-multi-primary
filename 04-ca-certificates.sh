#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n# Plug in certificates and key into the cluster\n"

BASEDIR=$(pwd)

# Generate the root certificate and key
printc "\n# Generate the root certificate and key\n"
    mkdir $BASEDIR/certs
    cd $BASEDIR/certs ; make -f ../tools/certs/Makefile.selfsigned.mk root-ca 

# Generate intermediate certificate
printc "\n# Generate intermediate certificate\n"
    cd $BASEDIR/certs ; make -f ../tools/certs/Makefile.selfsigned.mk istio-cluster-01-cacerts
    cd $BASEDIR/certs ; make -f ../tools/certs/Makefile.selfsigned.mk istio-cluster-02-cacerts

# Create secret cacerts
printc "\n# Create secret cacerts\n"
    for ctx in $CTX_CLUSTER1 $CTX_CLUSTER2; do
        printc "\n# Create secret cacerts on ${ctx}\n" "yellow"
        kubectl create namespace istio-system --context="${ctx}"
        kubectl create secret generic cacerts -n istio-system --context="${ctx}" \
          --from-file=$BASEDIR/certs/${ctx}/ca-cert.pem \
          --from-file=$BASEDIR/certs/${ctx}/ca-key.pem \
          --from-file=$BASEDIR/certs/${ctx}/root-cert.pem \
          --from-file=$BASEDIR/certs/${ctx}/cert-chain.pem
    done
