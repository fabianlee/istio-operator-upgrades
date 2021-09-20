#!/bin/bash
#
# removes revisioned istio control plan
# working for newer versions of istio (1.7+?)
#

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

kubectl get -n istio-system iop
timeout 90s kubectl delete -n istio-system iop/istio-control-plane-${revision_hyphenated}
if [ $? -eq 0 ]; then
  echo "iop deleted normally"
else
  echo "iop not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane-${revision_hyphenated} -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
fi
sleep 30

echo "Did iop deletion remove these?"
kubectl get -n istio-system iop
kubectl get -n istio-system cm
kubectl get -n istio-system mutatingwebhookconfiguration

echo remove control plane for istio $istiover revision $revision_hyphenated
if [[ "$istiover" < "1.7" ]]; then
  echo "istio versions less than 1.7 do not have 'operator --revision' flag, skipping istioctl to do operator removal"
else
  $istioctl_path x uninstall --revision $revision_hyphenated -y
fi
