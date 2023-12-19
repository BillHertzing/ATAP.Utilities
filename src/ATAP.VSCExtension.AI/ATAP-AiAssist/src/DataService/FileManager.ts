import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor } from '@Decorators/index';

import { ILogger } from '@Logger/index';
import { IConfigurationData } from '@DataService/index';

type AsyncFileFunction = (file: vscode.Uri) => Promise<void>;

export interface IFileManager {
  temporaryFilePaths: fs.PathLike[];
  checkFileAsync(path: string, mode: number): Promise<boolean>;
  getNewTemporaryFilePath(extension: string): number;
  processFilesAsync(extension: string, func: AsyncFileFunction): Promise<void>;
  dispose(): void;
}

@logConstructor
export class FileManager implements IFileManager {
  private temporaryFileDirectoryPath: fs.PathLike;
  public readonly temporaryFilePaths: fs.PathLike[] = [];
  private disposed = false;

  constructor(
    readonly logger: ILogger,
    readonly configurationData: IConfigurationData,
  ) {
    this.temporaryFileDirectoryPath = path.join(
      configurationData.getTempDirectoryBasePath(),
      configurationData.getExtensionFullName(),
    );
    try {
      fs.mkdirSync(this.temporaryFileDirectoryPath, { recursive: true });
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`FileManager.ctor: failed to create $this.temporaryFileDirectoryPath} -> `, e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `FileManager.ctor: failed to create ${
            this.temporaryFileDirectoryPath
          } and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }

  public checkFileAsync(path: fs.PathLike, mode: number): Promise<boolean> {
    return new Promise((resolve, reject) => {
      fs.access(path, mode, (err) => {
        if (err) {
          reject(err);
        } else {
          resolve(true);
        }
      });
    });
  }

  getNewTemporaryFilePath(extension: string): number {
    const randomFileName = crypto.randomBytes(16).toString('hex') + extension;
    const temporaryFilePath = path.join(this.temporaryFileDirectoryPath.toString(), randomFileName);
    this.temporaryFilePaths.push(temporaryFilePath);
    return this.temporaryFilePaths.length - 1;
  }

  async processFilesAsync(extension: string, func: AsyncFileFunction): Promise<void> {
    // Search for all files with the given extension in the workspace
    let pattern = `**/*.${extension}`;
    let files = await vscode.workspace.findFiles(pattern);

    // Loop through the results
    for (let file of files) {
      // Apply the function to each file
      await func(file);
    }
  }

  dispose() {
    if (!this.disposed) {
      // release any resources
      this.disposed = true;
    }
  }
}
