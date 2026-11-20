import type { EngineInterface, Register } from 'claude-code'

/**
 * Polls the shared xcodebuild lane (pueue group "xcode", scripts/xq.sh) and
 * toasts when it frees up, and when a job this session queued starts or ends.
 */

const PUEUE = '/opt/homebrew/bin/pueue'
const POLL_MS = 15_000

type Task = {
  id: number
  group?: string
  label?: string | null
  command?: string
  status: string | Record<string, { result?: unknown }>
  envs?: Record<string, string>
}

const kind = (t: Task) => (typeof t.status === 'string' ? t.status : (Object.keys(t.status)[0] ?? ''))
const name = (t: Task) => (t.label ?? t.command ?? `#${t.id}`).slice(0, 50)
const succeeded = (t: Task) =>
  typeof t.status === 'object' && t.status.Done?.result === 'Success'

let wasBusy: boolean | undefined
let mine = new Map<number, string>()

async function poll($: EngineInterface, sid: string) {
  let tasks: Task[]
  try {
    const r = await $.process.run([PUEUE, 'status', '--json'], { timeoutMs: 5_000 })
    if (r.exitCode !== 0) {
      return
    }
    tasks = Object.values((JSON.parse(r.stdout) as { tasks: Record<string, Task> }).tasks)
  } catch {
    return
  }

  const lane = tasks.filter(t => t.group === 'xcode')
  const busy = lane.some(t => kind(t) === 'Running' || kind(t) === 'Queued')
  const ownNow = new Map(
    tasks.filter(t => t.envs?.CLAUDE_CODE_SESSION_ID === sid).map(t => [t.id, kind(t)] as const),
  )

  let toasted = false
  for (const [id, before] of mine) {
    const task = tasks.find(t => t.id === id)
    const after = ownNow.get(id)
    if (task !== undefined && before === 'Queued' && after === 'Running') {
      $.ui.toast(`Your xcodebuild job started: ${name(task)}`)
      toasted = true
    } else if (task !== undefined && before !== 'Done' && after === 'Done') {
      $.ui.toast(`Your xcodebuild job ${succeeded(task) ? 'finished' : 'FAILED'}: ${name(task)}`)
      toasted = true
    }
  }
  if (wasBusy === true && !busy && !toasted) {
    $.ui.toast('Xcode lane is free')
  }

  wasBusy = busy
  mine = new Map([...ownNow].filter(([, k]) => k !== 'Done'))
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    const sid = await $.session.id()
    void poll($, sid)
    $.clock.every(POLL_MS, () => void poll($, sid))
    return started
  })
}
