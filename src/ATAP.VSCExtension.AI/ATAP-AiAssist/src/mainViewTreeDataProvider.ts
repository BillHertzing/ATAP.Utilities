import * as vscode from 'vscode';

export class mainViewTreeDataProvider implements vscode.TreeDataProvider<mainViewTreeItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<mainViewTreeItem | null> =
    new vscode.EventEmitter<mainViewTreeItem | null>();
  readonly onDidChangeTreeData: vscode.Event<mainViewTreeItem | null> = this._onDidChangeTreeData.event;

  getTreeItem(element: mainViewTreeItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: mainViewTreeItem): Thenable<mainViewTreeItem[]> {
    if (element) {
      return Promise.resolve(this.getSubItems(element));
    } else {
      return Promise.resolve(this.getRootItems());
    }
  }
  private getRootItems(): mainViewTreeItem[] {
    // return root level items here
    return [
      new mainViewTreeItem('RootItem1', vscode.TreeItemCollapsibleState.Collapsed),
      new mainViewTreeItem('RootItem2', vscode.TreeItemCollapsibleState.Collapsed)
    ];
  }

  private getSubItems(element: mainViewTreeItem): mainViewTreeItem[] {
    // return sub-items based on the element clicked
    return [
      new mainViewTreeItem('SubItem1', vscode.TreeItemCollapsibleState.None),
      new mainViewTreeItem('SubItem2', vscode.TreeItemCollapsibleState.None)
    ];
  }
}

class mainViewTreeItem extends vscode.TreeItem {
  constructor(public readonly label: string, public readonly collapsibleState: vscode.TreeItemCollapsibleState) {
    super(label, collapsibleState);
  }
}
