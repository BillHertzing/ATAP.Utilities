import * as vscode from "vscode";
import { IData } from "@DataService/index";
import { IQueryService } from "@QueryService/index";
import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  QueryFragmentEnum,
  QuickPickEnumeration,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
} from "@BaseEnumerations/index";
import { IQueryFragmentCollection } from "@ItemWithIDs/index";
import {
  IAllMachinesBaseInput,
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
  IQuickPickMachineInput,
  IQuickPickMachineOutput,
  IQuickPickMachineComponentOfParentMachineContext,
} from "./quickPickTypes";

import {
  IGatheringMachineInput,
  IGatheringMachineOutput,
  IGatheringMachineComponentOfParentMachineContext,
} from "./gatheringTypes";

import {
  IQuerySingleEngineMachineInput,
  IQuerySingleEngineMachineOutput,
  IQuerySingleEngineMachineComponentOfParentMachineContext,
} from "./querySingleEngineTypes";

import {
  IQueryMultipleEngineMachineInput,
  IQueryMultipleEngineMachineOutput,
  IQueryMultipleEngineMachineComponentOfParentMachineContext,
} from "./queryMultipleEngineTypes";

/*******************************************************************/
/* Primary Machine Input and Context types */
export interface IPrimaryMachineInput extends IAllMachinesBaseInput {
  queryService: IQueryService;
  data: IData;
}

export interface IPrimaryMachineContext extends IPrimaryMachineInput {
  quickPickMachine: IQuickPickMachineComponentOfParentMachineContext;
  gatheringMachine: IGatheringMachineComponentOfParentMachineContext;
  queryMultipleEngineMachine: IQueryMultipleEngineMachineComponentOfParentMachineContext;
  querySingleEngineMachine: IQuerySingleEngineMachineComponentOfParentMachineContext;
}

/*******************************************************************/
/* Primary Machine Events Payload types */
export interface IQuickPickEventPayload {
  kindOfEnumeration: QuickPickEnumeration;
  cTSToken: vscode.CancellationToken;
}
// ToDo: GatheringMachine
// ToDo: QuerySingleEngineMachine
export interface IQueryMultipleEngineEventPayload {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
}
