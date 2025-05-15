import * as vscode from "vscode";
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

import { IQueryService } from "@QueryService/index";

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

import { querySingleEngineActor } from "./querySingleEngineActorLogic";

// *********************************************************************************************************************
// Machine definition for the querySingleEngineMachine

export const querySingleEngineMachine = setup({
  types: {} as {
    context: IQuerySingleEngineMachineContext;
    input: IQuerySingleEngineMachineInput;
    output: IQuerySingleEngineMachineOutput;
    events: QuerySingleEngineMachineAllEventsUnionT;
    children: {
      querySingleEngineActor: "querySingleEngineActor";
    };
  },
  actors: {
    querySingleEngineActor: querySingleEngineActor,
  },
  actions: {
    debugMachineContext: ({ context, event }) => {
      context.logger.log(
        `debug QuerySingleEngineMachineContext, context.queryEngineName: ${context.queryEngineName},   context.queryString: ${context.queryString}, context.response: ${context!.response}, context.isCancelled: ${context.isCancelled}`,
        LogLevel.Debug,
      );
    },
    assignQuerySingleEngineActorDoneOutputToQueryMachineContext: assign({
      response: ({ context, spawn, event, self }) => {
        assertEvent(event, "xstate.done.actor.querySingleEngineActor");
        return event.output.response;
      },
      isCancelled: ({ context, spawn, event, self }) => {
        assertEvent(event, "xstate.done.actor.querySingleEngineActor");
        return event.output.isCancelled;
      },
    }),
    assignQuerySingleEngineActorErrorOutputToQueryMachineContext: assign({
      response: undefined,
      isCancelled: false,
      errorMessage: ({ context, event }) => {
        assertEvent(event, "xstate.error.actor.querySingleEngineActor");
        return event.message;
      },
    }),
    // the sendTo(...) is a special action that can go wherever an action can go
    //   it has two arguments, either or both of which can be a lambda that closes over their params argument
    //   The first lambda returns an actorRef
    //   The second lambda returns an event, thus satisfying the two argument types that sendTo expects
    notifyCompleteAction: sendTo(
      (_, params: IQuerySingleEngineMachineNotifyCompleteActionParameters) => {
        const logger = new Logger(
          params.logger,
          "notifyCompleteAction.destinationSelectorLambda",
        );
        logger.log(
          `sendToTargetActorRef is ${params.sendToTargetActorRef.id}`,
          LogLevel.Debug,
        );
        return params.sendToTargetActorRef;
      },
      (_, params: IQuerySingleEngineMachineNotifyCompleteActionParameters) => {
        const logger = new Logger(
          params.logger,
          "notifyCompleteAction.eventSelectorLambda",
        );
        logger.log(
          `eventCausingTheTransitionIntoOuterDoneState is ${params.eventCausingTheTransitionIntoOuterDoneState.type}`,
          LogLevel.Debug,
        );
        // discriminate on event that triggers this action and send the appropriate completion notification event to the parent
        let _eventToSend:
          | {
              type: "QUERY_SINGLE_ENGINE_MACHINE.DONE";
              payload: IQuerySingleEngineMachineDoneEventPayload;
            }
          | { type: "DISPOSE.COMPLETE" };
        switch (params.eventCausingTheTransitionIntoOuterDoneState.type) {
          case "xstate.done.actor.querySingleEngineActor":
          case "xstate.error.actor.querySingleEngineActor":
            _eventToSend = {
              type: "QUERY_SINGLE_ENGINE_MACHINE.DONE",
              payload: {
                queryEngineName: params.queryEngineName,
              } as IQuerySingleEngineMachineDoneEventPayload,
            };
            break;
          case "xstate.done.actor.disposeActor":
          case "xstate.error.actor.disposeActor": // ToDo: ensure the error from disposeActor is handled
            _eventToSend = { type: "DISPOSE.COMPLETE" };
            break;
          default:
            // since we don't know what event causes the error, we don't know that it has a .type property,
            //   so use square brackets to attempt to access the property
            const _eventType =
              params.eventCausingTheTransitionIntoOuterDoneState["type"];
            let _errorMessage: string;
            if (_eventType == undefined) {
              _errorMessage = `notifyCompleteAction received an event without a type`;
            } else {
              _errorMessage = `notifyCompleteAction received an unexpected event type: ${_eventType}`;
            }
            logger.log(_errorMessage, LogLevel.Error);
            throw new Error(`${logger.scope}` + _errorMessage);
        }
        logger.log(
          `notifyCompleteAction, in the event selector lambda, _eventToSend is ${_eventToSend.type}`,
          LogLevel.Debug,
        );
        return _eventToSend;
      },
    ),
    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposingStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      // Todo: add code to send the DISPOSE.START to all spawned child machine(s) so that they can free any resources
      // if this machine is waiting on an async function to return data, we expect that the any calling machine
      //   will have set the cancellationTokenSource token to cancelled, so that the async function will return early
      // ToDo: add code to dispose of any resources allocated in this machine
    },
    disposeCompleteStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposeCompleteStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
    },
  },
}).createMachine({
  id: "querySingleEngineMachine",
  context: ({ input }) => ({
    logger: new Logger(input.logger, "querySingleEngineMachine"),
    parent: input.parent,
    queryService: input.queryService,
    queryString: "",
    queryEngineName: input.queryEngineName,
    cTSToken: input.cTSToken,
    isCancelled: false,
  }),
  output: ({ context }) => ({
    queryEngineName: context.queryEngineName,
    response: context.response,
    isCancelled: context.isCancelled,
    errorMessage: context.errorMessage,
  }),
  initial: "startedState",
  states: {
    startedState: {
      entry: ({ context }) => {
        context.logger.log(
          `querySingleEngineMachineStartedState entry`,
          LogLevel.Debug,
        );
      },
      type: "parallel",
      states: {
        operationState: {
          // This state handles the main operation of the machine. First of two parallel states
          initial: "querySingleEngineState",
          states: {
            querySingleEngineState: {
              description:
                "send a query to a single queryAgent and collect the result",
              invoke: {
                id: "querySingleEngineActor",
                src: "querySingleEngineActor",
                input: ({ context }) => ({
                  logger: context.logger,
                  queryService: context.queryService,
                  queryString: context.queryString,
                  queryEngineName: context.queryEngineName,
                  cTSToken: context.cTSToken,
                }),
                onDone: {
                  target: "doneState",
                  // set the context for response and isCancelled
                  actions:
                    "assignQuerySingleEngineActorDoneOutputToQueryMachineContext",
                },
                onError: {
                  // set the context for errorMessage and isCancelled
                  target: "errorState",
                  actions:
                    "assignQuerySingleEngineActorErrorOutputToQueryMachineContext",
                },
              },
            },
            errorState: {
              description:
                "querySingleEngineMachine encountered an error. Attempt remediation else transition to the outer doneState",
              // ToDO: add code to attempt to remediate the error, otherwise transition to outer doneState
              always: "#querySingleEngineMachine.doneState",
            },
            doneState: {
              description:
                "querySingleEngineMachine is done. transition to the outer doneState",
              always: "#querySingleEngineMachine.doneState",
            },
          },
        },
        disposeState: {
          // 2nd parallel state. This state can be transitioned to from any state
          initial: "inactiveState",
          states: {
            inactiveState: {
              on: {
                "DISPOSE.START": "disposingState",
              },
            },
            disposingState: {
              // disposingStateEntryAction will dispose of any allocated resources,
              //   ToDo need data structures and code to support multiple active child machines
              //   call DISPOSE.START for any active child machines
              //   wait for all child machines to return a DISPOSE.COMPLETE event
              //   when all child machines have disposed of their resources, send a DISPOSE.COMPLETE event to the parent
              entry: "disposingStateEntryAction",
              on: {
                "DISPOSE.COMPLETE": {
                  // ToDo: add a guard to ensure that all child machines have returned a DISPOSE.COMPLETE event
                  target: "disposeCompleteState",
                },
              },
            },
            disposeCompleteState: {
              entry: "disposeCompleteStateEntryAction",
              always: "#querySingleEngineMachine.doneState",
            },
          },
        },
      },
    },
    doneState: {
      description: "the outer doneState for the querySingleEngineMachine",
      type: "final",
      entry: [
        // call the notifyCompleteAction here, setting the value of the params' properties to values
        //   pulled from the context and the event that entered the outer doneState.
        //   When notifyCompleteAction is called, the lambda's that are supplied as arguments to sendTo
        //   in the action's definition will use the values that are set into the params here when the lambdas run
        {
          type: "notifyCompleteAction",
          params: ({ context, event }) =>
            ({
              logger: context.logger,
              sendToTargetActorRef: context.parent,
              eventCausingTheTransitionIntoOuterDoneState: event,
              queryEngineName: context.queryEngineName,
            }) as IQuerySingleEngineMachineNotifyCompleteActionParameters,
        },
        "debugMachineContext",
      ],
    },
  },
});
