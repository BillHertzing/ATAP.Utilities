import * as vscode from "vscode";
import { LogLevel, ILogger, Logger } from "@Logger/index";

import {
  ActorRef,
  assertEvent,
  assign,
  fromPromise,
  OutputFrom,
  sendTo,
  setup,
} from "xstate";

import {
  QueryFragmentEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
} from "@BaseEnumerations/index";

import { IQueryService } from "@QueryService/index";

import {
  IChildMachineBaseInput,
  IChildMachineBaseOutput,
  IChildMachineBaseContext,
  IActorRefAndSubscription,
  IAllMachineNotifyCompleteActionParameters,
} from "./allMachinesCommonTypes";

export type QuerySingleEngineMachineActorOutputsT = Record<
  QueryEngineNamesEnum,
  IQuerySingleEngineMachineActorLogicOutput
>;
export type QuerySingleEngineMachineActorRefsT = Record<
  QueryEngineNamesEnum,
  IActorRefAndSubscription
>;

export interface IQuerySingleEngineComponentOfQueryMultipleEngineMachineContext {
  querySingleEngineMachineActorRefs: QuerySingleEngineMachineActorRefsT;
  querySingleEngineMachineActorOutputs: Partial<QuerySingleEngineMachineActorOutputsT>; // partial because the instance doesn't have to have every member of the enumeration
}

// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the querySingleEngineMachine

export interface IQuerySingleEngineMachineInput
  extends IChildMachineBaseContext {
  parent: ActorRef<any, any>;
  queryService: IQueryService;
  queryString: string;
  queryEngineName: QueryEngineNamesEnum;
  cTSToken: vscode.CancellationToken;
}
export interface IQuerySingleEngineMachineContext
  extends IQuerySingleEngineMachineInput,
    IChildMachineBaseOutput {
  response?: string;
}
export interface IQuerySingleEngineMachineOutput
  extends IQuerySingleEngineMachineActorLogicOutput {}

export interface IQuerySingleEngineMachineActorRefAndSubscription
  extends IActorRefAndSubscription {}
// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the querySingleEngineMachineActorLogic
export interface IQuerySingleEngineMachineActorLogicInput {
  logger: ILogger;
  queryService: IQueryService;
  queryString?: string;
  queryEngineName: QueryEngineNamesEnum;
  cTSToken: vscode.CancellationToken;
}
export interface IQuerySingleEngineMachineActorLogicOutput
  extends IChildMachineBaseOutput {
  queryEngineName: QueryEngineNamesEnum;
  response?: string;
}
export interface IQuerySingleEngineMachineDoneEventPayload {
  queryEngineName: QueryEngineNamesEnum;
}

export interface IQuerySingleEngineMachineNotifyCompleteActionParameters
  extends IAllMachineNotifyCompleteActionParameters {
  // sendToTargetActorRef: ActorRef<any, any>; // override the type from the base interface
  eventCausingTheTransitionIntoOuterDoneState: QuerySingleEngineMachineCompletionEventsT; // override the type from the base interface
  queryEngineName: QueryEngineNamesEnum;
}

export type QuerySingleEngineMachineCompletionEventsT =
  | {
      type: "xstate.done.actor.querySingleEngineMachineActor";
      output: IQuerySingleEngineMachineActorLogicOutput;
    }
  | {
      type: "xstate.error.actor.querySingleEngineMachineActor";
      message: string;
    }
  | { type: "xstate.done.actor.disposeActor" }
  | { type: "xstate.error.actor.disposeActor"; message: string };
export type QuerySingleEngineMachineNotifyEventsT =
  | {
      type: "QUERY.SINGLE_ENGINE_MACHINE_DONE";
      payload: IQuerySingleEngineMachineDoneEventPayload;
    }
  | { type: "DISPOSE_COMPLETE" };
export type QuerySingleEngineMachineAllEventsT =
  | QuerySingleEngineMachineCompletionEventsT
  | QuerySingleEngineMachineNotifyEventsT
  | { type: "DISPOSE_START" }; // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
