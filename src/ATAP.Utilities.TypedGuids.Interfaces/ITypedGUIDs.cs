using System;

namespace ATAP.Utilities.TypedGuids {
  public interface IIdAsStruct<T> { }
  public interface IStronglyTypedId<TValue> where TValue : notnull {
    TValue Value { get; init; }
  }
  public interface IGuidStronglyTypedId : IStronglyTypedId<Guid> {  }
  public interface IIntStronglyTypedId : IStronglyTypedId<int> {  }
}
