import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logAsyncFunction, logFunction } from '@Decorators/Decorators';

import { StringBuilder } from '@Utilities/index';

export interface IQueryResultBase {
  resultContent: StringBuilder;
  resultSnapshot: StringBuilder;
  isValid: boolean; // Indicates the validity of the data
  errorMessage?: string; // Optional field for error message
}

export interface IQueryResultOpenAPI extends IQueryResultBase {
  chatCompletion: any; // Replace 'any' with the actual type
  resultContent: StringBuilder;
  resultSnapshot: StringBuilder;
  isValid: boolean;
  errorMessage: string;
}

export class QueryResultOpenAPI implements IQueryResultOpenAPI {
  chatCompletion: any; // Replace 'any' with the actual type
  resultContent: StringBuilder;
  resultSnapshot: StringBuilder;
  isValid: boolean;
  errorMessage: string;

  constructor(
    chatCompletion: any,
    resultContent: StringBuilder,
    resultSnapshot: StringBuilder,
    isValid: boolean,
    errorMessage: string,
  ) {
    this.chatCompletion = chatCompletion;
    this.resultContent = resultContent;
    this.resultSnapshot = resultSnapshot;
    this.isValid = isValid;
    this.errorMessage = errorMessage;
  }
}
