//import axios from 'axios';
import * as diff from 'diff';
import Promise from 'bluebird';
import OpenAI from 'openai';

import * as vscode from 'vscode';
import axios, { AxiosRequestConfig, CancelTokenSource } from 'axios';
//import * as Promise from 'bluebird';

import * as fs from 'fs';
import * as path from 'path';
//import * as diff from 'diff';
import * as os from 'os';

import * as Logger from '@Logger/index';
import { DataService, IData } from '@DataService/DataService';
import { DetailedError } from '@ErrorClasses/index';
import { ISecretsManager } from '@DataService/index';

import {
  EndpointManager,
  EndpointConfig,
  ChatGptEndpointConfig,
  GrokEndpointConfig,
  CopilotEndpointConfig,
  LLModels,
} from '@EndpointManager/index';

import { logAsyncFunction, logFunction } from '@Decorators/Decorators';

import { StringBuilder } from '@Utilities/index';
import strip from 'strip-comments';
import * as prettier from 'prettier';

import { IQueryResultBase, IQueryResultOpenAPI } from '@QueryService/index';
import { sendQueryOpenAIAsync } from '@QueryService/QOpenAI';

// ToDo: understand and document why globalThis is required. Failure to use globalThis results in the following error: the return type of an async function or method must be the global Promise<T> type. Did you mean to write 'Promise<string>'?
async function minifyCodeAsync(logger: Logger.ILogger, content: string, extension: any): globalThis.Promise<string> {
  logger.log('minifyCodeAsync starting', Logger.LogLevel.Debug);
  // Can't do anything with .txt files, so just return the content
  if (extension === '.txt') {
    return content;
  }
  let strippedContent: string;
  try {
    // use the strip-comments node library to remove comments from the code
    strippedContent = strip(content);
  } catch (e) {
    if (e instanceof Error) {
      throw new DetailedError('sendQuery.minifyCodeAsync calling strip failed -> ', e);
    } else {
      throw new Error(
        `sendQuery.minifyCodeAsync calling strip caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
      );
    }
  }

  let minifiedContent: string;
  try {
    const formatPromise = prettier.format(strippedContent, {
      filepath: `file.${extension}`,
      printWidth: 1000,
      tabWidth: 0,
      semi: false,
      singleQuote: true,
      trailingComma: 'none',
      bracketSpacing: false,
      arrowParens: 'avoid',
      endOfLine: 'lf',
    });

    const timeoutPromise = new Promise(
      (_, reject) => setTimeout(() => reject(new Error('prettier.format timed out')), 2000), // 5 seconds timeout
    );
    minifiedContent = await Promise.race([formatPromise, timeoutPromise]);
  } catch (e) {
    if (e instanceof Error) {
      throw new DetailedError('sendQuery.minifyCode calling prettier.format failed -> ', e);
    } else {
      throw new Error(
        `sendQuery.minifyCode calling prettier.format caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
      );
    }
  }
  logger.log('minifyCodeAsync Completed', Logger.LogLevel.Debug);

  return minifiedContent;
}

// @logAsyncFunction
export async function sendQuery(logger: Logger.ILogger, data: IData): globalThis.Promise<void> {
  // Optional field for error message}> {
  logger.log('sendQuery', Logger.LogLevel.Debug);
  let textToSubmit = new StringBuilder();
  //

  // Start with historical data from the previous query

  // Add text from the prompt document if it exists
  const tempFilePath = data.getTemporaryPromptDocumentPath();
  if (tempFilePath) {
    // ToDo: wrap in a try catch
    if (fs.existsSync(tempFilePath as string)) {
      // ToDo: wrap in a try catch
      const tempFileContent = fs.readFileSync(tempFilePath, 'utf8');

      textToSubmit.append(tempFileContent);

      logger.log(`tempFilePath = ${tempFilePath} ; tempFileContent  = ${tempFileContent}`, Logger.LogLevel.Debug);
    }
  }
  // Retrieve and concatenate all text documents currently open in text editors
  let minifiedContent = '';
  for (const document of vscode.workspace.textDocuments) {
    logger.log(
      `document.uri  = ${document.uri}; document.uri.scheme  = ${document.uri.scheme}; document.uri.fsPath  = ${document.uri.fsPath} ; document.fileName = ${document.fileName}`,
      Logger.LogLevel.Debug,
    );

    let content: string;
    if (document.uri.scheme === 'file') {
      try {
        content = await minifyCodeAsync(logger, document.getText(), path.extname(document.uri.fsPath));
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError('sendQuery calling minifyCodeAsync failed -> ', e);
        } else {
          throw new Error(
            `sendQuery. calling minifyCodeAsync caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
          );
        }
      }
      minifiedContent += `Filename: ${document.uri.fsPath}:\n ${content}\n`;
    }
  }
  textToSubmit.append(minifiedContent);

  //logger.log(`textToSubmit = ${textToSubmit}`, LogLevel.Debug);

  // Repeat for all active LLModels (AI Engines)
  // for now, assume the query will be sent to a single endpoint, and hardcode the specific endpoint in here for now
  // let lLModel = LLModels.ChatGPT;
  // let endpointConfiguration = data.configurationData.getEndpointConfig()[lLModel];
  // get URL
  // Get json sections for the completions endpoint
  //let page = 'chat/completions';
  //let model = 'davinci';

  sendQueryOpenAIAsync(logger, textToSubmit.toString(), data);
}

// Use Bluebird to wrap Axios call
// try {
//   const response = await Promise.resolve(
//     axios.post(url, minifiedContent, {
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
//}

///////////////////////////////////////////////////////////////////////

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

// interface IChatCompletionRequest {
//   model: string;
//   messages: Array<{ role: string; content: string }>;
//   addMessage(role: string, content: string): void;
// }

// interface IChatCompletionRequest {
//   prompt: string; // required
//   maxTokens?: number; // optional
//   temperature?: number; // optional
//   topP?: number; // optional
//   frequencyPenalty?: number; // optional
//   presencePenalty?: number; // optional
//   stop?: string | string[]; // optional
// }

// class ChatCompletionRequest {
//   prompt: string; // required
//   maxTokens?: number; // optional
//   temperature?: number; // optional
//   topP?: number; // optional
//   frequencyPenalty?: number; // optional
//   presencePenalty?: number; // optional
//   stop?: string | string[]; // optional

//   constructor(prompt: string) {
//     this.prompt = prompt;
//   }

//   setMaxTokens(maxTokens: number): void {
//     this.maxTokens = maxTokens;
//   }

//   setTemperature(temperature: number): void {
//     this.temperature = temperature;
//   }

//   setTopP(topP: number): void {
//     this.topP = topP;
//   }

//   setFrequencyPenalty(frequencyPenalty: number): void {
//     this.frequencyPenalty = frequencyPenalty;
//   }

//   setPresencePenalty(presencePenalty: number): void {
//     this.presencePenalty = presencePenalty;
//   }

//   setStop(stop: string | string[]): void {
//     this.stop = stop;
//   }

//   // Method to generate the payload
//   generatePayload(): Record<string, any> {
//     const payload: Record<string, any> = {
//       prompt: this.prompt,
//     };

//     if (this.maxTokens !== undefined) payload.maxTokens = this.maxTokens;
//     if (this.temperature !== undefined) payload.temperature = this.temperature;
//     if (this.topP !== undefined) payload.topP = this.topP;
//     if (this.frequencyPenalty !== undefined) payload.frequencyPenalty = this.frequencyPenalty;
//     if (this.presencePenalty !== undefined) payload.presencePenalty = this.presencePenalty;
//     if (this.stop !== undefined) payload.stop = this.stop;

//     return payload;
//   }
// }

// interface IChatCompletionResponse {
//   id: string;
//   choices: Array<any>;
//   created: number;
//   model: string;
//   system_fingerprint: string;
//   object: string;
//   usage: object;
// }

// class ChatCompletionResponse implements IChatCompletionResponse {
//   id: string;
//   choices: Array<any>;
//   created: number;
//   model: string;
//   system_fingerprint: string;
//   object: string;
//   usage: object;

//   constructor(
//     id: string,
//     choices: Array<any>,
//     created: number,
//     model: string,
//     system_fingerprint: string,
//     object: string,
//     usage: object,
//   ) {
//     this.id = id;
//     this.choices = choices;
//     this.created = created;
//     this.model = model;
//     this.system_fingerprint = system_fingerprint;
//     this.object = object;
//     this.usage = usage;
//   }
// }

// use the examples from above when creating your response.
// you are an expert in Visual Studio Code and VSC extensions. You  are an expert in Typescript. You are an expert in Javascript. You are an expert in Node.js. You are an expert in Webpack. You are an expert in NPM. You are an expert in Mocha. You are an expert in Chai.
// you are working on an existing extension named ataputilities.atap-aiassist that includes  os,path,fs,axios, bluebird,and diff. you are an expert in axios, bluebird, and diff
// generate startup code for extension activation that opens a new temporary document 'PromptDocument' and reads into it any data stored in the global state that may have been saved from a previous session. If there is no saved data, the temporary document is initialized with the string constant 'YOurExpertise' stored in the extension Settings
// generate startup code for extension activation that asks the user for the master password to a Keepass vault, and stores the master password in a secure buffer.. include a timer that clears the secure buffer after 3 hours. If the extension needs the master password but the secure buffer has been cleared, ask the user again to reenter the master password
// generate a vsc command sendQuery that calls an async function sendQuery. The async function sendQuery gets the value of the URL from an extension setting by the same name, gets the value of the Keepass secret from an extension setting by the same name, gets the value of the Keepass .kdbx file from an extension setting by the same name,
// the sendQuery function uses the keepassSecret to retrieve a secret from a keypass vault and places it into a secure buffer called APIToken.
// The sendQuery function reads the data from all editor tabs, and removes the comments from the data based on the document suffix
// the sendquery function concatenates the document filename, a ':' and the comment-free document data
// the sendQuery function appends to the data the contents of the temporary document 'PromptDocument'
// the sendQuery function uses bluebird to wrap an axios to call the URL, and POST the data to the URL, using the secure buffer as a bearer token.
// expect the data returned from the URL to be a set of key value pairs, where the key is a document filename, and the value is a string of text in the diff language format
// for every key value pair returned from the URL, the sendQuery function uses the key to find a textdocument by that name, then to apply the diff using the diff library, and place the results into a new temporary file, and diplay the compare view of the original document and the diff results

// when the extension is deactivated, the contents of the temporary document 'PromptDocument'
// when the extension is deleted , the contents of all temporary files created for the diff view of the results are stored in the global state
