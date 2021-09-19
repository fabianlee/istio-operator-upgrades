
kubectl create ns istio-system
cd ~/k8s/istio-operator
./create-k8s-tls-secret.sh


#
# installing 1.8.1
# https://banzaicloud.com/blog/istio-1.8/

cd ~/k8s
export istiover=1.8.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istiover sh -

istio-$istiover/bin/istioctl x precheck

istio-$istiover/bin/istioctl operator init --revision 1-8-1 --hub gcr.io/istio-release
Using operator Deployment image: docker.io/istio/operator:1.8.1
2021-08-28T22:13:45.885707Z	info	proto: tag has too few fields: "-"
✔ Istio operator installed                                                                                              
✔ Installation complete

# should be new operator, deployment.apps/istio-operator-1-8-1
kubectl get all -n istio-operator

# only do if this is a new deployment, not for upgrade!!!
# it will be picked up from iop
kubectl apply -f istio-operator/istio-operator-1.8.1.yaml

# until you see "Ingress gateways installed"
istio-operator/show-istio-operator-logs.sh 1-8-1

# then wait for all components to be 'Running'
watch -n2 kubectl get pods -n istio-system
NAME                                    READY   STATUS    RESTARTS   AGE
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-86847475b6-wsmgv   1/1     Running   0          62s
istiod-1-7-8-555d98568c-2zmbs           1/1     Running   2          12h
istiod-1-8-1-69f875d865-prbcs           1/1     Running   0          103s

# 'istio-ingressgateway' will be on EXTERNAL-IP
kubectl get services -n istio-system

# apply namespace label istio.io/rev
istio-operator/namespace-labels.sh 1-8-1

istio-operator/show-istio-versions.sh

# 'my-istio-deployment' and 'my-istio-service'
kubectl apply -f istio-operator/my-istio-deployment-and-service.yaml
# 'my-istio-virtualservice'
kubectl apply -f istio-operator/my-istio-virtualservice.yaml
# 'istio-ingressgateway' referencing 'tls-credential' secret
kubectl apply -f istio-operator/my-istio-ingress-gateway.yaml

# rolling deployment restart, then wait for it to finish
# to do entire namespace!
# kubectl rollout restart deployment -n default
kubectl rollout restart -n default deployment/my-istio-deployment
kubectl rollout status  -n default deployment my-istio-deployment

# envoy proxy will roll to 1.8.1
watch kubectl describe pod -lapp=my-istio-deployment | grep 'Image:'




#
# uninstall the old control plane 1-7-8
#

# will see both 1-7-8 and 1-8-1 control planes
# operator, sidecar, istiod, operator
$ istio-operator/show-istio-versions.sh

$ istio-1.7.8/bin/istioctl x uninstall --revision 1-7-8
  Removed HorizontalPodAutoscaler:istio-system:istiod-1-7-8.
  Removed PodDisruptionBudget:istio-system:istiod-1-7-8.
  Removed Deployment:istio-operator:istio-operator-1-7-8.
  Removed Deployment:istio-system:istiod-1-7-8.
  Removed Service:istio-operator:istio-operator-1-7-8.
  Removed Service:istio-system:istiod-1-7-8.
  Removed ConfigMap:istio-system:istio-1-7-8.
  Removed ConfigMap:istio-system:istio-sidecar-injector-1-7-8.
  Removed ServiceAccount:istio-operator:istio-operator-1-7-8.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.6-1-7-8.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.7-1-7-8.
  Removed EnvoyFilter:istio-system:stats-filter-1.6-1-7-8.
  Removed EnvoyFilter:istio-system:stats-filter-1.7-1-7-8.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.6-1-7-8.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.7-1-7-8.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.6-1-7-8.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.7-1-7-8.
  Removed MutatingWebhookConfiguration::istio-sidecar-injector-1-7-8.
object: MutatingWebhookConfiguration::istio-sidecar-injector-1-7-8 is not being deleted because it no longer exists
  Removed MutatingWebhookConfiguration::istio-sidecar-injector-1-7-8.
✔ Uninstall complete                            

# remove vestige iop
istio-operator/show-istio-versions.sh
timeout 90s kubectl delete istiooperators.install.istio.io -n istio-system istio-control-plane
[ $? -eq 0 ] || kubectl patch -n istio-system --type merge iop/istio-control-plane -p '{"metadata":{"finalizers":null}}'

# should only be HEALTHY 1-8-1
kubectl get -n istio-system iop

# only 1-8-1 will be present
istio-operator/show-istio-versions.sh
kubectl get -n istio-system all | grep 1-7
kubectl get -n istio-operator all | grep 1-7


#
# now do upgrade to 1.8.2
#
cd ~/k8s
export istiover=1.8.2
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istiover sh -
istio-$istiover/bin/istioctl x precheck

# operator will come from docker.io unless you override
istio-$istiover/bin/istioctl operator init --revision 1-8-2 --hub gcr.io/istio-release
Using operator Deployment image: gcr.io/istio-release/operator:1.8.2
2021-08-28T22:43:30.572127Z	info	proto: tag has too few fields: "-"
✔ Istio operator installed                                                                                              
✔ Installation complete

# wait for 'Reconciling IstioOperator'
# new 'istio-operator-1-8-2'
istio-operator/show-istio-operator-logs.sh 1-8-2

# wait for a couple of minutes but no other objects created
# istio-operator namespace will have tag 'operator.istio.io/version=1.8.2'
# but ingressgateway not changed, no new sidecar injector, and no iop?  i was not expecting this!
# is 1.8 canary upgrade different???
istio-operator/show-istio-versions.sh

# apply new iop
kubectl apply -f istio-operator/istio-operator-1.8.2.yaml

# wait for 'Ingress gateways installed'
istio-operator/show-istio-operator-logs.sh 1-8-2

# now ingressgateway is changed to 1.8.2
# sidecar injector and iop for 1-8-2 and istiod 1-8-2
istio-operator/show-istio-versions.sh


# apply namespace label istio.io/rev
istio-operator/namespace-labels.sh 1-8-2

# rolling deployment restart and wait for ready
kubectl rollout restart -n default deployment/my-istio-deployment
kubectl rollout status deployment my-istio-deployment

# envoy proxy now at new version, envoy proxy will roll to 1.8.2
kubectl describe pod -lapp=my-istio-deployment | grep 'Image:'

#
# uninstall the old control plane 1-8-1
#

# will see both 1-8-1 and 1-8-2 control planes
istio-operator/show-istio-versions.sh

istio-1.8.1/bin/istioctl x uninstall --revision 1-8-1
 Removed HorizontalPodAutoscaler:istio-system:istiod-1-8-1.
  Removed PodDisruptionBudget:istio-system:istiod-1-8-1.
  Removed Deployment:istio-operator:istio-operator-1-8-1.
  Removed Deployment:istio-system:istiod-1-8-1.
  Removed Service:istio-operator:istio-operator-1-8-1.
  Removed Service:istio-system:istiod-1-8-1.
  Removed ConfigMap:istio-system:istio-1-8-1.
  Removed ConfigMap:istio-system:istio-sidecar-injector-1-8-1.
  Removed Pod:istio-system:istiod-1-8-1-69f875d865-prbcs.
  Removed ServiceAccount:istio-operator:istio-operator-1-8-1.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.6-1-8-1.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.7-1-8-1.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.8-1-8-1.
  Removed EnvoyFilter:istio-system:stats-filter-1.6-1-8-1.
  Removed EnvoyFilter:istio-system:stats-filter-1.7-1-8-1.
  Removed EnvoyFilter:istio-system:stats-filter-1.8-1-8-1.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.6-1-8-1.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.7-1-8-1.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.8-1-8-1.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.6-1-8-1.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.7-1-8-1.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.8-1-8-1.
  Removed MutatingWebhookConfiguration::istio-sidecar-injector-1-8-1.
  Removed ClusterRole::istio-operator-1-8-1.
  Removed ClusterRoleBinding::istio-operator-1-8-1.
✔ Uninstall complete                                       



# remove vestige iop
istio-operator/show-istio-versions.sh
timeout 90s kubectl delete istiooperators.install.istio.io -n istio-system istio-control-plane-1-8-1
[ $? -eq 0 ] || kubectl patch -n istio-system --type merge iop/istio-control-plane-1-8-1 -p '{"metadata":{"finalizers":null}}'

# should only be HEALTHY 1-8-2
kubectl get -n istio-system iop

# only 1-8-2 will be present
istio-operator/show-istio-versions.sh
kubectl get -n istio-system all | grep 1-8-1
kubectl get -n istio-operator all | grep 1-8-1


