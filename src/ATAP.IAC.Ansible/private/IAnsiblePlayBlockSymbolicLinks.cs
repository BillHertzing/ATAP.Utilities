// Interface for AnsiblePlayBlockSymbolicLinks, derived from IAnsiblePlayBlockCommon
public interface IAnsiblePlayBlockSymbolicLinks : IAnsiblePlayBlockCommon
{
  string Source { get; set; }
  string Destination { get; set; }
}
