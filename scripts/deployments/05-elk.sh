#!/bin/bash
set -euo pipefail

# Deploy Elasticsearch + Kibana + Filebeat (pod log collection from every node)

dir="$(dirname "${BASH_SOURCE[0]}")"
source "$dir/deployments.env"
export DOMAIN ELK_VERSION ES_DATA_PATH
vars='${DOMAIN} ${ELK_VERSION} ${ES_DATA_PATH}'

kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl -n logging get secret elk-credentials >/dev/null 2>&1; then
    kubectl -n logging create secret generic elk-credentials \
        --from-literal=elastic="$(openssl rand -hex 16)" \
        --from-literal=kibana_system="$(openssl rand -hex 16)"
fi

elastic_pw=$(kubectl -n logging get secret elk-credentials -o jsonpath='{.data.elastic}' | base64 -d)
kibana_pw=$(kubectl -n logging get secret elk-credentials -o jsonpath='{.data.kibana_system}' | base64 -d)

envsubst "$vars" < "$dir/manifests/elasticsearch.yaml" | kubectl apply -f -
kubectl -n logging rollout status deploy/elasticsearch --timeout=10m

echo "Setting kibana_system password..."
kubectl -n logging exec deploy/elasticsearch -- curl -fsS -u "elastic:$elastic_pw" \
    -H 'Content-Type: application/json' \
    -X POST localhost:9200/_security/user/kibana_system/_password \
    -d "{\"password\":\"$kibana_pw\"}" >/dev/null

envsubst "$vars" < "$dir/manifests/kibana.yaml" | kubectl apply -f -
envsubst "$vars" < "$dir/manifests/filebeat.yaml" | kubectl apply -f -

kubectl -n logging rollout status deploy/kibana --timeout=10m
kubectl -n logging rollout status ds/filebeat --timeout=5m

echo "✓ http://kibana.$DOMAIN  user: elastic"
echo "Password: $elastic_pw"
echo "Create a data view for 'filebeat-*' (Stack Management > Data Views)."
