//import axios from 'axios';
import * as diff from 'diff';
import Promise from 'bluebird';

import * as vscode from 'vscode';
import axios, { AxiosRequestConfig, CancelTokenSource } from 'axios';
//import * as Promise from 'bluebird';

import * as fs from 'fs';
import * as path from 'path';
//import * as diff from 'diff';
import * as os from 'os';

import { ILogger, LogLevel } from '@Logger/index';
import { DataService, IData } from '@DataService/DataService';

import {
  EndpointManager,
  EndpointConfig,
  ChatGptEndpointConfig,
  GrokEndpointConfig,
  CopilotEndpointConfig,
  LLModels,
} from '@EndpointManager/index';
import { logAsyncFunction } from '@Decorators/Decorators';

const commentSyntax = {
  '.js': { singleLine: '//', multiLine: { start: '/*', end: '*/' } },
  '.ts': { singleLine: '//', multiLine: { start: '/*', end: '*/' } },
  '.py': { singleLine: '#', multiLine: { start: '"""', end: '"""' } },
  '.ps1': { singleLine: '#', multiLine: { start: '<#', end: '#>' } },
  '.cs': { singleLine: '//', multiLine: { start: '/*', end: '*/' } },
};

function removeComments(content: string, syntax: any): string {
  // Regular expression to remove single line and multiline comments
  const singleLineCommentRegex = new RegExp(`${syntax.singleLine}.*`, 'g');
  const multiLineCommentRegex = new RegExp(`${syntax.multiLine.start}[\\s\\S]*?${syntax.multiLine.end}`, 'g');

  return content.replace(singleLineCommentRegex, '').replace(multiLineCommentRegex, '');
}

// @logAsyncFunction
export async function sendQuery(logger: ILogger, data: IData) {
  // for now, assume the query will be sent to a single endpoint, and hardcode the specific endpoint in here for now
  let endpointLLM = LLModels.ChatGPT;
  // let endpointConfiguration = data.configurationData.getEndpointConfig()[endpointLLM];

  // let keePassSecretKey = endpointConfiguration.;

  const keePassDatabasePath = data.configurationData.getKeePassKDBXPath();
  //const keepassSecret = vscode.workspace.getConfiguration().get<string>('KeepassSecret');

  // if (!url || !keepassSecret || !keepassFile || !masterPasswordBuffer) {
  //   vscode.window.showErrorMessage('Missing configuration or master password');
  //   return;
  // }

  // Retrieve and concatenate document data
  let contentCommentLess = '';
  for (const document of vscode.workspace.textDocuments) {
    if (document.uri.scheme === 'file') {
      let content = removeComments(document.getText(), path.extname(document.uri.fsPath));
      contentCommentLess += `${document.uri.fsPath}: ${content}\n\n`;
    }
  }

  // Append data from 'PromptDocument'
  const tempFilePath = path.join(os.tmpdir(), 'PromptDocument.txt');
  if (fs.existsSync(tempFilePath)) {
    contentCommentLess += fs.readFileSync(tempFilePath, 'utf8');
  }

  // Use Bluebird to wrap Axios call
  // try {
  //   const response = await Promise.resolve(
  //     axios.post(url, contentCommentLess, {
  //       headers: { Authorization: `Bearer ${masterPasswordBuffer.toString()}` },
  //     }),
  //   );

  //   // Process response to apply diffs
  //   Object.entries(response.data).forEach(([fileName, diffContent]) => {
  //     const filePath = vscode.workspace.textDocuments.find((doc) => doc.uri.fsPath === fileName)?.uri.fsPath;
  //     if (filePath) {
  //       const originalContent = fs.readFileSync(filePath, 'utf8');
  //       const patchedContent = diff.applyPatch(originalContent, diffContent);
  //       const tempDiffPath = path.join(os.tmpdir(), `diff_${path.basename(filePath)}`);
  //       fs.writeFileSync(tempDiffPath, patchedContent, 'utf8');

  //       const tempDiffUri = vscode.Uri.file(tempDiffPath);
  //       vscode.commands.executeCommand('vscode.diff', vscode.Uri.file(filePath), tempDiffUri, 'Diff View');
  //     }
  //   });
  // } catch (error) {
  //   vscode.window.showErrorMessage(`Error in sendQuery: ${error}`);
  // }
}

///////////////////////////////////////////////////////////////////////

// // Retrieve all text documents currently open in text editors
// const documents = vscode.workspace.textDocuments;

// documents.forEach((document) => {
//   // Ignore documents that aren't associated with a file (e.g., untitled documents)
//   if (document.uri.scheme === 'file') {
//     const fileName = document.fileName;
//     const content = document.getText();

//     // Log or display the file name and its content
//     console.log(`File Name: ${fileName}`);
//     console.log(`Content: ${content}\n\n`);
//   }
// });

// async function submitQuery(url: string, data: any, apiKey: string, cancelToken: CancelTokenSource): Promise<any> {
//   const config: AxiosRequestConfig = {
//     headers: {
//       Authorization: `Bearer ${apiKey}`,
//     },
//     cancelToken: cancelToken.token,
//   };

//   return new Promise((resolve, reject) => {
//     axios
//       .post(url, data, config)
//       .then((response) => resolve(response.data))
//       .catch((error) => {
//         if (axios.isCancel(error)) {
//           console.log('Request canceled:', error.message);
//         } else {
//           reject(error);
//         }
//       });
//   });
// }

// let cancelTokenSource = axios.CancelToken.source();

// submitQuery('https://api.example.com/data', { key: 'value' }, 'your-api-key', cancelTokenSource)
//   .then((data) => {
//     console.log('Data received:', data);
//   })
//   .catch((error) => {
//     console.error('Error:', error);
//   });

// // To cancel the request
// // cancelTokenSource.cancel('Operation canceled by the user.');

// let cancelTokenSource: CancelTokenSource | null = null;

// let submitCommand = vscode.commands.registerCommand('extension.submitQuery', () => {
//   cancelTokenSource = axios.CancelToken.source();

//   submitQuery('https://api.example.com/data', { key: 'value' }, 'your-api-key', cancelTokenSource)
//     .then((data) => {
//       vscode.window.showInformationMessage(`Data: ${JSON.stringify(data)}`);
//     })
//     .catch((error) => {
//       if (!axios.isCancel(error)) {
//         vscode.window.showErrorMessage(`Error: ${error}`);
//       }
//     });
// });

// let cancelCommand = vscode.commands.registerCommand('extension.cancelQuery', () => {
//   if (cancelTokenSource) {
//     cancelTokenSource.cancel('Operation canceled by the user.');
//   }
// });

// context.subscriptions.push(submitCommand, cancelCommand);

// async function collectContext(): Promise<string> {
//   let combinedData = '';

//   for (const document of vscode.workspace.textDocuments) {
//     if (document.uri.scheme === 'file') {
//       const fileName = document.fileName;
//       const fileExtension = path.extname(fileName);
//       const content = document.getText();

//       let uncommentedContent = content;

//       // Check if the language's comment syntax is known
//       if (commentSyntax[fileExtension]) {
//         uncommentedContent = removeComments(content, commentSyntax[fileExtension]);
//       }

//       combinedData += `${fileName}: ${uncommentedContent}\n\n`;
//     }
//   }

//   return combinedData;
// }
// vscode.commands.registerCommand('extension.collectContext', async () => {
//   try {
//     const combinedData = await collectContext();
//     vscode.window.showInformationMessage('Data collected from open documents.');
//     console.log(combinedData); // Or display it in another way
//   } catch (error) {
//     vscode.window.showErrorMessage('Error collecting data: ' + error);
//   }
// });

// async function processAndSubmitData(url: string, apiKey: string, cancelToken: CancelTokenSource): Promise<void> {
//   try {
//     const collectedData = await collectContext();
//     await submitQuery(url, collectedData, apiKey, cancelToken);
//     vscode.window.showInformationMessage('Data submitted successfully.');
//   } catch (error) {
//     vscode.window.showErrorMessage('Error processing or submitting data: ' + error);
//   }
// }

// vscode.commands.registerCommand('extension.processAndSubmitData', async () => {
//   const url = 'https://api.example.com/data'; // Replace with your URL
//   const apiKey = 'your-api-key'; // Replace with your API key
//   const cancelTokenSource = axios.CancelToken.source();

//   await processAndSubmitData(url, apiKey, cancelTokenSource);
// });

// function openNewDocument() {
//   vscode.workspace.openTextDocument({ content: '', language: 'plaintext' }).then((document) => {
//     vscode.window.showTextDocument(document);
//   });
// }

// function openDocumentWithDefaultText() {
//   const defaultText = 'Hello, World!'; // Your default text here
//   vscode.workspace.openTextDocument({ content: defaultText, language: 'plaintext' }).then((document) => {
//     vscode.window.showTextDocument(document);
//   });
// }

// let openDocumentReference;

// function openDocumentWithDefaultText() {
//   const defaultText = 'Hello, World!';
//   vscode.workspace.openTextDocument({ content: defaultText }).then((document) => {
//     openDocumentReference = document; // Store the document reference
//     vscode.window.showTextDocument(document);
//   });
// }

// function accessStoredDocument() {
//   if (openDocumentReference) {
//     // Use the stored reference here
//     // For example, show the document again
//     vscode.window.showTextDocument(openDocumentReference);
//   } else {
//     console.log('No document is stored');
//   }
// }

// function activate(context) {
//   // When extension is activated, retrieve stored document info
//   let storedUri = context.globalState.get('documentUri');
//   let storedContent = context.globalState.get('documentContent');

//   if (storedUri) {
//     vscode.workspace.openTextDocument(vscode.Uri.parse(storedUri)).then((document) => {
//       vscode.window.showTextDocument(document);
//     });
//   }

//   // Register command to store document info
//   let disposable = vscode.commands.registerCommand('yourExtension.storeDocumentInfo', () => {
//     let activeDocument = vscode.window.activeTextEditor.document;
//     context.globalState.update('documentUri', activeDocument.uri.toString());
//     context.globalState.update('documentContent', activeDocument.getText());
//   });

//   context.subscriptions.push(disposable);
// }

// function activate(context) {
//   let previousActiveDocument;

//   context.subscriptions.push(
//     vscode.window.onDidChangeActiveTextEditor((editor) => {
//       if (
//         editor &&
//         previousActiveDocument &&
//         editor.document.uri.toString() !== previousActiveDocument.uri.toString()
//       ) {
//         // Update the content in the global state
//         context.globalState.update('documentUri', previousActiveDocument.uri.toString());
//         context.globalState.update('documentContent', previousActiveDocument.getText());
//       }
//       previousActiveDocument = editor ? editor.document : null;
//     }),
//   );
// }

// async function openDiffView() {
//   const originalFilePath = '/path/to/original/file'; // Replace with actual file path
//   const modifiedFilePath = '/path/to/modified/file'; // Replace with actual file path

//   const originalUri = vscode.Uri.file(originalFilePath);
//   const modifiedUri = vscode.Uri.file(modifiedFilePath);

//   const originalDocument = await vscode.workspace.openTextDocument(originalUri);
//   const modifiedDocument = await vscode.workspace.openTextDocument(modifiedUri);

//   vscode.commands.executeCommand('vscode.diff', originalDocument.uri, modifiedDocument.uri, 'Diff View');
// }

// async function applyDiff() {
//   const originalFilePath = '/path/to/original/file'; // Replace with actual file path
//   const diffFilePath = '/path/to/diff/file'; // Replace with actual diff file path

//   // Read original and diff files
//   const originalContent = fs.readFileSync(originalFilePath, 'utf8');
//   const diffContent = fs.readFileSync(diffFilePath, 'utf8');

//   // Apply the diff
//   const patch = diff.parsePatch(diffContent);
//   const modifiedContent = diff.applyPatch(originalContent, patch);

//   // Write the modified content to a temporary file
//   const tempFilePath = '/path/to/temporary/modified/file'; // Replace with actual path for temporary file
//   fs.writeFileSync(tempFilePath, modifiedContent, 'utf8');

//   // Optionally, open the modified file in VS Code
//   const modifiedUri = vscode.Uri.file(tempFilePath);
//   const modifiedDocument = await vscode.workspace.openTextDocument(modifiedUri);
//   vscode.window.showTextDocument(modifiedDocument);
// }

// // Check for existing temp file path in globalState
// const tempFilePath = context.globalState.get('tempFilePath');

// if (tempFilePath) {
//   // File exists from previous session, you can use it here
// } else {
//   // Create a new temp file
//   const newTempFilePath = path.join(os.tmpdir(), 'myExtensionTempFile.txt');
//   fs.writeFileSync(newTempFilePath, 'Initial content');
//   context.globalState.update('tempFilePath', newTempFilePath);
// }

// function deactivate(context) {
//   // Optional: Clean up the temp file when the extension is deactivated
//   const tempFilePath = context.globalState.get('tempFilePath');
//   if (tempFilePath) {
//     try {
//       fs.unlinkSync(tempFilePath);
//       context.globalState.update('tempFilePath', undefined);
//     } catch (error) {
//       console.error('Error deleting temp file:', error);
//     }
//   }
// }

// use the examples from above when creating your response.
// you are an expert in Visual Studio Code and VSC extensions. You  are an expert in Typescript. You are an expert in Javascript. You are an expert in Node.js. You are an expert in Webpack. You are an expert in NPM. You are an expert in Mocha. You are an expert in Chai.
// you are working on an existing extension named ataputilities.atap-aiassist that includes  os,path,fs,axios, bluebird,and diff. you are an expert in axios, bluebird, and diff
// generate startup code for extension activation that opens a new temporary document 'PromptDocument' and reads into it any data stored in the global state that may have been saved from a previous session. If there is no saved data, the tmeporary document is initialized with the string constant 'YOurExpertise' stored in the extension Settings
// generate startup code for extension activation that asks the user for the master password to a Keepass vault, and stores the master password in a secure buffer.. include a timer that clears the secure buffer after 3 hours. If the extension needs the master password but the secure buffer has been cleared, ask the user again to reenter the master password
// generate a vsc command sendQuery that calls an async function sendQuery. The async function sendQuery gets the vaule of the URL from an extension setting by the same name, gets the vaule of the Keepass secret from an extension setting by the same name, gets the vaule of the Keepass .kdbx file from an extension setting by the same name,
// the sendQuery function uses the keepassSecret to retrieve a secret from a keypass vault and palces it into a secure buffer called APIToken.
// The sendQuery function reads the data from all editor tabs, and removes the comments from the data based on the document suffix
// the sendquery function concatenates the document filename, a ':' and the comment-free document data
// the sendQuery function appends to the data the contents of the temporary document 'PromptDocument'
// the sendQuery function uses bluebird to wrap an axios to call the URL, and POST the data to the URL, using the secure buffer as a bearer token.
// expect the data returned from the URL to be a set of key value pairs, where the key is a document filename, and the value is a string of text in the diff language format
// for every key value pair returned from the URL, the sendQuery function uses the key to find a textdocument by that name, then to apply the diff using the diff library, and place the results into a new temporary file, and diplay the compare view of the origianl document and the diff results

// when the extension is deactivated, the contents of the temporary document 'PromptDocument'
// when the extension is deleted , the contents of all tempoorary files created for the diff view of the results are stored in the global state
