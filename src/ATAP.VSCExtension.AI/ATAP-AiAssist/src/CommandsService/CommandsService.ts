import { LogLevel, ILogger, Logger } from '@Logger/index';
import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor } from '@Decorators/Decorators';

import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import { startCommand } from './startCommand';
import { showVSCEnvironment } from './showVSCEnvironment';
import { showPrompt } from './showPrompt';
import { sendQuery } from './sendQuery';

import { sendFilesToAPI } from './sendFilesToAPI';
import { showQuickPickExample } from './showQuickPickExample';
// import { quickPickFromSettings } from './quickPickFromSettings';
import { copyToSubmit } from './copyToSubmit';

@logConstructor
export class CommandsService {
  private disposables: vscode.Disposable[] = [];

  constructor(private logger: ILogger, private extensionContext: vscode.ExtensionContext, private data: IData) {
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
        try {
          const result = await sendQuery(this.logger, this.data);
          // this.logger.log(`result.success = ${result.success}, result `, LogLevel.Debug);
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError('Command sendQuery caught an error from function sendQuery -> ', e);
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `Command sendQuery caught an unknown object from function sendQuery, and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
      }),
    );

    this.logger.log('registering sendFilesToAPI', LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.sendFilesToAPI', () => {
        let message: string = 'starting commandID sendFilesToAPI';
        this.logger.log(message, LogLevel.Debug);
        sendFilesToAPI(this.extensionContext, this.logger);
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

    this.logger.log('registering showQuickPickExample', LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showQuickPickExample', async () => {
        this.logger.log('starting commandID showQuickPickExample', LogLevel.Debug);
        try {
          const result = await showQuickPickExample(this.logger);
          this.logger.log(`result.success = ${result.success}, result `, LogLevel.Debug);
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError('Data.ctor. create configurationData -> ', e);
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `An unknown error occurred during the showQuickPickExample call, and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
      }),
    );

    // this.message = 'registering quickPickFromSettings';
    // this.logger.log(this.message, LogLevel.Debug);
    // this.disposables.push(
    //   vscode.commands.registerCommand('atap-aiassist.quickPickFromSettings', async () => {
    //     let message: string = 'starting commandID quickPickFromSettings';
    //     this.logger.log(message, LogLevel.Debug);
    //     try {
    //       // ToDo: how to pass the string for 'setting' to the extension command
    //       // ToDo: the extensionId.setting that needs / contains the QuickPick setting
    //       let setting: string = 'CategoryCollection';
    //       const result = await quickPickFromSettings(this.logger, setting);
    //       message = `result.success = ${result.success}, result `;
    //       this.logger.log(message, LogLevel.Debug);
    //     } catch (e) {
    //       if (e instanceof Error) {
    //         // Report the error
    //         message = e.message;
    //       } else {
    //         // ToDo: e is not an instance of Error, needs investigation to determine what else might happen
    //         message = `An unknown error occurred during the quickPickFromSettings call, and the instance of (e) returned is of type ${typeof e}`;
    //       }
    //       this.logger.log(message, LogLevel.Error);
    //     }
    //   }),
    // );

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
