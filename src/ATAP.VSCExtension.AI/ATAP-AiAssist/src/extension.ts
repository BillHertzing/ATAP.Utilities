import * as vscode from 'vscode';
import { Buffer } from 'buffer';
import * as path from 'path';
import * as fs from 'fs';
import * as crypto from 'crypto';

import { DetailedError } from '@ErrorClasses/index';
import {
  LogLevel,
  Logger,
  getLoggerLogLevelFromSettings,
  getDevelopmentLoggerLogLevelFromSettings,
} from '@Logger/index';

import { SecurityService, ISecurityService } from '@SecurityService/index';

import { DataService, IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/index';

import { isRunningInDevHost } from '@Utilities/index';

import { CommandsService } from '@CommandsService/index';

import { checkFile } from './checkFile';
import { processPs1Files } from './processPs1Files';
import { mainViewTreeDataProvider } from './mainViewTreeDataProvider';
import { mainViewTreeItem } from './mainViewTreeItem';
import { FileTreeProvider } from './FileTreeProvider';
import { type } from 'os';
import { logFunction } from './Decorators';

//import { mainSearchEngineProvider } from './mainSearchEngineProvider';

// objects that need to be at the global level of the module, so they are visible in both activate and deactivate functions
let dataService: IDataService;

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export async function activate(extensionContext: vscode.ExtensionContext) {
  const runningInDevelopment = isRunningInDevHost();
  // Declaration of variables
  let message: string = '';
  let workspacePath: string = '';
  let securityService: ISecurityService;

  // ToDo: create a static startup logger, and use that until the full blown logger can be instantiated
  // create a logger instance, by default write to an output channel having the same name as the extension, with a LogLevel of Info
  const myLogger = new Logger();
  // const loggerLogLevelFromSettings = getLoggerLogLevelFromSettings(); // supplies a default if not found in settings
  // myLogger.createChannel('ATAP-AiAssist', loggerLogLevelFromSettings);
  myLogger.createChannel('ATAP-AiAssist', LogLevel.Debug);
  myLogger.log('Extension Activation', LogLevel.Info);

  // Get the VSC configuration settings for this extension
  const config = vscode.workspace.getConfiguration('ATAP-AiAssist');

  if (runningInDevelopment) {
    // update the loggerLogLevel with the'Development.Logger.LogLevel settings value, if it exists
    const developmentLoggerLogLevelFromSettings = getDevelopmentLoggerLogLevelFromSettings();
    myLogger.setChannelLogLevel('ATAP-AiAssist', developmentLoggerLogLevelFromSettings); // supplies a default if not found in settings
    myLogger.log('Running in development mode.', LogLevel.Info);
    // Focus on the output stream when starting the extension in development mode
    myLogger.getChannelInfo('ATAP-AiAssist')?.outputChannel?.show(true);
  }
  // instantiate the SecurityService
  // if a SecurityService initialization serialized string exists, this will try and use it to create the SecurityService, else return a new empty one.
  // Will return a valid SecurityService instance or will throw
  // if (isSerializationStructure(DefaultConfiguration.Development['SecurityServiceAsSerializationStructure'])) {
  //   securityService = SecurityService.CreateSecurityService(
  //     myLogger,
  //     extensionContext,
  //     'extension.ts',
  //     DefaultConfiguration.Development['SecurityServiceAsSerializationStructure'],
  //   );
  // } else {
  securityService = SecurityService.CreateSecurityService(myLogger, extensionContext, 'SecurityService.ts');
  // }

  // if a DataService initialization serialized string exists, this will try and use it to create the DataService, else return a new empty one.
  // Will return a valid DataService instance or will throw
  // if (isSerializationStructure(DefaultConfiguration.Development['DataServiceAsSerializationStructure'])) {
  //   dataService = DataService.CreateDataService(
  //     myLogger,
  //     extensionContext,
  //     'extension.ts',
  //     DefaultConfiguration.Development['DataServiceAsSerializationStructure'],
  //   );
  // } else {
  dataService = DataService.CreateDataService(myLogger, extensionContext, 'extension.ts');
  // }

  myLogger.log(`data ID/version = 'TheOnlydataSoFar' / ${dataService.version}`, LogLevel.Info);

  // identify the current workspace context. Compare to stored state information, and update if necessary
  const workspaceFolders = vscode.workspace.workspaceFolders;

  if (workspaceFolders && workspaceFolders.length > 0) {
    // A workspace or multi-root workspace has been opened
    workspaceFolders.forEach((folder) => {
      const workspacePath = folder.uri.fsPath;
      // Do something with workspacePath
    });
  } else {
    // No workspace has been opened
    // If the stored state matches, no action is needed, otherwise updated the stored state with the current workspace
    if (dataService.data.stateManager.getWorkspacePath() !== undefined) {
      await dataService.data.stateManager.setWorkspacePath('');
      // ToDo: fire the trigger for the workspacePath change event
    }
  }

  if (runningInDevelopment) {
    // in development mode, if a workspace is not supplied when the extension is activated,
    //  open a specific Workspace as specified in development configuration if one is defined
    const developmentWorkspacePath = dataService.data.configurationData.getDevelopmentWorkspacePath();
    if (developmentWorkspacePath !== undefined) {
      // ToDo:validate the path exists and is readable and writeable
      await dataService.data.stateManager.setWorkspacePath(developmentWorkspacePath);
      // ToDo: fire the trigger for the workspacePath change event
    }
  }

  // Setup the promptDocument
  // Create a temporary file name for this session
  const tempDirectoryBasePath = dataService.data.configurationData.getTempDirectoryBasePath();
  const tempDir = path.join(tempDirectoryBasePath, dataService.data.configurationData.getExtensionFullName());
  const randomFileName = crypto.randomBytes(16).toString('hex') + '.txt';
  const tempFilePath = path.join(tempDir, randomFileName);
  try {
    fs.mkdirSync(tempDir, { recursive: true });
  } catch (e) {
    if (e instanceof Error) {
      throw new DetailedError(`Activation: failed to create ${tempDir} -> `, e);
    } else {
      // ToDo:  investigation to determine what else might happen
      throw new Error(
        `Activation: failed to create ${tempDir} and the instance of (e) returned is of type ${typeof e}`,
      );
    }
  }
  try {
    fs.writeFileSync(tempFilePath, '');
  } catch (e) {
    if (e instanceof Error) {
      throw new DetailedError(`Activation: failed to create ${tempFilePath} -> `, e);
    } else {
      // ToDo:  investigation to determine what else might happen
      throw new Error(
        `Activation: failed to create ${tempFilePath} and the instance of (e) returned is of type ${typeof e}`,
      );
    }
  }

  // Open a new temporary document 'promptDocument' in an editor window
  let promptDocument = vscode.workspace.openTextDocument(tempFilePath).then((doc) => {
    let document: vscode.TextDocument = doc;
    return vscode.window.showTextDocument(document).then((ed) => {
      let editor: vscode.TextEditor = ed;
      let lastLine = document.lineAt(document.lineCount - 1);
      const savedPromptDocumentData = dataService.data.stateManager.getsavedPromptDocumentData();
      let promptDocumentData: string =
        savedPromptDocumentData || dataService.data.configurationData.getPromptExpertise();

      editor.edit((editBuilder) => {
        editBuilder.insert(lastLine.range.end, promptDocumentData);
      });
      document.save();

      dataService.data.setTemporaryPromptDocumentPath(tempFilePath);
      dataService.data.setTemporaryPromptDocument(document);
    });
  });

  // instantiate a view for the response of each AI engine
  // ChatGPT

  // Anthropic

  // Bard

  // Grok

  // Copilot

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
    commandsService = new CommandsService(myLogger, extensionContext, dataService.data);
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

  //debugging
  let allEditorsRestored = false;
  vscode.window.onDidChangeVisibleTextEditors((editors) => {
    if (!allEditorsRestored) {
      console.log(`onDidChangeVisibleTextEditors: num editors as event arg: ${editors.length}`);
      if (editors.length === vscode.workspace.textDocuments.length) {
        allEditorsRestored = true;
      }
    }
  });

  console.log(`Num editors: ${vscode.window.visibleTextEditors.length}`);
  vscode.window.visibleTextEditors.forEach((editor) => {
    console.log(editor.document.fileName);
  });
}

function deactivateExtension(): Promise<void> {
  return new Promise((resolve) => {
    // Clean up resources, like closing files or stopping services

    // Cleanup temporary prompt document
    let promptDocument = dataService.data.getTemporaryPromptDocument() as vscode.TextDocument;
    // Save the text in the promptDocument to the stateManager
    dataService.data.stateManager.setSavedPromptDocumentData(promptDocument.getText());

    // ToDo: The code to close editors with this document does not execute correctly
    // close any editors with this document open
    let editorsDisplayingDoc = vscode.window.visibleTextEditors.filter((editor) => editor.document === promptDocument);
    console.log(`Num editors: ${editorsDisplayingDoc.length}`);
    editorsDisplayingDoc.forEach((editor, i) => {
      console.log(i);

      vscode.window.showTextDocument(editor.document, { preserveFocus: false }).then(() => {
        console.log(`Closing ${editor.document.fileName}`);
        if (i === editorsDisplayingDoc.length - 1) {
          // If this is the last editor, close it directly
          console.log(`Closing ${editor.document.fileName} directly`);
          vscode.commands.executeCommand('workbench.action.closeActiveEditor');
        } else {
          // Otherwise, set a timeout to allow the editor to come into focus before closing it
          setTimeout(() => {
            console.log(`Closing ${editor.document.fileName} after timeout`);
            vscode.commands.executeCommand('workbench.action.closeActiveEditor');
          }, 500);
        }
      });
    });

    // delete the temporary file
    try {
      fs.unlinkSync(dataService.data.getTemporaryPromptDocumentPath() as string);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(
          `deactivate: failed to delete ${dataService.data.getTemporaryPromptDocumentPath()} -> `,
          e,
        );
      } else {
        throw new Error(
          `deactivate: failed to delete ${dataService.data.getTemporaryPromptDocumentPath()} and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
    resolve();
  });
}

// This method is called when your extension is deactivated
export function deactivate(): Promise<void> {
  console.log('deactivate');
  return new Promise((resolve) => {
    deactivateExtension();
    resolve();
  });
}
