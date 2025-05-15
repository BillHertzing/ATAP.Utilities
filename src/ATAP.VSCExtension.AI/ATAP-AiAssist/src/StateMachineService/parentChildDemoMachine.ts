// This code example is written by a human and is not machine generated.
// this code example is written by a developer with lots of c# and OOP experience
//   but with very little experience in TypeScript, JavaScript, and XState  (I'm learning)
// The example makes use of typescript interfaces instead of relying on typescript's auto-inference, in order to make
//    clear the types of the objects being used as parameters.
// This example makes liberal use of logging to trace the execution of the code. It uses a custom logger class.
//    The Logger class used in production code is from the ATAP AI-Assist vscode extension, and uses the
//    Pino logger for the underlying implementation. This example stubs out the custom logger and sends to console.log.
//  This example uses a CancellationTokenSource.Token (cTSToken) to pass a cancellation token to the child machine,
//    the invoked actor, and the async operation.
//    The cTSToken in production is an instance of a vscode.CancellationToken
//    The cTSToken in this example is a stub that is not used in the code. It is included for demonstration purposes.
// This example makes use of very long and descriptive names for objects, properties, classes, and methods.
//
// This is a demonstration of a parent machine spawning a child machine. The child machine executes an async function
//    that is wrapped in a function that supports a cancellation and a timeout.
//
// The parent machine is the primaryMachine and the child machine is the c1Machine.
// The parent machine starts in it's "Idle" state
// The child machine has an input property of type IC1MachineInput which
//   contains a property called "logger" of type ILogger
//   contains a property called "foo" of type string
//   contains a property called "parent" of type actorRef<any,any>
//   contains a property called "cTSToken" of type: CancellationToken
// the child machine has an output property of type IC1MachineOutput which
//   contains a property called "bar" of type string
//   contains a property called "error" of type Error
//   contains a property called "isTimeout" of type boolean
//   contains a property called "isCancelled" of type boolean
//   contains a property called "c1TerminatingEvent" of type C1MachineCompletionEventsUnionT
//  The interface IC1ActorContributionToParentContext consists of a union of IC1MachineInput and IC1MachineOutput
// the child machine has a context property of type IC1MachineContext that extends IC1ActorContributionToParentContext
//    and has no additional properties
// The parent machine has a context property called "c1" conforming to the interface IC1MachineContext which
//   contains a property called "foo" of type string
//   contains a property called "bar" of type string
//   contains a property called "isTimeout" of type boolean
//   contains a property called "isCancelled" of type boolean
//   contains a property called "error" of type Error
//   contains a property called "c1TerminatingEvent" of type C1MachineCompletionEventsUnionT
//   contains a property called "dTSStart" of type Date
//   contains a property called "dTSEnd" of type Date
//   contains a property called "actorRef" of type actorRef<any,any>
//   contains a property called "subscriptionLogger" of type ILogger
//   contains a property called "subscription" of type subscription<any> ???TBD
// The parent machine starts the child machine when it receives a "C1.START" event
// The "C1.START" event has a property named payload which
//   contains a property called "foo" of type string
//   contains a property called "cTSToken" of type CancellationToken
//   contains a property called "timeoutLimit" of type number
//   contains a property called "delayDurationForDemonstrationTesting" of type number
// on receipt of "C1.START", the parent machine will execute a transition action that will:
//   copy the value of "foo" from the event payload to the parent machine's context.c1.foo property
//   copies context.c1.foo into the child's input property "foo"
//   set the value of parent machine's context.c1.bar property to "undefined"
//   copies the parent self's actor reference into the child machine's input property "parent"
//   spawns the child machine and assign the object returned by spawn to the parent machine's context.c1.actorRef property
//   creates a logger for the subscription to the child machine and assigns it to the parent machine's
//    context.c1.subscriptionLogger property
//   takes a subscription on the child machine's actorRef and puts it into the parent machine's context.c1.subscription property
//       the subscription logs all calls by logging them to the subscriptionLogger.
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
//    copies the fromPromise actor's output "isCancelled" and "isTimeout" properties to the child machine's context
//    uses SendTo to notify the parent machine that the child machine is done via the "C1.DONE" event
// The "onError" event called by the fromPromise actor when it rejects invokes a transition action that
//    copies the error object returned from the fromPromise actor's rejection to the child machine's context.error property
//    uses SendTo to notify the parent machine that the child machine is done via the "C1.DONE" event
// The parent machine, on receipt of "C1.DONE" will execute a transition action that will
//   validate that the child machine's state is "Done"
//   assigns the child machine's output "bar", "isCancelled", "isTimeout" properties to its own context.c1. properties
//   assigns the child machine's output "error" property to its own context.c1.error property
//   unsubscribes from its own context.c1.subscription property
//   assigns "undefined" to its own context.c1.subscription property
//   assigns "undefined" to its own context.c1.subscriptionLogger property
//   assigns "undefined" to its own context.c1.actorRef property
//   transitions to (reenters) the "Idle" state

import { ActorRef, assign, fromPromise, sendTo, setup } from "xstate";
import { produce } from "immer";

import { Event } from "vscode";
// Logger class from the ATAP AI-Assist vscode extension
import { Logger, ILogger, LogLevel } from "@Logger/index";
// Logger class simple stub for this example
// an enumeration to represent the differing Logging levels
// enum LogLevel {
//   Fatal = 1,
//   Error = 2,
//   Warn = 3,
//   Info = 4,
//   Debug = 5,
//   Trace = 6,
//   Performance = 7,
// }
// interface ILogger {
//   readonly scope: string;
//   log(message: string, level: LogLevel): void;
//   dispose(): void;
// }
// class Logger implements ILogger {
//   public readonly scope: string;
//   constructor(logger: ILogger | null, scope: string) {
//     if (logger) {
//       this.scope = logger.scope + "." + scope;
//     } else {
//       this.scope = scope;
//     }
//   }
//   log(message: string, level: LogLevel): void {
//     console.log(`${this.scope}: ${message}`);
//   }
//   dispose(): void {}
// }
// End the Logger class simple stub for this example

// Cancellation token source token simple stub for this example
import { CancellationTokenSource, CancellationToken } from "vscode";
// interface ICancellationToken {
//   isCancellationRequested: boolean;
//   onCancellationRequested: Event<any>;
// }
// class CancellationToken implements ICancellationToken {
//   public isCancellationRequested: boolean = false;
//   constructor() {}
//   // an event that fires when the token is cancelled
//   public onCancellationRequested: () => void = () => {};
// }

interface IRandomOutcomeInput {
  strToReturn: string;
  delayDurationForDemonstrationTesting?: number;
}
interface IRandomOutcomeOutput {
  outputString?: string;
}
const errorRandomOutcomePromiseID = "##unknownError##";
const errorCancelledRandomOutcomePromiseID = "##cancelled##";
const errorTimeoutRandomOutcomePromiseID = "##timeout##";

// The randomOutcome function simulates an async operation,
async function randomOutcome(
  strToReturn: string,
  delayDurationForDemonstrationTesting?: number,
): Promise<IRandomOutcomeOutput> {
  // ToDo: implement a variable timeoutLimit
  // ToDo: implement polling on the cTSToken.isCancellationRequested while the simulated async operation is "running"
  // default built-in delayDurationForDemonstrationTesting to 10 msec
  const _delayDurationForDemonstrationTesting =
    delayDurationForDemonstrationTesting
      ? delayDurationForDemonstrationTesting
      : 10;
  return new Promise((resolve, reject) => {
    // simulating an async operation
    setTimeout(
      () => {
        // ToDo: return a timeout if the operation has taken too long
        //  simulate a random outcome to the underlying async operation
        const randomNumber = Math.random();
        if (randomNumber < 25.0) {
          // 25% chance to resolve successfully
          resolve({
            outputString: strToReturn,
          });
        } else if (randomNumber < 50.0) {
          // 25% chance to reject with timeout
          reject(new Error(errorTimeoutRandomOutcomePromiseID));
        } else if (randomNumber < 75.0) {
          // 25% chance to reject with cancelled
          reject(new Error(errorCancelledRandomOutcomePromiseID));
        } else {
          // Remaining 25 chance to throw an unknownerror
          reject(new Error(errorRandomOutcomePromiseID));
        }
      },
      delayDurationForDemonstrationTesting, // underlying async operation simulated delay to completion
    );
  });
}

interface IRandomOutcomeCancellationAndTimeoutWrapperInput
  extends IRandomOutcomeInput {
  cTSToken?: CancellationToken;
  timeoutLimit?: number;
}
interface IRandomOutcomeCancellationAndTimeoutWrapperOutput
  extends IRandomOutcomeOutput {
  isCancelled: boolean;
  isTimeout: boolean;
}

// async function W(
//   A: (
//     foo: string,
//   ) => Promise<IRandomOutcomeCancellationAndTimeoutWrapperOutput>,
//   foo: string,
//   cancellationToken: CancellationToken,
//   timeout: number,
// ): Promise<IRandomOutcomeCancellationAndTimeoutWrapperOutput> {
//   const _result =  Promise.race([
//     randomOutcome(foo),
//     new Promise<IRandomOutcomeCancellationAndTimeoutWrapperOutput>(
//       (resolve,) => {
//         const timeoutId = setTimeout(
//           () => resolve({ outputString: void 0, isCancelled: false, isTimeout: true }),
//         ), timeout,
//       }),
//     //  todo: does the timeoutId need to be cleared if the promise resolves before the timeout?),
//       // todo: does the subscription to the cancellation event need to be unsubscribed here?
//     // ToDo: figure out register for the cancellation event, do so here. save subscription in ???
//     //     cancellationToken.onCancellationRequested(() => {
//     //       clearTimeout(timeoutId); //  ToDo: not in scope - need to fix
//     //       () => resolve({ outputString: void 0, isCancelled : true, isTimeout : false}),
//     //     });
//     //   },
//     // ),
//   ]);
// }

async function randomOutcomeCancellationAndTimeoutWrapper<
  IRandomOutcomeCancellationAndTimeoutWrapperOutput,
  IRandomOutcomeCancellationAndTimeoutWrapperInput,
>(
  strToReturn: string,
  cTSToken?: CancellationToken,
  timeoutLimit?: number,
  delayDurationForDemonstrationTesting?: number,
): Promise<IRandomOutcomeCancellationAndTimeoutWrapperOutput> {
  // create a promise for the ctsToken if one is passed
  const cTSTokenPromise = cTSToken
    ? new Promise<never>((_, reject) => {
        // reject if the token is cancelled
        if (cTSToken.isCancellationRequested) {
          reject(new Error(errorCancelledRandomOutcomePromiseID));
        }
      })
    : void 0;
  // create a promise for the timeoutLimit if one is passed
  const timeoutLimitPromise = timeoutLimit
    ? new Promise<never>((_, reject) => {
        setTimeout(() => {
          reject(new Error(errorTimeoutRandomOutcomePromiseID));
        }, timeoutLimit);
      })
    : void 0;
  //  create a promise for the async function randomOutcome
  const randomOutcomePromise = randomOutcome(
    strToReturn,
    delayDurationForDemonstrationTesting,
  );
  // create an iterable of the promises that were not null
  const promises = [
    cTSTokenPromise,
    timeoutLimitPromise,
    randomOutcomePromise,
  ].filter((p) => p !== void 0);
  // create a promise.race and use the iterable for the promises that were not null
  return Promise.race(promises)
    .then((value) => {
      // if the thenable runs, there was no error
      // return the value from the async function randomOutcome
      return {
        result: value.outputString,
        isCancelled: false,
        isTimeout: false,
        error: void 0,
      } as IRandomOutcomeCancellationAndTimeoutWrapperOutput;
    })
    .catch((e) => {
      //  if the catch leg executes, a promise was rejected.
      //  was it cancellation
      if (e.message === errorCancelledRandomOutcomePromiseID) {
        return {
          result: void 0,
          isCancelled: true,
          isTimeout: false,
          error: void 0,
        } as IRandomOutcomeCancellationAndTimeoutWrapperOutput;
      }
      //  was it a timeout
      if (e.message === errorTimeoutRandomOutcomePromiseID) {
        return {
          result: void 0,
          isCancelled: false,
          isTimeout: true,
          error: void 0,
        } as IRandomOutcomeCancellationAndTimeoutWrapperOutput;
      }
      //  was it an error message from the async function randomOutcome
      if (e.message === errorRandomOutcomePromiseID) {
        return {
          result: void 0,
          isCancelled: false,
          isTimeout: false,
          error: e,
        } as IRandomOutcomeCancellationAndTimeoutWrapperOutput;
      }
      // was it even an error?
      if (e instanceof Error) {
        // ToDo: best way to rethrow if not using the ATAP Detailed Error Handling pattern
        // Just send it up the chain
        return {
          result: void 0,
          isCancelled: false,
          isTimeout: false,
          error: e,
        } as IRandomOutcomeCancellationAndTimeoutWrapperOutput;
      }
      // wow, caught something that was not an error. alert the securityService and log it
      return {
        result: void 0,
        isCancelled: false,
        isTimeout: false,
        error: new Error(
          `randomOutcomeCancellationAndTimeoutWrapper failed, caught unknown type of instance of (e), type is ${typeof e}`,
        ),
      } as IRandomOutcomeCancellationAndTimeoutWrapperOutput;
    });
}

interface IC1ActorInput
  extends Omit<
    IRandomOutcomeCancellationAndTimeoutWrapperInput,
    "strToReturn"
  > {
  foo?: string;
}

interface IC1ActorOutput
  extends Omit<
    IRandomOutcomeCancellationAndTimeoutWrapperOutput,
    "outputString"
  > {
  bar?: string;
  error?: Error;
}
interface IC1ActorContributionToParentContext
  extends IC1ActorInput,
    IC1ActorOutput {}

const c1Actor = fromPromise<IC1ActorOutput, IC1ActorInput>(
  async ({ input }: { input: IC1ActorInput }) => {
    // try/catch is not necessary or correct here, but it is included (but commented out) to demonstrate that
    //    catching an error and returning an instance of IC1ActorOutput will cause
    //    the event "xstate.done.actor.c1Actor" to be returned
    //try {
    const _result = await randomOutcomeCancellationAndTimeoutWrapper(
      randomOutcome(input.foo + "barString"),
      input.cTSToken,
      input.delayDurationForDemonstrationTesting,
    );
    return {
      bar: _result.outputString,
      isCancelled: _result.isCancelled,
      isTimeout: _result.isTimeout,
      error: void 0,
    } as IC1ActorOutput;

    // const _result = await randomOutcomeCancellationAndTimeoutWrapper<
    //   IRandomOutcomeCancellationAndTimeoutWrapperOutput,
    //   IRandomOutcomeCancellationAndTimeoutWrapperInput
    // >(
    //   input.foo + "barString",
    //   input.cTSToken,
    //   input.delayDurationForDemonstrationTesting,
    // );
    // return {
    //   bar: _result.outputString,
    //   isCancelled: _result.isCancelled,
    //   isTimeout: _result.isTimeout,
    //   error: void 0,
    // } as IC1ActorOutput;
    //} catch (e) {
    //  throw e; // this ensures that the event "xstate.error.actor.c1Actor" is returned, if using try/catch
    // the following code is commented out because inside the catch block, returning an instance of IC1ActorOutput
    //   causes the type of event returned to be "xstate.done.actor.c1Actor" instead of "xstate.error.actor.c1Actor"
    // if (e instanceof Error) {
    //   return {
    //     bar: void 0,
    //     isCancelled: false,
    //     isTimeout: false,
    //     error: e,
    //   } as IC1ActorOutput;
    // } else {
    //   console.log(
    //     `c1Actor failed, caught unknown type of instance of (e), type is ${typeof e}`,
    //   );
    //   throw new Error(
    //     `c1Actor failed, caught unknown type of instance of (e), type is ${typeof e}`,
    //   );
    // }
    //}
  },
);

interface IC1MachineInput extends IC1ActorInput {
  logger?: ILogger;
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

interface IC1MachineDisposeActionParameters {
  context: IC1MachineContext;
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
    c1MachineDisposeAction: ($_, params: IC1MachineDisposeActionParameters) => {
      return produce(params.context, (draft) => {
        // release the reference to the parent object
        draft.parent = void 0;
        // release the reference to the logger object
        draft.logger = void 0;
      });
    },
  },
}).createMachine({
  // cspell:disable
  /** @xstate-layout N4IgpgJg5mDOIC5gF8A0IB2B7CdGgGMBGAWQEMCALASwzHxAActZqAXarDBgD0SIBM6AJ78ByCciA */
  // cspell:enable
  id: "c1Machine",
  context: ({ input }) =>
    ({
      logger: new Logger(input.logger, "c1Machine"),
      parent: input.parent,
      foo: input.foo,
      cTSToken: input.cTSToken,
      timeoutLimit: input.timeoutLimit,
      delayDurationForDemonstrationTesting:
        input.delayDurationForDemonstrationTesting,
      bar: void 0,
      isCancelled: false,
      isTimeout: false,
      error: void 0,
      c1TerminatingEvent: void 0,
    }) as IC1MachineContext,
  output: ({ context }) =>
    ({
      bar: context.bar,
      isTimeout: context.isTimeout,
      isCancelled: context.isCancelled,
      error: context.error,
      c1TerminatingEvent: context.c1TerminatingEvent,
    }) as IC1MachineOutput,
  initial: "c1State",
  states: {
    c1State: {
      entry: [
        ({ context }) => {
          context.logger!.log(
            `c1State entry action, context: ${JSON.stringify(context)}`,
            LogLevel.Debug,
          );
        },
      ],
      invoke: {
        id: "c1Actor",
        src: "c1Actor",
        input: ({ context }) =>
          ({
            foo: context.foo,
            cTSToken: context.cTSToken,
            timeoutLimit: context.timeoutLimit,
            delayDurationForDemonstrationTesting:
              context.delayDurationForDemonstrationTesting,
          }) as IC1ActorInput,
        onDone: {
          target: "doneState",
          actions: [
            ({ context }) => {
              context.logger!.log(
                `c1State starting onDone transition action, context: ${JSON.stringify(context)}`,
                LogLevel.Debug,
              );
            },
            {
              type: "assignC1ActorOutputToParentContext",
              params: ({ context, event }) =>
                ({
                  context: context,
                  bar: event.output.bar,
                  isTimeout: event.output.isTimeout,
                  isCancelled: event.output.isCancelled,
                  error: void 0,
                  c1TerminatingEvent: event.output.isTimeout
                    ? { type: "C1.TIMEOUT" }
                    : event.output.isCancelled
                      ? { type: "C1.CANCELLED" }
                      : { type: "C1.DONE" },
                }) as IAssignC1ActorOutputToParentContextActionParameters,
            },
            ({ context }) => {
              context.logger!.log(
                `c1State ending onDone transition action, context: ${JSON.stringify(context)}`,
                LogLevel.Debug,
              );
            },
          ],
        },
        onError: {
          target: "doneState",
          actions: [
            ({ context }) => {
              context.logger!.log(
                `c1State starting onError transition action, context: ${JSON.stringify(context)}`,
                LogLevel.Debug,
              );
            },
            {
              type: "assignC1ActorOutputToParentContext",
              params: ({ context, event }) =>
                ({
                  context: context,
                  bar: void 0,
                  isTimeout: false,
                  isCancelled: false,
                  error: event.error,
                  c1TerminatingEvent: { type: "C1.ERROR" },
                }) as IAssignC1ActorOutputToParentContextActionParameters,
            },
            ({ context }) => {
              context.logger!.log(
                `c1State ending onError transition action, context: ${JSON.stringify(context)}`,
                LogLevel.Debug,
              );
            },
          ],
        },
      },
    },
    doneState: {
      type: "final",
      entry: [
        ({ context }) => {
          context.logger!.log(
            `c1Machine doneState entry actions, at start context = ${JSON.stringify(context)}`,
            LogLevel.Debug,
          );
        },
        {
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
        ({ context }) => {
          context.logger!.log(
            `c1Machine doneState entry actions, at near-end context: ${JSON.stringify(context)}`,
            LogLevel.Debug,
          );
        },
        // No logging is possible after this action executes, because the logger is disposed
        {
          type: "c1MachineDisposeAction",
          params: ({ context }) =>
            ({
              context: context,
            }) as IC1MachineDisposeActionParameters,
        },
      ],
    },
  },
});

export interface IPrimaryMachineInput {
  logger: ILogger;
}
interface IPrimaryMachineOutput {}
interface IC1MachineContributionToParentContext
  extends Omit<IC1MachineInput, "logger">,
    IC1MachineOutput {
  actorRef?: ActorRef<any, any>;
  subscriptionLogger?: ILogger;
  subscription?: any;
}

// ToDo: use this when the spawn and assign's are moved from being inline up to the primaryMachine's setups' actions..
// This is not currently correct, just a placeholder
// interface ISpawnC1MachineActionParameters extends IC1MachineInput {
//   context: IPrimaryMachineContext;
// }

interface IPrimaryMachineContext
  extends IPrimaryMachineInput,
    IPrimaryMachineOutput {
  c1: IC1MachineContributionToParentContext;
}
export interface IC1STARTEventPayload {
  foo: string;
  cTSToken?: CancellationToken;
  timeoutLimit?: number;
  delayDurationForDemonstrationTesting?: number;
}
type PMMachineAllEventsUnionT =
  | {
      type: "C1.START";
      payload: IC1STARTEventPayload;
    }
  | C1MachineCompletionEventsUnionT;

interface IAssignC1MachineOutputToParentContextActionParameters {
  context: IPrimaryMachineContext;
  c1MachineOutput: IC1MachineOutput;
}
/******************************************************************************************************************** */
// The primaryMachine is the parent machine that spawns the c1Machine
export const primaryMachine = setup({
  types: {} as {
    input: IPrimaryMachineInput;
    output: IPrimaryMachineOutput;
    context: IPrimaryMachineContext;
    events: PMMachineAllEventsUnionT;
  },
  actors: {
    c1Machine: C1Machine,
  },
  actions: {
    // eventually move the inline action up to this level
    // ToDo: use something like the commented section below when the spawn and assign's are moved from
    //    being inline up to the primaryMachine's setups' actions..
    // // spawn the c1Machine
    // //   the machine's input parameters come from the .START event payload and from this machine as parent
    // //   the machine's input is passed to this action via the parameters
    // //   assign the machine's input parameters to the parent context's fields
    // //   clear the machine's output fields in the parent context
    // //   spawn the c1Machine and assign its actorRef to the parent context
    // spawnC1Machine: assign((_, params: ISpawnC1MachineActionParameters) => {
    //   return produce(params.context, (draft) => {
    //     draft.c1.foo = params.foo;
    //     //draft.c1.cTSToken = params.cTSToken;
    //     draft.c1.bar = void 0;
    //     draft.c1.error = void 0;
    //     draft.c1.actorRef = params.spawn("c1Machine", {
    //       systemId: "c1Machine",
    //       id: "c1Machine",
    //       input: {
    //         logger: params.logger,
    //         parent: params.parent,
    //         foo: params.foo,
    //         //cTSToken: params.cTSToken,
    //       } as IC1MachineInput,
    //     });
    //   });
    // }),

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
          // remove reference to the subscriptionlogger (prevent leaks)
          draft.c1.subscriptionLogger = void 0;
          // unsubscribe from the childMachine actor (prevent leaks)
          draft.c1.subscription.unsubscribe();
          // remove reference to the subscription (prevent leaks)
          draft.c1.subscription = void 0;
          // remove reference to the actorRef (prevent leaks)
          draft.c1.actorRef = void 0;
        });
      },
    ),
  },
}).createMachine({
  // cspell:disable
  /** @xstate-layout N4IgpgJg5mDOIC5QAcBOBLAtgQ1QTwFlsBjAC3QDswA6dCAGzAGIBhARmoGUAVAQQCVuAbQAMAXUQoA9rHQAXdFIqSQAD0Rs2I6iIAsANgAc+rQE5TAJgDM+3YYA0IPBoDs+6lZGmRbAxdOGAboAvsGOaFi4hCTkVLQMzOzUACIA8gByAKKiEkggyDLyisp56gi6Fo7OCIYcegCsbFZs9SIiVgGGIaGOFFIQcCoROPhEZJRgQ4UKSiplALT6VYiLPfkYI9HjcXSMU7IzJaBlTYbU+jYWLlb1ulZ2N8sIV+71LhaBLi71ph0upvpQqEgA */
  // cspell:enable
  id: "parentChildDemoMachine",
  context: ({ input }) =>
    ({
      logger: new Logger(input.logger, "parentChildDemoMachine"),
      c1: {
        parent: void 0,
        foo: void 0,
        delayDurationForDemonstrationTesting: void 0,
        bar: void 0,
        isTimeout: false,
        isCancelled: false,
        error: void 0,
        c1TerminatingEvent: void 0,
        actorRef: void 0,
        subscription: void 0,
      } as IC1MachineContributionToParentContext,
    }) as IPrimaryMachineContext,
  initial: "idle",
  states: {
    idle: {
      reenter: true,
      entry: [
        ({ context }) => {
          context.logger.log("idle state entry", LogLevel.Debug);
        },
      ],
      on: {
        "C1.START": {
          target: "idle",
          reenter: true,
          actions: [
            ({ context }) => {
              context.logger.log(
                `C1.START Transition Action starting, context: ${JSON.stringify(context)}`,
                LogLevel.Debug,
              );
            },
            assign(({ context, spawn, event, self }) => {
              return produce(context, (draft) => {
                draft.c1.foo = event.payload.foo;
                draft.c1.cTSToken = event.payload.cTSToken;
                draft.c1.timeoutLimit = event.payload.timeoutLimit;
                draft.c1.bar = void 0;
                draft.c1.isCancelled = false;
                draft.c1.isTimeout = false;
                draft.c1.error = void 0;
                // when the action runs, spawn the childMachine
                draft.c1.actorRef = spawn("c1Machine", {
                  systemId: "c1Machine",
                  id: "c1Machine",
                  input: {
                    logger: context.logger,
                    parent: self,
                    foo: event.payload.foo,
                    cTSToken: event.payload.cTSToken,
                    timeoutLimit: event.payload.timeoutLimit,
                    delayDurationForDemonstrationTesting:
                      event.payload.delayDurationForDemonstrationTesting,
                  } as IC1MachineInput,
                });
                // create a scoped logger for the subscription to the childMachine
                draft.c1.subscriptionLogger = new Logger(
                  context.logger,
                  "c1MachineSubscription",
                );
                // subscribe to the childMachine
                draft.c1.subscription = draft.c1.actorRef.subscribe((s) => {
                  // first, the option to log everything the subscription sees
                  draft.c1.subscriptionLogger!.log(
                    JSON.stringify(s),
                    LogLevel.Debug,
                  );
                  // ToDo: pick out errors thrown from the childMachine and handle them
                });
              });
            }),
            ({ context }) => {
              context.logger.log(
                `C1.START Transition Action ending, context: ${JSON.stringify(context)}`,
                LogLevel.Debug,
              );
            },
          ],
        },
        "C1.DONE": {
          target: "idle",
          reenter: true,
          actions: [
            ({ context }) => {
              context.logger.log(
                `C1.Done Transition Action starting, context: ${JSON.stringify(context)}`,
                LogLevel.Debug,
              );
              context.logger.log(
                `C1.Done Transition Action. c1 snapshot: ${JSON.stringify(context.c1.actorRef?.getSnapshot())}`,
                LogLevel.Debug,
              );
            },
            {
              type: "assignC1MachineOutputToParentContext",
              params: ({ context }) =>
                ({
                  context: context,
                  c1MachineOutput: context.c1.actorRef?.getSnapshot().output,
                }) as IAssignC1MachineOutputToParentContextActionParameters,
            },
            ({ context }) => {
              const errMsg = context.c1.error?.message;
              // This proves that the error object exists on the context and has a message property
              context.logger.log(
                `C1.Done Transition Action ending. error.message after assign ${errMsg}`,
                LogLevel.Debug,
              );
              // In the logs, the context.error object looks empty here, but it is not. It can be viewed in the debugger
              //  but not stringified.  The following stack overflow answer explins why:
              //  [not possible to stringify an Error instance](https://stackoverflow.com/questions/18391212/is-it-not-possible-to-stringify-an-error-using-json-stringify)
              context.logger.log(
                `C1.Done Transition Action ending, context: ${JSON.stringify(context)}`,
                LogLevel.Debug,
              );
            },
          ],
        },
      },
    },
  },
});

export interface IParentChildDemoMachineC1STARTPayload {
  foo: string;
  cTSToken?: CancellationToken;
  timeoutLimit?: number;
  delayDurationForDemonstrationTesting: number;
}
