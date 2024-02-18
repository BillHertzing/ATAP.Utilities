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

export type GatheringActorLogicInputT = {
  logger: ILogger;
  queryCTSToken: vscode.CancellationToken;
  queryFragmentCollection: IQueryFragmentCollection;
};

export type GatheringActorLogicOutputT = {
  queryString: string;
  queryCancelled: boolean;
  queryError?: Error;
};

export const gatheringActorLogic = fromPromise<GatheringActorLogicOutputT, GatheringActorLogicInputT>(
  async ({ input }: { input: GatheringActorLogicInputT }) => {
    let _queryString = '';
    let _queryFragmentCollection: IQueryFragmentCollection;
    input.logger.log(`gatheringActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.queryCTSToken.isCancellationRequested) {
      input.logger.log(`gatheringActorLogic leaving with cancelled = true`, LogLevel.Debug);
      return {
        queryString: '',
        queryCancelled: true,
      } as GatheringActorLogicOutputT;
    }
    _queryFragmentCollection = input.queryFragmentCollection;
    // if the queryFragmentCollection is not defined or is empty, then return an error
    if (!_queryFragmentCollection || _queryFragmentCollection.value.length === 0) {
      throw new Error('queryFragmentCollection is not defined or empty');
    }
    // switch on the fragmentKind and collect accordingly
    _queryFragmentCollection.value.forEach((element) => {
      // test for cancellation each time around the loop
      // if (input.queryCTSToken.isCancellationRequested) {
      //   input.logger.log(`gatheringActorLogic leaving with cancelled = true`, LogLevel.Debug);
      //   return {
      //     queryString: '',
      //     cancelled: true,
      //     cTSToken: input.cTSToken,
      //   } as GatheringActorLogicOutputT;
      // }
      switch (element.value.kindOfFragment) {
        case QueryFragmentEnum.StringFragment:
          _queryString += element.value.value;
          break;
        case QueryFragmentEnum.FileFragment:
          //ToDo: Implement FileFragment
          //queryString += element.value;
          break;
        default:
          throw new Error(`Unhandled queryFragment.kindOfFragment: ${element.value.kindOfFragment}`);
      }
    });
    input.logger.log(`gatheringActorLogic leaving with queryString= ${_queryString}`, LogLevel.Debug);
    return {
      queryString: _queryString,
      queryCancelled: false,
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
  if (input.queryCTSToken?.isCancellationRequested) {
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
  queryResponse?: string;
  queryError?: Error;
  queryCancelled: boolean;
};

export type FetchingFromSingleQueryEngineOutputT = SingleQueryActorLogicOutputT;

// ToDo: Wish I could add a third type parameter to fromPromise to make it generic on the QueryEngineNamesEnum type
export const fetchingFromQueryEngineActorLogic = fromPromise<SingleQueryActorLogicOutputT, SingleQueryActorLogicInputT>(
  async ({ input }: { input: SingleQueryActorLogicInputT }) => {
    input.logger.log(`singleQueryActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.queryCTSToken?.isCancellationRequested) {
      return { queryCancelled: true } as SingleQueryActorLogicOutputT;
    }
    let queryResponse: string;
    queryResponse = 'ResponseFrom QueryEnginePlaceholder';
    // ToDo: use the queryService to handle the query to a queryEngine
    await input.queryService.sendQueryAsync(input.queryString, input.queryEngineName, input.cTSToken);
    return { queryResponse: queryResponse, queryCancelled: false } as SingleQueryActorLogicOutputT;
  },
);

// **********************************************************************************************************************
function randomOutcome(strToReturn: string): Promise<{ isCancelled: boolean; result?: string }> {
  return new Promise((resolve, reject) => {
    const randomNumber = Math.random();

    if (randomNumber < 0.3) {
      // 30% chance to resolve with "TaskSucceeded"
      resolve({ isCancelled: false, result: strToReturn });
    } else if (randomNumber >= 0.3 && randomNumber < 0.6) {
      // Additional 30% chance to resolve with isCancelled = true
      resolve({ isCancelled: true });
    } else {
      // Remaining 40% chance to throw an error
      reject(new Error('An error occurred'));
    }
  });
}

// **********************************************************************************************************************

export const fetchingFromBardActorLogic = fromPromise<SingleQueryActorLogicOutputT, SingleQueryActorLogicInputT>(
  async ({ input }: { input: SingleQueryActorLogicInputT }) => {
    input.logger.log(`fetchingFromBardActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.queryCTSToken?.isCancellationRequested) {
      input.logger.log(`fetchingFromBardActorLogic leaving on entrance with cancelled = true`, LogLevel.Debug);
      return { queryCancelled: true } as SingleQueryActorLogicOutputT;
    }
    let _qs = input.queryString;
    let _queryResponse: { result?: string; isCancelled: boolean };
    // use the queryService to handle the query to the Bard queryEngine
    try {
      _queryResponse = await randomOutcome('Response FromBard');
      // ToDo: use the queryService to handle the query to a queryEngine
    } catch (e) {
      // Rethrow the error with a more detailed error message
      HandleError(e, 'queryXXX', 'fetchingFromBardActorLogic', 'failed calling queryService.sendQueryToBard');
    }
    // always test the cancellation token after returning from an await to see if the function being awaited was cancelled
    if (input.queryCTSToken?.isCancellationRequested) {
      input.logger.log(
        `fetchingFromBardActorLogic leaving after await queryService.sendQueryToBard with cancelled = true`,
        LogLevel.Debug,
      );
      return { queryCancelled: true } as SingleQueryActorLogicOutputT;
    }
    input.logger.log(
      `fetchingFromBardActorLogic leaving with response = ${_queryResponse.result}, cancelled = false`,
      LogLevel.Debug,
    );
    return { queryResponse: _queryResponse.result, queryCancelled: false } as SingleQueryActorLogicOutputT;
  },
);

// **********************************************************************************************************************

export type WaitingForAllActorLogicOutputT = {
  queryResponses?: { [key in QueryEngineNamesEnum]: string };
  queryErrors?: { [key in QueryEngineNamesEnum]: DetailedError[] };
  queryCancelled: boolean;
};

export type WaitingForAllActorLogicInputT = {
  logger: ILogger;
  queryActorCollection: { [key in QueryEngineNamesEnum]: ActorRef<any, any> };
  queryCTSToken: vscode.CancellationToken;
  //data: IData;
};

export const waitingForAllActorLogic = fromPromise<WaitingForAllActorLogicOutputT, WaitingForAllActorLogicInputT>(
  async ({ input }: { input: WaitingForAllActorLogicInputT }) => {
    input.logger.log(`waitingForAllActorLogic`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.queryCTSToken.isCancellationRequested) {
      input.logger.log(`waitingForAllActorLogic leaving on entrance with cancelled = true`, LogLevel.Debug);
      return { queryCancelled: true } as WaitingForAllActorLogicOutputT;
    }
    const activeQueryEngineActorRefs = input.queryActorCollection;
    let _allActorResponse: { result?: string; isCancelled: boolean };
    try {
      // wait for all the promises to resolve
      // await Promise.allSettled(
      //   input.queryEngineNames.map((queryEngineName) =>
      //     fetchingFromQueryEngineActorLogic({ input: { ...input, queryEngineName: queryEngineName } }),
      //   ),
      // );

      _allActorResponse = await randomOutcome('Response FromBard');
    } catch (e) {
      // Rethrow the error with a more detailed error message
      input.logger.log(`waitingForAllActorLogic produced an error`, LogLevel.Debug);
      HandleError(e, 'queryXXX', 'waitingForAllActorLogic', 'failed awaiting all promises to settle');
    }
    // always test the cancellation token after returning from an await to see if the function being awaited has already been cancelled
    if (input.queryCTSToken.isCancellationRequested || _allActorResponse.isCancelled) {
      input.logger.log(`waitingForAllActorLogic leaving after await with cancelled = true`, LogLevel.Debug);
      return { queryCancelled: true } as WaitingForAllActorLogicOutputT;
    }

    return { queryCancelled: false } as WaitingForAllActorLogicOutputT;
  },
);
