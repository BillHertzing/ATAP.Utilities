using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Linq;
using System.Reflection;
using ATAP.Utilities.StronglyTypedId;
using Itenso.TimePeriod;

namespace ATAP.Utilities.Philote {


  public abstract record AbstractPhilote<TId, TValue> : IAbstractPhilote<TId, TValue> where TId : AbstractStronglyTypedId<TValue>, new() where TValue : notnull {

    public AbstractPhilote(TId iD = default, ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? additionalIds = default, IEnumerable<ITimeBlock>? timeBlocks = default) {
      if (iD != null) { Id = iD; }
      else {
        Id = (typeof(TValue)) switch {

          Type intType when typeof(TValue) == typeof(int) => new IntStronglyTypedId() { Value = new Random().Next() } as TId,
          // The following fails to work because Guid lacks a new()
          // Type GuidType when typeof(TValue) == typeof(Guid) => Activator.CreateInstance(typeof(Guid), new object[] { Guid.NewGuid() }) as TId,
          // The two following fails because there is no way to simply cast from the AbstractStronglyTypedId to the concrete TId
          // Type intType when typeof(TValue) == typeof(int) => (TId)(object)(AbstractStronglyTypedId<int>)new IntStronglyTypedId() { Value = new Random().Next() },
          // Type GuidType when typeof(TValue) == typeof(Guid) => (TId)(object)(AbstractStronglyTypedId<Guid>)new GuidStronglyTypedId(),
          // Attribution: [Activator.CreateInstance Alternative](https://trenki2.github.io/blog/2018/12/28/activator-createinstance-faster-alternative/) by Trenki
          Type GuidType when typeof(TValue) == typeof(Guid) => (TId)InstanceFactory.CreateInstance(typeof(TId)),
          // ToDo: replace with new custom exception and localization of exception message
          _ => throw new Exception(FormattableString.Invariant($"Invalid TValue type {typeof(TValue)}")),

        };
      }
      // Attribution [Linq ToDictionary will not implicitly convert class to interface](https://stackoverflow.com/questions/25136049/linq-todictionary-will-not-implicitly-convert-class-to-interface) Educational but ultimately fails
      // The ToDictionary extension method available in LINQ for generic Dictionaries is NOT availabe for ConcurrentDictionaries, the following won't work...
      //  additionalIds.ToDictionary(kvp => kvp.Key, kvp => (IAbstractStronglyTypedId<TValue>) kvp.Value)
      // A this is a concurrent operation we will need to put a semaphore around the argument passed in
      // attribution [How do you convert a dictionary to a ConcurrentDictionary?](https://stackoverflow.com/questions/27063889/how-do-you-convert-a-dictionary-to-a-concurrentdictionary) from a comment on a question, contributed by Panagiotis Kanavos
      // we have to convert the parameter's value to a cast to a less derived interface

      if (additionalIds != default) {
        // ToDo : add write semaphore around the parameter before enumerating the Dictionary
        AdditionalIds = new ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>(additionalIds.Select(kvp => new KeyValuePair<string, IAbstractStronglyTypedId<TValue>>(kvp.Key, (IAbstractStronglyTypedId<TValue>)kvp.Value)));
      }
      else {
        AdditionalIds = new ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>();
      }
      if (timeBlocks != null) { TimeBlocks = timeBlocks; }
    }

    public TId Id { get; init; }
    public ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? AdditionalIds { get; init; }
    public IEnumerable<ITimeBlock>? TimeBlocks { get; init; }
  }


    public record IntPhilote<TId> : AbstractPhilote<TId, int> , IIntPhilote<TId>  where TId : IntStronglyTypedId, new(){
    /// <summary>
    /// Parameterless Constructor, needed by Deserialization assemblies and ReadFrom Persistence assemblies
    /// /// ToDo: List other c# /Net constructs that require a parameterless constructor
    /// </summary>
    public IntPhilote() : base() { }
    /// <summary>
    ///
    /// </summary>
    /// <param name="iD"></param>
    public IntPhilote(TId iD) : base(iD) { }

    public  IntPhilote(TId iD = default, ConcurrentDictionary<string, IAbstractStronglyTypedId<int>>? additionalIds = default, IEnumerable<ITimeBlock>? timeBlocks = default) :base(iD,additionalIds,timeBlocks){ }

    /// <summary>
    /// ToDo: Might need a better ToString Converter, and/or Serializer.Shim specific assembly
    /// </summary>
    /// <returns></returns>
    public override string ToString() => base.ToString();
  }

  public record GuidPhilote<TId> : AbstractPhilote<TId, Guid> , IGuidPhilote<TId>  where TId : GuidStronglyTypedId, new(){
    /// <summary>
    ///
    /// </summary>
    public GuidPhilote() : base() { }
    /// <summary>
    ///
    /// </summary>
    /// <param name="iD"></param>
    public GuidPhilote(TId iD) : base(iD) { }
    public  GuidPhilote(TId iD = default, ConcurrentDictionary<string, IAbstractStronglyTypedId<Guid>>? additionalIds = default, IEnumerable<ITimeBlock>? timeBlocks = default) :base(iD,additionalIds,timeBlocks){ }

    /// <summary>
    /// ToDo: Might need a better ToString Converter, and/or Serializer.Shim specific assembly
    /// </summary>
    /// <returns></returns>
    public override string ToString() => base.ToString();
  }

  // public IIdAsStruct<T> ID { get; private set; }
  // public IDictionary<string, IIdAsStruct<T>> AdditionalIDs { get; private set; }
  // //public IConcurrentObservableDictionary<string,IIdAsStruct<T>) SecondaryIDs { get; private set; }
  // public IEnumerable<ITimeBlock> TimeBlocks { get; private set; }
  // }
}
