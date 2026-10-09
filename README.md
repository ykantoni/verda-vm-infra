# Verda Cloud: 2-node RKE2 Kubernetes cluster

This Terraform configuration creates two CPU virtual machines on [Verda
Cloud](https://verda.com) — a control-plane node and a worker node — using
the official [`verda-cloud/verda`](https://registry.terraform.io/providers/verda-cloud/verda/latest)
provider, then bootstraps a 2-node [RKE2](https://docs.rke2.io/) Kubernetes
cluster onto them over SSH, with [Cilium](https://cilium.io/) as the CNI.

It's meant to be paired with the sibling
[`verda-k8s-infra`](https://github.com/ykantoni/verda-k8s-infra) repo,
which installs [Argo CD](https://argo-cd.readthedocs.io/) onto whatever
cluster this repo produces, via a real Terraform-managed `helm_release` —
applied independently, so you can reinstall Argo CD without touching the
cluster, or recreate the cluster without needing to redesign how Argo CD
gets installed.

## What gets created

| Resource | Default |
| --- | --- |
| SSH key | Uploaded from `~/.ssh/id_ed25519.pub` |
| VMs | `k8s-cp1` (control plane), `k8s-worker1` (worker) |
| Instance type | `CPU.4V.16G` (4 vCPU, 16 GB RAM) each |
| Image | `26.04.base` (plain Ubuntu — RKE2 installs its own Kubernetes) |
| Location | `FIN-03` |
| OS disk | 100 GB NVMe per VM |
| Kubernetes | RKE2, with Cilium as the CNI (kube-proxy replaced) |

## What the RKE2 bootstrap does

- Generates one shared join token (`random_password.rke2_token`).
- Installs `open-iscsi`/`nfs-common` and starts `iscsid` on both nodes —
  not needed by RKE2 itself, but required by Longhorn (below) before it
  can attach any volume.
- Connects to the control-plane IP over SSH and runs the RKE2 server
  installer (`get.rke2.io`), configured with that token, `cni: cilium`,
  the pod/service CIDRs, `disable-kube-proxy: true`, a `HelmChartConfig`
  overriding Cilium's cluster name and kube-proxy replacement, and a
  `HelmChart` manifest that has RKE2's own helm-controller install
  [Longhorn](https://longhorn.io/) and set it as the cluster's default
  `StorageClass` (`persistence.defaultClass: true`, replica count `2` to
  match this cluster's node count — see "Why 2 replicas, not 3" below).
  RKE2 ships with no `StorageClass` at all otherwise, so without this any
  `PersistentVolumeClaim` — including ones from apps `verda-k8s-infra`
  installs, like OpenBao — sits `Pending` forever.
- Connects to the worker IP over SSH and runs the RKE2 agent installer,
  configured to join the control plane's `:9345` with the same token.
- Re-runs a node's install only when its target host or the rendered
  script changes (new token, new RKE2 version, or the IP changed because
  the underlying VM was replaced) — a no-op re-apply does nothing.
- Once both nodes have joined, fetches a kubeconfig over SSH to a local,
  gitignored file (`.terraform-kubeconfig.yaml`) — this is what
  `verda-k8s-infra`'s `helm` provider reads to install Argo CD, and it's
  also what `kubeconfig_command` (below) is built from.

Longhorn's UI (`longhorn-frontend` Service) is exposed as `NodePort`
`30093`, reachable directly at `http://<cp1-ip or worker1-ip>:30093` — no
tunnel needed. It has no auth of its own, so lock it down the same way as
the other NodePorts below if that matters for your setup. `just endpoints`
(from the `verda-cloud` root) prints this URL, along with `verda-k8s-infra`'s
Argo CD/OpenBao/Prometheus/Grafana NodePorts, using the current cluster's
actual IP.

### Why 2 Longhorn replicas, not the usual 3

Longhorn defaults to 3 replicas per volume for full redundancy, but this
cluster only has 2 nodes, so `longhorn_version`'s `HelmChart` sets
`defaultClassReplicaCount`/`defaultReplicaCount` to `2` instead. The
trade-off: with 2 replicas, Longhorn survives one node going down, but
can't rebuild a healthy third replica elsewhere until that node comes
back — there's no spare node to rebalance onto. Fine for a lab/dev
cluster, not what you'd want in production.

## Module structure

- [`modules/verda-vm`](modules/verda-vm) is a generic, Kubernetes-agnostic
  module that creates one Verda VM plus its OS volume. The root module
  calls it twice — once for `cp1`, once for `worker1` — sharing one SSH
  key between them.
- [`modules/rke2`](modules/rke2) takes a `role` (`server` or `agent`), a
  shared `token`, and a `host` to SSH into, and renders + executes the
  matching install script there via a `null_resource` with `file` and
  `remote-exec` provisioners.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer, or [OpenTofu](https://opentofu.org).
- A Verda Cloud account with billing set up.
- An SSH key pair. Create one with `ssh-keygen -t ed25519` if you don't have one.

## 1. Create a Verda client ID and client secret

Terraform authenticates to the Verda API with a client ID and client secret.

1. Log in to the [Verda Console](https://console.verda.com).
2. Open the **Credentials** page from the sidebar.
3. Under **Cloud API credentials**, click **+ Create**.
4. Copy the **Client ID** and **Client Secret**.

The client secret is shown only once, so save it in a password manager right away. If you lose it, delete the credential and create a new one. The same pair also works with the Verda CLI, SkyPilot and dstack.

See Verda's [API Credentials](https://docs.verda.com/welcome-to-verda/api-credentials/) page for details.

## 2. Configure the credentials

The provider reads credentials from two environment variables:

| Variable | Value |
| --- | --- |
| `VERDA_CLIENT_ID` | Your client ID |
| `VERDA_CLIENT_SECRET` | Your client secret |

Never put the secret in a `.tf` file or commit it to git.

### Windows PowerShell (current session only)

```powershell
$env:VERDA_CLIENT_ID     = "your-client-id"
$env:VERDA_CLIENT_SECRET = "your-client-secret"
```

### Windows PowerShell (persist for your user)

```powershell
[Environment]::SetEnvironmentVariable("VERDA_CLIENT_ID", "your-client-id", "User")
[Environment]::SetEnvironmentVariable("VERDA_CLIENT_SECRET", "your-client-secret", "User")
```

Open a new terminal afterwards so the variables are picked up.

### Linux, macOS or Git Bash

```bash
export VERDA_CLIENT_ID="your-client-id"
export VERDA_CLIENT_SECRET="your-client-secret"
```

To keep them across sessions, add the two lines to `~/.bashrc` or `~/.zshrc`. A safer option is a local `.env` file that git ignores:

```bash
# .env  (already listed in .gitignore)
export VERDA_CLIENT_ID="your-client-id"
export VERDA_CLIENT_SECRET="your-client-secret"
```

Load it with `source .env` before running Terraform.

### Check that the credentials work (optional)

This requests an access token from the Verda API. A JSON response with an `access_token` means the credentials are valid.

```bash
curl -s -X POST https://api.verda.com/v1/oauth2/token \
  -H "Content-Type: application/json" \
  -d "{\"grant_type\":\"client_credentials\",\"client_id\":\"$VERDA_CLIENT_ID\",\"client_secret\":\"$VERDA_CLIENT_SECRET\"}"
```

## 3. Adjust the settings (optional)

Copy the example file and edit it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

| Variable | Description | Default |
| --- | --- | --- |
| `name_prefix` | Hostname prefix | `k8s` |
| `cp_instance_type` | CPU instance type for `cp1`, e.g. `CPU.8V.32G`, `CPU-TURIN.4V.16G` | `CPU.4V.16G` |
| `worker_instance_type` | CPU instance type for `worker1` | `CPU.4V.16G` |
| `image` | Verda OS image | `26.04.base` |
| `location` | `FIN-01`, `FIN-02` or `FIN-03` | `FIN-03` |
| `os_volume_size` | OS disk size in GB | `100` |
| `ssh_public_key_path` | Path to your SSH public key | `~/.ssh/id_ed25519.pub` |
| `ssh_private_key_path` | Path to the matching private key, used to bootstrap RKE2 over SSH | `~/.ssh/id_ed25519` |
| `ssh_user` | SSH user on both VMs | `root` |
| `rke2_version` | RKE2 version to install | `v1.37.1+rke2r1` |
| `pod_cidr` | Pod IP address range (`cluster-cidr`) | `1.1.0.0/16` |
| `service_cidr` | Service IP address range (`service-cidr`) | `2.2.0.0/16` |
| `cilium_cluster_name` | Cilium's cluster identity name (`cluster.name` Helm value) | `verdaclu` |
| `longhorn_version` | Longhorn Helm chart version | `1.13.0` |

The current list of instance types is public:

```bash
curl -s https://api.verda.com/v1/instance-types
```

Capacity varies by location and changes over time — check before you pick one:

```bash
verda availability --location FIN-03 --type CPU.4V.16G
```

`rke2_version` is pinned rather than left empty: the install script's
"latest stable" auto-resolution depends on
`update.rke2.io/v1-release/channels`, which has been returning 404 (an
upstream outage, not this repo) — pinning a real tag bypasses it entirely.

`1.1.0.0/16`/`2.2.0.0/16` are real, publicly-routable internet ranges (not
RFC1918 private space) — `1.1.1.1` in particular is Cloudflare's public DNS
resolver. Using them as pod/service CIDRs is valid, but if anything inside
the cluster ever needs to reach the real `1.1.1.1`, it'll get silently
shadowed by the pod network instead.

## 4. Deploy

From the `verda-cloud` root (the parent directory containing both this repo
and `verda-k8s-infra` as sibling checkouts):

```bash
just vm-init
just vm-apply
```

See the root [Justfile](../Justfile). `just vm-init` runs `terraform init`
with this repo's state path pinned via `-backend-config` to
`TF_VAR_tfstate_location` if that's set in your shell, or else to an
absolute default (`verda-vm-infra/terraform.tfstate`, computed from the
Justfile's own location) — the same value `verda-k8s-infra`'s
`argocd_admin_password_command` output looks for. **Check
`echo $TF_VAR_tfstate_location`** before running `vm-init`/`vm-apply` if
you're not deliberately relocating state: a stale value will point this
repo's *real* state at the wrong file. You can still run plain
`terraform init`/`plan`/`apply` directly inside this directory if you
prefer — it ignores the variable and always uses the same default path.

Unlike a boot-time startup script, the RKE2 bootstrap blocks until each
install finishes over SSH — when `apply` completes, RKE2 and Cilium are
already installed and running. Give the Cilium CNI pods a little longer to
come up before nodes show `Ready`.

When the apply finishes, Terraform prints each VM's IP address and an SSH command:

```bash
terraform output ssh_commands
```

## 5. Connect to the cluster from outside Verda Cloud

Both nodes get a public IP directly on the VM — no VPN, bastion or Verda
console session required. Verda does not interpose a cloud firewall:
whatever is listening on that public IP is reachable from the internet, so
the OS is the only thing standing between you and each port.

### Connect to the VMs (SSH)

```bash
terraform output ssh_commands
# cp1     = "ssh root@<cp1-ip>"
# worker1 = "ssh root@<worker1-ip>"
```

### Connect to the cluster (kubectl)

```bash
just generate
```

(Or, from this directory: `eval "$(terraform output -raw kubeconfig_command)"`.)
This writes `~/verda_kubeconfig.yaml` — in your home directory, regardless
of which directory you ran it from — rewriting the server address from
`127.0.0.1` to the control-plane's public IP, and renaming RKE2's
hardcoded `default` cluster/context/user entries to `cilium_cluster_name`
(a cosmetic local label only — this doesn't touch Cilium's own cluster
identity, which is configured separately via the `HelmChartConfig` in
`modules/rke2`). Its TLS certificate already includes that IP (the
install script sets `tls-san`), so no `--insecure-skip-tls-verify` is
needed:

```bash
kubectl --kubeconfig ~/verda_kubeconfig.yaml get nodes
```

You should see both nodes `Ready` within a minute or so. Point any
kubectl-compatible tool (k9s, Lens, Helm, CI pipelines) at
`~/verda_kubeconfig.yaml`, or merge it into `~/.kube/config`.

The API server (`terraform output api_server_url`) listens on `:6443` and
is reachable the same way from anywhere with network access to the IP —
the kubeconfig isn't tied to the machine that generated it.

### Reach apps running in the cluster

- **NodePort**: a `Service` of type `NodePort` is reachable at
  `<cp1 or worker1 ip>:<30000-32767>`.
- **Ingress**: RKE2 ships `rke2-ingress-nginx` by default, exposed through
  its own `NodePort` (check with
  `kubectl get svc -n kube-system rke2-ingress-nginx-controller`); point a
  DNS record or `/etc/hosts` entry at either node's IP and that port.
- **LoadBalancer**: RKE2's bundled `servicelb` (Klipper) binds
  `LoadBalancer` services directly to ports 80/443/etc. on every node's
  public IP — no external load balancer needed for a two-node cluster like
  this one.

### Lock it down (optional)

For anything beyond experimentation, restrict inbound traffic with `ufw`
on each node to your own IP range, e.g. on `cp1`:

```bash
ssh root@<cp1-ip> '
  ufw allow from <your-ip>/32 to any port 22,6443 proto tcp
  ufw allow 6443/tcp                       # API server, node-to-node — kube-proxy is disabled, Cilium needs this directly
  ufw allow 10250/tcp                      # kubelet, node-to-node
  ufw allow 9345/tcp                       # RKE2 supervisor, node-to-node
  ufw allow 8472/udp                       # Cilium VXLAN, node-to-node
  ufw default deny incoming
  ufw --force enable
'
```

Open additional ports (NodePort range, 80/443) only as needed, and repeat
with the equivalent rules on `worker1` (skip the `6443` rule there — only
`cp1` runs the API server).

## 6. Clean up

The VMs bill by the hour until they are destroyed. From the `verda-cloud`
root:

```bash
just destroy
```

This runs `k8s-destroy` (uninstalls Argo CD, if applied) then `vm-destroy`
(destroys the VMs, which removes RKE2 along with them). To tear down only
the VMs: `just vm-destroy`.

## Troubleshooting

- **"Invalid client id or client secret" (HTTP 401):** Check that both environment variables are set in the same terminal that runs Terraform. In PowerShell, run `echo $env:VERDA_CLIENT_ID`.
- **Lost client secret:** Delete the credential in the console and create a new one.
- **Image or instance type not available:** Check the instance-types endpoint above. Each type lists the images it supports under `supported_os`.
- **Instance errors out / never gets an IP:** This is usually the target
  location being out of capacity for that instance type, not a config
  problem. Run `verda availability --location <loc> --type <type>` and pick
  a location that shows availability, then change `location` (this forces
  recreation of any instance already created) and re-apply.
- **Can't reach a VM from your machine:** Confirm the IP is right
  (`terraform output ssh_commands`) and that nothing upstream of Verda
  (your own network, a corporate proxy) blocks outbound port 22. If you've
  applied the `ufw` rule above, check it allows your current public IP:
  `ssh root@<ip> ufw status`.
- **`terraform plan`/`apply` says there's nothing created, but VMs exist in
  the console (or vice versa):** This repo's backend is pointed at the
  wrong file. Check `cat .terraform/terraform.tfstate` (the backend
  pointer, not your actual state) for the `path` it's actually using. If
  it's not where you expect, check `echo $TF_VAR_tfstate_location` — the
  Justfile honors it, so a stale export is the most likely cause. `unset`
  it (or fix it) and re-run `just vm-init` to reset the backend to the
  right path.
- **`apply` hangs or times out connecting over SSH:** Confirm the VM is
  actually up and SSH-reachable: `ssh -i <key> root@<ip>`. The RKE2
  module's `connection` block retries for 5 minutes, so a VM still booting
  will eventually succeed — but a wrong key or a `ufw` rule blocking your
  IP will not.
- **Node stuck `NotReady` or `kubectl` can't connect:** SSH in and check
  the install log and service status:

  ```bash
  ssh root@<ip> tail -n 100 /var/log/rke2-install.log
  ssh root@<ip> journalctl -u rke2-server -f   # on cp1
  ssh root@<ip> journalctl -u rke2-agent -f    # on worker1
  ```

- **Nodes stay `NotReady`, or pods stuck `ContainerCreating`/`Pending` with
  no Cilium pods running:** Check `kubectl get pods -n kube-system -l
  k8s-app=cilium` and `ssh root@<cp1-ip> journalctl -u rke2-server | grep -i
  helm`. Since `disable-kube-proxy: true` is set, `cilium-agent` needs
  direct access to the API server at the `k8sServiceHost`/`k8sServicePort`
  set in the `rke2-cilium` `HelmChartConfig` (cp1's public IP at install
  time, port `6443`) — if `cp1`'s IP changed since `cilium-agent` started,
  or a `ufw` rule blocks `6443` node-to-node, Cilium can't reach the API
  server and nothing comes up.
- **Longhorn pods missing, or `PersistentVolumeClaim`s stuck `Pending`:**
  Check it actually deployed and that `iscsid` is running on both nodes
  (the real prerequisite Longhorn needs, which this isn't RKE2-native so
  won't show up in `rke2-install.log`'s Helm section the way Cilium does):

  ```bash
  ssh root@<cp1-ip> kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods -n longhorn-system
  ssh root@<ip> systemctl status iscsid   # on both nodes
  ```

  If `iscsid` isn't `active`, the `apt-get` step earlier in the script
  likely never completed — check `/var/log/rke2-install.log` on that node
  for the retry loop's output.
- **Worker never joins:** Confirm the control-plane IP actually points at a
  running `rke2-server` and that the worker can reach it on `:9345` (not
  just `:22`) — a `ufw` rule on `cp1` that only opens `22` and `6443` would
  block this. Since the target host and rendered script haven't changed, a
  plain re-apply won't retry it — force it with (from this directory):
  `terraform apply -replace=module.rke2_agent.null_resource.bootstrap`.
- **A VM was replaced and got a new IP:** Just re-run `just vm-apply` — the
  IP is part of each RKE2 module's trigger, so Terraform picks up the new
  address and reruns the install automatically. If `verda-k8s-infra` has
  already been applied too, re-run `just k8s-apply` afterward so Argo CD
  reconnects to the (possibly new) kubeconfig.
- **`remote-exec provisioner error ... Process exited with status 22`:**
  This is `curl`'s own exit code for an HTTP failure (`--fail`), surfacing
  from inside `get.rke2.io`'s install script — check
  `ssh root@<ip> tail -n 60 /var/log/rke2-install.log` for the actual URL
  that 404'd. If it's `.../releases/download/stable/sha256sum-amd64.txt`,
  that means `rke2_version` was left empty and the install script's
  "resolve the stable channel" call to
  `update.rke2.io/v1-release/channels/stable` came back 404 — an upstream
  RKE2 outage, not this repo. `rke2_version` defaults to a pinned tag
  specifically to avoid depending on that endpoint; if you've overridden
  it to `""`, un-override it, or set it to another concrete tag from
  `https://github.com/rancher/rke2/releases`.
