#!/bin/bash
#
# removes revisioned istio control plan
# and optionally the iop and entire istio namespaces
#
source ./delete-include.sh

if [ $# -lt 2 ]; then
  echo "Usage: istioctlPath <istioVersion>"
  echo "Example: istio-1.7.5/bin/istioctl 1.7.5"
  exit 1
fi

istioctl_path="$1"
istiover="$2"
revision_hyphenated=${istiover//\./\-}

# make sure we can see istioctl
if [ ! -f $istioctl_path ]; then
  echo "ERROR cannot find istioctl for $istiover at $istioctl_path"
  exit 3
fi

# convert dotted version to hypenated version label
echo "istio version $istiover with revision $revision_hyphenated"

echo remove auto sidecar injection in namespaces
kubectl label namespace default istio-injection-
for the_namespace in $(kubectl get namespace -L istio.io/rev -l="istio.io/rev=$revision_hyphenated" --output=jsonpath="{.items[].metadata.name}"); do
  kubectl label namespace $the_namespace istio.io/rev-
done
# show namespaces that still have label
kubectl get namespace -L istio.io/rev

for cm_name in $(kubectl get cm -n istio-system -l="istio.io/rev=$revision_hyphenated" --output=jsonpath={.items[*].metadata.name}); do
  kubectl -n istio-system delete cm/$cm_name
done

echo do rolling restart of deployment and wait for ready
kubectl rollout restart -n default deployment/my-istio-deployment
kubectl rollout status deployment my-istio-deployment
kubectl get pods -lapp=my-istio-deployment

echo remove control plane for istio $istiover revision $revision_hyphenated
if [[ "$istiover" < "1.7" ]]; then
  echo "istio versions less than 1.7 do not have 'operator --revision' flag, skipping istioctl to do operator removal"
  #$istioctl_path operator remove
else
  $istioctl_path x uninstall --revision $revision_hyphenated
fi

kubectl get -n istio-system iop
read -p "Delete the iop (y/N)?" answer
if [ "$answer" == "y" ]; then

  timeout 90s kubectl delete -n istio-system iop/istio-control-plane-${revision_hyphenated}
  if [ $? -eq 0 ]; then
    echo "iop deleted normally"
  else
    echo "iop not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
    kubectl get istiooperator.install.istio.io/istio-control-plane -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
    sleep 5
  fi

fi
kubectl get -n istio-system iop

echo make sure mutatingwebhook is delete
if [ -n "$revision_hyphenated" ]; then
  kubectl delete mutatingwebhookconfiguration/istio-sidecar-injector-${revision_hyphenated}
else
  kubectl delete mutatingwebhookconfiguration/istio-sidecar-injector
fi

delete_entire_istio_ns

