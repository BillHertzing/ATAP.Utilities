import * as vscode from 'vscode';
import { LogLevel, Logger } from './Logger';

export class mainViewTreeItem extends vscode.TreeItem {
  private readonly logger: Logger;

  public Philote_ID: string;
  public pickedValue: string;

  constructor(
    label: string,
    collapsibleState: vscode.TreeItemCollapsibleState,
    logger: Logger,
    public readonly properties: any,
  ) {
    //guid: string, pickedValue: string,  public properties: any
    super(label, collapsibleState);
    let message: string = `mainViewTreeItem constructor, label ${label}`;
    logger.log(message, LogLevel.Debug);
    this.logger = logger;
    this.contextValue = 'mainViewTreeItemContext';
    this.Philote_ID = 'dummy'; //guid;
    this.pickedValue = 'dummy2'; //pickedValue;
    message = `label = ${label} ; contextValue =  ${this.contextValue};  Philote_ID =  ${this.Philote_ID};  pickedValue =  ${this.pickedValue}; properties = ${this.properties};`;
    logger.log(message, LogLevel.Debug);
  }
}
