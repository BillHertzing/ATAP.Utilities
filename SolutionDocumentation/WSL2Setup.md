# WSL2 Setup

## Purpose

This document captures the repository-specific guidance for using WSL2 as a Windows 11
adjacent automation environment. It focuses on the setup needed to use Ubuntu 24.04 as a
WSL-based Ansible and Docker host while keeping good interoperability with PowerShell,
.NET, and Windows-hosted services.

This is a companion reference to [NewComputerSetup.md](./NewComputerSetup.md). Use this
document when the workstation will run Ansible or Docker inside WSL2 rather than directly
on Windows.

## Recommended Baseline

- Use Windows 11 with WSL version 2.
- Standardize on `Ubuntu-24.04` unless there is a specific compatibility reason to use a
  different distribution.
- Keep Windows-side source repositories on NTFS, but keep active Ansible working files on
  the Linux filesystem for better performance.

## Install WSL2

From an elevated PowerShell session on Windows:

```powershell
wsl --install Ubuntu-24.04
wsl --set-default-version 2
wsl -l -v
```

Expected outcome:

- `Ubuntu-24.04` is installed.
- The distribution reports version `2`.
- First-launch initialization prompts for the Linux username and password.

If WSL is already installed, confirm the available distributions first:

```powershell
wsl --list --online
```

## Configure Drive Access

### Default behavior

WSL2 automatically mounts fixed Windows drives under `/mnt` using DrvFs. In the standard
configuration:

- `C:` appears as `/mnt/c`
- `D:` appears as `/mnt/d`
- `E:` appears as `/mnt/e`

### Manual mount check

If `D:` or `E:` are not available, create the mount points and mount them explicitly from
inside Ubuntu:

```bash
sudo mkdir -p /mnt/d /mnt/e
sudo mount -t drvfs D: /mnt/d
sudo mount -t drvfs E: /mnt/e
```

### Persistent automount configuration

Use `/etc/wsl.conf` to keep the standard mount root and enable automount behavior:

```ini
[automount]
enabled=true
root=/mnt/
options="metadata"
```

After editing `/etc/wsl.conf`, restart WSL from Windows:

```powershell
wsl --shutdown
```

Then reopen the distribution and verify the mounts are present.

## Networking Between Windows and WSL2

### Access Windows-hosted services from WSL2

When a service runs on Windows and must be called from WSL2, determine the Windows host IP
as seen from the Linux side:

```bash
ip route show | awk '/default/ { print $3 }'
```

Use that IP to call Windows-hosted APIs from Linux tools such as `curl`, Ansible URI
tasks, or custom scripts.

### Access WSL2-hosted services from Windows

On recent Windows 11 builds with mirrored or localhost-friendly networking, services
exposed inside WSL2 are often reachable directly from Windows at `http://localhost:<port>`.

For older NAT-based behavior, publish the service port from Windows to the WSL2 instance by
using `netsh interface portproxy`.

Example:

```powershell
netsh interface portproxy add v4tov4 `
    listenaddress=0.0.0.0 `
    listenport=5000 `
    connectaddress=<wsl-ip> `
    connectport=5000
```

Use portproxy only when localhost forwarding is not working on the host build.

## Install and Use Ansible in WSL2

Install Ansible inside Ubuntu:

```bash
sudo apt update
sudo apt install -y ansible
```

Recommended layout:

- Store source-of-truth definitions in a Windows repo, for example under `/mnt/d/...`
- Store generated playbooks, inventory, and transient execution state in the Linux home
  directory, for example `/home/<user>/ansible`

This keeps Windows-authored source material accessible while avoiding the slower file I/O
characteristics of repeatedly executing Ansible directly against DrvFs paths.

## Trigger Ansible from PowerShell on Windows

PowerShell on Windows can drive WSL2-based automation directly.

Typical pattern:

1. Read desired-state inputs from a Windows repository.
2. Generate playbooks or inventory files into a Windows-accessible staging folder.
3. Copy those files into WSL via `\\wsl$\<Distro>\home\<user>\...`, or let WSL read them
   from `/mnt/d/...`.
4. Execute Ansible through `wsl.exe`.

Example trigger from PowerShell:

```powershell
$distro = 'Ubuntu-24.04'
$playbook = '/home/whertzing/ansible/site.yml'
$inventory = '/home/whertzing/ansible/inventory'

wsl -d $distro -- ansible-playbook $playbook -i $inventory
```

Use the Windows UNC alias when copying directly into the Linux filesystem from Windows:

```text
\\wsl$\Ubuntu-24.04\home\whertzing\ansible
```

## Docker in WSL2

Docker can run either through Docker Desktop WSL integration or through a native Docker
Engine install inside the Ubuntu distribution.

For a WSL-hosted container API that must be consumed from Windows:

```bash
docker run -p 5000:80 myorg/myapp
```

Then test from Windows:

```powershell
Invoke-RestMethod -Uri 'http://localhost:5000'
```

If localhost forwarding is unavailable on the host build, use the WSL IP address or add a
Windows portproxy rule as described earlier.

## Quick Verification Checklist

- `wsl -l -v` shows `Ubuntu-24.04` on version 2.
- `/mnt/c`, `/mnt/d`, and `/mnt/e` are available in Ubuntu.
- `ip route show` reveals the Windows-side default gateway address.
- `ansible --version` succeeds inside WSL.
- `wsl -d Ubuntu-24.04 -- ansible-playbook ...` succeeds from Windows PowerShell.
- Docker-published ports are reachable from Windows.

## Related Documents

- [NewComputerSetup.md](./NewComputerSetup.md)
- [Security Shift-Left.md](./Security%20Shift-Left.md)
