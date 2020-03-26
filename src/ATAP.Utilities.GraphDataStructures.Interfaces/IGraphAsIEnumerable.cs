using System.Collections.Generic;

namespace ATAP.Utilities.GraphDataStructures
{
  public interface IGraphAsIEnumerable<T>
  {
    IEnumerable<IEdge<T>> Edges { get; }
    IEnumerable<IVertex<T>> Vertices { get; }
  }
}
