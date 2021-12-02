using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

using Itenso.TimePeriod;

namespace ATAP.Utilities.Serializer.DataForTests {

  #region classes that use a PhiloteRegion, defined for test purposes
  public interface IGCommentId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull { }

  public record GCommentId<TValue> : AbstractStronglyTypedId<TValue>, IGCommentId<TValue>  where TValue : notnull {
    public GCommentId() : base() { }
    public GCommentId(TValue value) : base(value) { }
  }
  // public interface IGCommentPhilote<TValue> : IAbstractPhilote<GCommentId<TValue>, TValue> where TValue : notnull { }

  // public record GCommentPhilote<TValue> : AbstractPhilote<GCommentId<TValue>, TValue>, IAbstractPhilote<GCommentId<TValue>, TValue>, IGCommentPhilote<TValue>
  //   where TValue : notnull {
  //   public GCommentPhilote(GCommentId<TValue> iD = default, ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? additionalIds = default, IEnumerable<ITimeBlock>? timeBlocks = default) : base(iD, additionalIds, timeBlocks) { }
  // }

  public interface IGComment<TValue> where TValue : notnull {
    IEnumerable<string> GStatements { get; init; }
    GCommentId<TValue> Id { get; init; }

  }

  public record GComment<TValue> : IGComment<TValue> where TValue : notnull {

    public GComment(IEnumerable<string> gStatements = default, GCommentId<TValue> id = default) {
      Id = id == default ? new GCommentId<TValue>() : id;
      GStatements = gStatements == default ? new List<string>() : gStatements;
    }
    public GComment() : this(new List<string>(), new GCommentId<TValue>(), null, null) { }
    public GComment(IEnumerable<string> gStatements) : this(gStatements, new GCommentId<TValue>(), null, null) { }
    //public GComment(IEnumerable<string> gStatements, GCommentId<TValue> iD ) : this(gStatements, iD, null, null) { }
    public GComment(IEnumerable<string> gStatements = default, GCommentId<TValue>? iD = default, ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? additionalIds = default, IEnumerable<ITimeBlock>? timeBlocks = default)  {
      // ToDo: Convert argument null check to c# V10 style
      if (gStatements == null) { throw new ArgumentNullException(nameof(gStatements)); }
      if (iD == null) { throw new ArgumentNullException(nameof(iD)); }
      GStatements = gStatements;
      Id = iD;
      AdditionalIds = additionalIds;
      TimeBlocks = timeBlocks;
    }

    #region Autoproperties
    public IEnumerable<string> GStatements { get; init; }
    #region Philote Autoproperties
    public GCommentId<TValue> Id { get; init; }
    ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? AdditionalIds { get; init; }
    IEnumerable<ITimeBlock>? TimeBlocks { get; init; }
    #endregion
    #endregion
  }
  #endregion

  #region test of the GComment<int>
  public class GCommentIntegerTestData : ATAP.Utilities.Testing.Serialization.TestData<GComment<int>> {
    public GCommentIntegerTestData(GComment<int> objTestData, string serializedTestData) : base(objTestData, serializedTestData) {
    }
  }

  public class GCommentIntegerTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> TestData() {
      yield return new GCommentIntegerTestData[] { new GCommentIntegerTestData(new GComment<int>(), "{\"GStatements\":[],\"Id\":\" \"}") };  // Random number or exception
      yield return new GCommentIntegerTestData[] { new GCommentIntegerTestData( new GComment<int>(new List<string>(),new GCommentId<int>(1234567)), "{\"GStatements\":[],\"Id\":\"1234567\"}") };
      //yield return new GCommentIntegerTestData[] { new GCommentIntegerTestData(new GComment<int>(null0), "{0}") };
      //yield return new GCommentIntegerTestData[] { new GCommentIntegerTestData(new GComment<int>(1), "{1}") };
      //yield return new GCommentIntegerTestData[] { new GCommentIntegerTestData(new GComment<int>(0, new ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>(), new List<ITimeBlock>() ), "{\"Id\":\"0\",\"AdditionalIds\":[],\"TimeBlocks\":[]}") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
  #endregion

  #region test of the GuidPhilote
  public class GCommentGuidTestData : ATAP.Utilities.Testing.Serialization.TestData<GComment<Guid>> {
    public GCommentGuidTestData(GComment<Guid> objTestData, string serializedTestData) : base(objTestData, serializedTestData) {
    }
  }

  public class GCommentGuidTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> TestData() {
      yield return new GCommentGuidTestData[] { new GCommentGuidTestData(new GComment<Guid>(), "{\"GStatements\":[],\"Id\":\" \"}") };  // Random number or exception
      yield return new GCommentGuidTestData[] { new GCommentGuidTestData(new GComment<Guid>(new List<string>(),new GCommentId<Guid>(Guid.Empty)), "{\"GStatements\":[],\"Id\":\"00000000-0000-0000-0000-000000000000\"}") };
      //yield return new GCommentGuidTestData[] { new GCommentGuidTestData(new GCommentId<Guid>(Guid.Empty, new ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>(), new List<ITimeBlock>() ), "{\"Id\":\"00000000-0000-0000-0000-000000000000\",\"AdditionalIds\":[],\"TimeBlocks\":[]}") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  #endregion
}
