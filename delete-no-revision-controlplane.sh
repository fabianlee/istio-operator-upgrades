#!/bin/bash
#
# delete istio object in non-revision control plane


timeout 90s kubectl delete -n istio-system iop/istio-control-plane
if [ $? -eq 0 ]; then
  echo "iop deleted normally"
else
  echo "iop not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
  sleep 5
fi
kubectl get -n istio-system iop

ns=istio-operator


set -x
kubectl delete deployment/istio-operator -n $ns
sleep 10

# delete services
kubectl delete service/istio-operator -n $ns

# show components now
kubectl get all -n $ns


ns=istio-system

# show horizontal pod autoscalers
kubectl get hpa -n $ns

# delete hpa
kubectl delete hpa/istiod -n $ns

sleep 10

# show pod disruption budgets
kubectl get pdb -n $ns

# delete pdb
kubectl delete pdb/istiod -n $ns

sleep 10

# delete deployments
kubectl delete deployment/istiod -n $ns

sleep 10

# delete services
kubectl delete service/istiod -n $ns

# delete mutatingwebhookconfiguration
kubectl delete mutatingwebhookconfiguration/istio-sidecar-injector

sleep 10

# show components now
kubectl get all -n $ns

