import { LogLevel, ILogger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { IStateMachineService } from '@StateMachineService/index';

import { ActorRef, assertEvent, assign, fromPromise, OutputFrom, sendTo, setup } from 'xstate';

export function inspector(logger: ILogger, inspEvent: any): void {
  let _eventInput = '';
  let _eventData = '';
  let _eventOutput = '';
  let _inspEventEventType = '';
  let _message: string = `StateMachineService ${inspEvent.type} actor: ${inspEvent.actorRef.id}`;
  if (inspEvent.type === '@xstate.snapshot') {
    switch (inspEvent.event.type) {
      case 'xstate.init':
      case 'xstate.promise.resolve':
      case 'xstate.promise.reject ':
      case 'QUERY_START':
      case 'QUERY_DONE':
      case 'QUICKPICK_START':
      case 'QUICKPICK_DONE':
      case 'xstate.done.actor.gatheringActor':
      case 'xstate.done.actor.quickPickActor':
      case 'xstate.done.actor.quickPickMachine':
      case 'xstate.done.actor.querySingleEngineActor':
      case 'xstate.done.actor.querySingleEngineMachine':
        _message += ` event.type: ${inspEvent.event.type}`;
        break;
      case 'xstate.error.actor.queryMachine':
      case 'xstate.error.actor.gatheringActor':
      case 'xstate.error.actor.quickPickActor':
      case 'xstate.error.actor.quickPickMachine':
      case 'xstate.error.actor.querySingleEngineActor':
        _message += ` event.type: ${inspEvent.event.type} errorMessage: ${inspEvent.event.error.message}`;
        break;
      default:
        _message += ` event.type: ${inspEvent.event.type} (UNKNOWN)`;
    }
    _message += ` snapshot.status: ${inspEvent.snapshot.status}`;
    // ToDO: add more detail around event payload/input/output/data
    // +message += `event_input: ${inspEvent.event.input}` : ''}${inspEvent.event.output ? `event_output: ${inspEvent.event.output}` : ''`}
  } else if (inspEvent.type === '@xstate.actor') {
    _message += ` referringActor: ${inspEvent.actorRef._parent?.id}`;
  } else if (inspEvent.type === '@xstate.event') {
    switch (inspEvent.event.type) {
      case 'xstate.init':
      case 'xstate.promise.resolve':
      case 'xstate.promise.reject':
      case 'QUERY_START':
      case 'QUERY_DONE':
      case 'QUICKPICK_START':
      case 'QUICKPICK_DONE':
      case 'xstate.done.actor.quickPickMachine':
      case 'xstate.done.actor.quickPickActor':
      case 'xstate.done.actor.queryMachine':
      case 'xstate.done.actor.gatheringActor':
      case 'xstate.done.actor.querySingleEngineActor':
      case 'xstate.done.actor.querySingleEngineMachine':
        _message += ` event.type: ${inspEvent.event.type}`;
        break;
      case 'xstate.error.actor.quickPickMachine':
      case 'xstate.error.actor.quickPickActor':
      case 'xstate.error.actor.queryMachine':
      case 'xstate.error.actor.gatheringActor':
      case 'xstate.error.actor.querySingleEngineActor':
      case 'xstate.error.actor.querySingleEngineMachine':
        _message += ` event.type: ${inspEvent.event.type} errorMessage: ${inspEvent.event.error.message}`;
        break;
      default:
        _message += ` event.type: ${inspEvent.event.type} (UNKNOWN)`;
      // ToDO: add more detail around event payload/input/output/data
      // +message += `event_input: ${inspEvent.event.input}` : ''}${inspEvent.event.output ? `event_output: ${inspEvent.event.output}` : ''`}
      // ${inspEvent.event.input ? `event_input: ${inspEvent.event.input}` : ''}${inspEvent.event.data ? `event_data: ${inspEvent.event.data}` : ''}${inspEvent.event.output ? `event_output: ${inspEvent.event.output}` : ''}
    }
  } else if (inspEvent.type === '@xstate.action') {
    _message += ` action.type: ${inspEvent.action.type}`;
  } else if (inspEvent.type === '@xstate.microstep') {
    // ToDo: deal with multiple transitions, no target, multiple targets, and guards
    if (inspEvent._transitions.length) {
      _message += ` transitions: ${inspEvent._transitions[0].source.key} -> ${inspEvent._transitions[0].target![0].key}`;
    } else {
      _message += ` transitions: None`;
    }
  } else {
    _message += ' (UNKNOWN)';
  }
  logger.log(_message, LogLevel.Debug);
}
