import * as vscode from 'vscode';

import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/index';

import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import {
  IQueryEngine,
  QueryEngine,
  IQueryEngineChatGPT,
  QueryEngineChatGPT,
  IQueryResultBase,
  QueryResultBase,
} from '@QueryService/index';

import * as fs from 'fs';
import * as path from 'path';
import strip from 'strip-comments';
import * as prettier from 'prettier';

export enum SupportedQueryEnginesEnum {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  // Anthropic
  // Claude = 'Claude',
  // Bard
  //  Bard = 'Bard',
  // Grok
  // Grok = 'Grok',
}

export interface IQueryService {
  QueryAsync(queryEngine?: SupportedQueryEnginesEnum): Promise<void>;
  ConstructQueryAsync(queryEngine?: SupportedQueryEnginesEnum): Promise<void>;
  SendQueryAsync(textToSubmit: string, queryEngine?: SupportedQueryEnginesEnum): Promise<void>;
  MinifyCodeAsync(content: string, extension: string): Promise<string>;
}
// holds all the possible query engines (currently only QueryEngineChatGPT)
type QueryEnginesMap = { [key in SupportedQueryEnginesEnum]: IQueryEngine };

@logConstructor
export class QueryService implements IQueryService {
  // the queryEnginesMap is not populated during the Query Service constructor, but rather when each query engine is first needed
  private readonly queryEnginesMap: QueryEnginesMap = {} as QueryEnginesMap;

  constructor(
    private readonly logger: ILogger,
    private readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly data: IData,
  ) {}

  @logExecutionTime
  static CreateQueryService(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    data: IData,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): QueryService {
    let _obj: QueryService | null;
    if (initializationStructure) {
      try {
        // ToDo: deserialize based on contents of structure
        _obj = QueryService.convertFrom_yaml(initializationStructure.value);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create queryService from initializationStructure using convertFrom_xxx -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create queryService from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
          );
        }
      }
      if (_obj === null) {
        throw new Error(
          `${callingModule}: create queryService from initializationStructure using convertFrom_xxx produced a null`,
        );
      }
      return _obj;
    } else {
      try {
        _obj = new QueryService(logger, extensionContext, data);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(`${callingModule}: create queryService from initializationStructure -> }`, e);
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(`${callingModule}: create queryService from initializationStructure`);
        }
      }
      return _obj;
    }
  }

  static convertFrom_json(json: string): QueryService {
    return fromJson<QueryService>(json);
  }

  static convertFrom_yaml(yaml: string): QueryService {
    return fromYaml<QueryService>(yaml);
  }

  @logAsyncFunction
  async MinifyCodeAsync(content: string, extension: string): Promise<string> {
    // Can't do anything with .txt files, so just return the content
    if (extension === '.txt') {
      return content;
    }
    let strippedContent: string;
    try {
      // use the strip-comments node library to remove comments from the code
      strippedContent = strip(content);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('sendQuery.minifyCodeAsync calling strip failed -> ', e);
      } else {
        throw new Error(
          `sendQuery.minifyCodeAsync calling strip caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }

    let minifiedContent: string;
    try {
      const formatPromise = prettier.format(strippedContent, {
        filepath: `file.${extension}`,
        printWidth: 1000,
        tabWidth: 0,
        semi: false,
        singleQuote: true,
        trailingComma: 'none',
        bracketSpacing: false,
        arrowParens: 'avoid',
        endOfLine: 'lf',
      });

      const timeoutPromise = new Promise(
        (_, reject) => setTimeout(() => reject(new Error('prettier.format timed out')), 2000), // 5 seconds timeout
      );
      const possibleContent = await Promise.race([formatPromise, timeoutPromise]);
      //ToDo: handle timeout (reject the promise with a timeout error)
      if (typeof possibleContent !== 'string') {
        throw new Error('QueryService MinifyCodeAsync the call to prettier.format timed out');
      }
      minifiedContent = possibleContent as string;
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('QueryService.MinifyCodeAsync calling prettier.format failed -> ', e);
      } else {
        throw new Error(
          `QueryService.MinifyCodeAsync calling prettier.format caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }

    return minifiedContent;
  }

  @logAsyncFunction
  async QueryAsync(queryEngine?: SupportedQueryEnginesEnum): Promise<void> {
    // Call CreateQueryAsync, wait for it to complete, then call SendQueryAsync, register the function that handles the event QueryResultsChatGPTCompletelyReceived
  }

  @logAsyncFunction
  async ConstructQueryAsync(queryEngine?: SupportedQueryEnginesEnum): Promise<void> {
    // get the query from the active editor and the data from the data service
    // Create the text to submit
    let textToSubmit: string;
    textToSubmit = 'abc';

    // add anything that is engine specific
    let engineSpecificTextToSubmit: string;
    // store this in Data in a dictionary indexed by SupportedQueryEnginesEnum
    engineSpecificTextToSubmit = textToSubmit;
  }

  @logAsyncFunction
  async SendQueryAsync(textToSubmit: string, queryEngine?: SupportedQueryEnginesEnum): Promise<void> {
    if (!queryEngine) {
      // send the query to every engine
      for (var _queryEngine of Object.values(SupportedQueryEnginesEnum).filter(isNaN as any)) {
        try {
          let responseData = await this.SendQueryAsync(textToSubmit, _queryEngine);
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              `QueryService SendQueryAsync (all): failed calling SendQueryAsync on the engine ${queryEngine} -> `,
              e,
            );
          } else {
            throw new Error(
              `QueryService SendQueryAsync (all) failed calling SendQueryAsync on the engine ${queryEngine}, and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
      }
    } else {
      switch (queryEngine) {
        case SupportedQueryEnginesEnum.ChatGPT:
          // load the query engine if it is not already loaded
          if (!this.queryEnginesMap[SupportedQueryEnginesEnum.ChatGPT]) {
            try {
              this.queryEnginesMap[SupportedQueryEnginesEnum.ChatGPT] = new QueryEngineChatGPT(this.logger, this.data);
            } catch (e) {
              if (e instanceof Error) {
                throw new DetailedError(
                  `QueryService SendQueryAsync: failed attempting to create an instance of a QueryEngineChatGPT -> `,
                  e,
                );
              } else {
                // ToDo:  investigation to determine what else might happen
                throw new Error(
                  `QueryService SendQueryAsync: failed attempting to create an instance of a QueryEngineChatGPT and the instance of (e) returned is of type ${typeof e}`,
                );
              }
            }
          }
          try {
            // call SendQueryAsync on the specific QueryEngine
            let responseData = await this.queryEnginesMap[queryEngine].SendQueryAsync(textToSubmit);
          } catch (e) {
            if (e instanceof Error) {
              throw new DetailedError(
                `QueryService SendQueryAsync: failed calling SendQueryAsync on the engine ${queryEngine} -> `,
                e,
              );
            } else {
              throw new Error(
                `QueryService SendQueryAsync failed calling SendQueryAsync on the engine ${queryEngine}, and the instance of (e) returned is of type ${typeof e}`,
              );
            }
          }
          break;
        // case SupportedQueryEnginesEnum.Claude:
        //   this.queryEnginesMap[queryEngine] = new ClaudeQueryEngine(logger);
        //   break;
        // case SupportedQueryEnginesEnum.Bard:
        //   this.queryEnginesMap[queryEngine] = new BardQueryEngine(logger);
        //   break;
        // case SupportedQueryEnginesEnum.Grok:
        //   this.queryEnginesMap[queryEngine] = new GrokQueryEngine(logger);
        //   break;
        default:
          throw new Error(`QueryService SendQueryAsync Unsupported query engine ${queryEngine}`);
      }
    }
  }
}
