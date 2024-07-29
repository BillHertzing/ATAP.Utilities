import * as vscode from "vscode";
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
  IChildMachineBaseInput,
  IChildMachineBaseOutput,
  IChildMachineBaseContext,
  IActorRefAndSubscription,
} from "./allMachinesCommonTypes";

// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the queryMultipleEngineMachine
export interface IQueryMultipleEngineEventPayload {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
}

export interface IQueryMultipleEngineMachineInput
  extends IChildMachineBaseInput,
    IQueryMultipleEngineEventPayload {
  parent: ActorRef<any, any>;
  currentQueryEngines: QueryEngineFlagsEnum;
  queryService: IQueryService;
}
export interface IQueryMultipleEngineMachineContext
  extends IChildMachineBaseContext,
    IChildMachineBaseOutput {}

export interface IQueryMultipleEngineMachineOutput
  extends Omit<
      IQueryMultipleEngineMachineContext,
      "querySingleEngineMachineActorRefs"
    >,
    IChildMachineBaseOutput {}

export interface IQueryMultipleEngineMachineRefAndSubscription
  extends IActorRefAndSubscription {}

// what the QueryMultipleEngineMachine contributes to the primaryMachine's context
export interface IQueryMultipleEngineMachineComponentOfPrimaryMachineContext {
  queryMultipleEngineMachineRefAndSubscription?: IQueryMultipleEngineMachineRefAndSubscription;
  queryMultipleEngineMachineOutput?: IQueryMultipleEngineMachineOutput;
}

export type QueryMultipleEngineMachineCompletionEventsT =
  | {
      type: "xstate.done.actor.gatheringActor";
      output: IQueryGatheringActorLogicOutput;
    }
  | { type: "xstate.error.actor.gatheringActor"; message: string }
  | {
      type: "QUERY_SINGLE_ENGINE_MACHINE_DONE";
      payload: IQuerySingleEngineMachineDoneEventPayload;
    }
  //| { type: 'xstate.done.actor.queryMultipleEngineActor'; output: IQueryMultipleEngineActorLogicOutput }
  //| { type: 'xstate.error.actor.queryMultipleEngineActor'; message: string }
  | { type: "xstate.done.actor.disposeActor" }
  | { type: "xstate.error.actor.disposeActor"; message: string };
export type QueryMultipleEngineMachineNotifyEventsT =
  | { type: "QUERY_DONE" }
  | { type: "DISPOSE_COMPLETE" };
type QueryMultipleEngineMachineAllEventsT =
  | QueryMultipleEngineMachineCompletionEventsT
  | QueryMultipleEngineMachineNotifyEventsT
  | { type: "DISPOSE_START" }; // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
