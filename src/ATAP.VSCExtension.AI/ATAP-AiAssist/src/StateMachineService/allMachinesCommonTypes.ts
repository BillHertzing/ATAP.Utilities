// **********************************************************************************************************************
// types and interfaces across all machines

import { LogLevel, ILogger, Logger } from "@Logger/index";
import { ActorRef } from "xstate";

export interface IActorRefAndSubscription {
  actorRef: ActorRef<any, any>;
  subscription: any;
}

export interface IAllMachinesBaseInput {
  logger: ILogger;
}
export interface IAllMachinesBaseContext extends IAllMachinesBaseInput {}

export interface IChildMachineBaseInput extends IAllMachinesBaseInput {
  parent: ActorRef<any, any>;
}
export interface IChildMachineBaseOutput {
  isCancelled: boolean;
  errorMessage?: string;
}
export interface IChildMachineBaseContext
  extends IChildMachineBaseInput,
    IChildMachineBaseOutput {}

export interface IAllMachineNotifyCompleteActionParameters {
  logger: ILogger;
  sendToTargetActorRef: ActorRef<any, any>; // More derived interfaces will override this with a more specific type
  eventCausingTheTransitionIntoOuterDoneState: any; // More derived interfaces will override this with a more specific type
}
