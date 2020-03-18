using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IConvertFileSystemToGraphProgress
  {
    bool Completed { get; set; }
    int DeepestDirectoryTree { get; set; }
    IList<Exception> AcceptableExceptions { get; }
    long LargestFile { get; set; }
    int NumberOfDirectories { get; set; }
    int NumberOfFiles { get; set; }
    int PercentCompleted { get; set; }
  }
}
