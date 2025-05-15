import * as vscode from "vscode";

import { QueryEngineNamesEnum } from "@BaseEnumerations/index";

import { LogLevel, ILogger, Logger } from "@Logger/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";
import {
  logConstructor,
  logFunction,
  logAsyncFunction,
  logExecutionTime,
} from "@Decorators/index";

import {
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from "@Serializers/index";

import {
  IDataService,
  IData,
  IStateManager,
  IConfigurationData,
} from "@DataService/index";

import {
  IQueryEngine,
  QueryEngine,
  IQueryEngineChatGPT,
  QueryEngineChatGPT,
  IQueryResultBase,
  QueryResultBase,
} from "@QueryService/index";

import * as fs from "fs";
import * as path from "path";
import * as prettier from "prettier";

//import * as strip from "strip-comments";
const strip = require("strip-comments");

export interface IQueryService {
  ConstructQueryAsync(queryEngine?: QueryEngineNamesEnum): Promise<void>;
  sendQueryAsync(
    textToSubmit: string,
    queryEngineName: QueryEngineNamesEnum,
    cTSToken: vscode.CancellationToken,
  ): Promise<void>;
  // MinifyCodeAsync(content: string, extension: string): Promise<string>;
}
// holds all the possible query engines (currently only QueryEngineChatGPT)
type QueryEnginesMap = { [key in QueryEngineNamesEnum]: IQueryEngine };

@logConstructor
export class QueryService implements IQueryService {
  // the queryEnginesMap is not populated during the Query Service constructor, but rather when each query engine is first needed
  private readonly queryEnginesMap: QueryEnginesMap = {} as QueryEnginesMap;

  constructor(
    private readonly logger: ILogger,
    private readonly extensionContext: vscode.ExtensionContext, // readonly folder: vscode.WorkspaceFolder,
    private readonly data: IData,
  ) {
    this.logger = new Logger(this.logger, "QueryService");
  }

  // static create(
  //   logger: ILogger,
  //   extensionContext: vscode.ExtensionContext,
  //   data: IData,
  //   callingModule: string,
  //   initializationStructure?: ISerializationStructure,
  // ): QueryService {
  //   Logger.staticLog(`QueryService.create called`, LogLevel.Debug);
  //   let _obj: QueryService | null;
  //   if (initializationStructure) {
  //     try {
  //       // ToDo: deserialize based on contents of structure
  //       _obj = QueryService.convertFrom_yaml(initializationStructure.value);
  //     } catch (e) {
  //       if (e instanceof Error) {
  //         throw new DetailedError(
  //           `${callingModule}: create queryService from initializationStructure using convertFrom_xxx -> }`,
  //           e,
  //         );
  //       } else {
  //         // ToDo:  investigation to determine what else might happen
  //         throw new Error(
  //           `${callingModule}: create queryService from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
  //         );
  //       }
  //     }
  //     if (_obj === null) {
  //       throw new Error(
  //         `${callingModule}: create queryService from initializationStructure using convertFrom_xxx produced a null`,
  //       );
  //     }
  //     return _obj;
  //   } else {
  //     try {
  //       _obj = new QueryService(logger, extensionContext, data);
  //     } catch (e) {
  //       if (e instanceof Error) {
  //         throw new DetailedError(`${callingModule}: create queryService from initializationStructure -> }`, e);
  //       } else {
  //         // ToDo:  investigation to determine what else might happen
  //         throw new Error(`${callingModule}: create queryService from initializationStructure`);
  //       }
  //     }
  //     return _obj;
  //   }
  // }

  static convertFrom_json(json: string): QueryService {
    return fromJson<QueryService>(json);
  }

  static convertFrom_yaml(yaml: string): QueryService {
    return fromYaml<QueryService>(yaml);
  }

  // @logAsyncFunction
  // async MinifyCodeAsync(content: string, extension: string): Promise<string> {
  //   // Can't do anything with .txt files, so just return the content
  //   if (extension === ".txt") {
  //     return content;
  //   }
  //   let strippedContent: string;
  //   try {
  //     // use the strip-comments node library to remove comments from the code
  //     strippedContent = strip(content);
  //   } catch (e) {
  //     if (e instanceof Error) {
  //       throw new DetailedError(
  //         "sendQuery.minifyCodeAsync calling strip failed -> ",
  //         e,
  //       );
  //     } else {
  //       throw new Error(
  //         `sendQuery.minifyCodeAsync calling strip caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
  //       );
  //     }
  //   }

  //   let minifiedContent: string;
  //   try {
  //     const formatPromise = prettier.format(strippedContent, {
  //       filepath: `file.${extension}`,
  //       printWidth: 1000,
  //       tabWidth: 0,
  //       semi: false,
  //       singleQuote: true,
  //       trailingComma: "none",
  //       bracketSpacing: false,
  //       arrowParens: "avoid",
  //       endOfLine: "lf",
  //     });

  //     const timeoutPromise = new Promise(
  //       (_, reject) =>
  //         setTimeout(
  //           () => reject(new Error("prettier.format timed out")),
  //           2000,
  //         ), // 5 seconds timeout
  //     );
  //     const possibleContent = await Promise.race([
  //       formatPromise,
  //       timeoutPromise,
  //     ]);
  //     //ToDo: handle timeout (reject the promise with a timeout error)
  //     if (typeof possibleContent !== "string") {
  //       throw new Error(
  //         "QueryService MinifyCodeAsync the call to prettier.format timed out",
  //       );
  //     }
  //     minifiedContent = possibleContent as string;
  //   } catch (e) {
  //     if (e instanceof Error) {
  //       throw new DetailedError(
  //         "QueryService.MinifyCodeAsync calling prettier.format failed -> ",
  //         e,
  //       );
  //     } else {
  //       throw new Error(
  //         `QueryService.MinifyCodeAsync calling prettier.format caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
  //       );
  //     }
  //   }

  //   return minifiedContent;
  // }

  @logAsyncFunction
  async ConstructQueryAsync(queryEngine?: QueryEngineNamesEnum): Promise<void> {
    // get the query from the active editor and the data from the data service
    // Create the text to submit
    let textToSubmit: string;
    textToSubmit = "abc";

    // add anything that is engine specific
    let engineSpecificTextToSubmit: string;
    // store this in Data in a dictionary indexed by QueryEngineNamesEnum
    engineSpecificTextToSubmit = textToSubmit;
  }

  @logAsyncFunction
  async sendQueryAsync(
    textToSubmit: string,
    queryEngineName: QueryEngineNamesEnum,
    cTSToken: vscode.CancellationToken,
  ): Promise<void> {
    switch (queryEngineName) {
      case QueryEngineNamesEnum.ChatGPT:
        // load the query engine if it is not already loaded
        if (!this.queryEnginesMap[QueryEngineNamesEnum.ChatGPT]) {
          try {
            this.queryEnginesMap[QueryEngineNamesEnum.ChatGPT] =
              new QueryEngineChatGPT(this.logger, this.data);
          } catch (e) {
            HandleError(
              e,
              "queryService",
              "sendQueryAsync",
              "calling QueryEngineChatGPT .ctor",
            );
          }
        }
        try {
          // call sendQueryAsync on the specific QueryEngine
          let responseData = await this.queryEnginesMap[
            queryEngineName
          ].sendQueryAsync(textToSubmit, cTSToken);
        } catch (e) {
          HandleError(
            e,
            "queryService",
            "sendQueryAsync",
            "calling sendQueryAsync",
          );
        }
        break;
      // case QueryEngineNamesEnum.Claude:
      //   this.queryEnginesMap[queryEngine] = new ClaudeQueryEngine(logger);
      //   break;
      // case QueryEngineNamesEnum.Bard:
      //   this.queryEnginesMap[queryEngine] = new BardQueryEngine(logger);
      //   break;
      // case QueryEngineNamesEnum.Grok:
      //   this.queryEnginesMap[queryEngine] = new GrokQueryEngine(logger);
      //   break;
      default:
        throw new Error(
          `QueryService sendQueryAsync Unsupported query engine ${queryEngineName}`,
        );
    }
  }
}
