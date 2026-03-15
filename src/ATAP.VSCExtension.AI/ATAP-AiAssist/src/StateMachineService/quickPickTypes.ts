import * as vscode from "vscode";
import { ActorRef, Snapshot } from "xstate";
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
  IChildActorBaseInput,
  IChildActorBaseOutput,
  IChildMachineBaseInput,
  IChildMachineBaseOutput,
  IChildMachineBaseContext,
  IAllMachineNotifyCompleteActionParameters,
  AllMachineActorDisposeCompletionEventsUnionT,
  AllMachineDisposeEventsUnionT,
} from "./allMachinesCommonTypes";

import { quickPickMachine } from "./quickPickMachine";

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

// *********************************************************************************************************************
// types and interfaces for the quickPickActor
export interface IQuickPickActorInput extends IChildActorBaseInput {
  cTSToken: vscode.CancellationToken;
  kindOfEnumeration: QuickPickEnumeration;
  pickValue: QuickPickValueT;
  pickItems: vscode.QuickPickItem[];
  prompt: string;
}

// *********************************************************************************************************************
// types and interfaces for the quickPickMachine
export interface IQuickPickMachineInput
  extends IChildMachineBaseInput,
    IQuickPickActorInput {}

export interface IQuickPickMachineOutput extends IChildMachineBaseOutput {
  pickValue: QuickPickValueT;
  isLostFocus: boolean;
}
export interface IQuickPickMachineContext
  extends IQuickPickMachineInput,
    IQuickPickMachineOutput {}
// what the quickPickActor contributes to the primaryMachine's context
export interface IQuickPickMachineComponentOfParentMachineContext {
  // ToDo: make this only refer to only a quickPickMachine instance
  actorRef?: ActorRef<any, any>;
  //ToDo: add a subscription and later subscribe to the machine to catch machine-level errors
  quickPickMachineOutput?: IQuickPickMachineOutput;
}
export interface IQuickPickActorOutput {
  pickValue: QuickPickValueT;
  isCancelled: boolean;
  isLostFocus: boolean;
}

export interface IAssignQuickPickActorOutputToParentContextActionParameters {
  logger: ILogger;
  pickValue: QuickPickValueT;
  isCancelled: boolean;
  isLostFocus: boolean;
}
export interface IQuickPickMachineNotifyCompleteActionParameters
  extends IAllMachineNotifyCompleteActionParameters {
  // ToDo override the type from the base interface with a union of calling machine types
  sendToTargetActorRef: ActorRef<any, any>;
  eventCausingTheTransitionIntoOuterDoneState: QuickPickMachineCompletionEventsUnionT;
}

export interface IAssignQuickPickMachineOutputToParentContextActionParameters
  extends IQuickPickMachineOutput {
  logger: ILogger;

  errorMessage?: string;
}

// Events
export type QuickPickActorCompletionEventsUnionT =
  | {
      type: "xstate.done.actor.quickPickActor";
      output: IQuickPickActorOutput;
    }
  | { type: "xstate.error.actor.quickPickActor"; message: string };
export type QuickPickMachineCompletionEventsUnionT =
  | QuickPickActorCompletionEventsUnionT
  | AllMachineActorDisposeCompletionEventsUnionT;
export type QuickPickMachineNotifyEventsUnionT =
  | { type: "QUICKPICK_MACHINE.DONE" }
  | { type: "DISPOSE.COMPLETE" };

export type QuickPickMachineAllEventsUnionT =
  | AllMachineDisposeEventsUnionT
  | QuickPickMachineCompletionEventsUnionT
  | QuickPickMachineNotifyEventsUnionT;
