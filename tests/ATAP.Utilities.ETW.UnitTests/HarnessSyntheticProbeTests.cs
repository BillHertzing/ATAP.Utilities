using System;
using System.Collections.Concurrent;
using System.Diagnostics.Tracing;
using System.Linq;

using ATAP.Utilities.ETW;

using Xunit;

namespace ATAP.Utilities.ETW.UnitTests;

public sealed class HarnessSyntheticProbeTests {
  private const string ProviderName = "ATAP-Utilities-ETWProvider";

  [Fact]
  public void DisabledProvider_EmitsNoRows() {
    using var listener = new Listener(enableProvider: false);
    Synthetic.Success("safe");
    Assert.Empty(listener.Events);
  }

  [Fact]
  public void Success_EmitsOneStartAndOneTerminal() {
    using var listener = new Listener(enableProvider: true);
    Synthetic.Success("safe");
    Assert.Equal(2, listener.Events.Count(item => item.EventId == 3));
    Assert.Contains(listener.Events, item => item.Payload.EndsWith(".Success", StringComparison.Ordinal));
  }

  [Fact]
  public void Fault_EmitsOneStartAndOneFaultTerminal() {
    using var listener = new Listener(enableProvider: true);
    Assert.Throws<InvalidOperationException>(() => Synthetic.Fault("safe"));
    Assert.Single(listener.Events.Where(item => item.EventId == 3));
    Assert.Single(listener.Events.Where(item => item.EventId == 1 && item.Payload.Contains(typeof(InvalidOperationException).FullName!, StringComparison.Ordinal)));
  }

  [Fact]
  public void Cancelled_EmitsOneStartAndOneFaultTerminal() {
    using var listener = new Listener(enableProvider: true);
    Assert.Throws<OperationCanceledException>(() => Synthetic.Cancelled("safe"));
    Assert.Single(listener.Events.Where(item => item.EventId == 3));
    Assert.Single(listener.Events.Where(item => item.EventId == 1 && item.Payload.Contains(typeof(OperationCanceledException).FullName!, StringComparison.Ordinal)));
  }

  [ETWLogAttribute]
  private static class Synthetic {
    public static void Success(string value) => _ = value;
    public static void Fault(string value) => throw new InvalidOperationException(value);
    public static void Cancelled(string value) => throw new OperationCanceledException(value);
  }

  private sealed class Listener : EventListener {
    private readonly bool enableProvider;

    public Listener(bool enableProvider) {
      this.enableProvider = enableProvider;
      foreach (EventSource eventSource in EventSource.GetSources()) {
        EnableWhenMatched(eventSource);
      }
    }

    public ConcurrentQueue<CapturedEvent> Events { get; } = new();

    protected override void OnEventSourceCreated(EventSource eventSource) {
      base.OnEventSourceCreated(eventSource);
      EnableWhenMatched(eventSource);
    }

    protected override void OnEventWritten(EventWrittenEventArgs eventData) =>
      Events.Enqueue(new CapturedEvent(
        eventData.EventId,
        string.Join("|", eventData.Payload?.Select(item => item?.ToString() ?? string.Empty) ?? [])));

    private void EnableWhenMatched(EventSource eventSource) {
      if (enableProvider && string.Equals(eventSource.Name, ProviderName, StringComparison.Ordinal)) {
        EnableEvents(eventSource, EventLevel.LogAlways, EventKeywords.All);
      }
    }
  }

  private sealed record CapturedEvent(int EventId, string Payload);
}
