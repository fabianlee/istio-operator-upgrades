
#
# installing 1.7.5
#
# https://istio.io/v1.7/docs/setup/upgrade/
# https://banzaicloud.com/blog/istio-canary-upgrade/

export istiover=1.7.5
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istiover sh -

istio-$istiover/bin/istioctl x precheck

istio-$istiover/bin/istioctl operator init --revision 1-7-5 --hub gcr.io/istio-release
Using operator Deployment image: docker.io/istio/operator:1.7.5
2021-08-28T22:13:45.885707Z	info	proto: tag has too few fields: "-"
✔ Istio operator installed                                                                                              
✔ Installation complete

# create istio-system which does not exist yet
kubectl get all -n istio-operator

# only do if this is a new deployment, not for upgrade!!!
# it will be picked up from iop
# kubectl apply -f istio-operator/istio-operator-1.7.5.yaml

# until you see "Ingress gateways installed"
istio-operator/show-istio-operator-logs.sh 1-7-5

# then wait for all components to be 'Running'
watch -n2 kubectl get pods -n istio-system
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-6bdd7687b6-86cls   1/1     Running   0          2m22s
istiod-1-7-5-649b69468-ptjrj            1/1     Running   0          2m34s

# 'istio-ingressgateway' will be on EXTERNAL-IP
kubectl get services -n istio-system

# apply namespace label istio.io/rev
istio-operator/namespace-labels.sh 1-7-5

istio-operator/show-istio-versions.sh

# 'my-istio-deployment' and 'my-istio-service'
kubectl apply -f istio-operator/my-istio-deployment-and-service.yaml
# 'my-istio-virtualservice'
kubectl apply -f istio-operator/my-istio-virtualservice.yaml
# 'istio-ingressgateway' referencing 'tls-credential' secret
kubectl apply -f istio-operator/my-istio-ingress-gateway.yaml

# rolling deployment restart, then wait for it to finish
kubectl rollout restart -n default deployment/my-istio-deployment
kubectl rollout status  -n default deployment my-istio-deployment

# to do entire namespace!
# kubectl rollout restart deployment -n default

istio-operator/show-istio-versions.sh




#
# now do upgrade to 1.7.6
#
cd ~/k8s
export istiover=1.7.6
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istiover sh -
istio-$istiover/bin/istioctl x precheck

# operator will come from docker.io unless you override
istio-$istiover/bin/istioctl operator init --revision 1-7-6 --hub gcr.io/istio-release
Using operator Deployment image: gcr.io/istio-release/operator:1.7.6
2021-08-28T22:43:30.572127Z	info	proto: tag has too few fields: "-"
✔ Istio operator installed                                                                                              
✔ Installation complete

# wait for 'Ingress gateways installed'
# new 'istio-operator-1-7-6'
istio-operator/show-istio-operator-logs.sh 1-7-6

# wait for a couple of minutes
# istio-operator namespace will have tag 'operator.istio.io/version=1.7.6'
# ingressgateway will have new 1.7.6 image and tag 'operator.istio.io/version=1.7.6'
# new istio-sidecar-injector-1-7-6
# iop will still be 1-7-5
istio-operator/show-istio-versions.sh

# SKIP do not do!  this will confuse the operators and ingressgateway into getting mixed!
# this changes revision in iop and image of ingress gateway
# kubectl apply -f istio-operator/istio-operator-1.7.6.yaml

# apply namespace label istio.io/rev
istio-operator/namespace-labels.sh 1-7-6

# rolling deployment restart and wait for ready
kubectl rollout restart -n default deployment/my-istio-deployment
kubectl rollout status deployment my-istio-deployment

# envoy proxy now at new version, envoy proxy will move to 1.7.6
kubectl describe pod -lapp=my-istio-deployment | grep 'Image:'

#
# uninstall the old control plane 1-7-5
#

# will see both 1-7-5 and 1-7-6 control planes
# sidecar, istiod, operator
$ istio-operator/show-istio-versions.sh

$ istio-1.7.5/bin/istioctl x uninstall --revision 1-7-5
  Removed HorizontalPodAutoscaler:istio-system:istiod-1-7-5.
  Removed PodDisruptionBudget:istio-system:istiod-1-7-5.
  Removed Deployment:istio-operator:istio-operator-1-7-5.
  Removed Deployment:istio-system:istiod-1-7-5.
  Removed Service:istio-operator:istio-operator-1-7-5.
  Removed Service:istio-system:istiod-1-7-5.
  Removed ConfigMap:istio-system:istio-1-7-5.
  Removed ConfigMap:istio-system:istio-sidecar-injector-1-7-5.
  Removed ServiceAccount:istio-operator:istio-operator-1-7-5.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.6-1-7-5.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.7-1-7-5.
  Removed EnvoyFilter:istio-system:stats-filter-1.6-1-7-5.
  Removed EnvoyFilter:istio-system:stats-filter-1.7-1-7-5.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.6-1-7-5.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.7-1-7-5.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.6-1-7-5.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.7-1-7-5.
  Removed MutatingWebhookConfiguration::istio-sidecar-injector-1-7-5.
object: MutatingWebhookConfiguration::istio-sidecar-injector-1-7-5 is not being deleted because it no longer exists
  Removed MutatingWebhookConfiguration::istio-sidecar-injector-1-7-5.
✔ Uninstall complete                                          


# switch over iop to new revision
kubectl patch -n istio-system --type merge iop/istio-control-plane -p '{"spec":{"revision":"1-7-6"}}'

# wait for state to go HEALTHY with 1-7-6
watch kubectl get -n istio-system iop

# only 1-7-6 will be present
istio-operator/show-istio-versions.sh




#
# now do upgrade to 1.7.8
#
cd ~/k8s
export istiover=1.7.8
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istiover sh -
istio-$istiover/bin/istioctl x precheck

# operator will come from docker.io unless you override
istio-$istiover/bin/istioctl operator init --revision 1-7-8 --hub gcr.io/istio-release
Using operator Deployment image: gcr.io/istio-release/operator:1.7.8
2021-08-28T22:43:30.572127Z	info	proto: tag has too few fields: "-"
✔ Istio operator installed                                                                                              
✔ Installation complete

# wait for 'Ingress gateways installed'
# new 'istio-operator-1-7-8'
istio-operator/show-istio-operator-logs.sh 1-7-8

# wait for a couple of minutes
# istio-operator namespace will have tag 'operator.istio.io/version=1.7.8'
# ingressgateway will have new 1.7.6 image and tag 'operator.istio.io/version=1.7.8'
# new istio-sidecar-injector-1-7-8
# iop will still be 1-7-6
istio-operator/show-istio-versions.sh

# SKIP do not do!  this will confuse the operators and ingressgateway into getting mixed!
# this changes revision in iop and image of ingress gateway
# kubectl apply -f istio-operator/istio-operator-1.7.6.yaml

# apply namespace label istio.io/rev
istio-operator/namespace-labels.sh 1-7-8

# rolling deployment restart and wait for ready
kubectl rollout restart -n default deployment/my-istio-deployment
kubectl rollout status deployment my-istio-deployment

# envoy proxy now at new version, envoy proxy will go to 1.7.8
kubectl describe pod -lapp=my-istio-deployment | grep 'Image:'

#
# uninstall the old control plane 1-7-6
#

# will see both 1-7-6 and 1-7-8 control planes
istio-operator/show-istio-versions.sh

istio-1.7.6/bin/istioctl x uninstall --revision 1-7-6
  Removed HorizontalPodAutoscaler:istio-system:istiod-1-7-6.
  Removed PodDisruptionBudget:istio-system:istiod-1-7-6.
  Removed Deployment:istio-operator:istio-operator-1-7-6.
  Removed Deployment:istio-system:istiod-1-7-6.
  Removed Service:istio-operator:istio-operator-1-7-6.
  Removed Service:istio-system:istiod-1-7-6.
  Removed ConfigMap:istio-system:istio-1-7-6.
  Removed ConfigMap:istio-system:istio-sidecar-injector-1-7-6.
  Removed ServiceAccount:istio-operator:istio-operator-1-7-6.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.6-1-7-6.
  Removed EnvoyFilter:istio-system:metadata-exchange-1.7-1-7-6.
  Removed EnvoyFilter:istio-system:stats-filter-1.6-1-7-6.
  Removed EnvoyFilter:istio-system:stats-filter-1.7-1-7-6.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.6-1-7-6.
  Removed EnvoyFilter:istio-system:tcp-metadata-exchange-1.7-1-7-6.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.6-1-7-6.
  Removed EnvoyFilter:istio-system:tcp-stats-filter-1.7-1-7-6.
  Removed MutatingWebhookConfiguration::istio-sidecar-injector-1-7-6.
object: MutatingWebhookConfiguration::istio-sidecar-injector-1-7-6 is not being deleted because it no longer exists
  Removed MutatingWebhookConfiguration::istio-sidecar-injector-1-7-6.
✔ Uninstall complete                      


# switch over iop to new revision
kubectl patch -n istio-system --type merge iop/istio-control-plane -p '{"spec":{"revision":"1-7-8"}}'

# wait for state to go from RECONCILING to HEALTHY for 1-7-8, can take 90 seconds
watch kubectl get -n istio-system iop

# only 1-7-8 will be present
istio-operator/show-istio-versions.sh

