#!/usr/bin/env bash

sed "s/namespace: .*/namespace: strimzi/" apps/strimzi/strimzi-cluster-operator-0.40.0.yaml.original > apps/strimzi/strimzi-cluster-operator-0.40.0.yaml
