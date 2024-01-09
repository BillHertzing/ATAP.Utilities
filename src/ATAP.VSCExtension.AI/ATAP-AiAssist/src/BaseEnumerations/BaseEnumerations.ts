// an enumeration to represent the SupportedQueryEngines choices
export enum SupportedQueryEnginesEnum {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  // Anthropic
  // Claude = 'Claude',
  // Bard
  //  Bard = 'Bard',
  // Grok
  // Grok = 'Grok',
}

// an enumeration to represent the StatusMenuItem choices
export enum StatusMenuItemEnum {
  Mode = 'Mode',
  Command = 'Command',
  Sources = 'Sources',
  ShowLogs = 'ShowLogs',
}

// an enumeration to represent the ModeItem choices
export enum ModeMenuItemEnum {
  Workspace = 'Workspace',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  VSCode = 'VSCode',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  Claude = 'Claude',
}

// an enumeration to represent the CommandItem choices
export enum CommandMenuItemEnum {
  Chat = 'Chat',
  Fix = 'Fix',
  Test = 'Test',
  Document = 'Document',
}

// an enumeration of the kinds of enumerations that can be quickpicked
export enum QuickPickEnumeration {
  StatusMenuItemEnum = 'StatusMenuItemEnum',
  ModeMenuItemEnum = 'ModeMenuItemEnum',
  CommandMenuItemEnum = 'CommandMenuItemEnum',
}

export enum SupportedSerializersEnum {
  Yaml = 'YAML',
  Json = 'JSON',
}
