import * as vscode from "vscode";

import { LogLevel, ILogger, Logger } from "@Logger/index";
import { PasswordEntryType, IData } from "@DataService/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";
import { logConstructor, logMethod, logAsyncFunction } from "@Decorators/index";

import {
  EndpointManager,
  EndpointConfig,
  ChatGptEndpointConfig,
  GrokEndpointConfig,
  CopilotEndpointConfig,
  LLModels,
} from "@EndpointManager/index";

import { StringBuilder } from "@Utilities/index";

import {
  IQueryResultBase,
  QueryResultBase,
  IQueryEngine,
  QueryEngine,
} from "@QueryService/index";

import OpenAI from "openai";

export interface IQueryResultChatGPT extends IQueryResultBase {
  chatCompletion: OpenAI.ChatCompletion;
}

export class QueryResultChatGPT
  extends QueryResultBase
  implements IQueryResultChatGPT
{
  chatCompletion: OpenAI.ChatCompletion;

  constructor(
    chatCompletion: OpenAI.ChatCompletion,
    resultContent: StringBuilder,
    resultSnapshot: StringBuilder,
    isValid: boolean,
    errorMessage: string,
  ) {
    super(resultContent, resultSnapshot, isValid, errorMessage);
    this.chatCompletion = chatCompletion;
  }
}

export interface IQueryEngineChatGPT extends IQueryEngine {
  sendQueryAsync(
    textToSubmit: string,
    cTSToken: vscode.CancellationToken,
  ): Promise<void>;
}

@logConstructor
export class QueryEngineChatGPT implements IQueryEngineChatGPT {
  private openai: OpenAI;

  constructor(
    private readonly logger: ILogger,
    private readonly data: IData,
  ) {
    // get API Token from Keepass
    let aPIToken: PasswordEntryType = undefined;

    // ToDo: use a Factory (Service) pattern to hand out secrets internally to the extension, to ensure they are cleaned on deactivate

    // Immediately Invoked Async Function Expression (IIFE)
    (async () => {
      try {
        aPIToken = await this.data.secretsManager.getAPITokenForChatGPTAsync();
      } catch (e) {
        HandleError(
          e,
          "QueryEngineChatGPT",
          ".ctor",
          "failed calling getAPITokenForChatGPTAsync",
        );
      }
    })();

    // Hmm I guess the extension should continue to operate with LLMs that do not have any authorization requirement
    // Every LLM is potentially different, the extension should have a defaultConfiguration structure for each LLM enumeration
    // but for now assume that an undefined aPIToken is an error
    if (!aPIToken) {
      throw new Error(
        `QueryEngineChatGPT .ctor  aPIToken returned from getAPITokenForChatGPTAsync is undefined`,
      );
    }
    aPIToken = aPIToken as Buffer;
    // Keep only the first line of the aPIToken
    // use a regular expression for the split to handle both \n (*nix and macOS) and \r\n (Windows)
    aPIToken = Buffer.from(aPIToken.toString().split(/\r?\n/)[0], "utf-8");

    try {
      this.openai = new OpenAI({
        apiKey: aPIToken.toString(),
      });
      // ToDo: use a Factory (Service) pattern to hand out secrets internally to the extension, to ensure they are cleaned on deactivate
      aPIToken.fill(0);
    } catch (e) {
      if (e instanceof OpenAI.APIError) {
        // ToDo: handle any extra data in the error
        throw new DetailedError(
          "QueryEngineChatGPT .ctor failed getting new OpenAI instance, OpenAI.APIError type was returned -> ",
          e,
        );
      } else {
        HandleError(
          e,
          "QueryEngineChatGPT",
          ".ctor",
          "failed getting new OpenAI instance",
        );
      }
    }
  }

  @logAsyncFunction
  async sendQueryAsync(textToSubmit: string): Promise<void> {
    let stream: any; //OpenAI.ChatCompletionStream;
    // ToDo: wrap in a resilience policy to handle transient errors
    try {
      stream = await this.openai.beta.chat.completions.stream({
        messages: [{ role: "user", content: textToSubmit.toString() }],
        model: "gpt-3.5-turbo",
        stream: true,
      });
    } catch (e) {
      if (e instanceof OpenAI.APIError) {
        // ToDo handle any extra data in the error
        throw new DetailedError(
          "QueryEngineChatGPT sendQueryAsync openai.beta.chat.completions.stream() failed, OpenAI.APIError type was returned -> ",
          e,
        );
      } else {
        HandleError(
          e,
          "QueryEngineChatGPT",
          ".sendQueryAsync",
          "failed calling openai.beta.chat.completions.stream()",
        );
      }
    }

    let resultContent: StringBuilder = new StringBuilder();
    let resultSnapshot: StringBuilder = new StringBuilder();
    let isValid = true;
    let errorMessage = "";

    let chatCompletion: OpenAI.ChatCompletion;

    try {
      for await (const chunk of stream) {
        resultContent.append(chunk.choices[0]?.delta?.content || "");
        resultSnapshot.append(chunk.choices[0]?.snapshot?.content || "");
      }

      chatCompletion = await stream.finalChatCompletion();
    } catch (e) {
      if (e instanceof OpenAI.APIError) {
        throw new DetailedError(
          "QueryEngineChatGPT sendQueryAsync error occurred reading chunk of openai.beta.chat.completions.stream,  APIError type was returned -> ",
          e,
        );
      } else if (e instanceof Error) {
        throw new DetailedError(
          "QueryEngineChatGPT sendQueryAsync error occurred reading chunk of openai.beta.chat.completions.stream, Error type was returned -> ",
          e,
        );
      } else {
        // Handle unknown error types
        throw new Error(
          `QueryEngineChatGPT sendQueryAsync error occurred reading chunk of openai.beta.chat.completions.stream, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }

    // ToDo: handle incomplete and responses and other app-level error conditions that indicate the query was not successful
    if (false) {
      isValid = false;
      errorMessage = "Invalid data detected";
    }

    // ToDo: figure out process to vet data as a string, yet also return the data as a structure
    //logger.log(chatCompletion, Logger.LogLevel.Debug);
    this.logger.log(
      `resultContent = ${resultContent.toString()}`,
      LogLevel.Debug,
    );
    this.logger.log(
      `resultSnapshot = ${resultSnapshot.toString()}`,
      LogLevel.Debug,
    );

    const results = new QueryResultChatGPT(
      chatCompletion,
      resultContent,
      resultSnapshot,
      isValid,
      errorMessage,
    );
    // Emit event after the stream is fully received
    this.data.eventManager
      .getEventEmitter()
      .emit(
        "ExternalDataReceived",
        results,
        "QueryResultsChatGPTCompletelyReceived",
      );
  }
}
