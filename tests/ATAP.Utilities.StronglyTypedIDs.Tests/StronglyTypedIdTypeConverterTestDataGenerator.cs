using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.StronglyTypedID;
using System;


namespace ATAP.Utilities.StronglyTypedID.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class StronglyTypedIDTypeConverterTestData<TValue> where TValue : notnull
  {
    public IStronglyTypedID<TValue> InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public StronglyTypedIDTypeConverterTestData()
    {
    }

    public StronglyTypedIDTypeConverterTestData(IStronglyTypedID<TValue> instanceTestData, string serializedTestData)
    {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class StronglyTypedIDTypeConverterTestDataGenerator<TValue> : IEnumerable<object[]> where TValue : notnull  {

    public static IEnumerable<object[]> StronglyTypedIDTypeConverterTestData() {
      switch (typeof(TValue)) {
        case Type guidType when typeof(TValue) == typeof(Guid): {
            yield return new StronglyTypedIDTypeConverterTestData<TValue>[] { new StronglyTypedIDTypeConverterTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new GuidStronglyTypedID(Guid.Empty), SerializedTestData = "00000000-0000-0000-0000-000000000000" } };
            yield return new StronglyTypedIDTypeConverterTestData<TValue>[] { new StronglyTypedIDTypeConverterTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new GuidStronglyTypedID(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "01234567-abcd-9876-cdef-456789abcdef" } };
            yield return new StronglyTypedIDTypeConverterTestData<TValue>[] { new StronglyTypedIDTypeConverterTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new GuidStronglyTypedID(Guid.NewGuid()), SerializedTestData = "Random, so ignore this property of the test data" } };
          }
          break;
        case Type intType when typeof(TValue) == typeof(int): {
            yield return new StronglyTypedIDTypeConverterTestData<TValue>[] { new StronglyTypedIDTypeConverterTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new IntStronglyTypedID(0), SerializedTestData = "0" } };
            yield return new StronglyTypedIDTypeConverterTestData<TValue>[] { new StronglyTypedIDTypeConverterTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new IntStronglyTypedID(1234567), SerializedTestData = "1234567" } };
            yield return new StronglyTypedIDTypeConverterTestData<TValue>[] { new StronglyTypedIDTypeConverterTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new IntStronglyTypedID(new Random().Next()), SerializedTestData = "Random, so ignore this property of the test data" } };
          }
          break;
        // ToDo: replace with new custom exception and localization of exception message
        default:
          throw new Exception(FormattableString.Invariant($"Invalid TValue type {typeof(TValue)}" ));
      }
    }


    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIDTypeConverterTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
