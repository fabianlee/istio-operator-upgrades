#!/bin/bash
#
# delete default non-revisioned operator
#


ns=istio-operator

kubectl delete deployment/istio-operator -n $ns
sleep 10

# delete services
kubectl delete service/istio-operator -n $ns
sleep 10

# show objects now
kubectl get all -n $ns
