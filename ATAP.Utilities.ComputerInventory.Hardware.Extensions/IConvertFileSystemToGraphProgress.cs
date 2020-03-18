using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IConvertFileSystemToGraphProgress
  {
    bool Completed { get; set; }
    int DeepestDirectoryTree { get; set; }
    IList<Exception> AcceptableExceptions { get; set; }
    long LargestFile { get; set; }
    int NumberOfDirectories { get; set; }
    int NumberOfFiles { get; set; }
    bool PercentCompleted { get; set; }
  }
}
