/*
export enum ModeMenuItemEnum {
  Workspace = 'Workspace',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  VSCode = 'VSCode',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  Claude = 'Claude',
}
export enum QueryAgentCommandMenuItemEnum {
  Chat = 'Chat',
  Fix = 'Fix',
  Test = 'Test',
  Document = 'Document',
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

export enum QuickPickEnumeration {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  VCSCommandMenuItemEnum = 'VCSCommandMenuItemEnum',
  ModeMenuItemEnum = 'ModeMenuItemEnum',
  QueryAgentCommandMenuItemEnum = 'QueryAgentCommandMenuItemEnum',
  QueryEnginesMenuItemEnum = 'QueryEnginesMenuItemEnum',
}
export interface IQuickPickTypeMapping {
  [QuickPickEnumeration.ModeMenuItemEnum]: ModeMenuItemEnum;
  [QuickPickEnumeration.QueryEnginesMenuItemEnum]: QueryEngineFlagsEnum;
  [QuickPickEnumeration.QueryAgentCommandMenuItemEnum]: QueryAgentCommandMenuItemEnum;
  //[QuickPickEnumeration.VCSCommandMenuItemEnum]: string;
}
export type QuickPickMappingKeysT = keyof IQuickPickTypeMapping;

export type QuickPickValueT =
  | [QuickPickEnumeration.ModeMenuItemEnum, ModeMenuItemEnum]
  | [QuickPickEnumeration.QueryEnginesMenuItemEnum, QueryEngineFlagsEnum]
  | [QuickPickEnumeration.QueryAgentCommandMenuItemEnum, QueryAgentCommandMenuItemEnum];

function createQuickPickValue<K extends QuickPickMappingKeysT>(
  type: K,
  value: IQuickPickTypeMapping[K],
): QuickPickValueT {
  return [type, value] as QuickPickValueT;
}

let _quickPickValue: QuickPickValueT;
_quickPickValue = createQuickPickValue(QuickPickEnumeration.ModeMenuItemEnum, ModeMenuItemEnum.ChatGPT);
console.log(`${_quickPickValue[0]}: ${_quickPickValue[1]}`);

_quickPickValue = createQuickPickValue(QuickPickEnumeration.QueryEnginesMenuItemEnum, QueryEngineFlagsEnum.Grok);
console.log(`${_quickPickValue[0]}: ${_quickPickValue[1]}`);

const _currentQueryEngines: QueryEngineFlagsEnum = QueryEngineFlagsEnum.Grok;
let _newQueryEngines: QueryEngineFlagsEnum;
_newQueryEngines = _currentQueryEngines ^ QueryEngineFlagsEnum.ChatGPT;
_quickPickValue = createQuickPickValue(QuickPickEnumeration.QueryEnginesMenuItemEnum, _newQueryEngines);
console.log(`${_quickPickValue[0]}: ${_quickPickValue[1]}`);

let pickLabel: string = 'workspace';
let _quickPickKindOfEnumeration: QuickPickEnumeration = QuickPickEnumeration.ModeMenuItemEnum;
_quickPickValue = createQuickPickValue(_quickPickKindOfEnumeration, pickLabel as ModeMenuItemEnum);
console.log(`${_quickPickValue[0]}: ${_quickPickValue[1]}`);

pickLabel = 'fix';
_quickPickKindOfEnumeration = QuickPickEnumeration.QueryAgentCommandMenuItemEnum;
_quickPickValue = createQuickPickValue(_quickPickKindOfEnumeration, pickLabel as QueryAgentCommandMenuItemEnum);
console.log(`${_quickPickValue[0]}: ${_quickPickValue[1]}`);

pickLabel = 'Claude';
pickLabel as QueryEngineNamesEnum;
switch (pickLabel as QueryEngineNamesEnum) {
  case QueryEngineNamesEnum.Grok:
    _newQueryEngines ^= QueryEngineFlagsEnum.Grok;
    break;
  case QueryEngineNamesEnum.ChatGPT:
    _newQueryEngines ^= QueryEngineFlagsEnum.ChatGPT;
    break;
  case QueryEngineNamesEnum.Claude:
    _newQueryEngines ^= QueryEngineFlagsEnum.Claude;
    break;
  case QueryEngineNamesEnum.Bard:
    _newQueryEngines ^= QueryEngineFlagsEnum.Bard;
    break;
  default:
    throw new Error(`quickPickStateInvokedActorOnDoneAction received an unexpected pickLabel: ${pickLabel}`);
}
_quickPickKindOfEnumeration = QuickPickEnumeration.QueryEnginesMenuItemEnum;
_quickPickValue = createQuickPickValue(_quickPickKindOfEnumeration, _newQueryEngines);
console.log(`${_quickPickValue[0]}: ${_quickPickValue[1]}`);

pickLabel = 'fix';
_quickPickKindOfEnumeration = QuickPickEnumeration.ModeMenuItemEnum;
_quickPickValue = createQuickPickValue(_quickPickKindOfEnumeration, pickLabel as QueryAgentCommandMenuItemEnum);
console.log(`${_quickPickValue[0]}: ${_quickPickValue[1]}`);

*/
