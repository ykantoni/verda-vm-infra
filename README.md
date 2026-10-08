# Verda Cloud: 2 CPU VMs for a Kubernetes cluster

This Terraform configuration creates two CPU virtual machines on [Verda
Cloud](https://verda.com) — a control-plane node and a worker node — using
the official [`verda-cloud/verda`](https://registry.terraform.io/providers/verda-cloud/verda/latest)
provider. It only provisions the VMs; it knows nothing about Kubernetes.

Installing and joining Kubernetes onto these VMs is a separate, independent
step handled by the sibling [`verda-k8s-infra`](https://github.com/ykantoni/verda-k8s-infra)
repo, which bootstraps [RKE2](https://docs.rke2.io/) over SSH once these VMs
are up. Keeping the two apart means you can destroy/recreate the Kubernetes
layer without touching the VMs, or vice versa.

## What gets created

| Resource | Default |
| --- | --- |
| SSH key | Uploaded from `~/.ssh/id_ed25519.pub` |
| VMs | `k8s-cp1` (control plane), `k8s-worker1` (worker) |
| Instance type | `CPU.4V.16G` (4 vCPU, 16 GB RAM) each |
| Image | `26.04.base` (plain Ubuntu) |
| Location | `FIN-03` |
| OS disk | 100 GB NVMe per VM |

## Module structure

[`modules/verda-vm`](modules/verda-vm) is a generic, Kubernetes-agnostic
module that creates one Verda VM plus its OS volume (and, if given one, a
startup script). The root module calls it twice — once for `cp1`, once for
`worker1` — sharing one SSH key between them.

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

The current list of instance types is public:

```bash
curl -s https://api.verda.com/v1/instance-types
```

Capacity varies by location and changes over time — check before you pick one:

```bash
verda availability --location FIN-03 --type CPU.4V.16G
```

## 4. Deploy

```bash
terraform init
terraform plan
terraform apply
```

When the apply finishes, Terraform prints each VM's IP address and an SSH command:

```bash
terraform output ssh_commands
```

## 5. Connect to the VMs from outside Verda Cloud

Both nodes get a public IP directly on the VM — no VPN, bastion or Verda
console session required. Verda does not interpose a cloud firewall:
whatever is listening on that public IP is reachable from the internet, so
the OS is the only thing standing between you and each port. The base
Ubuntu image ships with no firewall enabled.

From any machine that holds the matching private key:

```bash
terraform output ssh_commands
# cp1     = "ssh root@<cp1-ip>"
# worker1 = "ssh root@<worker1-ip>"
```

```bash
terraform output -raw cp1_ip      # for feeding into verda-k8s-infra
terraform output -raw worker1_ip
```

For anything beyond experimentation, restrict inbound SSH with `ufw` to
your own IP:

```bash
ssh root@<ip> '
  ufw allow from <your-ip>/32 to any port 22 proto tcp
  ufw default deny incoming
  ufw --force enable
'
```

Once you install Kubernetes via `verda-k8s-infra`, see that repo's README
for the additional ports (API server, kubelet, CNI, NodePort range) its
`ufw` instructions open.

## 6. Install Kubernetes

Point [`verda-k8s-infra`](https://github.com/ykantoni/verda-k8s-infra) at
`cp1_ip`/`worker1_ip` from step 5 and apply it — see that repo's README.

## 7. Clean up

The VMs bill by the hour until they are destroyed. Destroy `verda-k8s-infra`
first if you've applied it (it has nothing of its own to bill, but its
state references these VMs), then:

```bash
terraform destroy
```

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
