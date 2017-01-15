#!/bin/bash

if [ ! -z "$CONSUL_PREFIX" ]; then
  echo -e "Checking for Consul service"
  until $(curl --output /dev/null --silent --head --fail http://${CONSUL_HTTP_ADDR}/v1/agent/self); do
    printf '.'
    sleep 1
  done

  if [ ! -z "$CONSUL_SERVICE" ]; then
    echo -e "Checking service '${CONSUL_SERVICE}' for members"
    until [ "$(echo $(curl -s http://${CONSUL_HTTP_ADDR}/v1/health/service/${CONSUL_SERVICE}) | jq '. | length')" -gt 0 ]; do
      printf '.'
      sleep 1
    done

    export CONSUL_SESSION="$(echo $(curl -s -X PUT -d "{\"Name\":\"${HOSTNAME}\",\"ttl\":\"300s\",\"behavior\":\"delete\"}" http://${CONSUL_HTTP_ADDR}/v1/session/create) | jq -r .ID)"

    echo 'Waiting for healthy nodes'
    until [ "$(echo $(curl -s http://${CONSUL_HTTP_ADDR}/v1/health/service/${CONSUL_SERVICE}?passing) | jq '. | length')" -gt 0 ]; do

      if $(curl -s -X PUT http://${CONSUL_HTTP_ADDR}/v1/kv/service/${CONSUL_SERVICE}/leader?acquire=${CONSUL_SESSION}); then
        export CLUSTER_SEED=true
        echo 'This node is the first in the cluster'
        break
      fi

      printf '.'
      sleep 1
    done

    if [ ! "${CLUSTER_SEED}" ]; then
      curl -s http://${CONSUL_HTTP_ADDR}/v1/session/destroy/${CONSUL_SESSION}
      export RABBITMQ_CLUSTER_NODES="rabbit@$(echo $(curl -s http://${CONSUL_HTTP_ADDR}/v1/health/service/${CONSUL_SERVICE}?passing) | jq -r .[0].Node.Node).node.consul"
      echo -e "Setting cluster node: ${RABBITMQ_CLUSTER_NODES}"
    fi

    export RABBITMQ_USE_LONGNAME=true
    export RABBITMQ_NODENAME="rabbit@${HOSTNAME}.node.consul"
    
  fi
  if [ ! -z "$CONSUL_DEBUG" ]; then
    /usr/local/bin/envconsul -prefix $CONSUL_PREFIX -sanitize -upcase -once env
  fi
  /usr/local/bin/envconsul -prefix $CONSUL_PREFIX -sanitize -upcase -once /usr/local/bin/docker-entrypoint.sh "$@"
else
  /usr/local/bin/docker-entrypoint.sh "$@"
fi
