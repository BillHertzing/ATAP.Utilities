import { LogLevel, ILogger, Logger } from "@Logger/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";

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
  IQuerySingleEngineActorInput,
  IQuerySingleEngineActorOutput,
  IQuerySingleEngineMachineInput,
  IQuerySingleEngineMachineOutput,
  IQuerySingleEngineMachineContext,
  IQuerySingleEngineMachineNotifyCompleteActionParameters,
  IQuerySingleEngineMachineDoneEventPayload,
  QuerySingleEngineMachineCompletionEventsUnionT,
  QuerySingleEngineMachineAllEventsUnionT,
} from "./querySingleEngineTypes";

import { randomOutcome } from "@Utilities/index"; // ToDo: replace with a mocked iQueryService instead of using this import

// *********************************************************************************************************************
// actor logic definition for the querySingleEngineActor
export const querySingleEngineActor = fromPromise<
  IQuerySingleEngineActorOutput,
  IQuerySingleEngineActorInput
>(async ({ input }: { input: IQuerySingleEngineActorInput }) => {
  input.logger.log(`querySingleEngineActor called`, LogLevel.Debug);
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (input.cTSToken?.isCancellationRequested) {
    return {
      queryEngineName: input.queryEngineName,
      isCancelled: true,
      response: undefined,
      errorMessage: undefined,
    } as IQuerySingleEngineActorOutput;
  }
  let _qs = input.queryString;
  let _queryResponse: { result?: string; isCancelled: boolean };
  // use the queryService to handle the query (with resilience) to a queryEngine
  try {
    _queryResponse = await randomOutcome("Response FromRandom");
    // ToDo: use the queryService to handle the query (with resilience) to a queryEngine. For testing and development, pass an instance of queryService that uses a mock inside the sendQueryAsync
    // _queryResponse = await input.queryService.sendQueryAsync(
    //   input.queryString as string,
    //   input.queryEngineName,
    //   input.cTSToken,
    // );
  } catch (e) {
    // ToDo: reject the promise if the queryService.sendQueryAsync fails, and put the error details in the error event payload
    // Rethrow the error with a more detailed error message
    HandleError(
      e,
      "queryXXX",
      "querySingleEngineActor",
      `Failed: await queryService.sendQueryAsync (queryEngineName: ${input.queryEngineName}) returned with an error`,
    );
  }
  // always test the cancellation token after returning from an await to see if the function being awaited was cancelled
  if (input.cTSToken?.isCancellationRequested) {
    input.logger.log(
      `querySingleEngineActor Cancelled: await queryService.sendQueryAsync (queryEngineName: ${input.queryEngineName}) returned with cancelled = true`,
      LogLevel.Debug,
    );
    return {
      queryEngineName: input.queryEngineName,
      isCancelled: true,
      response: undefined,
      errorMessage: undefined,
    } as IQuerySingleEngineActorOutput;
  }
  input.logger.log(
    `querySingleEngineActor Success: await queryService.sendQueryAsync (queryEngineName: ${input.queryEngineName}) returned with response = ${_queryResponse.result}, cancelled = false`,
    LogLevel.Debug,
  );
  return {
    queryEngineName: input.queryEngineName,
    queryResponse: _queryResponse.result,
    isCancelled: false,
    errorMessage: undefined,
  } as IQuerySingleEngineActorOutput;
});
