
using System;
using System.Collections.Generic;


namespace ATAP.Utilities.ComputerInventory.Hardware
{

  public class ConvertFileSystemToGraphProgress : IConvertFileSystemToGraphProgress
  {
    public ConvertFileSystemToGraphProgress() : this(false, false, -1, -1, -1, -1, new List<Exception>()) { }

    public ConvertFileSystemToGraphProgress(bool percentCompleted, bool completed, int numberOfDirectories, int numberOfFiles, int deepestDirectoryTree, long largestFile, IList<Exception> acceptableExceptions)
    {
      PercentCompleted = percentCompleted;
      Completed = completed;
      NumberOfDirectories = numberOfDirectories;
      NumberOfFiles = numberOfFiles;
      DeepestDirectoryTree = deepestDirectoryTree;
      LargestFile = largestFile;
      AcceptableExceptions = acceptableExceptions ?? throw new ArgumentNullException(nameof(acceptableExceptions));
    }

    public bool PercentCompleted { get; set; }
    public bool Completed { get; set; }
    public int NumberOfDirectories { get; set; }
    public int NumberOfFiles { get; set; }
    public int DeepestDirectoryTree { get; set; }
    public long LargestFile { get; set; }
    public IList<Exception> AcceptableExceptions { get; set; }
  }

}
