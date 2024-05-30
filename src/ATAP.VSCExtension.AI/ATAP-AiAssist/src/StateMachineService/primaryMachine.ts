import { randomOutcome } from "@Utilities/index"; // ToDo: replace with a mocked iQueryService instead of using this import
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

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
} from "@BaseEnumerations/index";

import {
  QuickPickValueT,
  IQuickPickMachineRefAndSubscription,
  IQuickPickEventPayload,
} from "./quickPickMachineTypes";

import {
  IPrimaryMachineContext,
  IPrimaryMachineInput,
} from "./primaryMachineTypes";

// **********************************************************************************************************************
// context type, input type, output type, and event{ type: 'QUERY_DONE' } | { type: 'DISPOSE_COMPLETE' } payload types for the QueryMultipleEngineMachine
/*  Values imported from the queryMultipleEngineMachine*/
import {
  IQueryMultipleEngineMachineOutput,
  IQueryMultipleEngineEventPayload,
} from "./queryMultipleEngineMachineTypes";
import { queryMultipleEngineMachine } from "./queryMultipleEngineMachine";

import { createQuickPickValue } from "./quickPickMachine";

/*******************************************************************/
/* Primary Machine */

// create the primaryMachine definition
export const primaryMachine = setup({
  types: {} as {
    context: IPrimaryMachineContext;
    input: IPrimaryMachineInput;
    events:
      | { type: "QUICKPICK_START"; payload: IQuickPickEventPayload }
      | { type: "QUICKPICK_DONE" }
      | { type: "QUERY_START"; payload: IQueryMultipleEngineEventPayload }
      | { type: "QUERY_DONE" }
      | { type: "DISPOSE_START" } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
      | { type: "DISPOSE_COMPLETE" };
  },
  actions: {
    spawnQuickPickMachine: assign(({ context, spawn, event, self }) => {
      assertEvent(event, "QUICKPICK_START");
      let _pickItems: vscode.QuickPickItem[];
      let _pickValue: QuickPickValueT;
      let _prompt = "";
      switch (event.payload.quickPickKindOfEnumeration) {
        case QuickPickEnumeration.ModeMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.quickPickKindOfEnumeration,
            context.data.stateManager.currentMode,
          );
          _pickItems = context.data.pickItems.modeMenuItems;
          _prompt = `currently active Mode is ${context.data.stateManager.currentMode}, select one from the list to change it`;
          break;
        case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.quickPickKindOfEnumeration,
            context.data.stateManager.currentQueryAgentCommand,
          );
          _pickItems = context.data.pickItems.queryAgentCommandMenuItems;
          _prompt = `currently active Query Agent Command is ${context.data.stateManager.currentQueryAgentCommand}, select one from the list to change it`;
          break;
        case QuickPickEnumeration.QueryEnginesMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.quickPickKindOfEnumeration,
            context.data.stateManager.currentQueryEngines,
          );
          _pickItems = context.data.pickItems.queryEnginesMenuItems;
          _prompt = `currently active Query Engines are shown below, select one from the list to change it`;
          break;
        default:
          throw new Error(
            `primaryMachine received an unexpected quickPickKindOfEnumeration: ${event.payload.quickPickKindOfEnumeration}`,
          );
      }
      const _actorRef = spawn("quickPickMachine", {
        systemId: "quickPickMachine",
        id: "quickPickMachine",
        input: {
          logger: context.logger,
          parent: self,
          pickValue: _pickValue,
          pickItems: _pickItems,
          prompt: _prompt,
          cTSToken: event.payload.cTSToken,
        },
      });
      const _subscription = _actorRef.subscribe((x) => {
        context.logger.log(
          `spawnQuickPickMachine subscription called with x = ${x}`,
          LogLevel.Debug,
        );
      });
      return {
        quickPickMachineRefAndSubscription: {
          actorRef: _actorRef,
          subscription: _subscription,
        },
      };
    }),
    spawnMultipleEngineQueryMachine: assign(
      ({ context, spawn, event, self }) => {
        context.logger.log(
          `spawnMultipleEngineQueryMachine called`,
          LogLevel.Debug,
        );
        assertEvent(event, "QUERY_START");
        const _currentQueryEngines =
          context.data.stateManager.currentQueryEngines;
        const _actorRef = spawn("queryMultipleEngineMachine", {
          systemId: "queryMultipleEngineMachine",
          id: "queryMultipleEngineMachine",
          input: {
            logger: context.logger,
            parent: self,
            queryService: context.queryService,
            queryFragmentCollection: event.payload.queryFragmentCollection,
            currentQueryEngines: _currentQueryEngines,
            cTSToken: event.payload.cTSToken,
          },
        });
        const _subscription = _actorRef.subscribe((state) => {
          context.logger.log(
            `spawnMultipleEngineQueryMachine subscription called with x = ${state}`,
            LogLevel.Debug,
          );
        });
        return {
          queryMultipleEngineMachineActorRefAndSubscription: {
            actorRef: _actorRef,
            subscription: _subscription,
          },
        };
      },
    ),
    // copy the results (output) from the quickPickMachine to the context
    assignQuickPickMachineDoneOutputToPrimaryMachineContext: assign(
      ({ context }) => {
        context.logger.log(
          `assignQuickPickMachineDoneOutputToPrimaryMachineContext called`,
          LogLevel.Debug,
        );
        const _quickPickMachineActorRef =
          context.quickPickMachineRefAndSubscription as IQuickPickMachineRefAndSubscription;
        // confirm the quickPickMachineActor is done
        if (
          _quickPickMachineActorRef.actorRef.getSnapshot().status !== "done"
        ) {
          throw new Error(
            "OMG how can this happen??!! Gotta submit an xState issue if this ever pops up",
          );
        }
        // ToDo: unsubscribe from the quickPickMachineActorRef
        // ToDo: set the actorRef to undefined
        // Save the output of the quickPickMachine to the IData instance
        return {
          quickPickMachineOutput:
            context.quickPickMachineRefAndSubscription!.actorRef.getSnapshot()
              .output,
          data: {
            ...context.data,
            stateManager: {
              ...context.data.stateManager,
              currentQueryEngines:
                context.quickPickMachineRefAndSubscription!.actorRef.getSnapshot()
                  .output.pickValue.value,
            },
          },
          quickPickMachineRefAndSubscription: undefined,
        };
      },
    ),
    // copy the results (output) from the queryMultipleEngineMachine to the context
    assignQueryMultipleEngineMachineDoneOutputToPrimaryMachineContext: assign(
      ({ context }) => {
        context.logger.log(
          `assignQueryMultipleEngineMachineDoneOutputToPrimaryMachineContext called`,
          LogLevel.Debug,
        );
        const _queryMultipleEngineMachineActorRef =
          context.queryMultipleEngineMachineActorRefAndSubscription as IQueryMultipleEngineMachineActorRefAndSubscription;
        // confirm the queryMultipleEngineMachineActor is done
        if (
          _queryMultipleEngineMachineActorRef.actorRef.getSnapshot().status !==
          "done"
        ) {
          throw new Error(
            "OMG how can this happen??!! Gotta submit an xState issue if this ever pops up",
          );
        }
        // ToDo: unsubscribe from the quickPickMachineActorRef
        // ToDo: set the actorRef to undefined
        return {
          quickPickMachineOutput:
            context.quickPickMachineRefAndSubscription!.actorRef.getSnapshot()
              .output,
          quickPickMachineRefAndSubscription: undefined,
        };
      },
    ),
    updateUIStateEntryAction: (context) => {
      context.context.logger.log(
        `updateUIStateEntryAction, event type is ${context.event.type}`,
        LogLevel.Debug,
      );
    },
    updateUIStateExitAction: (context) => {
      context.context.logger.log(
        `updateUIStateExitAction, event type is ${context.event.type}`,
        LogLevel.Debug,
      );
    },
    updateUIAction: ({ context, event }) => {
      context.logger.log(
        `updateUIAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      switch (event.type) {
        case "QUERY_DONE":
          context.logger.log(
            `updateUIStateEntry, received event type is ${event.type}, context.queryMultipleEngineMachineOutput is ${context.queryMultipleEngineOutput}`,
            LogLevel.Debug,
          );
          break;
        case "QUICKPICK_DONE":
          context.logger.log(
            `updateUIStateEntry, received event type is ${event.type}, context.quickPickMachineOutput is ${context.quickPickMachineOutput}`,
            LogLevel.Debug,
          );
          break;
        default:
          throw new Error(
            `updateUIStateEntry received an unexpected event type: ${event.type}`,
          );
      }
      // if queryMultipleEngineMachineOutput.isCancelled is true, clean up any small UI elements
      // if queryMultipleEngineMachineOutput.errorMessage is defined, display the error message in the UI
      // if queryMultipleEngineMachineOutput.isCancelled is false,
      //  and also context.queryMultipleEngineMachineOutput!.querySingleEngineMachineActorOutputs.isCancelled is false for all keys, then update the UI
      // ToDO: what if some are cancelled but others have returned responses?
    },
    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposingStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
    },
    disposeCompleteStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposeCompleteStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      // Todo: add code to send the DISPOSE_EVENT to any spawned MachineActorRef so that it can free any allocated resources
      // ToDo: current machineActorRefs are queryMultipleEngineMachineMachineActorRefAndSubscription and quickPickMachineActorRefAndSubscription
      // ToDo: add code to dispose of any allocated resource
    },
    debugPrimaryMachineContext: ({ context, event }) => {
      context.logger.log(
        `debugPrimaryMachineContext, context.quickPickMachineOutput.pickValue: ${context.quickPickMachineOutput!.pickValue}, context.quickPickMachineOutput.isCancelled: ${context.quickPickMachineOutput!.isCancelled}, context.quickPickMachineOutput.isLostFocus: ${context.quickPickMachineOutput!.isLostFocus}, context.quickPickMachineOutput.errorMessage: ${context.quickPickMachineOutput!.errorMessage}, context.quickPickMachineActorRefAndSubscription: ${context.quickPickMachineRefAndSubscription}, context.queryMultipleEngineMachineOutput: ${context.queryMultipleEngineMachineOutput}, context.queryMultipleEngineMachineActorRefAndSubscription: ${context.queryMultipleEngineMachineActorRefAndSubscription}`,
        LogLevel.Debug,
      );
    },
    debugPrimaryMachineData: ({ context, event }) => {
      context.logger.log(
        `debugPrimaryMachineContext, context.quickPickMachineOutput.pickValue: ${context.quickPickMachineOutput!.pickValue}, context.quickPickMachineOutput.isCancelled: ${context.quickPickMachineOutput!.isCancelled}, context.quickPickMachineOutput.isLostFocus: ${context.quickPickMachineOutput!.isLostFocus}, context.quickPickMachineOutput.errorMessage: ${context.quickPickMachineOutput!.errorMessage}, context.quickPickMachineActorRefAndSubscription: ${context.quickPickMachineRefAndSubscription}, context.queryMultipleEngineMachineOutput: ${context.queryMultipleEngineMachineOutput}, context.queryMultipleEngineMachineActorRefAndSubscription: ${context.queryMultipleEngineMachineActorRefAndSubscription}`,
        LogLevel.Debug,
      );
    },
  },
  actors: {
    quickPickMachine: quickPickMachine,
    queryMultipleEngineMachine: queryMultipleEngineMachine,
  },
}).createMachine({
  /** @xstate-layout N4IgpgJg5mDOIC5QAcBOBLAtgQ1QTwFlsBjAC3QDswA6Ae2TFWwBd1aKBlZlm9CAGzBceAYgCKAVQCSAYQDSABVlyA+hwAqAQQBK6gNoAGALqIUtWOlbtTIAB6IArAGYALNQAcAdicBGJ5-cXAE4nIJ93ABoQPERfJ2onADYAJkTEzwMDJwdk1KcAX3yotCxcQhJyKjoGJitObmZeASEGsHEJAFFtAE01LV1DEyQQZHNLNgobewQfLKDqFKCg9yd3HwcHWYcomIQnbIWNnzD3ByDU9yzC4owcfCIyShp6RhYJ4UbqPkEPtsku3oAEQA8gA5DqDGyjCx1KaIWYGTzUdb7ULJIKZYI7RCJHxI7yJc6eZIGZKbQnXEa3MoPSrPGpvdi-L7NX7tZRKeQqEHgyHDaHjazDaa+NzpRLZXFORHJFzbaKOS7UMIuYJpILErIFIpU0r3CpPaqvOrM74tUS2WCtagQdg0EjMWioagARwAruhiABrBSer20p58swwiZwhCqnwJFyi7yBVyebEIU4OaieOXrEkklwkhyUkp3cqPKovWrva2MVBOtlBkZjWHCxDJVwLbwuYkOUmywkJhVJwLUAznDuzbOecLam56wt0o2lpnW91+33e6vGKF10MNmaraiynzozwdhy4keJtOJBLuQLpUlXrw+PPU-VF+nGss8V1uxh4ShQVdDYNBUmLcfGjJEOwMS4XB8PxTmSRNZnceYHACZIfESQdzlyB8dXzGkDWLBkTWtN1kAgHhpDZf4em5MEITXfkNyFUBphglwLxHHIVg1NNzkTS4U0PRJo2yMlVQCR8pwDQi33nD9SPIxpKNadl5E5VQeXogDaxDZi7BxAIFmSJC5QMQklgMFwzxWXds1xIIUn8DYgkkgtpNfOd6nksiKKkf91104CWMQYl5iCTZ9mMuDoJ8BDZRTdjPDHOV0hglzcKfadDQgdBYGhc1PkoB10AANwKtpAT8hRgQ4Do+h0fQGMA+tgpmIIXAMahVRJfcYKvdDEkTMkkS8NNB1A5xs38Vz8JfG1cvy5kcrysYKD-FTKo4arapUGRgQIBQABkOnULSAqAsNjibDxfCSjrcgcslE1VeJ0ncXFCQMWC-ESQodQoWgIDgKFMvc86Wv08Nkls-cNSPE9LKs3s3Ee9UNTJRIVmzGbnxnEtGS8xpwc3VqMRhg94ZgyzE3OAdEUuFJ2P8WVPBxrKZM801WVaYm9OmMloaQ0JNhJVx0Se3s8XmAwcnagWvs8NI2fc2cCeZCsqx5xjAsulKEglC4zLbMlIl7K8kXa8I0MPQ90V+jKpIIjy1YXD1vWXL1fl5oLIezNwzJQ04sllEJ5V2fw3ByNDAhcd60gD5WndV4iP3db9fy97WLq3EI3GjCUrpPLxTfDkIB2cVxMnSZIkpwyc3KT-GU8+BTfMz5qSchxXI3CjESTCEO0gQ9CkSyUk5VGmu8UTublsWrWO75+E1kFhx3t75ZLOEmmLxCLJiSvGvglcGeZzn8xyq+ChirK9udOz1rjgcSPvAcuZLK+sPl-iOGOzCY8NjxlPtlBaF8lqgIsGtO+AoIasSvCjdq4VhLsR6k4RMkVUzLH8IiGWWRjiswdg3WeEDL7n1gGAGQtBMDIEEI0aBTEfZwIwh4NehIzib3YkjXYOQkRNhJJccI+5jIuD+vkIAA */
  id: "primaryMachine",
  context: ({ input }) => ({
    logger: new Logger(input.logger, "primaryMachine"),
    data: input.data,
    quickPickMachineRefAndSubscription: undefined,
    quickPickMachineOutput: undefined,
    queryService: input.queryService,
    queryMultipleEngineMachineActorRefAndSubscription: undefined,
    queryMultipleEngineMachineOutput: undefined,
  }),
  type: "parallel",
  states: {
    operationState: {
      // This state handles the main operation of the machine. First of two parallel states
      initial: "idleState",
      states: {
        idleState: {
          on: {
            QUICKPICK_START: {
              target: "quickPickState",
            },
            QUERY_START: {
              target: "queryingState",
            },
            QUERY_DONE: {
              target: "updateUIState",
              // copy the results (output) from the queryMultipleEngineMachine to the context
              actions: [
                "assignQueryMultipleEngineMachineDoneOutputToPrimaryMachineContext",
                "debugPrimaryMachineContext",
              ],
            },
            QUICKPICK_DONE: {
              target: "updateUIState",
              // copy the results (output) from the quickPickMachine to the context
              actions: [
                "assignQuickPickMachineDoneOutputToPrimaryMachineContext",
                "debugPrimaryMachineContext",
              ],
            },
            "xstate.done.actor.quickPickMachine": {
              target: "updateUIState",
            },
          },
        },
        errorState: {
          // ToDO: add code to attempt to remediate the error, otherwise transition to finalErrorState and throw an error
          always: {
            target: "idleState",
          },
        },
        quickPickState: {
          description:
            "A parent state with child states that allow a user to see a list of available enumeration values, pick one, update the extension (transition it) to the UI indicated by the new value, update the 'currentValue' of the enumeration, and then return to the Idle state.",
          entry: "spawnQuickPickMachine", // spawn the quickPickMachine and store the reference in the context
          always: "idleState",
        },
        queryingState: {
          description:
            "A state that spawns a queryMultipleEngineMachine which encapsulates multiple states for handling parallel queries to multiple QueryAgents.",
          entry: [
            "spawnMultipleEngineQueryMachine",
            ({ context }) => {
              context.logger.log("queryingState entry", LogLevel.Debug);
            },
          ], // spawn the queryMultipleEngineMachine and store the reference in the context
          always: "idleState",
        },
        updateUIState: {
          description: "appearance",
          entry: "updateUIStateEntryAction",
          exit: "updateUIStateExitAction",
          always: {
            target: "idleState",
            actions: "updateUIAction",
          },
          // ToDo: all the various on... events
          on: {
            QUERY_DONE: {
              target: "idleState",
              actions: "updateUIAction",
            },
            QUICKPICK_DONE: {
              target: "idleState",
            },
          },
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
          entry: "disposeCompleteStateEntryAction",
          type: "final",
        },
      },
    },
  },
});
