//import axios from 'axios';
import * as diff from 'diff';
import Promise from 'bluebird';
import OpenAI from 'openai';

import * as vscode from 'vscode';
import axios, { AxiosRequestConfig, CancelTokenSource } from 'axios';
//import * as Promise from 'bluebird';

import * as fs from 'fs';
import * as path from 'path';
//import * as diff from 'diff';
import * as os from 'os';
import { exec } from 'child_process';

import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DataService, IData } from '@DataService/DataService';
import { DetailedError } from '@ErrorClasses/index';

import {
  EndpointManager,
  EndpointConfig,
  ChatGptEndpointConfig,
  GrokEndpointConfig,
  CopilotEndpointConfig,
  LLModels,
} from '@EndpointManager/index';

import { logAsyncFunction, logFunction } from '@Decorators/Decorators';

import { StringBuilder } from '@Utilities/index';
import strip from 'strip-comments';
import * as prettier from 'prettier';

import { IQueryResultBase, IQueryResultOpenAPI, QueryResultOpenAPI } from '@QueryService/index';

import { PasswordEntryType } from '@DataService/index';

export async function sendQueryOpenAIAsync(
  logger: ILogger,
  textToSubmit: string,
  data: IData,
): globalThis.Promise<IQueryResultOpenAPI> {
  // Get APISecretKey
  // let keePassSecretKey = endpointConfiguration[lLModel].keepass;
  // let keePassSecretKey = 'APIKeyForChatGPT';

  // get API Token from Keepass
  let aPIToken: PasswordEntryType = undefined;

  // ToDo: use a Factory (Service) pattern to hand out secrets internally to the extension, to ensure they are cleaned on deactivate

  try {
    aPIToken = await data.secretsManager.getAPITokenForChatGPTAsync();
    // Hmm I guess the extension should continue to operate with LLMs that do not have any authorization requirement
    // Every LLM is potentially different, the extension should have a defaultConfiguration structure for each LLM enumeration
    // but for now assume that an undefined aPIToken is an error
    if (!aPIToken) {
      throw new Error(`sendQueryOpenAIAsync calling getAPITokenForChatGPTAsync aPIToken is undefined`);
    }
    // Keep only the first line of the APIToken
    // use a regular expression for the split to handle both \n (*nix and macOS) and \r\n (Windows)
    aPIToken = Buffer.from(aPIToken.toString().split(/\r?\n/)[0], 'utf-8');
  } catch (e) {
    if (e instanceof Error) {
      throw new DetailedError('sendQueryOpenAIAsync getAPITokenForChatGPTAsync failed -> ', e);
    } else {
      // ToDo:  investigation to determine what else might happen
      throw new Error(
        `sendQueryOpenAIAsync getAPITokenForChatGPTAsync failed and the instance of (e) returned is of type ${typeof e}`,
      );
    }
  }

  logger.log(`setup an OpenAI instance with OpenAI library`, LogLevel.Debug);
  let openai: OpenAI | undefined = undefined;
  try {
    openai = new OpenAI({
      apiKey: aPIToken.toString(),
    });
    // ToDo: use a Factory (Service) pattern to hand out secrets internally to the extension, to ensure they are cleaned on deactivate
    aPIToken.fill(0);
  } catch (e) {
    if (e instanceof OpenAI.APIError) {
      // ToDo: handle any extra data in the error
      throw new DetailedError('sendQuery.OpenAI connection request  failed, APIError type was returned -> ', e);
    } else {
      if (e instanceof Error) {
        throw new DetailedError('sendQuery.OpenAI connection request failed -> ', e);
      } else {
        throw new Error(
          `sendQuery.OpenAI connection request caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }

  // // for testing
  // const chatCompletionTest = await openai.chat.completions.create({
  //   messages: [{ role: 'user', content: 'Say this is a test' }],
  //   model: 'gpt-3.5-turbo',
  // });

  logger.log(
    `Open the connection to OPenAI API, send the historical context, open files, query, and ask for streaming response`,
    LogLevel.Debug,
  );
  let stream: any; //OpenAI.ChatCompletionStream;
  try {
    stream = await openai.beta.chat.completions.stream({
      messages: [{ role: 'user', content: textToSubmit.toString() }],
      model: 'gpt-3.5-turbo',
    });
  } catch (e) {
    if (e instanceof OpenAI.APIError) {
      // ToDo handle any extra data in the error
      throw new DetailedError(
        'sendQuery openai.beta.chat.completions.stream failed, APIError type was returned -> ',
        e,
      );
    } else {
      if (e instanceof Error) {
        throw new DetailedError(
          'sendQuery openai.beta.chat.completions.stream failed, generic Error was returned -> ',
          e,
        );
      } else {
        throw new Error(
          `sendQuery openai.beta.chat.completions.stream page request caught an unknown object, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }

  // stream.on('content', (delta, snapshot) => {
  //   process.stdout.write(delta);
  // });

  let resultContent: StringBuilder = new StringBuilder();
  let resultSnapshot: StringBuilder = new StringBuilder();
  let isValid = true;
  let errorMessage = '';

  for await (const chunk of stream) {
    //logger.log(chunk.choices[0]?.delta?.content || '', Logger.LogLevel.Debug);
    //process.stdout.write(chunk.choices[0]?.delta?.content || '');
    resultContent.append(chunk.choices[0]?.delta?.content || '');
    //logger.log(chunk.choices[0]?.snapshot?.content || '', Logger.LogLevel.Debug);
    //process.stdout.write(chunk.choices[0]?.snapshot?.content || '');
    resultSnapshot.append(chunk.choices[0]?.snapshot?.content || '');
  }

  const chatCompletion = await stream.finalChatCompletion();

  // ToDo: handle incomplete and responses and other app-level error conditions that indicate the query was not successful
  if (false) {
    isValid = false;
    errorMessage = 'Invalid data detected';
  }

  //logger.log(chatCompletion, Logger.LogLevel.Debug);
  logger.log(`resultContent = ${resultContent.toString()}`, LogLevel.Debug);
  logger.log(`resultSnapshot = ${resultSnapshot.toString()}`, LogLevel.Debug);

  return new QueryResultOpenAPI(chatCompletion, resultContent, resultSnapshot, isValid, errorMessage);
}
