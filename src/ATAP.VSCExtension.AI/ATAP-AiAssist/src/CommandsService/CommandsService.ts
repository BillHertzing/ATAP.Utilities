import { LogLevel, ILogger, Logger } from '@Logger/index';
import * as vscode from 'vscode';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor } from '@Decorators/index';

import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';
import { IQueryService } from '@QueryService/index';

import { startCommand } from './startCommand';
import { showVSCEnvironment } from './showVSCEnvironment';
import { showPrompt } from './showPrompt';

import { showStatusMenuAsync } from './showStatusMenuAsync';
import { showModeMenuAsync } from './showModeMenuAsync';
import { showCommandMenuAsync } from './showCommandMenuAsync';
import {
  StatusMenuItemEnum,
  ModeMenuItemEnum,
  CommandMenuItemEnum,
  IPickItemsInitializer,
} from '@StateMachineService/index';
import {
  saveTagCollectionAsync,
  saveCategoryCollectionAsync,
  saveAssociationCollectionAsync,
  saveConversationCollectionAsync,
} from './saveCollectionAsync';
import { copyToSubmit } from './copyToSubmit';

@logConstructor
export class CommandsService {
  private disposables: vscode.Disposable[] = [];

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    private data: IData,
    private queryService: IQueryService,
    private pickItemsInitializer: IPickItemsInitializer,
  ) {
    this.registerCommands();
  }

  private registerCommands(): void {
    this.logger.log('starting registerCommands', LogLevel.Debug);

    this.logger.log('registering showVSCEnvironment', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showVSCEnvironment', () => {
        let message: string = 'starting commandID showVSCEnvironment';
        this.logger.log(message, LogLevel.Debug);
        showVSCEnvironment(this.logger);
      }),
    );

    this.logger.log('registering showPrompt', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showPrompt', async () => {
        this.logger.log('starting commandID showPrompt', LogLevel.Debug);
        try {
          const result = await showPrompt(this.logger, this.data);
          // this.logger.log(`result.success = ${result.success}, result `, LogLevel.Debug);
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError('Command showPrompt caught an error from function showPrompt -> ', e);
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `Command showPrompt caught an unknown object from function showPrompt, and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
      }),
    );

    this.logger.log('registering sendQuery', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.sendQuery', async () => {
        this.logger.log('starting commandID sendQuery', LogLevel.Debug);
        //change the visualstate of the statusBarItem
        // Event fired
        //statusBarItem.text = `$(sync~spin) Event Initializing`;
        //statusBarItem.show();
        try {
          await this.queryService.QueryAsync();
          // this.logger.log(`result.success = ${result.success}, result `, LogLevel.Debug);
        } catch (e) {
          // This is the top level of the command, so we need to catch any errors that are thrown and handle them, not rethrow them
          if (e instanceof Error) {
            this.logger.log(`Command sendQuery caught an error from function sendQuery: ${e.message}`, LogLevel.Error);
            // ToDo: display a visual error indicator to the user
          } else {
            // ToDo:  investigation to determine what else might happen
            this.logger.log(
              `Command sendQuery caught an unknown object from function sendQuery, and the instance of (e) returned is of type ${typeof e}`,
              LogLevel.Error,
            );
            // ToDo: display a visual error indicator to the user
          }
        }
      }),
    );

    this.logger.log('registering startCommand', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.startCommand', () => {
        let message: string = 'starting commandID startCommand';
        this.logger.log(message, LogLevel.Debug);
        startCommand(this.logger);
      }),
    );

    // register the command to show the status menu
    this.logger.log('registering showStatusMenuAsync', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showStatusMenuAsync', async () => {
        this.logger.log('starting commandID showStatusMenuAsync', LogLevel.Debug);
        let result: StatusMenuItemEnum | null = null;
        try {
          const _result = await showStatusMenuAsync(this.logger, this.data, this.pickItemsInitializer);
          this.logger.log(
            `result.success = ${_result.success}, result.statusMenuItem = ${_result.statusMenuItem?.toString()} `,
            LogLevel.Debug,
          );
          if (_result.success) {
            result = _result.statusMenuItem;
          } else {
            this.logger.log('showStatusMenuAsync was cancelled', LogLevel.Debug);
          }
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              'atap-aiassist.showStatusMenuAsync function showStatusMenuAsync returned an error -> ',
              e,
            );
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `atap-aiassist.showStatusMenuAsync function showStatusMenuAsync returned an error, and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
        // ToDo: fire an event to handle the results of the quickPick
        this.data.eventManager.getEventEmitter().emit('ExternalDataReceived', result, 'handleStatusMenuResults');
      }),
    );

    // register the command to show the Mode menu
    this.logger.log('registering showModeMenuAsync', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showModeMenuAsync', async () => {
        this.logger.log('starting commandID showModeMenuAsync', LogLevel.Debug);
        let result: ModeMenuItemEnum | null = null;
        try {
          const _result = await showModeMenuAsync(this.logger, this.data, this.pickItemsInitializer);
          this.logger.log(
            `result.success = ${_result.success}, result.modeMenuItem = ${_result.modeMenuItem?.toString()} `,
            LogLevel.Debug,
          );
          if (_result.success) {
            result = _result.modeMenuItem;
            // ToDo: fire an event to handle the results of the quickPick
            this.data.eventManager.getEventEmitter().emit('ExternalDataReceived', result, 'handleModeMenuResults');
          } else {
            this.logger.log('showModeMenuAsync was cancelled', LogLevel.Debug);
          }
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              'atap-aiassist.showModeMenuAsync function showModeMenuAsync returned an error -> ',
              e,
            );
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `atap-aiassist.showModeMenuAsync function showModeMenuAsync returned an error, and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
      }),
    );

    // register the command to show the Command menu
    this.logger.log('registering showCommandMenuAsync', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showCommandMenuAsync', async () => {
        this.logger.log('starting commandID showCommandMenuAsync', LogLevel.Debug);
        let result: CommandMenuItemEnum | null = null;
        try {
          const _result = await showCommandMenuAsync(this.logger, this.data, this.pickItemsInitializer);
          this.logger.log(
            `result.success = ${_result.success}, result.commandMenuItem = ${_result.commandMenuItem?.toString()} `,
            LogLevel.Debug,
          );
          if (_result.success) {
            result = _result.commandMenuItem;
          } else {
            this.logger.log('showCommandMenuAsync was cancelled', LogLevel.Debug);
          }
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              'atap-aiassist.showCommandMenuAsync function showCommandMenuAsync returned an error -> ',
              e,
            );
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `atap-aiassist.showCommandMenuAsync function showCommandMenuAsync returned an error, and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
        // ToDo: fire an event to handle the results of the quickPick
        this.data.eventManager.getEventEmitter().emit('ExternalDataReceived', result, 'handleCommandMenuResults');
      }),
    );

    // register the command to save the tag collection
    this.logger.log('registering saveTagCollectionAsync', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.saveTagCollectionAsync', async () => {
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
      vscode.commands.registerCommand('atap-aiassist.saveCategoryCollectionAsync', async () => {
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
      vscode.commands.registerCommand('atap-aiassist.saveAssociationCollectionAsync', async () => {
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
      vscode.commands.registerCommand('atap-aiassist.saveConversationCollectionAsync', async () => {
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
    // this.message = 'registering copyToSubmit';
    // this.logger.log(this.message, LogLevel.Debug);
    // this.disposables.push(
    //   vscode.commands.registerCommand('atap-aiassist.copyToSubmit', async () => {
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
    //   'atap-aiassist.showMainViewRootRecordProperties',
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
    //   'atap-aiassist.showSubItemProperties',
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
    // let removeRegionDisposable = vscode.commands.registerCommand('atap-aiassist.removeRegion', () => {
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
    //   'atap-aiassist.processPs1Files',
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
    //   'atap-aiassist.showExplorerView',
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
