import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';

import { LogLevel, Logger, getLoggerLogLevelFromSettings, getDevelopmentLoggerLogLevelFromSettings } from './Logger'; // '@Logger/index';

import { DefaultConfiguration } from './DefaultConfiguration';
import { SecurityService, ISecurityService } from '@SecurityService/index';

import { DataService, IDataService, IData, IUserData } from '@DataService/index';

import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from './Serializers'; // '@Serializers/index';

import { CommandsService } from '@CommandsService/index';

import * as path from 'path';

import * as fs from 'fs';
import { checkFile } from './checkFile';
import { processPs1Files } from './processPs1Files';
import { mainViewTreeDataProvider } from './mainViewTreeDataProvider';
import { mainViewTreeItem } from './mainViewTreeItem';
import { FileTreeProvider } from './FileTreeProvider';

//import { mainSearchEngineProvider } from './mainSearchEngineProvider';

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export async function activate(extensionContext: vscode.ExtensionContext) {
  const runningInDevelopment = extensionContext.extensionMode === vscode.ExtensionMode.Development;
  // Declaration of variables
  let message: string = '';
  let workspacePath: string = '';
  let securityService: ISecurityService;
  let dataService: IDataService;

  // create a logger instance, by default write to an output channel having the same name as the extension, with a LogLevel of Info
  const myLogger = new Logger();
  const loggerLogLevelFromSettings = getLoggerLogLevelFromSettings(); // supplies a default if not found in settings
  myLogger.createChannel('ATAP-AiAssist', loggerLogLevelFromSettings);
  myLogger.log('Extension Activation', LogLevel.Info);

  // Get the VSC configuration settings for this extension
  const config = vscode.workspace.getConfiguration('ATAP-AiAssist');

  // instantiate the SecurityService
  // if a SecurityService initialization serialized string exists, this will try and use it to create the SecurityService, else return a new empty one.
  // Will return a valid SecurityService instance or will throw
  if (isSerializationStructure(DefaultConfiguration.Production['SecurityServiceAsSerializationStructure'])) {
    securityService = SecurityService.CreateSecurityService(
      myLogger,
      extensionContext,
      'extension.ts',
      DefaultConfiguration.Production['SecurityServiceAsSerializationStructure'],
    );
  } else {
    securityService = SecurityService.CreateSecurityService(myLogger, extensionContext, 'SecurityService.ts');
  }
  myLogger.log('CreateSecurityService done', LogLevel.Info);

  if (runningInDevelopment) {
    // update the loggerLogLevel with the'Development.Logger.LogLevel settings value, if it exists
    const developmentLoggerLogLevelFromSettings = getDevelopmentLoggerLogLevelFromSettings();
    myLogger.setChannelLogLevel('ATAP-AiAssist', developmentLoggerLogLevelFromSettings); // supplies a default if not found in settings
    myLogger.log('Running in development mode.', LogLevel.Info);
    // Focus on the output stream on the extension when strarting in development mode
    myLogger.getChannelInfo('ATAP-AiAssist')?.outputChannel?.show(true);

    // if a DataService initialization serialized string exists, this will try and use it to create the DataService, else return a new empty one.
    // Will return a valid DataService instance or will throw
    if (isSerializationStructure(DefaultConfiguration.Development['DataServiceAsSerializationStructure'])) {
      dataService = DataService.CreateDataService(
        myLogger,
        extensionContext,
        'extension.ts',
        DefaultConfiguration.Development['DataServiceAsSerializationStructure'],
      );
    } else {
      dataService = DataService.CreateDataService(myLogger, extensionContext, 'extension.ts');
    }

    message = `data ID/version = 'TheOnlydataSoFar' / ${dataService.version}`;

    myLogger.log(message, LogLevel.Info);
    // was the development host opened to a specific workspace, e.g., as a command line argument
    const workspaceFolders = vscode.workspace.workspaceFolders;
    // Check if a workspace is open
    if (workspaceFolders && workspaceFolders.length > 0) {
      // yes, a workspace was supplied when opening VSC
      workspacePath = workspaceFolders[0].uri.fsPath;
      message = `workspace supplied, WorkspacePath = ${workspacePath}`;
      myLogger.log(message, LogLevel.Debug);
    } else {
      message = 'No workspace supplied!';
      myLogger.log(message, LogLevel.Error);

      // in development mode, if a workspace is not supplied by the invocation of VSC, open a specific Workspace as specified in settings
      const workspacePathFromSettings = config.get<string>('Development.WorkspacePath');
      var workspacePathFromSettingsNotNull: string;

      if (workspacePathFromSettings === null) {
        // no initial workspacePath in settings, and none supplied at startup
        // Let VSC and the extension use their fallback resolution process to ask the user if they want to open a folder
        message = `the setting 'ATAP-AiAssist:Development.WorkspacePath' is null`;
        myLogger.log(message, LogLevel.Error);
        // toDo: how to get workspace path from the fallback resolution, since it won't be set until after the extension has started. Will need callback?
      } else {
        // cast the nullable type to a string, as we have explicitly tested for not null
        workspacePathFromSettingsNotNull = <string>workspacePathFromSettings;
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
        // ToDo: need to open it ourselves, or will VSC just do it for us?
        // await vscode.commands.executeCommand('vscode.openFolder', uri, true);
      }
    }

    // in development mode, open into a specific .ps1 file (relative to the workspacePath) as specified in settings, but only if a workspace is somehow specified
    /*eslint eqeqeq: ["error", "smart"]*/
    if (workspacePath != null) {
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
          message = `An unknown error occurred, and the instance of (e) returned is of type ${typeof e}`;
        }
        myLogger.log(message, LogLevel.Error);
      }
    }
  } else {
    // if a DataService initialization serialized string exists, this will try and use it to create the DataService, else return a new empty one.
    // Will return a valid DataService instance or will throw
    if (isSerializationStructure(DefaultConfiguration.Production['DataServiceAsSerializationStructure'])) {
      dataService = DataService.CreateDataService(
        myLogger,
        extensionContext,
        'extension.ts',
        DefaultConfiguration.Production['DataServiceAsSerializationStructure'],
      );
    } else {
      dataService = DataService.CreateDataService(myLogger, extensionContext, 'extension.ts');
    }

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
  const mainViewTreeDataProviderInstance = new mainViewTreeDataProvider(myLogger);
  vscode.window.createTreeView('atap-aiassistMainTreeView', { treeDataProvider: mainViewTreeDataProviderInstance });

  // instantiate the FileTreeProvider and register it
  //   const rootPath = workspacePath || '';
  // const dummy:string = 'E:/'  ;
  // ToDo: figure out how to focus on the place the user last left off. If no such info, focus on workspaceroot.
  // ToDo: figure out how the mainSearchPanel interacts with the fileTreeProvider -> mainFileViewTreeProvider
  const fileTreeProviderInstance = new FileTreeProvider(); // rootPath  dummy
  vscode.window.createTreeView('atap-aiassistFileTreeView', { treeDataProvider: fileTreeProviderInstance });
  //vscode.window.registerTreeDataProvider('atap-aiassistFileTreeView"', fileTreeProviderInstance);

  // *************************************************************** //
  // ToDo: register some kind of search engine provider. tags:#enabledApiProposals #enableProposedApi (deprecated) #SearchProvider #TextSearchQuery #TextSearchOptions #TextSearchComplete #vscode.CancellationToken
  // let mainSearchTextDisposable = vscode.commands.registerCommand('extension.searchText', mainSearchText);
  // const mainSearchEngine = new mainSearchEngineProvider();
  // extensionContext.subscriptions.push(vscode.workspace.registerSearchProvider('myProvider', provider));

  // Register this extension's commands using the CommandsService.ts module and Dependency Injection for the logger
  // Calling the constructor registers all of the commands, and creates a disposables structure
  let commandsService: CommandsService;
  try {
    message = `instantiate commandsService`;
    myLogger.log(message, LogLevel.Debug);
    commandsService = new CommandsService(myLogger, extensionContext);
  } catch (e) {
    if (e instanceof Error) {
      // Report the error (file may not exist, etc.)
      message = e.message;
    } else {
      // If e is not an instance of Error, you might want to handle it differently
      message = 'An unknown error occurred';
    }
    myLogger.log(message, LogLevel.Error);
    throw new Error(message);
  }
  message = `commandsService instantiated`;
  myLogger.log(message, LogLevel.Trace);

  // Add the disposables from the CommandsService to extensionContext.subscriptions
  extensionContext.subscriptions.push(...commandsService.getDisposables());

  // *************************************************************** //
  let showMainViewRootRecordPropertiesDisposable = vscode.commands.registerCommand(
    'atap-aiassist.showMainViewRootRecordProperties',
    (item: mainViewTreeItem) => {
      let message: string = 'starting commandID showMainViewRootRecordProperties';
      myLogger.log(message, LogLevel.Debug);
      if (item === null) {
        message = `item is null`;
        myLogger.log(message, LogLevel.Debug);
      } else {
        message = `item is NOT null`;
        myLogger.log(message, LogLevel.Debug);
      }
      // message = `Philote_ID = ${item.Philote_ID} : pickedvalue = ${item.pickedValue}; properties = ${item.properties}`;
      // myLogger.log(message, LogLevel.Debug);
      message = `stringified item.properties = ${JSON.stringify(item.properties)}`;
      myLogger.log(message, LogLevel.Debug);
      vscode.window.showInformationMessage(JSON.stringify(item.properties));
    },
  );
  extensionContext.subscriptions.push(showMainViewRootRecordPropertiesDisposable);

  // *************************************************************** //
  let showSubItemPropertiesDisposable = vscode.commands.registerCommand(
    'atap-aiassist.showSubItemProperties',
    (item: mainViewTreeItem) => {
      let message: string = 'starting commandID showSubItemProperties';
      myLogger.log(message, LogLevel.Debug);
      // message = `Philote_ID = ${item.Philote_ID} : pickedvalue = ${item.pickedValue}; properties = ${item.properties}`;
      // myLogger.log(message, LogLevel.Debug);
      message = `stringified item.properties = ${JSON.stringify(item.properties)}`;
      myLogger.log(message, LogLevel.Debug);
      vscode.window.showInformationMessage(JSON.stringify(item.properties));
    },
  );
  extensionContext.subscriptions.push(showSubItemPropertiesDisposable);

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
  extensionContext.subscriptions.push(removeRegionDisposable);

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
  extensionContext.subscriptions.push(processPs1FilesDisposable);

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
  extensionContext.subscriptions.push(showExplorerViewDisposable);
}

function deactivateExtension() {
  // Clean up resources, like closing files or stopping services
  // ...
}
// This method is called when your extension is deactivated
export function deactivate() {
  deactivateExtension();
}
