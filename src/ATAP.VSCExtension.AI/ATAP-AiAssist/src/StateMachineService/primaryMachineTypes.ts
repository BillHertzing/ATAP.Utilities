import { LoggerDataT } from '@StateMachineService/index';
import { QuickPickMachineComponentOfPrimaryMachineContextT } from './quickPickTypes';
import { QueryMachineComponentOfPrimaryMachineContextT } from './queryTypes';

export type PrimaryMachineContextT = LoggerDataT &
  QuickPickMachineComponentOfPrimaryMachineContextT &
  QueryMachineComponentOfPrimaryMachineContextT;
