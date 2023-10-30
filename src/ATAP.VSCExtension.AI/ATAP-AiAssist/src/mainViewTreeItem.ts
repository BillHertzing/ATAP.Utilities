
import * as vscode from 'vscode';

export class mainViewTreeItem extends vscode.TreeItem {
  public Philote_ID: string;

  constructor(label: string, collapsibleState: vscode.TreeItemCollapsibleState, guid: string) {
    super(label, collapsibleState);
    this.Philote_ID = guid;
  }
}


