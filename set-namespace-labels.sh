#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: <istioVersion>"
  echo "Example: 1.7.5"
  exit 1
fi

# convert dotted version to hypenated version label
revision_hyphenated=${1//\./\-}
echo $revision_hyphenated

# if this old label is set on default namespace, envoy injection will not work because this classic label conflicts with istio.io/rev below
for ns in default istio-system istio-operator; do
  kubectl label namespace $ns istio-injection-
done
 
# set newer 'istio.io.rev' label
for ns in default istio-operator; do 
  kubectl label namespace $ns istio.io/rev=$revision_hyphenated --overwrite=true
done

set -ex
kubectl get namespace -L istio-injection
kubectl get namespace -L istio.io/rev
