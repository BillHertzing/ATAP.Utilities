using System.Collections.Generic;

namespace ATAP.Utilities.GraphDataStructures
{
  public interface IGraphAsIList<T>
  {
    IList<IEdge<T>> Edges { get; }
    IList<IVertex<T>> Vertices { get; }
  }
}
