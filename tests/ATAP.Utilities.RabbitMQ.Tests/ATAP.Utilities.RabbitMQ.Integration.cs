
using System;
using System.Collections;
using System.Collections.Generic;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using System.ComponentModel;
using ATAP.Utilities.Testing;

using System.Text.Json;

namespace ATAP.Utilities.RabbitMQIntegrationTests {
/// <summary>
/// Integration Tests 001 basic types serialized through the rabbit MQ basic consumer/producer queue
/// </summary>
  public partial class RabbitMQIntegrationTests001 : IClassFixture<SimpleFixture>
  {

    [Fact]
    public void CanEnqueString() {
      // var converterGuid = TypeDescriptor.GetConverter(typeof(GuidStronglyTypedId));
      // converterGuid.CanConvertFrom(typeof(string)).Should().Be(true);
      // converterGuid.CanConvertFrom(typeof(Guid)).Should().Be(true);
      // converterGuid.CanConvertFrom(typeof(int)).Should().Be(false);
      true.Should().Be(true);
    }
    [Fact]
    public void CanDequeString() {
      // var converterInt = TypeDescriptor.GetConverter(typeof(IntStronglyTypedId));
      // converterInt.CanConvertFrom(typeof(string)).Should().Be(true);
      // converterInt.CanConvertFrom(typeof(Guid)).Should().Be(false);
      // converterInt.CanConvertFrom(typeof(int)).Should().Be(true);
      true.Should().Be(false);
    }


  }
}
