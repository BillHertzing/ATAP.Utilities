using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

using Microsoft.Diagnostics.Tracing;
using Microsoft.Diagnostics.Tracing.EventPipe;

using Xunit;

namespace ATAP.Utilities.ETW.UnitTests;

public sealed record DecodedEtwRow(string ProviderName, string ProviderGuid, int EventId, string Payload);

public static class UtilitiesEtwTraceDecoder {
  public static IReadOnlyList<DecodedEtwRow> Decode(string tracePath, string providerName) {
    if (!File.Exists(tracePath) || new FileInfo(tracePath).Length == 0) throw new InvalidDataException("Trace is missing or empty.");
    var rows = new List<DecodedEtwRow>();
    using var source = new EventPipeEventSource(tracePath);
    source.Dynamic.All += data => {
      if (!string.Equals(data.ProviderName, providerName, StringComparison.Ordinal)) return;
      string payload = string.Join("|", Enumerable.Range(0, data.PayloadNames.Length).Select(index => data.PayloadValue(index)?.ToString() ?? string.Empty));
      rows.Add(new DecodedEtwRow(data.ProviderName, data.ProviderGuid.ToString(), (int)data.ID, payload));
    };
    source.Process();
    return rows;
  }
}

public sealed class UtilitiesEtwTraceDecoderEntryPointTests {
  [Fact]
  public void DecodeRequestedTrace_EmitsRowsJson() {
    string? tracePath = Environment.GetEnvironmentVariable("U00_TRACE_PATH");
    string? rowsPath = Environment.GetEnvironmentVariable("U00_DECODED_ROWS_PATH");
    if (string.IsNullOrWhiteSpace(tracePath) && string.IsNullOrWhiteSpace(rowsPath)) return;
    Assert.False(string.IsNullOrWhiteSpace(tracePath));
    Assert.False(string.IsNullOrWhiteSpace(rowsPath));
    IReadOnlyList<DecodedEtwRow> rows = UtilitiesEtwTraceDecoder.Decode(tracePath!, "ATAP-Utilities-ETWProvider");
    Assert.NotEmpty(rows);
    Directory.CreateDirectory(Path.GetDirectoryName(rowsPath!)!);
    File.WriteAllText(rowsPath!, JsonSerializer.Serialize(rows));
  }
}
