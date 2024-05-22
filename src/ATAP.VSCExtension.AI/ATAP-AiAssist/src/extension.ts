import * as vscode from "vscode";
// import * as fs from "fs";

// import { DetailedError, HandleError } from "@ErrorClasses/index";
//import { LogLevel, ILogger, Logger } from "@Logger/index";

// import { logFunction } from "@Decorators/index";
// import { DefaultConfiguration } from "@DataService/DefaultConfiguration";

// import { SecurityService, ISecurityService } from "@SecurityService/index";

// import {
//   DataService,
//   IDataService,
//   IData,
//   IStateManager,
//   IConfigurationData,
// } from "@DataService/index";

// import {
//   isRunningInTestingEnvironment,
//   isRunningInDevelopmentEnvironment,
// } from "@Utilities/index";

// import { CommandsService } from "@CommandsService/index";

// import {
//   IStateMachineService,
//   StateMachineService,
// } from "@StateMachineService/index";

// import { IQueryService, QueryService } from "@QueryService/index";

// import { processPs1Files } from "./processPs1Files";
// import { mainViewTreeDataProvider } from "./mainViewTreeDataProvider";
// import { mainViewTreeItem } from "./mainViewTreeItem";
// import { FileTreeProvider } from "./FileTreeProvider";
// import { type } from "os";

// //import { mainSearchEngineProvider } from './mainSearchEngineProvider';

// // objects that need to be at the global level of the module, so they are visible in both activate and deactivate functions
// let dataService: IDataService;
// let stateMachineService: IStateMachineService;

// // This method is called when your extension is activated
// // Your extension is activated the very first time the command is executed
export async function activate(extensionContext: vscode.ExtensionContext) {
  // create the initial logger instance for the extension,
  //  by default write all log messages to the console and to an output channel having the same name as the extension, with a LogLevel of Info
  // const logger = Logger.createLogger(
  //   extensionContext.extension.id.split(".")[1],
  // );
  // logger.info(`${extensionContext.extension.id} activating`);
  // // Declaration of variables
  // let message: string = "";
  // let workspacePath: string = "";
  // let securityService: ISecurityService;
  // let queryService: IQueryService;
  // let commandsService: CommandsService;
  // const extensionID = extensionContext.extension.id;
  // const extensionName = extensionID.split(".")[1];
  // // If the extension is running in the development host, or if the environment variable 'Environment' is set to 'Development',
  // //   set the environment variable 'Environment' to 'Development'. This overrides whatever value of Environment variable was set when the extension started
  // //   set the logger's channel's LogLevel to LogLevel.Debug initially
  // //   ToDo: use a static map from DefaultConfig to check for a debuggerLogLevel in an environment variable
  // //   if the debuggerLogLevel is set in the extension's setting, use that value,
  // //   else if the debuggerLogLevel in the DefaultConfiguration.Development, use that value
  // if (isRunningInDevelopmentEnvironment()) {
  //   // ToDO: test for an environment variable for debuggerLogLevel, and if it exists, use that value
  //   const settings = vscode.workspace.getConfiguration(extensionName);
  //   const settingsDebuggerLogLevel = settings.get<LogLevel>("debuggerLogLevel");
  //   //   if (settingsDebuggerLogLevel) {
  //   //     logger.setChannelLogLevel(extensionName, settingsDebuggerLogLevel);
  //   //   } else if ('debuggerLogLevel' in DefaultConfiguration.Development) {
  //   //     const defaultConfigurationDebuggerLogLevel = DefaultConfiguration.Development.debuggerLogLevel as LogLevel;
  //   //     logger.setChannelLogLevel(extensionName, defaultConfigurationDebuggerLogLevel);
  //   //   }
  //   //   // Focus on the output stream when starting the extension in development mode
  //   //   logger.getChannelInfo('atap-aiassist')?.outputChannel?.show(true);
  // }
  // logger.log(`${extensionName} Activation Begun`, LogLevel.Info);
  // // instantiate the SecurityService
  // // if a SecurityService initialization serialized string exists, this will try and use it to create the SecurityService, else return a new empty one.
  // // Will return a valid SecurityService instance or will throw
  // // if (isSerializationStructure(DefaultConfiguration.Development['SecurityServiceAsSerializationStructure'])) {
  // //   securityService = SecurityService.CreateSecurityService(
  // //     logger,
  // //     extensionContext,
  // //     'extension.ts',
  // //     DefaultConfiguration.Development['SecurityServiceAsSerializationStructure'],
  // //   );
  // // } else {
  // // ToDo: wrap in a try/catch block
  // // ToDo support rehydration of the SecurityService from a serialized structure
  // // securityService =   SecurityService.create(logger, extensionContext, 'extension.ts');
  // securityService = new SecurityService(logger, extensionContext);
  // // }
  // // if a DataService initialization serialized string exists, this will try and use it to create the DataService, else return a new empty one.
  // // Will return a valid DataService instance or will throw
  // // if (isSerializationStructure(DefaultConfiguration.Development['DataServiceAsSerializationStructure'])) {
  // //   dataService = DataService.CreateDataService(
  // //     logger,
  // //     extensionContext,
  // //     'extension.ts',
  // //     DefaultConfiguration.Development['DataServiceAsSerializationStructure'],
  // //   );
  // // } else {
  // // ToDo: wrap in a try/catch block
  // // ToDo support rehydration of the DataService from a serialized structure
  // dataService = new DataService(logger, extensionContext);
  // // }
  // // logger.log(`data ID/version = 'TheOnlydataSoFar' / ${dataService.version}`, LogLevel.Debug);
  // // ToDo: wrap in a try/catch block
  // securityService.externalDataVetting.AttachListener(
  //   dataService.data.eventManager.getEventEmitter(),
  // );
  // // ToDo: wrap in a try/catch block
  // // ToDo support rehydration of the QueryService from a serialized structure
  // queryService = new QueryService(logger, extensionContext, dataService.data);
  // // ToDo: wrap in a try/catch block
  // // creating the StateMachineService starts all of the state machines
  // try {
  //   stateMachineService = new StateMachineService(
  //     logger,
  //     dataService.data,
  //     queryService,
  //     extensionContext,
  //   );
  // } catch (e) {
  //   HandleError(
  //     e,
  //     "Activation",
  //     "activate",
  //     `failed to create an instance of StateMachineService`,
  //   );
  // }
  // // stateMachineService = StateMachineService.create(
  // //   logger,
  // //   extensionContext,
  // //   dataService.data,
  // //   queryService,
  // //   'extension.ts',
  // // );
  // // Register this extension's commands using the CommandsService.ts module and Dependency Injection for the logger
  // // Calling the constructor registers all of the commands, and creates a disposables structure
  // try {
  //   commandsService = new CommandsService(
  //     logger,
  //     extensionContext,
  //     dataService.data,
  //     stateMachineService,
  //     queryService,
  //   );
  // } catch (e) {
  //   if (e instanceof Error) {
  //     throw new DetailedError(
  //       `Activation: failed to create an instance of CommandsService -> `,
  //       e,
  //     );
  //   } else {
  //     // ToDo:  investigation to determine what else might happen
  //     throw new Error(
  //       `Activation: failed to create an instance of CommandsService and the object caught is of type ${typeof e}`,
  //     );
  //   }
  // }
  // // Add the disposables from the CommandsService to extensionContext.subscriptions
  // extensionContext.subscriptions.push(...commandsService.getDisposables());
  // // Create a status bar item for the extension
  // const statusBarItem = vscode.window.createStatusBarItem(
  //   vscode.StatusBarAlignment.Right,
  //   100,
  // );
  // // Initial state
  // statusBarItem.text = `$(robot) AiAssist`;
  // // set the statusbaritem's command to the VCSCommand sends the quickpickEvent (with kindOfQuickPick=VCSCommand) to the primaryActor
  // statusBarItem.command = `${extensionName}.primaryActor.quickPickVCSCommand`;
  // statusBarItem.tooltip = "Show AiAssist status menu";
  // extensionContext.subscriptions.push(statusBarItem);
  // statusBarItem.show();
  // // Start the state machine
  // stateMachineService.start();
  // // Initialize the UI to the saved appearance it had when the extension was last deactivated, or to a default appearance if there is no saved appearance.
  // // // identify the current workspace context. Compare to stored state information, and update if necessary
  // // const workspaceFolders = vscode.workspace.workspaceFolders;
  // // if (workspaceFolders && workspaceFolders.length > 0) {
  // //   // A workspace or multi-root workspace has been opened
  // //   workspaceFolders.forEach((folder) => {
  // //     const workspacePath = folder.uri.fsPath;
  // //     logger.log(`workspacePath = ${workspacePath}`, LogLevel.Debug);
  // //     // Do something with workspacePath
  // //   });
  // // } else {
  // //   // No workspace has been opened
  // //   // If the stored state matches, no action is needed, otherwise updated the stored state with the current workspace
  // //   if (dataService.data.stateManager.getWorkspacePath() !== undefined) {
  // //     await dataService.data.stateManager.setWorkspacePath('');
  // //     // ToDo: fire the trigger for the workspacePath change event
  // //   }
  // // }
  // // if (process.env['Environment'] === 'Development') {
  // //   // in development mode, if a workspace is not supplied when the extension is activated,
  // //   //  open a specific Workspace as specified in development configuration if one is defined
  // //   const developmentWorkspacePath = dataService.data.configurationData.getDevelopmentWorkspacePath();
  // //   if (developmentWorkspacePath !== undefined) {
  // //     // ToDo:validate the path exists and is readable and writeable
  // //     await dataService.data.stateManager.setWorkspacePath(developmentWorkspacePath);
  // //     // ToDo: fire the trigger for the workspacePath change event
  // //   }
  // // }
  // // If the mode is 'Chat',
  // // then see if a Conversation document has been restored from a previous session
  // // and if not, create a new Conversation document
  // // try {
  // //   fs.writeFileSync(tempFilePath, '');
  // // } catch (e) {
  // //   if (e instanceof Error) {
  // //     throw new DetailedError(`Activation: failed to create ${tempFilePath} -> `, e);
  // //   } else {
  // //     // ToDo:  investigation to determine what else might happen
  // //     throw new Error(
  // //       `Activation: failed to create ${tempFilePath} and the instance of (e) returned is of type ${typeof e}`,
  // //     );
  // //   }
  // // }
  // // // Open a new temporary document 'promptDocument' in an editor window
  // // let promptDocument = vscode.workspace.openTextDocument(tempFilePath).then((doc) => {
  // //   let document: vscode.TextDocument = doc;
  // //   return vscode.window.showTextDocument(document).then((ed) => {
  // //     let editor: vscode.TextEditor = ed;
  // //     let lastLine = document.lineAt(document.lineCount - 1);
  // //     const savedPromptDocumentData = dataService.data.stateManager.getsavedPromptDocumentData();
  // //     let promptDocumentData: string =
  // //       savedPromptDocumentData || dataService.data.configurationData.promptExpertise;
  // //     editor.edit((editBuilder) => {
  // //       editBuilder.insert(lastLine.range.end, promptDocumentData);
  // //     });
  // //     document.save();
  // //     dataService.data.setTemporaryPromptDocumentPath(tempFilePath);
  // //     dataService.data.setTemporaryPromptDocument(document);
  // //   });
  // // });
  // // instantiate a view for the response of each AI engine
  // // ChatGPT
  // // Anthropic
  // // Bard
  // // Grok
  // // Copilot
  // // // instantiate a mainViewTreeDataProvider instance and register that with the TreeDataProvider with the main tree view
  // // const mainViewTreeDataProviderInstance = new mainViewTreeDataProvider(logger);
  // // vscode.window.createTreeView('atap-aiassistMainTreeView', { treeDataProvider: mainViewTreeDataProviderInstance });
  // // // instantiate the FileTreeProvider and register it
  // // //   const rootPath = workspacePath || '';
  // // // const dummy:string = 'E:/'  ;
  // // // ToDo: figure out how to focus on the place the user last left off. If no such info, focus on workspaceroot.
  // // // ToDo: figure out how the mainSearchPanel interacts with the fileTreeProvider -> mainFileViewTreeProvider
  // // const fileTreeProviderInstance = new FileTreeProvider(); // rootPath  dummy
  // // vscode.window.createTreeView('atap-aiassistFileTreeView', { treeDataProvider: fileTreeProviderInstance });
  // // //vscode.window.registerTreeDataProvider('atap-aiassistFileTreeView"', fileTreeProviderInstance);
  // // // *************************************************************** //
  // // // ToDo: register some kind of search engine provider. tags:#enabledApiProposals #enableProposedApi (deprecated) #SearchProvider #TextSearchQuery #TextSearchOptions #TextSearchComplete #vscode.CancellationToken
  // // // let mainSearchTextDisposable = vscode.commands.registerCommand('extension.searchText', mainSearchText);
  // // // const mainSearchEngine = new mainSearchEngineProvider();
  // // // extensionContext.subscriptions.push(vscode.workspace.registerSearchProvider('myProvider', provider));
  // // //debugging
  // // let allEditorsRestored = false;
  // // vscode.window.onDidChangeVisibleTextEditors((editors) => {
  // //   if (!allEditorsRestored) {
  // //     logger.log(`onDidChangeVisibleTextEditors: editors length: ${editors.length}`, LogLevel.Debug);
  // //     if (editors.length === vscode.workspace.textDocuments.length) {
  // //       allEditorsRestored = true;
  // //     }
  // //   }
  // // });
  // // logger.log(`Num editors visible at end of activation: ${vscode.window.visibleTextEditors.length}`, LogLevel.Debug);
  // // vscode.window.visibleTextEditors.forEach((editor) => {
  // //   logger.log(
  // //     `Visible editor's document at end of activation: uri = ${editor.document.uri} filename = ${editor.document.fileName}`,
  // //     LogLevel.Debug,
  // //   );
  // // });
}

// async function deactivateExtensionAsync(): Promise<void> {
//   return new Promise(async (resolve) => {
//     // Dispose of the state machine service
//     await stateMachineService.disposeAsync();

//     // Clean up resources, like closing files or stopping services
//     await dataService.disposeAsync();

//     // Cleanup temporary prompt document
//     let promptDocument =
//       dataService.data.getTemporaryPromptDocument() as vscode.TextDocument;
//     // Save the text in the promptDocument to the stateManager
//     dataService.data.stateManager.setSavedPromptDocumentData(
//       promptDocument.getText(),
//     );

//     // ToDo: The code to close editors with this document does not execute correctly
//     // close any editors with this document open
//     let editorsDisplayingDoc = vscode.window.visibleTextEditors.filter(
//       (editor) => editor.document === promptDocument,
//     );
//     //logger.log(`Num editors: ${editorsDisplayingDoc.length}`, LogLevel.Debug);
//     console.log(`Num editors: ${editorsDisplayingDoc.length}`);
//     editorsDisplayingDoc.forEach((editor, i) => {
//       console.log(i);

//       vscode.window
//         .showTextDocument(editor.document, { preserveFocus: false })
//         .then(() => {
//           console.log(`Closing ${editor.document.fileName}`);
//           if (i === editorsDisplayingDoc.length - 1) {
//             // If this is the last editor, close it directly
//             console.log(`Closing ${editor.document.fileName} directly`);
//             vscode.commands.executeCommand(
//               "workbench.action.closeActiveEditor",
//             );
//           } else {
//             // Otherwise, set a timeout to allow the editor to come into focus before closing it
//             setTimeout(() => {
//               console.log(`Closing ${editor.document.fileName} after timeout`);
//               vscode.commands.executeCommand(
//                 "workbench.action.closeActiveEditor",
//               );
//             }, 500);
//           }
//         });
//     });

//     // delete the temporary files
//     await fs.unlink(
//       dataService.data.getTemporaryPromptDocumentPath() as string,
//       (err) => {
//         HandleError(
//           err,
//           "Activation",
//           "deactivateExtensionAsync",
//           `failed to delete ${dataService.data.getTemporaryPromptDocumentPath()}`,
//         );
//       },
//     );
//   });
// }

// This method is called when your extension is deactivated
export async function deactivate(): Promise<void> {
  console.log("deactivate");
  // await deactivateExtensionAsync();
}
