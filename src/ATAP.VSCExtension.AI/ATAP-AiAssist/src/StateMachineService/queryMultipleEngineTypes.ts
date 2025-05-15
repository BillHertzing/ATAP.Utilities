import * as vscode from "vscode";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { IData } from "@DataService/index";

import { IQueryService } from "@QueryService/index";

import { IQueryFragmentCollection } from "@ItemWithIDs/index";
import {
  QueryFragmentEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
} from "@BaseEnumerations/index";

import { ActorRef } from "xstate";
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

import {
  IGatheringActorInput,
  IGatheringActorOutput,
  IGatheringActorComponentOfParentMachineContext,
  IGatheringMachineInput,
  IGatheringMachineOutput,
  IGatheringMachineComponentOfParentMachineContext,
  GatheringActorCompletionEventsUnionT,
} from "./gatheringTypes";

import {
  IQuerySingleEngineMachineDoneEventPayload,
  IQuerySingleEngineMachineOutput,
} from "./querySingleEngineTypes";

import { IQueryMultipleEngineEventPayload } from "./primaryMachineTypes";

import { queryMultipleEngineMachine } from "./queryMultipleEngineMachine";

// *********************************************************************************************************************
// context type, input type, output type, and event payload types for the queryMultipleEngineMachine
export interface IQueryMultipleEngineMachineInput
  extends IChildMachineBaseInput,
    IQueryMultipleEngineEventPayload {
  parent: ActorRef<any, any>;
  currentQueryEngines: QueryEngineFlagsEnum;
  queryService: IQueryService;
}

export interface IQueryMultipleSingleEngineMachineOutputs {
  queryMultipleSingleEngineMachineOutputs: IQueryMultipleSingleEngineMachineOutputs;
}
export interface IQueryMultipleEngineMachineOutput
  extends IChildMachineBaseOutput,
    IQueryMultipleSingleEngineMachineOutputs {}

export interface IQueryMultipleSingleEngineMachineRefs {
  queryMultipleSingleEngineMachineRefs: Partial<
    Record<QueryEngineNamesEnum, IQuerySingleEngineMachineOutput>
  >;
}

export interface IQueryMultipleEngineMachineContext
  extends IChildMachineBaseContext,
    IChildMachineBaseOutput,
    IQueryMultipleEngineMachineInput,
    IQueryMultipleEngineMachineOutput {
  gatheringMachine:
    | IGatheringMachineComponentOfParentMachineContext
    | undefined;
  queryMultipleSingleEngineMachineRefs: IQueryMultipleSingleEngineMachineRefs;
}
export interface IQueryMultipleEngineMachineComponentOfParentMachineContext {
  // ToDo: make this only refer to only a queryMultipleEngineMachine instance
  actorRef?: ActorRef<any, any>;
  //ToDo: add a subscription and subscribe to the machine to catch machine-level errors
  queryMultipleEngineMachineOutput?: IQueryMultipleEngineMachineOutput;
}

// *********************************************************************************************************************
// parameter type for the QueryMultipleEngineMachineNotifyCompleteAction
export interface IQueryMultipleEngineMachineNotifyCompleteActionParameters
  extends Omit<
    IAllMachineNotifyCompleteActionParameters,
    "sendToTargetActorRef, eventCausingTheTransitionIntoOuterDoneStatement"
  > {
  // ToDo override the type from the base interface with a union of possible calling machine types
  sendToTargetActorRef: ActorRef<any, any>;
  // override the base set of events with a specific set of completion events
  eventCausingTheTransitionIntoOuterDoneState: QueryMultipleEngineMachineCompletionEventsUnionT;
}
// parameter type for the a2 action
export interface IA2ActionParameters extends IQuerySingleEngineMachineOutput {}

// Events

export type QueryMultipleEngineActorCompletionEventsUnionT =
  | {
      type: "xstate.done.actor.queryMultipleEngineMachineActor";
      output: IGatheringMachineOutput;
    }
  | {
      type: "xstate.error.actor.queryMultipleEngineMachineActor";
      message: string;
    };

export type QueryMultipleEngineMachineCompletionEventsUnionT =
  | QueryMultipleEngineActorCompletionEventsUnionT
  | AllMachineActorDisposeCompletionEventsUnionT
  | {
      type: "QUERY_SINGLE_ENGINE_MACHINE.DONE";
      payload: IQuerySingleEngineMachineDoneEventPayload;
    };

export type QueryMultipleEngineMachineNotifyEventsUnionT =
  | { type: "QUERY_MULTIPLE_ENGINE_MACHINE.DONE" }
  | { type: "DISPOSE.COMPLETE" };

export type QueryMultipleEngineMachineAllEventsUnionT =
  | AllMachineDisposeEventsUnionT
  | GatheringActorCompletionEventsUnionT
  | QueryMultipleEngineMachineCompletionEventsUnionT
  | QueryMultipleEngineMachineNotifyEventsUnionT;
