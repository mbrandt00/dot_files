import { expect, test } from 'claude-code/testing'

const PROD = 'qtsxycqlcwnrodayjjlc'
const ASK = [
  'mise run db:migrate --prod',
  'mise run secrets:sync --prod',
  'mise run bar-detection:queue-stale --prod --enqueue --limit 5',
  'cd x && mise run search:reindex --env=prod',
  'pnpm db:migrate --prod',
  'uv run python scripts/x.py --prod',
  'hatchet trigger -p prod my-wf',
  'HATCHET_PROFILE=prod hatchet worker dev',
  `supabase db push --project-ref ${PROD}`,
  `supabase link --project-ref ${PROD}`,
  'psql "$PROD_DATABASE_URL" -c "update pieces set x=1"',
  `psql "postgresql://postgres@db.${PROD}.supabase.co/postgres" -f fix.sql`,
]
const PASS = [
  'mise run db:migrate --dev',
  'mise run db:restore --dev',
  'pnpm db:restore --dev',
  'mise run db:migrate --prod --dry-run',
  'mise run bar-detection:jobs --prod --watch',
  'mise run users:funnel --prod',
  'hatchet worker dev',
  'hatchet trigger -p dev my-wf',
  'supabase db push',
  'psql "$DEV_DATABASE_URL" -c "delete from x"',
  'psql "$PROD_RO_URL" -c "select count(*) from pieces"',
  'uv sync --dev',
  'git log --oneline',
]

for (const command of ASK) {
  test(`asks: ${command}`, async ($, on) => {
    on('tool.check', () => ({ decision: 'allow' }))
    expect((await $.tool.check({ tool: 'Bash', input: { command } })).decision).toBe('ask')
  })
}
for (const command of PASS) {
  test(`passes: ${command}`, async ($, on) => {
    on('tool.check', () => ({ decision: 'allow' }))
    expect((await $.tool.check({ tool: 'Bash', input: { command } })).decision).toBe('allow')
  })
}
test('Supabase MCP: prod write asks, dev write and prod select pass', async ($, on) => {
  on('tool.check', () => ({ decision: 'allow' }))
  const check = (tool: string, input: object) => $.tool.check({ tool, input }).then(r => r.decision)
  expect(await check('mcp__claude_ai_Supabase__apply_migration', { project_id: PROD })).toBe('ask')
  expect(await check('mcp__claude_ai_Supabase__execute_sql', { project_id: PROD, query: 'delete from x' })).toBe('ask')
  expect(await check('mcp__claude_ai_Supabase__execute_sql', { project_id: PROD, query: 'select 1' })).toBe('allow')
  expect(await check('mcp__claude_ai_Supabase__apply_migration', { project_id: 'htfmcjovvkvdadnrxyfn' })).toBe('allow')
})
