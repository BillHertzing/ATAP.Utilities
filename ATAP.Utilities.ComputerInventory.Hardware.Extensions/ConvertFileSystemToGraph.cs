
using ATAP.Utilities.Persistence;
using ATAP.Utilities.TypedGuids;
using System;
using System.Collections.Generic;
using System.Linq;
using System.IO;
using System.Security;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using ATAP.Utilities.GraphDataStructures;
using System.Globalization;

// To get access to the .Dump utility for logging
//using ServiceStack.Text;

// ToDo: figure out logging for the ATAP libraries, this is only temporary

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public static class StaticExtensions
  {
    public static async Task<ConvertFileSystemToGraphResult> ConvertFileSystemToGraphAsyncTask(string root, int asyncFileReadBlockSize, IConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress, PersistenceAbstract? convertFileSystemToGraphPersistence, CancellationToken cancellationToken)
    {
      // Some internal functions to make the code cleaner
      void CheckAndHandleCancellationToken(int checkpointNumber, PersistenceAbstract? convertFileSystemToGraphPersistence, CancellationToken cancellationToken)
      {
        // check CancellationToken to see if this task is cancelled
        if (cancellationToken.IsCancellationRequested)
        {
          // ToDo localize the Log message
          // Log.Debug($"in ConvertFileSystemToGraphAsyncTask: Cancellation requested, checkpoint numbe {checkpointNumber}");
          // ToDo: cleanup is needed if persistence is not null and setup has completed
          // DatabaseRollback();
          cancellationToken.ThrowIfCancellationRequested();
        }
      }
      // create the results instance
      ConvertFileSystemToGraphResult convertFileSystemToGraphResult = new ConvertFileSystemToGraphResult();

      if (!Directory.Exists(root))
      {
        throw new ArgumentException(string.Format(CultureInfo.CurrentCulture, StringConstants.RootDirectoryNotFoundExceptionMessage, root));
      }

      // Data structure to hold names of subcontainers to be examined for files, along with associated structures for Vertex(s).
      Stack<string> containers = new Stack<string>();
      string currentContainer;
      Stack<Vertex<IFSEntityAbstract>> containerVerticesStack = new Stack<Vertex<IFSEntityAbstract>>();
      Vertex<IFSEntityAbstract> currentContainerVertex;
      Vertex<IFSEntityAbstract> parentContainerVertex;

      // Initialize the fields of the ConvertFileSystemToGraphProgress if it is not null
      if (convertFileSystemToGraphProgress != null)
      {
        convertFileSystemToGraphProgress.Completed = false;
        convertFileSystemToGraphProgress.NumberOfDirectories = 0;
        convertFileSystemToGraphProgress.NumberOfFiles = 0;
        convertFileSystemToGraphProgress.DeepestDirectoryTree = 0;
        convertFileSystemToGraphProgress.LargestFile = 0;
      }
      // check CancellationToken to see if this task is cancelled
      if (cancellationToken.IsCancellationRequested)
      {
        // nothing to cleanup here
        // Log.Debug($"in ConvertFileSystemToGraphAsyncTask: Cancellation requested (1st checkpoint)");
        cancellationToken.ThrowIfCancellationRequested();
      }
      // After this point, there will be cleanup to do if the task is cancelled or exceptions are thrown
      // If the persistence argument is not null, setup the persistence
      if (convertFileSystemToGraphPersistence != null)
      {
        try
        {
          convertFileSystemToGraphPersistence.PersistenceSetupResults = convertFileSystemToGraphPersistence.PersistenceSetup(convertFileSystemToGraphPersistence.PersistenceSetupInitializationData);
        }
        catch
        {
          //ToDo: catch exceptions when setting up convertFileSystemToGraphPersistence
        }
      }
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken(1, convertFileSystemToGraphPersistence, cancellationToken);

      containers.Push(root);
      parentContainerVertex = new Vertex<IFSEntityAbstract>(new FSEntityDirectory(root));
      // Create a vertex for the root
      //Vertex<IFSEntityAbstract> rootDirectoryVertex = new Vertex<IFSEntityAbstract>(new FSEntityDirectory(root));
      containerVerticesStack.Push(parentContainerVertex);
      convertFileSystemToGraphResult.GraphAsIList.Vertices.Add(parentContainerVertex);
      // No Edge for root
      // If the convertFileSystemToGraphPersistence argument is not null, persist the root directory
      if (convertFileSystemToGraphPersistence != null)
      {
        // ToDo: if writing to an ORM, there needs to be a indicator that this is a create operation
        // convertFileSystemToGraphPersistence.PersistenceInsertData.DList = new List<string>() { root };
        try
        {
          convertFileSystemToGraphPersistence.PersistenceInsertResults = convertFileSystemToGraphPersistence.PersistenceInsert(convertFileSystemToGraphPersistence.PersistenceInsertData, convertFileSystemToGraphPersistence.PersistenceSetupResults);
        }
        catch
        {
          //ToDo: catch exceptions when writing out data to convertFileSystemToGraphPersistence
        }
        // Did the insert fail
        if (!convertFileSystemToGraphPersistence.PersistenceInsertResults.Success)
        {
          // ToDo: figure out how to handle a failed convertFileSystemToGraphPersistence insert
        }

      }
      // go down all the containers, first get the list of subdirectories, then the list of files, then hash the files
      // dirs are done in the order that they are returned by Directory.GetDirectories(currentDir)
      while (containers.Count > 0)
      {
        currentContainer = containers.Pop();
        currentContainerVertex = containerVerticesStack.Pop();
        convertFileSystemToGraphResult.GraphAsIList.Vertices.Add(currentContainerVertex);
        convertFileSystemToGraphResult.GraphAsIList.Edges.Add(new Edge<IFSEntityAbstract>(parentContainerVertex, currentContainerVertex));

        try
        {
          // Handle directories and archiveFiles differently
          switch (currentContainerVertex.Obj)
          {
            case FSEntityDirectory directory:
            {
              (currentContainerVertex.Obj as FSEntityDirectory).DirectoryInfo = new DirectoryInfo(currentContainer);
              // Once the DirectoryInfo property is populated, no need to keep path
              currentContainerVertex.Obj.Path = string.Empty;
              break;
            }
            case FSEntityArchiveFile archive:
            {
              // The FileInfo has already been populated and the Path set to string.Empty
              break;
            }
            default:
            {
              throw new Exception(string.Format(CultureInfo.CurrentCulture, StringConstants.InvalidTypeInSwitchExceptionMessage, currentContainerVertex.Obj));
            }
          }
        }
        catch (Exception e) when (e is SecurityException || e is ArgumentException || e is PathTooLongException)
        {
          // Store this exception on the currentFSEntityDirectory and accumulate the exception as part of the Result and Progress
          currentContainerVertex.Obj.Exception = e;
          // Add this exception to the results and progress
          convertFileSystemToGraphResult.AcceptableExceptions.Add(e);
          if (convertFileSystemToGraphProgress != null)
          {
            convertFileSystemToGraphProgress.AcceptableExceptions.Add(e);
          }
        }

        CheckAndHandleCancellationToken(2, convertFileSystemToGraphPersistence, cancellationToken);

        // ToDo: getting the list of dirs, and the list of files, should be done in parallel. As soon as each has completed, populate FSEntities by path
        string[] subContainers = Array.Empty<string>();
        string[] files = Array.Empty<string>();
        try
        {
          switch (currentContainerVertex.Obj)
          {
            case FSEntityDirectory directory:
            {

              subContainers = Directory.GetDirectories(currentContainer);
              break;
            }
            case FSEntityArchiveFile archive:
            {
              // ToDo: call an async task that returns an IEnumerable<IFSEntitiesAbstract>, and opens the archive file to produce that IEnumerable
              break;
            }
            default:
            {
              throw new Exception(string.Format(CultureInfo.CurrentCulture, StringConstants.InvalidTypeInSwitchExceptionMessage, currentContainerVertex.Obj));
            }
          }
        }
        catch (Exception e) when (e is UnauthorizedAccessException || e is DirectoryNotFoundException)
        {
          // Thrown if we do not have discovery permission on the directory.
          // Thrown if another process has deleted the directory after we retrieved its name.
          currentContainerVertex.Obj.Exception = e;
          // Add this exception to the results and progress
          convertFileSystemToGraphResult.AcceptableExceptions.Add(e);
          if (convertFileSystemToGraphProgress != null)
          {
            convertFileSystemToGraphProgress.AcceptableExceptions.Add(e);
          }
          // ToDo: The reason paralllelism is needed.  An exception here means that the files are not even looked for
          continue;
        }
        // update the results
        // create entities, vertices, and edges for each subContainer, populated with path but no dirinfo, and put into results
        foreach (var sd in subContainers)
        {
          //Vertex<IFSEntityAbstract> pVertex = new Vertex<IFSEntityAbstract>(new FSEntityDirectory(sd));
          //convertFileSystemToGraphResult.GraphAsIList.Vertices.Add(pVertex);
          //Edge<IFSEntityAbstract> pEdge = new Edge<IFSEntityAbstract>(currentContainerVertex, pVertex);
          //convertFileSystemToGraphResult.GraphAsIList.Edges.Add(pEdge);
        }
        // Update the Progress
        if (convertFileSystemToGraphProgress != null)
        {
          convertFileSystemToGraphProgress.NumberOfDirectories += subContainers.Length;
        }
        // check CancellationToken to see if this task is cancelled
        CheckAndHandleCancellationToken(3, convertFileSystemToGraphPersistence, cancellationToken);

        // ToDo: The first of the two parallel tasks end here

        // ToDo: second part of the two parallel tasks starts here.
        // analyze the files in this subdirectories
        try
        {
          files = Directory.GetFiles(currentContainer);
        }
        catch (Exception e) when (e is UnauthorizedAccessException || e is IOException)
        {
          // Thrown if we do not have discovery permission on the directory.
          // Thrown for a generic IO exception
          // Store this exception on the currentFSEntityDirectory and accumulate the exception as part of the Result and Progress
          currentContainerVertex.Obj.Exception = e;
          // Add this exception to the results
          convertFileSystemToGraphResult.AcceptableExceptions.Add(e);
          convertFileSystemToGraphProgress?.AcceptableExceptions.Add(e);
          continue;
        }

        // create entities and vertexs for each file, populated with path but no dirinfo
        // create entities, vertices, and edges for each subdir, populated with path but no FileInfo or hash, and put into results
        //foreach (var f in files)
        //{
        //  FSEntityFile fEntity = new FSEntityFile(f);
        //  Vertex<IFSEntityAbstract> fVertex = new Vertex<IFSEntityAbstract>(fEntity);
        //  convertFileSystemToGraphResult.GraphAsIList.Vertices.Add(fVertex);
        //  Edge<IFSEntityAbstract> pEdge = new Edge<IFSEntityAbstract>(currentContainerVertex, fVertex);
        //  convertFileSystemToGraphResult.GraphAsIList.Edges.Add(pEdge);
        //  // If the convertFileSystemToGraphPersistence argument is not null, persist the vertex and edge for this file
        //  if (convertFileSystemToGraphPersistence != null)
        //  {
        //    // ToDo: if writing to an ORM, there needs to be a indicator that this is a create operation
        //    //convertFileSystemToGraphPersistence.PersistenceInsertData.DList = new List<string>(subDirs);
        //    try
        //    {
        //      convertFileSystemToGraphPersistence.PersistenceInsertResults = convertFileSystemToGraphPersistence.PersistenceInsert(convertFileSystemToGraphPersistence.PersistenceInsertData, convertFileSystemToGraphPersistence.PersistenceSetupResults);
        //    }
        //    catch
        //    {
        //      //ToDo: catch exceptions when writing out data to convertFileSystemToGraphPersistence
        //    }
        //    // Did the insert fail
        //    if (!convertFileSystemToGraphPersistence.PersistenceInsertResults.Success)
        //    {
        //      // ToDo: figure out how to handle a failed convertFileSystemToGraphPersistence insert
        //    }

        //  }
        //}

        // check CancellationToken to see if this task is cancelled
        CheckAndHandleCancellationToken(4, convertFileSystemToGraphPersistence, cancellationToken);

        // update the results
        if (convertFileSystemToGraphProgress != null) { convertFileSystemToGraphProgress.NumberOfFiles += files.Length; }
        // Exception handling gets tricky. files is an array of path strings
        //  each has to be FileIO opened, information about each file extracted, and the file read and hashed
        //  This should be done with async tasks.
        //  when all of the files have been processed, only then should we try to update the database.

        // ToDo Beginning  of code block that needs paging/throtling
        // Get FileInfo and Hash Files here. Create as many tasks and FileInfoEx containers as there are files
        List<Task<IFSEntityFile>> taskList = new List<Task<IFSEntityFile>>();
        foreach (var f in files)
        {
          taskList.Add(PopulateFSEntityFileAsync(f, asyncFileReadBlockSize, cancellationToken));
        }
        // wait for all to finish
        await Task.WhenAll(taskList).ConfigureAwait(false);
        CheckAndHandleCancellationToken(5, convertFileSystemToGraphPersistence, cancellationToken);
        // ToDo End of code block that needs paging/throtling

        // here, get the information from the tasklist needed to populate the ConvertFileSystemToGraphAsyncTask.GraphAsList
        foreach (var task in taskList)
        {
          // Create a vertex from the Result of the task
          // and regardless of any exception, add this Vertex to the Vertices, in order that a record of this file be kept
          Vertex<IFSEntityAbstract> vertex = new Vertex<IFSEntityAbstract>(task.Result);
          convertFileSystemToGraphResult.GraphAsIList.Vertices.Add(vertex);
          // Create an Edge between this Vertex and the curent directory Vertex, and add this Edge to the Edges
          Edge<IFSEntityAbstract> edge = new Edge<IFSEntityAbstract>(currentContainerVertex, vertex);
          convertFileSystemToGraphResult.GraphAsIList.Edges.Add(edge);
          // append the exception from each task, if it exist, to the convertFileSystemToGraphResults and the convertFileSystemToGraphProgress
          if (task.Result.Exception != null)
          {
            convertFileSystemToGraphResult.AcceptableExceptions.Add(task.Result.Exception);
            convertFileSystemToGraphProgress?.AcceptableExceptions.Add(task.Result.Exception);
          }
          // update the Progress
          if (convertFileSystemToGraphProgress != null)
          {
            if (task.Result.FileInfo.Length > convertFileSystemToGraphProgress.LargestFile)
            {
              convertFileSystemToGraphProgress.LargestFile = task.Result.FileInfo.Length;
            }
          }
        }
        CheckAndHandleCancellationToken(6, convertFileSystemToGraphPersistence, cancellationToken);

        parentContainerVertex = currentContainerVertex;
        // Push the subdirectories onto the stack for traversal.
        foreach (string str in subContainers)
        {
          // ToDo: Get DirectoryInfo for each directory
          // ToDo: only push if there is no exception
          // ToDo: Insert the Node and Edge information about all directories into the DB
          // ToDo: update the DirectoryInfoEx in subDirs with the nodeID for each subdirectories as returned by the insert
          containers.Push(str);
          //IFSEntityAbstract fSEntityDirectory = new FSEntityDirectory(str);
          //Vertex<IFSEntityAbstract> vertexDirectory = new Vertex<IFSEntityAbstract>(fSEntityDirectory);
          containerVerticesStack.Push(new Vertex<IFSEntityAbstract>(new FSEntityDirectory(str)));
        }
      }
      // The analysis is complete, update progress
      if (convertFileSystemToGraphProgress != null)
      {
        convertFileSystemToGraphProgress.Completed = true;
        convertFileSystemToGraphProgress.PercentCompleted = 100;
      }
      // Log.Debug($"finished ConvertFileSystemToGraphAsyncTask");
      // TearDown the convertFileSystemToGraphPersistence mechanism
      convertFileSystemToGraphResult.Success = true;
      return convertFileSystemToGraphResult;
    }



    //
    // Summary:
    //     Initializes a new instance of the FSEntityFile class, which wraps and enhances a FileInfo instance with the file's hash.
    //
    // Parameters:
    //   path:
    //     The fully qualified name of the file, or the relative file name. Do not end
    //     the path with the directory separator character.
    //
    //   blocksize:
    //     ToDo: Documentation.
    //
    //   cancellationToken:
    //     The fully qualified name of the file, or the relative file name. Do not end
    //     the path with the directory separator character.
    //
    // Exceptions:
    //   T:System.ArgumentNullException:
    //     fileName is null.
    //
    //   T:System.Security.SecurityException:
    //     The caller does not have the required permission.
    //
    //   T:System.ArgumentException:
    //     The file name is empty, contains only white spaces, or contains invalid characters.
    //
    //   T:System.UnauthorizedAccessException:
    //     Access to fileName is denied.
    //
    //   T:System.IO.PathTooLongException:
    //     The specified path, file name, or both exceed the system-defined maximum length.
    //     For example, on Windows-based platforms, paths must be less than 248 characters,
    //     and file names must be less than 260 characters.
    //
    //   T:System.NotSupportedException:
    //     fileName contains a colon (:) in the middle of the string.

    public static async Task<IFSEntityFile> PopulateFSEntityFileAsync(string path, int blocksize, CancellationToken cancellationToken)
    {
      FSEntityFile fSEntityFile = new FSEntityFile(path);

      try
      {
        fSEntityFile.FileInfo = new FileInfo(path);
      }
      catch (Exception e) when (e is System.ArgumentNullException || e is System.Security.SecurityException || e is System.ArgumentException || e is System.UnauthorizedAccessException || e is System.IO.PathTooLongException || e is System.NotSupportedException)
      {
        // Thrown if path is null.
        // Thrown if there is a general security exception.
        // Thrown if thepath has illegal characters in the string
        // Add this exception to the results
        fSEntityFile.Exception = e;
        //Keep the original Path property value, do not null it out if there was an exception
        return fSEntityFile;
      }
      // With FileInfo populated, no need to keep the Path property populated
      fSEntityFile.Path = "";

      if (cancellationToken != null)
      {
        if (cancellationToken.IsCancellationRequested)
        {
          // Log.Debug($"in PopulateFSEntityFileAsync: Cancellation requested (1st checkpoint)");
          cancellationToken.ThrowIfCancellationRequested();
        }
      }

      try
      {
        // read all bytes and generate the hash for the file
        using (var stream = new FileStream(fSEntityFile.FileInfo.FullName, FileMode.Open, FileAccess.Read, FileShare.Read, blocksize, true)) // true means use IO async operations
        {
          // ToDo: move the instance of the md5 hasher out of the task, but ensure the implementation of the instance is thread-safe and can be reused
          // ToDo: The MD5 hasher found in the AnalyzeDisk properties cannot be reused after the call to TransformFinalBlock
          // ToDo: The MD5Cng implementation is not available on netstandard2.0
          using (var md5 = System.Security.Cryptography.MD5.Create())
          {
            byte[] buffer = new byte[blocksize];
            int bytesRead;
            do
            {
              bytesRead = await stream.ReadAsync(buffer, 0, blocksize).ConfigureAwait(false);
              if (cancellationToken != null)
              {
                if (cancellationToken.IsCancellationRequested)
                {
                  // Log.Debug($"in PopulateFSEntityFileAsync: Cancellation requested (2nd checkpoint)");
                  // dispose of the hasher
                  md5.Dispose();
                  cancellationToken.ThrowIfCancellationRequested();
                }

              }              if (bytesRead > 0)
              {
                md5.TransformBlock(buffer, 0, bytesRead, null, 0);
                if (cancellationToken != null)
                {
                  if (cancellationToken.IsCancellationRequested)
                  {
                    // Log.Debug($"in PopulateFSEntityFileAsync: Cancellation requested (3rd checkpoint)");
                    // dispose of the hasher
                    md5.Dispose();
                    cancellationToken.ThrowIfCancellationRequested();
                  } 
                }
              }
            } while (bytesRead > 0);

            md5.TransformFinalBlock(buffer, 0, 0);
            fSEntityFile.Hash = BitConverter.ToString(md5.Hash).Replace("-", string.Empty).ToUpperInvariant();
          }
        }
      }
      catch (Exception e) when (e is IOException || e is System.Security.SecurityException || e is UnauthorizedAccessException)
      {
        fSEntityFile.Exception = e;
      }
      return fSEntityFile;
    }

  }
}



/*

    //  This is an example of the code that creates a "longRunningTasks" that executes the actual async task
    public async Task<ConvertFileSystemToGraphResult> CallConvertFileSystemToGraphAsyncTask()
    {

      // ToDo: If on *nix ignore driveLetters and just use / as root. Base the decision on Runtime?
      // Ensure this PartitionFileSystem has non-null and non-empty drive letters
      if (DriveLetters == null) { throw new AggregateException(StringConstants.PartitionFileSystemHasNullDriveLettersExceptionMessage); }
      if (!DriveLetters.Any()) { throw new AggregateException(StringConstants.PartitionFileSystemHasEmptyDriveLettersExceptionMessage); }

      //Log.Debug("in Task<ConvertFileSystemToGraphResult> ConvertFileSystemToGraphAsyncTask 1");

      // Get the BaseServicesData and diskAnalysisServicesData instances that were injected into the DI container
      //var baseServicesData = HostContext.TryResolve<BaseServicesData>();
      //var diskAnalysisServicesData = HostContext.TryResolve<DiskAnalysisServicesData>();

      // Setup the instance. Use Configuration Data if the request payload is null
      //var blockSize = request.ConvertFileSystemToGraphAsyncTaskRequestPayload.AsyncFileReadBlockSize >= 0 ? request.ConvertFileSystemToGraphAsyncTaskRequestPayload.AsyncFileReadBlockSize : diskAnalysisServicesData.ConfigurationData.BlockSize;
      var blockSize = 4096;
      var transferFileSystemStructure = new TransferFileSystemStructure(Log.Logger, blockSize);

      Func<Char, ConvertFileSystemToGraphResult> TransferFileSystemStructureToDBInternal = new Func<Char, ConvertFileSystemToGraphResult>((root) =>
      {
      }
      );
      // Define the lambda that describes the FileSystemAnalysis task
      var task = new Task<ConvertFileSystemToGraphResult>(() =>
      {
        this.ConvertFileSystemToGraphAsyncTask(
            request.ConvertFileSystemToGraphAsyncTaskRequestPayload.Root, blockSize
             convertFileSystemToGraphProgress,
            cancellationToken,
            persistence
        ).ConfigureAwait(false);
      });

      // Create self's Philote for self's LongRunningTaskInfo
      // Philote<LongRunningTaskInfo> longRunningTaskPhilote = new Philote<LongRunningTaskInfo>(new Id<LongRunningTaskInfo>(Guid.NewGuid(), new List<>(), new IList<ITimeBlock);
      // Create LongRunningTaskInfo
      //LongRunningTaskInfo longRunningTaskInfo = new LongRunningTaskInfo(longRunningTaskID, task, cancellationTokenSource);
      // Record this task (plus additional information about it) in the longRunningTasks dictionary in the BaseServicesData found in the Container
      //baseServicesData.LongRunningTasks.Add(longRunningTaskID, longRunningTaskInfo);
      // record the TaskID and task info into the LookupDiskDriveAnalysisResultsCOD
      //diskAnalysisServicesData.LookupFileSystemAnalysisResultsCOD.Add(longRunningTaskID, longRunningTaskInfo);
      //diskAnalysisServicesData.ConvertFileSystemToGraphAsyncTaskResultsCOD.Add(longRunningTaskID, transferFileSystemStructureToPersistenceResult);
      //diskAnalysisServicesData.ConvertFileSystemToGraphAsyncTaskProgressCOD.Add(longRunningTaskID, convertFileSystemToGraphProgress);

      return result;
    }

  //public FileSystemAnalysis(ILog log, int asyncFileReadBlockSize, MD5 mD5) {
  public FileSystemAnalysis(ILogger logger, int asyncFileReadBlockSize)
  {
    Logger = logger ?? throw new ArgumentNullException(nameof(logger));
    // ToDo: make the exception message a constant localizable string)
    AsyncFileReadBlocksize = (asyncFileReadBlockSize >= 0) ? asyncFileReadBlockSize : throw new ArgumentOutOfRangeException($"asyncFileReadBlockSize must be greater than 0, received {asyncFileReadBlockSize}");
    // MD5=mD5??throw new ArgumentNullException(nameof(mD5));
  }
  /*  Move this stuff to teh Expression for the Action that will validate the DB
   *  The block below is somewhat out of date, the structures carry two, 
   *  separate GUIDs for DB id and in-memory id
  if (DBFetch==null) {
      diskInfoEx.DiskIdentityId=0;
      diskInfoEx.DiskGuid=Guid.NewGuid();
      // Log.Debug($"in PopulateDiskInfoExs: awaiting PopulatePartitionInfoExs,  diskInfoEx = {diskInfoEx}");
      await PopulatePartitionInfoExs(cRUD, diskInfoEx);
      // Log.Debug($"in PopulateDiskInfoExs: PopulatePartitionInfoExs has completed,  diskInfoEx = {diskInfoEx}");
  } else {
      // Todo: see if the DiskDriveMaker and SerialNumber already exist in the DB
      // async (cRUD, diskInfoEx) => { await Task.Yield(); }
      // Task< DiskDriveInfoEx> t = await DBFetch.Invoke(cRUD, diskInfoEx);
      // diskInfoEx = await DBFetch.Invoke(cRUD, diskInfoEx);
      if (false) {
          // already exist in DB, get ID and GUID from DB
          diskInfoEx.DiskIdentityId=0; //ToDo: replace with SQL fetch
          diskInfoEx.DiskGuid=Guid.NewGuid(); //ToDo: replace with SQL fetch
          diskInfoEx.PartitionInfoExs=new List<PartitionInfoEx>(); //ToDo: replace with SQL fetch
      }
  }
          //ToDo: If cRUD is replace, update or delete
          // Todo: see if the DiskDriveMaker and SerialNumber already exist in the DB
          //if (false)
          //{
          //  // already exist in DB, get ID and GUID from DB
          //  diskInfoEx.DiskDriveDBIdentityId = 0; //ToDo: replace with SQL fetch
          //  diskInfoEx.DiskDriveGuid = Guid.NewGuid(); //ToDo: replace with SQL fetch
          //  diskInfoEx.PartitionInfoExs = new List<PartitionInfoEx>(); //ToDo: replace with SQL fetch
          //}
          //else
          //{
          //  diskInfoEx.DiskDriveDBIdentityId = 0;
          //  diskInfoEx.DiskDriveGuid = Guid.NewGuid();
          //}

                          // ToDo: depending on cRUD, do different things with the list
              // if cRUD is Create
              // make a partition list for every partition on the disk hw
              // ToDo: starting with the assumption there is only one partition, and only one drive associated E:
              foreach (var p in hwPartitions) {
                  partitionInfoEx.PartitionIdentityId=0;
                  partitionInfoEx.PartitionGuid=Guid.NewGuid();
                  partitionInfoEx.DriveLetters=p.DriveLetters;
                  partitionInfoExs.Add(partitionInfoEx);
              }


  public async Task ConvertFileSystemToGraphAsyncTask(string root, IConvertFileSystemToGraphResult ConvertFileSystemToGraphAsyncTaskResults, IConvertFileSystemToGraphProgress ConvertFileSystemToGraphAsyncTaskProgress, CancellationToken cancellationToken, IPersistenceAbstract persistence)
  {
    // Log.Debug($"starting ConvertFileSystemToGraphAsyncTask: root = {root}");





  #region Properties
  #region Properties:class logger
  //public ILog Log;
  //private static ILogger Logger;
  #endregion
  #region Properties:AsyncFileReadBlocksize
  //int AsyncFileReadBlocksize { get; set; }
  #endregion
  // the hasher
  // ToDo: Find a MD5 algorithm that is thread-safe and can be reused; the one below throws a cryptographic exception when called a second time (after transformFinalBlock)
  // ToDo: Make this into a list of hash functions that can be used on a filestream, and make it possible for any method in this class to select one from the list. Allows the user to select the hash function to be used.
  //MD5= System.Security.Cryptography.MD5.Create();
  #region Properties:Hasher MD5
  //System.Security.Cryptography.MD5 MD5 { get; set; }
  #endregion
  #endregion

  #region Disposable
  // ToDo: Dispose of any hashers that were created

  #endregion
}

}
// The ideas and code for ByteArrayHasher came from
// The ideas and some code for an async version of "read file and hash it" came from https://stackoverflow.com/questions/49858310/how-to-async-md5-calculate-c-sharp
// The ideas and some code for a parallel version to process files came from https://docs.microsoft.com/en-us/dotnet/standard/parallel-programming/how-to-iterate-file-directories-with-the-parallel-class


/* public class ByteArrayHasher
{
  public ByteArrayHasher(HashAlgorithm hashAlgorithm)
  {
    HashAlgorithm = hashAlgorithm;
    System.Security.Cryptography.MD5Cng hasherMD5;
    //Force.Crc32.Crc32Algorithm hasherCRC32;
    switch (hashAlgorithm)
    {
      case HashAlgorithm.CRC32:
      {
        //Force.Crc32.Crc32Algorithm hasherCRC32 = new Force.Crc32.Crc32Algorithm();
        throw new NotImplementedException();
        break;
      }
      case HashAlgorithm.MD5:
      {
        hasherMD5 = new System.Security.Cryptography.MD5Cng();
        break;
      }
      default:
      {
        throw new ArgumentException();
      }
    }
    // Create the HashFunction that can be called to incrementally 
    Func < HashFunction = new Func<byte[], string>(ba)    {
    string hashResult;
    switch (HashAlgorithm)
    {
      case HashAlgorithm.CRC32:
      {
        //hashResult = BitConverter.ToUInt32(hasherCRC32.ComputeHash(ba), 0).ToString("X8");
        break;
      }
      case HashAlgorithm.MD5:
      {
        hashResult = Convert.ToBase64String(hasherMD5.ComputeHash(ba));
        break;
      }
      default: { throw new ArgumentException(); }
    }
    return hashResult;
  }
  public HashAlgorithm HashAlgorithm;
  public Func<byte[], string> HashFunction;
}
*/

