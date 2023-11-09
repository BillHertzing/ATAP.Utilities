import * as vscode from 'vscode';
import { generateGuid } from './Utilities'; // '@Utilities/index';
import { LogLevel, Logger } from './Logger'; //'@Logger/index';
import { mainViewTreeItem } from './mainViewTreeItem';

export class mainViewTreeDataProvider implements vscode.TreeDataProvider<mainViewTreeItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<mainViewTreeItem | null> =
    new vscode.EventEmitter<mainViewTreeItem | null>();
  readonly onDidChangeTreeData: vscode.Event<mainViewTreeItem | null> = this._onDidChangeTreeData.event;
  private readonly logger: Logger;
  private message: string;

  constructor(logger: Logger) {
    this.logger = logger;
    this.message = `mainViewTreeDataProvider constructor called`;
    this.logger.log(this.message, LogLevel.Debug);
  }

  getTreeItem(element: mainViewTreeItem): vscode.TreeItem {
    this.message = `mainViewTreeDataProviderInstance.getTreeItem called`;
    this.logger.log(this.message, LogLevel.Debug);
    return element;
  }

  getChildren(element?: mainViewTreeItem): Thenable<mainViewTreeItem[]> {
    this.message = `mainViewTreeDataProviderInstance.getChildren called`;
    this.logger.log(this.message, LogLevel.Debug);
    if (element) {
      return Promise.resolve(this.getSubItems(element));
    } else {
      return Promise.resolve(this.getRootItems());
    }
  }

  private getRootItems(): mainViewTreeItem[] {
    this.message = `mainViewTreeDataProviderInstance.getRootItems called`;
    this.logger.log(this.message, LogLevel.Debug);

    // Initialize the command to be executed when the tree item is clicked
    const command: vscode.Command = {
      command: 'atap-aiassist.showMainViewRootRecordProperties', // The command ID
      title: 'Show the Root Record properties on this root record', // Tooltip shown when hovering over the tree item
    };
    // ToDo: if global user state storage exists,  get the picked value from global storage for each GUID
    // ToDo: for new items get the picked value from a default structure
    // return root level items here
    const rootItems = [
      new mainViewTreeItem('RootItem1', vscode.TreeItemCollapsibleState.Collapsed, this.logger, generateGuid()), //, 'RSomething'),
      new mainViewTreeItem('RootItem2', vscode.TreeItemCollapsibleState.Collapsed, this.logger, generateGuid()), //,'RSomethingElse')
    ];

    // Attach the command to each root item
    for (const item of rootItems) {
      item.command = command;
    }
    return rootItems;
  }

  private getSubItems(element: mainViewTreeItem): mainViewTreeItem[] {
    this.message = `mainViewTreeDataProviderInstance.getSubItems called`;
    this.logger.log(this.message, LogLevel.Debug);

    const command: vscode.Command = {
      command: 'atap-aiassist.showSubItemProperties', // The command ID
      title: 'Show the SubItem properties on this SubItem', // Tooltip shown when hovering over the tree item
    };
    // return sub-items based on the element clicked
    const subItems = [
      new mainViewTreeItem('SubItem1', vscode.TreeItemCollapsibleState.None, this.logger, generateGuid()), //, 'SSomething'),
      new mainViewTreeItem('SubItem2', vscode.TreeItemCollapsibleState.None, this.logger, generateGuid()), //,'SSomethingElse')
    ];
    // Attach the command to each first level subitem
    for (const item of subItems) {
      item.command = command;
    }
    return subItems;
  }
}
