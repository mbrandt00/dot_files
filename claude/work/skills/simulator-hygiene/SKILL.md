---
name: simulator-hygiene
description: Keep booted iOS simulators down to a budget while driving the UI for verification, and shut them down when finished. Load before booting a simulator, before any screenshot/UI-driving or XCUITest loop, when several worktrees are in flight, when the Mac gets hot, fans spin up, or builds and tests slow down, and at the end of any session that booted one. Applies in every worktree and every repo — booted-simulator state is machine-wide, not per-checkout.
---

# Simulator hygiene

**Booted simulators are the expensive resource.** Each one is a full OS running
its own SpringBoard, backboardd, and render server — it burns CPU and battery
continuously whether or not you are looking at it. A *shut down* simulator costs
disk only. So the unit to control is **booted count**, and the cheap corrective
is `simctl shutdown`, which is instant and fully reversible.

## The budget: 2 booted

Not a preference — measured. At three booted simulators (alongside a mixed
`Xcode.app` / `Xcode-beta.app` toolchain) `xcodebuild test-without-building`
began exiting 65 with zero tests run and *"the test runner hung before
establishing connection"*, once for 25+ minutes. Two is also exactly what an
iPhone/iPad parity pass needs.

Two booted covers a device and its iPad sibling. A third is almost always a
leftover, not a need.

## Rules

1. **Check before you boot.** `mise run sim:status` (in Bravissimo) or
   `xcrun simctl list devices booted` anywhere else.
2. **Reuse the worktree's own simulator** rather than creating another. One
   named device per worktree is the whole point of the naming scheme — a second
   scratch sim for the same branch is the usual way the count creeps up.
3. **Shut down, don't delete, to reclaim power.** Deleting destroys installed
   app state and granted permissions and costs a reinstall. Reach for deletion
   only when a device is genuinely finished with.
4. **Clean up when done.** Any session that booted a simulator ends with
   `mise run sim:reap` (shut everything down) or `mise run sim:reap --keep <name>`
   (which spares that device *and* its `-ipad` sibling, so a parity pass survives).
   When a feature actually ships, `mise run sim:down` deletes that worktree's device.
5. **Never *automatically* touch a device you did not create, and never delete
   one at all.** A booted simulator with a stock name (`iPhone 17 Pro`) may be
   the documented test device; one with an unfamiliar explicit name is someone's
   deliberate scratch device. Automatic budget enforcement reports those and
   stops. `reap` is the human-invoked exception — it shuts down everything
   booted, which is safe precisely because shutdown is reversible and someone
   asked for it. Deletion is never automatic, in either path.

## In Bravissimo

```bash
mise run sim:status              # booted count vs SIM_BUDGET, plus unmatched devices
mise run sim:reap                # shut everything down
mise run sim:reap --keep main    # …except that one and its -ipad sibling
mise run sim:down [name]         # delete this worktree's device (feature shipped)
SIM_BUDGET=3 mise run sim:up     # raise the ceiling deliberately, for one command
```

`sim:up` and `xcode:open` **enforce the budget themselves**: after booting their
target they shut down their own surplus worktree simulators down to `SIM_BUDGET`,
keeping the target **and its `-ipad` sibling**. Devices they did not create get a warning line and are left
running. So the budget mostly holds without anyone thinking about it — the rules
above are for the cases it can't see.

Implementation is `scripts/ios-sim.sh` (`status`, `reap`, `up`, `open`, `down`),
which owns the worktree→simulator-name derivation. **Do not reimplement that
derivation** — a second copy is exactly what once made every
`~/.herdr/worktrees/Bravissimo/*` worktree collapse onto the sim named `main` and
silently share one device. A worktree branched before these subcommands landed
does not have them; run the canonical checkout's copy
(`~/personal/Bravissimo/scripts/ios-sim.sh`) instead.

## Anywhere else

```bash
xcrun simctl list devices booted                     # what is running
xcrun simctl shutdown <udid|name>                    # reclaim the power
xcrun simctl shutdown all                            # end of session
```

Prefer a throwaway device for a one-off test run — `simctl create` → run →
`simctl delete` — over erasing or churning a device someone else depends on. A
device churned through many install/launch cycles also produces phantom test
failures, so re-run a lone failure on a clean device before calling it a
regression.

## Signals you are over budget

Fans audible, Xcode indexing crawling, `xcodebuild test` hanging before any test
reports, simulator UI dropping frames, or an unexplained `Unable to boot device
in current state`. Check `sim:status` first — it is a two-second answer and it is
the cause more often than the code is.
