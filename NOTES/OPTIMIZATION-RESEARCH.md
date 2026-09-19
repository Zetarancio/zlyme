Yes. On an RK3566 handheld, I would optimize the kernel less like a “desktop gaming kernel” and more like an **appliance kernel with aggressive device-specific power/performance control**.

The biggest gains will not come from `-O3`. They will come from **CPU/GPU/DDR frequency management, removing jitter, avoiding useless drivers/workqueues, and having a very small board-specific configuration**.

For the Miyoo Flip specifically, the current mainline work is already at Linux 7.0.x, with Mali-G52 at 200–800 MHz and an out-of-tree DMC driver capable of DDR devfreq up to 1056 MHz. That DMC work is particularly important: memory bandwidth can matter a lot for GPU-heavy emulators. ([GitHub][1])

## My priorities, in order

### 1. Get DDR/DMC scaling right first

I would put this above most scheduler tweaks.

The Flip's current mainline work defines DMC operating points at:

```text
324 MHz
528 MHz
780 MHz
1056 MHz
```

and uses a Rockchip-specific out-of-tree DMC devfreq implementation because upstream mainline still doesn't have a drop-in equivalent for the proprietary RK3566 V2 SIP/MCU mechanism. ([GitHub][2])

For demanding emulators, test:

```text
CPU: max/performance
GPU: max/performance
DMC: max/performance
```

versus dynamic DMC.

For PSP/Dreamcast/Saturn/N64, locking DDR high may improve **1% lows** more than another kernel compiler flag.

I would implement a per-system profile:

```text
NES/SNES/GBA:
    CPU schedutil
    GPU ondemand
    DMC ondemand

PS1:
    CPU schedutil/performance
    GPU ondemand
    DMC ondemand

N64/DC/Saturn/PSP:
    CPU performance
    GPU performance
    DMC performance
```

Not permanent max clocks.

---

## 2. CPU governor: use `performance` only while gaming hard systems

Linux's `performance` governor requests the highest frequency allowed by the policy, whereas `schedutil` uses scheduler utilization directly. ([Kernel Documentation][3])

For an emulator where consistent frametimes matter more than battery:

```text
performance
```

is a perfectly valid choice.

For menu / SNES / GBA:

```text
schedutil
```

makes more sense.

I'd avoid old `ondemand` as your architectural default even though ROCKNIX has used it on RK3566. `schedutil` is more tightly integrated with the scheduler and avoids the separate periodic worker mechanism used by `ondemand`. ([Kernel Documentation][3])

A useful experiment is decreasing:

```text
schedutil/rate_limit_us
```

from its normal millisecond-scale behavior to perhaps:

```text
500–1000 µs
```

and benchmarking.

Do not assume lower is always better: it increases governor activity.

---

# 3. PREEMPT_DYNAMIC

I would compile:

```text
CONFIG_PREEMPT_DYNAMIC=y
```

and benchmark at runtime:

```text
preempt=full
```

against:

```text
preempt=voluntary
```

Current ARM64 supports dynamic preemption, and current Linux allows choosing `none`, `voluntary`, or `full` through the kernel command line when `CONFIG_PREEMPT_DYNAMIC` is enabled. ([GitHub][4])

For your use case, my starting choice would be:

```text
preempt=full
```

because an interactive handheld benefits more from low scheduling latency than absolute server-style throughput.

But measure it.

You care about:

```text
frame-time p99
audio underruns
input latency
```

rather than kernel compile benchmarks.

I would **not use PREEMPT_RT**. That's solving a different problem and adds complexity you don't need.

---

# 4. HZ=1000 is worth testing

I'd start with:

```text
CONFIG_HZ_1000=y
```

rather than 250.

Upstream's Kconfig describes 1000 Hz as the preferred choice for systems requiring fast interactive response; 250 Hz is the general compromise. ([GitHub][5])

For a quad-core A55 appliance, the increased tick overhead is small enough that I'd benchmark it.

Candidates:

```text
HZ=250
HZ=1000
```

I suspect I'd keep 1000 for your use case.

Combined with:

```text
CONFIG_HIGH_RES_TIMERS=y
CONFIG_NO_HZ_IDLE=y
```

### But don't immediately use `NO_HZ_FULL`

I would **not** start with:

```text
CONFIG_NO_HZ_FULL=y
isolcpus=
rcu_nocbs=
```

Linux itself describes `NO_HZ_FULL` mainly as useful for realtime/HPC workloads and not normally desirable for general workloads. ([Kernel][6])

On only four A55 cores you can very easily hurt an emulator that uses multiple threads.

Later you could experiment with:

```text
CPU0 → kernel IRQ/background
CPU1-3 → emulator
```

but I'd do it with CPU affinity first, not kernel isolation.

---

# 5. Manually manage IRQ affinity

This is potentially more useful than exotic schedulers.

You have four identical Cortex-A55 cores.

I would experiment with:

```text
CPU0:
    Wi-Fi interrupts
    SD/MMC
    USB
    miscellaneous kernel work

CPU1-3:
    emulator
```

Or for single-thread-heavy emulators:

```text
CPU3:
    main emulation/JIT thread

CPU1-2:
    renderer/audio/helper threads

CPU0:
    OS IRQs/background
```

Set with:

```text
/proc/irq/*/smp_affinity
```

plus `sched_setaffinity()` / `taskset()` for emulator processes.

Don't blindly put audio interrupts on an overloaded background CPU; audio latency has to be tested separately.

This is where your own launcher daemon could do better than a general distro.

---

# 6. GPU devfreq matters more than kernel `-O3`

Upstream RK3566 defines GPU OPPs:

```text
200 MHz
300 MHz
400 MHz
600 MHz
700 MHz
800 MHz
```

for the Mali-G52. ([GitHub][7])

The Flip BSP/mainline work confirms active 200–800 MHz GPU devfreq and thermal integration. ([GitHub][8])

So provide:

```text
balanced:
    simple_ondemand

performance:
    performance
```

For PPSSPP/Flycast/YabaSanshiro, lock 800 MHz during benchmarks.

You'll then know whether GPU frequency transitions were causing frametime spikes.

---

# 7. CPU OPP table: first optimize voltage, then overclock

Mainline RK3566 officially defines CPU OPPs through:

```text
408 MHz
600
816
1104
1416
1608
1800 MHz
```

with 1.8 GHz at 1.15 V. ([GitHub][7])

ROCKNIX additionally exposes **2 GHz overclocking and three undervolt levels** on RK3566. Their own documentation notes that undervolting can improve sustained performance by reducing thermal throttling, but that not every chip is stable at the same voltage. ([GitHub][9])

This is important:

**a stable 1.8 GHz undervolted system can outperform a 2.0 GHz system that thermally throttles.**

I would implement profiles like:

```text
stock:
1800 MHz / upstream voltage

UV1:
1800 MHz / small undervolt

UV2:
1800 MHz / medium undervolt

OC:
1992/2000 MHz / validated voltage
```

and never silently enable OC globally.

Run long stress + emulator tests per device.

---

# 8. Keep thermal throttling functional

Do **not** “optimize” by disabling thermal control or raising trip points arbitrarily.

That gives great five-minute benchmark results followed by:

```text
thermal saturation
↓
frequency collapse
↓
worse sustained performance
```

Use:

```text
CONFIG_ROCKCHIP_THERMAL=y
CONFIG_DEVFREQ_THERMAL=y
```

where appropriate to your driver stack.

Then optimize voltage and cooling policy.

ROCKNIX explicitly found undervolting useful for sustained PPSSPP/YabaSanshiro performance. ([GitHub][9])

---

# 9. Make the kernel Miyoo-Flip-only

This is one of the safest optimizations.

Don't use an enormous RK3566 multi-device config.

Strip support for hardware that physically cannot exist:

```text
PCIe
SATA
NVMe
unused Ethernet PHYs
unused Rockchip boards
camera stacks
industrial I/O
unused touchscreen controllers
hundreds of USB Wi-Fi drivers
unused filesystems
unused HID drivers
virtualization
Xen
KVM
containers
NUMA
```

On this Flip, the current hardware work already documents things that can be disabled: unused combphy blocks, unused USB controllers, nonexistent alternate CPU-regulator hardware, etc. ([GitHub][2])

But remember:

**this mostly improves boot time, image size, memory footprint and maintainability — not emulator FPS.**

A dormant Ethernet driver isn't consuming 5% CPU.

---

# 10. Built-in essential drivers, modules for optional hardware

For boot-critical components I'd use built-ins:

```text
MMC/SD
GPIO
pinctrl
RK817
RK8600
display/DSI
backlight
input
DRM/GPU
audio if always needed
```

Then potentially keep these modular/on-demand:

```text
RTL8733BU Wi-Fi
Bluetooth
optional USB devices
extra filesystem support
```

This gives you an interesting handheld optimization:

```text
boot without networking
    ↓
don't even load Wi-Fi/BT drivers
```

until the user enables them.

Less boot work, less RAM and fewer background wakeups.

Be careful with the Flip Wi-Fi/BT power sequence: current mainline work has specific resume and GPIO-power handling for RTL8733BU. ([GitHub][1])

---

# 11. Disable kernel debugging in release builds

Your development kernel should have instrumentation.

Your shipping kernel should not.

I'd remove at least:

```text
CONFIG_DEBUG_KERNEL=n
CONFIG_DEBUG_INFO=n
CONFIG_GCOV_KERNEL=n
CONFIG_KCOV=n
CONFIG_KASAN=n
CONFIG_UBSAN=n
CONFIG_LOCKDEP=n
CONFIG_PROVE_LOCKING=n
CONFIG_DEBUG_SPINLOCK=n
CONFIG_DEBUG_MUTEXES=n
CONFIG_DEBUG_ATOMIC_SLEEP=n
```

and generally disable tracing/profiling that you don't use in production:

```text
FTRACE
FUNCTION_TRACER
KPROBES
UPROBES
PERF_EVENTS
```

**only after you're done profiling.**

For your dev kernel, keep:

```text
perf
ftrace
tracepoints
```

because you need them to find the real problems.

A good setup is:

```text
miyoo_flip_debug_defconfig
miyoo_flip_release_defconfig
```

---

# 12. Don't chase `-O3`

Current Linux does support a kernel `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3`, and ARM64 supports Clang ThinLTO. But upstream still treats LTO as optional/experimental territory rather than a guaranteed performance switch. ([GitHub][10])

I would use:

```text
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y
```

i.e. normal `-O2`.

Not:

```text
-O3 everything
```

until you've benchmarked it.

Kernel hot paths are already heavily hand-optimized and inline-sensitive. `-O3` can increase code size and instruction-cache pressure, which is especially relevant on a small Cortex-A55.

Likewise I would not make ThinLTO part of the first release.

Much bigger gains are available elsewhere.

And I would use:

```text
-mcpu=cortex-a55
```

aggressively for **userspace/emulators**, not start by forcing it globally into kernel `KCFLAGS`.

---

# 13. Keep 4K pages

ARM64 allows larger kernel page sizes, but for this project I'd stay with:

```text
CONFIG_ARM64_4K_PAGES=y
```

Compatibility is more important.

You are dealing with:

```text
PortMaster
proprietary ARM binaries
JITs
32-bit compatibility
emulators
possibly Box64
```

A nonstandard page size can create extremely annoying compatibility issues for negligible practical advantage on this device.

---

# 14. Transparent Huge Pages: `madvise`, not `always`

For an embedded system, current kernel documentation specifically recommends restricting THP to `madvise` regions rather than enabling it globally, to avoid wasting memory. ([Kernel Documentation][11])

I'd use:

```text
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y
```

or:

```text
transparent_hugepage=madvise
```

Not `always`.

Then if an emulator/JIT can explicitly benefit from huge pages, let that program ask for them.

---

# 15. Multi-Gen LRU is sensible if your Flip has memory pressure

For a modern mainline kernel I'd enable:

```text
CONFIG_LRU_GEN=y
CONFIG_LRU_GEN_ENABLED=y
```

MGLRU is designed to improve page reclaim behavior and reduce reclaim CPU overhead/jank under memory pressure. ([Kernel Documentation][12])

It won't make SNES faster.

It can make a constrained machine behave much better when:

```text
frontend
artwork cache
RetroArch
large ROM
shader cache
network services
```

start competing for RAM.

---

# 16. Avoid disk swap while gaming

If you need swap at all, use a modest zram device rather than SD swap.

Linux zram stores compressed pages in RAM and avoids physical storage I/O. ([Kernel Documentation][13])

But if you have enough RAM, I'd rather avoid swap activity during gameplay entirely.

A compressed-page storm consumes your Cortex-A55s too.

---

# 17. Optimize boot separately

For a BaseOS-like system, boot performance is its own project.

Use:

```text
initcall_debug
```

temporarily to identify slow kernel initcalls; Linux provides it specifically for tracing kernel initialization. ([Kernel Documentation][14])

Then remove slow/unnecessary probes.

Typical structure:

```text
BootROM
 ↓
SPL + DDR
 ↓
U-Boot
 ↓
kernel
 ↓
essential drivers only
 ↓
BusyBox init
 ↓
launcher
```

Also test kernel compression separately:

```text
uncompressed Image
LZ4
gzip
zstd
```

On SD storage, compressed images reduce I/O but require decompression; which wins is device-specific.

Don't guess.

---

# 18. The DDR init blob matters before Linux even starts

This is an unusually important RK3566 detail.

The Flip work documents RK3566 DDR init binaries and current ROCKNIX boot logs using newer Rockchip DDR firmware. The DDR initialization stage happens **before Linux**. ([GitHub][8])

So if you're optimizing memory performance, also validate:

```text
SPL DDR initialization
BL31
Linux DMC OPPs
DMC governor
```

as one coherent system.

A perfect kernel governor cannot recover bandwidth that the preloader configured incorrectly.

---

# What I would actually put in your kernel config

Something roughly like:

```text
# Scheduler / latency
CONFIG_PREEMPT_DYNAMIC=y
CONFIG_HZ_1000=y
CONFIG_HIGH_RES_TIMERS=y
CONFIG_NO_HZ_IDLE=y

# CPU scaling
CONFIG_CPU_FREQ=y
CONFIG_CPU_FREQ_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y
CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y

# Idle
CONFIG_CPU_IDLE=y

# Device frequency scaling
CONFIG_PM_DEVFREQ=y
CONFIG_DEVFREQ_GOV_PERFORMANCE=y
CONFIG_DEVFREQ_GOV_SIMPLE_ONDEMAND=y
CONFIG_DEVFREQ_THERMAL=y

# Rockchip
CONFIG_ROCKCHIP_THERMAL=y

# Flip-specific DMC implementation
CONFIG_DEVFREQ_EVENT_ROCKCHIP_DFI=y
# + current RK3566 DMC patch/config as required

# Memory
CONFIG_LRU_GEN=y
CONFIG_LRU_GEN_ENABLED=y
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y

# Architecture
CONFIG_ARM64_4K_PAGES=y

# Compiler
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y

# Release kernel:
CONFIG_DEBUG_KERNEL=n
CONFIG_DEBUG_INFO=n
CONFIG_KASAN=n
CONFIG_UBSAN=n
CONFIG_GCOV_KERNEL=n
```

And I'd boot it initially with:

```text
preempt=full transparent_hugepage=madvise
```

---

# My “performance mode” at runtime

When PPSSPP/Flycast/YabaSanshiro/N64 launches:

```text
CPU governor       performance
CPU max            1.8 GHz initially
GPU governor       performance
GPU max            800 MHz
DMC governor       performance
DDR max            1056 MHz
frontend rendering stopped
Wi-Fi background work minimized
process affinity   tuned
```

And when returning to the menu:

```text
CPU                schedutil
GPU                 simple_ondemand
DMC                 simple_ondemand
```

Then I'd test an optional:

```text
CPU = 2.0 GHz
```

profile separately.

Upstream RK3566 uses 1.8 GHz CPU and 800 MHz GPU; ROCKNIX's 2 GHz mode is an additional overclock, not the upstream baseline. ([GitHub][7])

## What I would *not* waste much time on initially

I would not start with:

```text
custom desktop schedulers
BORE/BMQ patches
PREEMPT_RT
NO_HZ_FULL
isolcpus
-O3 kernel
full kernel LTO
disabling security mitigations
exotic memory allocators
2 GHz overclock
```

Those are second- or third-order experiments.

For this exact hardware I expect the biggest real improvements to come from:

**DMC/DDR → CPU/GPU devfreq → sustained thermal behavior → direct KMS userspace → emulator-specific performance profile → IRQ/process affinity → scheduler/HZ tuning → compiler tricks.**

And the unusually interesting part of the Miyoo Flip is **DMC**. Your current mainline work already exposes 324/528/780/1056 MHz DDR OPPs and has the necessary out-of-tree driver. I would benchmark `DMC performance` vs `simple_ondemand` on N64, Saturn, Dreamcast and PSP before touching exotic scheduler patches. ([GitHub][2])

[1]: https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering "GitHub - Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering: A place where I summarize all the stuff related to the miyoo flip. I do not think it will ever be updated but I did not want all the researches I did on the stock firmware to be lost. · GitHub"
[2]: https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/drivers-and-dts/board-dts-pmic-ddr-updates.md "Miyoo-Flip-Mainline-Linux-Reverse-Engineering/docs/drivers-and-dts/board-dts-pmic-ddr-updates.md at main · Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering · GitHub"
[3]: https://docs.kernel.org/6.17/admin-guide/pm/cpufreq.html?utm_source=chatgpt.com "CPU Performance Scaling — The Linux Kernel documentation"
[4]: https://github.com/torvalds/linux/blob/master/arch/arm64/Kconfig?utm_source=chatgpt.com "linux/arch/arm64/Kconfig at master · torvalds/linux · GitHub"
[5]: https://github.com/torvalds/linux/blob/master/kernel/Kconfig.hz?utm_source=chatgpt.com "linux/kernel/Kconfig.hz at master · torvalds/linux · GitHub"
[6]: https://www.kernel.org/doc/html/latest/timers/no_hz.html?utm_source=chatgpt.com "NO_HZ: Reducing Scheduling-Clock Ticks — The Linux Kernel documentation"
[7]: https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/rockchip/rk3566.dtsi?utm_source=chatgpt.com "linux/arch/arm64/boot/dts/rockchip/rk3566.dtsi at master · torvalds/linux · GitHub"
[8]: https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/stock-firmware-and-findings/bsp-and-ddr-findings.md "Miyoo-Flip-Mainline-Linux-Reverse-Engineering/docs/stock-firmware-and-findings/bsp-and-ddr-findings.md at main · Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering · GitHub"
[9]: https://github.com/ROCKNIX/rocknix.org/blob/main/includes/platforms/rk3566.md?utm_source=chatgpt.com "rocknix.org/includes/platforms/rk3566.md at main · ROCKNIX/rocknix.org · GitHub"
[10]: https://github.com/torvalds/linux/blob/master/arch/Kconfig?utm_source=chatgpt.com "linux/arch/Kconfig at master · torvalds/linux · GitHub"
[11]: https://docs.kernel.org/admin-guide/mm/transhuge.html?utm_source=chatgpt.com "Transparent Hugepage Support — The Linux Kernel documentation"
[12]: https://docs.kernel.org/mm/multigen_lru.html?utm_source=chatgpt.com "Multi-Gen LRU — The Linux Kernel documentation"
[13]: https://docs.kernel.org/admin-guide/blockdev/zram.html?utm_source=chatgpt.com "zram: Compressed RAM-based block devices — The Linux Kernel documentation"
[14]: https://docs.kernel.org/admin-guide/kernel-parameters.html?utm_source=chatgpt.com "The kernel’s command-line parameters — The Linux Kernel documentation"
