import { LogLevel, ILogger } from '@Logger/Logger';
import * as vscode from 'vscode';


import { ExternalDataVetting } from './ExternalDataVetting';

export class SecurityService {
  private message: string;
  private externalDataVetting: ExternalDataVetting;

  constructor(private logger: ILogger, private context: vscode.ExtensionContext) {
    this.message = 'starting SecurityService constructor';
    this.logger.log(this.message, LogLevel.Trace);

    this.externalDataVetting = new ExternalDataVetting(this.logger);

    this.message = 'leaving SecurityService constructor';
    this.logger.log(this.message, LogLevel.Trace);
  }
}
