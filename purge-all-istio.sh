#!/bin/bash
#
# for entirely deleting isto-system and istio-operator namespaces if necessary
#

if [ $# -lt 1 ]; then
  echo "Usage: istioctlPath"
  echo "Example: istio-1.10.3/bin/istioctl"
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

echo purge all objects
set -x
istio-1.10.3/bin/istioctl x uninstall --purge
set +x

echo "removing istio.io/rev label from all namespace"
for the_namespace in $(kubectl get namespace --output=jsonpath="{.items[].metadata.name}"); do
  kubectl label namespace $the_namespace istio.io/rev-
done
# show namespaces that still have label
kubectl get namespace -L istio.io/rev


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


