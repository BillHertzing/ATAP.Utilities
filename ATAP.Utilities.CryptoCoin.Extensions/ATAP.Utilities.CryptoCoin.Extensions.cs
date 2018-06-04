
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Reflection;
using Itenso.TimePeriod;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Models;

namespace ATAP.Utilities.CryptoCoin.Extensions
{
 
 
    public interface ICryptoCoinNetworkInfoBuilder
    {
        CryptoCoinNetworkInfo Build();
    }

    public class CryptoCoinNetworkInfoBuilder
    {
        TimeBlock avgBlockTime;
        double blockRewardPerBlock;
        Coin coin;
        HashRate hashRate;

        public CryptoCoinNetworkInfoBuilder() {
        }

        public CryptoCoinNetworkInfoBuilder AddAvgBlockTime(TimeBlock avgBlockTime)
        {
            this.avgBlockTime = avgBlockTime;
            return this;
        }
        public CryptoCoinNetworkInfoBuilder AddBlockReward(double blockRewardPerBlock)
        {
            this.blockRewardPerBlock = blockRewardPerBlock;
            return this;
        }
        public CryptoCoinNetworkInfoBuilder AddCoin(Coin coin)
        {
            this.coin = coin;
            return this;
        }

        public CryptoCoinNetworkInfoBuilder AddHashRate(HashRate hashRate)
        {
            this.hashRate = hashRate;
            return this;
        }
        public CryptoCoinNetworkInfo Build()
        {
            return new CryptoCoinNetworkInfo(coin, hashRate, avgBlockTime, blockRewardPerBlock);
        }
        public static CryptoCoinNetworkInfoBuilder CreateNew()
        {
            return new CryptoCoinNetworkInfoBuilder();
        }
    }

    

 

    public class FeesConverter : ExpandableObjectConverter
    {
        public override bool CanConvertFrom(ITypeDescriptorContext context, Type sourceType)
        {
            if(sourceType == typeof(string))
            {
                return true;
            }
            return base.CanConvertFrom(context, sourceType);
        }
        public override bool CanConvertTo(ITypeDescriptorContext context, Type destinationType)
        {
            if(destinationType == typeof(string))
            {
                return true;
            }
            return base.CanConvertTo(context, destinationType);
        }
        public override object ConvertFrom(ITypeDescriptorContext
            context, CultureInfo culture, object value)
        {
            if(value == null)
            {
                return new Fees();
            }

            if(value is string)
            {
                double d;
                if(!double.TryParse(value as string, out d))
                {
                    throw new ArgumentException("Object is not a string of format double", "value");
                }

                return new Fees(d);
            }

            return base.ConvertFrom(context, culture, value);
        }
        public override object ConvertTo(ITypeDescriptorContext context, CultureInfo culture, object value, Type destinationType)
        {
            if(value != null)
            {
                if(!(value is Fees))
                {
                    throw new ArgumentException("Invalid object, is not a Fees", "value");
                }
            }

            if(destinationType == typeof(string))
            {
                if(value == null)
                {
                    return ((value as Fees).FeeAsAPercent).ToString();
                }
            }
            return base.ConvertTo(context, culture, value, destinationType);
        }
    }

 

    public sealed class InterestingCoins
    {
        static readonly Lazy<InterestingCoins> lazy =
    new Lazy<InterestingCoins>(() => new InterestingCoins());

        public InterestingCoins()
        {
        }

        public static InterestingCoins Instance { get { return lazy.Value; } }
    }
}

//public class CryptoCoins
//{
//
//            //Coinname = coinname ?? throw new ArgumentNullException(nameof(coinname));
//            //Avgblocktime = avgblocktime == TimeBlock.Zero ? throw new ArgumentOutOfRangeException(nameof(avgblocktime)) : avgblocktime;
//            //Networkhashrate = networkhashrate == Decimal.Zero ? throw new ArgumentOutOfRangeException(nameof(networkhashrate)) : networkhashrate;
//            //Blockreward = blockreward == Decimal.Zero ? throw new ArgumentOutOfRangeException(nameof(blockreward)) : blockreward;
//            //Hashrate = hashrate == Decimal.Zero ? throw new ArgumentOutOfRangeException(nameof(hashrate)) : hashrate;
//        // provides an estimate of the probability


//    }
//public class CryptoCoinDifficulty
//{
//    string coinname;
//    string aPIfull;
//    public string Coinname { get => coinname; set => coinname = value; }
//    public string APIfull { get => aPIfull; set => aPIfull = value; }
//    public CryptoCoinDifficulty(string coinname, string aPIfull)
//    {
//        Coinname = coinname ?? throw new ArgumentNullException(nameof(coinname));
//        APIfull = aPIfull ?? throw new ArgumentNullException(nameof(aPIfull));
//    }
//    public static async Task<int> GetDifficultyFromAPI(string requestUri)
//    {
//        if (string.IsNullOrWhiteSpace(requestUri))
//        {
//            throw new ArgumentException("message", nameof(requestUri));
//        }
//        // TODO: add validation tests on the requestUri string to ensure it passes basic URI rules
//        var response = await HttpRequestFactory.Get(requestUri);
//        // TODO: throw appropriate exception if a bad response is received
//        // ToDo: parse response based on collection of requestUri rules
//        // This is for XMR stats
//        var rstr = response.ContentAsJson();
//        // parse the JSON
//        XMRMoneroblocksCoinStats stats = JsonConvert.DeserializeObject<XMRMoneroblocksCoinStats>(response.ContentAsJson());
//        int dif = stats.difficulty;
//        return dif;
//    }
//}

/*
public class LocalizedDescriptionAttribute : DescriptionAttribute
{
private readonly string _resourceKey;
private readonly ResourceManager _resource;
public LocalizedDescriptionAttribute(string resourceKey, Type resourceType)
{
_resource = new ResourceManager(resourceType);
_resourceKey = resourceKey;
}

public override string Description{
get {
string displayName = _resource.GetString(_resourceKey);
return string.IsNullOrEmpty(displayName)
? string.Format("[[{0}]]", _resourceKey)
: displayName;
}
}
}
*/

/** Read-only thread safe Lazy loaded Singleton Instance class with the minimum data fields needed to calculate one miners average share of total coins mined in a time period */
/*
public sealed class NTSP_AverageShareOfBlockRewardDT : AverageShareOfBlockRewardDT
{
    //static readonly Lazy<NTSP_NormalizedAverageShareOfEmittedCoins> lazy =
    //new Lazy<NTSP_NormalizedAverageShareOfEmittedCoins>(() => new NTSP_NormalizedAverageShareOfEmittedCoins());

    public NTSP_AverageShareOfBlockRewardDT(TimeBlock averageBlockCreationSpan, TimeBlock duration, HashRate minerHashRate, HashRate networkHashRate, double blockRewardPerBlock) :
      base(averageBlockCreationSpan, duration, minerHashRate, networkHashRate, blockRewardPerBlock)
    {
    }

    //public static NTSP_NormalizedAverageShareOfEmittedCoins Instance { get { return lazy.Value; } }
}
*/

// NormalizedAverageShareOfEmittedCoins is a set of properties/fields, aka a DS.
// NormalizedAverageShareOfEmittedCoinsDS_FromHTTPClient
// 


//public class FromJSON1
//{

//    public FromJSON1(string r)
//    {
//        async Task<FromJSON1> GetAsync(string requestUri)
//        {

//            //ToDO: Better validation on getter
//            if (string.IsNullOrWhiteSpace(requestUri))
//            {
//                //ToDo: Better error handling on the throw
//                throw new ArgumentException("message", nameof(requestUri));
//            }
//            // TODO: add validation tests on the requestUri string to ensure it passes basic URI rules
//            var response = await HttpRequestFactory.Get(requestUri);
//            // TODO: throw appropriate exception if a bad response is received
//            // ToDo: parse response based on collection of requestUri rules - generalize the conversion based on the enumerations
//            // This is for XMR stats
//            var rstr = response.ContentAsJson();
//            // parse the JSON
//            //ToDo: encapsulate the specific type to which the JSON returned by that specific URI can be Converted by the JSONConvert<specificType> into the method parameter
//            FromJSON1 stats = JsonConvert.DeserializeObject<FromJSON1>(response.ContentAsJson());

//            return stats;

//        }
//        //FromJSON1 t = await GetAsync("http://moneroblocks.info/api/get_stats/");
//        Difficulty = 1;
//        Height = 2;
//        HashRate = 3.0m;
//        Current_emission = 5;
//        Last_reward = 2;
//        Last_timestamp = 2;
//        ;
//    }


//public CryptoCoins.CoinStatsCryptoNote ConvertToCryptoNoteCoinStats()
//{
//        CryptoCoins.CoinStatsCryptoNote t = new CryptoCoins.CoinStatsCryptoNote(Coin.XMR, DateTime.Now, TimeBlock.Zero, TimeBlock.FromMinutes(1.00), HashRate, Last_reward, Difficulty);
//        return t;
//    }

