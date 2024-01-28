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
  QueryFragmentEnum,
} from '@BaseEnumerations/index';

import { IQueryFragment, IQueryFragmentCollection } from '@ItemWithIDs/index';

import { fromCallback, StateMachine, fromPromise, assign, ActionFunction } from 'xstate';

import { MachineContextT } from '@StateMachineService/index';

export type QueryEventPayloadT = {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
};

export type QueryEventOutputT = {
  responses: { [key in QueryEngineNamesEnum]: string };
  errors: { [key in QueryEngineNamesEnum]: DetailedError[] };
};

export type QueryActorLogicInputT = MachineContextT & QueryEventPayloadT;

export type QueryActorLogicOutputT = {
  cTSId: string;
};

export type GatherQueryFragmentsActorLogicInputT = QueryActorLogicInputT;

export type GatherQueryFragmentsActorLogicOutputT = {
  queryString: string;
  cTSToken: vscode.CancellationToken;
  cancelled: boolean;
  error?: DetailedError;
};

export const gatherQueryFragmentsActorLogic = fromPromise<
  GatherQueryFragmentsActorLogicOutputT,
  GatherQueryFragmentsActorLogicInputT
>(async ({ input }: { input: GatherQueryFragmentsActorLogicInputT }) => {
  let cancelled: boolean = false;
  let queryString = '';
  input.logger.log(`gatherQueryFragmentsActorLogic called`, LogLevel.Debug);
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (input.cTSToken.isCancellationRequested) {
    return {
      queryString: queryString,
      cancelled: true,
      cTSToken: input.cTSToken,
    } as GatherQueryFragmentsActorLogicOutputT;
  }
  // if the queryFragmentCollection is not defionmed or is empty, then return an error
  if (!input.queryFragmentCollection || input.queryFragmentCollection.value.length === 0) {
    return {
      queryString: queryString,
      cancelled: false,
      cTSToken: input.cTSToken,
      error: new DetailedError('queryFragmentCollection is not defined or empty'),
    } as GatherQueryFragmentsActorLogicOutputT;
  }
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
  input.logger.log(
    `gatherQueryFragmentsActorLogic leaving with queryString= ${queryString}, cancelled: ${cancelled}`,
    LogLevel.Debug,
  );
  return {
    queryString: queryString,
    cancelled: cancelled,
    cTSToken: input.cTSToken,
  } as GatherQueryFragmentsActorLogicOutputT;
});

// **********************************************************************************************************************

export type ParallelQueryActorLogicInputT = MachineContextT & GatherQueryFragmentsActorLogicOutputT;

export type ParallelQueryActorLogicResultsT = {
  results?: Record<QueryEngineNamesEnum, string>;
};

export type ParallelQueryActorLogicOutputT = {
  results: ParallelQueryActorLogicResultsT;
  cancelled: boolean;
  errors?: Record<QueryEngineNamesEnum, DetailedError>;
  cTSToken: vscode.CancellationToken;
};

export const parallelQueryActorLogic = fromPromise(async ({ input }: { input: ParallelQueryActorLogicInputT }) => {
  input.logger.log(`parallelQueryActorLogic called`, LogLevel.Debug);
  let cancelled: boolean = false;
  let success: boolean = false;
  let results: ParallelQueryActorLogicResultsT = {} as ParallelQueryActorLogicResultsT;
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (input.cTSToken.isCancellationRequested) {
    return { results: results, cancelled: true, cTSToken: input.cTSToken } as ParallelQueryActorLogicOutputT;
  }
  // if the input queryString is undefined or '', return an error
  if (!input.queryString || input.queryString === '') {
    return {
      results: results,
      cancelled: false,
      cTSToken: input.cTSToken,
      error: new DetailedError('queryString is not defined or empty'),
    } as ParallelQueryActorLogicOutputT;
  }
  // passes all checks so return and continue
  return { results: results, cancelled: cancelled, cTSToken: input.cTSToken } as ParallelQueryActorLogicOutputT;
});

// **********************************************************************************************************************

export type SingleQueryActorLogicInputT = ParallelQueryActorLogicInputT;

export type SingleQueryActorLogicOutputT = {
  response?: string;
  error?: DetailedError;
  cancelled: boolean;
};

export const singleQueryActorLogic = fromPromise<SingleQueryActorLogicOutputT, SingleQueryActorLogicInputT>(
  async ({ input }: { input: SingleQueryActorLogicInputT }) => {
    input.logger.log(`singleQueryActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      return { cancelled: true } as SingleQueryActorLogicOutputT;
    }
    let _qs = input.queryString;
    let response: string;
    response = 'ResponseFrom QueryEnginePlaceholder';
    // ToDo: use the queryService to handle the query to a queryEngine
    return { response: response, cancelled: false } as SingleQueryActorLogicOutputT;
  },
);

// **********************************************************************************************************************

export const fetchingFromBardActorLogic = fromPromise<SingleQueryActorLogicOutputT, SingleQueryActorLogicInputT>(
  async ({ input }: { input: SingleQueryActorLogicInputT }) => {
    input.logger.log(`fetchingFromBardActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      input.logger.log(`fetchingFromBardActorLogic leaving with cancelled = true`, LogLevel.Debug);
      return { cancelled: true } as SingleQueryActorLogicOutputT;
    }

    let _qs = input.queryString;
    let response: string;
    response = 'ResponseFrom QueryEnginePlaceholder';
    // use the queryService to handle the query to the Bard queryEngine
    // ToDo: use the queryService to handle the query to a queryEngine
    return { response: response, cancelled: false } as SingleQueryActorLogicOutputT;

    input.logger.log(
      `fetchingFromBardActorLogic leaving with response = ${response}, cancelled = false`,
      LogLevel.Debug,
    );
    return { response: response, cancelled: false } as SingleQueryActorLogicOutputT;
  },
);
