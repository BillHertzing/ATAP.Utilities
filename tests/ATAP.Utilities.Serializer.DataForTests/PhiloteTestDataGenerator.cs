using System;
using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.Serializer.DataForTests;

public interface IGCommentId<TValue> : IAbstractStronglyTypedId<TValue>
  where TValue : notnull
{
}

public record GCommentId<TValue> : AbstractStronglyTypedId<TValue>, IGCommentId<TValue>
  where TValue : notnull
{
  public GCommentId()
  {
  }

  public GCommentId(TValue value)
    : base(value)
  {
  }
}

public interface IGComment<TValue>
  where TValue : notnull
{
  IEnumerable<string> GStatements { get; }

  GCommentId<TValue> Id { get; }
}

public sealed record GComment<TValue> : IGComment<TValue>
  where TValue : notnull
{
  public GComment(
    IEnumerable<string>? gStatements = default,
    GCommentId<TValue>? id = default)
  {
    GStatements = gStatements ?? Array.Empty<string>();
    Id = id ?? new GCommentId<TValue>();
  }

  public IEnumerable<string> GStatements { get; }

  public GCommentId<TValue> Id { get; }
}

public sealed class GCommentIntegerTestData : ATAP.Utilities.Testing.Serialization.TestData<GComment<int>>
{
  public GCommentIntegerTestData(GComment<int> objTestData, string serializedTestData)
    : base(objTestData, serializedTestData)
  {
  }
}

public sealed class GCommentIntegerTestDataGenerator : IEnumerable<object[]>
{
  public static IEnumerable<object[]> TestData()
  {
    yield return new object[]
    {
      new GCommentIntegerTestData(
        new GComment<int>(Array.Empty<string>(), new GCommentId<int>(1234567)),
        "{\"GStatements\":[],\"Id\":\"1234567\"}")
    };
  }

  public IEnumerator<object[]> GetEnumerator() => TestData().GetEnumerator();

  IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}

public sealed class GCommentGuidTestData : ATAP.Utilities.Testing.Serialization.TestData<GComment<Guid>>
{
  public GCommentGuidTestData(GComment<Guid> objTestData, string serializedTestData)
    : base(objTestData, serializedTestData)
  {
  }
}

public sealed class GCommentGuidTestDataGenerator : IEnumerable<object[]>
{
  public static IEnumerable<object[]> TestData()
  {
    yield return new object[]
    {
      new GCommentGuidTestData(
        new GComment<Guid>(Array.Empty<string>(), new GCommentId<Guid>(Guid.Empty)),
        "{\"GStatements\":[],\"Id\":\"00000000-0000-0000-0000-000000000000\"}")
    };
  }

  public IEnumerator<object[]> GetEnumerator() => TestData().GetEnumerator();

  IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}
