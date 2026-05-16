# VeloGuardian DNS — Changelog

All user-visible changes to VeloGuardian DNS appliance releases.

This changelog covers releases that have been published to the official download server. For pre-release internal builds, see the release notes shipped with each `.vgupdate` package.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

---

## [0.6.1] — 2026-05-14

### Fixed

- **Boot-time pre-flight self-heal of the category seed directory.** When upgrading from v0.5.0 (or earlier) in place via the `.vgupdate` system, the new binary's pre-flight check refused to start because the on-disk `.txt` seed files still used the legacy pre-Argos filenames. `.vgupdate` packages ship binaries only — not seed files — so the rename had to happen in-process. The new pre-flight performs the legacy → Argos rename/merge/drop on disk using the same mapping the migration uses, transparently, on first boot after upgrade. Operator-curated content in pre-existing target files is preserved verbatim. Idempotent.
- The pre-flight + auto-rollback safety net behaved correctly throughout the v0.6.0 deploy attempt — the appliance never served traffic with a broken filter engine. The fix is purely additive and data-preserving.

## [0.6.0] — 2026-05-14

### Argos taxonomy alignment (Phase 1)

The headline feature of this release. The category taxonomy moved from a legacy 91-slug layout to **VeloGuardian Argos** — 13 groups × 75 categories — the universal classification standard across every VeloGuardian product. The migration is in-place, idempotent, and rewrites every category reference in profiles, blocklists, schedules, and the on-disk seed files in a single boot.

### Added

- `internal/categories/` package: Argos taxonomy snapshot in Go constants (single source of truth at runtime), pre-flight seed-file self-heal (`PreflightFileState`), and dual-verify invariant (`VerifyDatabaseMatchesConstants` — runs twice per boot, before and after migration application, to catch constants-vs-SQL drift).
- Migration `011_argos_taxonomy.sql` — creates `category_groups` and `categories` tables, seeds 13 groups + 75 categories, rewrites legacy slugs across `profiles.categories`, `blocklists.categories`, `profile_schedules.blocked_categories`.
- `/api/categories` response shape is now nested: `{data: {groups: [{slug, name, description, display_order, categories: [{slug, name, description, display_order, domain_count}]}]}}`. Server-side ordering by `group.display_order, category.display_order`.
- Backup format gained a `schema_version` field. `POST /api/backup/restore` rejects (HTTP 400) any backup whose `schema_version` does not match the running appliance — symmetric on older / newer / zero, by design. Take a fresh backup on the destination's version before any major-version upgrade.
- React Categories page rewritten to consume the nested API shape directly. No client-side group ordering.

### Changed

- The Reports page's "Security blocked" pie chart is now driven by a DB-derived set of slugs (`category_groups.slug='security-threats'` → 8 Argos slugs) rather than a hardcoded 9-slug legacy list. As the taxonomy evolves, the report set evolves with it.
- The default blocklists' category assignments use Argos slugs (`malware` instead of `malicious-websites`, etc.).

### Removed

- The legacy `# @group:` directive in category `.txt` seed files is no longer parsed. Group membership comes from the DB join. Existing `# @group:` lines are stripped during the pre-flight self-heal.

### Migration notes for operators

- **In-place upgrade from 0.5.x is automatic.** The 0.6.1 binary's pre-flight self-heals the seed directory before migration 011 runs. No operator action required.
- **One visible regression:** the `hacking-tools` category moved out of the Security Threats group and into Illegal & Harmful (the Argos taxonomy classifies it there). The Reports page's "Security blocked" pie chart no longer includes hacking-tools. Toggle Illegal & Harmful in your profile if you want it in the security view.
- **6 Argos categories are empty in Phase 1** (`botnet`, `file-storage`, `piracy`, `research`, `tor`, `uncategorized`). The legacy taxonomy did not carry data for them. They will be populated in Phase 2, when the appliance gains a live delta sync with the central Argos service.

> ⚠️ **0.6.0 was superseded by 0.6.1 within hours.** The original 0.6.0 binary did not include the pre-flight self-heal, so in-place upgrades from 0.5.x auto-rolled back. Use 0.6.1 or later. If you somehow downloaded the original 0.6.0 `.vgupdate` package, apply 0.6.1 on top of 0.5.x; it self-heals correctly.

## [0.5.0] — 2026-05-03

### Added

- **Per-tier DNS routing.** Per-tier subnet-to-profile mappings: `10.90.0.0/16 → Sentry`, `10.91.0.0/16 → Shield`, `10.92.0.0/16 → Fortress`, `10.93.0.0/16 → Citadel`. The default fleet configuration aligns with this layout.
- **Heartbeat payload gained `hostname`.** Read once at startup via `os.Hostname()` and sent to apollo on every heartbeat. Empty string fallback if the syscall fails. Older appliances heartbeating without the field do not clobber a previously-set value (apollo writes conditionally).
- **Operator-edited `label` column** on the apollo `dns_instances` table. Apollo-side only — the appliance never sends or sees this. Use the install-base page's pencil-edit UI to set a human-friendly name (e.g., "ELAN VGDNS", "Office floor 3"). The label persists across heartbeats; the hostname overwrites itself on every heartbeat.
- Standardized fleet configuration: 5 default profiles (Default + Sentry/Shield/Fortress/Citadel), per-tier `log_queries` defaults (Citadel logs, everyone else doesn't), tier-specific blocked-category sets.

### Changed

- Stress-tested on a single-vCPU host: 6,365 qps achieved with logging enabled, 9,556 qps with logging disabled. Recommendation: bump to 2 vCPUs if you expect peaks ≥ 10 qps per active user.

## [0.4.0] — 2026-04-30

### Added — Privacy controls

- **Global IP-mask toggle**, wired end-to-end. When enabled, all per-IP attribution in both `query_log` and `stats_hourly.top_clients` is masked: IPv4 → `/24`, IPv6 → `/48`. Implemented via the single shared `internal/privacy.MaskIP` primitive imported by both the query-log writer and the stats collector.
- **Per-profile `log_queries` flag** (default `true`). When set to `false`, the DNS handler short-circuits the query-log row write entirely while stats counters continue to increment. Lets you serve a strict no-log tier (per Argos profile) without losing aggregate dashboard metrics.
- Migration `010_add_profile_log_queries.sql` introduces the column. Uses the SQLite 12-step rebuild pattern for its Down branch with `-- +goose NO TRANSACTION` so the `PRAGMA foreign_keys=OFF` actually takes effect (`PRAGMA foreign_keys` is a silent no-op inside an active transaction).
- Backup/restore round-trip updated to carry the new column.
- Settings page exposes both controls under **Settings → Privacy**.

### Verified under load

- ~340K queries with `log_queries=false` → exactly 1 row written. Mid-stream toggle false → true at T+10s of a 60s × 2K qps run wrote zero rows for the first 10s and exactly 60,236 rows for the next 30s. No buffer drops in any run. Memory stable.

## [0.3.x] — pre-2026-04-30

Pre-launch release line, focused on the dashboard, PDF report system, and OVA hardening. Highlights:

- **0.3.2** — Branded dark-themed HTML email templates for report delivery and SMTP test emails.
- **0.3.1** — PDF improvements: security category pie chart, compact bar rows, page-splitting fix.
- **0.3.0** — PDF redesign: modern layout with logo, professional colors, top 10 allowed + blocked on page 1.

## [0.2.x] — earlier

- **0.2.8** — Heartbeat telemetry to VeloGuardian apollo.
- **0.2.7** — Reporting system: PDF reports, email delivery, scheduler, IP groups, SMTP settings.
- **0.2.5** — Dashboard and login UI improvements.

---

## Versioning policy

- **Major version bumps** (e.g., 0.x → 1.0, eventually 1.x → 2.x) ship breaking changes to the data schema, the API, or the upgrade path. Take a fresh backup on the destination's version before applying.
- **Minor version bumps** (0.5 → 0.6) ship significant new features. In-place upgrades are supported but may require schema migrations; the pre-flight + dual-verify invariant guards against drift.
- **Patch version bumps** (0.6.0 → 0.6.1) are bugfixes and small improvements. Safe to apply at any time.

## Verifying releases

Every published `.vgupdate` package is signed with the project's Ed25519 release key. The public key is embedded in every appliance binary and printed in [INSTALL.md](INSTALL.md#verifying-signatures). The signature is verified before any update is applied; the `.vgupdate` apply path will refuse to install an unsigned or invalidly-signed package.

For installer tarballs, a SHA-256 sidecar is published next to every release tarball on the download server (`veloguardian-dns-<version>-linux-amd64.tar.gz.sha256`). Verify with `sha256sum -c` before unpacking.
