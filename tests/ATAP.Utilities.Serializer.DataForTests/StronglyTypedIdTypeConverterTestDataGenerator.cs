using System;
using System.Collections;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedIds;

namespace ATAP.Utilities.Serializer.DataForTests
{
  public class StronglyTypedIdTypeConverterTestData<TValue> where TValue : notnull
  {
    public IAbstractStronglyTypedId<TValue> InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public StronglyTypedIdTypeConverterTestData()
    {
    }

    public StronglyTypedIdTypeConverterTestData(IAbstractStronglyTypedId<TValue> instanceTestData, string serializedTestData)
    {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }
/// <summary>
/// The generic test data generator, which produces a single test data object each time when enumerated
/// </summary>
/// <typeparam name="TValue">One of int, GUID, or string</typeparam>
  public class StronglyTypedIdTypeConverterTestDataGenerator<TValue>  : IEnumerable<object[]>  where TValue: notnull {
/// <summary>
/// Test Data in the format of `Declaration of an Object Instance` coupled with it's expected serialization
/// </summary>
/// <returns></returns>
    public static IEnumerable<object[]> StronglyTypedIdTypeConverterTestData() {
      switch (typeof(TValue)) {
        case {} guidType when typeof(TValue) == typeof(Guid): {
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(Guid.Empty), SerializedTestData = "00000000-0000-0000-0000-000000000000" } };
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "01234567-abcd-9876-cdef-456789abcdef" } };
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(Guid.NewGuid()), SerializedTestData = "Random, so ignore this property of the test data" } };
          }
          break;
        case {} intType when typeof(TValue) == typeof(int): {
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new IntStronglyTypedId(0), SerializedTestData = "0" } };
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new IntStronglyTypedId(1234567), SerializedTestData = "1234567" } };
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new IntStronglyTypedId(new Random().Next()), SerializedTestData = "Random, so ignore this property of the test data" } };
          }
          break;
        // ToDo: replace with new custom exception and localization of exception message
        default:
          throw new Exception(FormattableString.Invariant($"Invalid TValue type {typeof(TValue)}" ));
      }
    }

    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIdTypeConverterTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
