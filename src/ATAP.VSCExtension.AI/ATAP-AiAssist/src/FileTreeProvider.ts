import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { TreeItemWithChildren } from './TreeItemWithChildren';


export class FileTreeProvider implements vscode.TreeDataProvider<TreeItemWithChildren> {
  getTreeItem(element: TreeItemWithChildren): TreeItemWithChildren {
    return element;
  }

  getChildren(element?: TreeItemWithChildren): vscode.ProviderResult<TreeItemWithChildren[]> {
    if (!element) {
      // For demonstration, you could replace this with a dynamic path
      return this.readDirectory('C:/Dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.VSCExtension.AI/ATAP-AiAssist');
    }
    return [];
  }

  private readDirectory(dir: string): TreeItemWithChildren[] {
    const items: TreeItemWithChildren[] = [];
    const files = fs.readdirSync(dir);
    for (const file of files) {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      if (stat.isDirectory()) {
        const directoryItem = new TreeItemWithChildren(file, vscode.TreeItemCollapsibleState.Collapsed);
        directoryItem.children = this.readDirectory(filePath); // Recursively read directory
        items.push(new TreeItemWithChildren(file, vscode.TreeItemCollapsibleState.Collapsed));
      } else {
        items.push(new TreeItemWithChildren(file, vscode.TreeItemCollapsibleState.None));
      }
    }
    return items;
  }
}
