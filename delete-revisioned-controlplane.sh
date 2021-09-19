#!/bin/bash
#
# removes revisioned istio control plan
# and optionally the iop and entire istio namespaces
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

echo remove auto sidecar injection in namespaces
kubectl label namespace default istio-injection-
for the_namespace in $(kubectl get namespace -L istio.io/rev -l="istio.io/rev=$revision_hyphenated" --output=jsonpath="{.items[].metadata.name}"); do
  kubectl label namespace $the_namespace istio.io/rev-
done
# show namespaces that still have label
kubectl get namespace -L istio.io/rev

echo do rolling restart of deployment and wait for ready
kubectl rollout restart -n default deployment/my-istio-deployment
kubectl rollout status deployment my-istio-deployment
kubectl get pods -lapp=my-istio-deployment

echo remove control plane for istio $istiover revision $revision_hyphenated
if [[ "$istiover" < "1.7" ]]; then
  echo "istio versions less than 1.7 do not have 'operator --revision' flag, so just doing 'istioctl x uninstall'"
  $istioctl_path operator remove
else
  $istioctl_path x uninstall --revision $revision_hyphenated
fi
# do this for an unrevsioned control plan
#~/k8s/istio-$istiover/bin/istioctl x uninstall

kubectl get -n istio-system iop
read -p "Delete the iop (y/N)?" answer
if [ $answer == "y" ]; then

  timeout 90s kubectl delete -n istio-system iop/istio-control-plane
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

# remove all istio related namespaces
kubectl get ns
read -p "Delete the istio-system and istio-operator namespaces completely (y/N)?" answer
if [ $answer == "y" ]; then

  for ns in istio-system istio-operator; do 
    kubectl get ns $ns
    # skip if not namespace not found
    if [ $? -eq 1 ]; then
      continue
    fi

    echo deleting namespace $ns
    timeout 60s kubectl delete ns $ns
    if [ $? -ne 0 ]; then
      echo "ns $ns could not be deleted normally, emptying its finalizers"
      kubectl patch ns $ns --type merge -p '{"metadata":{"finalizers":null}}'

      echo "waiting 20sec to see if patching with empty finalizers worked"
      sleep 20

      kubectl get ns $ns
      if [ $? -ne 0 ]; then
        echo "Using raw patch of empty finalizers to try to delete ns $ns"

        # if you really cannot get ns deleted
        # https://stackoverflow.com/questions/52369247/namespace-stuck-as-terminating-how-do-i-remove-it
        kubectl get namespace $ns -o json \
        | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
        | kubectl replace --raw /api/v1/namespaces/$ns/finalize -f -

      fi

    else
      echo "ns $ns deleted normally"
    fi

  done

fi



