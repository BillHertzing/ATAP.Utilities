using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics.Tracing;
using System.Linq;

using ATAP.Utilities.ETW;

using Xunit;

namespace ATAP.Utilities.ETW.UnitTests;

public sealed class ETWLogAttributeRedactionTests {
  private const string ProviderName = "ATAP-Utilities-ETWProvider";

  [Fact]
  public void ThrowingOperation_EmitsOnlyExceptionTypeWithoutSensitiveMessages() {
    // Arrange
    string[] sensitiveValues = [
      "Server=sql01;User Id=admin;Password=NotARealSecret!",
      "Bearer eyJhbGciOiJub25lIn0.task15_181_l",
      "Bitwarden.Database.Production.Password",
      @"C:\Users\sensitive-user\private.txt",
      "SELECT PasswordHash FROM Users",
      "operator@example.invalid",
      "nested-secret-value"
    ];
    using var listener = new CapturingEventListener(ProviderName);

    // Act
    var exception = Assert.Throws<InvalidOperationException>(() =>
      RedactionFixture.ThrowSensitiveException(sensitiveValues));

    // Assert
    Assert.Equal(sensitiveValues[0], exception.Message);
#if TRACE
    CapturedEvent exceptionEvent = Assert.Single(
      listener.Events,
      item => item.EventId == 1 && item.PayloadText.Contains("OnException:", StringComparison.Ordinal));
    Assert.Contains(typeof(InvalidOperationException).FullName!, exceptionEvent.PayloadText, StringComparison.Ordinal);
    foreach (string sensitiveValue in sensitiveValues) {
      Assert.DoesNotContain(sensitiveValue, exceptionEvent.PayloadText, StringComparison.Ordinal);
    }
    Assert.DoesNotContain(typeof(ArgumentException).FullName!, exceptionEvent.PayloadText, StringComparison.Ordinal);
#else
    Assert.DoesNotContain(listener.Events, item => item.PayloadText.Contains("OnException:", StringComparison.Ordinal));
#endif
  }

  private sealed class CapturingEventListener : EventListener {
    private readonly string providerName;

    public CapturingEventListener(string providerName) {
      this.providerName = providerName;
      foreach (EventSource eventSource in EventSource.GetSources()) {
        EnableWhenMatched(eventSource);
      }
    }

    public ConcurrentQueue<CapturedEvent> Events { get; } = new();

    protected override void OnEventSourceCreated(EventSource eventSource) {
      base.OnEventSourceCreated(eventSource);
      EnableWhenMatched(eventSource);
    }

    protected override void OnEventWritten(EventWrittenEventArgs eventData) {
      string payloadText = string.Join(
        "|",
        eventData.Payload?.Select(item => item?.ToString() ?? string.Empty) ?? []);
      Events.Enqueue(new CapturedEvent(eventData.EventId, payloadText));
    }

    private void EnableWhenMatched(EventSource eventSource) {
      if (string.Equals(eventSource.Name, providerName, StringComparison.Ordinal)) {
        EnableEvents(eventSource, EventLevel.LogAlways, EventKeywords.All);
      }
    }
  }

  private sealed record CapturedEvent(int EventId, string PayloadText);

#if TRACE
  [ETWLogAttribute]
#endif
  private static class RedactionFixture {
    public static void ThrowSensitiveException(IReadOnlyList<string> sensitiveValues) {
      var inner = new ArgumentException(sensitiveValues[6]);
      throw new InvalidOperationException(sensitiveValues[0], inner);
    }
  }
}
