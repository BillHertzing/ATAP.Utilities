import * as vscode from "vscode";
import { DetailedError } from "@ErrorClasses/index";

// The ATAP Logger  module provides a logginginterface between the program and an underlying logger library
// Currently the underlying logger library is pino
// The Logger module defines logging destinations and levels, and provides a set of logging methods
// support logging destinations include the debug console, a VSC output channel for extensions, a file, a UDP port, and TBD

// implement the logger using pino
import pino from "pino"; // eslint-disable-line @typescript-eslint/no-var-requires
import pinoPretty from "pino-pretty"; // eslint-disable-line @typescript-eslint/no-var-requires
import { PassThrough } from "stream";

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
  UDP = 3,
}

export interface IDestinationCommonInformation {
  enabled: boolean;
  level: LogLevel;
}

export interface IConsoleDestinationInformation
  extends IDestinationCommonInformation {}

export interface IExtensionDestinationInformation
  extends IDestinationCommonInformation {
  outputChannel: vscode.OutputChannel;
}

export interface IFileDestinationInformation
  extends IDestinationCommonInformation {
  filePath: string;
}

export interface IUDPDestinationInformation
  extends IDestinationCommonInformation {
  uDPPort: number;
}
// export interface ChannelInfo {
//   outputChannel: vscode.OutputChannel | undefined;
//   enabled: boolean;
//   level: LogLevel;
// }

export interface DestinationInfo {
  enabled: boolean;
  level: LogLevel;
  channelDestinationInformation?: IConsoleDestinationInformation;
  extensionDestinationInformation?: IExtensionDestinationInformation;
  fileDestinationInformation?: IFileDestinationInformation;
  uDPDestinationInformation?: IUDPDestinationInformation;
  pinoOptions?: Record<string, any>;
}

export type DestinationType = Partial<Record<DestinationEnum, DestinationInfo>>;

export interface ILogger {
  readonly scope: string;
  fatal(message: string, scope?: string, channelName?: string): void;
  error(message: string, scope?: string, channelName?: string): void;
  warn(message: string, scope?: string, channelName?: string): void;
  info(message: string, scope?: string, channelName?: string): void;
  debug(message: string, scope?: string, channelName?: string): void;
  trace(message: string, scope?: string, channelName?: string): void;
  performance(message: string, scope?: string, channelName?: string): void;
  log(message: string, level: LogLevel, destinationID?: string): void;
  dispose(): void;
}

// The initial implementation of the Logger creates the destination information during the creation of the Logger class
// ToDo: read the initial logger configuration from the extension's VSC and User settings
// ToDo: Add the ability to enable / disable existing destinations, add and remove destinations, and to change the level of a destination
export class Logger implements ILogger {
  private static extensionName: string;
  private static pinoLogger: pino.Logger;
  private static staticOutputChannel: vscode.OutputChannel;
  public static staticOutputChannelStream = {
    write: (message) => {
      Logger.staticOutputChannel.append(message);
    },
  };
  private static pinoStreams = [
    { stream: process.stdout },
    { stream: Logger.staticOutputChannelStream },
  ];
  private static destinations: DestinationType;
  public readonly scope: string;

  // This creates the Logger static instance data and the initial set of destinations
  static createLogger(extensionName: string): ILogger {
    // ToDO: create a logger display name from the extension name
    Logger.extensionName = extensionName;
    //ToDo: create a disply name for the output Channel from the extension name
    Logger.staticOutputChannel = vscode.window.createOutputChannel(
      Logger.extensionName,
    );
    Logger.staticOutputChannelStream = {
      write: (message) => {
        Logger.staticOutputChannel.append(message);
      },
    };

    // Create the static set of destinations for the logger class
    // configure the logger instance to write to the console and to an output channel having the same name as the extension, with a LogLevel of Info
    // Logger.destinations = {
    //   [DestinationEnum.Console]: {
    //     enabled: true,
    //     level: LogLevel.Debug,
    //     stream: process.stdout,
    //     options: {},
    //   },
    //   [DestinationEnum.Extension]: {
    //     enabled: true,
    //     level: LogLevel.Debug,
    //     stream: {
    //       write: (message) => {
    //         Logger.staticOutputChannel.append(message);
    //       },
    //     },
    //     options: { append: true },
    //   },
    // };
    // ToDO: Accept File and other destinations (UDP, URL, Telemetry, etc.)
    //[DestinationEnum.File]: { enabled: false, level: LogLevel.Debug, options: {} // }
    // create a transport that uses the pino pretty printer, Colorizer, and specific Time format
    // const pinoPrettyTransport = pinoPretty({
    //   colorize: true,
    //   translateTime: "SYS:standard",
    // });
    Logger.staticOutputChannel.appendLine(
      "test message from staticOutputChannel",
    );

    const basicPino = pino({
      level: "trace",
      transport: { target: "pino-pretty" },
    });
    basicPino.info("test message from basicPino to stdout");

    const prettyStream = pinoPretty({
      colorize: true,
      translateTime: "yyyy-mm-dd HH:MM:ss.l",
      ignore: "pid,hostname",
    });

    const combinedStream = new PassThrough();
    combinedStream.pipe(prettyStream).pipe(process.stdout);

    const prettyLoggerStream = pino(
      {
        level: "debug",
      },
      //combinedStream,
      prettyStream.pipe(process.stdout),
    );

    // const streams: pino.DestinationStream[] = [
    //   { stream: prettyLoggerStream },
    //   { stream: process.stdout },
    // ];

    prettyLoggerStream.info("test message from prettyLoggerStream to stdout");
    // ToDo: figure out why transports don't seem to work inside a VSC extension. it may have to do with the fact that Transports are run in a separate Node worker thread
    // const prettyTransport = {
    //   target: "pino-pretty",
    //   options: {
    //     colorize: true,
    //     translateTime: "yyyy-mm-dd HH:MM:ss.l",
    //     ignore: "pid,hostname", // Optional: adjust based on your preference
    //   },
    // };
    // const prettyLoggerTransport = pino({
    //   level: "trace",
    //   transport: {
    //     target: "pino-pretty",
    //     options: {
    //       colorize: true,
    //       translateTime: "yyyy-mm-dd HH:MM:ss.l",
    //       ignore: "pid,hostname", // Optional: adjust based on your preference
    //     },
    //   },
    // });

    // prettyLoggerTransport.info(
    //   "test message from prettyLoggerTransport to stdout",
    // );

    // Assign the pinoLogger static variable to one of the pino instances
    Logger.pinoLogger = prettyLoggerStream;
    //Logger.pinoLogger = pino({ level: "trace" }, pino.multistream(streams));

    // Logger.pinoLogger.info("test message from pinoLogger");
    // the base scope for the logger is the extension name
    return new Logger(void 0, extensionName);
  }

  constructor(logger: ILogger | void, scope: string) {
    if (logger) {
      this.scope = logger.scope + "." + scope;
    } else {
      this.scope = scope;
    }
  }

  addScope(message: string): string {
    return `[${this.scope}] ${message}`;
  }

  fatal(message: string): void {
    Logger.pinoLogger.fatal(this.addScope(message));
  }

  error(message: string): void {
    Logger.pinoLogger.error(this.addScope(message));
  }

  warn(message: string): void {
    Logger.pinoLogger.warn(this.addScope(message));
  }

  info(message: string): void {
    Logger.pinoLogger.info(this.addScope(message));
  }

  debug(message: string): void {
    Logger.pinoLogger.debug(this.addScope(message));
  }

  trace(message: string): void {
    Logger.pinoLogger.trace(this.addScope(message));
  }

  performance(message: string): void {
    Logger.pinoLogger.trace(this.addScope(message));
  }

  log(message: string, level: LogLevel, channelName?: string): void {
    switch (level) {
      case LogLevel.Fatal:
        this.fatal(message);
        break;
      case LogLevel.Error:
        this.error(message);
        break;
      case LogLevel.Warn:
        this.warn(message);
        break;
      case LogLevel.Info:
        this.info(message);
        break;
      case LogLevel.Debug:
        this.debug(message);
        break;
      case LogLevel.Trace:
        this.trace(message);
        break;
      case LogLevel.Performance:
        this.performance(message);
        break;
    }

    // static staticLog(message: string, level: LogLevel) {
    //   const _message = `[${LogLevel[level]}] [${new Date().toISOString()}] ${message}`;

    //   Logger.staticOutputChannel.appendLine(_message);
    // }

    // static createChannel(
    //   name: string,
    //   level: LogLevel,
    //   enabled: boolean = true,
    // ): void {
    //   const outputChannel = vscode.window.createOutputChannel(name);
    //   this.channels[name] = { outputChannel, enabled, level };
    // }

    // static setChannelEnabled(channelName: string, enabled: boolean): void {
    //   const channelInfo = this.channels[channelName];
    //   if (channelInfo) {
    //     channelInfo.enabled = enabled;
    //   }
    // }

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
