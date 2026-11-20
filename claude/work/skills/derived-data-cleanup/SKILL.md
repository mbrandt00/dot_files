---
name: derived-data-cleanup
description: Reclaim disk space from Xcode DerivedData and its multipliers. Use when the Mac is low on disk, when a build fails with "no space left on device", after removing a git worktree, or when asked to audit/clean DerivedData, Xcode caches, simulators, or build artifacts. Covers why DerivedData multiplies across worktrees, the worktree audit that finds the root cause (merged-PR worktrees still on disk), custom -derivedDataPath roots the default scan misses, and how the unattended launchd sweep is configured.
---

# DerivedData cleanup

## The mechanism (this is what makes the multiplication predictable)

Xcode keys each DerivedData directory to the **full filesystem path of the project or workspace file** it was built from, and records that path in `<Name>-<hash>/info.plist` → `WorkspacePath`.

Consequences:

- **Every git worktree gets its own cache**, because each has a different path. A worktree whose PR merged weeks ago still holds 4–8G.
- **Opening the workspace in Xcode and building the project from the CLI produce two separate caches**, because `Foo.xcworkspace` and `Foo.xcodeproj` are different paths. Verified on Bravissimo 2026-08-08: canonical held 9.4G (`.xcworkspace`) *plus* 5.2G (`.xcodeproj`).
- **Xcode never reclaims a cache whose source path is gone.** Deleting a worktree leaves 4–10G of permanently unreachable garbage.
- **Scripts that pass `-derivedDataPath` write somewhere else entirely.** On this machine the convention is `~/Library/Caches/<Project>-DD/<worktree>-{sim,device,sdk26,release}` — 18G sat there invisible to a scan of the default root (2026-09-11).
- **An aborted build leaves a hash-named dir with no `info.plist`** (only `Logs/` + `SourcePackages/`, ~3G each from the SPM checkout). Xcode never revisits it.

Classification the script uses:

| Class | Test | Deleted by |
|---|---|---|
| ORPHAN | `WorkspacePath` no longer exists | default |
| ABORTED | name matches `<Name>-<28 letters>`, no `info.plist`, in the default root | default |
| STALE | source exists, idle ≥ `--stale N` days | `--stale N` only |
| UNKEYED | in an extra root, no `WorkspacePath` | `--stale N` only |
| LIVE / shared | everything else (`*.noindex`, `SDKExplicitPrecompiledModules`) | never |

## Running it — in this order

**1. Find the root cause first: which worktrees are done?**

Load the `worktree-cleanup` skill and run it. It auto-removes provably merged or superseded worktrees and branches, after bundling them, and triages the rest. Once worktrees are gone, their caches become ORPHANs and step 2 reclaims them.

**2. Prune caches.** `prune-derived-data.sh` is **dry-run by default**.

```bash
S=~/.claude/skills/derived-data-cleanup/prune-derived-data.sh

"$S"                          # report: orphans + aborted, sizes, source paths
"$S" --apply                  # delete them
"$S" --stale 7                # also report LIVE/UNKEYED caches idle ≥7 days
"$S" --stale 7 --apply        # …and delete those too
"$S" --apply --min-free 200   # no-op unless the data volume is under 200G free
"$S" --extra-dd /path/dd      # another -derivedDataPath root (~/Library/Caches/*-DD is automatic)
```

Always show the dry run before applying anything that includes `--stale`. Orphans and aborted dirs need no discussion; stale LIVE caches do, because only the user knows whether they are about to return to that worktree. **`--stale 7` is the right starting point here, not 21** — on 2026-09-11 `--stale 21` found nothing while `--stale 3` found 68G; the worktree cadence is days, not weeks.

**3. The other offenders — run these, don't just mention them.**

```bash
du -sh ~/Library/Developer/Xcode/{DerivedData,iOS\ DeviceSupport,Archives} 2>/dev/null
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport/* | sort -rh      # keep only the connected phone's build; the rest regenerate on reconnect
for d in ~/Library/Developer/CoreSimulator/Devices/*/; do printf '%s MB  %s  %s\n' "$(du -sm "$d"|cut -f1)" "$(/usr/libexec/PlistBuddy -c 'Print :name' "$d/device.plist")" "$(basename "$d")"; done | sort -rn
xcrun simctl delete unavailable
du -sh ~/Library/Caches/* 2>/dev/null | sort -rh | head -12
```

Sims named after a worktree that worktree-cleanup removed are dead too: `xcrun simctl shutdown <udid>; xcrun simctl delete <udid>` (keep the shared `main` / `main-26` sims — see the `xcode-open` skill). Regenerable caches Claude can delete without asking: `com.spotify.client` (22G on 2026-09-11), `com.github.peripheryapp` (4.5G), `~/.npm` (`npm cache clean --force`, 9G), `org.swift.swiftpm`. DeviceSupport for a beta build the phone no longer runs (6.5G). Not Claude's call: `~/work`, Steam, Downloads, `Application Support/Claude`.

## Safety rules the script enforces — preserve these if you edit it

1. **A dir with no readable absolute `WorkspacePath` is only a candidate when its name matches Xcode's `<Name>-<28 letters>` hash pattern in the default root.** `ModuleCache.noindex`, `SymbolCache.noindex`, `SDKStatCaches.noindex`, `CompilationCache.noindex`, and `SDKExplicitPrecompiledModules` are *shared* caches with no `info.plist`; naive logic reads "no WorkspacePath" as "orphan" and deletes them. The name pattern is what separates an aborted project build from a shared cache.
2. **`--min-age-hours` (default 1) skips caches written to very recently**, so a sweep can't delete a cache out from under a build in flight. Applies to ABORTED too.
3. **Free space is read from `/System/Volumes/Data`, not `/`.** On APFS the root volume is read-only and reports nonsense — `df -h /` said "9% used" while the data volume was 85% full.
4. **`rm -rf` is path-guarded** to the root each target was found in.
5. **Extra roots are never orphan-classified.** A custom `-derivedDataPath` dir with no plist can't be traced to a source, so it is UNKEYED and only goes with `--stale`.
6. macOS ships bash 3.2: an empty array under `set -u` must be expanded as `${ARR[@]+"${ARR[@]}"}`.

## Unattended sweep (launchd)

`~/Library/LaunchAgents/com.michaelbrandt.derived-data-prune.plist` runs the **orphan + aborted sweep only**, weekly, logging to `~/Library/Logs/derived-data-prune.log`.

```bash
launchctl list | grep derived-data              # is it loaded?
tail -20 ~/Library/Logs/derived-data-prune.log  # what did it reclaim?
launchctl kickstart -k gui/$UID/com.michaelbrandt.derived-data-prune   # run now
launchctl bootout gui/$UID ~/Library/LaunchAgents/com.michaelbrandt.derived-data-prune.plist  # disable
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.michaelbrandt.derived-data-prune.plist # re-enable
```

**The cron never prunes LIVE caches, however stale.** Unattended deletion of a cache you're about to use turns a background chore into a surprise 10-minute rebuild. Staleness is a judgement call, so it stays manual — that is the division of labour between the launchd job and this skill. It also can't remove worktrees, so the cron only ever treats symptoms; the audit in step 1 is what stops the growth.

Claude-app routines cannot do this job: they run as cloud agents with no access to the local filesystem. `CronCreate` is also wrong — session-only, in memory, gone when Claude exits, 7-day expiry. launchd is the only durable local mechanism.

## The structural fix, if the user wants to go further

Standardising CLI builds on `-workspace` (instead of `-project`) would collapse each duplicate pair into one cache and roughly halve the steady-state footprint. In Bravissimo that means `ios/CLAUDE.md`, `scripts/ios-sim.sh`, `scripts/practice-surface-validate.sh`, and `docs/session-notes-redesign.md`. Not free: workspace and project builds can resolve SPM dependencies differently, so it needs a verification pass, and every existing `-project` cache is orphaned the moment it changes (one large one-off reclaim). Propose it; don't do it unasked.
