import type { Register } from 'claude-code'

/**
 * Asks the person before any write to PROD. Dev is a staging ground for
 * destructive work (recoverable with `pnpm db:restore --dev`), so it passes.
 * A plugin's ask goes to the person; no rule, auto-mode classifier or
 * headless host can settle it.
 */

const PROD_REF = 'qtsxycqlcwnrodayjjlc'
const PROD_FLAG = /(^|\s)--prod(?=[\s=]|$)|--env[= ]prod\b/
const PROD_TEXT = new RegExp(`${PROD_REF}|(^|[\\s$_{])PROD_|(^|\\s)--prod\\b`, 'i')
const WRITE_SWITCH = /(^|\s)--(enqueue|apply|write[\w-]*|delete|fix|execute|force)\b/
const DRY_RUN = /(^|\s)--dry-run\b/

// Tasks that only read prod unless a write switch is added.
const READ_ONLY_TASKS = [
  'db:backup',
  'db:catalog-audit',
  'onboarding:verify-starters',
  'users:funnel',
  'search:doctor',
  'bar-detection:jobs',
  'bar-detection:snapshot-batch',
  'bar-detection:llm-spend',
  'bar-detection:clef-playthrough',
  'bar-detection:queue-stale',
  'session-jobs',
]

const SQL_WRITE = /\b(insert|update|delete|merge|upsert|alter|drop|create|truncate|grant|revoke|comment\s+on|vacuum|reindex|refresh|call|do|copy)\b/i

function readOnlySql(sql: string): boolean {
  const s = sql.trim().replace(/^["']|["']$/g, '')
  return /^(select|with|explain|show|\\d)/i.test(s) && !SQL_WRITE.test(s) && !/\bselect\s+(?!(count|sum|min|max|avg|coalesce|now|lower|upper|length|date_trunc|array_agg|string_agg|jsonb?_\w+|to_char|distinct)\s*\()[\w.]+\s*\(/i.test(s)
}

function segmentWrite(seg: string): string | undefined {
  if (/\bhatchet\s+(worker|trigger|run|replay|cancel|rerun|bulk)\b/.test(seg)) {
    const profile = seg.match(/(?:-p|--profile)[\s=]+(\S+)/)?.[1] ?? seg.match(/HATCHET_PROFILE=(\S+)/)?.[1]
    return profile === 'prod' ? 'a Hatchet prod run or worker' : undefined
  }
  if (/\bsupabase\s/.test(seg) && seg.includes(PROD_REF)) {
    return 'a Supabase CLI command against the prod project'
  }
  if (/(^|\s)psql\b/.test(seg) && PROD_TEXT.test(seg)) {
    const sql = seg.match(/(?:-c|--command)[\s=]+("[^"]*"|'[^']*'|\S+)/)?.[1]
    return sql !== undefined && readOnlySql(sql) ? undefined : 'psql against prod'
  }
  if (PROD_FLAG.test(seg)) {
    const readOnly = READ_ONLY_TASKS.some(t => new RegExp(`(^|\\s)${t}(\\s|$)`).test(seg))
    return DRY_RUN.test(seg) || (readOnly && !WRITE_SWITCH.test(seg)) ? undefined : 'a --prod run that may write'
  }
  return undefined
}

export function remoteWrite(command: string): string | undefined {
  for (const seg of command.split(/\|\||&&|[;|\n]|\$\(|`/)) {
    const why = segmentWrite(seg.trim())
    if (why !== undefined) {
      return why
    }
  }
  return undefined
}

const SUPABASE_MCP = /^mcp__(claude_ai_)?[Ss]upabase__(\w+)$/
const SUPABASE_MCP_WRITE =
  /^(apply_migration|deploy_edge_function|create_edge_function_secret|pause_project|restore_project|(create|delete|merge|reset|rebase)_branch|run_notebook)$/

function mcpWrite(tool: string, input: unknown): string | undefined {
  const name = tool.match(SUPABASE_MCP)?.[2]
  if (name === undefined || !JSON.stringify(input ?? {}).includes(PROD_REF)) {
    return undefined
  }
  if (SUPABASE_MCP_WRITE.test(name)) {
    return 'a Supabase MCP change to prod'
  }
  if (name === 'execute_sql' && !readOnlySql((input as { query?: string }).query ?? '')) {
    return 'Supabase MCP SQL on prod that may write'
  }
  return undefined
}

export const register: Register = on => {
  on('tool.check', async ($, e, next) => {
    const why =
      e.tool === 'Bash'
        ? remoteWrite((e.input as { command?: string }).command ?? '')
        : e.tool.startsWith('mcp__')
          ? mcpWrite(e.tool, e.input)
          : undefined
    if (why === undefined) {
      return next(e)
    }
    const beneath = await next(e)
    if (beneath.decision === 'deny') {
      return beneath
    }
    return { decision: 'ask', reason: `${$.plugin.name}: ${why}. Prod writes need your OK every time.` }
  }).catch(() => ({ decision: 'ask', reason: 'env-write-guard failed; asking to be safe.' }))
}
