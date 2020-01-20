#!/usr/bin/env bash

set -e

# Turn colors in this script off by setting the NO_COLOR variable in your
# environment to any value:
#
# $ NO_COLOR=1 test.sh
NO_COLOR=${NO_COLOR:-""}
if [ -z "$NO_COLOR" ]; then
  header=$'\e[1;33m'
  reset=$'\e[0m'
else
  header=''
  reset=''
fi

strimzi_version=`curl https://github.com/strimzi/strimzi-kafka-operator/releases/latest |  awk -F 'tag/' '{print $2}' | awk -F '"' '{print $1}' 2>/dev/null`
serving_version="v0.11.0"
eventing_version="v0.11.0"
istio_version="1.3.5"

function header_text {
  echo "$header$*$reset"
}

header_text             "Starting Knative on kind!"
header_text "Using Strimzi Version:                  ${strimzi_version}"
header_text "Using Knative Serving Version:          ${serving_version}"
header_text "Using Knative Eventing Version:         ${eventing_version}"
header_text "Using Istio Version:                    ${istio_version}"

kind create cluster --wait 5m
kubectl cluster-info

header_text "Strimzi install"
kubectl create namespace kafka
curl -L "https://github.com/strimzi/strimzi-kafka-operator/releases/download/${strimzi_version}/strimzi-cluster-operator-${strimzi_version}.yaml" \
  | sed 's/namespace: .*/namespace: kafka/' \
  | kubectl -n kafka apply -f -

header_text "Applying Strimzi Cluster file"
kubectl -n kafka apply -f "https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/${strimzi_version}/examples/kafka/kafka-persistent-single.yaml"
header_text "Waiting for Strimzi to become ready"
sleep 5; while echo && kubectl get pods -n kafka | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Creating demo topic"
kubectl apply -f - << EOF
apiVersion: kafka.strimzi.io/v1beta1
kind: KafkaTopic
metadata:
  name: demo
  namespace: kafka
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 10
  replicas: 1
EOF

header_text "Setting up Istio"
# kubectl apply --filename "https://raw.githubusercontent.com/knative/serving/${serving_version}/third_party/istio-${istio_version}/istio-crds.yaml" &&
#     curl -L "https://raw.githubusercontent.com/knative/serving/${serving_version}/third_party/istio-${istio_version}/istio.yaml" \
#         | sed 's/LoadBalancer/NodePort/' \
#         | kubectl apply --filename -
###curl -L "https://gist.githubusercontent.com/matzew/8772d5095a93b04d1de6f07319db4ba9/raw/afd20d5b342cb2f7ddccb532ea0f19f431bebe79/matzew-istio-lean.yaml" \
curl -L "https://raw.githubusercontent.com/knative/serving/${serving_version}/third_party/istio-${istio_version}/istio-lean.yaml" \
    | sed 's/LoadBalancer/NodePort/' \
    | kubectl apply --filename -

# Label the default namespace with istio-injection=enabled.
header_text "Labeling default namespace w/ istio-injection=enabled"
kubectl label namespace default istio-injection=enabled
header_text "Waiting for istio to become ready"
sleep 5; while echo && kubectl get pods -n istio-system | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Setting up Knative Serving"

 n=0
   until [ $n -ge 2 ]
   do
      kubectl apply --filename https://github.com/knative/serving/releases/download/${serving_version}/serving.yaml && break
      n=$[$n+1]
      sleep 5
   done

header_text "Waiting for Knative Serving to become ready"
sleep 5; while echo && kubectl get pods -n knative-serving | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Setting up Knative Eventing"
kubectl apply --filename https://github.com/knative/eventing/releases/download/${eventing_version}/release.yaml
# kubectl apply --filename https://storage.googleapis.com/knative-nightly/eventing/latest/release.yaml

header_text "Applying some permissions stuff"
kubectl -n default create serviceaccount eventing-broker-ingress
kubectl -n default create serviceaccount eventing-broker-filter
kubectl -n default create rolebinding eventing-broker-ingress \
  --clusterrole=eventing-broker-ingress \
  --serviceaccount=default:eventing-broker-ingress
kubectl -n default create rolebinding eventing-broker-filter \
  --clusterrole=eventing-broker-filter \
  --serviceaccount=default:eventing-broker-filter
  kubectl -n knative-eventing create rolebinding eventing-config-reader-default-eventing-broker-ingress \
  --clusterrole=eventing-config-reader \
  --serviceaccount=default:eventing-broker-ingress
kubectl -n knative-eventing create rolebinding eventing-config-reader-default-eventing-broker-filter \
  --clusterrole=eventing-config-reader \
  --serviceaccount=default:eventing-broker-filter

header_text "Waiting for Knative Eventing to become ready"
sleep 5; while echo && kubectl get pods -n knative-eventing | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Setting up Knative Apache Kafka Source"
kubectl apply --filename https://github.com/knative/eventing-contrib/releases/download/${eventing_version}/kafka-source.yaml
# kubectl apply --filename https://storage.googleapis.com/knative-nightly/eventing-contrib/latest/kafka-source.yaml

header_text "Waiting for Knative Apache Kafka Source to become ready"
sleep 5; while echo && kubectl get pods -n knative-sources | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Setting up Knative Apache Kafka Channel"
kubectl apply --filename https://github.com/knative/eventing-contrib/releases/download/${eventing_version}/kafka-channel.yaml
# kubectl apply --filename https://storage.googleapis.com/knative-nightly/eventing-contrib/latest/kafka-channel.yaml

# Configure the config-kafka config map
kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-kafka
  namespace: knative-eventing
data:
  bootstrapServers: my-cluster-kafka-bootstrap.kafka.svc:9092
EOF
kubectl delete pods -n knative-eventing --all

header_text "Waiting for Knative Apache Kafka Channel to become ready"
sleep 5; while echo && kubectl get pods -n knative-eventing | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done
