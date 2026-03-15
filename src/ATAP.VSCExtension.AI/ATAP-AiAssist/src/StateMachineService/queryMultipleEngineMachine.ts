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

import { produce } from "immer";

import {
  QueryFragmentEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
} from "@BaseEnumerations/index";

import { IQueryService } from "@QueryService/index";

import { IQueryFragmentCollection } from "@ItemWithIDs/index";

import { DetailedError, HandleError } from "@ErrorClasses/index";

import {
  IChildActorBaseInput,
  IChildActorBaseOutput,
  IChildMachineBaseInput,
  IChildMachineBaseOutput,
  IChildMachineBaseContext,
  IAllMachineNotifyCompleteActionParameters,
  AllMachineActorDisposeCompletionEventsUnionT,
  AllMachineDisposeEventsUnionT,
} from "./allMachinesCommonTypes";

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

import { querySingleEngineMachine } from "./querySingleEngineMachine";

import {
  IQueryMultipleEngineMachineInput,
  IQueryMultipleEngineMachineContext,
  IQueryMultipleEngineMachineOutput,
  IQueryMultipleSingleEngineMachineRefs,
  IQueryMultipleSingleEngineMachineOutputs,
  IQueryMultipleEngineMachineNotifyCompleteActionParameters,
  QueryMultipleEngineMachineAllEventsUnionT,
} from "./queryMultipleEngineTypes";

import {
  IGatheringActorInput,
  IGatheringActorOutput,
  IGatheringActorComponentOfParentMachineContext,
} from "./gatheringTypes";
import { gatheringActor } from "./gatheringActorLogic";

// *********************************************************************************************************************
// Machine definition for the queryMultipleEngineMachine
export const queryMultipleEngineMachine = setup({
  types: {} as {
    context: IQueryMultipleEngineMachineContext;
    input: IQueryMultipleEngineMachineInput;
    output: IQueryMultipleEngineMachineOutput;
    events: QueryMultipleEngineMachineAllEventsUnionT;
    children: {
      gatheringActor: "gatheringActor";
      querySingleEngineMachine: "querySingleEngineMachine";
    };
  },
  actors: {
    gatheringActor: gatheringActor,
    querySingleEngineMachine: querySingleEngineMachine,
  },
  actions: {
    debugMachineContext: ({ context, event }) => {
      context.logger.log(
        // ToDo stringify the context.queryMultipleSingleEngineMachineRefs object
        `queryMultipleEngineMachineDebugMachineContext
        context.gatheringMachine.queryString: ${JSON.stringify(context.gatheringMachine!.queryString)}
          context.queryMultipleSingleEngineMachineRefs: ${JSON.stringify(context.queryMultipleSingleEngineMachineRefs)}
          context.queryMultipleSingleEngineMachineOutputs: ${JSON.stringify(context.queryMultipleSingleEngineMachineOutputs)}
          `,
        LogLevel.Debug,
      );
    },
    // spawn a querySingleEngineMachine for each enabled queryAgent and store the actor references in the context.queryMultipleSingleEngineMachineRefs
    fetchingStateEntryAction: assign({
      queryMultipleSingleEngineMachineRefs: ({
        context,
        spawn,
        event,
        self,
      }) => {
        const logger = new Logger(context.logger, "fetchingStateEntryAction");
        logger.log(`Started`, LogLevel.Debug);
        // create a local variable to hold the new queryMultipleSingleEngineMachineRefs object
        const numActive = Object.entries(QueryEngineFlagsEnum).filter(
          // get just the active query engines
          ([name, queryEngineFlagValue]) =>
            context.currentQueryEngines &
            (queryEngineFlagValue as QueryEngineFlagsEnum),
        ).length;
        logger.log(
          `fetchingStateEntryAction numActive = ${numActive} querySingleEngineMachine(s) to be created`,
          LogLevel.Debug,
        );
        let _queryMultipleSingleEngineMachineRefs: IQueryMultipleSingleEngineMachineRefs =
          {} as IQueryMultipleSingleEngineMachineRefs;
        // spawn a querySingleEngineMachine for each enabled queryAgent
        Object.entries(QueryEngineFlagsEnum)
          .filter(
            // get just the active query engines
            ([name, queryEngineFlagValue]) =>
              context.currentQueryEngines &
              (queryEngineFlagValue as QueryEngineFlagsEnum),
          )
          // convert from the name of the enumeration values (string) to the actual entire enumeration object
          .map(
            ([name]) =>
              QueryEngineNamesEnum[name as keyof typeof QueryEngineNamesEnum],
          )
          // iterate over each active enumeration object and spawn a querySingleEngineMachine for each
          .forEach((name) => {
            const _actorRef = spawn("querySingleEngineMachine", {
              systemId: `qSAM-${name}`,
              id: "querySingleEngineMachine",
              input: {
                logger: context.logger,
                queryEngineName: name,
                parent: self,
                queryService: context.queryService,
                queryString: context.gatheringMachine!.queryString as string,
                cTSToken: context.cTSToken,
              },
            });
            const _subscription = _actorRef.subscribe((state) => {});
            //store the spawned actor reference and its subscription in the queryMultipleSingleEngineMachineRefs object keyed by the enumeration object
            _queryMultipleSingleEngineMachineRefs[name] = {
              actorRef: _actorRef,
              subscription: _subscription,
            };
          });
        logger.log(
          `Created ${Object.keys(_queryMultipleSingleEngineMachineRefs).length} querySingleEngineMachine(s)`,
          LogLevel.Debug,
        );
        // return the new _queryMultipleSingleEngineMachineRefs structure, placing it into the context.queryMultipleSingleEngineMachineRefs
        return _queryMultipleSingleEngineMachineRefs;
      },
    }),
    assignGatheringMachineActorDoneOutputToParentContext: assign(
      ({ context, spawn, event, self }) => {
        assertEvent(event, "xstate.done.actor.gatheringActor");
        return {
          queryString: event.output.queryString,
          isCancelled: event.output.isCancelled,
          errorMessage: "",
        };
      },
    ),
    assignGatheringMachineActorErrorOutputToParentContext: assign(
      ({ context, spawn, event, self }) => {
        assertEvent(event, "xstate.error.actor.gatheringActor");
        return {
          queryString: "",
          isCancelled: false,
          errorMessage: event.message,
        };
      },
    ),
    assignQuerySingleEngineMachineDoneOutputToQueryMultipleEngineMachineContext:
      assign({
        queryMultipleSingleEngineMachineOutputs: ({ context, event }) =>
          produce(context, (draftContext) => {
            assertEvent(event, "QUERY_SINGLE_ENGINE_MACHINE.DONE");
            const _queryEngineName = event.payload.queryEngineName;
            // ensure that the queryMultipleSingleEngineMachineRefs[_queryEngineName] object is defined
            if (
              draftContext.queryMultipleSingleEngineMachineRefs[
                _queryEngineName
              ] == undefined
            ) {
              const _message = `context.queryMultipleSingleEngineMachineRefs[${_queryEngineName}] is undefined`;
              context.logger.log(_message, LogLevel.Error);
              throw new Error(`${context.logger.scope}  + .a2 ` + _message);
            }
            const _querySingleEngineMachineRef =
              context.queryMultipleSingleEngineMachineRefs[_queryEngineName];
            // confirm the _querySingleEngineMachine is done
            if (
              _querySingleEngineMachineRef.actorRef.getSnapshot().status !==
              "done"
            ) {
              throw new Error(
                "OMG how can this happen??!! Gotta submit an xState issue if this ever pops up",
              );
            }
            // Get the output of the querySingleEngineMachine for this specific queryEngineName
            const _querySingleEngineMachineOutput =
              context.queryMultipleSingleEngineMachineRefs[
                _queryEngineName
              ].actorRef.getSnapshot()
                .output as IQuerySingleEngineMachineOutput;
            // assign the output of the querySingleEngineMachine to the queryMultipleSingleEngineMachineOutputs object
            draftContext.queryMultipleSingleEngineMachineOutputs[
              _queryEngineName
            ] = _querySingleEngineMachineOutput;
          }),
      }),
    assignQuerySingleEngineMachineDoneOutputToQueryMultipleEngineMachineContextOld:
      assign(({ context, spawn, event, self }) => {
        assertEvent(event, "QUERY_SINGLE_ENGINE_MACHINE.DONE");
        const _queryEngineName = event.payload.queryEngineName;
        const _querySingleEngineMachineRef =
          context.queryMultipleSingleEngineMachineRefs![_queryEngineName];
        // confirm the querySingleEngineMachine is done
        if (
          _querySingleEngineMachineRef.actorRef.getSnapshot().status !== "done"
        ) {
          throw new Error(
            "OMG how can this happen??!! Gotta submit an xState issue if this ever pops up",
          );
        }
        if (context.queryMultipleSingleEngineMachineRefs == undefined) {
          const _message = `assignQuerySingleEngineMachineDoneOutputToQueryMultipleEngineMachineContext: context.queryMultipleSingleEngineMachineRefs is undefined`;
          context.logger.log(_message, LogLevel.Error);
          throw new Error(
            `${context.logger.scope}  + .assignQuerySingleEngineMachineDoneOutputToQueryMultipleEngineMachineContext ` +
              _message,
          );
        }
        const _querySingleEngineMachineOutput =
          context.queryMultipleSingleEngineMachineRefs[
            _queryEngineName
          ].actorRef.getSnapshot().output as IQuerySingleEngineMachineOutput;
        const _queryMultipleSingleEngineMachineOutputs =
          context.queryMultipleSingleEngineMachineOutputs;
        _queryMultipleSingleEngineMachineOutputs![_queryEngineName] =
          _querySingleEngineMachineOutput;
        return {
          queryMultipleSingleEngineMachineOutputs:
            _queryMultipleSingleEngineMachineOutputs,
        };
      }),
    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposingStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      // Todo: add code to send the DISPOSE.START to any spawned MachineActorRef so that it can free any allocated resources
      // ToDo: current machineActorRefs are the dictionary of singleEngineMachineRefs
      // ToDo: add code to dispose of any allocated resource
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
    // the sendTo(...) is a special action that can go wherever an action can go
    //  it has two arguments, either or both of which can be a lambda that closes over their params argument
    //   The first lambda returns an actorRef, and the second lambda returns an event, thus satisfying the two argument types that sendTo expects
    notifyCompleteAction: sendTo(
      (
        _,
        params: IQueryMultipleEngineMachineNotifyCompleteActionParameters,
      ) => {
        params.logger.log(
          `notifyCompleteAction, in the destination selector lambda, sendToTargetActorRef is ${params.sendToTargetActorRef.id}`,
          LogLevel.Debug,
        );
        return params.sendToTargetActorRef;
      },
      (
        _,
        params: IQueryMultipleEngineMachineNotifyCompleteActionParameters,
      ) => {
        params.logger.log(
          `notifyCompleteAction, in the event selector lambda, eventCausingTheTransitionIntoOuterDoneState is ${params.eventCausingTheTransitionIntoOuterDoneState.type}`,
          LogLevel.Debug,
        );
        // discriminate on event that triggers this action and send the appropriate completion notification event to the parent
        let _eventToSend:
          | { type: "QUERY_MULTIPLE_ENGINE_MACHINE.DONE" }
          | { type: "DISPOSE.COMPLETE" };
        switch (params.eventCausingTheTransitionIntoOuterDoneState.type) {
          case "xstate.done.actor.queryMultipleEngineMachineActor":
            _eventToSend = { type: "QUERY_MULTIPLE_ENGINE_MACHINE.DONE" };
            break;
          case "xstate.done.actor.disposeActor":
            _eventToSend = { type: "DISPOSE.COMPLETE" };
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
  },
  guards: {
    allQueryMultipleSingleEngineMachineOutputsDefined: ({ context, event }) => {
      const _queryMultipleSingleEngineMachineRefs =
        context.queryMultipleSingleEngineMachineRefs as IQueryMultipleSingleEngineMachineRefs;
      const _queryMultipleSingleEngineMachineOutputs =
        context.queryMultipleSingleEngineMachineOutputs as IQueryMultipleSingleEngineMachineOutputs;
      return (
        Object.keys(
          context.queryMultipleSingleEngineMachineRefs as IQueryMultipleSingleEngineMachineRefs,
        ).length ===
        Object.keys(
          context.queryMultipleSingleEngineMachineOutputs as Partial<IQuerySingleEngineActorOutput>,
        ).length
      );
    },
  },
}).createMachine({
  id: "queryMultipleEngineMachine",
  context: ({ input }) => ({
    logger: new Logger(input.logger, "queryMultipleEngineMachine"),
    parent: input.parent,
    queryService: input.queryService,
    queryFragmentCollection: input.queryFragmentCollection,
    currentQueryEngines: input.currentQueryEngines,
    gatheringMachine: undefined,
    queryMultipleSingleEngineMachineRefs:
      {} as IQueryMultipleSingleEngineMachineRefs,
    queryMultipleSingleEngineMachineOutputs:
      {} as IQueryMultipleSingleEngineMachineOutputs,
    cTSToken: input.cTSToken,
    isCancelled: false,
  }),
  output: ({ context }) =>
    ({
      queryMultipleSingleEngineMachineOutputs:
        context.queryMultipleSingleEngineMachineOutputs,
      isCancelled: context.isCancelled,
      errorMessage: context.errorMessage,
    }) as IQueryMultipleEngineMachineOutput,
  initial: "startedState",
  states: {
    startedState: {
      entry: ({ context }) => {
        context.logger.log(
          `queryMultipleEngineMachine startedState entry`,
          LogLevel.Debug,
        );
      },
      type: "parallel",
      states: {
        operationState: {
          initial: "gatheringState",
          entry: ({ context }) => {
            context.logger.log(`operationState entry`, LogLevel.Debug);
          },
          states: {
            gatheringState: {
              description:
                "given an ordered collection of fragment identifiers, gather the fragments and assemble them into a query string",
              entry: ({ context }) => {
                context.logger.log(`gatheringState entry`, LogLevel.Debug);
              },
              invoke: {
                id: "gatheringActor",
                src: "gatheringActor",
                input: ({ context }) => ({
                  logger: context.logger,
                  queryFragmentCollection: context.queryFragmentCollection,
                  cTSToken: context.cTSToken,
                }),
                onDone: {
                  target: "fetchingState",
                  // set the context for queryString and isCancelled
                  actions:
                    "assignGatheringMachineActorDoneOutputToParentContext",
                },
                onError: {
                  target: "errorState",
                  actions:
                    "assignGatheringMachineActorErrorOutputToParentContext",
                },
              },
            },
            fetchingState: {
              id: "fetchingState",
              description:
                "given a query string, send it to every enabled queryAgent and collect the results",
              entry:
                // this entry action spawns a querySingleEngineMachine for each enabled queryAgent and stores the actor references in the context.queryMultipleSingleEngineMachineRefs
                "fetchingStateEntryAction",
              // when a querySingleEngineMachine is done, it will send the QUERY_SINGLE_ENGINE_MACHINE.DONE event to this machine
              // when this machine receives a QUERY_SINGLE_ENGINE_MACHINE.DONE event it will:
              // read the event payload for the engineName
              // get the corresponding actorRef, confirm it is in done state,
              // and assign the output of the querySingleEngineMachine of type IQuerySingleEngineMachineOutput to the value of the context.queryMultipleSingleEngineMachineOutputs instance keyed by the engineName
              // ToDo: Notify this machine's parent machine (primaryMachine) that one querySingleEngineMachine is done and send the instance of the IQuerySingleEngineMachineOutput to its parent
              // transition to the doneState guarded by condition that all of the context.queryMultipleSingleEngineMachineOutputs instances are defined for every entry in context.queryMultipleSingleEngineMachineRefs
              on: {
                "QUERY_SINGLE_ENGINE_MACHINE.DONE": {
                  target: "waitingForAllState",
                  actions:
                    // assign to queryMultipleSingleEngineMachineOutputs in this machine's context the output of the querySingleEngineMachine
                    "assignQuerySingleEngineMachineDoneOutputToQueryMultipleEngineMachineContext",
                },
              },
            },
            waitingForAllState: {
              // if all context.queryMultipleSingleEngineMachineOutputs are defined, transition to the doneState
              // else transition back to the fetchingState, (note that reset is NOT true, so entry actions will not be re-executed)
              always: [
                {
                  target: "doneState",
                  guard: "allQueryMultipleSingleEngineMachineOutputsDefined",
                },
                { target: "fetchingState" },
              ],
            },
            errorState: {
              // ToDO: add code to attempt to remediate the error, otherwise transition to outer doneState
              always: "#queryMultipleEngineMachine.doneState",
            },
            doneState: {
              description:
                "all querySingleEngineMachines are done. all queryMultipleSingleEngineMachineOutputs are defined. queryMultipleEngineMachine is done. transition to the outer doneState",
              always: "#queryMultipleEngineMachine.doneState",
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
              entry: "disposingStateEntryAction",
              on: {
                "DISPOSE.COMPLETE": {
                  target: "disposeCompleteState",
                },
              },
            },
            disposeCompleteState: {
              entry: "disposeCompleteStateEntryAction",
              always: "#queryMultipleEngineMachine.doneState",
            },
          },
        },
      },
    },
    doneState: {
      type: "final",
      entry: [
        {
          type: "notifyCompleteAction",
          params: ({ context, event }) =>
            ({
              logger: context.logger,
              sendToTargetActorRef: context.parent,
              eventCausingTheTransitionIntoOuterDoneState: event,
            }) as IQueryMultipleEngineMachineNotifyCompleteActionParameters,
        },
        "debugMachineContext",
      ],
    },
  },
});
