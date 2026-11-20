import type { Register } from 'claude-code'

/**
 * Keeps the gitignored secret env files (.env.secrets, .env.local) out of
 * the transcript. A seatbelt for agent mistakes, not a sandbox: a script the
 * model writes can still read them.
 */

// A path that ends in one of the files, or a glob that could expand to one.
const SECRET_PATH = /(^|\/)\.env\.(secrets|local)$/
const SECRET_TEXT = /\.env\.(secrets|local)\b|\.env\.?[A-Za-z]*[*?[]/

// Shell segments that touch the files without printing what they hold.
const SAFE_SEGMENT = [
  /^(ls|stat|test|\[\[?|file|readlink|realpath|chmod|ln|wc\s+-[lc])(\s|$)/,
  /^git\s+(check-ignore|ls-files|status)(\s|$)/,
  /^cut\s+(?:-d\s*(['"]?)=\1\s+-f\s*1|-f\s*1\s+-d\s*(['"]?)=\2)(\s|$)/,
  /^grep\s+(?:-[A-Za-z]*\s+)*-[A-Za-z]*[qc][A-Za-z]*(\s|$)/,
]

const ENV_PREFIX = /^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*/

const HOW =
  'Inspect key names only, e.g. `cut -d= -f1 .env.secrets`; scripts read the file through readSecret / secret_read.'

function unsafeSegment(command: string): string | undefined {
  return command
    .split(/\|\||&&|[;|\n&]|\$\(|`/)
    .map(part => part.trim().replace(ENV_PREFIX, ''))
    .find(part => SECRET_TEXT.test(part) && !SAFE_SEGMENT.some(rx => rx.test(part)))
}

function pathsIn(value: unknown, out: string[] = []): string[] {
  if (typeof value === 'string') {
    out.push(value)
  } else if (Array.isArray(value)) {
    value.forEach(v => pathsIn(v, out))
  } else if (value !== null && typeof value === 'object') {
    Object.values(value).forEach(v => pathsIn(v, out))
  }
  return out
}

export const register: Register = on => {
  on('tool.call', { tool: 'Bash' }, ($, e, next) => {
    const bad = unsafeSegment(e.command)
    return bad === undefined
      ? next(e)
      : { deny: `${$.plugin.name}: \`${bad.slice(0, 80)}\` would expose a secret env file. ${HOW}` }
  }).catch(($, e, next) =>
    next.called ? next(e) : { deny: `${$.plugin.name}: its guard failed, so the call is refused.` },
  )

  on('tool.call', ($, e, next) => {
    if (e.tool === 'Bash') {
      return next(e)
    }
    const strings = pathsIn(e)
    const hit = e.tool.startsWith('mcp__')
      ? strings.find(s => SECRET_PATH.test(s.trim()) || (s.includes(' ') && unsafeSegment(s) !== undefined))
      : ['Read', 'Edit', 'Write', 'NotebookEdit'].includes(e.tool)
        ? strings.find(s => SECRET_PATH.test(s))
        : undefined
    return hit === undefined
      ? next(e)
      : { deny: `${$.plugin.name}: ${e.tool} on a secret env file is refused. ${HOW}` }
  }).catch(($, e, next) =>
    next.called ? next(e) : { deny: `${$.plugin.name}: its guard failed, so the call is refused.` },
  )
}
