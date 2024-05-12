import * as vscode from 'vscode';
import { ActorRef } from 'xstate';
import { LogLevel, ILogger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { IData } from '@DataService/index';

import { QueryEngineNamesEnum, QueryEngineFlagsEnum, QueryFragmentEnum } from '@BaseEnumerations/index';

import { IQueryFragment, QueryFragment, IQueryFragmentCollection } from '@ItemWithIDs/index';

import { LoggerDataT } from '@StateMachineService/index';
import { IQueryService } from '@QueryService/index';

export type ActorRefAndSubscriptionT = {actorRef: ActorRef<any, any>, subscription: any};
export type QueryActorOutputsT = Record<QueryEngineNamesEnum, QuerySingleActorLogicOutputT>;
export type QueryActorRefsT = Record<QueryEngineNamesEnum, ActorRef<any, any>>;

// **********************************************************************************************************************
// context, input and output to the QueryMachine
export type QueryMachineSpecificContextT = {
  parent: ActorRef<any, any>;
  queryService: IQueryService;
  queryFragmentCollection?: IQueryFragmentCollection;
  queryString?: string;
  queryErrorMessage?: string;
  queryCancelled: boolean;
  queryActorRefs?: QueryActorRefsT;
  queryActorOutputs?: QueryActorOutputsT;
  queryCTSToken?: vscode.CancellationToken;
};

export type QueryMachineComponentOfPrimaryMachineContextT = {
  queryService: IQueryService;
  queryMachineActorRef?: ActorRef<any, any>;
  queryMachineOutput?: QueryMachineOutputT;
};

export type QueryMachineContextT = LoggerDataT & QueryMachineSpecificContextT;

export type QueryEventPayloadT = {
  queryFragmentCollection: IQueryFragmentCollection;
  queryCTSToken: vscode.CancellationToken;
};

export type QueryMachineOutputT = {
  queryActorOutputs?: QueryActorOutputsT;
  queryErrorMessage?: string;
  queryCancelled: boolean;
};

// **********************************************************************************************************************
// input and output to the QueryGatheringActorLogicSource
export type QueryGatheringActorLogicInputT = {
  logger: ILogger;
  data: IData;
  queryFragmentCollection: IQueryFragmentCollection;
  queryCTSToken: vscode.CancellationToken;
};

export type QueryGatheringActorLogicOutputT = {
  queryString?: string;
  queryErrorMessage?: string;
  queryCancelled: boolean;
};

// **********************************************************************************************************************
// input type and output type to the QuerySingleActorLogicSource
export type QuerySingleActorLogicInputT = {
  logger: ILogger;
  data: IData;
  queryService: IQueryService;
  queryString?: string;
  queryEngineName: QueryEngineNamesEnum;
  queryCTSToken: vscode.CancellationToken;
};

export type QuerySingleActorLogicOutputT = {
  queryEngineName: QueryEngineNamesEnum;
  queryResponse?: string;
  queryErrorMessage?: string;
  queryCancelled: boolean;
};

// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the querySingleActorMachine
export type QuerySingleActorMachineContextT = {
  logger: ILogger;
  data: IData;
  parent: ActorRef<any, any>;
  queryService: IQueryService;
  queryString?: string;
  queryEngineName: QueryEngineNamesEnum;
  queryResponse?: string;
  queryErrorMessage?: string;
  queryCancelled: boolean;
  queryCTSToken: vscode.CancellationToken;
};
export type QuerySingleActorMachineInputT = {
  logger: ILogger;
  data: IData;
  parent: ActorRef<any, any>;
  queryService: IQueryService;
  queryString?: string;
  queryEngineName: QueryEngineNamesEnum;
  queryCTSToken: vscode.CancellationToken;
};
export type QuerySingleActorMachineOutputT = QuerySingleActorLogicOutputT;

export type QuerySingleActorDoneEventPayloadT = { queryEngineName: QueryEngineNamesEnum };
