// *********************************************************************************************************************
// types and interfaces across all machines

import { LogLevel, ILogger, Logger } from "@Logger/index";
import { ActorRef } from "xstate";

export interface IAllMachinesBaseInput {
  logger: ILogger;
}
export interface IAllMachinesBaseContext extends IAllMachinesBaseInput {}

export interface IChildActorBaseInput extends IAllMachinesBaseInput {}
export interface IChildMachineBaseInput extends IAllMachinesBaseInput {
  parent: ActorRef<any, any>;
}
export interface IChildActorBaseOutput {
  isCancelled: boolean;
  errorMessage?: string;
}
export interface IChildMachineBaseOutput extends IChildActorBaseOutput {}
export interface IChildMachineBaseContext
  extends IChildMachineBaseInput,
    IChildMachineBaseOutput {}

export interface IAllMachineNotifyCompleteActionParameters {
  logger: ILogger;
  sendToTargetActorRef: ActorRef<any, any>; // More derived interfaces will override this with a more specific type
  eventCausingTheTransitionIntoOuterDoneState: any; // More derived interfaces will override this with a more specific type
}

// events
export type AllMachineActorDisposeCompletionEventsUnionT =
  | { type: "xstate.done.actor.disposeActor" }
  | { type: "xstate.error.actor.disposeActor"; message: string };

export type AllMachineDisposeEventsUnionT =
  | { type: "DISPOSE.START" } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
  | { type: "DISPOSE.COMPLETE" };
