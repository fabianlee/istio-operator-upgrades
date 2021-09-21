#!/bin/bash

# convert dotted version to hypenated version label
revision_hyphenated=${1//\./\-}
echo $revision_hyphenated

# if this old label is set on default namespace, envoy injection will not work because this classic label conflicts with istio.io/rev below
for ns in default istio-system istio-operator; do
  kubectl label namespace $ns istio-injection-
done
 
# unsetnewer 'istio.io.rev' label
for ns in default istio-operator; do 
  kubectl label namespace $ns istio.io/rev-
done

echo "Final results:"
set -ex
kubectl get namespace -L istio-injection
kubectl get namespace -L istio.io/rev
