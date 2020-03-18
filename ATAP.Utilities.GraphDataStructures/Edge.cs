using System;

namespace ATAP.Utilities.GraphDataStructures
{


  public class Edge<T> : IEdge<T>
  {
    public Edge()
    {
    }

    public Edge(Vertex<T> from, Vertex<T> to)
    {
      To = to ?? throw new ArgumentNullException(nameof(to));
      From = from ?? throw new ArgumentNullException(nameof(from));
    }
    public IVertex<T> From { get; private set; }
    public IVertex<T> To { get; private set; }
  }

}
