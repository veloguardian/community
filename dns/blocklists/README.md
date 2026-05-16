# Recommended community blocklists

A curated list of community-maintained blocklists you can add to VeloGuardian DNS. Copy the URL into the dashboard's **Filtering → Blocklists → Add Blocklist** form, set the format, and assign the appropriate categories.

| Blocklist | URL | Format | Recommended categories | Notes |
|---|---|---|---|---|
| **Steven Black — Unified Hosts** *(ships enabled)* | `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts` | `hosts` | `advertising`, `malware` | The classic. Aggregated from dozens of sources. ~190K domains. Daily updates. |
| **OISD Small** *(ships enabled)* | `https://small.oisd.nl/` | `domains` | `advertising` | Curated, conservative ad list with low false-positive rate. ~70K domains. |
| **OISD Big** | `https://big.oisd.nl/` | `domains` | `advertising`, `malware`, `phishing` | Larger superset of OISD Small with broader coverage. ~200K domains. Use instead of OISD Small (not both). |
| **Phishing Army Extended** *(ships enabled)* | `https://phishing.army/download/phishing_army_blocklist_extended.txt` | `domains` | `phishing` | Phishing domains aggregated by Andrea Draghetti. ~28K domains. Hourly updates. |
| **URLhaus Malware Filter** *(ships enabled)* | `https://urlhaus.abuse.ch/downloads/hostfile/` | `hosts` | `malware` | Live malware C2/distribution hosts from abuse.ch. ~3K domains. Updates every 5 minutes. |
| **OISD NSFW** | `https://nsfw.oisd.nl/` | `domains` | `pornography` | Adult content; complements the Argos `pornography` category seed. |
| **Hagezi Pro++** | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/pro.plus.txt` | `hosts` | `advertising`, `malware` | Hagezi's "pro plus" tier — strong ad + tracker + malware coverage with the no-redirect-issues policy. ~150K domains. |
| **Hagezi TIF** | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/tif.txt` | `hosts` | `malware`, `phishing`, `botnet` | Threat-intelligence feed — phishing, malware, scam, ransomware C2. Strong signal-to-noise. |
| **AdAway** | `https://adaway.org/hosts.txt` | `hosts` | `advertising` | Mobile-focused ad list originally for Android, but works for any device. |
| **PiHole Default — Adlists** | `https://v.firebog.net/hosts/AdguardDNS.txt` | `domains` | `advertising` | AdGuard DNS list mirrored at firebog.net. |
| **Mullvad — Privacy List** | `https://github.com/mullvad/dns-blocklists/raw/main/output/relay/doh.txt` | `domains` | `analytics`, `advertising` | Mullvad's curated tracker + analytics list. ~135K domains. Conservative — low false positives. |
| **Energized Ultimate** | `https://block.energized.pro/ultimate/formats/hosts` | `hosts` | `advertising`, `malware`, `pornography` | Maximalist all-in-one blocklist. ~600K domains. Higher false-positive rate — use with care. |
| **Cybercrime Tracker** | `https://cybercrime-tracker.net/all.php` | `domains` | `malware`, `botnet` | C2 / malware tracker. |
| **ThreatFox** | `https://threatfox.abuse.ch/downloads/hostfile/` | `hosts` | `malware`, `botnet` | abuse.ch threatfox feed — indicators of compromise. |

## Picking a starter set

A pragmatic default that covers ~95% of unwanted traffic without breaking legitimate sites:

1. **Steven Black — Unified Hosts** (advertising, malware) — shipped enabled
2. **OISD Small** (advertising) — shipped enabled
3. **Phishing Army Extended** (phishing) — shipped enabled
4. **URLhaus Malware Filter** (malware) — shipped enabled
5. **Hagezi TIF** (malware, phishing, botnet) — add this

That's it. Don't pile on more advertising lists — the marginal coverage from list #6 is usually negative (more false positives than additional blocks). If you want stronger blocking, swap OISD Small for OISD Big rather than enabling both.

## Format reference

| Format | What it expects |
|---|---|
| `hosts` | Each line: `<ip> <domain>` (e.g., `0.0.0.0 ads.example.com`). VeloGuardian DNS ignores the IP and treats the domain as block. Comments start with `#`. |
| `domains` | Each line: a single domain (e.g., `ads.example.com`). Comments start with `#` or `!`. |
| `adblock` | EasyList-style rules. VeloGuardian DNS extracts only exact-domain block rules (`\|\|example.com^`). Complex rules (cosmetic filters, scriptlets, URL pattern matches) are ignored. |

## How filtering categories interact with blocklists

A domain is blocked when ANY of these is true:

1. The domain matches a `deny` rule in the active profile.
2. The domain appears in any blocklist whose category is in the active profile's blocked-category set.
3. (Wildcard) A parent domain matches one of the above.

A domain is allowed (overriding the above) when an `allow` rule in the active profile matches.

So: a blocklist alone does nothing. You assign categories to the blocklist when adding it, and those categories must be in the active profile's blocked list. Otherwise the blocklist is loaded but inert.

## Submitting new blocklists

If you'd like a curated community blocklist added to this list, [open an issue](https://github.com/veloguardian/community/issues/new?template=dns-feature-request.yml) with the URL, format, suggested categories, source maintainer, and a one-line description of what it blocks.
