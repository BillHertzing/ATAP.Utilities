import * as vscode from 'vscode';
import { copyToSubmit } from './copyToSubmit';
import { stat } from 'fs';

import { LogLevel, ILogger, Logger, IScopedLogger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';
import { IQueryService } from '@QueryService/index';
import { IStateMachineService, QuickPickEventPayloadT } from '@StateMachineService/index';

import { startCommand } from './startCommand';
import { showVSCEnvironment } from './showVSCEnvironment';

import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  VCSCommandMenuItemEnum,
  SupportedSerializersEnum,
  QuickPickEnumeration,
} from '@BaseEnumerations/index';

import { AiAssistCancellationTokenSource } from '@ItemWithIDs/index';

import {
  saveTagCollectionAsync,
  saveCategoryCollectionAsync,
  saveAssociationCollectionAsync,
  saveConversationCollectionAsync,
} from './saveCollectionAsync';

import { QueryEventPayloadT } from '@StateMachineService/index';

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
    private logger: IScopedLogger,
    private extensionContext: vscode.ExtensionContext,
    private data: IData,
    private stateMachineService: IStateMachineService,
  ) {
    this.extensionID = extensionContext.extension.id;
    this.extensionName = this.extensionID.split('.')[1];
    const _cname = this.constructor.name;
    this.logger = {
      scope: `${logger.scope}.CommandsService`,
      log(message: string, logLevel: LogLevel = LogLevel.Info): void {
        logger.logWithScope(message, this.scope, logLevel);
      },
      logWithScope(message: string, scope: string, logLevel: LogLevel = LogLevel.Info): void {
        logger.logWithScope(message, this.scope, logLevel);
      },
    };

    this.registerCommands();
  }

  private registerCommands(): void {
    this.logger.log('starting registerCommands', LogLevel.Trace);

    this.logger.log('registering showVSCEnvironment', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.showVSCEnvironment`, () => {
        let message: string = 'starting commandID showVSCEnvironment';
        this.logger.log(message, LogLevel.Trace);
        showVSCEnvironment(this.logger);
      }),
    );

    // this.logger.log('registering showPrompt', LogLevel.Trace);
    // this.disposables.push(
    //   vscode.commands.registerCommand('atap-aiassist.showPrompt', async () => {
    //     this.logger.log('starting commandID showPrompt', LogLevel.Trace);
    //     try {
    //       const result = await showPrompt(this.logger, this.data);
    //       // this.logger.log(`result.success = ${result.success}, result `, LogLevel.Trace);
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

    this.logger.log('registering startCommand', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.startCommand`, () => {
        let message: string = 'starting commandID startCommand';
        this.logger.log(message, LogLevel.Trace);
        startCommand(this.logger);
      }),
    );

    // register the command to save the tag collection
    this.logger.log('registering saveTagCollectionAsync', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.saveTagCollectionAsync`, async () => {
        this.logger.log('starting commandID saveTagCollectionAsync', LogLevel.Trace);
        try {
          await saveTagCollectionAsync(this.logger, this.data);
          this.logger.log(`saveTagCollectionAsync completed} `, LogLevel.Trace);
        } catch (e) {
          HandleError(e, 'commandsService', 'saveTagCollectionAsync', 'failed calling saveTagCollectionAsync');
        }
        // Add the event that makes the tag editor go from dirty to clean
        // this.data.eventManager.getEventEmitter().emit('ExternalDataReceived', 'saveTagCollectionAsyncCompleted');
      }),
    );

    // register the command to save the category collection
    this.logger.log('registering saveCategoryCollectionAsync', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.saveCategoryCollectionAsync`, async () => {
        this.logger.log('starting commandID saveCategoryCollectionAsync', LogLevel.Trace);
        try {
          await saveCategoryCollectionAsync(this.logger, this.data);
          this.logger.log(`saveCategoryCollectionAsync completed} `, LogLevel.Trace);
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
    this.logger.log('registering saveAssociationCollectionAsync', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.saveAssociationCollectionAsync`, async () => {
        this.logger.log('starting commandID saveAssociationCollectionAsync', LogLevel.Trace);
        try {
          await saveAssociationCollectionAsync(this.logger, this.data);
          this.logger.log(`saveAssociationCollectionAsync completed} `, LogLevel.Trace);
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
    this.logger.log('registering saveConversationCollectionAsync', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.saveConversationCollectionAsync`, async () => {
        this.logger.log('starting commandID saveConversationCollectionAsync', LogLevel.Trace);
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

    // *************************************************************** //
    // register the command to send the quickPick event (with kindOfQuickPick=VCSCommand) to the primaryActor
    this.logger.log('registering primaryActor.quickPickVCSCommand', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.primaryActor.quickPickVCSCommand`, () => {
        this.logger.log('starting commandService.primaryActor.quickPickVCSCommand (FireAndForget)', LogLevel.Debug);
        try {
          this.stateMachineService.quickPick({
            kindOfEnumeration: QuickPickEnumeration.VCSCommandMenuItemEnum,
            cTSId: 'GetARealCTSId',
          });
        } catch (e) {
          HandleError(e, 'commandsService', 'primaryActor.quickPickVCSCommand', 'failed calling primaryActor C1');
        }
      }),
    );
    // register the command to send the quickPick event (with kindOfQuickPick=Mode) to the primaryActor
    this.logger.log('registering primaryActor.quickPickMode', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.primaryActor.quickPickMode`, () => {
        this.logger.log('starting commandService.primaryActor.quickPickMode (FireAndForget)', LogLevel.Trace);
        try {
          this.stateMachineService.quickPick({
            kindOfEnumeration: QuickPickEnumeration.ModeMenuItemEnum,
            cTSId: 'GetARealCTSId',
          });
        } catch (e) {
          HandleError(
            e,
            'commandsService',
            'primaryActor.quickPickMode',
            'failed calling this.stateMachineService.quickPick',
          );
        }
      }),
    );
    // register the command to send the quickPick event (with kindOfQuickPick=Command) to the primaryActor
    this.logger.log('registering primaryActor.quickPickQueryAgentCommand', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.primaryActor.quickPickQueryAgentCommand`, () => {
        this.logger.log(
          'starting commandService.primaryActor.quickPickQueryAgentCommand (FireAndForget)',
          LogLevel.Debug,
        );
        try {
          this.stateMachineService.quickPick({
            kindOfEnumeration: QuickPickEnumeration.QueryAgentCommandMenuItemEnum,
            cTSId: 'GetARealCTSId',
          });
        } catch (e) {
          HandleError(
            e,
            'commandsService',
            'primaryActor.quickPickQueryAgentCommand',
            'failed calling this.stateMachineService.quickPick',
          );
        }
      }),
    );

    // register the command to send the quickPick event (with kindOfQuickPick=QueryEngines) to the primaryActor
    this.logger.log('registering primaryActor.quickPickQueryEngines', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.primaryActor.quickPickQueryEngines`, () => {
        this.logger.log('starting commandService.primaryActor.quickPickQueryEngines (FireAndForget)', LogLevel.Debug);
        try {
          this.stateMachineService.quickPick({
            kindOfEnumeration: QuickPickEnumeration.QueryEnginesMenuItemEnum,
            cTSId: 'GetARealCTSId',
          });
        } catch (e) {
          // ToDo: // This is the top level of the command, so we need to catch any errors that are thrown and handle them, not rethrow them
          HandleError(
            e,
            'commandsService',
            'primaryActor.quickPickQueryEngines',
            'failed calling this.stateMachineService.quickPick',
          );
        }
      }),
    );

    // *************************************************************** //
    this.logger.log('registering sendQuery', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand(`${this.extensionName}.sendQuery`, async () => {
        this.logger.log('starting commandService.stateMachineService.sendQuery (FireAndForget)', LogLevel.Debug);
        let cancellationTokenSource = new vscode.CancellationTokenSource();
        this.data.aiAssistCancellationTokenSourceManager.aiAssistCancellationTokenSourceCollection?.value.push(
          new AiAssistCancellationTokenSource(cancellationTokenSource),
        );
        try {
          this.stateMachineService.sendQuery({
            queryFragmentCollection: this.data.fileManager.queryFragmentCollection,
            cTSToken: cancellationTokenSource.token,
          } as QueryEventPayloadT);
          // this.logger.log(`result.success = ${result.success}, result `, LogLevel.Trace);
        } catch (e) {
          // ToDo: // This is the top level of the command, so we need to catch any errors that are thrown and handle them, not rethrow them

          HandleError(
            e,
            'commandsService',
            'stateMachineService.sendQuery',
            'failed calling this.stateMachineService.sendQuery',
          );
          // ToDo: display a visual error indicator to the user
        }
      }),
    );

    // ************************************************************ //
    // this.message = 'registering copyToSubmit';
    // this.logger.log(this.message, LogLevel.Trace);
    // this.disposables.push(
    //   vscode.commands.registerCommand(`${this.extensionName}.copyToSubmit`, async () => {
    //     let message: string = 'starting commandID copyToSubmit';
    //     this.logger.log(message, LogLevel.Trace);
    //     try {
    //       const result = await copyToSubmit(this.context, this.logger);
    //       message = `result.success = ${result.success}, result `;
    //       this.logger.log(message, LogLevel.Trace);
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
    //     myLogger.log(message, LogLevel.Trace);
    //     if (item === null) {
    //       message = `item is null`;
    //       myLogger.log(message, LogLevel.Trace);
    //     } else {
    //       message = `item is NOT null`;
    //       myLogger.log(message, LogLevel.Trace);
    //     }
    //     // message = `Philote_ID = ${item.Philote_ID} : pickedvalue = ${item.pickedValue}; properties = ${item.properties}`;
    //     // myLogger.log(message, LogLevel.Trace);
    //     message = `stringified item.properties = ${JSON.stringify(item.properties)}`;
    //     myLogger.log(message, LogLevel.Trace);
    //     vscode.window.showInformationMessage(JSON.stringify(item.properties));
    //   },
    // );
    // extensionContext.subscriptions.push(showMainViewRootRecordPropertiesDisposable);

    // // *************************************************************** //
    // let showSubItemPropertiesDisposable = vscode.commands.registerCommand(
    //   `${this.extensionName}.showSubItemProperties`,
    //   (item: mainViewTreeItem) => {
    //     let message: string = 'starting commandID showSubItemProperties';
    //     myLogger.log(message, LogLevel.Trace);
    //     // message = `Philote_ID = ${item.Philote_ID} : pickedvalue = ${item.pickedValue}; properties = ${item.properties}`;
    //     // myLogger.log(message, LogLevel.Trace);
    //     message = `stringified item.properties = ${JSON.stringify(item.properties)}`;
    //     myLogger.log(message, LogLevel.Trace);
    //     vscode.window.showInformationMessage(JSON.stringify(item.properties));
    //   },
    // );
    // extensionContext.subscriptions.push(showSubItemPropertiesDisposable);

    // // *************************************************************** //
    // let removeRegionDisposable = vscode.commands.registerCommand(`${this.extensionName}.removeRegion`, () => {
    //   let message: string = 'starting commandID removeRegion';
    //   myLogger.log(message, LogLevel.Trace);

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
    //     myLogger.log(message, LogLevel.Trace);

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
    //     myLogger.log(message, LogLevel.Trace);

    //     vscode.commands.executeCommand('workbench.view.explorer');
    //     message = 'explorer view should be up';
    //     myLogger.log(message, LogLevel.Trace);
    //   },
    // );
    // extensionContext.subscriptions.push(showExplorerViewDisposable);
  }

  public getDisposables(): vscode.Disposable[] {
    return this.disposables;
  }
}
