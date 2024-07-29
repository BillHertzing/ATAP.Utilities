import { createMachine } from "xstate";

import { randomOutcome } from "@Utilities/index"; // ToDo: replace with a mocked iQueryService instead of using this import
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

import { IQueryService } from "@QueryService/index";

import { IQueryFragmentCollection } from "@ItemWithIDs/index";

import { DetailedError, HandleError } from "@ErrorClasses/index";

interface IInput {
  logger: ILogger;
}
interface IContext extends IInput {}
interface IOutput {}
type EventsT = { type: "START" } | { type: "FINISH" };

export const primaryMachine = setup({
  types: {} as {
    context: IContext;
    input: IInput;
    output: IOutput;
    events: EventsT;
  },
}).createMachine({
  // cspell:disable
  /** @xstate-layout N4IgpgJg5mDOIC5gF8A0IB2B7CdGgwEMBbMAeQDN8QAHLWASwBcGsNqAPRAWgDZ0Anj17I0mEuQoA6BhmYNCAGwDKTQkzDU6jFm06IALACZBiABwBGKQAYDAVgsBmXkYDsjs7YtHRooA */
  // cspell:enable
  context: ({ input }) => ({
    logger: new Logger(input.logger, "primaryMachine"),
  }),
  output: () => ({}),
  id: "primaryMachine",
  initial: "initialState",
  states: {
    initialState: {
      entry: ({ context }) => {
        context.logger.log("Enter initialState", LogLevel.Info);
      },
      exit: ({ context }) => {
        context.logger.log("Exit initialState", LogLevel.Info);
      },
      on: {
        START: "doneState",
      },
    },
    doneState: {
      type: "final",
      entry: ({ context }) => {
        context.logger.log("Enter doneState", LogLevel.Info);
      },
    },
  },
});
