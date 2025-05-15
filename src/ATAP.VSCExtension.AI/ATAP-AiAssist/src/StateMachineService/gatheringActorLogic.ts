// ToDo: replace with a mocked IQueryService instead of using this importimport { randomOutcome } from "@Utilities/index";
import * as vscode from "vscode";
import { LogLevel, ILogger, Logger } from "@Logger/index";

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
  QueryFragmentEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
} from "@BaseEnumerations/index";
import { IQueryFragmentCollection } from "@ItemWithIDs/index";

import { IGatheringActorInput, IGatheringActorOutput } from "./gatheringTypes";

// *********************************************************************************************************************
// actor logic for the gatheringActor

export const gatheringActor = fromPromise<
  IGatheringActorOutput,
  IGatheringActorInput
>(async ({ input }: { input: IGatheringActorInput }) => {
  const logger = new Logger(input.logger, "gatheringActor");

  let _queryString = "";
  let _queryFragmentCollection: IQueryFragmentCollection;
  logger.log("entry", LogLevel.Debug);
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (input.cTSToken.isCancellationRequested) {
    logger.log("leaving with cancelled = true", LogLevel.Debug);
    return {
      queryString: "",
      isCancelled: true,
    } as IGatheringActorOutput;
  }
  _queryFragmentCollection = input.queryFragmentCollection;
  // if the queryFragmentCollection is not defined or is empty, then return an error
  if (
    !_queryFragmentCollection ||
    _queryFragmentCollection.value.length === 0
  ) {
    throw new Error(
      `${logger.scope} queryFragmentCollection is not defined or empty`,
    );
  }
  // switch on the fragmentKind and collect accordingly
  _queryFragmentCollection.value.forEach((element) => {
    // test for cancellation each time around the loop
    // if (input.queryCTSToken.isCancellationRequested) {
    //   logger.log("leaving with cancelled = true", LogLevel.Debug);
    //   return {
    //     queryString: "",
    //     isCancelled: true,
    //   } as GatheringActorOutputT;
    // }
    switch (element.value.kindOfFragment) {
      case QueryFragmentEnum.StringFragment:
        _queryString += element.value.value;
        // ToDo: test for cancellation after every N concatenations (an async operation resets the counter to 0)
        break;
      case QueryFragmentEnum.FileFragment:
        //ToDo: Implement FileFragment
        //queryString += element.value;
        // test for cancellation after any async operation
        if (input.cTSToken.isCancellationRequested) {
          logger.log("leaving with cancelled = true", LogLevel.Debug);
          return {
            queryString: "",
            isCancelled: true,
          } as IGatheringActorOutput;
        }
        break;
      default:
        const _errorMessage = `Received unknown queryFragment.kindOfFragment: ${element.value.kindOfFragment}`;
        logger.log(_errorMessage, LogLevel.Error);
        throw new Error(`${logger.scope} ` + _errorMessage);
    }
  });
  logger.log(`leaving with queryString = ${_queryString}`, LogLevel.Debug);
  return {
    queryString: _queryString,
    isCancelled: false,
  } as IGatheringActorOutput;
});
