import { IData } from "@DataService/index";
import { IQueryService } from "@QueryService/index";

import { IAllMachinesBaseContext } from "./allMachinesCommonTypes";

import {
  IQuickPickMachineInput,
  IQuickPickMachineOutput,
  IQuickPickMachineComponentOfPrimaryMachineContext,
} from "./quickPickMachineTypes";

import {
  IQueryMultipleEngineMachineInput,
  IQueryMultipleEngineMachineOutput,
} from "./queryMultipleEngineMachineTypes";

import { IQuickPickMachineRefAndSubscription } from "./quickPickMachineTypes";
import { IQueryMultipleEngineMachineRefAndSubscription } from "./queryMultipleEngineMachineTypes";

/*******************************************************************/
/* Primary Machine Input and Context types */
export interface IPrimaryMachineInput extends IAllMachinesBaseContext {
  queryService: IQueryService;
  data: IData;
}

export interface IPrimaryMachineContext
  extends IPrimaryMachineInput,
    IQuickPickMachineInput,
    IQuickPickMachineComponentOfPrimaryMachineContext, // the IQuickPickMachineOutput and the ActorRefAndSubscription for the QuickPickMachine child machine
    IQueryMultipleEngineMachineInput,
    IQueryMultipleEngineMachineOutput {
  queryMultipleEngineMachineActorRefAndSubscription: IQueryMultipleEngineMachineRefAndSubscription;
}
