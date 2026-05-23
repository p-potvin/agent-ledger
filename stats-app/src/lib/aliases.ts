// ── Project alias map — canonical name → former names ────────────────────────

export const ALIASES: Record<string, string[]> = {
  'vaultwares-glass':              ['glass-ui'],
  'vaultwares-dispatch':           ['dispatch-wares'],
  'vaultwares-decompile':          ['deconstructed-website-a-la-mode'],
  'vaultwares-media-processing':   ['vault-video-enhancer'],
  'vaultwares-realtime':           ['realtime-stt'],
  'vaultwares-studio':             ['usd-playground'],
  'vaultwares-website':            ['vaultwares-v1'],
  'vaultwares-docs':               ['tmp-app'],
  'vaultwares-identity-manager':   ['vaultwares-auto-signup'],
  'tube-sites':                    ['tube-site'],
  'vaultwares-themes':             ['vault-themes'],
  'vaultwares-adk':                ['vaultwares-agentciation'],
}

/** Resolve aliases for a project — returns array of former names or [] */
export function getAliases(name: string): string[] {
  return ALIASES[name.toLowerCase()] ?? []
}
