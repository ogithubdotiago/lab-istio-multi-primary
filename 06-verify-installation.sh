#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n# Verify Istio Multi-Primary installation\n"

printc " Create sample namespace\n" "yellow"
kubectl create --cluster=istio-cluster-01 namespace sample
kubectl create --cluster=istio-cluster-02 namespace sample

printc "Enable istio-injection\n" "yellow"
kubectl label --cluster=istio-cluster-01 namespace sample istio-injection=enabled
kubectl label --cluster=istio-cluster-02 namespace sample istio-injection=enabled

printc "Apply helloworld service\n" "yellow"
kubectl apply --cluster=istio-cluster-01 -f manifests/helloworld.yaml -l service=helloworld -n sample
kubectl apply --cluster=istio-cluster-02 -f manifests/helloworld.yaml -l service=helloworld -n sample

printc "Apply helloworld deployment\n" "yellow"
kubectl apply --cluster=istio-cluster-01 -f manifests/helloworld.yaml -l version=v1 -n sample
kubectl apply --cluster=istio-cluster-02 -f manifests/helloworld.yaml -l version=v2 -n sample

printc "Apply sleep deployment\n" "yellow"
kubectl apply --cluster=istio-cluster-01 -f manifests/sleep.yaml -n sample
kubectl apply --cluster=istio-cluster-02 -f manifests/sleep.yaml -n sample

printc "Wait sleep deployment\n" "yellow"
sleep 20

#kubectl exec --cluster=istio-cluster-01 -n sample -c sleep \
#    "$(kubectl get pod --cluster=istio-cluster-01 -n sample -l app=sleep \
#    -o jsonpath='{.items[0].metadata.name}')" -- \
#    x=1; while [ $x -le 5 ]; do curl -sS helloworld.sample:5000/hello $(( x++ )); done

#kubectl exec --cluster=istio-cluster-02 -n sample -c sleep \
#    "$(kubectl get pod --cluster=istio-cluster-02 -n sample -l app=sleep \
#    -o jsonpath='{.items[0].metadata.name}')" -- \
#    x=1; while [ $x -le 5 ]; do curl -sS helloworld.sample:5000/hello $(( x++ )); done