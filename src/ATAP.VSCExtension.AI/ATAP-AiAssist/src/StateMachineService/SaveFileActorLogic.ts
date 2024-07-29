import * as vscode from "vscode";
import { ILogger, Logger, LogLevel } from "@Logger/index";
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

import {
  Actor,
  createActor,
  assign,
  fromCallback,
  StateMachine,
  fromPromise,
} from "xstate";
import { IPrimaryMachineContext } from "./primaryMachineTypes";

export enum SaveFileEnumeration {
  TagsCollection = "TagsCollection",
  CategoryCollection = "CategoryCollection",
}

export interface ISaveFileMachineActorLogicInput {
  logger: ILogger;
  filePath: string;
  kindOfCollection: SaveFileEnumeration;
  collection: ITagCollection | ICategoryCollection;
}

export interface ISaveFileMachineActorOutput {
  isCancelled: boolean;
}

export const saveFileActorLogic = fromPromise(
  async ({ input }: { input: ISaveFileMachineActorLogicInput }) => {
    input.logger.log("Started", LogLevel.Debug);
    // validate path exists and is writeable, raise error if not

    switch (input.kindOfCollection) {
    }

    await true;

    return { isCancelled: false } as ISaveFileMachineActorOutput;
  },
);
