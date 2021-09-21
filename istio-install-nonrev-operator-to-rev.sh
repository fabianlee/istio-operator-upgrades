#!/bin/bash
script_path=$( cd $(dirname "${BASH_SOURCE[0]}") && pwd)

if [ $# -lt 1 ]; then
  echo "Usage: <istioVersion>"
  echo "Example: 1.7.5"
  exit 1
fi

istiover="$1"
revision_hyphenated=${istiover//\./\-}


function show_menu() {
echo ""
echo "===== MENU ============================"
echo "1) install $istiover without revisioned control plane"
echo "2) upgrade to $istiover fully revisioned control plane"
echo "3) rolling restart of deployments in default ns"
echo "4) delete default, non-revisioned $istiover control plane and operator"
echo ""
echo "show ) show all istio objects"
echo "purge) purge all istio objects and operators using istioctl $istiover"
echo "quit ) quit program"
echo ""
}


##### MAIN #############################


# check for manifest files existing up-front
[ -f $script_path/istio-operator-${istiover}-no-revision.yaml ] || { echo "ERROR finding yaml for no-revision $istionver"; exit 3; }
[ -f $script_path/istio-operator-${istiover}.yaml ] || { echo "ERROR finding yaml for revisioned $istionver"; exit 3; }

while [ 1==1 ]; do

show_menu
read -p "action: " answer

# which?
case $answer in


1)

if [ ! -d $script_path/istio-$istiover ]; then
  pushd .
  cd $script_path
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istiover sh -
  popd
fi

$script_path/istio-$istiover/bin/istioctl operator init --hub gcr.io/istio-release

kubectl create ns istio-system

kubectl create -f $script_path/istio-operator-${istiover}-no-revision.yaml

echo going to settle for 10 seconds
sleep 10

# wait for 3 ready pods
count_ready=0
while [ $count_ready -lt 2 ]; do
  kubectl get pods -n istio-system
  count_ready=$(kubectl get pods -n istio-system -l="app in (istio-ingressgateway,istiod)" -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep true | wc -w)
  sleep 5
done
echo "moving on, $count_ready pods ready"

# label according to older 1.6 spec or newer
if [[ $istiover =~ ^1.6 ]] ; then 
  for the_ns in istio-operator default; do
    kubectl label namespace $the_ns istio-injection=disabled --overwrite=true
  done
else
  kubectl label namespace default istio.io/rev=$revision_hyphenated --overwrite=true
  kubectl get namespace -L istio.io/rev
fi

$script_path/show-istio-objects.sh
;;



2)

# if you do not init a new operator, then applying a new manifest will create an iop and its dependent objects that can easily be deleted just by deleting its iop
# BUT if you do init this new operator, then you have a more involved deletion of old operator, iop, then dependent objects

if [[ $istiover =~ ^1.6 ]] ; then 
  echo "istio 1.6.x does not support operator init with --revision flag"
  echo "there will be only one operator, so when we get to the removal, we only need to delete the iop (not the operator)"
else
  $script_path/istio-$istiover/bin/istioctl operator init --revision $revision_hyphenated --hub gcr.io/istio-release
fi

kubectl get deployment -n istio-operator

kubectl create -f $script_path/istio-operator-${istiover}.yaml

kubectl get iop -A

echo going to settle for 10 seconds
sleep 10

kubectl get pods -n istio-system
count_ready=0
while [ $count_ready -lt 3 ]; do
  kubectl get pods -n istio-system
  count_ready=$(kubectl get pods -n istio-system -l="app in (istio-ingressgateway,istiod)" -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep true | wc -w)
  sleep 5
done
echo "moving on, $count_ready pods ready"

kubectl label namespace default istio.io/rev=$revision_hyphenated --overwrite=true
kubectl get namespace -L istio.io/rev

$script_path/show-istio-objects.sh
;;



3)
kubectl rollout restart -n default deployments
echo going to settle for 15 seconds
sleep 15
;;


4)
timeout 120s kubectl delete -n istio-system iop/istio-control-plane
if [ $? -eq 0 ]; then
  echo "iop default deleted normally"
else
  echo "iop default not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
  echo going to settle for 15 seconds
  sleep 30
fi

# no explicit way to delete operator that is non-revisioned
if [[ $istiover =~ ^1.6 ]] ; then 
  kubectl get deployment -n istio-operator
  echo "since this is 1.6, you cannot have a --revision flag and there is only a single operator"
  echo "therefore we are not deleting the operator.  Deleting the iop will delete all relevant default control plane objects"
else
  # we cannot use this, because the non-rev operator was installed
  #$script_path/istio-$istiover/bin/istioctl operator remove --revision ${revision_hyphenated}
  operator_name_old=istio-operator
  echo the operator_name_old is $operator_name_old
  kubectl delete deployment/$operator_name_old -n istio-operator
  kubectl delete service/$operator_name_old -n istio-operator
  echo going to settle for 15 seconds
  sleep 15
fi

if [[ $istiover =~ ^1.6 ]] ; then 
  echo "for istio 1.6, only have single operator and deleting the iop is sufficient to remove all the default control plane objects"
else
  echo "we need to do x uninstall or older control plane objects will not be deleted"
  $script_path/istio-$istiover/bin/istioctl x uninstall --filename $script_path/istio-operator-$istiover-no-revision.yaml
  echo going to settle for 10 seconds
  sleep 10
fi

echo going to settle for 15 seconds
sleep 15
$script_path/show-istio-objects.sh
;;


99)

# no explicit way to delete operator that is non-revisioned
if [[ $istiover =~ ^1.6 ]] ; then 
  kubectl get deployment -n istio-operator
  echo "since this is 1.6, you cannot have a --revision flag and there is only a single operator"
  echo "therefore we are not deleting the operator.  Deleting the iop will delete all relevant default control plane objects"
else
  kubectl delete deployment/istio-operator -n istio-operator
  kubectl delete service/istio-operator -n istio-operator
  echo going to settle for 15 seconds
  sleep 15
fi

timeout 120s kubectl delete -n istio-system iop/istio-control-plane
if [ $? -eq 0 ]; then
  echo "iop default deleted normally"
else
  echo "iop default not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
  echo going to settle for 15 seconds
  sleep 30
fi

if [[ $istiover =~ ^1.6 ]] ; then 
  echo "for istio 1.6, only have single operator and deleting the iop is sufficient to remove all the default control plane objects"
else
  #echo "do we need to do x uninstall ?"
  $script_path/istio-$istiover/bin/istioctl x uninstall --filename $script_path/istio-operator-$istiover-no-revision.yaml
  echo going to settle for 10 seconds
  sleep 10
fi

$script_path/show-istio-objects.sh
;;



show)
$script_path/show-istio-objects.sh
;;

purge)
# 1.6 does not have purge
$script_path/purge-all-istio.sh 1.10.2
;;


quit|q)
exit 0
;;


esac



done # loop for menu
