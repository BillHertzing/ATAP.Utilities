export function isRunningInDevHost(): boolean {
  return process.env.VSCODE_DEV === '1';
}
