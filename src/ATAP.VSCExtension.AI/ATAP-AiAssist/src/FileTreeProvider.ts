import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class FileTreeProvider implements vscode.TreeDataProvider<vscode.TreeItem> {
  getTreeItem(element: vscode.TreeItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: vscode.TreeItem): vscode.ProviderResult<vscode.TreeItem[]> {
    if (!element) {
      // For demonstration, you could replace this with a dynamic path
      return this.readDirectory('C:/Dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.VSCExtension.AI/ATAP-AiAssist');
    }
    return [];
  }

  private readDirectory(dir: string): vscode.TreeItem[] {
    const items: vscode.TreeItem[] = [];
    const files = fs.readdirSync(dir);
    for (const file of files) {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      if (stat.isDirectory()) {
        items.push(new vscode.TreeItem(file, vscode.TreeItemCollapsibleState.Collapsed));
      } else {
        items.push(new vscode.TreeItem(file, vscode.TreeItemCollapsibleState.None));
      }
    }
    return items;
  }
}
