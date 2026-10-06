# Verda Cloud: 2x CPU Kubernetes VMs

This Terraform configuration creates two CPU virtual machines on [Verda Cloud](https://verda.com) from Verda's Kubernetes OS image. It uses the official [`verda-cloud/verda`](https://registry.terraform.io/providers/verda-cloud/verda/latest) provider.

## What gets created

| Resource | Default |
| --- | --- |
| SSH key | Uploaded from `~/.ssh/id_ed25519.pub` |
| VMs | `k8s-node-1`, `k8s-node-2` |
| Instance type | `CPU.4V.16G` (4 vCPU, 16 GB RAM) |
| Image | `26.04.cuda13.2.kubernetes-1.36.4` |
| Location | `FIN-01` |
| OS disk | 100 GB NVMe per VM |

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
| `instance_count` | Number of VMs | `2` |
| `name_prefix` | Hostname prefix | `k8s-node` |
| `instance_type` | CPU instance type, e.g. `CPU.8V.32G`, `CPU-TURIN.4V.16G` | `CPU.4V.16G` |
| `image` | Kubernetes image. Versions 1.33 to 1.37 are available | `26.04.cuda13.2.kubernetes-1.36.4` |
| `location` | `FIN-01`, `FIN-02` or `FIN-03` | `FIN-01` |
| `os_volume_size` | OS disk size in GB | `100` |
| `ssh_public_key_path` | Path to your SSH public key | `~/.ssh/id_ed25519.pub` |

The current list of instance types is public:

```bash
curl -s https://api.verda.com/v1/instance-types
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

## 5. Form the Kubernetes cluster

The image has Kubernetes preinstalled, but the two VMs are not joined into a cluster yet. On `k8s-node-1`:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

Then run the `kubeadm join ...` command it prints on `k8s-node-2`, and install a CNI plugin such as Flannel or Calico.

## 6. Clean up

The VMs bill by the hour until they are destroyed:

```bash
terraform destroy
```

## Troubleshooting

- **"Invalid client id or client secret" (HTTP 401):** Check that both environment variables are set in the same terminal that runs Terraform. In PowerShell, run `echo $env:VERDA_CLIENT_ID`.
- **Lost client secret:** Delete the credential in the console and create a new one.
- **Image or instance type not available:** Check the instance-types endpoint above. Each type lists the images it supports under `supported_os`.
