import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor } from '@Decorators/index';

import { ILogger } from '@Logger/index';
import { IConfigurationData } from '@DataService/index';

export interface IFileManager {
  temporaryFilePaths: fs.PathLike[];
  checkFileAsync(path: string, mode: number): Promise<boolean>;
  getNewTemporaryFilePath(extension: string): number;
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

  dispose() {
    if (!this.disposed) {
      // release any resources
      this.disposed = true;
    }
  }
}
