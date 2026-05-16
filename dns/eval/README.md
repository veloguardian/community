# Evaluating VeloGuardian DNS without touching real infrastructure

Three ways to take the appliance for a spin without affecting your real network. Pick whichever matches your environment.

## 1. VirtualBox or VMware (easiest)

Best for non-technical evaluation. The OVA boots straight into the appliance, and the VM's networking is sandboxed by the hypervisor — no risk to your real LAN.

1. Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (free, all platforms) or VMware Workstation Player (free for personal use).
2. Download `VeloGuardianDNS-0.6.1.ova` from [the download page](https://www.veloguardian.com/dns.html).
3. **File → Import Appliance** and select the OVA. Accept the defaults.
4. Set the network adapter to **NAT** (default) — this isolates the VM from your real LAN.
5. Configure port forwarding so you can reach the dashboard from your host:
   - **VirtualBox** — Settings → Network → Adapter 1 → Advanced → Port Forwarding → Add a rule: `Host Port 8443 → Guest Port 443`.
   - **VMware** — Edit Virtual Machine → Network → NAT settings → Port Forwarding → Add: `Host Port 8443 → VM IP : 443`.
6. Start the VM. Wait ~30 seconds for the appliance to finish booting.
7. From the host browser, open `https://localhost:8443/`. Accept the TLS warning. Log in as `admin` / `admin`.
8. To test DNS resolution against the appliance from the host, you need to add another port forward: `Host Port 5353/UDP → Guest Port 53/UDP`, then `dig @127.0.0.1 -p 5353 example.com`.

When you're done, just delete the VM. Zero impact on your real network.

## 2. qemu (Linux power-user path)

If you have qemu installed (`qemu-system-x86_64`) and want a scripted eval that boots a clean Debian VM, installs the appliance via the tarball, and binds the dashboard to localhost — run `qemu-eval.sh`:

```sh
./qemu-eval.sh
```

The script:

1. Downloads a Debian 12 cloud image (cached to `/tmp/vgdns-eval/`).
2. Generates a cloud-init seed ISO that fetches and runs the v0.6.1 installer tarball on first boot.
3. Boots qemu with user-mode networking, forwarding host port `8080` → guest port `8080` (HTTP dashboard) and host port `5353/UDP` → guest port `53/UDP` (DNS).
4. Prints the URL to open when the dashboard is ready.

Prerequisites: `qemu-system-x86_64`, `qemu-img`, `genisoimage` (Linux) or `mkisofs` / `hdiutil` (macOS — script adapts). About 300 MB of disk for the cached Debian image plus the appliance.

Press `Ctrl+A` then `X` to terminate the VM. The script cleans up its temp dir on exit.

## 3. Cloud VM (best for testing a real LAN)

Spin up a $5/mo Debian/Ubuntu VM at your provider of choice (Hetzner, DigitalOcean, Linode, Vultr), run the installer tarball, and point one device at it. Tear the VM down when you're done.

```sh
# On the cloud VM:
curl -sSLO https://www.veloguardian.com/downloads/veloguardian-dns-0.6.1-linux-amd64.tar.gz
tar -xzf veloguardian-dns-0.6.1-linux-amd64.tar.gz
cd veloguardian-dns-0.6.1
sudo ./install.sh
```

Open the firewall (`sudo ufw allow 8080`, `sudo ufw allow 53`), then on your test client device set the DNS to the VM's public IP. Browse for a few minutes, then check the Query Log page on the dashboard.

> ⚠️ **Cloud DNS exposure caveat.** Opening DNS port 53 on a public IP makes the appliance a candidate for DNS amplification abuse. The appliance has per-client rate limiting on by default, but for production use behind a real router, keep DNS on the LAN side only.

---

## What to look at first

Once the appliance is running and reachable:

1. **Dashboard** — confirm the appliance is receiving queries by browsing a few sites on a device pointing at it.
2. **Filtering → Categories** — see the 13 Argos groups + 75 categories with live per-group domain counts.
3. **Filtering → Profiles → Default → Edit** — toggle the `advertising` category on under the **Technology & Infrastructure** group. Browse to a page with ads; confirm the ads are gone and check the Query Log.
4. **Filtering → Profiles** — create a "Strict" profile with several category groups enabled, then map your test device to it under Filtering → Clients.
5. **System → Reports** — create a one-off report scoped to your test device for the last 1h and download the PDF.

This walks the main filtering pipeline and the report system end to end in about 5 minutes.
