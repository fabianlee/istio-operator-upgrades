#!/bin/bash
script_path=$( cd $(dirname "${BASH_SOURCE[0]}") && pwd)

if [ $# -lt 1 ]; then
  echo "Usage: <new_istioVersion"
  echo "Example: 1.8.1"
  exit 1
fi

istiover_new="$1"
revision_hyphenated_new=${istiover_new//\./\-}

# make sure upgrade is to at least 1.7
if [[ $istiover_new =~ ^1.6 ]] ; then 
  echo "ERROR this script cannot handle 1.6 upgrades because the opeator does not support the --revision flag"
  exit 1
fi

# check for manifest files existing up-front
[ -f $script_path/istio-operator-${istiover_new}.yaml ] || { echo "ERROR finding yaml for $istionver_new"; exit 3; }

if [ ! -d $script_path/istio-$istiover_new ]; then
  pushd .
  cd $script_path
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istiover_new sh -
  popd
fi

$script_path/istio-$istiover_new/bin/istioctl operator init --revision $revision_hyphenated_new --hub gcr.io/istio-release

kubectl get deployment -n istio-operator

kubectl create -f $script_path/istio-operator-${istiover_new}.yaml

kubectl get iop -A

echo going to settle for 10 seconds
sleep 10

kubectl get pods -n istio-system
count_ready=0
while [ $count_ready -lt 2 ]; do
  kubectl get pods -n istio-system
  count_ready=$(kubectl get pods -n istio-system -l="app in (istio-ingressgateway,istiod)" -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep true | wc -w)
  sleep 5
done
echo "moving on, $count_ready pods ready"

# remove older style labels
for ns in default istio-system istio-operator; do
  kubectl label namespace $ns istio-injection-
done

kubectl label namespace default istio.io/rev=$revision_hyphenated_new --overwrite=true
kubectl get namespace -L istio.io/rev

$script_path/show-istio-objects.sh
