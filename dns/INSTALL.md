# Installing VeloGuardian DNS

This guide covers the two officially supported install paths — the **OVA virtual machine** and the **Debian/Ubuntu installer tarball** — plus first-boot configuration, pointing your router at the appliance, verifying signatures, and troubleshooting. For a 60-second eval that doesn't touch your real network, see [`eval/`](eval/) instead.

- [Which path should I use?](#which-path-should-i-use)
- [OVA virtual machine](#ova-virtual-machine)
- [Installer tarball](#installer-tarball)
- [First-boot configuration](#first-boot-configuration)
- [Pointing your network at the appliance](#pointing-your-network-at-the-appliance)
- [Verifying it works](#verifying-it-works)
- [Verifying signatures](#verifying-signatures)
- [Updating](#updating)
- [Backing up and restoring](#backing-up-and-restoring)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)

---

## Which path should I use?

| | OVA | Installer tarball |
|---|---|---|
| You have a hypervisor (VMware, Proxmox, VirtualBox, Hyper-V) | ✓ canonical | works, but more steps |
| You have a spare Raspberry Pi 4 / mini PC / Debian VM | works (run an OVA-compatible hypervisor on it) | ✓ canonical |
| You want a hardened, read-only-root appliance | ✓ | — (you manage the host) |
| You want full control of the host OS | — | ✓ |
| You want the smallest disk footprint (~50 MB instead of ~600 MB) | — | ✓ |

If you have no preference and a hypervisor available, **use the OVA**. It boots into a hardened, console-only appliance with a restricted shell, read-only root filesystem, and automatic security updates handled by the appliance.

---

## OVA virtual machine

### Prerequisites

- A hypervisor that can import OVA / OVF: **VMware Workstation/Player/ESXi, VirtualBox, Proxmox, Hyper-V** (Hyper-V users: convert with `qemu-img convert` first).
- 2 GB RAM minimum (1 vCPU is enough for ≤ 1000 active users; bump to 2 vCPUs for higher load).
- 8 GB disk.
- Network: a bridged interface on the LAN you want to filter (so the appliance gets an IP your router can reach).

### Download

```
https://www.veloguardian.com/downloads/VeloGuardianDNS-0.6.1.ova
```

(File size approximately 600 MB.)

> **Note:** The OVA on the download server may briefly lag the latest binary release while a new OVA is being built. If you download an older OVA, just let it boot — the in-app updater will pull the latest signed `.vgupdate` and apply it in place on first run.

### Import

- **VMware Workstation / Player / Fusion** — `File → Open` and select the `.ova`. Click `Import`. Accept the default settings.
- **VirtualBox** — `File → Import Appliance` and select the `.ova`. Make sure "Generate new MAC addresses for all network adapters" is checked.
- **Proxmox** — Upload the `.ova` to your node, then:
  ```sh
  pveum tar zxf VeloGuardianDNS-0.6.1.ova
  qm importovf <VMID> ./VeloGuardianDNS-0.6.1.ovf local-lvm
  qm set <VMID> --net0 virtio,bridge=vmbr0
  ```
- **Hyper-V** — Convert qcow2 → VHDX first:
  ```sh
  qemu-img convert -O vhdx VeloGuardianDNS-disk001.vmdk VeloGuardianDNS-disk001.vhdx
  ```
  Then create a Generation 1 VM in Hyper-V Manager pointing at the converted VHDX.

### First boot

The appliance boots into the **restricted console** (`vgdns-console`), a menu-driven CLI that runs as the root login shell. You will be presented with a numbered menu:

```
VeloGuardian DNS Console — v0.6.1

  1. Network Configuration
  2. Set Hostname
  3. Change Admin Password
  4. System Status
  5. Restart Services
  6. Show Dashboard URL
  7. Check for Updates / Apply from file
  8. Test DNS Resolution
  9. Show Logs
  R. Factory Reset
  0. Reboot / Shutdown
```

Do, in order:

1. **Option 1 → Network Configuration**. Choose DHCP if your LAN has a DHCP server (recommended for first boot), or assign a static IP. Note the IP you end up with — you'll need it to access the dashboard.
2. **Option 3 → Change Admin Password**. The factory default is `admin` / `admin`. Change it now. (You can also change it from the dashboard's Settings page after first login.)
3. **Option 6 → Show Dashboard URL**. Note the URL — it will look like `https://192.168.1.50/`.
4. Open that URL in a browser on the same network. You'll get a self-signed TLS warning on first connect — accept it (the appliance generates a self-signed ECDSA P-256 cert on first boot; you can replace it with a real cert later if you want).
5. Log in as `admin` with the password you set.

You're done with the console for now. All ongoing configuration happens in the dashboard.

---

## Installer tarball

### Prerequisites

- A Debian 12, Ubuntu 22.04, or Ubuntu 24.04 host. (Other distros may work — the binary is statically linked Go — but we only test those three.)
- Root access (the installer needs to create a system user, install systemd units, and open ports 53 and 8080).
- ~50 MB free disk (the binary + dashboard assets).
- DNS port 53 not already taken by another service (notably `systemd-resolved` — the installer detects this and offers to free up port 53).

### Download and verify

```sh
curl -sSLO https://www.veloguardian.com/downloads/veloguardian-dns-0.6.3-linux-amd64.tar.gz
curl -sSLO https://www.veloguardian.com/downloads/veloguardian-dns-0.6.3-linux-amd64.tar.gz.sha256

sha256sum -c veloguardian-dns-0.6.3-linux-amd64.tar.gz.sha256
# Expected: veloguardian-dns-0.6.3-linux-amd64.tar.gz: OK
```

If `sha256sum -c` does not print `OK`, **stop**. The tarball is corrupted or has been tampered with. Re-download and retry.

### Install

```sh
mkdir -p veloguardian-dns-0.6.3
tar -xzf veloguardian-dns-0.6.3-linux-amd64.tar.gz -C veloguardian-dns-0.6.3
cd veloguardian-dns-0.6.3
sudo ./install.sh
```

The installer:

1. Creates a `vgdns` system user (no login, no shell).
2. Installs the binary to `/opt/veloguardian-dns/veloguardian-dns`.
3. Installs the console CLI to `/opt/veloguardian-dns/vgdns-console`.
4. Drops the default config at `/etc/vgdns/config.yaml`.
5. Copies the category seed files to `/etc/vgdns/categories/`.
6. Creates the data directory `/var/lib/vgdns/`.
7. Detects and (with your permission) disables the `systemd-resolved` stub listener on port 53.
8. Installs the systemd units `vgdns.service`, `vgdns-apply-update.path`, and `vgdns-apply-update.service`.
9. Enables and starts `vgdns.service`.

When the script finishes, it prints the dashboard URL — typically `http://<host-ip>:8080/`.

Open the URL, log in as `admin` / `admin`, and the dashboard will prompt you to change the password.

### Filesystem layout after install

| Path | Purpose |
|---|---|
| `/opt/veloguardian-dns/` | Binaries and built-in dashboard assets |
| `/etc/vgdns/config.yaml` | Main configuration file (YAML) |
| `/etc/vgdns/categories/` | Category seed files (one `.txt` per Argos category slug) |
| `/var/lib/vgdns/vgdns.db` | SQLite database (WAL mode) |
| `/var/lib/vgdns/cache/` | Blocklist download cache |
| `/var/lib/vgdns/reports/` | Generated PDF reports |
| `/etc/systemd/system/vgdns*.service`, `vgdns*.path` | systemd unit files |

---

## First-boot configuration

Whichever install path you used, the first time you log into the dashboard:

1. **Change the admin password** (Settings → Password). The default is `admin` / `admin` — change it before exposing the dashboard to anyone.
2. **Set up SMTP** (Settings → SMTP) if you want scheduled PDF report email delivery. Skip if you don't.
3. **Review the default profile** (Filtering → Profiles → Default). The default profile has filtering enabled with no categories blocked — meaning all DNS queries are forwarded upstream. Pick the categories you want to block.
4. **Optionally create per-client profiles**. For example: a "Kids" profile blocking Adult Content + Lifestyle & Vices + (during school hours) Media & Entertainment. Map clients to it via Filtering → Clients.
5. **Verify upstream DNS**. Settings → Upstream DNS. Defaults to `1.1.1.1, 8.8.8.8`. Change if you want a privacy-respecting upstream (Quad9 `9.9.9.9`, Mullvad DoH `https://dns.mullvad.net/dns-query`, etc.).

---

## Pointing your network at the appliance

DNS filtering only works if your devices' DNS queries actually reach the appliance. Three common ways to make that happen:

### Easiest — change your router's DNS

Most home routers expose a DNS field under "WAN" or "Internet" settings. Set the primary DNS to the appliance's IP. Save and reboot the router. Every device that gets DNS via DHCP from the router will start using the appliance automatically.

> Some ISP-provided routers (especially fiber gateways) lock the DNS field. If yours does, see "Advanced" below.

### Per-device — change device DNS manually

Useful if you only want to filter specific devices, or for testing before you flip the whole network.

- **macOS** — `System Settings → Network → <Interface> → Details → DNS` → add the appliance's IP at the top.
- **Windows** — `Settings → Network & Internet → <Interface> → Edit DNS settings`.
- **iOS** — `Settings → Wi-Fi → <Network> → Configure DNS → Manual`.
- **Android** — depends on the device; typically `Wi-Fi → <Network> → Advanced → IP settings → Static`.

### Advanced — DHCP option 6 from a separate DHCP server

If your router won't let you change DNS but lets you disable DHCP, run DHCP from a separate device (e.g., on the same VeloGuardian DNS host, or a dedicated DHCP server) and set DHCP option 6 to point clients at the appliance.

### Bypass-resistant — DNAT port 53 on the router

The strongest option (and the one that prevents children/users from manually changing their device's DNS). On routers that support custom firewall rules (OpenWrt, pfSense, OPNsense), add a DNAT rule that redirects *all* outbound UDP/TCP port 53 traffic to the appliance's IP. Every device on the LAN — including ones that try to use `1.1.1.1` or `8.8.8.8` directly — gets transparently routed through the appliance.

---

## Verifying it works

From any device on the network (or the appliance itself):

```sh
# Should resolve and return the upstream IP
dig @<appliance-ip> example.com

# Should be blocked (NXDOMAIN) if you enabled the Advertising category in any profile
dig @<appliance-ip> doubleclick.net

# Test from a specific client IP to confirm profile routing
dig @<appliance-ip> +tries=1 +time=2 doubleclick.net
```

Open the dashboard's **Query Log** page and you should see your test queries appear in real time, with the matched profile, client IP, and (for blocked queries) the reason.

If the blocked-domain dig returned a real IP instead of NXDOMAIN: check that the calling client's IP is mapped to the right profile (Filtering → Clients) and that the profile has the relevant category enabled.

---

## Verifying signatures

The `.vgupdate` packages distributed via the in-app updater are signed with the project's Ed25519 release key. The corresponding **public key** is embedded in every appliance binary and is also published here for cross-verification:

```
# VeloGuardian DNS — release public key (Ed25519)
# Fingerprint will be populated from `vgdns-sign keygen --print-pub` and added to a future release.
```

> **For 0.6.x:** the embedded public key is the canonical one. Check the appliance log when applying an update — if signature verification fails, the apply path refuses to install the package and rolls back.

Tarball checksums are published as `.sha256` sidecars on the download server and verified with `sha256sum -c`. Tarballs are not separately signed — verify the download server's TLS chain (it is a Let's Encrypt cert at `www.veloguardian.com`) plus the SHA-256.

---

## Updating

Once the appliance is running, updates are pulled from the official download server automatically:

- The in-app **System Status** page shows the current version and any available update.
- The dashboard's update badge shows in the sidebar within 5 minutes of a new release appearing.
- Click **Apply Update** — the appliance downloads the `.vgupdate`, verifies the signature, applies it in place, and restarts the service.
- If signature verification or the apply step fails, the appliance automatically rolls back to the previous binary.

The appliance also performs a daily check (default cron `0 3 * * *`). You can change the schedule in Settings → Update Schedule.

For air-gapped installs: download the `.vgupdate` manually from the download server, then upload it via the dashboard's **System Status → Apply from file**.

---

## Backing up and restoring

The dashboard's **System Status → Backup** button downloads a `.vgbackup` file — a gzipped tar archive containing a JSON snapshot of every configuration table, the current YAML config, and the TLS keypair if enabled. Take a fresh backup before any major upgrade.

To restore: **System Status → Restore from file** and upload a `.vgbackup`. The restore is **schema-version-gated** — a backup taken on v0.5.x will be rejected (HTTP 400) if you try to restore it onto a v0.6.x appliance, and vice versa. Always restore to an appliance running the same major version that produced the backup.

If your hypervisor supports snapshots, those are a reasonable fallback for cross-major rollback (snapshot before applying any `.vgupdate` and before any factory reset).

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Dashboard not reachable after install (tarball) | Firewall blocks port 8080, or another service has it | `sudo ss -tnlp \| grep 8080` to check; allow the port (`sudo ufw allow 8080`) or change `web.port` in `/etc/vgdns/config.yaml` and restart |
| Dashboard not reachable after first boot (OVA) | Console option 1 didn't complete, or DHCP didn't give the appliance an IP | Console option 4 → System Status — confirm an IP is assigned; option 6 → Dashboard URL; reboot if needed |
| Browser shows TLS warning | Self-signed cert (expected on first boot) | Accept the warning, or replace `/etc/vgdns/certs/{cert,key}.pem` with your own cert + restart |
| `dig @<appliance-ip>` times out | DNS port 53 not bound, or upstream firewall blocks | `sudo systemctl status vgdns` to check service; verify port 53 is listening (`sudo ss -unlp \| grep :53`); from the appliance, `dig @1.1.1.1 example.com` to verify the upstream is reachable |
| Test query not blocked even though category is enabled | Client's IP not mapped to the right profile, or the category file has no domains for that domain | Filtering → Clients — confirm IP/CIDR mapping; Query Log — confirm the profile that matched |
| Update fails to apply | Signature mismatch or disk full | System Logs page — look for `update apply failed`; check disk free; the appliance will have rolled back automatically |
| `systemd-resolved` keeps grabbing port 53 after install | Installer's free-port-53 step was declined | `sudo systemctl disable --now systemd-resolved`; edit `/etc/resolv.conf` to be a plain text file with `nameserver 127.0.0.1` |
| Backup restore fails with HTTP 400 | Backup `schema_version` does not match the running appliance | Restore onto an appliance running the same major version that produced the backup, then upgrade |

---

## Uninstalling

### OVA

Delete the VM in your hypervisor. The appliance writes nothing outside its own disk. If you point your router back at your previous DNS, no further cleanup is needed.

### Installer tarball

The tarball ships with an `uninstall.sh` script:

```sh
sudo /opt/veloguardian-dns/uninstall.sh
```

It stops and disables `vgdns.service`, removes the systemd units, removes the binary and category seed files, deletes the `vgdns` system user, and asks (interactively) whether to delete `/var/lib/vgdns/` (the database and reports). Decline that prompt if you want to keep the data for a later reinstall.

If you previously let the installer disable `systemd-resolved` to free port 53, re-enable it with:

```sh
sudo systemctl enable --now systemd-resolved
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

---

For deeper documentation on each dashboard page, see the [website docs](https://veloguardian.com/docs/dns/quick-start.html). For bug reports and feature requests, see the [issue templates](https://github.com/veloguardian/community/issues/new/choose).
