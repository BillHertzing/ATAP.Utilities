import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';


import { ExternalDataVetting } from './ExternalDataVetting';

export class SecurityService {
  private message: string;
  private externalDataVetting: ExternalDataVetting;

  constructor(private logger: ILogger, private extensionContext: vscode.ExtensionContext) {
    this.message = 'starting SecurityService constructor';
    this.logger.log(this.message, LogLevel.Trace);

    this.externalDataVetting = new ExternalDataVetting(this.logger);

    this.message = 'leaving SecurityService constructor';
    this.logger.log(this.message, LogLevel.Trace);
  }
}
