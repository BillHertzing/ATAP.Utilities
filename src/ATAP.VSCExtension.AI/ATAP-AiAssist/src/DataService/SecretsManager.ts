import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

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
          `SecretsManager.getAPIKeyForChatGPT call to this.secretManagersMap[secretVaultToUse].getValue('APIKeyForChatGPT') failed -> `,
          e,
        );
      } else {
        throw new Error(
          `SecretsManager.getAPIKeyForChatGPT call to 'this.secretManagersMap[secretVaultToUse].getValue('APIKeyForChatGPT')' caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
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

import kdbxweb from 'kdbxweb';
import fs from 'fs';
import path from 'path';

interface IKeePassSecretsManager extends IBaseSecretsManager {}

// When the extension starts and instantiates a SecretsManager the Data structure,
// that instantiates a KeePassSecretsManager, which will ask the user for the master password to the Keepass vault
// masterPassword is a kdbxweb.ProtectedValue in the eePassSecretsManager class that holds the master password to a Keepass vault
// it is stored in the extension's KeePassSecretsManager instance
// it is cleared after 3 hours

@logConstructor
class KeePassSecretsManager extends BaseSecretsManager implements IKeePassSecretsManager {
  private keePassKDBXPath: string;
  private masterPassword: kdbxweb.ProtectedValue | null = null;
  private masterPasswordTimer: NodeJS.Timeout | undefined = undefined;

  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, configurationData: IConfigurationData) {
    super(logger, extensionContext);
    this.keePassKDBXPath = configurationData.getKeePassKDBXPath(); // gaurnetted to return a nonnull or throw an error
    console.log(`keePassKDBXPath = ${this.keePassKDBXPath}`);
    logger.log(`keePassKDBXPath = ${this.keePassKDBXPath}`, LogLevel.Debug);
    this.masterPassword = this.getMasterPassword();
  }

  private askForMasterPassword(): Promise<void> {
    return new Promise((resolve) => {
      vscode.window
        .showInputBox({ prompt: 'Enter the master password to the Keepass vault at TBD', password: true })
        .then((password) => {
          if (password) {
            this.masterPassword = kdbxweb.ProtectedValue.fromString(password);

            // Set a timer to clear the secure buffer after 3 hours
            if (this.masterPasswordTimer) {
              clearTimeout(this.masterPasswordTimer);
            }
            this.masterPasswordTimer = setTimeout(() => {
              this.masterPassword = null;
            }, 3 * 60 * 60 * 1000);
          }
          resolve();
        });
    });
  }

  public getMasterPassword(): kdbxweb.ProtectedValue | null {
    if (!this.masterPassword) {
      this.askForMasterPassword();
    }
    return this.masterPassword ? this.masterPassword : null;
  }

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
  //   const credentials = new kdbxweb.Credentials(this.masterPassword);
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
  //   // the .kdbx file as a kdbxweb.Kdbx object
  //   const db = token kdbxweb.Kdbx.load(new Uint8Array(dbBuffer.buffer), credentials);
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
  @logAsyncFunction
  async getValueAsync<T>(keyPath: string[]): Promise<T | undefined> {
    const credentials = new kdbxweb.Credentials(this.masterPassword);
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
    // the .kdbx file as a kdbxweb.Kdbx object
    const db = await kdbxweb.Kdbx.load(new Uint8Array(dbBuffer.buffer), credentials);

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
