import * as vscode from 'vscode';
import * as fs from 'fs';
import { LogLevel, ILogger } from '../Logger';

interface IProcessResult {
  success: boolean;
  numLinesOriginal: number | undefined;
}

class ProcessResult implements IProcessResult {
  success: boolean;
  numLinesOriginal: number | undefined;

  constructor(success: boolean, numLinesOriginal: number | undefined) {
    this.success = success;
    this.numLinesOriginal = numLinesOriginal;
  }

  // ToDo: JASON, YAML and string serializers and deserializers
  // Additional functionality can be added to the class as needed
  // printResult(): void {
  //   console.log(`Success: ${this.success}, Number of Original Lines: ${this.numLinesOriginal}`);
  // }
}

async function processFiles(
  paths: string[],
  asyncFunctionToExecute: (path: string, logger: ILogger) => Promise<ProcessResult>,
  logger: ILogger,
): Promise<ProcessResult[]> {
  let message: string = 'starting processFiles';
  logger.log(message, LogLevel.Debug);

  const results: ProcessResult[] = [];

  for (const path of paths) {
    const result = await asyncFunctionToExecute(path, logger);
    results.push(result);
  }

  return results;
}

// export async function sendFilesToAPI(extensionContext: vscode.ExtensionContext, logger: ILogger) {
//   let message: string = 'starting command sendFilesToAPI';
//   logger.log(message, LogLevel.Debug);

//   // List of file paths to be processed
//   const filesToProcess: string[] = [
//     // Populate this array with actual file paths
//   ];

//   // Destination web address
//   const destination: string = 'https://your.api.endpoint/submit'; // ToDo:from settings

// Async function to send the file to the API
// const sendToAPI = async (path: string, logger: ILogger): Promise<ProcessResult> => {
//   try {
//     const fileContent = fs.readFileSync(path, 'utf8');
//     const response = await axios.post(destination, {
//       file: fileContent,
//       filename: path,
//     });
//     message = `File ${path} was sent successfully.`;
//     logger.log(message, LogLevel.Info);
//     return new ProcessResult(response.status === 200, fileContent.split('\n').length);
//   } catch (e) {
//     if (e instanceof Error) {
//       // Report the error
//       message = e.message;
//     } else {
//       // ToDo: e is not an instance of Error, needs investigation to determine what else might happen
//       message = `An unknown error occurred during the copyToSubmit call, and the instance of (e) returned is of type ${typeof e}`;
//     }
//     logger.log(message, LogLevel.Error);
//     return new ProcessResult(false, undefined);
//   }
// };

// Call 'processFiles' with 'filesToProcess' and 'sendToAPI'
//   try {
//     const results = await processFiles(filesToProcess, sendToAPI, logger);
//     message = `All files processed. Results: ${JSON.stringify(results)}`;
//     logger.log(message, LogLevel.Info);
//   } catch (e) {
//     if (e instanceof Error) {
//       // Report the error
//       message = e.message;
//     } else {
//       // ToDo: e is not an instance of Error, needs investigation to determine what else might happen
//       message = `An unknown error occurred during the processFiles call, and the instance of (e) returned is of type ${typeof e}`;
//     }
//     logger.log(message, LogLevel.Error);
//   }

//   message = 'leaving command sendFilesToAPI';
//   logger.log(message, LogLevel.Debug);
// }

// export async function  processFiles(logger: ILogger, commandId: string | null): void {
//   let message: string = 'starting commandID processFiles';
//   logger.log(message, LogLevel.Debug);

//       const processPs1FilesRecord = await processFiles(commandId);
//       if (processPs1FilesRecord.success) {
//         message = `processFiles processed ${processPs1FilesRecord.numFilesProcessed} files, using commandID  ${processPs1FilesRecord.commandIDUsed}`;
//         vscode.window.showInformationMessage(`${message}`);
//       } else {
//         message = `processFiles failed, error message is ${processPs1FilesRecord.errorMessage}, attemptedCommandID is ${processPs1FilesRecord.commandIDUsed}`;
//         vscode.window.showErrorMessage(`${message}`);
//       }
//     },
//   );
// }
// async function processSingleFile(path: string, logger: ILogger): Promise<ProcessResult> {
//   let message: string = 'starting processSingleFile';
//   logger.log(message, LogLevel.Debug);

// }
