import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { Actor, createActor, assign, createMachine, fromCallback, StateMachine, fromPromise } from 'xstate';
import { MachineContextT } from '@StateMachineService/index';

export enum SaveFileEnumeration {
  TagsCollection = 'TagsCollection',
  CategoryCollection = 'CategoryCollection',
}

export type SaveFileInputT = MachineContextT & {
  filePath: string;
  collectionEnumeration: SaveFileEnumeration;
};
export const saveFileActorLogic = fromPromise(async ({ input }: { input: SaveFileInputT }) => {
  input.logger.log(`saveFileActor called`, LogLevel.Debug);
  switch (input.collectionEnumeration) {
  }
  //   let quickPickItems: vscode.QuickPickItem[] = input.data.pickItems.modeMenuItems;
  //   let prompt: string = `currentMode is ${input.data.stateManager.currentMode}, select from list below to change it`;
  //   const pick = await vscode.window.quickPick(quickPickItems, {
  //     placeHolder: prompt,
  //   });
  //   if (pick !== undefined) {
  //     input.data.stateManager.currentMode = pick.label as ModeMenuItemEnum;
  //   }

  await true;
});
