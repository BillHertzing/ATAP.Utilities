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
  IChildActorBaseInput,
  IChildActorBaseOutput,
  IChildMachineBaseInput,
  IChildMachineBaseOutput,
  IChildMachineBaseContext,
  IAllMachineNotifyCompleteActionParameters,
  AllMachineActorDisposeCompletionEventsUnionT,
  AllMachineDisposeEventsUnionT,
} from "./allMachinesCommonTypes";

// *********************************************************************************************************************
// context type, input type, output type, and event payload types for the querySingleEngineActorLogic
export interface IQuerySingleEngineActorInput {
  logger: ILogger;
  queryService: IQueryService;
  queryString?: string;
  queryEngineName: QueryEngineNamesEnum;
  cTSToken: vscode.CancellationToken;
}
export interface IQuerySingleEngineActorOutput extends IChildActorBaseOutput {
  queryEngineName: QueryEngineNamesEnum;
  response?: string;
}

// what the QuerySingleEngineActor contributes to a parent's context
export interface IQuerySingleEngineActorComponentOfParentMachineContext
  extends IQuerySingleEngineActorInput,
    IQuerySingleEngineActorOutput {
  // Comment out - when a promise actor is invoked inside of a machine, we don't need a reference to it
  // ToDo: make this only refer to only a querySingleEngineActor instance
  // actorRef?: ActorRef<any, any>;
}

// *********************************************************************************************************************
// context type, input type, output type, and event payload types for the querySingleEngineMachine
//  The NotifyCompleteActionParameters are used to pass the event that caused the transition to the outer done state
//  along with an identifier for the parent and the name of the queryEngine that was queried by this actor

export interface IQuerySingleEngineMachineInput extends IChildMachineBaseInput {
  parent: ActorRef<any, any>;
  queryService: IQueryService;
  queryString: string;
  queryEngineName: QueryEngineNamesEnum;
  cTSToken: vscode.CancellationToken;
}
export interface IQuerySingleEngineMachineOutput
  extends IQuerySingleEngineActorOutput {}

export interface IQuerySingleEngineMachineContext
  extends IQuerySingleEngineMachineInput,
    IChildMachineBaseOutput {
  response?: string;
}
// what the QuerySingleEngineMachine contributes to a parent's context
export interface IQuerySingleEngineMachineComponentOfParentMachineContext
  extends IQuerySingleEngineMachineInput,
    IQuerySingleEngineMachineOutput {
  // ToDo: make this only refer to only a querySingleEngineMachine instance
  actorRef?: ActorRef<any, any>;
  //ToDo: add a subscription and later subscribe to the machine to catch machine-level errors
}

export interface IQuerySingleEngineMachineDoneEventPayload {
  queryEngineName: QueryEngineNamesEnum;
}

export interface IQuerySingleEngineMachineNotifyCompleteActionParameters
  extends IAllMachineNotifyCompleteActionParameters {
  // ToDo override the type from the base interface with a union of possible calling machine types
  sendToTargetActorRef: ActorRef<any, any>;
  eventCausingTheTransitionIntoOuterDoneState: QuerySingleEngineMachineCompletionEventsUnionT;
  queryEngineName: QueryEngineNamesEnum;
}

// Events
export type QuerySingleEngineActorCompletionEventsUnionT =
  | {
      type: "xstate.done.actor.querySingleEngineActor";
      output: IQuerySingleEngineActorOutput;
    }
  | {
      type: "xstate.error.actor.querySingleEngineActor";
      message: string;
    };
export type QuerySingleEngineMachineCompletionEventsUnionT =
  | QuerySingleEngineActorCompletionEventsUnionT
  | AllMachineActorDisposeCompletionEventsUnionT;
export type QuerySingleEngineMachineNotifyEventsUnionT =
  | {
      type: "QUERY_SINGLE_ENGINE_MACHINE.DONE";
      payload: IQuerySingleEngineMachineDoneEventPayload;
    }
  | { type: "DISPOSE.COMPLETE" };
export type QuerySingleEngineMachineAllEventsUnionT =
  | AllMachineDisposeEventsUnionT
  | QuerySingleEngineMachineCompletionEventsUnionT
  | QuerySingleEngineMachineNotifyEventsUnionT;
