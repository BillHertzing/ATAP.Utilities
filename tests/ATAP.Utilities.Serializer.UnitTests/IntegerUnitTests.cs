


using System;
using Moq;

using Xunit;
using Xunit.Abstractions;
using System.Collections.Generic;
using System.Linq;
using FluentAssertions;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Serializer;
using ATAP.Utilities.Serializer.DataForTests;

namespace ATAP.Utilities.Serializer.UnitTests {

 public partial class UnitTests001 : IClassFixture<Fixture >  {
      [Fact]
    void PassingTest() {
      var dummy = "abc";
      dummy.Should().Be("abc");
    }

    [Theory]
    [MemberData(nameof(IntegerTestDataGenerator.TestData), MemberType = typeof(IntegerTestDataGenerator))]
    public void IntegerDeserializeFromJSON(IntegerTestData inTestData)    {
      var obj = Fixture.Serializer.Deserialize<System.Int32>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(System.Int32));
      Fixture.Serializer.Deserialize<System.Int32>(inTestData.SerializedTestData).Should().Equals(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(IntegerTestDataGenerator.TestData), MemberType = typeof(IntegerTestDataGenerator))]
    public void IntegerSerializeToJSON(IntegerTestData inTestData)    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }
  }
}
