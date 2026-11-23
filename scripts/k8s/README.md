# Kubernetes cluster setup

| Node | Cluster IP (NIC 0) | Extra NIC IPs | Role |
|------|----|----|------|
| northwoods | 10.0.0.4 | .14 .24 .34 | control plane, storage (NFS) |
| eastwoods | 10.0.0.6 | .16 .26 .36 | web |
| westwoods | 10.0.0.8 | .18 .28 .38 | GPU |

Each node has four NICs. NIC 0 is the one holding the default route; it gets the cluster IP, gateway and DNS, and kubelet is pinned to it with `--node-ip`. The other NICs follow in name order with the extra addresses and no gateway. All 12 addresses are listed explicitly in `NODE_NIC_IPS` in `cluster.env`.

Settings (versions, IPs, CIDR, gateway) live in `cluster.env`. `sudo` is not assumed to be installed.

## Running the scripts

Become root with a **login shell**, then change to this directory (the USB SCRIPTS partition):

```bash
su -          # NOT plain "su"
cd /path/to/scripts/k8s
bash 01-prep-node.sh
```

Plain `su` keeps your user's `PATH`, which has no `/sbin` or `/usr/sbin`, so scripts fail with errors like `swapoff: command not found`. `su -` gives root's own `PATH`. Check with `echo $PATH`: it should contain `/usr/sbin`. Every command in the steps below is run from this root shell.

## Steps

0. **All nodes:** `post-install.sh` sets the hostname to `northwoods`, `eastwoods` or `westwoods`. Then assign the static IPs to all four NICs (it shows the NIC-to-IP plan and asks first) and reboot.

   ```bash
   bash 00-set-static-ip.sh
   ```

1. **All nodes:** prepare the OS and install the Kubernetes packages.

   ```bash
   bash 01-prep-node.sh
   ```

2. **northwoods:** initialize the control plane. Pass your normal username so it gets `~/.kube/config`. Copy the printed `kubeadm join ...` line.

   ```bash
   bash 02-init-control-plane.sh clint
   ```

3. **eastwoods and westwoods:** join the cluster.

   ```bash
   bash 03-join-node.sh "kubeadm join 10.0.0.4:6443 --token ... --discovery-token-ca-cert-hash sha256:..."
   ```

4. **northwoods:** label nodes and taint the GPU node.

   ```bash
   bash 04-label-nodes.sh
   ```

5. **westwoods:** install the NVIDIA driver and container toolkit, then reboot and check `nvidia-smi`.

   ```bash
   bash 05-setup-gpu-node.sh
   ```

6. **northwoods:** apply the GPU device plugin.

   ```bash
   kubectl apply -f manifests/nvidia-device-plugin.yaml
   ```

7. **northwoods:** format data disks and export them over NFS. This erases the listed disks.

   ```bash
   bash 06-setup-storage-node.sh /dev/sdb /dev/sdc
   ```

## Verify

```bash
kubectl get nodes -o wide
kubectl describe node westwoods | grep -i nvidia.com/gpu
showmount -e northwoods
```

## Notes

- Non-free Debian repos must be enabled on westwoods before step 5.
- The join token expires after 24 hours. Create a new one with `kubeadm token create --print-join-command` on northwoods.
- NFS exports allow `10.0.0.0/24` with `no_root_squash`. Tighten this if the network is shared.
- FAT32 does not keep execute bits, so run scripts with `bash script.sh`.
- Optional, any time after step 0: `07-power-thermal.sh` installs temperature-based fan control for Dell PowerEdge R720s (IPMI). It refuses to run on other models.
