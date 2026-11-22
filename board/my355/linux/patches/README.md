# Kernel patches for my355. Order in BR2_GLOBAL_PATCH_DIR is load-bearing.
# After copying new patches, run scripts/refresh-kernel-patches.sh so they
# apply with Buildroot's -F0.
#
# 0001 adds opp-1992000000 with turbo-mode at 1.15 V. Normal profiles leave
# boost off and cap at 1.8 GHz. The three CPU undervolt overlays name that
# OPP, so removing the patch breaks them.
#
# 0003 is ROCKNIX 001. It raises the NVRAM SoC ceiling from 10000 to 100000.
# On the observed boot paths that saved value is then replaced, so the patch
# does not change the overnight OCV reseed. 002, 005, and 008 are not in this
# directory. The reason is in docs/OPERATIONS.md.
#
# The applied-patch assessment for Linux 7.2.10 is
# docs/research/phase-12d-linux-7.2.10-preflight.md.
