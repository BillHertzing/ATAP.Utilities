using System.Threading;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Moq;
using ATAP.Utilities.Configuration.Secrets.Shims;
using ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden;
using Xunit;

namespace ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden.Tests;

[Trait("Category", "Unit")]
public sealed class BitwardenSecretMappingTests
{
    [Fact]
    public void Constructor_SetsAllProperties()
    {
        // Arrange / Act
        var mapping = new BitwardenSecretMapping("MyConfigKey", "MyVaultItem", "myField");

        // Assert
        mapping.ConfigKey.Should().Be("MyConfigKey");
        mapping.BwItemName.Should().Be("MyVaultItem");
        mapping.BwFieldName.Should().Be("myField");
    }

    [Fact]
    public void DefaultFieldName_IsPassword()
    {
        // Arrange / Act
        var mapping = new BitwardenSecretMapping("Key", "Item");

        // Assert
        mapping.BwFieldName.Should().Be("password");
    }

    [Fact]
    public void RecordEquality_WorksCorrectly()
    {
        // Arrange
        var a = new BitwardenSecretMapping("K", "I", "F");
        var b = new BitwardenSecretMapping("K", "I", "F");
        var c = new BitwardenSecretMapping("K", "I", "OTHER");

        // Assert
        a.Should().Be(b);
        a.Should().NotBe(c);
    }
}

public sealed class BitwardenConfigurationProviderTests
{
    private static Mock<IConfigurationSecretsShim> MakeShim(string? returnValue = "secret-value")
    {
        var mock = new Mock<IConfigurationSecretsShim>();
        mock.Setup(s => s.GetSecretAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(returnValue);
        return mock;
    }

    [Fact]
    public void Load_PopulatesConfigKey_WhenShimReturnsValue()
    {
        // Arrange
        var shim = MakeShim("my-secret");
        var mappings = new[]
        {
            new BitwardenSecretMapping("App:ApiKey", "MyVaultItem", "password"),
        };
        var provider = new BitwardenConfigurationProvider(mappings, shim.Object);

        // Act
        provider.Load();

        // Assert
        provider.TryGet("App:ApiKey", out var value).Should().BeTrue();
        value.Should().Be("my-secret");
    }

    [Fact]
    public void Load_SkipsKey_WhenShimReturnsNull()
    {
        // Arrange
        var shim = MakeShim(returnValue: null);
        var mappings = new[]
        {
            new BitwardenSecretMapping("App:Missing", "NoSuchItem"),
        };
        var provider = new BitwardenConfigurationProvider(mappings, shim.Object);

        // Act
        provider.Load();

        // Assert
        provider.TryGet("App:Missing", out _).Should().BeFalse();
    }

    [Fact]
    public void Load_PopulatesMultipleKeys()
    {
        // Arrange
        var mock = new Mock<IConfigurationSecretsShim>();
        mock.Setup(s => s.GetSecretAsync("ItemA", It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync("value-a");
        mock.Setup(s => s.GetSecretAsync("ItemB", It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync("value-b");

        var mappings = new[]
        {
            new BitwardenSecretMapping("Config:KeyA", "ItemA"),
            new BitwardenSecretMapping("Config:KeyB", "ItemB"),
        };
        var provider = new BitwardenConfigurationProvider(mappings, mock.Object);

        // Act
        provider.Load();

        // Assert
        provider.TryGet("Config:KeyA", out var a).Should().BeTrue();
        a.Should().Be("value-a");

        provider.TryGet("Config:KeyB", out var b).Should().BeTrue();
        b.Should().Be("value-b");
    }

    [Fact]
    public void Load_PassesFieldName_ToShim()
    {
        // Arrange
        var mock = new Mock<IConfigurationSecretsShim>();
        mock.Setup(s => s.GetSecretAsync("MyItem", "customField", It.IsAny<CancellationToken>()))
            .ReturnsAsync("field-value");

        var mappings = new[]
        {
            new BitwardenSecretMapping("Cfg:Key", "MyItem", "customField"),
        };
        var provider = new BitwardenConfigurationProvider(mappings, mock.Object);

        // Act
        provider.Load();

        // Assert
        mock.Verify(s => s.GetSecretAsync("MyItem", "customField", It.IsAny<CancellationToken>()), Times.Once);
        provider.TryGet("Cfg:Key", out var val).Should().BeTrue();
        val.Should().Be("field-value");
    }

    [Fact]
    public void Load_EmptyMappings_ProducesNoKeys()
    {
        // Arrange
        var shim = MakeShim();
        var provider = new BitwardenConfigurationProvider([], shim.Object);

        // Act
        provider.Load();

        // Assert — shim was never called
        shim.Verify(s => s.GetSecretAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

public sealed class BitwardenConfigurationSourceTests
{
    [Fact]
    public void Build_ReturnsBitwardenConfigurationProvider()
    {
        // Arrange
        var shim = new Mock<IConfigurationSecretsShim>().Object;
        var source = new BitwardenConfigurationSource([], shim);
        var builder = new ConfigurationBuilder();

        // Act
        var provider = source.Build(builder);

        // Assert
        provider.Should().BeOfType<BitwardenConfigurationProvider>();
    }
}

public sealed class ConfigurationBuilderExtensionsTests
{
    [Fact]
    public void AddBitwardenSecrets_AddsSourceToBuilder()
    {
        // Arrange
        var builder = new ConfigurationBuilder();
        var mappings = new[] { new BitwardenSecretMapping("K", "I") };

        // Act — does not throw (BW_SESSION not needed until Load() is called)
        var returned = builder.AddBitwardenSecrets(mappings);

        // Assert
        returned.Should().BeSameAs(builder);
        builder.Sources.Should().ContainSingle()
               .Which.Should().BeOfType<BitwardenConfigurationSource>();
    }
}
