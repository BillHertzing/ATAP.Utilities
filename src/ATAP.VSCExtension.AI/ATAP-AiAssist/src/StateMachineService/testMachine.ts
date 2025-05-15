// This is a demonstration of a parent machine spawning a child machine
// The parent machine starts in the "Idle" state
// The child machine has an input property which
//   contains a property called "foo" of type string
//   contains a property called "parent" of type actorRef<any,any>
// the child machine has an output property which
//   contains a property called "bar" of type string
//   contains a property called "error" of type Error
// the child machine has a context property which
//   contains a property called "foo" of type string
//   contains a property called "parent" of type actorRef<any,any>
//   contains a property called "bar" of type string
//   contains a property called "error" of type Error
// The parent machine has a single property in its context, called "c1", which
//   contains a property called "foo" of type string
//   contains a property called "bar" of type string
//   contains a property called "error" of type Error
//   contains a property called "actorRef" of type actorRef<any,any>
//   contains a property called "subscription" of type subscription<any> ???TBD
// The parent machine starts the child machine when it receives a "C1START" event
// The "C1START" event has a payload containing a single property called "foo" of type string
// on receipt of "C1START", the parent machine will execute a transition action that will:
//   copy the value of "foo" from the event payload to the parent machine's context.c1.foo property
//   copies context.c1.foo into the child's input property "foo"
//   copies the parent self's actor reference into the child machine's input property "parent"
//   set the value of parent machine's context.c1.bar property to "undefined"
//   spawns the child machine and assign the object returned by spawn to the parent machine's context.c1.actorRef property
//   takes a subscription on the child machine's actorRef and puts it into the parent machine's context.c1.subscription property
//       the subscription handles any error raised by the machine by logging it to the console.
//   when the child machine starts, it
//     copies the child machine's input property "foo"" to the child machine's context property "foo"
//     copies the child machine's input property "parent"" to the child machine's context property called "parent"
//     sets the child machine's context property "bar" to undefined
//     sets the child machine's context property "error" to undefined
// The parent machine has a guard on the transition action that prevents the transition if the parent machine's
//    context.c1.actorRef property is not undefined
// The parent machine transitions to (reenters) the "Idle" state, waiting on any further events
// The child machine's output is defined to be the properties "bar" and "error" from the child machine's context
// The child machine invokes a fromPromise actor that performs an async operation
// The async operation has a 25/25/25/25 chance of
//    resolving with a result, resolving with a cancellation, resolving with a timeout, or rejecting with an error
// The "onDone" event triggered by the fromPromise actor when it resolves invokes a transition action that
//    copies the fromPromise actor's output "bar" property to the child machine's context.bar property
//    uses SendTo to notify the parent machine that the child machine is done via the "C1.DONE" event
// The "onError" event called by the fromPromise actor when it rejects invokes a transition action that
//    copies the error object returned from the fromPromise actor's rejection to the child machine's context.error property
//    uses SendTo to notify the parent machine that the child machine is done via the "C1.DONE" event
// The parent machine, on receipt of "C1.DONE" will execute a transition action that will
//   validate that the child machine's state is "Done"
//   assigns the child machine's output "bar" property to its own context.c1.bar property
//   assigns the child machine's output "error" property to its own context.c1.error property
//   assigns "undefined" to its own context.c1.actorRef property
//   assigns "undefined" to its own context.c1.subscription property
//   transitions to (reenters) the "Idle" state

// @ts-check
import { ActorRef, assign, fromPromise, sendTo, setup } from "xstate";

import { produce } from "immer";

interface IC1ActorInput {
  foo?: string;
}

interface IC1ActorOutput {
  bar?: string;
  isCancelled: boolean;
  isTimeout: boolean;
  error?: Error;
}

interface IC1ActorContributionToParentContext
  extends IC1ActorInput,
    IC1ActorOutput {}

interface IRandomOutcomeOutput {
  outputString?: string;
  isCancelled: boolean;
  isTimeout: boolean;
}

function randomOutcome(strToReturn: string): Promise<IRandomOutcomeOutput> {
  return new Promise((resolve, reject) => {
    // Add a 10 milliseconds delay for simulating an async operation
    setTimeout(() => {
      const randomNumber = Math.random();
      if (randomNumber < 0.25) {
        // 25% chance to resolve successfully
        resolve({
          outputString: strToReturn,
          isCancelled: false,
          isTimeout: false,
        } as IRandomOutcomeOutput);
      } else if (randomNumber < 0.5) {
        // 25% chance to resolve with isTimeout = true
        resolve({
          outputString: undefined,
          isCancelled: false,
          isTimeout: true,
        } as IRandomOutcomeOutput);
      } else if (randomNumber < 0.75) {
        // 25% chance to resolve with isCancelled = true
        resolve({
          outputString: undefined,
          isCancelled: true,
          isTimeout: false,
        } as IRandomOutcomeOutput);
      } else {
        // Remaining 25 chance to throw an error
        reject(new Error("Error message from randomOutcome"));
      }
    }, 10); // Delay specified here
  });
}

const c1Actor = fromPromise<IC1ActorOutput, IC1ActorInput>(
  async ({ input }: { input: IC1ActorInput }) => {
    let _result: IRandomOutcomeOutput;
    try {
      _result = await randomOutcome(input.foo + "bar");
      return _result.isCancelled
        ? ({
            bar: undefined,
            isCancelled: true,
            isTimeout: false,
            error: undefined,
          } as IC1ActorOutput)
        : _result.isTimeout
          ? ({
              bar: undefined,
              isCancelled: false,
              isTimeout: true,
              error: undefined,
            } as IC1ActorOutput)
          : ({
              bar: _result.outputString,
              isCancelled: false,
              isTimeout: false,
              error: undefined,
            } as IC1ActorOutput);
    } catch (e) {
      if (e instanceof Error) {
        return {
          bar: undefined,
          isCancelled: false,
          isTimeout: false,
          error: e,
        } as IC1ActorOutput;
      } else {
        // ToDo: add a subscription in the parent machine to catch this
        throw new Error(
          `c1Actor failed, caught unknown type of instance of (e), type is ${typeof e}`,
        );
      }
    }
  },
);

interface IC1MachineInput extends IC1ActorInput {
  parent?: ActorRef<any, any>;
}

interface IC1MachineOutput extends IC1ActorOutput {
  c1TerminatingEvent?: C1MachineCompletionEventsUnionT;
}

interface IC1MachineContext
  extends IC1MachineInput,
    IC1MachineOutput,
    IC1ActorContributionToParentContext {}

interface IC1MachineNotifyCompleteActionParameters {
  sendToTargetActorRef: ActorRef<any, any>;
  isCancelled: boolean;
  eventCausingTheTransitionIntoDoneState: C1MachineCompletionEventsUnionT;
}

export type C1ActorCompletionEventsUnionT =
  | { type: "xstate.done.actor.c1Actor" }
  | { type: "xstate.error.actor.c1Actor" };

type C1MachineCompletionEventsUnionT =
  | { type: "C1.DONE" }
  | { type: "C1.TIMEOUT" }
  | { type: "C1.CANCELLED" }
  | { type: "C1.ERROR" };

type C1MachineAllEventsUnionT =
  | C1ActorCompletionEventsUnionT
  | C1MachineCompletionEventsUnionT;

interface IAssignC1ActorOutputToParentContextActionParameters
  extends IC1ActorOutput {
  context: IC1MachineContext;
  c1TerminatingEvent?: C1MachineCompletionEventsUnionT;
}

const C1Machine = setup({
  types: {} as {
    context: IC1MachineContext;
    input: IC1MachineInput;
    output: IC1MachineOutput;
    events: C1MachineAllEventsUnionT;
  },
  actors: {
    c1Actor: c1Actor,
  },
  actions: {
    // assign the output of the c1Actor to the parent context using assignC1ActorOutputToParentContext
    //  use parameters and immer together
    assignC1ActorOutputToParentContext: assign(
      (_, params: IAssignC1ActorOutputToParentContextActionParameters) => {
        return produce(params.context, (draft) => {
          draft.bar = params.bar;
          draft.isTimeout = params.isTimeout;
          draft.isCancelled = params.isCancelled;
          draft.error = params.error;
          draft.c1TerminatingEvent = params.c1TerminatingEvent;
        });
      },
    ),
    // inform the parent machine that the child machine c1Machine is done
    c1MachineNotifyCompleteAction: sendTo(
      (_, params: IC1MachineNotifyCompleteActionParameters) => {
        return params.sendToTargetActorRef;
      },
      (_, params: IC1MachineNotifyCompleteActionParameters) => {
        return { type: "C1.DONE" };
      },
    ),
  },
}).createMachine({
  // cspell:disable
  /** @xstate-layout N4IgpgJg5mDOIC5gF8A0IB2B7CdGgGMBGAWQEMCALASwzHxAActZqAXarDBgD0SIBM6AJ78ByCciA */
  // cspell:enable
  id: "c1Machine",
  context: ({ input }) => ({
    parent: input.parent,
    foo: input.foo,
    bar: undefined,
    isCancelled: false,
    isTimeout: false,
    error: undefined,
    c1TerminatingEvent: undefined,
    output: ({ context }) =>
      ({
        bar: context.bar,
        isTimeout: context.isTimeout,
        isCancelled: context.isCancelled,
        error: context.error,
        c1TerminatingEvent: context.c1TerminatingEvent,
      }) as IC1MachineOutput,
    initial: "c1State",
    c1State: {
      invoke: {
        id: "c1Actor",
        src: "c1Actor",
        input: ({ context }) =>
          ({
            foo: context.foo,
          }) as IC1ActorInput,
        onDone: {
          target: "doneState",
          actions: {
            type: "assignC1ActorOutputToParentContext",
            params: ({ context, event }) =>
              ({
                context: context,
                bar: event.output.bar,
                isTimeout: event.output.isTimeout,
                isCancelled: event.output.isCancelled,
                error: undefined,
                c1TerminatingEvent: event.output.isTimeout
                  ? { type: "C1.TIMEOUT" }
                  : event.output.isCancelled
                    ? { type: "C1.CANCELLED" }
                    : { type: "C1.DONE" },
              }) as IAssignC1ActorOutputToParentContextActionParameters,
          },
        },
        onError: {
          target: "doneState",
          actions: {
            type: "assignC1ActorOutputToParentContext",
            params: ({ context, event }) =>
              ({
                context: context,
                bar: undefined,
                isTimeout: false,
                isCancelled: false,
                error: event.output.error,
                c1TerminatingEvent: { type: "C1.ERROR" },
              }) as IAssignC1ActorOutputToParentContextActionParameters,
          },
        },
      },
    },
    doneState: {
      type: "final",
      entry: {
        type: "c1MachineNotifyCompleteAction",
        params: ({ context, event }) =>
          ({
            sendToTargetActorRef: context.parent,
            isTimeout: context.isTimeout,
            isCancelled: context.isCancelled,
            c1TerminatingEvent: context.c1TerminatingEvent,
            eventCausingTheTransitionIntoDoneState: event,
          }) as IC1MachineNotifyCompleteActionParameters,
      },
    },
  }),
});

interface IPMInput {}
interface IPMOutput {}
interface IC1MachineContributionToParentContext
  extends IC1MachineInput,
    IC1MachineOutput {
  actorRef?: ActorRef<any, any>;
}

interface ISpawnC1MachineActionParameters extends IC1MachineInput {
  context: IPMContext;
  spawn: (machineId: string, input: any) => ActorRef<any, any>;
}

interface IPMContext extends IPMInput, IPMOutput {
  c1: IC1MachineContributionToParentContext;
}

export interface IC1STARTEventPayload {
  foo: string;
}
type PMMachineAllEventsUnionT =
  | {
      type: "C1START";
      payload: IC1STARTEventPayload;
    }
  | C1MachineCompletionEventsUnionT;

interface IAssignC1MachineOutputToParentContextActionParameters {
  context: IPMContext;
  c1MachineOutput: IC1MachineOutput;
}
/******************************************************************************************************************** */
// The primaryMachine is the parent machine that spawns the c1Machine
export const primaryMachine = setup({
  types: {} as {
    input: IPMInput;
    output: IPMOutput;
    context: IPMContext;
    events: PMMachineAllEventsUnionT;
  },
  actors: {
    c1Machine: C1Machine,
  },
  actions: {
    // spawn the c1Machine
    //   the machine's input parameters come from the .START event payload and from this machine as parent
    //   the machine's input is passed to this action via the parameters
    //   assign the machine's input parameters to the parent context's fields
    //   clear the machine's output fields in the parent context
    //   spawn the c1Machine and assign its actorRef to the parent context
    spawnC1Machine: assign((_, params: ISpawnC1MachineActionParameters) => {
      return produce(params.context, (draft) => {
        draft.c1.foo = params.foo;
        //draft.c1.cTSToken = params.cTSToken;
        draft.c1.bar = undefined;
        draft.c1.error = undefined;
        draft.c1.actorRef = params.spawn("c1Machine", {
          systemId: "c1Machine",
          id: "c1Machine",
          input: {
            parent: params.parent,
            foo: params.foo,
            //cTSToken: params.cTSToken,
          } as IC1MachineInput,
        });
      });
    }),

    // assign the output of the c1Machine to the parent context using assignC1MachineOutputToParentContext
    //  use parameters and immer together
    assignC1MachineOutputToParentContext: assign(
      (_, params: IAssignC1MachineOutputToParentContextActionParameters) => {
        return produce(params.context, (draft) => {
          draft.c1.bar = params.c1MachineOutput.bar;
          draft.c1.isTimeout = params.c1MachineOutput.isTimeout;
          draft.c1.isCancelled = params.c1MachineOutput.isCancelled;
          draft.c1.error = params.c1MachineOutput.error;
          draft.c1.c1TerminatingEvent =
            params.c1MachineOutput.c1TerminatingEvent;
        });
      },
    ),
  },
}).createMachine({
  // cspell:disable
  /** @xstate-layout N4IgpgJg5mDOIC5QAcBOBLAtgQ1QTwFlsBjAC3QDswA6dCAGzAGIBhARmoGUAVAQQCVuAbQAMAXUQoA9rHQAXdFIqSQAD0Rs2I6iIAsANgAc+rQE5TAJgDM+3YYA0IPBoDs+6lZGmRbAxdOGAboAvsGOaFi4hCTkVLQMzOzUACIA8gByAKKiEkggyDLyisp56gi6Fo7OCIYcegCsbFZs9SIiVgGGIaGOFFIQcCoROPhEZJRgQ4UKSiplALT6VYiLPfkYI9HjcXSMU7IzJaBlTYbU+jYWLlb1ulZ2N8sIV+71LhaBLi71ph0upvpQqEgA */
  // cspell:enable
  id: "parentChildDemoMachine",
  context: () =>
    ({
      c1: {
        parent: undefined,
        foo: undefined,
        bar: undefined,
        isTimeout: false,
        isCancelled: false,
        errorMessage: undefined,
        c1TerminatingEvent: undefined,
      } as IC1MachineContributionToParentContext,
    }) as IPMContext,
  initial: "idle",
  states: {
    idle: {
      entry: () => {
        console.log("parentChildDemoMachine idle state entry");
      },
      on: {
        C1START: {
          target: "idle",
          reenter: true,
          actions: [
            assign(({ context, spawn, event, self }) => {
              return produce(context, (draft) => {
                draft.c1.foo = event.payload.foo;
                //draft.c1.cTSToken = params.cTSToken;
                draft.c1.bar = undefined;
                draft.c1.error = undefined;
                draft.c1.actorRef = spawn("c1Machine", {
                  systemId: "c1Machine",
                  id: "c1Machine",
                  input: {
                    parent: self,
                    foo: event.payload.foo,
                    //cTSToken: params.cTSToken,
                  } as IC1MachineInput,
                });
              });
            }),
            // {
            //   type: "spawnC1Machine",
            //   params: ({ context, spawn, event, self }) =>
            //   ({
            //     context:context,
            //       foo: event.payload.foo,
            //       parent: self,
            //     } as ISpawnC1MachineActionParameters),
            // },
          ],
        },
        "C1.DONE": {
          target: "idle",
          reenter: true,
          actions: {
            type: "assignC1MachineOutputToParentContext",
            params: ({ context }) =>
              ({
                context: context,
                c1MachineOutput: context.c1.actorRef?.getSnapshot().output,
              }) as IAssignC1MachineOutputToParentContextActionParameters,
          },
        },
      },
    },
  },
});
