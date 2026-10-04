# Contributing to Zlyme

Thanks for looking. Zlyme is a small project built around one handheld, and it gets better every time someone else pokes at it.

## You don't need a patch to help

All of these count:

- a bug report with logs (Settings → System → Advanced → System logs, then the `/storage/.logs` folder);
- a correction to the docs or the hardware wiki;
- an emulator or core experiment, even one that failed, if you say what you measured;
- a new pak, or a better one;
- frame-time, power, temperature or current measurements from a real Flip;
- a review of code that's already here;
- a design idea or a question before you write anything.

## Talk first if it's big

For anything larger than a fix (a new subsystem, a different kernel patch, swapping an emulator, changing how updates or storage work), open an issue or ask in the [SpruceOS Discord](https://discord.gg/KjR5uMQQt9) first. Zlyme's discussion space is kindly hosted inside the SpruceOS server. It's cheaper to argue about a design than to rewrite a branch.

## Fork, branch, pull request

1. Fork `Zetarancio/zlyme` and branch off `main`.
2. Keep one idea per branch, and one reason per commit. Don't tidy unrelated code on the way past.
3. Open a pull request that says what changed, why, and how you checked it.

`./build.sh --config zlyme_my355_defconfig` builds the product image. You rarely need a full image to check an edit. [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) has the package-level rebuilds and the tests under `scripts/tests/`. Run the narrowest check that covers your change, and say which one you ran.

## Before you write code

Feed the repository's `docs/` folder to your coding assistant, or read it yourself. It explains how Zlyme is put together, why, and where things are owned. [AGENTS.md](AGENTS.md) is the operating contract for automated and maintainer work. You don't need to memorize it, but a pull request that breaks it will get pushback.

## Rules that don't bend

- **Hardware claims must be real.** "Tested on the Flip" means you ran it on a Flip. "Builds" and "boots" and "played an hour" are different claims. Say which one you mean.
- **Hardware facts belong in the [hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering).** Pinouts, register behavior, firmware protocols and measurements go there, with evidence. Zlyme's docs say how Zlyme uses them.
- **Provenance and licenses stay intact.** Say where code, patches and binaries came from. Keep authorship and license notices. Don't add ROMs, BIOS files, keys, commercial software or vendor binaries unless redistribution is clearly allowed.
- **Writing follows [docs/WRITING.md](docs/WRITING.md).** The README has a voice. The technical docs don't.

## AI-assisted work

Welcome. Give your tool the repository and the `docs/` folder. Then check what it produced the same way you'd check your own work: against the source, the tests and, for anything hardware-facing, a real Flip. A generated claim that nobody verified is not evidence.
