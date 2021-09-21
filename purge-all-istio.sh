#!/bin/bash
#
# for entirely deleting isto-system and istio-operator namespaces if necessary
#
script_path=$( cd $(dirname "${BASH_SOURCE[0]}") && pwd)

if [ $# -lt 1 ]; then
  echo "Usage: istioVersion"
  echo "Example: 1.10.2"
  exit 1
fi

istiover="$1"
revision_hyphenated=${istiover//\./\-}
istioctl_path="$script_path/istio-$istiover/bin/istioctl"

# make sure we can see istioctl
if [ ! -f $istioctl_path ]; then
  echo "ERROR cannot find istioctl at $istioctl_path"
  exit 3
fi

echo purge all objects
set -ex
$istioctl_path x uninstall --purge -y
set +ex

echo "removing istio.io/rev label from all namespace"
for the_namespace in $(kubectl get namespace --output=jsonpath="{.items[*].metadata.name}"); do
  kubectl label namespace $the_namespace istio.io/rev-
done

# show namespaces that still have label
echo ""
kubectl get namespace -L istio.io/rev


kubectl get -n istio-system iop istio-control-plane-${revision_hyphenated}
if [ $? -eq 0 ]; then
  timeout 90s kubectl delete -n istio-system iop/istio-control-plane-${revision_hyphenated}
  if [ $? -eq 0 ]; then
    echo "iop deleted normally"
  else
    echo "iop not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
    kubectl get istiooperator.install.istio.io/istio-control-plane-${revision_hyphenated} -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
  fi
  sleep 30
fi


echo ""
kubectl get ns
read -p "Delete the istio-system and istio-operator namespaces completely (y/N)?" answer
if [ "$answer" == "y" ]; then

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
      if [ $? -eq 0 ]; then
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


