import * as vscode from 'vscode';

export enum LogLevel {
  Error = 0,
  Warning = 1,
  Info = 2,
  Debug = 3,
  Trace = 4
}

// Function to read log level
export function getLoggerLogLevelFromSettings(): LogLevel {
  const configuration = vscode.workspace.getConfiguration('atap-aiassist');
  const logLevel = configuration.get<LogLevel>('Logger.LogLevel', LogLevel.Info); // default to LogLevel.Info
  return logLevel;
}

// Function to update log level
export function setLoggerLogLevelFromSettings(newLevel: LogLevel): Thenable<void> {
  const configuration = vscode.workspace.getConfiguration('atap-aiassist');
  return configuration.update('Logger.LogLevel', newLevel, vscode.ConfigurationTarget.Global);
}

// Function to read the Development log level
export function getDevelopmentLoggerLogLevelFromSettings(): LogLevel {
  const configuration = vscode.workspace.getConfiguration('atap-aiassist');
  const logLevel = configuration.get<LogLevel>('Development.Logger.LogLevel', LogLevel.Debug); // default to LogLevel.Debug
  return logLevel;
}

// Function to update the Development log level
export function setDevelopmentLoggerLogLevelFromSettings(newLevel: LogLevel): Thenable<void> {
  const configuration = vscode.workspace.getConfiguration('atap-aiassist');
  return configuration.update('Development.Logger.LogLevel', newLevel, vscode.ConfigurationTarget.Global);
}

interface ChannelInfo {
  outputChannel: vscode.OutputChannel;
  enabled: boolean;
  level: LogLevel;
}

export class Logger {
  private channels: { [key: string]: ChannelInfo } = {};

  constructor() {}

  createChannel(name: string, level: LogLevel, enabled: boolean = true): void {
    const outputChannel = vscode.window.createOutputChannel(name);
    this.channels[name] = { outputChannel, enabled, level };
  }

  log(message: string, level: LogLevel, channelName: string): void {
    const channelInfo = this.channels[channelName];
    if (channelInfo && channelInfo.enabled && level <= channelInfo.level) {
      channelInfo.outputChannel.appendLine(`[${LogLevel[level]}] ${message}`);
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

  dispose(): void {
    for (const channelName in this.channels) {
      this.channels[channelName].outputChannel.dispose();
    }
  }
}
