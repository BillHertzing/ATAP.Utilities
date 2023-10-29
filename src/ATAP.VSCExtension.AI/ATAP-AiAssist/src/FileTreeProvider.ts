
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

import { FileTreeItem } from './FileTreeItem';


export class FileTreeProvider implements vscode.TreeDataProvider<FileTreeItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<FileTreeItem | undefined> = new vscode.EventEmitter<FileTreeItem | undefined>();
  readonly onDidChangeTreeData: vscode.Event<FileTreeItem | undefined> = this._onDidChangeTreeData.event;

  constructor(private rootPath: string) {}

  refresh(): void {
    this._onDidChangeTreeData.fire(undefined);
  }

  getTreeItem(element: FileTreeItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: FileTreeItem): Thenable<FileTreeItem[]> {
    if (!this.rootPath) {
      vscode.window.showInformationMessage('No folder or file in explorer');
      return Promise.resolve([]);
    }

    return new Promise(resolve => {
      const children: FileTreeItem[] = [];
      const folderPath = element ? element.uri.fsPath : this.rootPath;

      fs.readdir(folderPath, (err, files) => {
        if (err) {
          vscode.window.showErrorMessage('Unable to read directory');
          return resolve([]);
        }

        files.forEach(file => {
          const filePath = path.join(folderPath, file);
          if (fs.statSync(filePath).isDirectory()) {
            children.push(new FileTreeItem(vscode.Uri.file(filePath), 'folder'));
          } else {
            children.push(new FileTreeItem(vscode.Uri.file(filePath), 'file'));
          }
        });

        return resolve(children);
      });
    });
  }
}
