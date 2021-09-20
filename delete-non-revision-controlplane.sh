#!/bin/bash
#
# delete istio object in non-revision control plane
#

# deleting the iop should be sufficient to remove all the non-revisioned control plane objects
timeout 90s kubectl delete -n istio-system iop/istio-control-plane
if [ $? -eq 0 ]; then
  echo "iop deleted normally"
else
  echo "iop not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
  sleep 5
fi
kubectl get -n istio-system iop


#
# none of these deletions should be necessary, the iop deletion should have taken care of
#
set -x
ns=istio-system

echo "Did iop deletion remove these?"
kubectl get -n $ns iop
kubectl get -n $ns cm
kubectl get  mutatingwebhookconfiguration
kubectl get -n deployment istiod
kubectl get -n service istiod
kubectl get -n hpa istiod
kubectl get -n pdb istiod
kubectl get -n configmap
kubectl get all -n $ns

# optionally delete operator
read -p "Delete the istio-operator/istio-operator (y/N)?" answer
if [ "$answer" == "y" ]; then
  ns=istio-operator
  kubectl delete deployment/istio-operator -n $ns
  sleep 10
  # delete services
  kubectl delete service/istio-operator -n $ns
  sleep 10
  # show objects now
  kubectl get all -n $ns
fi
