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

import { IQueryFragment, QueryFragment, IQueryFragmentCollection } from '@ItemWithIDs/index';

import { fromCallback, StateMachine, fromPromise, ActorRef, assign, ActionFunction } from 'xstate';

import { QueryMachineContextT, QueryEventPayloadT } from './queryMachine';

import { IQueryService } from '@QueryService/index';

export type GatheringActorLogicInputT = QueryMachineContextT & QueryEventPayloadT;

export type GatheringActorLogicOutputT = {
  queryString: string;
  cTSToken: vscode.CancellationToken;
  cancelled: boolean;
  error?: DetailedError;
};

export const gatheringActorLogic = fromPromise<GatheringActorLogicOutputT, GatheringActorLogicInputT>(
  async ({ input }: { input: GatheringActorLogicInputT }) => {
    let cancelled: boolean = false;
    let queryString = '';
    let _queryFragmentCollection: IQueryFragmentCollection;
    let _queryFragment: IQueryFragment;
    input.logger.log(`gatheringActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      return {
        queryString: queryString,
        cancelled: true,
        cTSToken: input.cTSToken,
      } as GatheringActorLogicOutputT;
    }
    _queryFragmentCollection = input.queryFragmentCollection;
    // if the queryFragmentCollection is not defined or is empty, then return an error
    if (!_queryFragmentCollection || _queryFragmentCollection.value.length === 0) {
      return {
        queryString: queryString,
        cancelled: false,
        cTSToken: input.cTSToken,
        error: new DetailedError('queryFragmentCollection is not defined or empty'),
      } as GatheringActorLogicOutputT;
    }
    // switch on the fragmentKind and collect accordingly
    _queryFragmentCollection.value.forEach((element) => {
      switch (element.value.kindOfFragment) {
        case QueryFragmentEnum.StringFragment:
          queryString += element.value.value;
          break;
        case QueryFragmentEnum.FileFragment:
          //ToDo: Implement FileFragment
          //queryString += element.value;
          break;
        default:
          throw new Error(`Unhandled queryFragment.kindOfFragment: ${element.value.kindOfFragment}`);
      }
    });
    input.logger.log(
      `gatheringActorLogic leaving with queryString= ${queryString}, cancelled: ${cancelled}`,
      LogLevel.Debug,
    );
    return {
      queryString: queryString,
      cancelled: cancelled,
      cTSToken: input.cTSToken,
    } as GatheringActorLogicOutputT;
  },
);

// **********************************************************************************************************************

export type ParallelQueryActorLogicInputT = QueryMachineContextT & GatheringActorLogicOutputT;

export type ParallelQueryActorLogicOutputT = {
  actorReferences: { [key in QueryEngineNamesEnum]: ActorRef<any, any> };
  cancelled: boolean;
  cTSToken: vscode.CancellationToken;
  error?: DetailedError;
};

export const parallelQueryActorLogic = fromPromise(async ({ input }: { input: ParallelQueryActorLogicInputT }) => {
  input.logger.log(`parallelQueryActorLogic called`, LogLevel.Debug);
  let cancelled: boolean = false;
  let success: boolean = false;
  // let results: ParallelQueryActorLogicResultsT = {} as ParallelQueryActorLogicResultsT;
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (input.cTSToken.isCancellationRequested) {
    return { cancelled: true, cTSToken: input.cTSToken } as ParallelQueryActorLogicOutputT;
  }
  // if the input queryString is undefined or '', return an error
  if (!input.queryString || input.queryString === '') {
    return {
      //results: results,
      cancelled: false,
      cTSToken: input.cTSToken,
      error: new DetailedError('queryString is not defined or empty'),
    } as ParallelQueryActorLogicOutputT;
  }
  // passes all checks so return and continue
  // ToDo: is this the appropriate place to get the ActorReferences for all the things needed for te Promise.All
  return { cancelled: cancelled, cTSToken: input.cTSToken } as ParallelQueryActorLogicOutputT;
});

// **********************************************************************************************************************

export type SingleQueryActorLogicInputT = ParallelQueryActorLogicInputT & { queryEngineName: QueryEngineNamesEnum };

export type SingleQueryActorLogicOutputT = {
  response?: string;
  error?: DetailedError;
  cancelled: boolean;
};

export type FetchingFromSingleQueryEngineOutputT = SingleQueryActorLogicOutputT;

// ToDo: Wish I could add a third type parameter to fromPromise to make it generic on the QueryEngineNamesEnum type
export const fetchingFromQueryEngineActorLogic = fromPromise<SingleQueryActorLogicOutputT, SingleQueryActorLogicInputT>(
  async ({ input }: { input: SingleQueryActorLogicInputT }) => {
    input.logger.log(`singleQueryActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      return { cancelled: true } as SingleQueryActorLogicOutputT;
    }
    let response: string;
    response = 'ResponseFrom QueryEnginePlaceholder';
    // ToDo: use the queryService to handle the query to a queryEngine
    await input.queryService.sendQueryAsync(input.queryString, input.queryEngineName, input.cTSToken);
    return { response: response, cancelled: false } as SingleQueryActorLogicOutputT;
  },
);

// **********************************************************************************************************************

export const fetchingFromBardActorLogic = fromPromise<SingleQueryActorLogicOutputT, SingleQueryActorLogicInputT>(
  async ({ input }: { input: SingleQueryActorLogicInputT }) => {
    input.logger.log(`fetchingFromBardActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      input.logger.log(`fetchingFromBardActorLogic leaving on entrance with cancelled = true`, LogLevel.Debug);
      return { cancelled: true } as SingleQueryActorLogicOutputT;
    }
    let _qs = input.queryString;
    let response: string;
    response = 'Response From QueryEngine Placeholder';
    // use the queryService to handle the query to the Bard queryEngine
    try {
      // ToDo: use the queryService to handle the query to a queryEngine
    } catch (e) {
      HandleError(e, 'queryMachine', 'fetchingFromBardActorLogic', 'failed calling queryService.sendQueryToBard');
    }
    // always test the cancellation token after returning from an await to see if the function being awaited has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      input.logger.log(`fetchingFromBardActorLogic leaving after awaitwith cancelled = true`, LogLevel.Debug);
      return { cancelled: true } as SingleQueryActorLogicOutputT;
    }
    input.logger.log(
      `fetchingFromBardActorLogic leaving with response = ${response}, cancelled = false`,
      LogLevel.Debug,
    );
    return { response: response, cancelled: false } as SingleQueryActorLogicOutputT;
  },
);

// **********************************************************************************************************************

export type WaitingForAllActorLogicOutputT = {
  responses?: { [key in QueryEngineNamesEnum]: string };
  errors?: { [key in QueryEngineNamesEnum]: DetailedError[] };
  cancelled: boolean;
};

export type WaitingForAllActorLogicInputT = {
  logger: ILogger;
  actorCollection: { [key in QueryEngineNamesEnum]: ActorRef<any, any> };
  cTSToken: vscode.CancellationToken;
};

export const waitingForAllActorLogic = fromPromise<WaitingForAllActorLogicOutputT, WaitingForAllActorLogicInputT>(
  async ({ input }: { input: WaitingForAllActorLogicInputT }) => {
    input.logger.log(`waitingForAllActorLogic`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      input.logger.log(`waitingForAllActorLogic leaving on entrance with cancelled = true`, LogLevel.Debug);
      return { cancelled: true } as WaitingForAllActorLogicOutputT;
    }
    const activeQueryEngineActorRefs = input.actorCollection;
    // wait for all the promises to resolve
    // await Promise.all(
    //   input.queryEngineNames.map((queryEngineName) =>
    //     fetchingFromQueryEngineActorLogic({ input: { ...input, queryEngineName: queryEngineName } }),
    //   ),
    // );
    // always test the cancellation token after returning from an await to see if the function being awaited has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      input.logger.log(`waitingForAllActorLogic leaving after await with cancelled = true`, LogLevel.Debug);
      return { cancelled: true } as SingleQueryActorLogicOutputT;
    }

    return { cancelled: false } as WaitingForAllActorLogicOutputT;
  },
);
