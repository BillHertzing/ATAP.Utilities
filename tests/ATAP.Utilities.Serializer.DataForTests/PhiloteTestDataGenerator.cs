using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedIds;
using ATAP.Utilities.Philote;

using Itenso.TimePeriod;

namespace ATAP.Utilities.Serializer.DataForTests
{

  #region classes that use a Philote, defined for test purposes

    public record GCommentId<TValue> : AbstractStronglyTypedId<TValue>, IAbstractStronglyTypedId<TValue> where TValue : notnull {
    public GCommentId() : base() { }
    public GCommentId(TValue value) : base(value) { }
  }
  public interface IGCommentPhilote<TValue> : IAbstractPhilote<GCommentId<TValue>, TValue> where TValue : notnull { }
  public record GCommentPhilote<TValue> : AbstractPhilote<GCommentId<TValue>, TValue>, IAbstractPhilote<GCommentId<TValue>, TValue>, IGCommentPhilote<TValue>
    where TValue : notnull {
    public GCommentPhilote(GCommentId<TValue> iD = default, ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? additionalIds = default, IEnumerable<ITimeBlock>? timeBlocks = default) : base(iD, additionalIds, timeBlocks) { }
  }

  public interface IGComment<TValue> where TValue : notnull {
    IEnumerable<string> GStatements { get; init; }
    IAbstractPhilote<GCommentId<TValue> ,TValue> Philote { get; init; }
  }

  public record GComment<TValue> : IGComment<TValue> where TValue : notnull {
    public GComment(IEnumerable<string> gStatements = default, IGCommentPhilote<TValue> philote = default) {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      Philote = philote == default ? new GCommentPhilote<TValue>() : philote;
    }
    public IEnumerable<string> GStatements { get; init; }
    public IAbstractPhilote<GCommentId<TValue> ,TValue> Philote { get; init; }
  }


  #endregion
  public class PhiloteIntegerTestData : ATAP.Utilities.Testing.Serialization.TestData<Philote<GComment<int>>>
  {
    public PhiloteIntegerTestData(Philote<GComment<int>> objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class PhiloteIntegerTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new PhiloteIntegerTestData[] { new PhiloteIntegerTestData(new Philote<GComment<int>>(), "{}" )};
      //yield return new PhiloteGenericTestData[] { new PhiloteGenericTestData(new Philote<object>(100, UnitsNet.Units.InformationUnit.Megabyte), "\"100 MB\"") };
      //yield return new PhiloteGenericTestData[] { new PhiloteGenericTestData(new Philote<object>(2, UnitsNet.Units.InformationUnit.Gigabyte), "\"2 GB\"") };
      //yield return new PhiloteGenericTestData[] { new PhiloteGenericTestData(new Philote<object>(200, UnitsNet.Units.InformationUnit.Gigabyte), "\"200 GB\"") };
      //yield return new PhiloteGenericTestData[] { new PhiloteGenericTestData(new Philote<object>(1, UnitsNet.Units.InformationUnit.Terabyte), "\"1 TB\"") };
      //yield return new PhiloteGenericTestData[] { new PhiloteGenericTestData(new Philote<object>(4, UnitsNet.Units.InformationUnit.Terabyte), "\"4 TB\"") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
