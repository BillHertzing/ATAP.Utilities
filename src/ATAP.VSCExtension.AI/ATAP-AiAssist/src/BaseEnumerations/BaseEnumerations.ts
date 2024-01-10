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

export enum QueryEngineNamesEnum {
  // OpenAi's AI
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  // Anthropic's AI
  Claude = 'Claude',
  // Google's AI
  Bard = 'Bard',
  // X's AI
  Grok = 'Grok',
}

export enum QueryEngineFlagsEnum {
  // OpenAi's AI
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 1 << 0,
  // Anthropic's AI
  Claude = 1 << 1,
  // Google's AI
  Bard = 1 << 2,
  // X's AI
  Grok = 1 << 3,
}

// an enumeration to represent the StatusMenuItem choices
export enum StatusMenuItemEnum {
  Mode = 'Mode',
  Command = 'Command',
  QueryEngines = 'QueryEngines',
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
  QueryEnginesMenuItemEnum = 'QueryEnginesMenuItemEnum',
}

export enum SupportedSerializersEnum {
  Yaml = 'YAML',
  Json = 'JSON',
}
