# Phase 16. Diagnostics and defect discovery

Objective: give shipped launches a bounded diagnostic log, and, separately, search a bounded set of defects. A logging change is not itself that search.

Disposition: Closed, 2026-11-02. 16A, 16B, 16C, and 16D are closed. This is not a public release.

Accepted behavior: local OTA `zlyme-my355-20261031-4d1f74efea54.tar`, source `4d1f74efea54a731ff038edb31038527a3f4590d`, root SHA-256 `2cf9d268e5e724563c55cc7a16391425baade2b117d012874fa42962d9f8706f`. It is not the published `zlyme44.4` release. 16A, closed 2026-10-27, inventoried every shipped launcher and recorded RetroArch's `wb` log open. 16B, closed 2026-10-30 on local OTA `zlyme-my355-20261029-c8f952407098.tar`, accepted Game Boy in RetroArch, PSP standalone, and PortMaster. System logs take effect on the next boot. 16C accepted a NextUI reboot and a NextUI power-off on the 16C3 firmware. `zlyme-update` refuses a staged root that is not a SquashFS, including a symlink to one. 16D, on the same local image, switched system logs on and off through frontend-owned reboots. Game Boy Advance through gpSP, Tools → RetroArch with no ROM, and OpenBOR each started and returned to NextUI. OpenBOR also wrote its native logs. A logs-off launch did not create or rotate a PAK log, and that boot did not add a system generation.

Limitations: two `rc.late` copies still run with logs off. The other 16B launchers were not each run. A failed `/storage` unmount still continues into the forced shutdown. Status 125 recovery is deferred. A direct `reboot` without `-f` was not run on the Flip. The prelaunch window is unverified. Root replacement stays non-atomic under [ADR 0006](../decisions/0006-root-image-lifecycle.md). An unmounted `fsck.exfat -n` reported the volume clean and did not repair it. The dirty-bit origin is unknown. All 63 stock launchers are covered by source and host tests. That is not a Flip run of each one. Ruffle was not launched. None of the deferred items is a fix.

Records: [docs/LOGBOOK.md](../LOGBOOK.md), [docs/MAINTENANCE.md](../MAINTENANCE.md), [docs/research/phase-16-logging-inventory.md](https://github.com/Zetarancio/zlyme/blob/391508499a077efeb5e24ca966abab09cd635f5f/docs/research/phase-16-logging-inventory.md), [ADR 0012](../decisions/0012-diagnostic-logging.md), [docs/AUDITING.md](../AUDITING.md), and [ADR 0006](../decisions/0006-root-image-lifecycle.md). Each 16A–16D heading remains in the snapshot.

## Headings in the 2026-11-17 snapshot

- [Phase 16. Diagnostics and defect discovery](../archive/roadmap-2026-11-17.md#phase-16-diagnostics-and-defect-discovery)
- [16A. Logging inventory and contract](../archive/roadmap-2026-11-17.md#16a-logging-inventory-and-contract)
- [16B. Unified diagnostics](../archive/roadmap-2026-11-17.md#16b-unified-diagnostics)
- [16C. Bounded defect investigation](../archive/roadmap-2026-11-17.md#16c-bounded-defect-investigation)
- [16D. Logging validation](../archive/roadmap-2026-11-17.md#16d-logging-validation)

