#!/bin/bash

CONSUL_HTTP_ADDR=${ENV_CONSUL_HOST}:${ENV_CONSUL_PORT} consul services register -address=minio.${ENV_CLUSTER_NAMESPACE}.svc.cluster.local -name=minio.npool.top -port=9000
if [ ! $? -eq 0 ]; then
  echo "FAIL TO REGISTER ME TO CONSUL"
  exit 1
fi

/usr/bin/docker-entrypoint.sh $@
