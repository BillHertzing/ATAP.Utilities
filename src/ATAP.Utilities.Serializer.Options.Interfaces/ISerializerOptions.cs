
namespace ATAP.Utilities.Serializer {
  public interface ISerializerOptions {
    bool AllowTrailingCommas { get; set; }
    bool WriteIndented { get; set; }
    bool IgnoreNullValues { get; set; }
  }
}
