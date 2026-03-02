
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;

namespace ATAP.Utilities.CryptoMiner.Enumerations
{
    // ToDo: continue to add miner SW to this list
    //[JsonConverter(typeof(StringEnumConverter))]
    public enum MinerSWE
    {
    [Description("Generic")]
    Generic = 0,
    [Description("Claymore")]
    Claymore = 1,
        [Description("ETHminer")]
    ETHMiner = 2,
        [Description("GENOIL")]
    GENOIL = 3,
        [Description("XMRStak ")]
    XMRStak = 4,
        [Description("WolfsMiner")]
    WolfsMiner = 5,
        [Description("MoneroSpelunker")]
    MoneroSpelunker = 6
  }


}
