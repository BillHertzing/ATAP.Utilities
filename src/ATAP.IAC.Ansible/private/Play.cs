 public class Play
  {
    public string Name { get; set; }
    public List<AnsibleScriptBlock> AnsibleScriptBlocks { get; set; }

    public Play()
    {
      AnsibleScriptBlocks = new List<AnsibleScriptBlock>();
    }

  }
