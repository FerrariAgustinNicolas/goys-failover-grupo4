# F0 review and integration

## Intent and constraints
Safely integrate PR #4 (R5) before PR #3 (R2), preserving valid R1–R5 contributions and unsquashed author history. F0 deadline: 2026-10-02. Design/documentation only: no router CLI, F1 execution, force push, main history rewrite or personal credentials.

## Initial state
Main 5427689 (local fast-forwarded); R5 a634504 CLEAN; R2 feaecc6 CONFLICTING, base 784ea3e. Repo PUBLIC. Preserve untracked .gitignore and .codegraph/; neither enters commits.

## Tasks and routing
- [ ] T1 Correct and integrate PR #4. In progress: safe backup policy and truthful backlog/log corrected; independent verification and native review pending. Delegated writer because two nontrivial files; parent Git publication.
- [ ] T2 Merge new main into PR #3, reconcile semantically, consolidate security, diagram, backlog and log. Pending. Delegated writer; parent merge/history.
- [ ] T3 Audit resulting main and report gate/blockers. Pending. Independent read-only verifier; parent report.

## Acceptance and checks
Preserve authors and every valid role contribution. Public backups only inspected sanitized exports/metadata; sensitive exports and encrypted binaries remain private. HA is a production recommendation, residual single-EDGE SPOF, not applied. Correct minimum three defects without inventing appliances. Actual GNS3 interface mapping and restore evidence belong to F1. Verify complete diffs, IP math, unique IDs, key/service consistency, honest backlog, log coverage, conflict markers, required directories and absence of premature configs.

TDD: not applicable to documentation-only changes; no runner found. One writer. RDD on. Native ASSESS was unassessable (untracked declaration), so independent verification required. Normal merges per existing PR; original PR #4 257 changed lines, #3 43. Narrow corrections plus this tracking document expected below about 400 per slice, advisory only.

## Evidence and rationale
Parent fetched all refs and read full PR diffs/metadata. Independent verifier inspected Git and Python: combined main+R2 gives nine valid /30s, 33 unique assignments, 18 networks, 153 pairs, zero overlaps; main alone has five assigned RIDs (ISP pending). MikroTik primary Backup/VRRP documentation confirms explicit password required to encrypt binaries, sensitive private backup storage, and cleartext simple VRRP only protects accidental misconfiguration.

R5 writer passed diff whitespace/conflict checks; corrected unsafe publication, restored BASE ownership/SCP-SFTP/versioning/retention/same-device-version restore, kept F1–F5 unchecked, added existing a634504 log row and prospective unique R1 correction reference. No backups or router commands executed. Independent final PR4 verdict pending; no PR merged yet.

## Next step
Finish independent verification and native review of corrected R5 slice, commit/push without rewriting history, merge #4, then update #3. Never equate checklist text with acceptance evidence.
