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
    }

    public bool Success { get; set; }
    public FSEntityAdjacencyGraph FSEntityAdjacencyGraph { get; private set; }
    public IList<Exception> AcceptableExceptions { get; private set; }
    public AggregateException? AggregateException { get; set; }
  }

}
