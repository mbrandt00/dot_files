import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import type { Info, Pr } from '../types'

const WT = '/opt/homebrew/bin/wt'
const GH = '/opt/homebrew/bin/gh'
const OPEN_PR_LIMIT = 5
// Same envelope the worktrunk plugin reads, whatever the person's config picks.
const LIST_JSON = ['--config-set', 'list.json-schema=2', 'list', '--format=json']
const VCS_COMMAND = /(^|[\s;&|(])(git|gh|wt)\s/

const info = atom({ plugin: 'worktree-band', key: 'info' } as const, null as Info | null)

const GIT = '/opt/homebrew/bin/git'
const TMUX = '/opt/homebrew/bin/tmux'
const FILE_TOOLS = ['Edit', 'Write', 'NotebookEdit']
const CD = /^\s*cd\s+("[^"]+"|'[^']+'|[^\s;&|]+)/

let timer: Timer | undefined
let running: Promise<void> | undefined
// The worktree this session last worked in: where it edited a file, cd'd a
// command into, or moved its own working directory. Published to the tmux
// pane as @claude_worktree for prefix+v (~/.local/bin/revdiff-popup).
let activeRoot: string | undefined
let lastCwd: string | undefined

type WtItem = {
  branch?: string
  worktree?: { path?: string; main?: boolean; current?: boolean; changes?: Record<string, unknown> }
  upstream?: { ahead?: number }
  default_branch?: { ahead?: number; behind?: number; integration?: { reason?: string } }
}

async function run($: EngineInterface, argv: string[], cwd: string) {
  try {
    const r = await $.process.run(argv, { cwd, timeoutMs: 15_000 })
    return r.exitCode === 0 ? r.stdout : undefined
  } catch {
    return undefined
  }
}

const parentOf = (path: string) => path.slice(0, Math.max(path.lastIndexOf('/'), 1))

function resolvePath(path: string, base: string) {
  const bare = path.replace(/^["']|["']$/g, '')
  return bare.startsWith('/') ? bare : `${base}/${bare}`
}

async function rootOf($: EngineInterface, dir: string) {
  const out = await run($, [GIT, '-C', dir, 'rev-parse', '--show-toplevel'], '/')
  return out?.trim() || undefined
}

async function setActive($: EngineInterface, dir: string) {
  const root = await rootOf($, dir)
  if (root === undefined || root === activeRoot) {
    return
  }
  activeRoot = root
  await run(
    $,
    ['/bin/sh', '-c', '[ -n "$TMUX_PANE" ] && exec "$0" set-option -p -t "$TMUX_PANE" @claude_worktree "$1"', TMUX, root],
    '/',
  )
  later($, 200)
}

async function collect($: EngineInterface): Promise<Info | null> {
  const cwd = activeRoot ?? (await $.session.cwd())
  const listed = await run($, [WT, ...LIST_JSON], cwd)
  if (listed === undefined) {
    return null
  }
  const parsed = JSON.parse(listed) as { repo?: { default_branch?: string }; items?: WtItem[] }
  const item = parsed.items?.find(i => i.worktree?.current === true)
  if (item?.branch === undefined) {
    return null
  }
  const changes = item.worktree?.changes ?? {}
  const isMain = item.worktree?.main === true
  const [prOut, countOut] = await Promise.all([
    isMain ? Promise.resolve(undefined) : run($, [GH, 'pr', 'view', '--json', 'number,state,isDraft'], cwd),
    run($, [GH, 'pr', 'list', '--state', 'open', '--json', 'number', '--jq', 'length'], cwd),
  ])
  const reason = item.default_branch?.integration?.reason
  return {
    branch: item.branch,
    worktree: (item.worktree?.path ?? cwd).split('/').pop() ?? '',
    isMain,
    base: parsed.repo?.default_branch ?? 'main',
    dirty: ['staged', 'modified', 'untracked', 'renamed', 'deleted', 'conflicted'].some(k => changes[k] === true),
    ahead: item.default_branch?.ahead ?? 0,
    behind: item.default_branch?.behind ?? 0,
    unpushed: item.upstream?.ahead ?? 0,
    merged: reason !== undefined && reason !== 'none',
    pr: prOut === undefined ? null : (JSON.parse(prOut) as Pr),
    openPrs: countOut === undefined ? null : Number(countOut.trim()),
  }
}

function refresh($: EngineInterface): Promise<void> {
  running ??= collect($)
    .then(async next => {
      await update($, info, () => next)
    })
    .catch(() => undefined)
    .finally(() => {
      running = undefined
    })
  return running
}

function later($: EngineInterface, ms: number) {
  timer?.cancel()
  timer = $.clock.after(ms, () => void refresh($))
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    lastCwd = await $.session.cwd()
    await setActive($, lastCwd)
    void refresh($)
    return started
  })

  on('tool.call', async ($, e, next) => {
    const ran = await next(e)
    if (ran.deny !== undefined) {
      return ran
    }
    const cwd = await $.session.cwd()
    let dir: string | undefined
    if (cwd !== lastCwd) {
      lastCwd = cwd
      dir = cwd
    }
    if (FILE_TOOLS.includes(e.tool)) {
      const path = (e as { file_path?: string; notebook_path?: string }).file_path ?? (e as { notebook_path?: string }).notebook_path
      dir = path === undefined ? dir : parentOf(path)
    } else if (e.tool === 'Bash') {
      const target = (e as { command?: string }).command?.match(CD)?.[1]
      dir = target === undefined ? dir : resolvePath(target.replace(/^~(?=\/|$)/, cwd.match(/^\/Users\/[^/]+/)?.[0] ?? '~'), cwd)
    }
    if (dir !== undefined) {
      await setActive($, dir)
    }
    return ran
  })

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    if (e.agentId === undefined) {
      later($, 300)
    }
    return done
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const ran = await next(e)
    if (VCS_COMMAND.test(` ${e.command}`)) {
      later($, 1500)
    }
    return ran
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    // Terminal only: the desktop app already shows branch and PR state itself.
    if (e.surface !== 'terminal') {
      return next(e)
    }
    const now = await read($, info)
    if (e.props.hasSurvey || now === null) {
      return next(e)
    }
    const { Box, Text } = $.ui.resolve(e)
    const sep = <Text dimColor> · </Text>
    const crowded = now.openPrs !== null && now.openPrs >= OPEN_PR_LIMIT
    return (
      <Box>
        <Text dimColor>{now.worktree} </Text>
        <Text color="success">⎇ {now.branch}</Text>
        {now.dirty && <Text color="warning"> ●</Text>}
        {!now.isMain && (
          <Text dimColor>
            {' '}
            ↑{now.ahead} ↓{now.behind} vs {now.base}
          </Text>
        )}
        {now.unpushed > 0 && <Text color="warning"> ⇡{now.unpushed} unpushed</Text>}
        {!now.isMain && now.merged && now.pr?.state !== 'OPEN' && <Text color="merged"> merged</Text>}
        {now.pr !== null && (
          <Text>
            {sep}
            <Text color={now.pr.state === 'OPEN' ? 'suggestion' : 'merged'}>
              PR #{now.pr.number} {now.pr.isDraft ? 'draft' : now.pr.state.toLowerCase()}
            </Text>
          </Text>
        )}
        {now.openPrs !== null && (
          <Text>
            {sep}
            <Text color={crowded ? 'warning' : undefined} dimColor={!crowded}>
              {now.openPrs} open PRs{crowded ? ' ⚠ ask before opening another' : ''}
            </Text>
          </Text>
        )}
      </Box>
    )
  })
}
