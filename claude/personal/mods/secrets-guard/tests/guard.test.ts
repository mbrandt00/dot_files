import { expect, test } from 'claude-code/testing'

const DENIED = [
  'cat .env.secrets',
  'grep SUPABASE ~/personal/Bravissimo/.env.secrets',
  'head -5 .env.local',
  'cat .env.*',
  'source .env.secrets && echo $SECRET_X',
  'while read l; do echo $l; done < .env.secrets',
  'echo $(cat supabase/functions/audio-job-webhook/.env.local)',
  'cut -d= -f2 .env.secrets',
  'FOO=1 sed -n 1p .env.secrets',
]
const ALLOWED = [
  'cut -d= -f1 .env.secrets',
  "cut -d '=' -f1 .env.secrets | sort",
  'ls -la .env.secrets',
  'test -f .env.secrets && echo present',
  'git check-ignore -q .env.secrets',
  "grep -q '^SECRET_A=' .env.secrets",
  'mise run secrets:doctor',
  'git status',
]

for (const command of DENIED) {
  test(`denies: ${command}`, async ($, on) => {
    on('tool.call', () => ({ result: 'ran' }) as never)
    const r = await $.tool.call({ tool: 'Bash', command })
    expect(r.deny ?? (r as { text?: string }).text ?? '').toContain('secret env file')
  })
}

for (const command of ALLOWED) {
  test(`allows: ${command}`, async ($, on) => {
    let ran = false
    on('tool.call', () => {
      ran = true
      return { result: 'ran' } as never
    })
    await $.tool.call({ tool: 'Bash', command })
    expect(ran).toBe(true)
  })
}

test('denies Read of the file, allows Write of a doc that names it', async ($, on) => {
  let ran = 0
  on('tool.call', () => {
    ran += 1
    return { result: 'ran' } as never
  })
  await $.tool.call({ tool: 'Read', file_path: '/Users/x/personal/Bravissimo/.env.secrets' })
  expect(ran).toBe(0)
  await $.tool.call({ tool: 'Write', file_path: '/tmp/notes.md', content: 'never cat .env.secrets' })
  expect(ran).toBe(1)
})
