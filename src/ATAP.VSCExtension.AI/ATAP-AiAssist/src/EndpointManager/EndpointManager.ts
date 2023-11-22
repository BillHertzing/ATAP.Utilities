import * as vscode from 'vscode';

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

export enum LLModels {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  //Grok = 'Grok',
  //Copilot = 'Copilot',
}

export enum HttpVerb {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  GET = 'GET',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  POST = 'POST',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  PUT = 'PUT',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  DELETE = 'DELETE',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  PATCH = 'PATCH',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  HEAD = 'HEAD',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  OPTIONS = 'OPTIONS',
}

export class EndpointConfig {
  public baseUrl: string;
  public headers: Record<string, string>;
  public path: string;
  public verb: HttpVerb;
  public body?: any;
  public queryParams?: URLSearchParams;

  constructor(
    baseUrl: string,
    headers: Record<string, string> = {},
    path: string,
    verb: HttpVerb,
    body?: any,
    queryParams?: URLSearchParams,
  ) {
    this.baseUrl = baseUrl;
    this.headers = headers;
    this.path = path;
    this.verb = verb;
    this.body = body;
    this.queryParams = queryParams;
  }

  get fullUrl(): string {
    const url = new URL(this.path, this.baseUrl);
    if (this.queryParams) {
      url.search = this.queryParams.toString();
    }
    return url.toString();
  }
}

export class ChatGptEndpointConfig extends EndpointConfig {
  constructor(
    baseUrl: string,
    headers: Record<string, string> = {},
    path: string,
    verb: HttpVerb,
    body?: any,
    queryParams?: URLSearchParams,
  ) {
    super(baseUrl, headers, path, verb, body, queryParams);
    // Additional ChatGPT-specific configuration can go here
  }
}

export class GrokEndpointConfig extends EndpointConfig {
  constructor(
    baseUrl: string,
    headers: Record<string, string> = {},
    path: string,
    verb: HttpVerb,
    body?: any,
    queryParams?: URLSearchParams,
  ) {
    super(baseUrl, headers, path, verb, body, queryParams);
    // Additional Grok-specific configuration can go here
  }
}

export class CopilotEndpointConfig extends EndpointConfig {
  constructor(
    baseUrl: string,
    headers: Record<string, string> = {},
    path: string,
    verb: HttpVerb,
    body?: any,
    queryParams?: URLSearchParams,
  ) {
    super(baseUrl, headers, path, verb, body, queryParams);
    // Additional CoPilot-specific configuration can go here
  }
}
export class EndpointManager {
  private endpointConfigs: Record<LLModels, EndpointConfig>;

  constructor() {
    this.endpointConfigs = {
      [LLModels.ChatGPT]: new ChatGptEndpointConfig('https://api.openai.com/v1', {}, 'chat/completions', HttpVerb.POST),
      //[LLModels.Grok]: new GrokEndpointConfig(baseConfig),
      //[LLModels.Copilot]: new CopilotEndpointConfig(baseConfig),
      // Additional endpoints can be added here
    };
  }

  getEndpointConfig(model: LLModels): EndpointConfig {
    return this.endpointConfigs[model];
  }

  convertTo_json(): string {
    return toJson(this);
  }
  // for developemnt purposes only
  // create an endpointconfigs and serialize it to json

  devEndpointConfigsAsJson(): string {
    const devEndpointConfigs = {
      [LLModels.ChatGPT]: new ChatGptEndpointConfig('https://api.openai.com/v1', {}, 'chat/completions', HttpVerb.POST),
      //[LLModels.Grok]: new GrokEndpointConfig(new EndpointConfig('https://test.openai.com/v1')),
      //[LLModels.Copilot]: new CopilotEndpointConfig(new EndpointConfig('https://test.openai.com/v1')),
    };
    return toJson(devEndpointConfigs);
  }
}
