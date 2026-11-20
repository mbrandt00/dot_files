#!/usr/bin/env python3
"""Classify every worktree, local branch and origin branch of a repo, and
optionally delete the provably-safe ones. Everything deleted is bundled first.

  branch-audit.py [repo]                       # report (default)
  branch-audit.py [repo] --json                # machine-readable report
  branch-audit.py [repo] --apply-auto          # bundle + delete every AUTO ref
  branch-audit.py [repo] --delete REF...       # bundle + delete named refs (triage verdicts)

REF forms: a local branch name, origin/<branch>, or an absolute worktree path.

Classes:
  AUTO       provably safe: content in origin/main, or the tip IS the head of a
             MERGED/CLOSED PR (GitHub keeps refs/pull/N/head forever)
  TRIAGE     clean, idle, not provable: needs the novelty triage (SKILL.md)
  PROTECTED  open PR, uncommitted changes, live process, or active recently
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime

ap = argparse.ArgumentParser()
ap.add_argument("repo", nargs="?", default=os.getcwd())
ap.add_argument("--json", action="store_true")
ap.add_argument("--active-days", type=float, default=3)
ap.add_argument("--apply-auto", action="store_true")
ap.add_argument("--delete", nargs="+", metavar="REF")
ap.add_argument(
    "--archive-dir", default=os.path.expanduser("~/.local/share/branch-archive")
)
args = ap.parse_args()


def run(*cmd, check=True, cwd=None):
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd or REPO)
    if check and r.returncode:
        sys.exit(f"failed: {' '.join(cmd)}\n{r.stderr}")
    return r


REPO = run(
    "git",
    "-C",
    args.repo,
    "rev-parse",
    "--path-format=absolute",
    "--git-common-dir",
    cwd=args.repo,
).stdout.strip()
REPO = os.path.dirname(REPO)
NAME = os.path.basename(REPO)
now = time.time()

run("git", "fetch", "-q", "--prune", "origin")
prs = json.loads(
    run(
        "gh",
        "pr",
        "list",
        "--state",
        "all",
        "--limit",
        "2000",
        "--json",
        "number,state,headRefName,headRefOid",
    ).stdout
)
by_head, by_oid = {}, {}
for p in prs:
    by_head.setdefault(p["headRefName"], []).append(p)
    by_oid.setdefault(p["headRefOid"], p)
open_heads = {p["headRefName"] for p in prs if p["state"] == "OPEN"}

live = set()
lsof = run("lsof", "-d", "cwd", "-Fn", check=False).stdout
for line in lsof.splitlines():
    if line.startswith("n"):
        live.add(line[1:])

wt_items = json.loads(run("wt", "list", "--branches", "--format=json").stdout)["items"]
remote = {}
for line in run(
    "git",
    "for-each-ref",
    "--format=%(refname:lstrip=3)|%(objectname)|%(committerdate:unix)",
    "refs/remotes/origin",
).stdout.split():
    b, sha, ts = line.split("|")
    if b not in ("HEAD", "main"):
        remote[b] = (sha, int(ts))


def in_main(sha):
    return (
        run(
            "git", "merge-base", "--is-ancestor", sha, "origin/main", check=False
        ).returncode
        == 0
    )


def pr_verdict(branch, sha):
    for p in by_head.get(branch, []) + ([by_oid[sha]] if sha in by_oid else []):
        if p["state"] in ("MERGED", "CLOSED") and p["headRefOid"] == sha:
            return f"tip = head of {p['state'].lower()} PR #{p['number']}"
    return None


def latest_pr(branch):
    ps = sorted(by_head.get(branch, []), key=lambda p: -p["number"])
    return f"{ps[0]['state'].lower()} #{ps[0]['number']}" if ps else ""


def worktree_age(path):
    gitdir = run(
        "git", "-C", path, "rev-parse", "--absolute-git-dir", check=False
    ).stdout.strip()
    try:
        return (now - os.stat(gitdir).st_birthtime) / 86400
    except OSError:
        return 0.0


rows = []
for i in wt_items:
    wt = i.get("worktree")
    if wt and wt.get("main"):
        continue
    branch = i.get("branch")
    sha = i["head"]["sha"]
    age = (
        now
        - datetime.fromisoformat(
            i["head"]["committed_at"].replace("Z", "+00:00")
        ).timestamp()
    ) / 86400
    row = {
        "kind": "worktree" if wt else "branch",
        "ref": wt["path"] if wt else branch,
        "branch": branch,
        "sha": sha,
        "age_days": round(age, 1),
        "pr": latest_pr(branch) if branch else "",
        "ahead": i.get("default_branch", {}).get("ahead", 0),
    }
    state = i.get("display", {}).get("state", "")
    dirty = wt and any(
        wt.get("changes", {}).get(k)
        for k in ("staged", "modified", "untracked", "deleted", "renamed")
    )
    is_live = wt and any(
        p == wt["path"] or p.startswith(wt["path"] + "/") for p in live
    )
    if branch in open_heads:
        row.update(cls="PROTECTED", why="open PR")
    elif is_live:
        row.update(cls="PROTECTED", why="live process in worktree")
    elif dirty:
        row.update(cls="PROTECTED", why="uncommitted changes")
    elif wt and (created := worktree_age(wt["path"])) < args.active_days:
        # A fresh worktree sits at main's commit and looks "merged".
        row.update(cls="PROTECTED", why=f"created {created:.1f}d ago")
    elif state in ("integrated", "empty") or in_main(sha):
        row.update(cls="AUTO", why="content in main")
    elif v := pr_verdict(branch, sha):
        row.update(cls="AUTO", why=v)
    elif age < args.active_days:
        row.update(cls="PROTECTED", why=f"active ({age:.1f}d)")
    else:
        row.update(
            cls="TRIAGE",
            why=f"idle {age:.0f}d, {row['ahead']} commits not provably in main",
        )
    rows.append(row)

local_names = {i.get("branch") for i in wt_items if i.get("branch")}
for b, (sha, ts) in remote.items():
    age = (now - ts) / 86400
    row = {
        "kind": "remote",
        "ref": f"origin/{b}",
        "branch": b,
        "sha": sha,
        "age_days": round(age, 1),
        "pr": latest_pr(b),
        "local_copy": b in local_names,
    }
    if b in open_heads:
        row.update(cls="PROTECTED", why="open PR")
    elif in_main(sha):
        row.update(cls="AUTO", why="content in main")
    elif v := pr_verdict(b, sha):
        row.update(cls="AUTO", why=v)
    elif age < args.active_days:
        row.update(cls="PROTECTED", why=f"active ({age:.1f}d)")
    else:
        row.update(cls="TRIAGE", why=f"idle {age:.0f}d, no closed PR at this tip")
    rows.append(row)


def save_uncommitted(wt, stem):
    """Tracked changes as a patch, untracked files as a tarball. wt's backup ref
    skips detached worktrees, so this is the copy that always exists."""
    if not run("git", "-C", wt, "status", "--porcelain", check=False).stdout.strip():
        return
    diff = run("git", "-C", wt, "diff", "HEAD", "--binary", check=False).stdout
    if diff:
        with open(stem + ".patch", "w") as f:
            f.write(diff)
    untracked = run(
        "git", "-C", wt, "ls-files", "--others", "--exclude-standard", "-z", check=False
    ).stdout
    if untracked:
        tar = subprocess.run(
            ["tar", "-czf", stem + "-untracked.tgz", "--null", "-T", "-"],
            input=untracked,
            text=True,
            cwd=wt,
            capture_output=True,
        )
        if tar.returncode:
            sys.exit(
                f"could not save untracked files of {wt}, nothing deleted:\n{tar.stderr}"
            )


def bundle(targets):
    """Name every target under refs/archive/ and bundle them. Returns the path."""
    os.makedirs(os.path.join(args.archive_dir, NAME), exist_ok=True)
    path = os.path.join(
        args.archive_dir, NAME, datetime.now().strftime("%Y-%m-%d-%H%M%S") + ".bundle"
    )
    names = []
    for r in targets:
        safe = r["ref"].replace(os.path.expanduser("~") + "/", "").replace("/", "__")
        name = f"refs/archive/{r['kind']}/{safe}"
        run("git", "update-ref", name, r["sha"])
        names.append(name)
        if r["kind"] == "worktree":
            save_uncommitted(r["ref"], path[: -len(".bundle")] + "-" + safe)
    res = run("git", "bundle", "create", path, *names, "^origin/main", check=False)
    for n in names:
        run("git", "update-ref", "-d", n)
    if res.returncode and "empty bundle" not in res.stderr:
        sys.exit(f"bundle failed, nothing deleted:\n{res.stderr}")
    if res.returncode:
        return "(all targets already in origin/main; no bundle needed)"
    run("git", "bundle", "verify", "-q", path)
    with open(path + ".txt", "w") as f:
        for r in targets:
            f.write(f"{r['kind']}\t{r['ref']}\t{r['sha']}\t{r.get('why', '')}\n")
    return path


def delete(targets):
    if not targets:
        print("nothing to delete")
        return
    print(f"backup: {bundle(targets)}")
    remotes = [r["branch"] for r in targets if r["kind"] == "remote"]
    for r in targets:
        if r["kind"] == "worktree":
            flags = ["-f"] if r.get("cls") != "AUTO" else []
            res = run(
                "wt",
                "remove",
                "--foreground",
                "-D",
                "-y",
                *flags,
                r["ref"],
                check=False,
            )
            print(
                ("ok   " if res.returncode == 0 else "FAIL ") + r["ref"],
                res.stderr.strip().splitlines()[-1:] if res.returncode else "",
            )
        elif r["kind"] == "branch":
            res = run("git", "branch", "-D", r["branch"], check=False)
            print(("ok   " if res.returncode == 0 else "FAIL ") + r["branch"])
    if remotes:
        res = run("git", "push", "origin", "--delete", *remotes, check=False)
        print(
            f"{'ok  ' if res.returncode == 0 else 'FAIL'} origin: {len(remotes)} branches"
        )
        if res.returncode:
            print(res.stderr)


if args.apply_auto:
    delete([r for r in rows if r["cls"] == "AUTO"])
elif args.delete:
    want = set(args.delete)
    found = [
        r
        for r in rows
        if r["ref"] in want or (r["kind"] != "remote" and r["branch"] in want)
    ]
    blocked = [r for r in found if r["why"] in ("open PR", "live process in worktree")]
    if blocked:
        sys.exit("refusing: " + ", ".join(f"{r['ref']} ({r['why']})" for r in blocked))
    missing = want - {r["ref"] for r in found} - {r["branch"] for r in found}
    if missing:
        sys.exit("unknown refs: " + ", ".join(sorted(missing)))
    delete(found)
elif args.json:
    json.dump(rows, sys.stdout, indent=1)
else:
    order = {"AUTO": 0, "TRIAGE": 1, "PROTECTED": 2}
    for r in sorted(rows, key=lambda r: (order[r["cls"]], r["kind"], -r["age_days"])):
        ref = r["ref"].replace(os.path.expanduser("~"), "~")
        print(
            f"{r['cls']:9} {r['kind']:8} {r['age_days']:>5}d {r['pr']:12} {ref[:60]:60} {r['why']}"
        )
    counts = {c: sum(r["cls"] == c for r in rows) for c in order}
    print("\n" + "  ".join(f"{c}={n}" for c, n in counts.items()))
