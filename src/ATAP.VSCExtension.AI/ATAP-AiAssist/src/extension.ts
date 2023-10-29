// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';
import * as path from 'path';

import {
  Logger,
  LogLevel,
  getLoggerLogLevelFromSettings,
  setLoggerLogLevelFromSettings,
  getDevelopmentLoggerLogLevelFromSettings,
  setDevelopmentLoggerLogLevelFromSettings,
  ChannelInfo,
} from './logger';

import * as fs from 'fs';
import { stringBuilder } from './stringBuilder';
import { checkFile } from './checkFile';
import { processPs1Files } from './processPs1Files';
import { mainViewTreeDataProvider } from './mainViewTreeDataProvider';
import { FileTreeProvider } from './FileTreeProvider';

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export async function activate(context: vscode.ExtensionContext) {
  const runningInDevelopment = context.extensionMode === vscode.ExtensionMode.Development;
  let message: string = '';

  // create a logger instance, by default write to an output channel having the same name as the extension, with a LogLevel of Info
  const myLogger = new Logger();
  const loggerLogLevelFromSettings = getLoggerLogLevelFromSettings(); // supplies a default if not found in settings
  myLogger.createChannel('ATAP-AiAssist', loggerLogLevelFromSettings);

  myLogger.log('Extension Activation', LogLevel.Info);


  // Get the VSC configuration settings for this extension
  const config = vscode.workspace.getConfiguration('ATAP-AiAssist');

  // Declaration of variables
  var workspacePath: string;

  if (runningInDevelopment) {
    // update the loggerLogLevel with the'Development.Logger.LogLevel settings value, if it exists
    const developmentLoggerLogLevelFromSettings = getDevelopmentLoggerLogLevelFromSettings();
    myLogger.setChannelLogLevel('ATAP-AiAssist', developmentLoggerLogLevelFromSettings); // supplies a default if not found in settings
    myLogger.log('Running in development mode.', LogLevel.Debug);

    // Focus on the output stream when strarting in development mode
    myLogger.getChannelInfo('ATAP-AiAssist')?.outputChannel?.show(true);

    // in development mode, open a specific Workspace as specified in settings
    const workspacePathFromSettings = config.get<string>('Development.WorkspacePath');
    var workspacePathFromSettingsNotNull: string;

    if (workspacePathFromSettings === null) {
      // no initial workspacePath in settings
      // ToDo: need a function to handle error conditions, ask user for input to resolve, etc.
      message = `the setting 'ATAP-AiAssist:Development.WorkspacePath' is null`;
      myLogger.log(message, LogLevel.Error, 'ATAP-AiAssist'); // ToDO: support logging to all enabled channels
      return; // ToDo: only return if the user decides not to specify an initial file or is ok with no editor open
    } else {
      // cast the nullable type to a string, as we have explicitly tested for not null
      workspacePathFromSettingsNotNull = <string>workspacePathFromSettings;
    }

    // Validate the workspace exists and is readable

    workspacePath = workspacePathFromSettingsNotNull;

    message = `Workspace to open when in development mode: ${workspacePath}`;
    myLogger.log(message, LogLevel.Debug);

    // Add a folder to the workspaceFolders collection
    const workspaceFolderURI = vscode.Uri.file(workspacePath);
    //ToDo: wrap in a try/catch block and handle any errors
    vscode.workspace.updateWorkspaceFolders(0, null, {
      uri: workspaceFolderURI,
    });
    // await vscode.commands.executeCommand('vscode.openFolder', uri, true);

    // in development mode, open into a specific .ps1 file (relative to the workspacePath) as specified in settings
    const editorFilePathFromSettings = config.get<string>('Development.Editor.FilePath');
    var editorFilePathFromSettingsNotNull: string;
    if (editorFilePathFromSettings === null) {
      // no initial file path in settings
      // ToDo: need a function to handle error conditions, ask user for input to resolve, etc.
      message = `the setting 'ATAP-AiAssist:Development.Editor.FilePath' is null`;
      myLogger.log(message, LogLevel.Error, 'ATAP-AiAssist'); // ToDO: support logging to all enabled channels
      return; // ToDo: only return if the user decides not to specify an initial file or is ok with no editor open
    } else {
      // cast the nullable type to a string, as we have explicitly tested for not null
      editorFilePathFromSettingsNotNull = <string>editorFilePathFromSettings;
    }

    // Validate the initial file path exists and is readable
    var editorFilePath: string;

    editorFilePath = editorFilePathFromSettingsNotNull;

    message = `File to open when in development mode: ${editorFilePath}`;
    myLogger.log(message, LogLevel.Debug);

    // ensure the root workspace is open
    const workspaceFolders = vscode.workspace.workspaceFolders;
    // Check if a workspace is open
    if (workspaceFolders && workspaceFolders.length > 0) {
      // this is extra confirmation code. workspacePath (from above) should match workspaceFolders[0].uri.fsPath
      message = `workspacePath = ${workspacePath} ;  rootWorkspace = workspaceFolders[0] ; rootWorkspacePath = ${workspaceFolders[0].uri.fsPath} `;
      myLogger.log(message, LogLevel.Debug);
    } else {
      message = 'No workspace folder open!';
      myLogger.log(message, LogLevel.Error);
      return; // ToDo: How to handle a terminating error - ask user what to do
    }

    // combine the workspace and filepath
    const fullFilePath = path.join(workspacePath || '', editorFilePath);
    const fileUri = vscode.Uri.file(fullFilePath);

    try {
      // Open the text file
      const document = await vscode.workspace.openTextDocument(fileUri);
      await vscode.window.showTextDocument(document);
    } catch (e) {
      if (e instanceof Error) {
        // Report the error (file may not exist, etc.)
        message = e.message;
      } else {
        // If e is not an instance of Error, you might want to handle it differently
        message = 'An unknown error occurred';
      }
      myLogger.log(message, LogLevel.Error);
    }
  } else {
    message = 'Running in normal mode.';
    myLogger.log(message, LogLevel.Debug);
  }

  // in non-development mode, we may be started without a workspace root
  const workspaceFolders = vscode.workspace.workspaceFolders;
  if (workspaceFolders && workspaceFolders.length > 0) {
    // ToDo: ensure that We've already ensured that a workspace is open
    workspacePath = workspaceFolders[0].uri.fsPath;
  } else {
  // ToDo: design the fallback - what should be the workspace root? Ask? PowershellPro Tools extension asks that....
    workspacePath = './'; // ToDO: Priority: this probably won't work
  }

  // instantiate a mainViewTreeDataProvider instance and register that with the TreeDataProvider with the main tree view
  const mainViewTreeDataProviderInstance = new mainViewTreeDataProvider();
  vscode.window.createTreeView('atap-aiassistMainTreeView', { treeDataProvider: mainViewTreeDataProviderInstance });

  // instantiate the FileTreeProvider and register it
  message = 'Instantiate the custom fileTreeProvider.';
  myLogger.log(message, LogLevel.Debug);

  const rootPath = workspacePath || '';
  const dummy:string = 'E:/'  ;
  const fileTreeProvider = new FileTreeProvider(dummy); // rootPath
  vscode.window.registerTreeDataProvider('atap-aiassistFileTreeView"', fileTreeProvider);

  // *************************************************************** //
  let copyToSubmitDisposable = vscode.commands.registerCommand('atap-aiassist.copyToSubmit', () => {
    let message: string = 'starting commandID copyToSubmit';
    myLogger.log(message, LogLevel.Debug);

    let editor = vscode.window.activeTextEditor;
    if (editor) {
      let document = editor.document;
      let selection = editor.selection;
      let text = document.getText(selection);

      let message: string = 'text fetched';
      myLogger.log(message, LogLevel.Debug);
      let textToSubmit = new stringBuilder();
      //textToSubmit.append(text);
    }
  });
  context.subscriptions.push(copyToSubmitDisposable);

  // *************************************************************** //
  let showVSCEnvironmentDisposable = vscode.commands.registerCommand('atap-aiassist.showVSCEnvironment', () => {
    let message: string = 'starting commandID showVSCEnvironment';
    myLogger.log(message, LogLevel.Debug);

    const workspaceFolders = vscode.workspace.workspaceFolders;

    // Check if a workspace is open
    if (workspaceFolders && workspaceFolders.length > 0) {
      // Use the URI property to get the folder path
      message = `workspaceFolder = ${workspaceFolders[0].uri.fsPath} `;
    } else {
      message = 'No workspace folder open.';
    }

    const editor = vscode.window.activeTextEditor;
    if (editor) {
      const document = editor.document;
      const fileName = document.fileName;
      message += `; fileDirname = ${document.fileName}`;
    } else {
      message += '; No editor open';
    }
    myLogger.log(message, LogLevel.Debug);
  });
  context.subscriptions.push(showVSCEnvironmentDisposable);

  // *************************************************************** //
  let removeRegionDisposable = vscode.commands.registerCommand('atap-aiassist.removeRegion', () => {
    let message: string = 'starting commandID removeRegion';
    myLogger.log(message, LogLevel.Debug);

    const editor = vscode.window.activeTextEditor;

    if (editor) {
      const document = editor.document;
      const edit = new vscode.WorkspaceEdit();

      for (let i = 0; i < document.lineCount; i++) {
        const line = document.lineAt(i);

        if (line.text.trim().startsWith('#region') || line.text.trim().startsWith('#endregion')) {
          const range = line.rangeIncludingLineBreak;
          edit.delete(document.uri, range);
        }
      }

      vscode.workspace.applyEdit(edit);
    }
  });
  context.subscriptions.push(removeRegionDisposable);

  // *************************************************************** //
  let processPs1FilesDisposable = vscode.commands.registerCommand(
    'atap-aiassist.processPs1Files',
    async (commandId: string | null) => {
      let message: string = 'starting commandID processPs1Files';
      myLogger.log(message, LogLevel.Debug);

      const processPs1FilesRecord = await processPs1Files(commandId);
      if (processPs1FilesRecord.success) {
        message = `processPs1Files processed ${processPs1FilesRecord.numFilesProcessed} files, using commandID  ${processPs1FilesRecord.commandIDUsed}`;
        vscode.window.showInformationMessage(`${message}`);
      } else {
        message = `processPs1Files failed, error message is ${processPs1FilesRecord.errorMessage}, attemptedCommandID is ${processPs1FilesRecord.commandIDUsed}`;
        vscode.window.showErrorMessage(`${message}`);
      }
    },
  );
  context.subscriptions.push(processPs1FilesDisposable);

  // *************************************************************** //
  let showExplorerViewDisposable = vscode.commands.registerCommand(
    'atap-aiassist.showExplorerView',
    async (commandId: string | null) => {
      let message: string = 'starting commandID showExplorerView';
      myLogger.log(message, LogLevel.Debug);

      vscode.commands.executeCommand('workbench.view.explorer');
      message = 'explorer view should be up';
      myLogger.log(message, LogLevel.Debug);
    },
  );
  context.subscriptions.push(showExplorerViewDisposable);
}
// This method is called when your extension is deactivated
export function deactivate() {}
