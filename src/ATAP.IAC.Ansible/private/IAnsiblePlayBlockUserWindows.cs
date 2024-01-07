// Interface for AnsiblePlayBlockUserWindows, derived from IAnsiblePlayBlockCommon
public interface IAnsiblePlayBlockUserWindows : IAnsiblePlayBlockCommon
{
  string Fullname { get; set; }
  string Description { get; set; }
  string Groups { get; set; }
  string Password { get; set; }
}
