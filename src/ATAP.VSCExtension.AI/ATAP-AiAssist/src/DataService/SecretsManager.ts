import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import * as KdbxWeb from 'kdbxweb';
import fs from 'fs';
import path from 'path';
import { exec } from 'child_process';

export enum SupportedSecretsVaultEnum {
  KeePass = 'KeePass',
}

export type MasterPasswordType = Buffer | null | undefined;
export type PasswordEntryType = Buffer | null | undefined;

export interface ISecretsManager {
  getAPITokenForChatGPTAsync(): Promise<PasswordEntryType>;
}

// holds all the possible secrets managers (currently only KeePassSecretsManager)
type SecretManagerMap = { [key in SupportedSecretsVaultEnum]: ISecretsManager };

@logConstructor
export class SecretsManager implements ISecretsManager {
  private readonly secretManagersMap: SecretManagerMap;
  private masterPassword: MasterPasswordType = null;
  private masterPasswordTimer: NodeJS.Timeout | undefined = undefined;

  constructor(
    private readonly selectedSecretsVault: SupportedSecretsVaultEnum,
    private readonly logger: ILogger,
    private readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly configurationData: IConfigurationData,
  ) {
    this.secretManagersMap = {} as SecretManagerMap;
    switch (selectedSecretsVault) {
      case SupportedSecretsVaultEnum.KeePass:
        this.secretManagersMap[SupportedSecretsVaultEnum.KeePass] = new KeePassSecretsManager(
          this.GetMasterPasswordAsync.bind(this),
          this.logger,
          this.extensionContext,
          this.configurationData,
        );
        break;
      default:
        throw new DetailedError(`SecretsManager constructor does not support the ${selectedSecretsVault} vault`);
    }
  }

  // Ask the user to input a master password using an VSC inputBox
  @logAsyncFunction
  private async AskForMasterPasswordAsync(): Promise<MasterPasswordType> {
    return new Promise(async (resolve) => {
      // The inputBox gets z-order visually overwritten in the UI with any newly created or activated editors
      //  so we need to make sure the inputBox is on top.
      // But secretsManager is instantiated in the extension's Data structure, which is instantiated in the extension's activate function

      // let mp: KdbxWeb.ProtectedValue = KdbxWeb.ProtectedValue.fromString('NopeNotReallyThePassword');
      // console.log('mp = ', mp.toString());

      // this.masterPassword = KdbxWeb.ProtectedValue.fromString('NopeNotReallyThePassword');
      const pwd = await vscode.window.showInputBox({
        prompt: `Enter the master password to the Secrets vault`,
        password: true,
      });
      if (pwd) {
        try {
          // ToDo: I18N
          this.masterPassword = Buffer.from(pwd, 'utf-8');
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(`SecretsManager AskForMasterPasswordAsync failed -> `, e);
          } else {
            throw new Error(
              `SecretsManager AskForMasterPasswordAsync failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
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
    });
  }

  // return the masterPassword if it is defined, otherwise ask the user for it
  @logAsyncFunction
  private async GetMasterPasswordAsync(): Promise<MasterPasswordType> {
    if (!this.masterPassword) {
      await this.AskForMasterPasswordAsync();
    }
    return this.masterPassword ? this.masterPassword : null;
  }

  @logAsyncFunction
  async getAPITokenForChatGPTAsync(): Promise<MasterPasswordType> {
    // ToDo: wrap in a try/catch
    return this.secretManagersMap[this.selectedSecretsVault].getAPITokenForChatGPTAsync();
  }
}

// When the extension starts and instantiates a SecretsManager the Data structure,
// that instantiates a KeePassSecretsManager, which will ask the user for the master password to the Keepass vault
// masterPassword is a KdbxWeb.ProtectedValue in the KeePassSecretsManager class that holds the master password to a Keepass vault
// it is stored in the extension's KeePassSecretsManager instance
// it is cleared after 3 hours

enum KeePassAccessEnum {
  KpScript,
  KdbxWeb,
}

@logConstructor
class KeePassSecretsManager implements ISecretsManager {
  private callGetMasterPasswordAsync: () => Promise<MasterPasswordType>;
  private KeePassAccess: KeePassAccessEnum = KeePassAccessEnum.KpScript;
  // ToDo: replace with pathlike
  private keePassKDBXPath: string;

  constructor(
    callGetMasterPasswordAsync: () => Promise<MasterPasswordType>,
    private logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    configurationData: IConfigurationData,
  ) {
    //super(logger, extensionContext, configurationData);
    this.callGetMasterPasswordAsync = callGetMasterPasswordAsync;
    this.keePassKDBXPath = configurationData.getKeePassKDBXPath(); // guaranteed to return a nonnull or throw an error
    logger.log(`keePassKDBXPath = ${this.keePassKDBXPath}`, LogLevel.Debug);
  }

  @logAsyncFunction
  async getAPITokenForChatGPTAsync(): Promise<PasswordEntryType> {
    let aPIToken: PasswordEntryType;
    // ToDo: Move the processing of kdbx, argv, env, and include the possibility of development and production defaultconfiguration fields for some LLMs
    // Does the environment have a APITokenForChatGPT?
    // Is it a CLI argument passed in argv?
    // Is it in environment variables (specific to the extension)?
    // Is it in environment variables (specific to the library. for ChatGPT, this is process.env["OPENAI_API_KEY"])?
    // is it hardcoded for this LLM in the defaultConfiguration structures
    const keyPath = ['Internet', 'ChatGPT'];
    try {
      aPIToken = await this.getValueAsync(keyPath, 'ChatGPTAPIToken');
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(
          `SecretsManager.getAPITokenForChatGPT call to this.secretManagersMap[secretVaultToUse].getValueAsync('APITokenForChatGPT') failed -> `,
          e,
        );
      } else {
        throw new Error(
          `SecretsManager.getAPITokenForChatGPT call to 'this.secretManagersMap[secretVaultToUse].getValueAsync('APITokenForChatGPT')' caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
    return aPIToken;
  }

  // Implement the abstract base function using the kdbxweb library
  @logAsyncFunction
  async getValueAsync<Buffer>(keyPath: string[], entryTitle: string): Promise<PasswordEntryType> {
    // get the masterPassword from the SecretsManager. It will ask the user via an inputbox if it is not defined. It might return null if the user cancels the inputBox
    let _masterPassword: MasterPasswordType = null;
    try {
      _masterPassword = await this.callGetMasterPasswordAsync();
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`KeePassSecretsManager getValueAsync failed -> `, e);
      } else {
        throw new Error(
          `KeePassSecretsManager getValueAsync failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }

    if (!_masterPassword) {
      // ToDo: look to support other LLM models and APIs that don't require any secrets from the secrets vault
      throw new Error('KeePassSecretsManager getValueAsync failed. The masterPassword is null');
    }

    switch (this.KeePassAccess) {
      case KeePassAccessEnum.KpScript:
        return new Promise((resolve, reject) => {
          try {
            const kPScriptPath = '"C:/Program Files/KeePass Password Safe 2/KPScript.exe"';
            const keePassKDBXPath = '"C:/Dropbox/whertzing/GitHub/ATAP.IAC/Security/ATAP_KeePassDatabase.kdbx"';
            const masterPasswordBuffer = Buffer.from('EncryptMySecrets', 'utf-8');
            const args = `-c:GetEntryString ${keePassKDBXPath}  -pw:${masterPasswordBuffer.toString()} -ref-Title:"${entryTitle}" -Field:Password -FailIfNoEntry -FailIfNotExists -Spr`;
            exec(`${kPScriptPath} ${args}`, (error, stdout, stderr) => {
              if (error) {
                return reject(new DetailedError('KPScript exec failed -> ', error));
              }
              if (stderr) {
                return reject(new DetailedError(`KPScript exec returned data in stderr -> ${stderr}`));
              }
              resolve(Buffer.from(stdout, 'utf-8'));
            });
          } catch (e) {
            if (e instanceof Error) {
              throw new DetailedError('sendQuery KPScript exec failed -> ', e);
            } else {
              // ToDo:  investigation to determine what else might happen
              throw new Error(`sendQuery KPScript exec failed and the instance of (e) returned is of type ${typeof e}`);
            }
          }
        });
      default:
        throw new DetailedError(
          `KeePassSecretsManager getValueAsync does not support the ${this.KeePassAccess} access library`,
        );
    }

    //  case KeePassAccessEnum.KdbxWeb:
    //     const _masterPasswordAsKdbxWebProtectedValue = KdbxWeb.ProtectedValue.fromString(_masterPassword.toString());
    //     // the raw .kdbx file
    //     let dbBuffer: Buffer;
    //     try {
    //       dbBuffer = await fs.promises.readFile(this.keePassKDBXPath);
    //     } catch (e) {
    //       if (e instanceof Error) {
    //         throw new DetailedError(`KeePassSecretsManager getValueAsync failed -> `, e);
    //       } else {
    //         throw new Error(
    //           `KeePassSecretsManager getValueAsync failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
    //         );
    //       }
    //     }

    //     // the .kdbx file as a KdbxWeb.Kdbx object
    //     // convert the _masterPasswordAsKdbxwebProtectedValue into a Credentials instance
    //     let credentials: KdbxWeb.Credentials;
    //     try {
    //       this.logger.log(
    //         `getValueAsync 4.1. _masterPasswordAsKdbxWebProtectedValue = ${_masterPasswordAsKdbxWebProtectedValue.toString()}`,
    //         LogLevel.Debug,
    //       );
    //       credentials = new KdbxWeb.Credentials(_masterPasswordAsKdbxWebProtectedValue);
    //       this.logger.log(`getValueAsync 4.2. credentials = ${credentials.toString()}`, LogLevel.Debug);
    //     } catch (e) {
    //       if (e instanceof Error) {
    //         throw new DetailedError(
    //           `KeePassSecretsManager getValueAsync calling KdbxWeb.Credentials .ctor failed -> `,
    //           e,
    //         );
    //       } else {
    //         throw new Error(
    //           `KeePassSecretsManager getValueAsync calling KdbxWeb.Credentials .ctor failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
    //         );
    //       }
    //     }

    //     let db: KdbxWeb.Kdbx;
    //     try {
    //       db = await KdbxWeb.Kdbx.load(new Uint8Array(dbBuffer.buffer), credentials);
    //       console.log(`getValueAsync 5.2 db.versionMajor = ${db.versionMajor}, db.versionMinor = ${db.versionMinor}`);
    //     } catch (e) {
    //       if (e instanceof Error) {
    //         throw new DetailedError(`KeePassSecretsManager getValueAsync calling KdbxWeb.Kdbx.load failed -> `, e);
    //       } else {
    //         throw new Error(
    //           `KeePassSecretsManager getValueAsync calling KdbxWeb.Kdbx.load failed. It caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
    //         );
    //       }
    //     }

    //     // ToDo:shred the local _masterPasswordAsKdbxWebProtectedValue
    //     let currentGroup = db.getDefaultGroup();
    //     for (const key of keyPath) {
    //       // ToDo: wrap in a trycatch
    //       const nextGroup = currentGroup.groups.find((group) => group.name === key);
    //       if (!nextGroup) {
    //         return undefined;
    //       }
    //       currentGroup = nextGroup;
    //     }

    //     // ToDo: wrap in a trycatch
    //     const entry = currentGroup.entries.find((entry) => entry.fields.get('Title') === entryTitle);
    //     if (!entry) {
    //       return undefined;
    //     }

    //     // ToDo: wrap in a trycatch
    //     const value = entry.fields.get('Password');
    //     if (!value) {
    //       return undefined;
    //     }
    //     return value as PasswordEntryType;
    //   default:
    //     throw new DetailedError(
    //       `KeePassSecretsManager getValueAsync does not support the ${this.KeePassAccess} Access value`,
    //     );
    // }
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

// interface IBaseSecretsManagerAbstract {
//   getValueAsync(keyPath: string[], entryTitle: string): Promise<Buffer | null | undefined>;
// }

// // ToDo: @logConstructor need an abstract class decorator
// abstract class BaseSecretsManagerAbstract implements IBaseSecretsManagerAbstract {
//   constructor(logger: ILogger, extensionContext: vscode.ExtensionContext) {}
//   // ToDo: @logMethod need an abstract method decorator
//   abstract getValueAsync(keyPath: string[], entryTitle: string): Promise<Buffer | null | undefined>;
// }

// async getValueAsync(keyPath: string[], entryTitle: string): Promise<Buffer | null | undefined> {
//   // placeholder implementation, the real implementation is in the derived classes
//   // throw an error indicating not implemented, which only should happen if the derived classes fail to implement it
//   throw new DetailedError(
//     `SecretsManager.getValueAsync is not implemented. It should have been implemented in a derived class`,
//   );
// }

// Immediately Invoked Async Function Expression (IIFE)
// (async () => {
//   this.parent.masterPassword = await this.parent.askForMasterPasswordAsync();
// })();
