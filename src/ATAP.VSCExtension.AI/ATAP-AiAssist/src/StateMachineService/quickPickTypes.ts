import * as vscode from "vscode";
import { ActorRef } from "xstate";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";
import { logConstructor, logMethod, logAsyncFunction } from "@Decorators/index";
import { IData } from "@DataService/index";

import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  QueryFragmentEnum,
  QuickPickEnumeration,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
} from "@BaseEnumerations/index";

import {
  IChildMachineBaseInput,
  IChildMachineBaseOutput,
  IChildMachineBaseContext,
  IActorRefAndSubscription,
  IAllMachineNotifyCompleteActionParameters,
} from "./allMachinesCommonTypes";

export interface IQuickPickMachineInput extends IChildMachineBaseContext {
  cTSToken: vscode.CancellationToken;
  quickPickKindOfEnumeration: QuickPickEnumeration;
  pickValue: QuickPickValueT;
  pickItems: vscode.QuickPickItem[];
  prompt: string;
}
export interface IQuickPickMachineOutput extends IChildMachineBaseOutput {
  pickValue: QuickPickValueT;
  isLostFocus: boolean;
}
export interface IQuickPickMachineContext
  extends IQuickPickMachineInput,
    IQuickPickMachineOutput {}
export interface IQuickPickActorLogicInput
  extends Omit<
    IQuickPickMachineContext,
    "parent" | "isCancelled" | "isLostFocus"
  > {}

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

export type QuickPickEventPayloadT = {
  quickPickKindOfEnumeration: QuickPickEnumeration;
  quickPickCTSToken: vscode.CancellationToken;
};

export type QuickPickActorLogicOutputT = {
  quickPickKindOfEnumeration: QuickPickEnumeration;
  pickLabel: string;
};

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
  | [
      QuickPickEnumeration.QueryAgentCommandMenuItemEnum,
      QueryAgentCommandMenuItemEnum,
    ];

// **********************************************************************************************************************
// types and interfaces for the quickPickMachine
export interface IQuickPickMachineRefAndSubscription
  extends IActorRefAndSubscription {
  // replace the any with the specific type of the actorRef
}
// what the quickPickActor contributes to the primaryMachine's context
export interface IQuickPickMachineComponentOfPrimaryMachineContext {
  quickPickMachineActorRefAndSubscription?: IQuickPickMachineRefAndSubscription;
  quickPickMachineOutput?: IQuickPickMachineOutput;
}
export interface IQuickPickEventPayload {
  quickPickKindOfEnumeration: QuickPickEnumeration;
  cTSToken: vscode.CancellationToken;
}
export interface IQuickPickActorLogicOutput {
  pickValue: QuickPickValueT;
  isCancelled: boolean;
  isLostFocus: boolean;
}
export interface IQuickPickMachineNotifyCompleteActionParameters
  extends IAllMachineNotifyCompleteActionParameters {
  sendToTargetActorRef: ActorRef<any, any>; // Make this the actorRef for a primary machine
  eventCausingTheTransitionIntoOuterDoneState: QuickPickMachineCompletionEventsUnionT;
}
export type QuickPickMachineCompletionEventsUnionT =
  | {
      type: "xstate.done.actor.quickPickActor";
      output: IQuickPickActorLogicOutput;
    }
  | { type: "xstate.error.actor.quickPickActor"; message: string }
  | { type: "xstate.done.actor.quickPickDisposeActor" }
  | { type: "xstate.error.actor.quickPickDisposeActor"; message: string };

export interface IAssignQuickPickActorDoneOutputToQuickPickMachineContextActionParameters
  extends IQuickPickMachineOutput {
  errorMessage?: string;
}
