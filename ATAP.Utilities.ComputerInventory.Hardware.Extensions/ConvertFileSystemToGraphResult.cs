using ATAP.Utilities.GraphDataStructures;
using System;
using System.Collections.Generic;


namespace ATAP.Utilities.ComputerInventory.Hardware
{

  public class ConvertFileSystemToGraphResult : IConvertFileSystemToGraphResult
  {
    public ConvertFileSystemToGraphResult() : this(false, new GraphAsIList<IFSEntityAbstract>(), new List<Exception>(), null)
    {
    }

    public ConvertFileSystemToGraphResult(bool success, IGraphAsIList<IFSEntityAbstract> graphAsIList, IList<Exception> acceptableExceptions, AggregateException? aggregateException)
    {
      Success = success;
      GraphAsIList = graphAsIList;
      AcceptableExceptions = acceptableExceptions;
      AggregateException = aggregateException;
    }

    public bool Success { get; set; }
    public IGraphAsIList<IFSEntityAbstract> GraphAsIList { get; private set; }
    public IList<Exception> AcceptableExceptions { get; private set; }
    public AggregateException? AggregateException { get; set; }
  }

}
