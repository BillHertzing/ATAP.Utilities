import * as vscode from "vscode";
import * as path from "path";
import * as crypto from "crypto";
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
import {
  SupportedSerializersEnum,
  QueryFragmentEnum,
} from "@BaseEnumerations/index";

import {
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from "@Serializers/index";

import { IConfigurationData } from "@DataService/index";

import {
  TagValueType,
  CategoryValueType,
  IAssociationValueType,
  AssociationValueType,
  QueryFragmentValueType,
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
  IQueryFragment,
  QueryFragment,
  IQueryFragmentCollection,
  QueryFragmentCollection,
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
} from "@ItemWithIDs/index";

type AsyncFileFunction = (file: vscode.Uri) => Promise<void>;

export interface IFileManager {
  readonly tagCollection: ITagCollection | undefined;
  readonly categoryCollection: ICategoryCollection | undefined;
  readonly associationCollection: IAssociationCollection | undefined;
  readonly queryFragmentCollection: IQueryFragmentCollection | undefined;
  readonly conversationCollection: IConversationCollection;

  saveTagCollectionAsync(): Promise<void>;
  saveCategoryCollectionAsync(): Promise<void>;
  saveAssociationCollectionAsync(): Promise<void>;
  saveQueryFragmentCollectionAsync(): Promise<void>;
  saveConversationCollectionAsync(): Promise<void>;

  readonly temporaryFileDirectoryPath: PathLike;
  readonly temporaryFilePaths: PathLike[];
  checkFileAsync(path: string, mode: number): Promise<boolean>;

  getNewTemporaryFilePathIndex(extension: string): number;
  processFilesAsync(extension: string, func: AsyncFileFunction): Promise<void>;
  disposeAsync(): void;
}

@logConstructor
export class FileManager implements IFileManager {
  private _temporaryFileDirectoryPath: PathLike | undefined;
  private _conversationCollection: ConversationCollection | undefined;
  private _tagCollection: ITagCollection | undefined;
  private _associationCollection: IAssociationCollection | undefined;
  private _queryFragmentCollection: IQueryFragmentCollection | undefined;
  private _categoryCollection: ICategoryCollection | undefined;
  public readonly temporaryFilePaths: PathLike[] = [];
  private disposed = false;

  constructor(
    private readonly logger: ILogger,
    readonly configurationData: IConfigurationData,
  ) {
    this.logger = new Logger(this.logger, "FileManager");
  }

  get temporaryFileDirectoryPath(): PathLike {
    // lazy load the temporaryFileDirectoryPath
    if (!this._temporaryFileDirectoryPath) {
      this._temporaryFileDirectoryPath = path.join(
        this.configurationData.getTempDirectoryBasePath(),
        this.configurationData.extensionID,
      );
      try {
        mkdirSync(this._temporaryFileDirectoryPath, { recursive: true });
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
    return this._temporaryFileDirectoryPath as PathLike;
  }

  get tagCollection(): ITagCollection {
    if (!this._tagCollection) {
      // Lazy load the tag collection
      // does the file configurationData.tagsFilePath exist?
      let data: string;
      if (existsSync(this.configurationData.tagsFilePath)) {
        // read the data
        try {
          data = readFileSync(this.configurationData.tagsFilePath, "utf8");
        } catch (e) {
          HandleError(
            e,
            "FileManager",
            "tagCollection",
            this.configurationData.tagsFilePath,
          );
          throw e;
        }
        // use the serializer to deserialize the data
        // ToDo: add try/catch block if deserialization fails
        if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Json
        ) {
          const parsedData = JSON.parse(data);
          this._tagCollection = parsedData as TagCollection;
        } else if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Yaml
        ) {
          const parsedData = fromYaml(data);
          this._tagCollection = parsedData as TagCollection;
        }
      } else {
        // if the local copy is not defined and the file doesn't exist, create a new conversation collection
        let value: ItemWithID<Tag, string>[] = [];
        this._tagCollection = new TagCollection(value);
      }
    }
    return this._tagCollection as TagCollection;
  }

  @logAsyncFunction
  async saveTagCollectionAsync(): Promise<void> {
    this.logger.log("starting function saveTagCollectionAsync", LogLevel.Debug);
    // write the tag collection to disk
    // serialize the tag collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._tagCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._tagCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.tagsFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "saveTagCollectionAsync",
        `failed calling createFileAndWriteAsync(${this.configurationData.tagsFilePath}, ${data}`,
      );
    }

    this.logger.log("finished function saveTagCollectionAsync", LogLevel.Debug);
  }

  get categoryCollection(): ICategoryCollection {
    if (!this._categoryCollection) {
      // Lazy load the category collection
      // does the file configurationData.categorysFilePath exist?
      let data: string;
      if (existsSync(this.configurationData.categorysFilePath)) {
        // read the data
        try {
          data = readFileSync(this.configurationData.categorysFilePath, "utf8");
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              `FileManager categoryCollection: failed to read ${this.configurationData.categorysFilePath} -> `,
              e,
            );
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `FileManager categoryCollection: failed to read ${
                this.configurationData.categorysFilePath
              } and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
        // use the serializer to deserialize the data
        // ToDo: add try/catch block if deserialization fails
        if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Json
        ) {
          const parsedData = JSON.parse(data);
          this._categoryCollection = parsedData as CategoryCollection;
        } else if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Yaml
        ) {
          const parsedData = fromYaml(data);
          this._categoryCollection = parsedData as CategoryCollection;
        }
      } else {
        // if the local copy is not defined and the file doesn't exist, create a new conversation collection
        let value: ItemWithID<Category, string>[] = [];
        this._categoryCollection = new CategoryCollection(value);
      }
    }

    return this._categoryCollection as CategoryCollection;
  }

  @logAsyncFunction
  async saveCategoryCollectionAsync(): Promise<void> {
    this.logger.log(
      "starting function saveCategoryCollectionAsync",
      LogLevel.Debug,
    );
    // write the category collection to disk
    // serialize the category collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._categoryCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._categoryCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.categorysFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "saveCategoryCollectionAsync",
        `failed calling createFileAndWriteAsync(${this.configurationData.categorysFilePath}, ${data}`,
      );
    }

    this.logger.log(
      "finished function saveCategoryCollectionAsync",
      LogLevel.Debug,
    );
  }

  get associationCollection(): IAssociationCollection {
    if (!this._associationCollection) {
      // Lazy load the association collection
      // does the file configurationData.associationsFilePath exist?
      let data: string;
      if (existsSync(this.configurationData.associationsFilePath)) {
        // read the data
        try {
          data = readFileSync(
            this.configurationData.associationsFilePath,
            "utf8",
          );
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              `FileManager associationCollection: failed to read ${this.configurationData.associationsFilePath} -> `,
              e,
            );
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `FileManager associationCollection: failed to read ${
                this.configurationData.associationsFilePath
              } and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
        // use the serializer to deserialize the data
        // ToDo: add try/catch block if deserialization fails
        if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Json
        ) {
          const parsedData = JSON.parse(data);
          this._associationCollection = parsedData as AssociationCollection;
        } else if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Yaml
        ) {
          const parsedData = fromYaml(data);
          this._associationCollection = parsedData as AssociationCollection;
        }
      } else {
        // if the local copy is not defined and the file doesn't exist, create a new conversation collection
        let value: ItemWithID<Association, AssociationValueType>[] = [];
        this._associationCollection = new AssociationCollection(value);
      }
    }

    return this._associationCollection as AssociationCollection;
  }

  @logAsyncFunction
  async saveAssociationCollectionAsync(): Promise<void> {
    this.logger.log(
      "starting function saveAssociationCollectionAsync",
      LogLevel.Debug,
    );
    // write the association collection to disk
    // serialize the association collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._associationCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._associationCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.associationsFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "saveAssociationCollectionAsync",
        `failed calling createFileAndWriteAsync(${this.configurationData.associationsFilePath}, ${data}`,
      );
    }
    this.logger.log(
      "finished function saveAssociationCollectionAsync",
      LogLevel.Debug,
    );
  }

  get queryFragmentCollection(): IQueryFragmentCollection {
    if (!this._queryFragmentCollection) {
      // Lazy load the queryFragment collection
      // does the file configurationData.queryFragmentsFilePath exist?
      let data: string;
      if (existsSync(this.configurationData.queryFragmentsFilePath)) {
        // read the data
        try {
          data = readFileSync(
            this.configurationData.queryFragmentsFilePath,
            "utf8",
          );
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              `FileManager queryFragmentCollection: failed to read ${this.configurationData.queryFragmentsFilePath} -> `,
              e,
            );
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `FileManager queryFragmentCollection: failed to read ${
                this.configurationData.queryFragmentsFilePath
              } and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
        // use the serializer to deserialize the data
        // ToDo: add try/catch block if deserialization fails
        if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Json
        ) {
          const parsedData = JSON.parse(data);
          this._queryFragmentCollection = parsedData as QueryFragmentCollection;
        } else if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Yaml
        ) {
          const parsedData = fromYaml(data);
          this._queryFragmentCollection = parsedData as QueryFragmentCollection;
        }
      } else {
        // if the local copy is not defined and the file doesn't exist, create a new QueryFragmenCollection
        let value: ItemWithID<QueryFragment, QueryFragmentValueType>[] = [];
        this._queryFragmentCollection = new QueryFragmentCollection(value);
        // TEMP: populate a collection of string QueryFragments
        this._queryFragmentCollection.value.push(
          new QueryFragment(
            new QueryFragmentValueType(
              QueryFragmentEnum.StringFragment,
              "string fragment 1",
            ),
          ),
        );
      }
    }
    return this._queryFragmentCollection as QueryFragmentCollection;
  }

  @logAsyncFunction
  async saveQueryFragmentCollectionAsync(): Promise<void> {
    this.logger.log(
      "starting function saveQueryFragmentCollectionAsync",
      LogLevel.Debug,
    );
    // write the queryFragment collection to disk
    // serialize the queryFragment collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._queryFragmentCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._queryFragmentCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.queryFragmentsFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "saveQueryFragmentCollectionAsync",
        `failed calling createFileAndWriteAsync(${this.configurationData.queryFragmentsFilePath}, ${data}`,
      );
    }
    this.logger.log(
      "finished function saveQueryFragmentCollectionAsync",
      LogLevel.Debug,
    );
  }

  get conversationCollection(): IConversationCollection {
    if (!this._conversationCollection) {
      // Lazy load the conversation collection
      // does the file configurationData.conversationsFilePath exist?
      let data: string;
      if (existsSync(this.configurationData.conversationsFilePath)) {
        // read the data
        try {
          data = readFileSync(
            this.configurationData.conversationsFilePath,
            "utf8",
          );
        } catch (e) {
          if (e instanceof Error) {
            throw new DetailedError(
              `FileManager conversationCollection: failed to read ${this.configurationData.conversationsFilePath} -> `,
              e,
            );
          } else {
            // ToDo:  investigation to determine what else might happen
            throw new Error(
              `FileManager conversationCollection: failed to read ${
                this.configurationData.conversationsFilePath
              } and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        }
        // use the serializer to deserialize the data
        // ToDo: add try/catch block if deserialization fails
        if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Json
        ) {
          const parsedData = JSON.parse(data);
          this._conversationCollection = parsedData as ConversationCollection;
        } else if (
          this.configurationData.serializerName ===
          SupportedSerializersEnum.Yaml
        ) {
          const parsedData = fromYaml(data);
          this._conversationCollection = parsedData as ConversationCollection;
        }
      } else {
        // if the local copy is not defined and the file doesn't exist, create a new conversation collection
        let value: ItemWithID<
          QueryPairCollection,
          QueryPairCollectionValueType
        >[] = [];
        this._conversationCollection = new ConversationCollection(value);
      }
    }
    return this._conversationCollection as ConversationCollection;
  }

  @logAsyncFunction
  async saveConversationCollectionAsync(): Promise<void> {
    this.logger.log(
      "starting function saveConversationCollectionAsync",
      LogLevel.Debug,
    );
    // write the conversation collection to disk
    // serialize the conversation collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._conversationCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._conversationCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.conversationsFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "saveConversationCollectionAsync",
        `failed calling createFileAndWriteAsync(${this.configurationData.conversationsFilePath}, ${data}`,
      );
    }

    this.logger.log(
      "finished function saveConversationCollectionAsync",
      LogLevel.Debug,
    );
  }

  @logAsyncFunction
  async checkFileAsync(path: PathLike, mode: number): Promise<boolean> {
    return new Promise(async (resolve, reject) => {
      try {
        await fs.access(path, mode);
      } catch (e) {
        reject(e);
      }
      resolve(true);
    });
  }

  //   return new Promise((resolve, reject) => {
  //     fs.access(path, mode, (err) => {
  //       if (err) {
  //         reject(err);
  //       } else {
  //         resolve(true);
  //       }
  //     });
  //   });
  // }

  @logAsyncFunction
  async createDirectoryIfNeededAsync(path: PathLike): Promise<void> {
    //this.logger.log(`FileManager.createDirectoryIfNeededAsync: creating ${path}`, LogLevel.Debug);
    try {
      await fs.mkdir(path, { recursive: true });
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(
          `FileManager createDirectoryIfNeededAsync: failed to create ${path} -> `,
          e,
        );
      } else {
        throw new Error(
          `FileManager createDirectoryIfNeededAsync: failed to create ${path} and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
    this.logger.log(
      `FileManager.createDirectoryIfNeededAsync: created ${path}`,
      LogLevel.Debug,
    );
  }

  @logAsyncFunction
  async createFileAndWriteAsync(
    filePath: PathLike,
    content: string,
  ): Promise<void> {
    //      this.logger.log(`FileManager.createFileAndWriteAsync: creating ${filePath}`, LogLevel.Debug);
    //this.logger.log(`FileManager.createFileAndWriteAsync: path=${path.dirname(filePath.toString())}`, LogLevel.Debug);

    this.createDirectoryIfNeededAsync(path.dirname(filePath.toString()))
      .then(() => {
        this.logger.log(
          `FileManager.createFileAndWriteAsync: writing ${filePath}`,
          LogLevel.Debug,
        );
        fs.writeFile(filePath, content)
          .then(() => {
            this.logger.log(
              `FileManager.createFileAndWriteAsync: wrote ${filePath}`,
              LogLevel.Debug,
            );
          })
          .catch((e) => {
            HandleError(
              e,
              "FileManager",
              "createFileAndWriteAsync",
              `failed attempting to write ${filePath}`,
            );
          });
      })
      .catch((e) => {
        HandleError(
          e,
          "FileManager",
          "createDirectoryIfNeededAsync",
          `failed attempting ot create ${path}`,
        );
      });
  }

  @logFunction
  getNewTemporaryFilePathIndex(extension: string): number {
    const randomFileName = crypto.randomBytes(16).toString("hex") + extension;
    const temporaryFilePath = path.join(
      this.temporaryFileDirectoryPath.toString(),
      randomFileName,
    );
    this.temporaryFilePaths.push(temporaryFilePath);
    return this.temporaryFilePaths.length - 1;
  }

  @logAsyncFunction
  async processFilesAsync(
    extension: string,
    func: AsyncFileFunction,
  ): Promise<void> {
    // Search for all files with the given extension in the workspace
    let pattern = `**/*.${extension}`;
    let files = await vscode.workspace.findFiles(pattern);

    // Loop through the results
    for (let file of files) {
      // Apply the function to each file
      await func(file);
    }
  }

  @logAsyncFunction
  async disposeTagCollectionAsync() {
    // write the tag collection to disk
    // serialize the tag collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._tagCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._tagCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.tagsFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "disposeTagCollection",
        this.configurationData.tagsFilePath,
      );
      throw e;
    }
    this._tagCollection = undefined;
  }

  @logAsyncFunction
  async disposeCategoryCollectionAsync() {
    try {
      await this.saveConversationCollectionAsync();
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "disposeCategoryCollection",
        this.configurationData.categorysFilePath,
      );
    }
    this._categoryCollection = undefined;
  }

  @logAsyncFunction
  async disposeAssociationCollectionAsync() {
    // write the association collection to disk
    // serialize the association collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._associationCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._associationCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.associationsFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "disposeAssociationCollection",
        this.configurationData.associationsFilePath,
      );
    }
    this._associationCollection = undefined;
  }

  async disposeQueryFragmentCollectionAsync() {
    // write the queryFragment collection to disk
    // serialize the queryFragment collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._queryFragmentCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._queryFragmentCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.queryFragmentsFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "disposeQueryFragmentCollection",
        this.configurationData.queryFragmentsFilePath,
      );
    }
    this._queryFragmentCollection = undefined;
  }

  @logAsyncFunction
  async disposeConversationCollectionAsync() {
    await this.saveConversationCollectionAsync();
    // write the conversation collection to disk
    // serialize the conversation collection
    let data: string = "";
    if (
      this.configurationData.serializerName === SupportedSerializersEnum.Json
    ) {
      data = JSON.stringify(this._conversationCollection);
    } else if (
      this.configurationData.serializerName === SupportedSerializersEnum.Yaml
    ) {
      data = toYaml(this._conversationCollection);
    } else {
      throw new Error(
        `Unsupported serializer: ${this.configurationData.serializerName}`,
      );
    }
    // write the data to disk
    try {
      await this.createFileAndWriteAsync(
        this.configurationData.conversationsFilePath,
        data,
      );
    } catch (e) {
      HandleError(
        e,
        "FileManager",
        "disposeConversationCollection",
        this.configurationData.conversationsFilePath,
      );
    }
    this._conversationCollection = undefined;
  }
  @logAsyncFunction
  async disposeAsync() {
    if (!this.disposed) {
      // release any resources
      // Write the Tag, Category,ASsociation, and Conversation collection to disk
      try {
        const results = await Promise.all([
          this.disposeTagCollectionAsync(),
          this.disposeCategoryCollectionAsync(),
          this.disposeAssociationCollectionAsync(),
          this.disposeQueryFragmentCollectionAsync(),
          this.disposeConversationCollectionAsync(),
        ]);
        this.disposed = true;
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `FileManager disposeAsync: failed to dispose -> `,
            e,
          );
        }
      }
    }
  }
}
