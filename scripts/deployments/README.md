# Cluster deployments

Run from northwoods as your normal user with `kubectl` working. Edit `deployments.env` first (domain, retention, paths). Node IPs come from `../k8s/cluster.env`.

## Prerequisites

- `k8s/06-setup-storage-node.sh` has run on northwoods, which also creates the NFS directory `/srv/data/disk1/k8s` used for persistent volumes.
- Every node needs `nfs-common` to mount NFS volumes (`01-prep-node.sh` installs it).
- Resolve `gitlab.`, `jenkins.` and `rancher.` under your domain to the ingress IP (eastwoods, 10.0.0.6) using DNS or `/etc/hosts` on your workstation.
- GitLab wants at least 4 GB of free RAM on eastwoods.

## Steps

```bash
bash 01-platform.sh   # helm, ingress-nginx, cert-manager, NFS default StorageClass
bash 02-gitlab.sh     # GitLab CE; prints the initial root password
bash 03-jenkins.sh    # Jenkins LTS; prints the initial admin password
bash 04-rancher.sh    # Rancher; prints the bootstrap password
bash 05-elk.sh        # Elasticsearch, Kibana, Filebeat; prints the elastic password
bash 06-elk-retention.sh  # delete logs after RETENTION_DAYS
```

## Layout

| Service | URL | Node | Storage |
|---------|-----|------|---------|
| GitLab CE | `http://gitlab.<domain>` (git over ssh: node port 30022) | eastwoods | local disk, `GITLAB_DATA_PATH` |
| Jenkins | `http://jenkins.<domain>` | eastwoods | 20Gi, NFS |
| Rancher | `https://rancher.<domain>` | eastwoods | none |
| Kibana | `http://kibana.<domain>` | eastwoods | none |
| Elasticsearch | internal `elasticsearch.logging:9200` | northwoods | local disk, `ES_DATA_PATH` |
| Filebeat | DaemonSet on every node (including the GPU node) | all | none |

Ingress-nginx runs with host networking on eastwoods, so ports 80 and 443 there serve all three.

## Notes

- GitLab's root password file is deleted after 24 hours; change it on first login.
- Jenkins can launch build agents as pods in its own namespace (RBAC included). Configure the Kubernetes plugin with the in-cluster URL.
- Pipelines on the GPU node need a toleration for `nvidia.com/gpu`.
- Rancher uses a self-signed certificate from cert-manager; your browser will warn.
- Filebeat reads `/var/log/containers` on each node and ships to the `filebeat-*` indices with Kubernetes metadata. After `05-elk.sh`, create a Kibana data view for `filebeat-*`.
- Elasticsearch is a single node on local disk (not NFS) with a 2g heap. Run `06-elk-retention.sh` to set retention (`RETENTION_DAYS`, default 14); re-run it to change. Filebeat uses the `elastic` superuser; swap in a dedicated role for stricter setups.
- Images use `latest`/`lts` tags. Pin versions once things work.
