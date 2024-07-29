import * as vscode from "vscode";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";
import { assertEvent, assign, fromPromise, sendTo, setup } from "xstate";
import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  QueryFragmentEnum,
  QuickPickEnumeration,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
} from "@BaseEnumerations/index";
import {
  QuickPickMappingKeysT,
  IQuickPickTypeMapping,
  QuickPickValueT,
  IQuickPickActorInput,
  IQuickPickActorOutput,
  QuickPickActorCompletionEventsUnionT,
  IAssignQuickPickActorOutputToParentContextActionParameters,
  IQuickPickMachineInput,
  IQuickPickMachineOutput,
  IQuickPickMachineContext,
  IQuickPickMachineNotifyCompleteActionParameters,
  QuickPickMachineCompletionEventsUnionT,
  QuickPickMachineAllEventsUnionT,
} from "./quickPickTypes";
import { quickPickActorLogic } from "./quickPickActorLogic";
// **********************************************************************************************************************
// Helper function for creating a quickPickValue
// Used by primary machine when spawning the quickPickMachine
// Used by the quickPickMachine when creating the pickValue to return
export function createQuickPickValue<K extends QuickPickMappingKeysT>(
  type: K,
  value?: IQuickPickTypeMapping[K],
): QuickPickValueT {
  return [type, value] as QuickPickValueT;
}
// *********************************************************************************************************************
// Machine definition for the quickPickMachine
export const quickPickMachine = setup({
  types: {} as {
    context: IQuickPickMachineContext;
    input: IQuickPickMachineInput;
    output: IQuickPickMachineOutput;
    events: QuickPickMachineAllEventsUnionT;
  },
  actors: {
    quickPickActor: quickPickActorLogic,
  },
  actions: {
    debugMachineContext: ({ context, event }) => {
      context.logger.log(
        `debugQuickPickMachineContext, context.pickValue: ${context.pickValue}, context.isCancelled: ${context.isCancelled} context.isLostFocus: ${context.isLostFocus}`,
        LogLevel.Debug,
      );
    },
    assignQuickPickActorOutputToParentContext: assign(
      ({ event }) => {
        assertEvent(event, "xstate.done.actor.quickPickActor");
        return {
          pickValue: event.output.pickValue,
          isCancelled: event.output.isCancelled,
          isLostFocus: event.output.isLostFocus,
        };
      },
    ),
    // assignQuickPickActorOutputToParentContext2: assign(
    //   _,
    //   params: IAssignQuickPickActorOutputToParentContextActionParameters,
    // ) => {
    //         const logger = new Logger(
    //         params.logger,
    //         "assignQuickPickActorOutputToParentContext",
    //       );

    //   logger.log(
    //     `pickValue= ${params.pickValue}, isCancelled= ${params.isCancelled}, isLostFocus= ${params.isLostFocus}, errorMessage= ${params.errorMessage!}`,
    //     LogLevel.Debug,
    //   );
    //   return assign({
    //     pickValue: params.pickValue,
    //     isCancelled: params.isCancelled,
    //     isLostFocus: params.isLostFocus,
    //     errorMessage: params.errorMessage,
    //   });
    // },
    assignQuickPickActorErrorOutputToQuickPickMachineContext: assign(
      ({ context, event }) => {
        assertEvent(event, "xstate.error.actor.quickPickActor");
        return {
          pickValue: createQuickPickValue(context.pickValue[0], undefined),
          isCancelled: false,
          isLostFocus: false,
          errorMessage: event.message,
        };
      },
    ),
    // the sendTo(...) is a special action that can go wherever an action can go
    //   it has two arguments, either or both of which can be a lambda that closes over their params argument
    //   The first lambda returns an actorRef
    //   The second lambda returns an event, thus satisfying the two argument types that sendTo expects
    notifyCompleteAction: sendTo(
      (_, params: IQuickPickMachineNotifyCompleteActionParameters) => {
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
      (_, params: IQuickPickMachineNotifyCompleteActionParameters) => {
        const logger = new Logger(
          params.logger,
          "notifyCompleteAction.eventSelectorLambda",
        );
        logger.log(
          `eventCausingTheTransitionIntoOuterDoneState is ${params.eventCausingTheTransitionIntoOuterDoneState.type}`,
          LogLevel.Debug,
        );
        // discriminate on event that triggers this action and send the appropriate notification event to the parent
        let _eventToSend:
          | { type: "QUICKPICK_MACHINE.DONE" }
          | { type: "DISPOSE.COMPLETE" };
        switch (params.eventCausingTheTransitionIntoOuterDoneState.type) {
          case "xstate.done.actor.quickPickActor":
          case "xstate.error.actor.quickPickActor":
            _eventToSend = { type: "QUICKPICK_MACHINE.DONE" };
            break;
          case "xstate.done.actor.disposeActor":
          case "xstate.error.actor.disposeActor": // ToDo: ensure the error from disposeActor is handled
            _eventToSend = { type: "DISPOSE.COMPLETE" };
            break;
          // ToDo: add case legs for the two error events that come from the quickPickActor and quickPickDisposeActor
          default:
            // since we don't know what event causes the error, we don't know that it has a .type property,
            //   so use square brackets to attempt to access the property
            const _eventType =
              params.eventCausingTheTransitionIntoOuterDoneState["type"];
            let _errorMessage: string;
            if (_eventType == undefined) {
              _errorMessage = `Received an event without a type`;
            } else {
              _errorMessage = `Received an unexpected event type: ${_eventType}`;
            }
            logger.log(_errorMessage, LogLevel.Error);
            throw new Error(`${logger.scope}` + _errorMessage);
        }
        logger.log(`_eventToSend is ${_eventToSend.type}`, LogLevel.Debug);
        return _eventToSend;
      },
    ),
    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposingStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      // Todo: add code to send the DISPOSE.START to all spawned child machine(s) so that they can free any resources
      // this machine does not spawn any child machine(s), so there is no need to send any DISPOSE.START events
      // ToDo: if this machine is waiting on user input, close the input dialog and set lostFocus to true
      // ToDo: if this machine is waiting on a promise, cancel the promise
    },
    disposeCompleteStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposeCompleteStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      sendTo(context.parent, {
        type: "DISPOSE.COMPLETE",
      });
    },
  },
}).createMachine({
  // cspell:disable
  /** @xstate-layout N4IgpgJg5mDOIC5QEcCuBLAxgawApewFkBDTAC3QDswA6WAF2ICd7IBlR1mgewAcwmxeum6UOQ2mgL4c41gGIIo2lQBu3bJIw4Z2AIKZ63JgG0ADAF1EoXt1jpho6yAAeiALQBGABzeaAVn8AJgBOADYAFk8Qs38wkJCggBoQAE8PTzM-AGZc7LMEoKD-XM8ggF9ylKkdAhJyKloGZlYIOVo+ASERMU4taQJ2+QEmYxpeABshADNjAFsaGrwCAyNTS2dbe0dKZzcEaIB2AOzvT08I4JCIkLiwlPSELyyaPPzC4tKKqpAl3XqKNQ6IwWOw+jx+IIdu0aCNjENzFYkCAtg4entENl-GYaBFvLdPIcggUImF-CEHohErizBFQt5-J5sp4yWZvtVtMscADGsCWmCJBCutDwVRqEwACLKBEbZGonYYg7+Y4RCLZELZQ6RMKHRm6ykIYo4plBbI3Mnec1ZSocgbc0iApog1owiDoWBbMAwqikYSqL19eQSgCSbFwAHk2ABRAD6bAAKnoAErxxGbOxopzI-aHBI0Ymmswsy7ZIJkg3uYnZGi+ELF4mHesRG2-Tn-B285qgtrgt0euwBwV91GUKBDENhyOxgDC4cIuAAMlH41G03KMwrs4hDt4ggFElkzJFiplsgbcjQ2f5VSEzlFNXTmz8-nUO0Cuy7e+7Pa7vwPp9wcyTGArAykiNgbuiW4IJafiNv4ZxnEWeLqgaFzGrczLHteCSRJUPyUNwEBwM4L72g01DptsUGgPs7i5HugShJE0SxPEFJpB4YQvDEQTeGYZpMt4ZLsq2dpEG+Tr8j2EhUZmuzQZWloBFcLExHECQVsEng1sqYS7maUQMqJZESRRUndjCnRQj07RyZutEeKaYQqcxUTqexyScU8px+GWhxqma15YdkLamTy77OgKXDWd0ogwqZdnrtRWaOU8fE0Bc+nEmEQS6sJwQVvkOlFEURI+NEOFhGFbavuZfKWeCsUioKcJMElEEpQpaWlJluVBBc6oBTchznnu+nxBcxLRPxjY1eJEUWZ+grNbZoqUOKUrUB1KKQalrgeMchzHcd5zYrldK5GhWo0CEuo7ucdJFHd821ORjoNctXDDgOO3yjRB0IPE-g0LqVy+MhZIcY89HKRqES0uEubXrmhyvVyZkfR+0W0D9sCDlwPqGOg-p-Xt3WA2c1a5I+pK6mU5beZWd01rWfHcbeOq3Oj7b1djMnfX++O-v29ijmTXWKgF1Zg-S-FZeSFanplRLwUehxZMEJm1e9nZRQLuNCwThui2AAFARMIHG-ZAM5t41O5PbuS5pajIGjEAT6bk8S5mafH+DzdUfdwqCsJK0p9Db+37KcNBhDq+I+KqyPOeety3WENMknxJ5PpUQA */
  // cspell:enable
  id: "quickPickMachine",
  context: ({ input }) => ({
    logger: new Logger(input.logger, "quickPickMachine"),
    parent: input.parent,
    kindOfEnumeration: input.kindOfEnumeration,
    pickValue: input.pickValue,
    pickItems: input.pickItems,
    prompt: input.prompt,
    cTSToken: input.cTSToken,
    isCancelled: false,
    isLostFocus: false,
  }),
  output: ({ context }) => ({
    pickValue: context.pickValue,
    isCancelled: context.isCancelled,
    isLostFocus: context.isLostFocus,
    errorMessage: context.errorMessage,
  }),
  initial: "startedState",
  states: {
    startedState: {
      entry: ({ context }) => {
        context.logger.log(
          `quickPickMachine startedState entry`,
          LogLevel.Debug,
        );
      },
      type: "parallel",
      states: {
        operationState: {
          // This state handles the main operation of the machine. First of two parallel states
          initial: "quickPickState",
          states: {
            quickPickState: {
              description:
                "A state where an actor is invoked to show and let the user select an enum value from a QuickPick list.",
              invoke: {
                id: "quickPickActor",
                src: "quickPickActor",
                input: ({ context }) =>
                  ({
                    logger: new Logger(context.logger, "quickPickMachineActor"),
                    kindOfEnumeration: context.kindOfEnumeration,
                    cTSToken: context.cTSToken,
                    pickValue: context.pickValue,
                    pickItems: context.pickItems,
                    prompt: context.prompt,
                  }) as IQuickPickActorInput,
                onDone: {
                  target: "doneState",
                  actions: [
                    {
                      type: "assignQuickPickActorOutputToParentContext",
                      params: ({ context, event }) => ({
                        logger: context.logger,
                        pickValue: event.output.pickValue,
                        isCancelled: event.output.isCancelled,
                        isLostFocus: event.output.isLostFocus,
                      }),
                    },
                  ],
                },
                onError: {
                  target: "errorState",
                  actions:
                    "assignQuickPickActorErrorOutputToQuickPickMachineContext",
                },
              },
            },
            errorState: {
              description:
                "quickPickMachine has entered an error. Will transition to the outer doneState",
              // ToDO: add code to attempt to remediate the error, otherwise transition to innerDoneState
              always: "#quickPickMachine.doneState",
            },
            doneState: {
              description:
                "quickPickMachine is done. Transition to the outer doneState",
              always: "#quickPickMachine.doneState",
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
              // disposingStateEntryAction will dispose of any allocated resources, call DISPOSE.START for any active child machines, and send a DISPOSE.COMPLETE event to itself
              entry: "disposingStateEntryAction",
              on: {
                "DISPOSE.COMPLETE": {
                  target: "disposeCompleteState",
                },
              },
            },
            disposeCompleteState: {
              entry: "disposeCompleteStateEntryAction",
              always: "#quickPickMachine.doneState",
            },
          },
        },
      },
    },
    doneState: {
      type: "final",
      entry: [
        // call the notifyComplete action here, setting the value of the params' properties to values pulled from the context and the event
        // that entered the outer donestate.
        // When notifyCompleteAction is called, the lambda's supplied as arguments to sendTo (because they close over params), will use the values
        //  set into params here, when the lambdas run
        {
          type: "notifyCompleteAction",
          params: ({ context, event }) =>
            ({
              logger: context.logger,
              sendToTargetActorRef: context.parent,
              eventCausingTheTransitionIntoOuterDoneState: event,
            }) as IQuickPickMachineNotifyCompleteActionParameters,
        },
        "debugMachineContext",
      ],
    },
  },
});
