import { randomOutcome } from "@Utilities/index"; // ToDo: replace with a mocked iQueryService instead of using this import
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

import { IQueryFragmentCollection } from "@ItemWithIDs/index";

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
// input and output to the gatheringActor
export interface IGatheringActorInput {
  //extends IChildActorBaseInput { // logger
  logger: ILogger;
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
}
export interface IGatheringActorOutput {
  //extends IChildActorBaseOutput { isCancelled and errormessages
  isCancelled: boolean;
  queryString?: string;
}

export interface IGatheringActorComponentOfParentMachineContext
  extends IGatheringActorInput,
    IGatheringActorOutput {}

// *********************************************************************************************************************
// input and output to the GatheringMachine
export interface IGatheringMachineInput
  extends IChildMachineBaseInput,
    IGatheringActorInput {}

export interface IGatheringMachineOutput
  extends IChildMachineBaseOutput,
    IGatheringActorOutput {}

export interface IGatheringMachineComponentOfParentMachineContext
  extends IGatheringMachineInput,
    IGatheringMachineOutput {
  // ToDo: make this only refer to only a gatheringMachine instance
  actorRef?: ActorRef<any, any>;
  //ToDo: add a subscription and later subscribe to the machine to catch machine-level errors
}
export interface IGatheringMachineNotifyCompleteActionParameters
  extends Omit<
    IAllMachineNotifyCompleteActionParameters,
    "sendToTargetActorRef, eventCausingTheTransitionIntoOuterDoneStatement"
  > {
  // ToDo override the type of the ActorRef from the base interface with a union of possible calling machine types
  sendToTargetActorRef: ActorRef<any, any>;
  // override the base interface with a specific set of completion events
  eventCausingTheTransitionIntoOuterDoneState: GatheringMachineCompletionEventsUnionT;
  queryEngineName: QueryEngineNamesEnum;
}

// Events
export type GatheringActorCompletionEventsUnionT =
  | {
      type: "xstate.done.actor.gatheringActor";
      output: IGatheringActorOutput;
    }
  | { type: "xstate.error.actor.gatheringActor"; message: string };
export type GatheringMachineCompletionEventsUnionT =
  | GatheringActorCompletionEventsUnionT
  | AllMachineActorDisposeCompletionEventsUnionT;
