#!/bin/bash
#
# delete istio object in non-revision control plane
#

#
# delete operator first, so it doesn't recreate control plane objects
#

if [ $# -lt 1 ]; then
  echo "Usage: <istioManifestFile>"
  echo "Example: istio-operator-1.7.5-no-revision.yaml"
  exit 1
fi

istiomanifest_path="$1"
# make sure we can see istioctl
if [ ! -f $istiomanifest_path ]; then
  echo "ERROR cannot find istio manifest $istiomanifest_path"
  exit 3
fi


ns=istio-system

# deleting the iop should be sufficient to remove all the non-revisioned control plane objects
timeout 90s kubectl delete -n $ns iop/istio-control-plane
if [ $? -eq 0 ]; then
  echo "iop deleted normally"
else
  echo "iop not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane -n $ns -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
  sleep 5
fi
kubectl get -n istio-system iop


#
# none of these deletions should be necessary, the iop deletion should have taken care of them
#

echo "Did iop deletion remove these?"
kubectl get -n $ns deployment istiod
if [ $? -eq 0 ]; then
  kubectl delete deployment/istiod -n $ns
  sleep 10
fi

kubectl get -n $ns service istiod
if [ $? -eq 0 ]; then
  kubectl delete service/istiod -n $ns
  sleep 10
fi

kubectl get -n $ns hpa istiod
if [ $? -eq 0 ]; then
  kubectl delete hpa/istiod -n $ns
  sleep 10
fi
kubectl get -n $ns pdb istiod
if [ $? -eq 0 ]; then
  kubectl delete pdb/istiod -n $ns
  sleep 10
fi

kubectl get mutatingwebhookconfiguration istio-sidecar-injector
if [ $? -eq 0 ]; then
  kubectl delete mutatingwebhookconfiguration/istio-sidecar-injector
fi

for cm_name in $(kubectl get cm -n istio-system -l="istio.io/rev=default" --output=jsonpath={.items[*].metadata.name}); do
  kubectl -n istio-system delete cm/$cm_name
done

kubectl get all -n $ns

echo remove control plane for istio $istiover revision $revision_hyphenated
if [[ "$istiover" < "1.7" ]]; then
  echo "istio versions less than 1.7 do not have 'operator uninstall', skipping istioctl to do operator removal"
  ns=istio-operator
  kubectl delete deployment/istio-operator -n $ns
  sleep 10
  # delete services
  kubectl delete service/istio-operator -n $ns
  sleep 10
  # show objects now
  kubectl get all -n $ns  
else
  $istioctl_path x uninstall --filename $istiomanifest_path
fi


