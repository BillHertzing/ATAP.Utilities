import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import * as KdbxWeb from 'kdbxweb';
import fs from 'fs';
import path from 'path';
import { log } from 'console';

export enum SupportedSecretsVaultEnum {
  KeePass = 'KeePass',
}

export interface ISecretsManager {
  getAPIKeyForChatGPTAsync(): Promise<Buffer | undefined>;
}

type SecretManagerMap = { [key in SupportedSecretsVaultEnum]: IBaseSecretsManager };
@logConstructor
export class SecretsManager {
  private readonly secretManagersMap: SecretManagerMap;
  constructor(
    private readonly logger: ILogger,
    private readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly configurationData: IConfigurationData,
  ) {
    this.secretManagersMap = {} as SecretManagerMap;
    this.secretManagersMap[SupportedSecretsVaultEnum.KeePass] = new KeePassSecretsManager(
      this.logger,
      this.extensionContext,
      this.configurationData,
    );
  }

  //   getAPIKeyForChatGPT(): Buffer | undefined {
  //     const secretVaultToUse = SupportedSecretsVaultEnum.KeePass;
  //     let apiKey: Buffer | undefined;
  //     // ToDo: Move the processing of kdbx, argv, env, and include the possibility of development and production defaultconfiguration fields for some LLMs
  //     // Does the environment have a APIKeyForChatGPT?
  //     // Is it a CLI argument passed in argv?
  //     // Is it in environment variables (specific to the extension)?
  //     // Is it in environment variables (specific to the library. for ChatGPT, this is  process.env["OPENAI_API_KEY"])?
  //     // is it hardcoded for this LLM in the defaultConfiguration structures

  //     try {
  //       apiKey = this.secretManagersMap[secretVaultToUse].getValue('APIKeyForChatGPT');
  //     } catch (e) {
  //       if (e instanceof Error) {
  //         throw new DetailedError(
  //           `SecretsManager.getAPIKeyForChatGPT call to this.secretManagersMap[secretVaultToUse].getValue('APIKeyForChatGPT') failed -> `,
  //           e,
  //         );
  //       } else {
  //         throw new Error(
  //           `SecretsManager.getAPIKeyForChatGPT call to 'this.secretManagersMap[secretVaultToUse].getValue('APIKeyForChatGPT')' caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
  //         );
  //       }
  //     }
  //     return apiKey;
  //   }
  @logAsyncFunction
  async getAPIKeyForChatGPTAsync(): Promise<Buffer | undefined> {
    // ToDo: support other secrets vaults
    const secretVaultToUse = SupportedSecretsVaultEnum.KeePass;
    let apiKey: Buffer | undefined;
    // ToDo: Move the processing of kdbx, argv, env, and include the possibility of development and production defaultconfiguration fields for some LLMs
    // Does the environment have a APIKeyForChatGPT?
    // Is it a CLI argument passed in argv?
    // Is it in environment variables (specific to the extension)?
    // Is it in environment variables (specific to the library. for ChatGPT, this is  process.env["OPENAI_API_KEY"])?
    // is it hardcoded for this LLM in the defaultConfiguration structures
    const keyPath = ['Internet', 'ChatGPT'];
    try {
      apiKey = await this.secretManagersMap[secretVaultToUse].getValueAsync<Buffer>(keyPath);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(
          `SecretsManager.getAPIKeyForChatGPT call to this.secretManagersMap[secretVaultToUse].getValueAsync('APIKeyForChatGPT') failed -> `,
          e,
        );
      } else {
        throw new Error(
          `SecretsManager.getAPIKeyForChatGPT call to 'this.secretManagersMap[secretVaultToUse].getValueAsync('APIKeyForChatGPT')' caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
    return apiKey;
  }
}

interface IBaseSecretsManager {
  // getValue<T>(key: string): T | undefined;
  // getValueAsync<T>(key: string): Promise<T | undefined>;
  getValueAsync<T>(keyPath: string[]): Promise<T | undefined>;
}

// ToDo: @logConstructor need an abstract class decorator
abstract class BaseSecretsManager implements IBaseSecretsManager {
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext) {}
  //abstract getValue<T>(key: string): T | undefined;
  // abstract getValueAsync<T>(key: string): Promise<T | undefined>;
  abstract getValueAsync<T>(keyPath: string[]): Promise<T | undefined>;
}

interface IKeePassSecretsManager extends IBaseSecretsManager {}

// When the extension starts and instantiates a SecretsManager the Data structure,
// that instantiates a KeePassSecretsManager, which will ask the user for the master password to the Keepass vault
// masterPassword is a KdbxWeb.ProtectedValue in the eePassSecretsManager class that holds the master password to a Keepass vault
// it is stored in the extension's KeePassSecretsManager instance
// it is cleared after 3 hours

@logConstructor
class KeePassSecretsManager extends BaseSecretsManager implements IKeePassSecretsManager {
  private keePassKDBXPath: string;
  private masterPassword: KdbxWeb.ProtectedValue | null = null;
  private masterPasswordTimer: NodeJS.Timeout | undefined = undefined;

  constructor(
    private logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    configurationData: IConfigurationData,
  ) {
    super(logger, extensionContext);
    this.keePassKDBXPath = configurationData.getKeePassKDBXPath(); // gaurnetted to return a nonnull or throw an error
    logger.log(`keePassKDBXPath = ${this.keePassKDBXPath}`, LogLevel.Debug);
    // Immediately Invoked Async Function Expression (IIFE)
    // (async () => {
    //   this.masterPassword = await this.getMasterPasswordAsync();
    // })();
  }

  private async askForMasterPasswordAsync(): Promise<KdbxWeb.ProtectedValue | null> {
    return new Promise(async (resolve) => {
      this.logger.log('askForMasterPasswordasync Starting', LogLevel.Debug);
      // The inputBox gets z-order visually overwritten in the UI with any newly created or activated editors
      //  so we need to make sure the inputBox is on top.
      // But secretsManager is instantiated in the extension's Data structure, which is instantiated in the extension's activate function

      // let mp: KdbxWeb.ProtectedValue = KdbxWeb.ProtectedValue.fromString('NopeNotReallyThePassword');
      // console.log('mp = ', mp.toString());

      // this.masterPassword = KdbxWeb.ProtectedValue.fromString('NopeNotReallyThePassword');
      const pwd = await vscode.window.showInputBox({
        prompt: 'Enter the master password to the Keepass vault at TBD',
        password: true,
      });
      this.logger.log(`askForMasterPasswordAsync at 1`, LogLevel.Debug);
      if (pwd) {
        this.logger.log(`askForMasterPasswordAsync at 1.1 pwd is ${pwd}`, LogLevel.Debug);
        try {
          this.masterPassword = KdbxWeb.ProtectedValue.fromString(pwd);
          console.log(
            `askForMasterPassword at 1.1 pwd is ${pwd} and this.masterPassword is ${this.masterPassword.toString()}`,
          );
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(`KeePassSecretsManager askForMasterPasswordAsync failed -> `, e);
          } else {
            throw new Error(
              `KeePassSecretsManager askForMasterPasswordAsync failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }

        // Set a timer to clear the secure buffer after 3 hours
        if (this.masterPasswordTimer) {
          clearTimeout(this.masterPasswordTimer);
        }
        this.masterPasswordTimer = setTimeout(
          () => {
            this.masterPassword = null;
          },
          3 * 60 * 60 * 1000,
        );
      }
      this.logger.log('askForMasterPassword at 2 ', LogLevel.Debug);
    });
    this.logger.log('askForMasterPassword at 3', LogLevel.Debug);
  }

  @logAsyncFunction
  public async getMasterPasswordAsync(): Promise<KdbxWeb.ProtectedValue | null> {
    if (!this.masterPassword) {
      await this.askForMasterPasswordAsync();
    }
    return this.masterPassword ? this.masterPassword : null;
  }

  @logAsyncFunction
  async getValueAsync<T>(keyPath: string[]): Promise<T | undefined> {
    this.logger.log('getValueAsync 1', LogLevel.Debug);

    // the raw .kdbx file
    let dbBuffer: Buffer;

    try {
      dbBuffer = await fs.promises.readFile(this.keePassKDBXPath);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`KeePassSecretsManager getValueAsync failed -> `, e);
      } else {
        throw new Error(
          `KeePassSecretsManager getValueAsync failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
    this.logger.log('getValueAsync 1.1', LogLevel.Debug);
    // get the masterPassword from the SecretsManager. It will ask the user via an inputbox if it is not defined. It might return null if the user cancels the inputBox
    let _masterPassword: KdbxWeb.ProtectedValue | null = null;
    try {
      _masterPassword = await this.getMasterPasswordAsync();
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`KeePassSecretsManager getValueAsync failed -> `, e);
      } else {
        throw new Error(
          `KeePassSecretsManager getValueAsync failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
    this.logger.log('getValueAsync 2', LogLevel.Debug);

    if (!_masterPassword) {
      // ToDo: look to support other LLM models and APIs that don't require any secrets from the secrets vault
      throw new Error('KeePassSecretsManager getValueAsync failed. The masterPassword is null');
    }

    const _masterPasswordAsKdbxWebProtectedValue = _masterPassword as KdbxWeb.ProtectedValue;

    // the .kdbx file as a KdbxWeb.Kdbx object
    this.logger.log('getValueAsync 3', LogLevel.Debug);
    // convert the _masterPasswordAsKdbxwebProtectedValue into a Credentials instance
    let credentials: KdbxWeb.Credentials;
    try {
      this.logger.log(
        `getValueAsync 4.1. _masterPasswordAsKdbxWebProtectedValue = ${_masterPasswordAsKdbxWebProtectedValue.toString()}`,
        LogLevel.Debug,
      );
      credentials = new KdbxWeb.Credentials(_masterPasswordAsKdbxWebProtectedValue);
      this.logger.log(`getValueAsync 4.2. credentials = ${credentials.toString()}`, LogLevel.Debug);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`KeePassSecretsManager getValueAsync calling KdbxWeb.Credentials .ctor failed -> `, e);
      } else {
        throw new Error(
          `KeePassSecretsManager getValueAsync calling KdbxWeb.Credentials .ctor failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }

    let db: KdbxWeb.Kdbx;
    try {
      console.log('getValueAsync 5.1');
      db = await KdbxWeb.Kdbx.load(new Uint8Array(dbBuffer.buffer), credentials);
      console.log(`getValueAsync 5.2 db.versionMajor = ${db.versionMajor}, db.versionMinor = ${db.versionMinor}`);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`KeePassSecretsManager getValueAsync calling KdbxWeb.Kdbx.load failed -> `, e);
      } else {
        throw new Error(
          `KeePassSecretsManager getValueAsync calling KdbxWeb.Kdbx.load failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }

    console.log('getValueAsync 5');
    // ToDo:shred the local _masterPasswordAsKdbxWebProtectedValue
    let currentGroup = db.getDefaultGroup();
    for (const key of keyPath) {
      // ToDo: wrap in a trycatch
      const nextGroup = currentGroup.groups.find((group) => group.name === key);
      if (!nextGroup) {
        return undefined;
      }
      currentGroup = nextGroup;
    }

    // ToDo: wrap in a trycatch
    const entry = currentGroup.entries.find((entry) => entry.fields.get('Title') === 'ChatGPTAPIToken');
    if (!entry) {
      return undefined;
    }

    // ToDo: wrap in a trycatch
    const token = entry.fields.get('Password');
    if (!token) {
      return undefined;
    }
    return token as T;
  }
}

// try {
//  placeholderReplacementPattern()
// } catch (e) {
//   if (e instanceof Error) {
//     throw new DetailedError(`KeePassSecretsManager getValueAsync failed -> `, e);
//   } else {
//     throw new Error(
//       `KeePassSecretsManager getValueAsync failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
//     );
//   }
// }

//   getValue<T>(key: string): T | undefined {
//     let dbBuffer: Buffer;

//     // Load your .kdbx file
//     dbBuffer = fs.readFileSync(this.keePassKDBXPath);
//     try {
//       dbBuffer = fs.readFileSync(this.keePassKDBXPath);
//     } catch (e) {
//       if (e instanceof Error) {
//         throw new DetailedError(`KeePassSecretsManager getValue failed -> `, e);
//       } else {
//         throw new Error(
//           `KeePassSecretsManager getValue failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
//         );
//       }
//     }
//     return value;
//   }

// async getValueAsync<T>(key: string): Promise<T | undefined> {
//   const credentials = new KdbxWeb.Credentials(this.masterPassword);
//   // the raw .kdbx file
//   let dbBuffer: Buffer;

//   try {
//     dbBuffer = token fs.promises.readFile(this.keePassKDBXPath);
//   } catch (e) {
//     if (e instanceof Error) {
//       throw new DetailedError(`KeePassSecretsManager getValueAsync failed -> `, e);
//     } else {
//       throw new Error(
//         `KeePassSecretsManager getValueAsync failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
//       );
//     }
//   }
//   // the .kdbx file as a KdbxWeb.Kdbx object
//   const db = token KdbxWeb.Kdbx.load(new Uint8Array(dbBuffer.buffer), credentials);
//   const internetGroup = db.groups.find((group) => group.name === key[0]);
//   if (!internetGroup) return undefined;

//   const chatGPTGroup = internetGroup.groups.find((group) => group.name === key[1]);
//   if (!chatGPTGroup) return undefined;

//   const chatGPTAPITokenEntry = chatGPTGroup.entries.find((entry) => entry.fields.get('Title') === 'ChatGPTAPIToken');
//   if (!chatGPTAPITokenEntry) return undefined;
//   const chatGPTAPIToken = chatGPTAPITokenEntry.fields.get('Password');
//   if (!chatGPTAPIToken) return undefined;
//   return chatGPTAPIToken as T;
// }
