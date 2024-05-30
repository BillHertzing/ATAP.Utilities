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
  IQuickPickMachineInput,
  IQuickPickMachineOutput,
  IQuickPickMachineContext,
  QuickPickMachineCompletionEventsUnionT,
  IQuickPickMachineNotifyCompleteActionParameters,
  IQuickPickActorLogicInput,
  IQuickPickActorLogicOutput,
} from "./quickPickMachineTypes";
import { quickPickActorLogic } from "./quickPickMachineActorLogic";
// ***********************************************************************************************************************
// Helper function for creating a quickPickValue
// Used by primary machine when spawning the quickPickMachine
// Used by the quickPickMachine when creating the pickValue to return
export function createQuickPickValue<K extends QuickPickMappingKeysT>(
  type: K,
  value?: IQuickPickTypeMapping[K],
): QuickPickValueT {
  return [type, value] as QuickPickValueT;
}
// **********************************************************************************************************************
// Machine definition for the quickPickMachine
export const quickPickMachine = setup({
  types: {} as {
    context: IQuickPickMachineContext;
    input: IQuickPickMachineInput;
    output: IQuickPickMachineOutput;
    events:
      | QuickPickMachineCompletionEventsUnionT
      | { type: "QUICKPICK_DONE" }
      | { type: "DISPOSE_START" } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
      | { type: "DISPOSE_COMPLETE" };
  },
  actions: {
    assignQuickPickActorDoneOutputToQuickPickMachineContext: assign(
      ({ event }) => {
        assertEvent(event, "xstate.done.actor.quickPickActor");
        return {
          pickValue: event.output.pickValue,
          isCancelled: event.output.isCancelled,
          isLostFocus: event.output.isLostFocus,
        };
      },
    ),
    // assignQuickPickActorDoneOutputToQuickPickMachineContext2: assign(
    //   _,
    //   params: IAssignQuickPickActorDoneOutputToQuickPickMachineContextActionParameters,
    // ) => {
    //   params.logger.log(
    //     `assignQuickPickActorDoneOutputToQuickPickMachineContext2, pickValue= ${params.pickValue}, isCancelled= ${params.isCancelled}, isLostFocus= ${params.isLostFocus}, errorMessage= ${params.errorMessage!}`,
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
    //  it has two arguments, either or both of which can be a lambda that closes over their params argument
    //   The first lambda returns an actorRef, and the second lambda returns an event, thus satisfying the two argument types that sendTo expects
    notifyCompleteAction: sendTo(
      (_, params: IQuickPickMachineNotifyCompleteActionParameters) => {
        params.logger.log(
          `notifyCompleteAction, in the destination selector lambda, sendToTargetActorRef is ${params.sendToTargetActorRef.id}`,
          LogLevel.Debug,
        );
        return params.sendToTargetActorRef;
      },
      (_, params: IQuickPickMachineNotifyCompleteActionParameters) => {
        params.logger.log(
          `notifyCompleteAction, in the event selector lambda, eventCausingTheTransitionIntoOuterDoneState is ${params.eventCausingTheTransitionIntoOuterDoneState.type}`,
          LogLevel.Debug,
        );
        // discriminate on event that triggers this action and send QUICKPICK_DONE or DISPOSE_COMPLETE
        let _eventToSend:
          | { type: "QUICKPICK_DONE" }
          | { type: "DISPOSE_COMPLETE" };
        switch (params.eventCausingTheTransitionIntoOuterDoneState.type) {
          case "xstate.done.actor.quickPickActor":
            _eventToSend = { type: "QUICKPICK_DONE" };
            break;
          case "xstate.done.actor.quickPickDisposeActor":
            _eventToSend = { type: "DISPOSE_COMPLETE" };
            break;
          // ToDo: add case legs for the two error events that come from the quickPickActor and quickPickDisposeActor
          default:
            throw new Error(
              `notifyCompleteAction received an unexpected event type: ${params.eventCausingTheTransitionIntoOuterDoneState.type}`,
            );
        }
        params.logger.log(
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
      // ToDo: add code to dispose of any allocated resource
    },

    debugQuickPickMachineContext: ({ context, event }) => {
      context.logger.log(
        `debugQuickPickMachineContext, context.pickValue: ${context.pickValue}, context.isCancelled: ${context.isCancelled} context.isLostFocus: ${context.isLostFocus}`,
        LogLevel.Debug,
      );
    },
  },
  actors: {
    quickPickActor: quickPickActorLogic,
  },
}).createMachine({
  /** @xstate-layout N4IgpgJg5mDOIC5QEcCuBLAxgawApewFkBDTAC3QDswA6WAF2ICd7IBlR1mgewAcwmxeum6UOQ2mgL4c41gGIIo2lQBu3bJIw4Z2AIKZ63JgG0ADAF1EoXt1jpho6yAAeiALQBGABzeaAVn8AJgBOADYAFk8Qs38wkJCggBoQAE8PTzM-AGZc7LMEoKD-XM8ggF9ylKkdAhJyKloGZlYIOVo+ASERMU4taQJ2+QEmYxpeABshADNjAFsaGrwCAyNTS2dbe0dKZzcEaIB2AOzvT08I4JCIkLiwlPSELyyaPPzC4tKKqpAl3XqKNQ6IwWOw+jx+IIdu0aCNjENzFYkCAtg4entENl-GYaBFvLdPIcggUImF-CEHohErizBFQt5-J5sp4yWZvtVtMscADGsCWmCJBCutDwVRqEwACLKBEbZGonYYg7+Y4RCLZELZQ6RMKHRm6ykIYo4plBbI3Mnec1ZSocgbc0iApog1owiDoWBbMAwqikYSqL19eQSgCSbFwAHk2ABRAD6bAAKnoAErxxGbOxopzI-aHBI0Ymmswsy7ZIJkg3uYnZGi+ELF4mHesRG2-Tn-B285qgtrgt0euwBwV91GUKBDENhyOxgDC4cIuAAMlH41G03KMwrs4hDt4ggFElkzJFiplsgbcjQ2f5VSEzlFNXTmz8-nUO0Cuy7e+7Pa7vwPp9wcyTGArAykiNgbuiW4IJafiNv4ZxnEWeLqgaFzGrczLHteCSRJUPyUNwEBwM4L72g01DptsUGgPs7i5HugShJE0SxPEFJpB4YQvDEQTeGYZpMt4ZLsq2dpEG+Tr8j2EhUZmuzQZWloBFcLExHECQVsEng1sqYS7maUQMqJZESRRUndjCnRQj07RyZutEeKaYQqcxUTqexyScU8px+GWhxqma15YdkLamTy77OgKXDWd0ogwqZdnrtRWaOU8fE0Bc+nEmEQS6sJwQVvkOlFEURI+NEOFhGFbavuZfKWeCsUioKcJMElEEpQpaWlJluVBBc6oBTchznnu+nxBcxLRPxjY1eJEUWZ+grNbZoqUOKUrUB1KKQalrgeMchzHcd5zYrldK5GhWo0CEuo7ucdJFHd821ORjoNctXDDgOO3yjRB0IPE-g0LqVy+MhZIcY89HKRqES0uEubXrmhyvVyZkfR+0W0D9sCDlwPqGOg-p-Xt3WA2c1a5I+pK6mU5beZWd01rWfHcbeOq3Oj7b1djMnfX++O-v29ijmTXWKgF1Zg-S-FZeSFanplRLwUehxZMEJm1e9nZRQLuNCwThui2AAFARMIHG-ZAM5t41O5PbuS5pajIGjEAT6bk8S5mafH+DzdUfdwqCsJK0p9Db+37KcNBhDq+I+KqyPOeety3WENMknxJ5PpUQA */
  id: "quickPickMachine",
  context: ({ input }) => ({
    logger: new Logger(input.logger, "quickPickMachine"),
    parent: input.parent,
    quickPickKindOfEnumeration: input.quickPickKindOfEnumeration,
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
                input: ({ context }) => ({
                  logger: new Logger(context.logger, "quickPickMachineActor"),
                  quickPickKindOfEnumeration:
                    context.quickPickKindOfEnumeration,
                  cTSToken: context.cTSToken,
                  pickValue: context.pickValue,
                  pickItems: context.pickItems,
                  prompt: context.prompt,
                }),
                onDone: {
                  target: "innerDoneState",
                  actions: [
                    {
                      type: "assignQuickPickActorDoneOutputToQuickPickMachineContext",
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
              // ToDO: add code to attempt to remediate the error, otherwise transition to innerDoneState
              always: {
                target: "innerDoneState",
              },
            },
            innerDoneState: {
              description:
                "quickPickMachine is done. Transition to the outerDoneState",
              always: "#quickPickMachine.outerDoneState",
            },
          },
        },
        disposeState: {
          // 2nd parallel state. This state can be transitioned to from any state
          initial: "inactiveState",
          states: {
            inactiveState: {
              on: {
                DISPOSE_START: "disposingState",
              },
            },
            disposingState: {
              entry: "disposingStateEntryAction",
              on: {
                DISPOSE_COMPLETE: {
                  target: "disposeCompleteState",
                },
              },
            },
            disposeCompleteState: {
              always: "#quickPickMachine.outerDoneState",
            },
          },
        },
      },
    },
    outerDoneState: {
      type: "final",
      entry: [
        // call the notifyComplete action here, setting the value of the params' properties to values pulled from the context and the event
        // that entered the outerDonestate.
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
        "debugQuickPickMachineContext",
      ],
    },
  },
});
