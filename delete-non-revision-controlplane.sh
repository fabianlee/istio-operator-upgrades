#!/bin/bash
#
# delete istio object in non-revision control plane
#


timeout 90s kubectl delete -n istio-system iop/istio-control-plane
if [ $? -eq 0 ]; then
  echo "iop deleted normally"
else
  echo "iop not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
  sleep 5
fi
kubectl get -n istio-system iop


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


set -x
ns=istio-system

# delete deployments
kubectl delete deployment/istiod -n $ns
sleep 10

kubectl delete service/istiod -n $ns
sleep 10

# show horizontal pod autoscalers
kubectl get hpa -n $ns
kubectl delete hpa/istiod -n $ns
sleep 10

# show pod disruption budgets
kubectl get pdb -n $ns
kubectl delete pdb/istiod -n $ns
sleep 10

# delete mutatingwebhookconfiguration
kubectl delete mutatingwebhookconfiguration/istio-sidecar-injector
sleep 10

for cm_name in $(kubectl get cm -n istio-system -l="istio.io/rev=default" --output=jsonpath={.items[*].metadata.name}); do
  kubectl -n istio-system delete cm/$cm_name
done

# show components now
kubectl get all -n $ns
