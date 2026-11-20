#!/bin/bash
#
# prune-derived-data.sh — reclaim Xcode DerivedData safely.
#
# Xcode keys each DerivedData directory to the full path of the project or
# workspace file it was built from, so `<Name>-<hash>/info.plist` records that
# path as `WorkspacePath`. When the path no longer exists — a deleted git
# worktree, a moved or renamed checkout — the cache is unreachable garbage that
# Xcode will never reuse or clean up. Those are ORPHANs and are always safe to
# delete.
#
# A hash-named dir (`<Name>-<28 letters>`) with NO info.plist never completed a
# build — an aborted SPM resolve leaves only Logs/ + SourcePackages/. Those are
# ABORTED and treated like orphans. Shared caches (`*.noindex`,
# SDKExplicitPrecompiledModules) also lack a plist but don't match the hash
# pattern, so they are never candidates.
#
# Caches whose source still exists are LIVE. Deleting one only costs a cold
# rebuild, but that cost is real, so LIVE caches are never touched unless you
# explicitly pass --stale. Caches in extra roots that carry no WorkspacePath
# (custom `-derivedDataPath` output) are UNKEYED: stale-eligible only.
#
# DRY RUN BY DEFAULT. Nothing is deleted without --apply.
#
#   prune-derived-data.sh                      # report what would go
#   prune-derived-data.sh --apply              # delete orphans + aborted
#   prune-derived-data.sh --stale 7            # + report LIVE caches idle 7d
#   prune-derived-data.sh --stale 7 --apply    # + delete them
#   prune-derived-data.sh --apply --min-free 200   # no-op unless <200G free
#   prune-derived-data.sh --extra-dd ~/build/dd    # scan another root too
#
# Extra roots: every `~/Library/Caches/*-DD` is scanned automatically (the
# convention for project-local `-derivedDataPath` output). `--no-auto-extra`
# turns that off.
#
set -uo pipefail

DD="${DERIVED_DATA_DIR:-$HOME/Library/Developer/Xcode/DerivedData}"
APPLY=0
STALE_DAYS=0
MIN_FREE_GB=0
MIN_AGE_HOURS=1     # never touch a cache written to this recently (build in flight)
QUIET=0
AUTO_EXTRA=1
declare -a EXTRA_DDS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--apply)          APPLY=1; shift ;;
		--stale)          STALE_DAYS="${2:-0}"; shift 2 ;;
		--min-free)       MIN_FREE_GB="${2:-0}"; shift 2 ;;
		--min-age-hours)  MIN_AGE_HOURS="${2:-1}"; shift 2 ;;
		--dd)             DD="${2:?}"; shift 2 ;;
		--extra-dd)       EXTRA_DDS+=("${2:?}"); shift 2 ;;
		--no-auto-extra)  AUTO_EXTRA=0; shift ;;
		--quiet)          QUIET=1; shift ;;
		-h|--help)        sed -n '2,35p' "$0" | sed 's|^# \{0,1\}||'; exit 0 ;;
		*) echo "unknown flag: $1" >&2; exit 2 ;;
	esac
done

say() { [[ $QUIET -eq 1 ]] && return 0; printf '%s\n' "$*"; }

if [[ $AUTO_EXTRA -eq 1 ]]; then
	for x in "$HOME"/Library/Caches/*-DD; do [[ -d "$x" ]] && EXTRA_DDS+=("$x"); done
fi

declare -a ROOTS=()
[[ -d "$DD" ]] && ROOTS+=("$DD")
for x in ${EXTRA_DDS[@]+"${EXTRA_DDS[@]}"}; do [[ -d "$x" ]] && ROOTS+=("$x"); done
[[ ${#ROOTS[@]} -gt 0 ]] || { say "no DerivedData at $DD — nothing to do"; exit 0; }

# APFS: `df /` reports the read-only system volume and is meaningless. The data
# volume is what actually fills up.
free_gb() {
	local vol=/System/Volumes/Data
	[[ -d $vol ]] || vol=/
	df -g "$vol" 2>/dev/null | awk 'NR==2 {print $4}'
}

FREE_BEFORE=$(free_gb)
for r in "${ROOTS[@]}"; do say "DerivedData: $r"; done
say "Free space:  ${FREE_BEFORE}G"

if [[ "$MIN_FREE_GB" -gt 0 && "${FREE_BEFORE:-0}" -ge "$MIN_FREE_GB" ]]; then
	say "Free space above --min-free ${MIN_FREE_GB}G — nothing to do."
	exit 0
fi

now=$(date +%s)
declare -a TARGETS=() KEPT=()
orphan_kb=0 stale_kb=0 live_kb=0

for root in "${ROOTS[@]}"; do
for dir in "$root"/*/; do
	[[ -d "$dir" ]] || continue
	name=$(basename "$dir")

	src=$(/usr/libexec/PlistBuddy -c "Print :WorkspacePath" "$dir/info.plist" 2>/dev/null)
	size_kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
	size_kb=${size_kb:-0}
	mtime=$(stat -f '%m' "$dir" 2>/dev/null || echo 0)
	age_h=$(( (now - mtime) / 3600 ))
	age_d=$(( age_h / 24 ))

	if [[ -z "$src" || "$src" != /* ]]; then
		# No usable WorkspacePath. Three cases:
		#  - Xcode hash-named dir in the main root → a build that never
		#    completed (ABORTED); nothing reachable, same as an orphan.
		#  - anything else in the main root → shared cache
		#    (ModuleCache.noindex, SymbolCache.noindex, SDKStatCaches.noindex,
		#    CompilationCache.noindex, SDKExplicitPrecompiledModules): keep.
		#    Do NOT infer "no plist means orphan" here.
		#  - dir in an extra root → UNKEYED custom output; stale-eligible only.
		if [[ "$root" == "$DD" && "$name" =~ ^.+-[a-z]{28}$ ]]; then
			if [[ "$age_h" -lt "$MIN_AGE_HOURS" ]]; then
				KEPT+=("$name|ABORTED but written ${age_h}h ago|$size_kb")
				continue
			fi
			TARGETS+=("$root|$name|ABORTED|$size_kb|${age_d}d|(no info.plist — build never completed)")
			orphan_kb=$((orphan_kb + size_kb))
		elif [[ "$root" != "$DD" && "$STALE_DAYS" -gt 0 && "$age_d" -ge "$STALE_DAYS" ]]; then
			TARGETS+=("$root|$name|STALE|$size_kb|${age_d}d|(unkeyed: $root)")
			stale_kb=$((stale_kb + size_kb))
		elif [[ "$root" != "$DD" ]]; then
			KEPT+=("$name|UNKEYED|$size_kb")
			live_kb=$((live_kb + size_kb))
		else
			KEPT+=("$name|shared cache / no WorkspacePath|-")
		fi
		continue
	fi

	if [[ ! -e "$src" ]]; then
		if [[ "$age_h" -lt "$MIN_AGE_HOURS" ]]; then
			KEPT+=("$name|ORPHAN but written ${age_h}h ago|$size_kb")
			continue
		fi
		TARGETS+=("$root|$name|ORPHAN|$size_kb|${age_d}d|$src")
		orphan_kb=$((orphan_kb + size_kb))
	elif [[ "$STALE_DAYS" -gt 0 && "$age_d" -ge "$STALE_DAYS" ]]; then
		TARGETS+=("$root|$name|STALE|$size_kb|${age_d}d|$src")
		stale_kb=$((stale_kb + size_kb))
	else
		KEPT+=("$name|LIVE|$size_kb")
		live_kb=$((live_kb + size_kb))
	fi
done
done

human() { awk -v k="${1:-0}" 'BEGIN{ if (k>=1048576) printf "%.1fG", k/1048576; else printf "%dM", k/1024 }'; }

if [[ ${#TARGETS[@]} -eq 0 ]]; then
	say "Nothing to prune. LIVE caches total $(human $live_kb)."
	exit 0
fi

say ""
say "$([[ $APPLY -eq 1 ]] && echo 'DELETING' || echo 'WOULD DELETE'):"
for t in "${TARGETS[@]}"; do
	IFS='|' read -r root n kind kb age src <<<"$t"
	say "  $(printf '%-7s %-7s %-6s' "$(human "$kb")" "$kind" "$age") $n"
	say "          ← $src"
done

for t in "${TARGETS[@]}"; do
	IFS='|' read -r root n kind kb age src <<<"$t"
	[[ $APPLY -eq 1 ]] || continue
	# Belt and braces: never rm outside a scanned root.
	victim="$root/$n"
	case "$victim" in
		"$root"/?*) rm -rf -- "$victim" || say "  ! failed to remove $n" ;;
		*) say "  ! refusing to remove $victim (outside $root)" ;;
	esac
done

say ""
say "orphans+aborted $(human $orphan_kb) · stale $(human $stale_kb) · keeping LIVE $(human $live_kb)"
if [[ $APPLY -eq 1 ]]; then
	say "Free space: ${FREE_BEFORE}G → $(free_gb)G"
else
	say "Dry run — pass --apply to delete."
fi
