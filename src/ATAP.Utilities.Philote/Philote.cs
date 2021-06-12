using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Linq;
using System.Reflection;
using ATAP.Utilities.StronglyTypedIds;
using Itenso.TimePeriod;

namespace ATAP.Utilities.Philote {


  public abstract record AbstractPhilote<TId, TValue> : IAbstractPhilote<TId, TValue> where TId : AbstractStronglyTypedId<TValue>, new() where TValue : notnull {

    public AbstractPhilote(TId iD = default, ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? additionalIDs = default, IEnumerable<ITimeBlock>? timeBlocks = default) {
      if (iD != null) { ID = iD; }
      else {
        ID = (typeof(TValue)) switch {

          Type intType when typeof(TValue) == typeof(int) => new IntStronglyTypedId() { Value = new Random().Next() } as TId,
          // The following fails to work because Guid lacks a new()
          // Type GuidType when typeof(TValue) == typeof(Guid) => Activator.CreateInstance(typeof(Guid), new object[] { Guid.NewGuid() }) as TId,
          // The two following fails because there is no way to simply cast from the AbstractStronglyTypedId to the concrete TId
          // Type intType when typeof(TValue) == typeof(int) => (TId)(object)(AbstractStronglyTypedId<int>)new IntStronglyTypedId() { Value = new Random().Next() },
          // Type GuidType when typeof(TValue) == typeof(Guid) => (TId)(object)(AbstractStronglyTypedId<Guid>)new GuidStronglyTypedId(),
          // Attribution: [Activator.CreateInstance Alternative](https://trenki2.github.io/blog/2018/12/28/activator-createinstance-faster-alternative/) by Trenki
          Type GuidType when typeof(TValue) == typeof(Guid) => (TId) InstanceFactory.CreateInstance(typeof(TId)),
          // ToDo: replace with new custom exception and localization of exception message
          _ => throw new Exception(FormattableString.Invariant($"Invalid TValue type {typeof(TValue)}")),

        };
      }
      // Attribution [Linq ToDictionary will not implicitly convert class to interface](https://stackoverflow.com/questions/25136049/linq-todictionary-will-not-implicitly-convert-class-to-interface) Educational but ultimately fails
      // The ToDictionary extension method available in LINQ for generic Dictionaries is NOT availabe for ConcurrentDictionaries, the following won't work...
      //  additionalIDs.ToDictionary(kvp => kvp.Key, kvp => (IAbstractStronglyTypedId<TValue>) kvp.Value)
      // A this is a concurrent operation we will need to put a semaphore around the argument passed in
      // attribution [How do you convert a dictionary to a ConcurrentDictionary?](https://stackoverflow.com/questions/27063889/how-do-you-convert-a-dictionary-to-a-concurrentdictionary) from a comment on a question, contributed by Panagiotis Kanavos
      // we have to convert the parameter's value to a cast to a less derived interface

      if (additionalIDs != default) {
        // ToDo : add write semaphore around the parameter before enumerating the Dictionary
        AdditionalIDs = new ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>(additionalIDs.Select(kvp => new KeyValuePair<string, IAbstractStronglyTypedId<TValue>>(kvp.Key, (IAbstractStronglyTypedId<TValue>)kvp.Value)));
      }
      else {
        AdditionalIDs = new ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>();
      }
      TimeBlocks = timeBlocks != default ? timeBlocks : new List<ITimeBlock>();
    }

    public TId ID { get; init; }
    public ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? AdditionalIDs { get; init; }
    public IEnumerable<ITimeBlock>? TimeBlocks { get; init; }
  }

    // public IIdAsStruct<T> ID { get; private set; }
    // public IDictionary<string, IIdAsStruct<T>> AdditionalIDs { get; private set; }
    // //public IConcurrentObservableDictionary<string,IIdAsStruct<T>) SecondaryIDs { get; private set; }
    // public IEnumerable<ITimeBlock> TimeBlocks { get; private set; }
  // }
}
