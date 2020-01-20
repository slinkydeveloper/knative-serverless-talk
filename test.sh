#!/bin/bash

kubectl run curl \
  --image=curlimages/curl --rm=true --restart=Never -ti -- \
  -H 'content-type: application/json' \
  -H 'ce-type: stuff.demo' \
  -H 'ce-specversion: 1.0' \
  -H 'ce-source: www.example.com' \
  -H 'ce-id: 2' \
  -d '{"value":2}' \
  -X POST -v http://source-to-factorial-kn-channel.default.svc.cluster.local

kubectl run kafka-producer \
 -ti --image=strimzi/kafka:latest-kafka-2.3.1 \
 --rm=true --restart=Never -- bin/kafka-console-producer.sh \
 --broker-list my-cluster-kafka-bootstrap.kafka.svc:9092 \
 --topic demo
