#!/bin/bash

kubectl label namespace istio-operator istio-injection=disabled --overwrite=true
kubectl label namespace default istio-injection=enabled --overwrite=true

# will be empty for 1.6, only used in newer istio versions
set -x 
kubectl get namespace -L istio-injection
kubectl get namespace -L istio.io/rev
