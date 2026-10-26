# Phase 15D — Save-bind ownership

Date: 2026-10-27. This is a design note. It does not move code.

PPSSPP, Dolphin, and Flycast each have a script that records a bind by mount id, refuses a destination that is already mounted, and lets `pak-launch.sh` release that id after the emulator exits. The sequence is the same. The policies are not: two PSP save directories, GameCube and Wii directories, and one Flycast directory that has to stay mounted until Flycast writes its autosave. Each has its own registry and its own unresolved-session marker.

The identity primitives live in `package/system/portmaster/zlyme-portmaster-mounts.sh`. Dolphin and NextUI call them without a package dependency on PortMaster. The product defconfig selects all three, so the image works. The boundary is still wrong.

Two ways to repair it:

1. Leave the PortMaster script where it is. Add one Zlyme script that performs the save-bind sequence. Each emulator keeps a short adapter for its destinations, registry, and session marker.
2. Move the generic mount-id functions into a Zlyme module, point PortMaster at that module, and build the save-bind script on top.

Option 1 is the smaller change. It does not reopen the PortMaster cleanup that has already been exercised. Option 2 is the cleaner package boundary and a larger risk, because PortMaster's proved cleanup would move with the primitives.

This pass does not extract the script. The PPSSPP controller-file fix and the status-125 marker are the behavior changes. Folding the three copies together is a separate change, and principles 24 and 25 say not to hide it inside those fixes. The marker PPSSPP now uses is the same one Dolphin and Flycast already use: a file under `/tmp` that blocks release and a new launch until that boot ends or the marker is cleared after a proved exit. A timeout or an empty process list is not that proof.
