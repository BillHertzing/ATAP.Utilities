using QuickGraph;
using System;
using System.Collections.Generic;


namespace ATAP.Utilities.ComputerInventory.Hardware {

  public class ConvertFileSystemToGraphResult : IConvertFileSystemToGraphResult {
    public ConvertFileSystemToGraphResult() : this(false, new FSEntityAdjacencyGraph(), new List<Exception>(), null) {
    }

    public ConvertFileSystemToGraphResult(bool success, FSEntityAdjacencyGraph fSEntityAdjacencyGraph, IList<Exception> acceptableExceptions, AggregateException? aggregateException) {
      Success = success;
      FSEntityAdjacencyGraph = fSEntityAdjacencyGraph;
      AcceptableExceptions = acceptableExceptions;
      AggregateException = aggregateException;
      DeepestDirectoryTree = 0;
      LargestFile = 0;
      EarliestDirectoryCreationTime = DateTime.MaxValue;
      LatestDirectoryCreationTime = DateTime.MinValue;
      EarliestFileCreationTime = DateTime.MaxValue;
      LatestFileCreationTime = DateTime.MinValue;
      EarliestFileModificationTime = DateTime.MaxValue;
      LatestFileModificationTime = DateTime.MinValue;
    }

    public bool Success { get; set; }
    public FSEntityAdjacencyGraph FSEntityAdjacencyGraph { get; private set; }
    public int DeepestDirectoryTree { get; set; }
    public long LargestFile { get; set; }
    public DateTime EarliestDirectoryCreationTime { get; set; }
    public DateTime LatestDirectoryCreationTime { get; set; }
    public DateTime EarliestFileCreationTime { get; set; }
    public DateTime LatestFileCreationTime { get; set; }
    public DateTime EarliestFileModificationTime { get; set; }
    public DateTime LatestFileModificationTime { get; set; }
    public IList<Exception> AcceptableExceptions { get; private set; }
    public AggregateException? AggregateException { get; set; }

    public void UpdateWithDirectory(FSEntityDirectory vertex) {
      if (LatestDirectoryCreationTime < vertex.DirectoryInfo.CreationTimeUtc) { LatestDirectoryCreationTime = vertex.DirectoryInfo.CreationTimeUtc; }
      if (EarliestDirectoryCreationTime > vertex.DirectoryInfo.CreationTimeUtc) { EarliestDirectoryCreationTime = vertex.DirectoryInfo.CreationTimeUtc; }
    }
    public void UpdateWithFile(FSEntityFile vertex) {
      if (LatestFileCreationTime < vertex.FileInfo.CreationTimeUtc) { LatestFileCreationTime = vertex.FileInfo.CreationTimeUtc; }
      if (EarliestFileCreationTime > vertex.FileInfo.CreationTimeUtc) { EarliestFileCreationTime = vertex.FileInfo.CreationTimeUtc; }
      if (LatestFileModificationTime < vertex.FileInfo.LastWriteTimeUtc) { LatestFileModificationTime = vertex.FileInfo.LastWriteTimeUtc; }
      if (EarliestFileModificationTime > vertex.FileInfo.LastWriteTimeUtc) { EarliestFileModificationTime = vertex.FileInfo.LastWriteTimeUtc; }
      if (LargestFile < vertex.FileInfo.Length) { LargestFile = vertex.FileInfo.Length; }
    }
  }
}
