import * as vscode from "vscode";
import {
  promises as fs,
  PathLike,
  existsSync,
  readFileSync,
  mkdirSync,
} from "fs";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";
import {
  logConstructor,
  logFunction,
  logAsyncFunction,
  logExecutionTime,
} from "@Decorators/index";
import { SupportedSerializersEnum } from "@BaseEnumerations/index";
import { IConfigurationData } from "@DataService/index";

import {
  AiAssistCancellationTokenSourceValueType,
  IItemWithID,
  ItemWithID,
  ICollection,
  Collection,
  IAiAssistCancellationTokenSource,
  AiAssistCancellationTokenSource,
  IAiAssistCancellationTokenSourceCollection,
  AiAssistCancellationTokenSourceCollection,
} from "@ItemWithIDs/index";

export interface IAiAssistCancellationTokenSourceManager {
  readonly aiAssistCancellationTokenSourceCollection:
    | IAiAssistCancellationTokenSourceCollection
    | undefined;
  disposeAsync(): void;
}

@logConstructor
export class AiAssistCancellationTokenSourceManager
  implements IAiAssistCancellationTokenSourceManager
{
  private _aiAssistCancellationTokenSourceCollection:
    | IAiAssistCancellationTokenSourceCollection
    | undefined;
  private disposed = false;
  constructor(private readonly logger: ILogger) {
    this.logger = new Logger(
      this.logger,
      "AiAssistCancellationTokenSourceManager",
    );
  }

  get aiAssistCancellationTokenSourceCollection(): IAiAssistCancellationTokenSourceCollection {
    if (!this._aiAssistCancellationTokenSourceCollection) {
      let value: ItemWithID<
        AiAssistCancellationTokenSource,
        AiAssistCancellationTokenSourceValueType
      >[] = [];
      this._aiAssistCancellationTokenSourceCollection =
        new AiAssistCancellationTokenSourceCollection(value);
    }
    return this
      ._aiAssistCancellationTokenSourceCollection as IAiAssistCancellationTokenSourceCollection;
  }

  @logAsyncFunction
  async disposeCancellationTokenSourceCollectionAsync() {
    // toDo: If the collection is not empty, trigger the cancellation token for each item in the collection
  }

  @logAsyncFunction
  async disposeAsync() {
    if (!this.disposed) {
      // cancel any cancellable async tasks
      try {
        const results = await Promise.all([
          this.disposeCancellationTokenSourceCollectionAsync(),
        ]);
        this.disposed = true;
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `CancellationTokenSourceManager disposeAsync: failed to dispose -> `,
            e,
          );
        }
      }
    }
  }
}
