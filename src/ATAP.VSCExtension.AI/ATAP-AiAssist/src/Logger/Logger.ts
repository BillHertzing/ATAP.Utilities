import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';

// implement the logger using pino
import pino from 'pino'; // eslint-disable-line @typescript-eslint/no-var-requires
import pinoPretty from 'pino-pretty'; // eslint-disable-line @typescript-eslint/no-var-requires

// an enumeration to represent the differing Logging levels
export enum LogLevel {
  Fatal = 1,
  Error = 2,
  Warn = 3,
  Info = 4,
  Debug = 5,
  Trace = 6,
  Performance = 7,
}

// an enumeration to represent the differing Logging destinations
export enum DestinationEnum {
  Console = 0,
  Extension = 1,
  File = 2,
}

export interface ChannelInfo {
  outputChannel: vscode.OutputChannel | undefined;
  enabled: boolean;
  level: LogLevel;
}

export interface DestinationInfo {
  enabled: boolean;
  level: LogLevel;
  options: Record<string, any>;
}

export type DestinationType = Record<DestinationEnum, DestinationInfo>;

export interface ILogger {
  readonly scope: string;
  fatal(message: string, scope?: string, channelName?: string): void;
  error(message: string, scope?: string, channelName?: string): void;
  warn(message: string, scope?: string, channelName?: string): void;
  info(message: string, scope?: string, channelName?: string): void;
  debug(message: string, scope?: string, channelName?: string): void;
  trace(message: string, scope?: string, channelName?: string): void;
  performance(message: string, scope?: string, channelName?: string): void;
  log(message: string, level: LogLevel, scope?: string, channelName?: string): void;
  dispose(): void;
}

export class Logger implements ILogger {
  private static extensionName: string;
  private static rootScope: string;
  private static channels: { [key: string]: ChannelInfo } = {
    console: { outputChannel: undefined, enabled: true, level: LogLevel.Debug },
  };
  private static pinoLogger: pino.Logger;
  private static staticOutputChannel: vscode.OutputChannel;
  private static destinations: Partial<DestinationType>;
  public readonly scope: string;

  // This creates the Logger static instance data for the
  static createLogger(rootScope: string, extensionName?: string): ILogger {
    // Create the static set of destinations for the logger class
    // configure the logger instance to write to the console and to an output channel having the same name as the extension, with a LogLevel of Info

    Logger.extensionName = extensionName ? extensionName : rootScope;

    Logger.staticOutputChannel = vscode.window.createOutputChannel(Logger.extensionName);
    Logger.destinations = {
      [DestinationEnum.Console]: { enabled: true, level: LogLevel.Debug, stream: process.stdout, options: {} },
      //[DestinationEnum.Extension]: { enabled: true, level: LogLevel.Debug, options: {outputChannel: vscode.OutputChannel} } },
      //[DestinationEnum.File]: { enabled: false, level: LogLevel.Debug, options: {},
    } as Partial<DestinationType>;
    // create channels for the exrtension (rootScope) and the console
    if (true) {
      Logger.createChannel(rootScope, LogLevel.Debug, true);
      Logger.setChannelEnabled('console', true);
      Logger.setChannelEnabled(rootScope, true);
    }
    const transport = pinoPretty({
      colorize: true,
      translateTime: 'SYS:standard',
    });
    Logger.pinoLogger = pino(
      {
        level: 'trace',
      },
      transport,
    ).child({ bindings: () => ({}) });
    return new Logger(null, rootScope);
  }

  constructor(logger: ILogger | null, scope: string) {
    if (logger) {
      this.scope = logger.scope + '.' + scope;
    } else {
      this.scope = scope;
    }
  }

  fatal(message: string): void {
    Logger.pinoLogger.fatal(message);
  }

  error(message: string): void {
    Logger.pinoLogger.error(message);
  }

  warn(message: string): void {
    Logger.pinoLogger.warn(message);
  }

  info(message: string): void {
    Logger.pinoLogger.info(message);
  }

  debug(message: string): void {
    Logger.pinoLogger.debug(message);
  }

  trace(message: string): void {
    Logger.pinoLogger.trace(message);
  }

  performance(message: string): void {
    Logger.pinoLogger.trace(message);
  }

  static staticLog(message: string, level: LogLevel) {
    const _message = `[${LogLevel[level]}] [${new Date().toISOString()}] ${message}`;

    Logger.staticOutputChannel.appendLine(_message);
  }

  static createChannel(name: string, level: LogLevel, enabled: boolean = true): void {
    const outputChannel = vscode.window.createOutputChannel(name);
    this.channels[name] = { outputChannel, enabled, level };
  }

  static setChannelEnabled(channelName: string, enabled: boolean): void {
    const channelInfo = this.channels[channelName];
    if (channelInfo) {
      channelInfo.enabled = enabled;
    }
  }

  log(message: string, level: LogLevel, channelName?: string): void {
    const _message = `[${LogLevel[level]}] [${new Date().toISOString()}] ${message}`;
    switch (level) {
      case LogLevel.Fatal:
        this.fatal(_message);
        break;
      case LogLevel.Error:
        this.error(_message);
        break;
      case LogLevel.Warn:
        this.warn(_message);
        break;
      case LogLevel.Info:
        this.info(_message);
        break;
      case LogLevel.Debug:
        this.debug(_message);
        break;
      case LogLevel.Trace:
        this.trace(_message);
        break;
      case LogLevel.Performance:
        this.performance(_message);
        break;
    }

    // // eslint-disable-next-line eqeqeq
    // if (channelName != null) {
    //   const channelInfo = this.channels[channelName];
    //   if (channelInfo && channelInfo.enabled && level <= channelInfo.level) {
    //     if (channelName === 'console') {
    //       console.log(_message);
    //     } else {
    //       let _outputChannel: vscode.OutputChannel = channelInfo.outputChannel as vscode.OutputChannel;
    //       _outputChannel.appendLine(_message);
    //     }
    //   }
    // } else {
    //   for (const channelName in this.channels) {
    //     const channelInfo = this.channels[channelName];
    //     if (channelInfo && channelInfo.enabled && level <= channelInfo.level) {
    //       if (channelName === 'console') {
    //         console.log(_message);
    //       } else {
    //         let _outputChannel: vscode.OutputChannel = channelInfo.outputChannel as vscode.OutputChannel;
    //         _outputChannel.appendLine(_message);
    //       }
    //     }
    //   }
    // }
  }

  // setChannelLogLevel(channelName: string, level: LogLevel): void {
  //   const channelInfo = this.channels[channelName];
  //   if (channelInfo) {
  //     channelInfo.level = level;
  //   }
  // }

  // getChannelInfo(channelName: string): ChannelInfo | null {
  //   const channelInfo = this.channels[channelName];
  //   return channelInfo ? channelInfo : null;
  // }

  dispose(): void {
    // for (const channelName in this.channels) {
    //   if (channelName !== 'console') {
    //     let _outputChannel: vscode.OutputChannel = this.channels[channelName].outputChannel as vscode.OutputChannel;
    //     _outputChannel.dispose();
    //   }
    // }
  }
}
