using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.StronglyTypedId;
using System;


namespace ATAP.Utilities.StronglyTypedId.Tests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
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

  public class StronglyTypedIdTypeConverterTestDataGenerator<TValue> : IEnumerable<object[]> where TValue : notnull  {

    public static IEnumerable<object[]> StronglyTypedIdTypeConverterTestData() {
      switch (typeof(TValue)) {
        case Type guidType when typeof(TValue) == typeof(Guid): {
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(Guid.Empty), SerializedTestData = "00000000-0000-0000-0000-000000000000" } };
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "01234567-abcd-9876-cdef-456789abcdef" } };
            yield return new StronglyTypedIdTypeConverterTestData<TValue>[] { new StronglyTypedIdTypeConverterTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(Guid.NewGuid()), SerializedTestData = "Random, so ignore this property of the test data" } };
          }
          break;
        case Type intType when typeof(TValue) == typeof(int): {
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
