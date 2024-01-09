import { LogLevel, ILogger, Logger } from '@Logger/index';
import * as vscode from 'vscode';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor } from '@Decorators/index';

import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';
import { IQueryService } from '@QueryService/index';

import { startCommand } from './startCommand';
import { showVSCEnvironment } from './showVSCEnvironment';

import {
  StatusMenuItemEnum,
  ModeMenuItemEnum,
  CommandMenuItemEnum,
  IStateMachineService,
} from '@StateMachineService/index';
import {
  saveTagCollectionAsync,
  saveCategoryCollectionAsync,
  saveAssociationCollectionAsync,
  saveConversationCollectionAsync,
} from './saveCollectionAsync';
import { copyToSubmit } from './copyToSubmit';
import { stat } from 'fs';
import { QuickPickEnumeration } from '@StateMachineService/PrimaryMachine';

export interface ICommandsService {
  readonly stateMachineService: IStateMachineService;
  getDisposables(): vscode.Disposable[];
}

@logConstructor
export class CommandsService {
  private disposables: vscode.Disposable[] = [];
  private readonly extensionID: string;
  private readonly extensionName: string;
  private _stateMachineService: IStateMachineService | null = null;

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    private data: IData,
    private stateMachineService: IStateMachineService,
  ) {
    this.extensionID = extensionContext.extension.id;
    this.extensionName = this.extensionID.split('.')[1];
    this.registerCommands();
  }

  private registerCommands(): void {
    this.logger.log('starting registerCommands', LogLevel.Debug);

    this.logger.log('registering showVSCEnvironment', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.showVSCEnvironment`, () => {
        let message: string = 'starting commandID showVSCEnvironment';
        this.logger.log(message, LogLevel.Debug);
        showVSCEnvironment(this.logger);
      }),
    );

    // this.logger.log('registering showPrompt', LogLevel.Debug);
    // this.disposables.push(
    //   vscode.commands.registerCommand('atap-aiassist.showPrompt', async () => {
    //     this.logger.log('starting commandID showPrompt', LogLevel.Debug);
    //     try {
    //       const result = await showPrompt(this.logger, this.data);
    //       // this.logger.log(`result.success = ${result.success}, result `, LogLevel.Debug);
    //     } catch (e) {
    //       if (e instanceof Error) {
    //         throw new DetailedError('Command showPrompt caught an error from function showPrompt -> ', e);
    //       } else {
    //         // ToDo:  investigation to determine what else might happen
    //         throw new Error(
    //           `Command showPrompt caught an unknown object from function showPrompt, and the instance of (e) returned is of type ${typeof e}`,
    //         );
    //       }
    //     }
    //   }),
    // );

    // this.logger.log('registering sendQuery', LogLevel.Debug);
    // this.disposables.push(
    //   vscode.commands.registerCommand(`${this.extensionName}.sendQuery`, async () => {
    //     this.logger.log('starting commandID sendQuery', LogLevel.Debug);
    //     try {
    //       await this.queryService.QueryAsync();
    //       // this.logger.log(`result.success = ${result.success}, result `, LogLevel.Debug);
    //     } catch (e) {
    //       // This is the top level of the command, so we need to catch any errors that are thrown and handle them, not rethrow them
    //       if (e instanceof Error) {
    //         this.logger.log(`Command sendQuery caught an error from function sendQuery: ${e.message}`, LogLevel.Error);
    //         // ToDo: display a visual error indicator to the user
    //       } else {
    //         // ToDo:  investigation to determine what else might happen
    //         this.logger.log(
    //           `Command sendQuery caught an unknown object from function sendQuery, and the instance of (e) returned is of type ${typeof e}`,
    //           LogLevel.Error,
    //         );
    //         // ToDo: display a visual error indicator to the user
    //       }
    //     }
    //   }),
    // );

    this.logger.log('registering startCommand', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.startCommand`, () => {
        let message: string = 'starting commandID startCommand';
        this.logger.log(message, LogLevel.Debug);
        startCommand(this.logger);
      }),
    );

    // register the command to save the tag collection
    this.logger.log('registering saveTagCollectionAsync', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.saveTagCollectionAsync`, async () => {
        this.logger.log('starting commandID saveTagCollectionAsync', LogLevel.Debug);
        try {
          await saveTagCollectionAsync(this.logger, this.data);
          this.logger.log(`saveTagCollectionAsync completed} `, LogLevel.Debug);
        } catch (e) {
          HandleError(e, 'commandsService', 'saveTagCollectionAsync', 'failed calling saveTagCollectionAsync');
        }
        // Add the event that makes the tag editor go from dirty to clean
        // this.data.eventManager.getEventEmitter().emit('ExternalDataReceived', 'saveTagCollectionAsyncCompleted');
      }),
    );

    // register the command to save the category collection
    this.logger.log('registering saveCategoryCollectionAsync', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.saveCategoryCollectionAsync`, async () => {
        this.logger.log('starting commandID saveCategoryCollectionAsync', LogLevel.Debug);
        try {
          await saveCategoryCollectionAsync(this.logger, this.data);
          this.logger.log(`saveCategoryCollectionAsync completed} `, LogLevel.Debug);
        } catch (e) {
          HandleError(
            e,
            'commandsService',
            'saveCategoryCollectionAsync',
            'failed calling saveCategoryCollectionAsync',
          );
        }
        // Add the event that makes the category editor go from dirty to clean
        // this.data.eventManager.getEventEmitter().emit('ExternalDataReceived', 'saveCategoryCollectionAsyncCompleted');
      }),
    );
    // register the command to save the association collection
    this.logger.log('registering saveAssociationCollectionAsync', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.saveAssociationCollectionAsync`, async () => {
        this.logger.log('starting commandID saveAssociationCollectionAsync', LogLevel.Debug);
        try {
          await saveAssociationCollectionAsync(this.logger, this.data);
          this.logger.log(`saveAssociationCollectionAsync completed} `, LogLevel.Debug);
        } catch (e) {
          HandleError(
            e,
            'commandsService',
            'saveAssociationCollectionAsync',
            'failed calling saveAssociationCollectionAsync',
          );
        }
        // Add the event that makes the association editor go from dirty to clean
        // this.data.eventManager.getEventEmitter().emit('ExternalDataReceived', 'saveAssociationCollectionAsyncCompleted');
      }),
    );
    // register the command to save the Conversation collection
    this.logger.log('registering saveConversationCollectionAsync', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.saveConversationCollectionAsync`, async () => {
        this.logger.log('starting commandID saveConversationCollectionAsync', LogLevel.Debug);
        try {
          await saveConversationCollectionAsync(this.logger, this.data);
          this.logger.log(`saveConversationCollectionAsync completed} `, LogLevel.Debug);
        } catch (e) {
          HandleError(
            e,
            'commandsService',
            'saveConversationCollectionAsync',
            'failed calling saveConversationCollectionAsync',
          );
        }
        // Add the event that makes the Conversation editor go from dirty to clean
        // this.data.eventManager.getEventEmitter().emit('ExternalDataReceived', 'saveConversationCollectionAsyncCompleted');
      }),
    );

    // ************************************************************ //
    // register the command to send the quickPick event (with kindOfQuickPick=Status) to the primaryActor
    this.logger.log('registering primaryActor.quickPickStatus', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.primaryActor.quickPickStatus`, () => {
        this.logger.log('starting commandService.primaryActor.quickPickStatus (FireAndForget)', LogLevel.Debug);
        try {
          this.stateMachineService.quickPick(QuickPickEnumeration.StatusMenuItemEnum);
        } catch (e) {
          HandleError(e, 'commandsService', 'primaryActor.quickPickStatus', 'failed calling primaryActor C1');
        }
      }),
    );
    // register the command to send the quickPick event (with kindOfQuickPick=Mode) to the primaryActor
    this.logger.log('registering primaryActor.quickPickMode', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.primaryActor.quickPickMode`, () => {
        this.logger.log('starting commandService.primaryActor.quickPickMode (FireAndForget)', LogLevel.Debug);
        try {
          this.stateMachineService.quickPick(QuickPickEnumeration.ModeMenuItemEnum);
        } catch (e) {
          HandleError(e, 'commandsService', 'primaryActor.quickPickMode', 'failed calling primaryActor C1');
        }
      }),
    );
    // register the command to send the quickPick event (with kindOfQuickPick=Command) to the primaryActor
    this.logger.log('registering primaryActor.quickPickCommand', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.primaryActor.quickPickCommand`, () => {
        this.logger.log('starting commandService.primaryActor.quickPickCommand (FireAndForget)', LogLevel.Debug);
        try {
          this.stateMachineService.quickPick(QuickPickEnumeration.CommandMenuItemEnum);
        } catch (e) {
          HandleError(e, 'commandsService', 'primaryActor.quickPickCommand', 'failed calling primaryActor C1');
        }
      }),
    );
    // this.message = 'registering copyToSubmit';
    // this.logger.log(this.message, LogLevel.Debug);
    // this.disposables.push(
    //   vscode.commands.registerCommand(`${this.extensionName}.copyToSubmit`, async () => {
    //     let message: string = 'starting commandID copyToSubmit';
    //     this.logger.log(message, LogLevel.Debug);
    //     try {
    //       const result = await copyToSubmit(this.context, this.logger);
    //       message = `result.success = ${result.success}, result `;
    //       this.logger.log(message, LogLevel.Debug);
    //     } catch (e) {
    //       if (e instanceof Error) {
    //         // Report the error
    //         message = e.message;
    //       } else {
    //         // ToDo: e is not an instance of Error, needs investigation to determine what else might happen
    //         message = `An unknown error occurred during the copyToSubmit call, and the instance of (e) returned is of type ${typeof e}`;
    //       }
    //       this.logger.log(message, LogLevel.Error);
    //     }
    //   }),
    // );

    // // *************************************************************** //
    // let showMainViewRootRecordPropertiesDisposable = vscode.commands.registerCommand(
    //   `${this.extensionName}.showMainViewRootRecordProperties`,
    //   (item: mainViewTreeItem) => {
    //     let message: string = 'starting commandID showMainViewRootRecordProperties';
    //     myLogger.log(message, LogLevel.Debug);
    //     if (item === null) {
    //       message = `item is null`;
    //       myLogger.log(message, LogLevel.Debug);
    //     } else {
    //       message = `item is NOT null`;
    //       myLogger.log(message, LogLevel.Debug);
    //     }
    //     // message = `Philote_ID = ${item.Philote_ID} : pickedvalue = ${item.pickedValue}; properties = ${item.properties}`;
    //     // myLogger.log(message, LogLevel.Debug);
    //     message = `stringified item.properties = ${JSON.stringify(item.properties)}`;
    //     myLogger.log(message, LogLevel.Debug);
    //     vscode.window.showInformationMessage(JSON.stringify(item.properties));
    //   },
    // );
    // extensionContext.subscriptions.push(showMainViewRootRecordPropertiesDisposable);

    // // *************************************************************** //
    // let showSubItemPropertiesDisposable = vscode.commands.registerCommand(
    //   `${this.extensionName}.showSubItemProperties`,
    //   (item: mainViewTreeItem) => {
    //     let message: string = 'starting commandID showSubItemProperties';
    //     myLogger.log(message, LogLevel.Debug);
    //     // message = `Philote_ID = ${item.Philote_ID} : pickedvalue = ${item.pickedValue}; properties = ${item.properties}`;
    //     // myLogger.log(message, LogLevel.Debug);
    //     message = `stringified item.properties = ${JSON.stringify(item.properties)}`;
    //     myLogger.log(message, LogLevel.Debug);
    //     vscode.window.showInformationMessage(JSON.stringify(item.properties));
    //   },
    // );
    // extensionContext.subscriptions.push(showSubItemPropertiesDisposable);

    // // *************************************************************** //
    // let removeRegionDisposable = vscode.commands.registerCommand(`${this.extensionName}.removeRegion`, () => {
    //   let message: string = 'starting commandID removeRegion';
    //   myLogger.log(message, LogLevel.Debug);

    //   const editor = vscode.window.activeTextEditor;

    //   if (editor) {
    //     const document = editor.document;
    //     const edit = new vscode.WorkspaceEdit();

    //     for (let i = 0; i < document.lineCount; i++) {
    //       const line = document.lineAt(i);

    //       if (line.text.trim().startsWith('#region') || line.text.trim().startsWith('#endregion')) {
    //         const range = line.rangeIncludingLineBreak;
    //         edit.delete(document.uri, range);
    //       }
    //     }

    //     vscode.workspace.applyEdit(edit);
    //   }
    // });
    // extensionContext.subscriptions.push(removeRegionDisposable);

    // // *************************************************************** //
    // let processPs1FilesDisposable = vscode.commands.registerCommand(
    //   `${this.extensionName}.processPs1Files`,
    //   async (commandId: string | null) => {
    //     let message: string = 'starting commandID processPs1Files';
    //     myLogger.log(message, LogLevel.Debug);

    //     const processPs1FilesRecord = await processPs1Files(commandId);
    //     if (processPs1FilesRecord.success) {
    //       message = `processPs1Files processed ${processPs1FilesRecord.numFilesProcessed} files, using commandID  ${processPs1FilesRecord.commandIDUsed}`;
    //       vscode.window.showInformationMessage(`${message}`);
    //     } else {
    //       message = `processPs1Files failed, error message is ${processPs1FilesRecord.errorMessage}, attemptedCommandID is ${processPs1FilesRecord.commandIDUsed}`;
    //       vscode.window.showErrorMessage(`${message}`);
    //     }
    //   },
    // );
    // extensionContext.subscriptions.push(processPs1FilesDisposable);

    // // *************************************************************** //
    // let showExplorerViewDisposable = vscode.commands.registerCommand(
    //   `${this.extensionName}.showExplorerView`,
    //   async (commandId: string | null) => {
    //     let message: string = 'starting commandID showExplorerView';
    //     myLogger.log(message, LogLevel.Debug);

    //     vscode.commands.executeCommand('workbench.view.explorer');
    //     message = 'explorer view should be up';
    //     myLogger.log(message, LogLevel.Debug);
    //   },
    // );
    // extensionContext.subscriptions.push(showExplorerViewDisposable);
  }

  public getDisposables(): vscode.Disposable[] {
    return this.disposables;
  }
}
