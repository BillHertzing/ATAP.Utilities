import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { Actor, createActor, assign, createMachine, fromCallback, StateMachine, fromPromise } from 'xstate';
import { PrimaryMachineContextT } from './primaryMachineTypes';

export enum SaveFileEnumeration {
  TagsCollection = 'TagsCollection',
  CategoryCollection = 'CategoryCollection',
}

export type SaveFileInputT = PrimaryMachineContextT & {
  filePath: string;
  collectionEnumeration: SaveFileEnumeration;
};
export const saveFileActorLogic = fromPromise(async ({ input }: { input: SaveFileInputT }) => {
  input.logger.log(`saveFileActor called`, LogLevel.Debug);
  switch (input.collectionEnumeration) {
  }

  await true;
});
