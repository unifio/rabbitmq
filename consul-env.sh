#!/bin/bash

if [ ! -z "$CONSUL_PREFIX" ]; then
  if [ ! -z "$CONSUL_SERVICE" ]; then
    export RABBITMQ_USE_LONGNAME=true
    export RABBITMQ_NODENAME="rabbit@${HOSTNAME}.node.consul"
    export RABBITMQ_CLUSTER_NODES="rabbit@`echo $(curl -s http://${CONSUL_HTTP_ADDR}/v1/health/service/${CONSUL_SERVICE}?passing) | jq -r .[0].Node.Node`.node.consul"
    echo -e "Setting RabbitMQ cluster nodes: ${RABBITMQ_CLUSTER_NODES}"
  fi
  if [ ! -z "$CONSUL_DEBUG" ]; then
    /usr/local/bin/envconsul -prefix $CONSUL_PREFIX -sanitize -upcase -once env
  fi
  /usr/local/bin/envconsul -prefix $CONSUL_PREFIX -sanitize -upcase -once /usr/local/bin/docker-entrypoint.sh "$@"
else
  /usr/local/bin/docker-entrypoint.sh "$@"
fi
