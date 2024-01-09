import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';

// an enumeration to represent the differing Logging levels
export enum LogLevel {
  Error = 0,
  Warning = 1,
  Info = 2,
  Debug = 3,
  Trace = 4,
  Performance = 5,
}

export interface ChannelInfo {
  outputChannel: vscode.OutputChannel | undefined;
  enabled: boolean;
  level: LogLevel;
}

export interface ILogger {
  createChannel(name: string, level: LogLevel, enabled: boolean): void;
  log(message: string, level: LogLevel, channelName?: string): void;
  setChannelEnabled(channelName: string, enabled: boolean): void;
  setChannelLogLevel(channelName: string, level: LogLevel): void;
  getChannelInfo(channelName: string): ChannelInfo | null;
}

export class Logger implements ILogger {
  private channels: { [key: string]: ChannelInfo } = {
    console: { outputChannel: undefined, enabled: true, level: LogLevel.Trace },
  };
  private static staticOutputChannel: vscode.OutputChannel;

  constructor() {}

  static staticConstructor() {
    Logger.staticOutputChannel = vscode.window.createOutputChannel('AiAssistStaticLogger');
  }

  static staticLog(message: string, level: LogLevel) {
    Logger.staticOutputChannel.appendLine(`[${LogLevel[level]}] ${message}`);
  }

  createChannel(name: string, level: LogLevel, enabled: boolean = true): void {
    const outputChannel = vscode.window.createOutputChannel(name);
    this.channels[name] = { outputChannel, enabled, level };
  }

  log(message: string, level: LogLevel, channelName?: string): void {
    // eslint-disable-next-line eqeqeq
    if (channelName != null) {
      const channelInfo = this.channels[channelName];
      if (channelInfo && channelInfo.enabled && level <= channelInfo.level) {
        if (channelName === 'console') {
          console.log(`[${LogLevel[level]}] ${message}`);
        } else {
          let _outputChannel: vscode.OutputChannel = channelInfo.outputChannel as vscode.OutputChannel;
          _outputChannel.appendLine(`[${LogLevel[level]}] ${message}`);
        }
      }
    } else {
      for (const channelName in this.channels) {
        const channelInfo = this.channels[channelName];
        if (channelInfo && channelInfo.enabled && level <= channelInfo.level) {
          if (channelName === 'console') {
            console.log(`[${LogLevel[level]}] ${message}`);
          } else {
            let _outputChannel: vscode.OutputChannel = channelInfo.outputChannel as vscode.OutputChannel;
            _outputChannel.appendLine(`[${LogLevel[level]}] ${message}`);
          }
        }
      }
    }
  }

  setChannelEnabled(channelName: string, enabled: boolean): void {
    const channelInfo = this.channels[channelName];
    if (channelInfo) {
      channelInfo.enabled = enabled;
    }
  }

  setChannelLogLevel(channelName: string, level: LogLevel): void {
    const channelInfo = this.channels[channelName];
    if (channelInfo) {
      channelInfo.level = level;
    }
  }

  getChannelInfo(channelName: string): ChannelInfo | null {
    const channelInfo = this.channels[channelName];
    return channelInfo ? channelInfo : null;
  }

  dispose(): void {
    for (const channelName in this.channels) {
      if (channelName !== 'console') {
        let _outputChannel: vscode.OutputChannel = this.channels[channelName].outputChannel as vscode.OutputChannel;
        _outputChannel.dispose();
      }
    }
  }
}
