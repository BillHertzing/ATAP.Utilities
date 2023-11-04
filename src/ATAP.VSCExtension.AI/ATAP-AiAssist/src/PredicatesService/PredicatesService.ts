import {
  LogLevel,
  ChannelInfo,
  ILogger,
  Logger,
  getLoggerLogLevelFromSettings,
  setLoggerLogLevelFromSettings,
  getDevelopmentLoggerLogLevelFromSettings,
  setDevelopmentLoggerLogLevelFromSettings,
} from '../Logger';
import * as vscode from 'vscode';
import * as yaml from 'js-yaml';

export class PredicatesService {
  private message: string;

  constructor(private logger: ILogger) {
    this.message = 'starting PredicatesService constructor';
    this.logger.log(this.message, LogLevel.Trace);
    this.loadTagsFromSettings();
    this.loaCategorysFromSettings();
    this.loadPredicatesFromSettings();
    this.message = 'leaving PredicatesService constructor';
    this.logger.log(this.message, LogLevel.Trace);
  }

  private loadTagsFromSettings(): void {
    this.message = 'starting loadTagsFromSettings';
    this.logger.log(this.message, LogLevel.Trace);
  }
  private loaCategorysFromSettings(): void {
    this.message = 'starting loadTagsFromSettings';
    this.logger.log(this.message, LogLevel.Trace);
  }
  private loadPredicatesFromSettings(): void {
    this.message = 'starting loadTagsFromSettings';
    this.logger.log(this.message, LogLevel.Trace);
  }
}
