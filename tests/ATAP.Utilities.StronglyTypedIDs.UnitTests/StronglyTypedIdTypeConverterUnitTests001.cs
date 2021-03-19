
using System;
using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedID;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

using System.ComponentModel;

// For the tests that use the new Serializer/Deserializer
using System.Text.Json;
// For the tests that use the old Newtonsoft Serializer/Deserializer
//using Newtonsoft.Json;

namespace ATAP.Utilities.StronglyTypedID.UnitTests {

  public partial class StronglyTypedIDTypeConverterUnitTests001 : IClassFixture<Fixture> {

    [Fact]
    public void GuidIdCanConvertTests() {
      var converterGuid = TypeDescriptor.GetConverter(typeof(GuidStronglyTypedID));
      converterGuid.CanConvertFrom(typeof(string)).Should().Be(true);
      converterGuid.CanConvertFrom(typeof(Guid)).Should().Be(true);
      converterGuid.CanConvertFrom(typeof(int)).Should().Be(false);
    }
    [Fact]
    public void IntIdCanConvertTests() {
      var converterInt = TypeDescriptor.GetConverter(typeof(IntStronglyTypedID));
      converterInt.CanConvertFrom(typeof(string)).Should().Be(true);
      converterInt.CanConvertFrom(typeof(Guid)).Should().Be(false);
      converterInt.CanConvertFrom(typeof(int)).Should().Be(true);
    }
    [Fact]
    public void GuidIDToStringTest() {
      var guidStronglyTypedID = new GuidStronglyTypedID();
      guidStronglyTypedID.ToString().Should().MatchRegex("^[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}$");
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIDTypeConverterTestDataGenerator<Guid>.StronglyTypedIDTypeConverterTestData), MemberType = typeof(StronglyTypedIDTypeConverterTestDataGenerator<Guid>))]
    public void GuidIdConvertFromString(StronglyTypedIDTypeConverterTestData<Guid> inTestData) {
      var converterGuid = TypeDescriptor.GetConverter(typeof(GuidStronglyTypedID));
      if (inTestData.SerializedTestData.StartsWith("0000", System.StringComparison.CurrentCulture) || inTestData.SerializedTestData.StartsWith("01234", System.StringComparison.CurrentCulture)) {
        //var stronglyTypedID = SerializationFixtureSystemTextJson.Serializer.Deserialize<GuidStronglyTypedID>(inTestData.SerializedTestData);
        var stronglyTypedID = converterGuid.ConvertFrom(inTestData.SerializedTestData);
        stronglyTypedID.Should().BeOfType(typeof(GuidStronglyTypedID));
        // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
        stronglyTypedID.Should().Be(inTestData.InstanceTestData);
      }
      else {
        // No data for random guids
      }
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIDTypeConverterTestDataGenerator<Guid>.StronglyTypedIDTypeConverterTestData), MemberType = typeof(StronglyTypedIDTypeConverterTestDataGenerator<Guid>))]
    public void GuidIdConvertToString(StronglyTypedIDTypeConverterTestData<Guid> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      var converterGuid = TypeDescriptor.GetConverter(typeof(GuidStronglyTypedID));
      // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
      if (inTestData.SerializedTestData.StartsWith("0000", System.StringComparison.CurrentCulture) || inTestData.SerializedTestData.StartsWith("01234", System.StringComparison.CurrentCulture)) {
        converterGuid.ConvertTo(inTestData.InstanceTestData, typeof(string)).Should().Be(inTestData.SerializedTestData);
      }
      else {
        ((string)converterGuid.ConvertTo(inTestData.InstanceTestData, typeof(string))).Should().MatchRegex("^[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}$");
      }
    }

    [Fact]
    public void IntIDToStringTest() {
      var intStronglyTypedID = new IntStronglyTypedID();
      intStronglyTypedID.ToString().Should().MatchRegex("^\\d+$");
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIDTypeConverterTestDataGenerator<int>.StronglyTypedIDTypeConverterTestData), MemberType = typeof(StronglyTypedIDTypeConverterTestDataGenerator<int>))]
    public void IntIdConvertFromString(StronglyTypedIDTypeConverterTestData<int> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      var converterInt = TypeDescriptor.GetConverter(typeof(IntStronglyTypedID));
      if (inTestData.SerializedTestData.StartsWith("0000", System.StringComparison.CurrentCulture) || inTestData.SerializedTestData.StartsWith("01234", System.StringComparison.CurrentCulture)) {
        //var stronglyTypedID = SerializationFixtureSystemTextJson.Serializer.Deserialize<IntStronglyTypedID>(inTestData.SerializedTestData);
        var stronglyTypedID = converterInt.ConvertFrom(inTestData.SerializedTestData);
        stronglyTypedID.Should().BeOfType(typeof(IntStronglyTypedID));
        // two sets of test data have fixed, non-random Integers, the rest are random
        stronglyTypedID.Should().Be(inTestData.InstanceTestData);
      }
      else {
        // No data for random Integers
      }
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIDTypeConverterTestDataGenerator<int>.StronglyTypedIDTypeConverterTestData), MemberType = typeof(StronglyTypedIDTypeConverterTestDataGenerator<int>))]
    public void IntIdConvertToString(StronglyTypedIDTypeConverterTestData<int> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      var converterInt = TypeDescriptor.GetConverter(typeof(IntStronglyTypedID));
      // two sets of test data have fixed, non-random Integers, the rest are random
      if (inTestData.SerializedTestData.Equals("0") || inTestData.SerializedTestData.Equals("1234567")) {
        converterInt.ConvertTo(inTestData.InstanceTestData, typeof(string)).Should().Be(inTestData.SerializedTestData);
      }
      else {
        // No test available for random integer
      }
    }
  }
}
