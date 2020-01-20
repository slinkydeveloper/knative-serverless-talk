#!/bin/bash

kn service create rust-factorial-function --image="docker.io/slinkydeveloper/rust-factorial-function"

# https://github.com/knative/eventing-contrib/blob/master/cmd/event_display/main.go
kn service create event-logger --image="docker.io/slinkydeveloper/event_display"
