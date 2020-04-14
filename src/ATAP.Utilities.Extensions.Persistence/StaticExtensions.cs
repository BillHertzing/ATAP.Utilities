using System;
using System.Data;
using System.IO;
using System.Linq;
using System.Text;
using ServiceStack.OrmLite;
using ServiceStack.OrmLite.SqlServer;

namespace ATAP.Utilities.Persistence {
  public static class StaticExtensions {
    // Common constructor method for the SetupViaFileFunc
    public static Func<SetupViaFileData, SetupViaFileResults> SetupViaFileFuncBuilder() {
      Func<SetupViaFileData, SetupViaFileResults> ret = new Func<SetupViaFileData, SetupViaFileResults>((setupData) => {
        var filePathsAsArray = setupData.FilePaths.ToArray();
        int numberOfFiles = filePathsAsArray.Length;
        FileStream[] fileStreams = new FileStream[numberOfFiles];
        StreamWriter[] streamWriters = new StreamWriter[numberOfFiles];
        for (var i = 0; i < numberOfFiles; i++) {
          fileStreams[i] = new FileStream(filePathsAsArray[i], FileMode.Create, FileAccess.Write);
          //ToDo: exception handling
          streamWriters[i] = new StreamWriter(fileStreams[i], Encoding.UTF8);
          //ToDo: exception handling
        }
        return new SetupViaFileResults(true, fileStreams, streamWriters);
      });
      return ret;
    }

    // Common constructor method for the InsertViaFileFunc
    // expects setupResults instance setup by the SetupViaFileFuncBuilder, and closes over it
    public static Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults> InsertViaFileFuncBuilder() {
      Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults> ret = new Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults>((insertData, setupResults) => {
        int numberOfFiles = insertData.DataToInsert[0].Length;
        for (var i = 0; i < numberOfFiles; i++) {
          foreach (string str in insertData.DataToInsert[i]) {
            //ToDo: create async version await setupResults.StreamWriters[i].WriteLineAsync(str);
            setupResults.StreamWriters[i].WriteLine(str);
          }
        }
        return new InsertViaFileResults(true);
      });
      return ret;
    }

    // Common constructor method for the SetupViaORMFunc
    public static Func<SetupViaORMData, SetupViaORMResults> SetupViaORMFuncBuilder() {
      Func<SetupViaORMData, SetupViaORMResults> ret = new Func<SetupViaORMData, SetupViaORMResults>((setupData) => {
        //Setup SQL Server Connection Factory
        var dbFactory = new OrmLiteConnectionFactory(
          setupData.DBConnectionString,
            setupData.Provider
            );

        //Use in-memory Sqlite DB instead
        //var dbFactory = new OrmLiteConnectionFactory(
        //    ":memory:", false, SqliteOrmLiteDialectProvider.Instance);

        IDbConnection dbConn = dbFactory.OpenDbConnection();
        IDbCommand dbCmd = dbConn.CreateCommand();
        //var InsertableTableOrViewsAsarray = setupData.InsertableTableOrViews.ToArray();
        //int numberOfInsertableTableOrViews = InsertableTableOrViewsAsarray.Length;
        //InsertableTableOrView[] InsertableTableOrViewCollection = new InsertableTableOrView[number OfTables];

        return new SetupViaORMResults( dbFactory, dbConn, dbCmd, true);
      });
      return ret;
    }

    // Common constructor method for the InsertViaORMFunc
    // expects setupResults instance setup by the SetupViaORMFuncBuilder,  and closes over it
    public static Func<IInsertViaORMData, ISetupViaORMResults, InsertViaORMResults> InsertViaORMFuncBuilder() {
      Func<IInsertViaORMData, ISetupViaORMResults, InsertViaORMResults> ret = new Func<IInsertViaORMData, ISetupViaORMResults, InsertViaORMResults>((insertData, setupResults) => {
        //int numberOfORMs = insertData.DataToInsert[0].Length;
        //for (var i = 0; i < numberOfORMs; i++) {
        //  foreach (string str in insertData.DataToInsert[i]) {
        //    //ToDo: create async version await setupResults.StreamWriters[i].WriteLineAsync(str);
        //    setupResults.StreamWriters[i].WriteLine(str);
        //  }
        //}
        return new InsertViaORMResults(true);
      });
      return ret;
    }

  }
}
