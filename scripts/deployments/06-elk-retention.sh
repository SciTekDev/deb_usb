#!/bin/bash
set -euo pipefail

# Set the ILM policy used by Filebeat indices: roll over daily or at 20gb, delete after RETENTION_DAYS.
# Safe to re-run to change the retention.

source "$(dirname "${BASH_SOURCE[0]}")/deployments.env"

elastic_pw=$(kubectl -n logging get secret elk-credentials -o jsonpath='{.data.elastic}' | base64 -d)

kubectl -n logging exec -i deploy/elasticsearch -- curl -fsS -u "elastic:$elastic_pw" \
    -H 'Content-Type: application/json' \
    -X PUT localhost:9200/_ilm/policy/filebeat -d @- <<EOF
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": { "max_age": "1d", "max_primary_shard_size": "20gb" }
        }
      },
      "delete": {
        "min_age": "${RETENTION_DAYS}d",
        "actions": { "delete": {} }
      }
    }
  }
}
EOF

echo ""
echo "✓ Filebeat logs are deleted ${RETENTION_DAYS} days after rollover."
