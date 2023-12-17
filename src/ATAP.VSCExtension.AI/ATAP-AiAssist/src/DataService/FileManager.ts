import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

import { ILogger } from '@Logger/index';
import { logConstructor } from '@Decorators/index';
import { IData } from '@DataService/index';

export interface IFileManager {
  temporaryFilePaths: fs.PathLike[];
  checkFileAsync(path: string, mode: number): Promise<boolean>;
}

@logConstructor
export class FileManager implements IFileManager {
  public readonly temporaryFilePaths: fs.PathLike[] = [];
  constructor(readonly logger: ILogger) {}

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
}
