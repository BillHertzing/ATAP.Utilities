// an enumeration to represent the SupportedQueryEngines choices
export enum SupportedQueryEnginesEnum {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  // Anthropic
  Claude = 'Claude',
  // Bard
  Bard = 'Bard',
  // Grok
  Grok = 'Grok',
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

// an enumeration to represent the VCSCommandMenuItem choices
export enum VCSCommandMenuItemEnum {
  SelectMode = 'SelectMode',
  SelectQueryAgentCommand = 'SelectQueryAgentCommand',
  SelectQueryEngines = 'SelectQueryEngines',
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

// an enumeration to represent the QueryAgentCommandItem choices
export enum QueryAgentCommandMenuItemEnum {
  Chat = 'Chat',
  Fix = 'Fix',
  Test = 'Test',
  Document = 'Document',
}

// an enumeration of the kinds of enumerations that can be quickpicked
export enum QuickPickEnumeration {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  VCSCommandMenuItemEnum = 'VCSCommandMenuItemEnum',
  ModeMenuItemEnum = 'ModeMenuItemEnum',
  QueryAgentCommandMenuItemEnum = 'QueryAgentCommandMenuItemEnum',
  QueryEnginesMenuItemEnum = 'QueryEnginesMenuItemEnum',
}

export enum SupportedSerializersEnum {
  Yaml = 'YAML',
  Json = 'JSON',
}
