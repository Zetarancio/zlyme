# Engineering principles

These are the default software-design principles for Zlyme.

They are intentionally concise. They are inspired by established software-engineering literature, especially *A Philosophy of Software Design*, *The Pragmatic Programmer*, and *Code Complete*, but are adapted to an embedded Linux handheld rather than copied as a generic rulebook.

When principles conflict, use this priority:

```text
hardware safety and correctness
        >
documented Zlyme architecture
        >
simplicity and maintainability
        >
performance proven by measurement
        >
style preferences
```

No principle overrides a device-safety requirement or a documented architecture decision.

## 1. Complexity is the primary design cost

Minimize the amount of system state and special knowledge a developer must hold in their head.

A change that reduces lines but increases hidden coupling is not simpler.

Prefer designs where a caller can use a component correctly without understanding its internals.

## 2. Prefer deep modules

A good module has:

- a small, stable interface;
- substantial useful behavior behind it;
- implementation details hidden from callers.

Avoid shallow wrappers that merely rename another API or pass every parameter through unchanged.

For Zlyme, commands such as `zlyme-audio` and `zlyme-governor` should expose semantic operations while hiding RK817/RK3566 details.

## 3. Hide information at the correct boundary

Hardware-specific knowledge should live near the hardware implementation.

Examples:

```text
generic caller              hardware implementation
--------------              -----------------------
set volume           ->     RK817 mixer controls
performance profile  ->     RK3566 CPU/GPU/DMC sysfs
shutdown             ->     board-specific power/storage sequence
```

Do not duplicate mixer names, GPIO numbers, DTB names, sysfs paths, or probe-order assumptions across unrelated files.

## 4. Pull complexity downward

If one module can absorb complexity once, prefer that over making every caller understand it.

Examples:

- resolve an ALSA card by stable ID inside the audio layer;
- derive device identity from one immutable metadata source;
- make the updater validate the device instead of requiring every caller to construct a perfect filename.

Do not pull unrelated policy into a low-level module merely to make a caller shorter.

## 5. Different layer, different abstraction

Each layer should add meaning.

Bad layering:

```text
wrapper_a() -> wrapper_b() -> ioctl()
```

where every layer exposes the same concepts.

Good layering:

```text
frontend: "performance profile = heavy"
        ->
zlyme governor policy
        ->
CPU/GPU/DMC hardware controls
```

Pass-through layers require a concrete justification.

## 6. Prefer explicit dependencies

A component should state what it needs.

Do not rely on:
- build order accidents;
- device enumeration order;
- undeclared libraries;
- hidden environment state;
- a service "usually" having started first.

Buildroot dependencies, init ordering, and runtime readiness should be visible.

## 7. Make invalid states difficult to create

Prefer interfaces that prevent mistakes rather than detecting them late.

Examples:

- update packages carry/derive a device identity;
- destructive operations validate their target;
- only documented sink IDs can be saved by `zlyme-audio`;
- board-specific packages cannot be selected for the wrong device.

If a failure mode can be removed by a better interface, prefer that to another warning message.

## 8. Fail fast at build and configuration boundaries

Build failures should be early, specific, and actionable.

Runtime behavior is different: optional hardware should degrade gracefully when possible.

Therefore:

```text
missing required DTB at build     -> fail
wrong update device               -> fail
missing optional Bluetooth device -> continue without Bluetooth
```

Do not silently convert a broken mandatory component into a degraded system.

## 9. Preserve one source of truth

Do not copy mutable facts into several files when they can be derived from one source.

Examples:
- selected device identity;
- NextUI platform name;
- update prefix;
- DTB name;
- patch ordering.

Duplication is acceptable for assertions that deliberately verify another source.

## 10. Avoid premature generalization

Zlyme supports one device today.

Do not build an elaborate device framework for devices that do not exist.

Create extension seams where the current implementation already reveals a natural boundary.

Generalize interfaces, not hypothetical hardware.

## 11. Avoid dogmatic DRY

Two similar pieces of code are not automatically the same abstraction.

Duplication is sometimes cheaper than coupling unrelated subsystems.

Extract shared code when the duplicated behavior has the same reason to change.

## 12. Apply YAGNI aggressively

Do not add:
- unused configuration knobs;
- compatibility layers for imagined devices;
- fallback paths that cannot currently be exercised;
- framework features with no current caller.

A future requirement can justify a future abstraction.

## 13. Design important interfaces twice

Before committing a new long-lived interface, consider at least two plausible shapes.

This is especially important for:
- board/runtime contracts;
- update formats;
- PAK metadata;
- service command-line APIs;
- input abstraction;
- frontend/emulator lifecycle.

Choose the interface that exposes the least implementation detail while remaining easy to debug.

## 14. Prefer reversible decisions when uncertainty is high

When hardware behavior is uncertain, make the experiment easy to back out.

Examples:
- selectable old/new joypad module during migration;
- optional Weston runtime rather than a permanent compositor;
- optional InputPlumber before making it a boot-critical dependency.

Do not make five irreversible architecture changes in one experiment.

## 15. Use tracer-bullet integration for risky features

For a large feature, first prove the complete minimal path.

Examples:

```text
Weston starts -> one app renders -> exits -> NextUI recovers
```

before integrating Wine, Xwayland, PortMaster policy, gamepad routing, and settings UI.

Likewise:

```text
new joypad module -> buttons + sticks + rumble -> suspend/resume
```

before replacing the old driver everywhere.

## 16. Separate mechanism from policy

Kernel drivers should expose hardware mechanisms.

Userspace should own policy where practical.

Examples:
- input driver reports input; InputPlumber may later define composite-controller policy;
- kernel/devfreq exposes frequency control; `zlyme-governor` chooses gaming profiles;
- DRM exposes display; launcher policy decides when a temporary Weston session is used.

Do not push frontend policy into a kernel driver.

## 17. Keep resource ownership obvious

At any moment it should be clear who owns:

- DRM master / seat;
- ALSA PCM/mixer routing;
- input grabs;
- mount points;
- update staging;
- radio power;
- kernel-module binding.

Ambiguous ownership produces intermittent embedded bugs.

Lifecycle transitions must have an explicit acquire/release path.

## 18. Prefer event-driven behavior

Use kernel/device events, file-descriptor readiness, inotify/uevent/evdev/ALSA events, and real readiness checks where appropriate.

Avoid:
- busy loops;
- frequent polling;
- fixed sleeps used as dependency management.

Polling is acceptable when the subsystem offers no reliable event and the cost is measured/controlled.

## 19. Keep the boot critical path intentionally small

Every operation before first frontend frame spends part of a finite startup budget.

For every new startup task ask:

1. Does the frontend require this?
2. Can it start after first frame?
3. Can it start on demand?
4. Can the application tolerate the resource appearing later?

Do not make a daemon Class A merely because it is useful.

## 20. Optimize after measurement

Do not accept "faster" based on intuition.

Performance work requires a baseline and a repeatable comparison.

Prefer:
- p95/p99 frame time;
- input/audio latency;
- underruns;
- sustained clocks;
- temperature/throttling;
- power;
- boot first-frame time.

Compiler flags are not architecture.

## 21. Keep experiments separate from production decisions

Research may explore many alternatives.

Production architecture records only decisions that survived validation.

Do not make an AI treat every note, abandoned patch, or historical workaround as current truth.

## 22. Remove code only after proving it is unused

"Looks unused" is not enough in an embedded distribution.

Before deleting a file/patch/package:
- search references;
- inspect generated/build-time use;
- inspect init/udev/module loading;
- build without it;
- run the relevant hardware test.

Deletion is a behavior change when the dependency graph is not proven.

## 23. Comments explain intent and constraints

Useful comments answer:
- why is this unusual?
- what hardware bug does it avoid?
- what upstream behavior does it compensate for?
- what breaks if it is removed?

Do not narrate obvious syntax.

## 24. Strategic fixes beat repeated tactical patches

A tactical fix is acceptable to restore functionality quickly.

When the same complexity appears repeatedly, stop adding local exceptions and repair the boundary that causes them.

Do not turn every small problem into a large refactor. The strategic fix must have a clear payoff.

## 25. Keep changes reviewable

One conceptual reason per change whenever practical.

Do not mix:
- dependency upgrades;
- formatting;
- architecture moves;
- behavior changes;
- performance tuning

unless they are inseparable.

Small diffs make hardware regressions easier to bisect.

## 26. Validate contracts, not just compilation

Compilation proves syntax and link compatibility.

For hardware-facing work, test the contract:
- device appears;
- suspend/resume survives;
- resources release correctly;
- frontend returns;
- OTA accepts/rejects the correct artifact;
- audio/input routing behaves as specified.

A feature is not supported merely because it builds.
