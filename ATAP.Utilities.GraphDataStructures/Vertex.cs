
using System;

namespace ATAP.Utilities.GraphDataStructures
{


  public class Vertex<T> : IVertex<T>
  {
    public Vertex()
    {
    }

    public Vertex(T obj)
    {
      Obj = obj;
    }

    public T Obj { get; private set; }
  }

}
