using System;
using System.ComponentModel;
using static ATAP.Utilities.CryptoCoin.Enumerations.ExtensionHelpers;
using static ATAP.Utilities.Enumeration.Utilities;

namespace ATAP.Utilities.CryptoCoin.Enumerations
{
  public static class ExtensionHelpers
  {

    public sealed class Symbol : Attribute, IAttribute<string>
    {
      public Symbol(string value)
      {
        Value = value;
      }

      public static implicit operator string(Symbol v) { return v.Value; }

      public string Value { get; }
    }

    public sealed class Algorithm : Attribute, IAttribute<string>
    {
      public Algorithm(string value)
      {
        Value = value;
      }

      public static implicit operator string(Algorithm v) { return v.Value; }

      public string Value { get; }
    }

    public sealed class Proof : Attribute, IAttribute<string>
    {
      public Proof(string value)
      {
        Value = value;
      }

      public static implicit operator string(Proof v) { return v.Value; }

      public string Value { get; }
    }
  }

  public enum Proofs
  {
    //[LocalizedDescription("Work", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("Work")]
    Work = 1,
    [Description("Stake")]
    Stake = 2,
    [Description("Burn")]
    Burn = 3,
    [Description("Activity")]
    Activity = 4,
    [Description("Capacity")]
    Capacity = 5
  }

  // ToDo: automate the creation of the Algorithm enumeration and its attributes based on ???
  // ToDo: it will require the DLL version created to be part of versioning
  // RoDo: it require any changes be integrated into version control.
  public enum Algorithms
  {
    [Description("Generic")]
    Generic = 0,
    [Description("Casper")]
    Casper = 1,
    [Description("CryptoNote")]
    CryptoNote = 2,
    [Description("Hashcash")]
    Hashcash = 3,
    [Description("Lyra2RE")]
    Lyra2RE = 4,
    [Description("ZeroCoin")]
    ZeroCoin = 5
  }

  // ToDo: automate the creation of the enumeration and its attributes based on the data stored in the GIT project https://github.com/crypti/cryptocurrencies.git. Also look at https://stackoverflow.com/questions/725043/dynamic-enum-in-c-sharp for making the list dynamic
  // ToDo: it will require the DLL version created to be part of versioning
  // RoDo: it require any changes be integrated into version control.
  // There are over 1500+ different documented coins so far
  public enum Coin
  {
    [Symbol("GNR")]
    [Description("Generic")]
    [Proof("Generic")]
    [Algorithm("Generic")]
    Generic = 0,
    [Symbol("BCN")]
    [Description("Bytecoin")]
    [Proof("Work")]
    [Algorithm("CryptoNote")]
    BCN = 1,
    [Proof("Work")]
    [Algorithm("Hashcash")]
    [Symbol("BTC")]
    [Description("BitCoin")]
    BTC = 2,
    [Symbol("ETH")]
    [Description("Ethereum")]
    [Proof("Stake")]
    [Algorithm("Casper")]
    ETH = 3,
    [Symbol("DSH")]
    [Description("Dashcoin ")]
    [Proof("Work")]
    [Algorithm("CryptoNote")]
    DSH = 4,
    [Symbol("XMR")]
    [Description("Monero")]
    [Proof("Work")]
    [Algorithm("CryptoNote")]
    XMR = 5,
    [Algorithm("ZeroCoin")]
    [Symbol("ZEC")]
    [Description("ZCoin")]
    ZEC = 6
  }

}
