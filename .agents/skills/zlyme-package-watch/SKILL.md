---
name: zlyme-package-watch
description: Investigate updated KNULLI or Batocera recipes, emulator versions, dependencies, and patches, and report a proposal without applying it. Use when asked to compare a Zlyme package with knulli-linux or batocera.linux.
---

# Package watch

This procedure is optional. Follow `AGENTS.md`. It does not replace `docs/UPSTREAMS.md`, `docs/MAINTENANCE.md`, or `docs/DEVELOPMENT.md`.

The default operation is read-only. Do not change a pin, copy a patch stack, launcher, filesystem layout, or service framework, upgrade a dependency, or import an asset whose license is unknown. Do not build, make an OTA, or run a hardware test. A comparison of recipes does not advance a reviewed-through cursor. A component pin is not that cursor.

Before a comparison:

1. Read `docs/UPSTREAMS.md` for the source hierarchy, the package procedure, and the patch classes.
2. Read `docs/MAINTENANCE.md` and `docs/DEVELOPMENT.md` for the update and build boundaries.
3. Read [phase-17-upstream-monitor.md](../../../docs/research/phase-17-upstream-monitor.md).

Then:

1. Identify the Zlyme recipe, the component's own upstream, and Zlyme's current pin. Do not take "latest" from another distribution.
2. Verify the live tips of `knulli-cfw/knulli-linux` branch `knulli-main` and `batocera-linux/batocera.linux` branch `master`. Do not use archived `knulli-cfw/distribution`. A local checkout is optional and is not a required path.
3. Locate the corresponding recipes. A standalone program, a libretro core, and a fork are different packages.
4. Compare version, dependencies, build options, patch stacks, and license. Include a later correction or revert. Check whether the component upstream already has the fix.
5. Check Zlyme's graphics, input, audio, storage, and runtime contracts.
6. Classify with the classes in `docs/UPSTREAMS.md`. Keep the proposal separate from the change. Name the host package build, and name a device test only when the change can affect the device. A host build is not Miyoo Flip acceptance.
