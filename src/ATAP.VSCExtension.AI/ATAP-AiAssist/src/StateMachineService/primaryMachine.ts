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

import { produce } from "immer";

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
} from "@BaseEnumerations/index";

// *********************************************************************************************************************
// quickPickMachine types used in the primaryMachine
import {
  QuickPickValueT,
  IQuickPickMachineInput,
  IQuickPickMachineOutput,
  IQuickPickMachineComponentOfParentMachineContext,
  IAssignQuickPickMachineOutputToParentContextActionParameters,
} from "./quickPickTypes";
import { quickPickMachine, createQuickPickValue } from "./quickPickMachine";

// *********************************************************************************************************************
// gatheringMachine types used in the primaryMachine
import {
  IGatheringMachineInput,
  IGatheringMachineOutput,
  IGatheringMachineComponentOfParentMachineContext,
} from "./gatheringTypes";
//import { gatheringMachine } from "./gatheringMachine";

// *********************************************************************************************************************
// querySingleEngineMachine types used in the primaryMachine
import {
  IQuerySingleEngineMachineInput,
  IQuerySingleEngineMachineOutput,
  IQuerySingleEngineMachineComponentOfParentMachineContext,
} from "./querySingleEngineTypes";
import { querySingleEngineMachine } from "./querySingleEngineMachine";
// *********************************************************************************************************************
// queryMultipleEngineMachine types used in the primaryMachine
import {
  IQueryMultipleEngineMachineInput,
  IQueryMultipleEngineMachineOutput,
  IQueryMultipleEngineMachineComponentOfParentMachineContext,
} from "./queryMultipleEngineTypes";
import { queryMultipleEngineMachine } from "./queryMultipleEngineMachine";

// *********************************************************************************************************************
// AllMachine Event types used in the primaryMachine
import {
  AllMachineDisposeEventsUnionT,
  AllMachineActorDisposeCompletionEventsUnionT,
} from "./allMachinesCommonTypes";

// *********************************************************************************************************************
// primaryMachine types used in the primaryMachine
import {
  IPrimaryMachineContext,
  IPrimaryMachineInput,
  IQuickPickEventPayload,
  IQueryMultipleEngineEventPayload,
} from "./primaryMachineTypes";

/*******************************************************************/
/* Primary Machine */

// create the primaryMachine definition
export const primaryMachine = setup({
  types: {} as {
    context: IPrimaryMachineContext;
    input: IPrimaryMachineInput;
    events:
      | {
          type: "QUICKPICK_MACHINE.START";
          payload: IQuickPickEventPayload;
        }
      | { type: "QUICKPICK_MACHINE.DONE" }
      | {
          type: "QUERY_MULTIPLE_ENGINE_MACHINE.START";
          payload: IQueryMultipleEngineEventPayload;
        }
      | { type: "QUERY_MULTIPLE_ENGINE_MACHINE.DONE" }
      | AllMachineDisposeEventsUnionT;
  },
  actors: {
    quickPickMachine: quickPickMachine,
    queryMultipleEngineMachine: queryMultipleEngineMachine,
  },

  actions: {
    debugMachineContext: ({ context, event }) => {
      context.logger.log(
        // ToDo stringify the context.<various>Machine objects
        `primaryMachineDebugMachineContext,
          context.quickPickMachine: ${JSON.stringify(context.quickPickMachine)}
          context.gatheringMachine: ${JSON.stringify(context.gatheringMachine)}
          context.querySingleEngineMachine: ${JSON.stringify(context.querySingleEngineMachine)}
          context.queryMultipleEngineMachine: ${JSON.stringify(context.queryMultipleEngineMachine)}
          `,
        LogLevel.Debug,
      );
    },
    spawnQuickPickMachine: assign(({ context, spawn, event, self }) => {
      const logger = new Logger(context.logger, "spawnQuickPickMachine");
      logger.log(`Started`, LogLevel.Debug);
      assertEvent(event, "QUICKPICK_MACHINE.START");
      let _pickItems: vscode.QuickPickItem[];
      let _pickValue: QuickPickValueT;
      let _prompt = "";
      switch (event.payload.kindOfEnumeration) {
        case QuickPickEnumeration.ModeMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.kindOfEnumeration,
            context.data.stateManager.currentMode,
          );
          _pickItems = context.data.pickItems.modeMenuItems;
          _prompt = `currently active Mode is ${context.data.stateManager.currentMode}, select one from the list to change it`;
          break;
        case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.kindOfEnumeration,
            context.data.stateManager.currentQueryAgentCommand,
          );
          _pickItems = context.data.pickItems.queryAgentCommandMenuItems;
          _prompt = `currently active Query Agent Command is ${context.data.stateManager.currentQueryAgentCommand}, select one from the list to change it`;
          break;
        case QuickPickEnumeration.QueryEnginesMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.kindOfEnumeration,
            context.data.stateManager.currentQueryEngines,
          );
          _pickItems = context.data.pickItems.queryEnginesMenuItems;
          _prompt = `currently active Query Engines are shown below, select one from the list to change it`;
          break;
        default:
          throw new Error(
            `primaryMachine received an unexpected kindOfEnumeration: ${event.payload.kindOfEnumeration}`,
          );
      }
      const _actorRef = spawn("quickPickMachine", {
        systemId: "quickPickMachine",
        id: "quickPickMachine",
        input: {
          logger: context.logger,
          parent: self,
          kindOfEnumeration: event.payload.kindOfEnumeration,
          pickValue: _pickValue,
          pickItems: _pickItems,
          prompt: _prompt,
          cTSToken: event.payload.cTSToken,
        },
      });
      const _subscription = _actorRef.subscribe((state) => {
        logger.log(`Subscription called with x = ${state}`, LogLevel.Debug);
      });
      const _quickPickMachine = context.quickPickMachine;
      _quickPickMachine.actorRef = _actorRef;
      // ToDo: Subscribe and handle machine-level errors

      logger.log(
        `Leaving _actorRef = ${JSON.stringify(_actorRef)}, _subscription = ${JSON.stringify(_subscription)}`,
        LogLevel.Debug,
      );
      return {
        quickPickMachine: _quickPickMachine,
      };
    }),
    spawnMultipleEngineQueryMachine: assign(
      ({ context, spawn, event, self }) => {
        const logger = new Logger(
          context.logger,
          "spawnMultipleEngineQueryMachine",
        );
        logger.log(`Started`, LogLevel.Debug);
        assertEvent(event, "QUERY_MULTIPLE_ENGINE_MACHINE.START");
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
            `spawnMultipleEngineQueryMachine subscription called with state = ${state}`,
            LogLevel.Debug,
          );
        });
        const _queryMultipleEngineMachine = context.queryMultipleEngineMachine;
        _queryMultipleEngineMachine.actorRef = _actorRef;
        // ToDo: Subscribe and handle machine-level errors
        logger.log(
          `Leaving _actorRef = ${JSON.stringify(_actorRef)}, _subscription = ${JSON.stringify(_subscription)}`,
          LogLevel.Debug,
        );
        return {
          queryMultipleEngineMachine: _queryMultipleEngineMachine,
        };
      },
    ),
    // copy the results (output) from the quickPickMachine to the context
    assignQuickPickMachineDoneOutputToParentContext: assign({
      quickPickMachine: ({ context, event }) =>
        produce(context, (draftContext) => {
          const logger = new Logger(
            draftContext.logger,
            "assignQuickPickMachineOutputToParentContext",
          );
          // confirm the _quickPickActor is done
          // First confirm that a actorRef for a quickPickActor exists
          const _quickPickActorRef = draftContext.quickPickMachine.actorRef;
          if (_quickPickActorRef == undefined) {
            const _message = `draftContext.quickPickMachine.actorRef is undefined`;
            logger.log(_message, LogLevel.Error);
            throw new Error(`${logger.scope} ` + _message);
          }
          // confirm that the status is "done"
          if (_quickPickActorRef!.getSnapshot().status !== "done") {
            const _message = `draftContext.quickPickMachine.actorRef.status is NOT done. This should never happen, contact xState`;
            logger.log(_message, LogLevel.Error);
            throw new Error(`${logger.scope} ` + _message);
          }
          // assign the output of the quickPickMachine to the primaryMachine context
          draftContext.quickPickMachine.quickPickMachineOutput =
            _quickPickActorRef.getSnapshot().output;
          // ToDo: unsubscribe from the quickPickActorSubscription
          // ToDo: remove the reference to the quickPickMachineRef
          draftContext.quickPickMachine.actorRef = undefined;
        }),
    }),

    // copy the results (output) from the queryMultipleEngineMachine to the context
    assignQueryMultipleEngineMachineDoneOutputToParentContext: assign({
      queryMultipleEngineMachine: ({ context, event }) =>
        produce(context, (draftContext) => {
          const logger = new Logger(
            draftContext.logger,
            " assignQueryMultipleEngineMachineDoneOutputToParentContext",
          );
          // confirm the _queryMultipleEngineMachine is done
          // First confirm that a actorRef for a queryMultipleEngineActor exists
          const _queryMultipleEngineActorRef =
            draftContext.queryMultipleEngineMachine.actorRef;
          if (_queryMultipleEngineActorRef == undefined) {
            const _message = `draftContext.queryMultipleEngineMachine.actorRef is undefined`;
            logger.log(_message, LogLevel.Error);
            throw new Error(`${logger.scope} ` + _message);
          }
          // confirm that the status is "done"
          if (_queryMultipleEngineActorRef.getSnapshot().status !== "done") {
            const _message = `draftContext.queryMultipleEngineMachine.actorRef.status is NOT done. This should never happen, contact xState`;
            logger.log(_message, LogLevel.Error);
            throw new Error(`${logger.scope} ` + _message);
          }
          // assign the output of the quickPickMachine to the primaryMachine context
          draftContext.queryMultipleEngineMachine.queryMultipleEngineMachineOutput =
            _queryMultipleEngineActorRef.getSnapshot().output;
          // ToDo: unsubscribe from the queryMultipleEngineSubscription
          // ToDo: remove the reference to the queryMultipleEngineMachineRef
          draftContext.queryMultipleEngineMachine.actorRef = undefined;
        }),
    }),

    updateUIStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `updateUIStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
    },
    updateUIStateExitAction: ({ context, event }) => {
      context.logger.log(
        `updateUIStateExitAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
    },
    updateUIAction: ({ context, event }) => {
      context.logger.log(
        `updateUIAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      switch (event.type) {
        case "QUERY_MULTIPLE_ENGINE_MACHINE.DONE":
          context.logger.log(
            `updateUIStateEntry, received event type is ${event.type}, context.queryMultipleEngineMachineOutput is ${context.queryMultipleEngineMachine.queryMultipleEngineMachineOutput}`,
            LogLevel.Debug,
          );
          break;
        case "QUICKPICK_MACHINE.DONE":
          context.logger.log(
            `updateUIStateEntry, received event type is ${event.type}, context.quickPickMachineOutput is ${context.quickPickMachine.quickPickMachineOutput}`,
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
      //  and also context.queryMultipleEngineMachineOutput!.queryMultipleSingleEngineMachineOutputs.isCancelled is false for all keys, then update the UI
      // ToDO: what if some are cancelled but others have returned responses?
    },
    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposingStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      // Todo: add code to send the DISPOSE.START to any spawned MachineActorRef so that it can free any allocated resources
      // ToDo: current machineActorRefs are queryMultipleEngineActorRefAndSubscription and quickPickActorRefAndSubscription
      // ToDo: add code to dispose of any allocated resource
    },
    disposeCompleteStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposeCompleteStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
    },
    debugPrimaryMachineContext: ({ context, event }) => {
      context.logger.log(
        `debugPrimaryMachineContext:
        context.quickPickMachineOutput: ${JSON.stringify(context.quickPickMachine.quickPickMachineOutput)},
        context.quickPickMachine.actorRef: ${JSON.stringify(context.quickPickMachine.actorRef)},
         context.queryMultipleEngineMachine.queryMultipleEngineMachineOutput: ${JSON.stringify(context.queryMultipleEngineMachine.queryMultipleEngineMachineOutput)},
         context.actorRef: ${JSON.stringify(context.queryMultipleEngineMachine.actorRef)}`,
        LogLevel.Debug,
      );
    },
    debugPrimaryMachineData: ({ context, event }) => {
      context.logger.log(
        `debugPrimaryMachineData Data: ${JSON.stringify(context.data)}`,
        LogLevel.Debug,
      );
    },
  },
}).createMachine({
  // cspell:disable
  /** @xstate-layout N4IgpgJg5mDOIC5QAcBOBLAtgQ1QTwFlsBjAC3QDswA6Ae2TFWwBd1aKBlZlm9CAGzBceAYgCKAVQCSAYQDSABVlyA+hwAqAQQBK6gNoAGALqIUtWOlbtTIAB6IArAGYALNQAcAdicBGJ5-cXAE4nIJ93ABoQPERfJ2onADYAJkTEzwMDJwdk1KcAX3yotCxcQhJyKjoGJitObmZeASEGsHEJAFFtAE01LV1DEyQQZHNLNgobewQfLKDqFKCg9yd3HwcHWYcomIQnbIWNnzD3ByDU9yzC4owcfCIyShp6RhYJ4UbqPkEPtsku3oAEQA8gA5DqDGyjCx1KaIWYGTzUdb7ULJIKZYI7RCJHxI7yJc6eZIGZKbQnXEa3MoPSrPGpvdi-L7NX7tZRKeQqEHgyHDaHjazDaa+NzpRLZXFORHJFzbaKOS7UMIuYJpILErIFIpU0r3CpPaqvOrM74tUS2WCtagQdg0EjMWioagARwAruhiABrBSer20p58swwiZwhCqnwJFyi7yBVyebEIU4OaieOXrEkklwkhyUkp3cqPKovWrva2MVBOtlBkZjWHCxDJVwLbwuYkOUmywkJhVJwLUAznDuzbOecLam56wt0o2lpnW91+33e6vGKF10MNmaraiynzozwdhy4keJtOJBLuQLpUlXrw+PPU-VF+nGss8V1uxh4ShQVdDYNBUmLcfGjJEOwMS4XB8PxTmSRNZnceYHACZIfESQdzlyB8dXzGkDWLBkTWtN1kAgHhpDZf4em5MEITXfkNyFUBphglwLxHHIVg1NNzkTS4U0PRJo2yMlVQCR8pwDQi33nD9SPIxpKNadl5E5VQeXogDaxDZi7BxAIFmSJC5QMQklgMFwzxWXds1xIIUn8DYgkkgtpNfOd6nksiKKkf91104CWMQYl5iCTZ9mMuDoJ8BDZRTdjPDHOV0hglzcKfadDQgdBYGhc1PkoB10AANwKtpAT8hRgQ4Do+h0fQGMA+tgpmIIXAMahVRJfcYKvdDEkTMkkS8NNB1A5xs38Vz8JfG1cvy5kcrysYKD-FTKo4arapUGRgQIBQABkOnULSAqAsNjibDxfCSjrcgcslE1VeJ0ncXFCQMWC-ESQodQoWgIDgKFMvc86Wv08Nkls-cNSPE9LKs3s3Ee9UNTJRIVmzGbnxnEtGS8xpwc3VqMRhg94ZgyzE3OAdEUuFJ2P8WVPBxrKZM801WVaYm9OmMloaQ0JNhJVx0Se3s8XmAwcnagWvs8NI2fc2cCeZCsqx5xjAsulKEglC4zLbMlIl7K8kXa8I0MPQ90V+jKpIIjy1YXD1vWXL1fl5oLIezNwzJQ04sllEJ5V2fw3ByNDAhcd60gD5WndV4iP3db9fy97WLq3EI3GjCUrpPLxTfDkIB2cVxMnSZIkpwyc3KT-GU8+BTfMz5qSchxXI3CjESTCEO0gQ9CkSyUk5VGmu8UTublsWrWO75+E1kFhx3t75ZLOEmmLxCLJiSvGvglcGeZzn8xyq+ChirK9udOz1rjgcSPvAcuZLK+sPl-iOGOzCY8NjxlPtlBaF8lqgIsGtO+AoIasSvCjdq4VhLsR6k4RMkVUzLH8IiGWWRjiswdg3WeEDL7n1gGAGQtBMDIEEI0aBTEfZwIwh4NehIzib3YkjXYOQkRNhJJccI+5jIuD+vkIAA */
  // cspell:enable
  id: "primaryMachine",
  context: ({ input }) =>
    ({
      logger: new Logger(input.logger, "primaryMachine"),
      data: input.data,
      queryService: input.queryService,
      quickPickMachine: {} as IQuickPickMachineComponentOfParentMachineContext,
      gatheringMachine: {} as IGatheringMachineComponentOfParentMachineContext,
      querySingleEngineMachine:
        {} as IQuerySingleEngineMachineComponentOfParentMachineContext,
      queryMultipleEngineMachine:
        {} as IQueryMultipleEngineMachineComponentOfParentMachineContext,
    }) as IPrimaryMachineContext,
  type: "parallel",
  states: {
    operationState: {
      // This state handles the main operation of the machine. First of two parallel states
      initial: "idleState",
      states: {
        idleState: {
          on: {
            "QUICKPICK_MACHINE.START": {
              target: "idleState",
              reenter: true,
              actions: ["debugPrimaryMachineContext", "spawnQuickPickMachine"],
            },
            "QUICKPICK_MACHINE.DONE": {
              target: "updateUIState",
              // copy the results (output) from the quickPickMachine to the context
              actions: [
                "assignQuickPickMachineDoneOutputToParentContext",
                "debugPrimaryMachineContext",
              ],
            },
            "QUERY_MULTIPLE_ENGINE_MACHINE.START": {
              target: "queryingState",
            },
            "QUERY_MULTIPLE_ENGINE_MACHINE.DONE": {
              target: "updateUIState",
              // copy the results (output) from the queryMultipleEngineMachine to the context
              actions: [
                "assignQueryMultipleEngineMachineDoneOutputToParentContext",
                "debugPrimaryMachineContext",
              ],
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
            ({ context }) => {
              context.logger.log("queryingState entry action", LogLevel.Debug);
            },
            "spawnMultipleEngineQueryMachine",
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
            "QUERY_MULTIPLE_ENGINE_MACHINE.DONE": {
              target: "idleState",
              actions: "updateUIAction",
            },
            "QUICKPICK_MACHINE.DONE": {
              target: "idleState",
            },
          },
        },
      },
    },

    disposeState: {
      // 2nd parallel state. This state can be transitioned to regardless of any other state the machine might be in
      initial: "inactiveState",
      states: {
        inactiveState: {
          on: {
            "DISPOSE.START": "disposingState",
          },
        },
        disposingState: {
          entry: "disposingStateEntryAction",
          on: {
            "DISPOSE.COMPLETE": {
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
