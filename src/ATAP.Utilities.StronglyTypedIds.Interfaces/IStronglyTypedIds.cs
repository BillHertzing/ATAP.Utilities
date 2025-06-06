using System;

namespace ATAP.Utilities.StronglyTypedId {
  // public interface IIdAsStruct<T> { } // Deprecated
  public interface IAbstractStronglyTypedId<TValue> where TValue : notnull {
    TValue Value { get; init; }
  }
  public interface IGuidStronglyTypedId : IAbstractStronglyTypedId<Guid> { }
  public interface IIntStronglyTypedId : IAbstractStronglyTypedId<int> { }

}
