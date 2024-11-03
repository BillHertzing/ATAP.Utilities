namespace ATAP.Utilities.IAC.Ansible
{


  // Interface for AnsiblePlayBlockCopyFiles, derived from IAnsiblePlayBlockCommon
  public interface IAnsiblePlayBlockCopyFiles : IAnsiblePlayBlockCommon
  {
    string Source { get; set; }
    string Destination { get; set; }
  }
}
