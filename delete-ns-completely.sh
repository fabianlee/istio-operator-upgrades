# for entirely deleting isto-system and istio-operator namespaces if necessary
function delete_entire_istio_ns() {

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

} # function

