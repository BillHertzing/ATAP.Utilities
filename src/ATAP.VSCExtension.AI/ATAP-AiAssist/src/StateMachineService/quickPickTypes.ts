import * as vscode from 'vscode';
import { ActorRef } from 'xstate';
import { LogLevel, ILogger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { IData } from '@DataService/index';

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
} from '@BaseEnumerations/index';

import { LoggerDataT } from '@StateMachineService/index';

export type QuickPickMachineComponentOfPrimaryMachineContextT = {
  quickPickMachineActorRef?: ActorRef<any, any>;
};

export type QuickPickMachineSpecificContextT = {
  parent: ActorRef<any, any>;
  quickPickCTSToken?: vscode.CancellationToken;
  quickPickKindOfEnumeration?: QuickPickEnumeration;
  quickPickErrorMessage?: string;
  quickPickCancelled: boolean;
};

export type QuickPickMachineContextT = {
  logger: ILogger;
  data: IData;
  parent: ActorRef<any, any>;
  quickPickKindOfEnumeration?: QuickPickEnumeration;
  quickPickCTSToken?: vscode.CancellationToken;
  quickPickErrorMessage?: string;
  quickPickCancelled?: boolean;
};

//LoggerDataT & QuickPickMachineSpecificContextT;

export type QuickPickEventPayloadT = {
  quickPickKindOfEnumeration: QuickPickEnumeration;
  quickPickCTSToken: vscode.CancellationToken;
};

export type QuickPickActorLogicInputT = LoggerDataT & QuickPickEventPayloadT;

export type QuickPickActorLogicOutputT = {
  quickPickKindOfEnumeration: QuickPickEnumeration;
  pickLabel: string;
};

// the QuickPickMachine does not return any output
export type QuickPickMachineOutputT = {};
