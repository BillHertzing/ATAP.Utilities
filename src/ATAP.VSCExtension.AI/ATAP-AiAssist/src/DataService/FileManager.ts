import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { DetailedError } from '@ErrorClasses/index';
import { logAsyncFunction, logConstructor, logFunction } from '@Decorators/index';
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

import { ILogger } from '@Logger/index';
import { IConfigurationData } from '@DataService/index';

import {
  TagValueType,
  CategoryValueType,
  IAssociationValueType,
  AssociationValueType,
  QueryRequestValueType,
  QueryResponseValueType,
  IQueryPairValueType,
  QueryPairValueType,
  IQueryPairCollectionValueType,
  QueryPairCollectionValueType,
  ItemWithIDValueType,
  ItemWithIDTypes,
  //  MapTypeToValueType,
  //  YamlData,
  //  fromYamlForItemWithID,
  IItemWithID,
  ItemWithID,
  ICollection,
  Collection,
  ITag,
  Tag,
  ITagCollection,
  TagCollection,
  ICategory,
  Category,
  ICategoryCollection,
  CategoryCollection,
  IAssociation,
  Association,
  IAssociationCollection,
  AssociationCollection,
  IQueryRequest,
  QueryRequest,
  IQueryResponse,
  QueryResponse,
  IQueryPair,
  QueryPair,
  IQueryPairCollection,
  QueryPairCollection,
  IConversationCollection,
  ConversationCollection,
} from '@ItemWithIDs/index';

import { log } from 'console';

type AsyncFileFunction = (file: vscode.Uri) => Promise<void>;

export interface IFileManager {
  readonly conversationCollection: IConversationCollection;
  readonly temporaryFileDirectoryPath: fs.PathLike;
  readonly temporaryFilePaths: fs.PathLike[];
  checkFileAsync(path: string, mode: number): Promise<boolean>;
  getNewTemporaryFilePathIndex(extension: string): number;
  processFilesAsync(extension: string, func: AsyncFileFunction): Promise<void>;
  dispose(): void;
}

@logConstructor
export class FileManager implements IFileManager {
  private _temporaryFileDirectoryPath: fs.PathLike | undefined;
  private _conversationCollection: ConversationCollection | undefined;
  public readonly temporaryFilePaths: fs.PathLike[] = [];
  private disposed = false;

  constructor(
    readonly logger: ILogger,
    readonly configurationData: IConfigurationData,
  ) {}

  get temporaryFileDirectoryPath(): fs.PathLike {
    // lazy load the temporaryFileDirectoryPath
    if (!this._temporaryFileDirectoryPath) {
      this._temporaryFileDirectoryPath = path.join(
        this.configurationData.getTempDirectoryBasePath(),
        this.configurationData.extensionID,
      );
      try {
        fs.mkdirSync(this._temporaryFileDirectoryPath, { recursive: true });
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `FileManager temporaryFileDirectoryPath: failed to create ${this._temporaryFileDirectoryPath} -> `,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `FileManager temporaryFileDirectoryPath: failed to create ${
              this._temporaryFileDirectoryPath
            } and the instance of (e) returned is of type ${typeof e}`,
          );
        }
      }
    }
    return this._temporaryFileDirectoryPath as fs.PathLike;
  }

  get conversationCollection(): IConversationCollection {
    if (!this._conversationCollection) {
      // Lazy load the conversation collection
      // does the file configurationData.conversationFilePath exist?
      let data: string;
      if (fs.existsSync(this.configurationData.conversationFilePath)) {
        // read the data
        try {
          data = fs.readFileSync(this.configurationData.conversationFilePath, 'utf8');
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              `FileManager conversationCollection: failed to read ${this.configurationData.conversationFilePath} -> `,
              e,
            );
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `FileManager conversationCollection: failed to read ${
                this.configurationData.conversationFilePath
              } and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
        // use the serializer to deserialize the data
        if (this.configurationData.serializerName === SupportedSerializersEnum.Json) {
          const parsedData = JSON.parse(data);
          this._conversationCollection = parsedData as ConversationCollection;
        } else if (this.configurationData.serializerName === SupportedSerializersEnum.Yaml) {
          const parsedData = fromYaml(data);
          this._conversationCollection = parsedData as ConversationCollection;
        }
      } else {
        let value: ItemWithID<QueryPairCollection, QueryPairCollectionValueType>[] = [];
        this._conversationCollection = new ConversationCollection(value);
      }
    } else {
      // create a new conversation collection
      let value: ItemWithID<QueryPairCollection, QueryPairCollectionValueType>[] = [];
      this._conversationCollection = new ConversationCollection(value);
    }

    return this._conversationCollection as ConversationCollection;
  }

  @logAsyncFunction
  public checkFileAsync(path: fs.PathLike, mode: number): Promise<boolean> {
    return new Promise((resolve, reject) => {
      fs.access(path, mode, (err) => {
        if (err) {
          reject(err);
        } else {
          resolve(true);
        }
      });
    });
  }

  @logFunction
  getNewTemporaryFilePathIndex(extension: string): number {
    const randomFileName = crypto.randomBytes(16).toString('hex') + extension;
    const temporaryFilePath = path.join(this.temporaryFileDirectoryPath.toString(), randomFileName);
    this.temporaryFilePaths.push(temporaryFilePath);
    return this.temporaryFilePaths.length - 1;
  }

  @logAsyncFunction
  async processFilesAsync(extension: string, func: AsyncFileFunction): Promise<void> {
    // Search for all files with the given extension in the workspace
    let pattern = `**/*.${extension}`;
    let files = await vscode.workspace.findFiles(pattern);

    // Loop through the results
    for (let file of files) {
      // Apply the function to each file
      await func(file);
    }
  }

  @logFunction
  disposeConversationCollection() {
    // write the conversation collection to disk

    // serialize the conversation collection
    let data: string = '';
    if (this.configurationData.serializerName === SupportedSerializersEnum.Json) {
      data = JSON.stringify(this._conversationCollection);
    } else if (this.configurationData.serializerName === SupportedSerializersEnum.Yaml) {
      data = toYaml(this._conversationCollection);
    } else {
      throw new Error(`Unsupported serializer: ${this.configurationData.serializerName}`);
    }

    // write the data to disk
    try {
      fs.writeFileSync(this.configurationData.conversationFilePath, data);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(
          `FileManager disposeConversationCollection: failed to write ${this.configurationData.conversationFilePath} -> `,
          e,
        );
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `FileManager disposeConversationCollection: failed to write ${
            this.configurationData.conversationFilePath
          } and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
    this._conversationCollection = undefined;
  }

  @logFunction
  dispose() {
    if (!this.disposed) {
      // release any resources
      // Write the conversation collection to disk
      this.disposeConversationCollection();
      this.disposed = true;
    }
  }
}
