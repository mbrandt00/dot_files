export type Pr = { number: number; state: string; isDraft: boolean }

export type Info = {
  branch: string
  worktree: string
  isMain: boolean
  base: string
  dirty: boolean
  ahead: number
  behind: number
  unpushed: number
  merged: boolean
  pr: Pr | null
  openPrs: number | null
}

declare module 'claude-code' {
  interface PluginState {
    'worktree-band': { info: Info | null }
  }
}
