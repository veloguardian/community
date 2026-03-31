# VeloGuardian DNS

**Free, self-hosted DNS filtering appliance for your network.**

VeloGuardian DNS is a virtual appliance that provides network-wide DNS filtering. Deploy it on your LAN and every device on your network is protected — no per-device software required.

## Features

- **90+ filtering categories** — legacy category compatible taxonomy
- **Blocklist support** — Import and manage custom blocklists
- **Per-client profiles** — Different filtering rules for different devices
- **Web dashboard** — Dark-themed UI for configuration, monitoring, and reporting
- **Query logging** — See what's being blocked and allowed in real time
- **Console CLI** — Full management from the VM console
- **Auto-updates** — Signed update packages applied from the dashboard
- **No account required** — Fully self-contained, runs on your infrastructure

## Getting Started

1. **Download** the OVA from [veloguardian.com/dns.html](https://veloguardian.com/dns.html)
2. **Import** into VMware, VirtualBox, Proxmox, or Hyper-V
3. **Configure** your network's DNS to point to the appliance IP
4. **Access** the dashboard at `https://<appliance-ip>`

For detailed setup instructions, see the [Quick Start Guide](https://veloguardian.com/docs/dns/quick-start.html).

## Documentation

- [Quick Start Guide](https://veloguardian.com/docs/dns/quick-start.html)
- [Dashboard Guide](https://veloguardian.com/docs/dns/dashboard.html)
- [Blocklist Management](https://veloguardian.com/docs/dns/blocklists.html)
- [Console CLI Reference](https://veloguardian.com/docs/dns/console-cli.html)

## Feedback & Support

- **Bug reports:** [Open an issue](https://github.com/veloguardian/community/issues/new?template=dns-bug-report.yml)
- **Feature requests:** [Submit an idea](https://github.com/veloguardian/community/issues/new?template=dns-feature-request.yml)
- **Questions:** [Ask a question](https://github.com/veloguardian/community/issues/new?template=general-question.yml) or start a [Discussion](https://github.com/veloguardian/community/discussions)
- **Release notes:** [Changelog](CHANGELOG.md)

## Release Notes

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.
