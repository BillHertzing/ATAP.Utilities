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
  IQuerySingleEngineMachineContext,
  IQuerySingleEngineMachineInput,
  IQuerySingleEngineMachineOutput,
  IQuerySingleEngineMachineNotifyCompleteActionParameters,
  QuerySingleEngineMachineCompletionEventsT,
  QuerySingleEngineMachineAllEventsT,
  IQuerySingleEngineMachineDoneEventPayload,
  IQuerySingleEngineMachineActorLogicInput,
  IQuerySingleEngineMachineActorLogicOutput,
} from "./querySingleEngineMachineTypes";

import { randomOutcome } from "@Utilities/index"; // ToDo: replace with a mocked iQueryService instead of using this import

// **********************************************************************************************************************
// actor logic definition for the querySingleEngineMachineActorLogic
export const querySingleEngineMachineActorLogic = fromPromise<
  IQuerySingleEngineMachineActorLogicOutput,
  IQuerySingleEngineMachineActorLogicInput
>(async ({ input }: { input: IQuerySingleEngineMachineActorLogicInput }) => {
  input.logger.log(`querySingleEngineMachineActorLogic called`, LogLevel.Debug);
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (input.cTSToken?.isCancellationRequested) {
    return { isCancelled: true } as IQuerySingleEngineMachineActorLogicOutput;
  }
  let _qs = input.queryString;
  let _queryResponse: { result?: string; isCancelled: boolean };
  // use the queryService to handle the query to the Bard queryEngine
  try {
    _queryResponse = await randomOutcome("Response FromBard");
    // ToDo: use the queryService to handle the query to a queryEngine. For testing and development, pass an instance of queryService that uses a mock inside the sendQueryAsync
    // _queryResponse = await input.queryService.sendQueryAsync(
    //   input.queryString as string,
    //   input.queryEngineName,
    //   input.cTSToken,
    // );
  } catch (e) {
    // Rethrow the error with a more detailed error message
    HandleError(
      e,
      "queryXXX",
      "querySingleEngineMachineActorLogic",
      "failed calling queryService.sendQueryAsync",
    );
  }
  // always test the cancellation token after returning from an await to see if the function being awaited was cancelled
  if (input.cTSToken?.isCancellationRequested) {
    input.logger.log(
      `querySingleEngineMachineActorLogic leaving after await queryService.sendQueryAsync with cancelled = true`,
      LogLevel.Debug,
    );
    return { isCancelled: true } as IQuerySingleEngineMachineActorLogicOutput;
  }
  input.logger.log(
    `querySingleEngineMachineActorLogic leaving with response = ${_queryResponse.result}, cancelled = false`,
    LogLevel.Debug,
  );
  return {
    queryEngineName: input.queryEngineName,
    queryResponse: _queryResponse.result,
    isCancelled: false,
  } as IQuerySingleEngineMachineActorLogicOutput;
});
