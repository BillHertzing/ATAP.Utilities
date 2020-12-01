using System;

namespace ATAP.Utilities.Testing
{
  // http://geekswithblogs.net/akraus1/archive/2013/12/28/154992.aspx
  public interface ITempDir : IDisposable
    {
        string Name
        {
            get;
        }
    }

}
