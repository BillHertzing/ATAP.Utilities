import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
  VCSCommandMenuItemEnum,
  SupportedQueryEnginesEnum,
  QueryFragmentEnum,
} from '@BaseEnumerations/index';

import { fromCallback, StateMachine, fromPromise, assign, ActionFunction } from 'xstate';

import { MachineContextT } from '@StateMachineService/index';

import { QueryEventPayloadT } from './queryMachine';

export type QueryActorLogicInputT = MachineContextT & QueryEventPayloadT;

export type QueryActorLogicOutputT = {
  cTSId: string;
};

export type GatherQueryFragmentsActorLogicInputT = QueryActorLogicInputT;

export type GatherQueryFragmentsActorLogicOutputT = { queryString: string };

export const gatherQueryFragmentsActorLogic = fromPromise(
  async ({ input }: { input: GatherQueryFragmentsActorLogicInputT }) => {
    let cancelled: boolean = false;
    let queryString = '';
    input.logger.log(`gatherQueryFragmentsActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (!input.cTSToken.isCancellationRequested) {
      // switch on the fragmentKind and collect accordingly
      for (const queryFragmentId of input.queryFragmentCollection?.ID.ID) {
        //ToDo: wrap in try catch
        const queryFragment = input.data.fileManager.queryFragmentCollection?.findById(queryFragmentId);
        switch (queryFragment?.value.kindOfFragment) {
          case QueryFragmentEnum.StringFragment:
            queryString += queryFragment.value;
            break;
          case QueryFragmentEnum.FileFragment:
            queryString += queryFragment.value;
            break;
          default:
            throw new Error(`Unhandled queryFragment.kindOfFragment: ${queryFragment?.value.kindOfFragment}`);
        }
      }
    } else {
      // ToDo: make the various cancellation conditions into an enumeration, and return that as part of the retrun structure?
      cancelled = true;
    }
    input.logger.log(
      `gatherQueryFragmentsActorLogic leaving with queryString= ${queryString}, cancelled: ${cancelled}`,
      LogLevel.Debug,
    );
    return {
      queryString: queryString,
      cancelled: cancelled,
    } as GatherQueryFragmentsActorLogicOutputT;
  },
);

// **********************************************************************************************************************

export type ParallelQueryActorLogicInputT = MachineContextT &
  QueryActorLogicInputT &
  GatherQueryFragmentsActorLogicOutputT;

export type ParallelQueryActorLogicResultsT = {
  results: { queryEngineName: string; queryResult: string }[];
  success: boolean;
};

export type ParallelQueryActorLogicOutputT = {
  results: ParallelQueryActorLogicResultsT;
  cancelled: boolean;
};

export const parallelQueryActorLogic = fromPromise(async ({ input }: { input: ParallelQueryActorLogicInputT }) => {
  input.logger.log(`parallelQueryActorLogic called`, LogLevel.Debug);
  let cancelled: boolean = false;
  let success: boolean = false;
  let results: ParallelQueryActorLogicResultsT = { results: [], success: false };
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (!input.cTSToken.isCancellationRequested) {
    let _qs = input.queryString;
    // dispatch to active,and await all
    // ToDo: add resilience to the query engine dispatching
  } else {
    // ToDo: make the various cancellation conditions into an enumeration, and return that as part of the retrun structure?
    cancelled = true;
  }

  input.logger.log(
    `parallelQueryActorLogic leaving with results = ${results}, cancelled: ${cancelled}`,
    LogLevel.Debug,
  );
  return { results: results, cancelled: cancelled } as ParallelQueryActorLogicOutputT;
});

// **********************************************************************************************************************

export type SingleQueryActorLogicInputT = ParallelQueryActorLogicInputT;

export type SingleQueryActorLogicOutputT = {
  response: string | undefined;
  success: boolean;
  cancelled: boolean;
};

export const singleQueryActorLogic = fromPromise(async ({ input }: { input: SingleQueryActorLogicInputT }) => {
  input.logger.log(`singleQueryActorLogic called`, LogLevel.Debug);
  let cancelled: boolean = false;
  let success: boolean = false;
  let response: string | undefined = undefined;
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (!input.cTSToken.isCancellationRequested) {
    let _qs = input.queryString;
    // use the queryService to handle the query to a queryEngine
  } else {
    // ToDo: make the various cancellation conditions into an enumeration, and return that as part of the retrun structure?
    cancelled = true;
  }

  input.logger.log(
    `singleQueryActorLogic leaving with respone = ${response}, success = ${success}, cancelled = ${cancelled}`,
    LogLevel.Debug,
  );
  return { response: response, success: success, cancelled: cancelled } as SingleQueryActorLogicOutputT;
});
