using System;
using System.IO;
using System.Linq;
using System.Text;

namespace ATAP.Utilities.Persistence
{
    public static class StaticExtensions
    {
		    // Common constructor method for the SetupViaFileFunc
    public static Func<SetupViaFileData, SetupViaFileResults> SetupViaFileFuncBuilder()
    {
      Func<SetupViaFileData, SetupViaFileResults> ret = new Func<SetupViaFileData, SetupViaFileResults>((setupData) =>
      {
        var filePathsAsArray = setupData.FilePaths.ToArray();
        int numberOfFiles = filePathsAsArray.Length;
        FileStream[] fileStreams = new FileStream[numberOfFiles];
        StreamWriter[] streamWriters = new StreamWriter[numberOfFiles];
        for (var i = 0; i < numberOfFiles; i++)
        {
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
    public static  Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults> InsertViaFileFuncBuilder()
    {
      Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults> ret = new Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults>((insertData, setupResults) =>
      {
        int numberOfFiles = insertData.DataToInsert[0].Length;
        for (var i = 0; i < numberOfFiles; i++)
        {
          foreach (string str in insertData.DataToInsert[i])
          {
            //ToDo: create async version await setupResults.StreamWriters[i].WriteLineAsync(str);
            setupResults.StreamWriters[i].WriteLine(str);
          }
        }
        return new InsertViaFileResults(true);
      });
      return ret;
    }

   
  }
}
