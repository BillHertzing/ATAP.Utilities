import * as vscode from 'vscode';
import { generateGUID } from './generateGuid';
import { mainViewTreeItem } from './mainViewTreeItem';

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
    // Initialize the command to be executed when the tree item is clicked
    const command: vscode.Command = {
      command: 'atap-aiassist.mainViewRootRecordQuickPick', // The command ID
      title: 'Show the Quick Pick on this root record', // Tooltip shown when hovering over the tree item
    };
    // ToDo: if global user state storage exists,  get the picked value from global storage for each GUID
    // ToDo: for new items get the picked value from a default structure
    // return root level items here
    const rootItems = [
      new mainViewTreeItem('RootItem1', vscode.TreeItemCollapsibleState.Collapsed, generateGUID()), //, 'RSomething'),
      new mainViewTreeItem('RootItem2', vscode.TreeItemCollapsibleState.Collapsed, generateGUID()), //,'RSomethingElse')
    ];

    // Attach the command to each root item
    for (const item of rootItems) {
      item.command = command;
    }
    return rootItems;
  }

  private getSubItems(element: mainViewTreeItem): mainViewTreeItem[] {
    const command: vscode.Command = {
      command: 'atap-aiassist.mainViewSubItemRecordQuickPick', // The command ID
      title: 'Show the Quick Pick on this item record', // Tooltip shown when hovering over the tree item
    };
    // return sub-items based on the element clicked
    const subItems = [
      new mainViewTreeItem('SubItem1', vscode.TreeItemCollapsibleState.None, generateGUID()), //, 'SSomething'),
      new mainViewTreeItem('SubItem2', vscode.TreeItemCollapsibleState.None, generateGUID()), //,'SSomethingElse')
    ];
    // Attach the command to each first level subitem
    for (const item of subItems) {
      item.command = command;
    }
    return subItems;
  }
}
