#!/bin/bash
script_path=$( cd $(dirname "${BASH_SOURCE[0]}") && pwd)

if [ $# -lt 2 ]; then
  echo "Usage: <old_istioVersion> <new_istioVersion"
  echo "Example: 1.7.5 1.7.6"
  echo "Example: 1.7.6 1.8.1"
  echo "Example: 1.8.1 1.10.2"
  exit 1
fi

istiover_old="$1"
istiover_new="$2"
revision_hyphenated_old=${istiover_old//\./\-}
revision_hyphenated_new=${istiover_new//\./\-}

# make sure upgrade is to at least 1.7
if [[ $istiover_new =~ ^1.6 ]] ; then 
  echo "ERROR this script cannot handle 1.6 upgrades because the opeator does not support the --revision flag"
  exit 1
fi


function show_menu() {
echo ""
echo "===== MENU ============================"
echo "1) deploy $istiover_new fully revisioned control plane"
echo "2) rolling restart of deployments in default ns"
echo "3) delete revisioned $istiover_old control plane and operator"
echo ""
echo "show ) show all istio objects"
echo "purge) purge all istio objects and operators using istioctl $istiover_new"
echo "quit ) quit program"
echo ""
}


##### MAIN #############################

# check for manifest files existing up-front
[ -f $script_path/istio-operator-${istiover_old}.yaml ] || { echo "ERROR finding yaml for $istionver_old"; exit 3; }
[ -f $script_path/istio-operator-${istiover_new}.yaml ] || { echo "ERROR finding yaml for $istionver_new"; exit 3; }


while [ 1==1 ]; do

show_menu
read -p "action: " answer

# which?
case $answer in


1)

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
while [ $count_ready -lt 3 ]; do
  kubectl get pods -n istio-system
  count_ready=$(kubectl get pods -n istio-system -l="app in (istio-ingressgateway,istiod)" -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep true | wc -w)
  sleep 5
done
echo "moving on, $count_ready pods ready"

kubectl label namespace default istio.io/rev=$revision_hyphenated_new --overwrite=true
kubectl get namespace -L istio.io/rev

$script_path/show-istio-objects.sh
;;


2)
kubectl rollout restart -n default deployments
echo going to settle for 15 seconds
sleep 15
;;


3)

# delete iop, which should cascade deletion of control plane objects
timeout 120s kubectl delete -n istio-system iop/istio-control-plane-${revision_hyphenated_old}
if [ $? -eq 0 ]; then
  echo "iop $revision_hyphenated_old deleted normally"
else
  echo "iop $revision_hyphenated_old not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane-${revision_hyphenated_old} -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
fi
echo going to settle for 15 seconds
sleep 15

if [[ $istiover_old =~ ^1.6 ]] ; then 
  read -r -d '' cmd <<EOF
  kubectl get deployment -n istio-operator -o=jsonpath='{.items[?(@.metadata.labels.operator\.istio\.io/version=="$istiover_old")].metadata.name}'
EOF
  operator_name_old=$($cmd | tr -d "'")
  echo the operator_name_old is $operator_name_old
  kubectl delete deployment/$operator_name_old -n istio-operator
  kubectl delete service/$operator_name_old -n istio-operator
else
  # remove operator
  $script_path/istio-$istiover_old/bin/istioctl operator remove --revision ${revision_hyphenated_old}
  # remove related objects
  $script_path/istio-$istiover_old/bin/istioctl x uninstall --revision ${revision_hyphenated_old} -y
fi
echo going to settle for 10 seconds
sleep 10

$script_path/show-istio-objects.sh
;;


99)

# construct jsonpath filter in heredoc to avoid complex escaping
# we lookup operator name with revision instead of name because it could have been created with revision or default

#read -r -d '' cmd <<EOF
#kubectl get deployment \
#-n istio-system \
#--output jsonpath='{.items[?(@.spec.selector.matchLabels.istio\.io/rev=="$revision_hyphenated_old")].metadata.name}'
#EOF
operator_count=$(kubectl get deployment -n istio-operator | wc -l)
if [ $operator_count -gt 1 ]; then
  read -r -d '' cmd <<EOF
  kubectl get deployment -n istio-operator -o=jsonpath='{.items[?(@.metadata.labels.operator\.istio\.io/version=="$istiover_old")].metadata.name}'
EOF
  operator_name_old=$($cmd | tr -d "'")
  echo the operator_name_old is $operator_name_old
  
  kubectl delete deployment/$operator_name_old -n istio-operator
  kubectl delete service/$operator_name_old -n istio-operator
else
  echo "there was less than 2 operators, so not able to proceed with any operator deletion"
fi

# delete iop, which should cascade deletion of control plane objects
timeout 120s kubectl delete -n istio-system iop/istio-control-plane-${revision_hyphenated_old}
if [ $? -eq 0 ]; then
  echo "iop $revision_hyphenated_old deleted normally"
else
  echo "iop $revision_hyphenated_old not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/istio-control-plane-${revision_hyphenated_old} -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
fi
echo going to settle for 15 seconds
sleep 15

# relevant control plane objects deleted as part of iop deletion

$script_path/show-istio-objects.sh
;;



show)
$script_path/show-istio-objects.sh
;;

purge)
$script_path/purge-all-istio.sh $istiover_new

for the_iop in istio-control-plane istio-control-plane-${revision_hyphenated_old} istio-control-plane-${revision_hyphenated_new}; do

timeout 60s kubectl delete -n istio-system iop/$the_iop
if [ $? -eq 0 ]; then
  echo "iop $the_iop deleted normally"
else
  echo "iop $the_iop not deleted normally after waiting 90 seconds, going to empty metadata.finalizers list"
  kubectl get istiooperator.install.istio.io/$the_iop -n istio-system -o json | jq '.metadata.finalizers = []' | kubectl replace -f -
fi

done


;;


quit|q)
exit 0
;;


esac



done # loop for menu
