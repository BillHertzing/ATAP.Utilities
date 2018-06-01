using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.Testing;
using FluentAssertions;
using nucs.JsonSettings;
using Xunit;
using Xunit.Abstractions;
using YamlDotNet.Serialization;

namespace ATAP.Utilities.ZSandbox.UnitTests
{
    public class Fixture
    {
        public Fixture()
        {
        }
    }

    public class ClassLevelTestData : IEnumerable<(string, string, string, double)[]>, IEnumerable<object[]>
    {
        public static List<(string, string, string, double)> TestData =
            new List<(string, string, string, double)>() {
        ("k1=1", "k2=1","c1=1", 11.1),
            ("k1=1", "k2=2","c1=1", 12.1),
            ("k1=2", "k2=1","c1=1", 21.1),
            ("k1=2", "k2=2","c1=1", 22.1),
            ("k1=1", "k2=1","c1=2", 11.2),
            ("k1=1", "k2=2","c1=2", 12.2),
            ("k1=2", "k2=1","c1=2", 21.2),
            ("k1=2", "k2=2","c1=2", 22.2)
        };

        IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
        IEnumerator<object[]> IEnumerable<object[]>.GetEnumerator()
        {
            throw new NotImplementedException();
        }

        public IEnumerator<(string, string, string, double)[]> GetEnumerator()
        {
            yield return new(string, string, string, double)[] {
            ("k1=1", "k2=1", "c1=1", 11.1)
            };
            yield return new(string, string, string, double)[] {
            ("k1=1", "k2=2", "c1=1", 12.1)
            };
            yield return new(string, string, string, double)[] {
            ("k1=2", "k2=1", "c1=1", 21.1)
            };
            yield return new(string, string, string, double)[] {
            ("k1=2", "k2=2", "c1=1", 22.1)
            };
            yield return new(string, string, string, double)[] {
            ("k1=1", "k2=1", "c1=1", 11.1),
                ("k1=2", "k2=2", "c1=1", 22.1)
            };
        }

        // Test Data
        public static IEnumerable<(string, string, string, double)[]> TestData0() => new List<(string, string, string, double)[]> {
        new (string, string, string, double)[] {
        ("k1=1", "k2=1","c1=1", 11.1)
        },
            new (string, string, string, double)[] {
            ("k1=1", "k2=2","c1=1", 12.1)
            },
            new (string, string, string, double)[] {
            ("k1=2", "k2=1","c1=1", 21.1)
            },
            new (string, string, string, double)[] {
            ("k1=2", "k2=2","c1=1", 22.1)
            },
            new (string, string, string, double)[] {
            ("k1=1", "k2=1","c1=2", 11.2)
            },
            new (string, string, string, double)[] {
            ("k1=1", "k2=2","c1=2", 12.2)
            },
            new (string, string, string, double)[] {
            ("k1=2", "k2=1","c1=2", 21.2)
            },
            new (string, string, string, double)[] {
            ("k1=2", "k2=2","c1=2", 22.2)
            }
        };

    //public static IEnumerable<(string, string, string, double)[]> GetTestData(int start, int end)
        //{
        //    return TestData.Take(numTests);
        //}
        //public static IEnumerable<(string, string, string, double)[]> GetTestData(int numTests) {
        //    return new(string, string, string, double)[numTests] { TestData.Take(numTests); }
        //    }
    }

    class MySettings : JsonSettings
    {
        //Step 3: Override parent's constructors
        public MySettings() {
        }
        public MySettings(string fileName) : base(fileName) {
        }

        public override string FileName { get; set; }  //for loading and saving.

        #region Settings

        public string SomeProperty { get; set; }
        public int SomeNumberWithDefaultValue { get; set; } = 1;
        #endregion
    }

    public class ZSandboxUnitTests001 : IClassFixture<Fixture>
    {
        readonly ITestOutputHelper output;
        protected Fixture _fixture;

        public ZSandboxUnitTests001(ITestOutputHelper output, Fixture fixture)
        {
            this.output = output;
            this._fixture = fixture;
        }

        [Theory]
        // [MemberData(nameof(Fixture.TestData))]
        [InlineData("")]
        //[ClassData(typeof(ClassLevelTestData))]
        public void ConfigurationSettingsTest(string _testdatainput)
        {
            string appConfigFileName = "appConfig.txt";
            string userConfigFileName = "userConfig.txt";
            ///string path = Path.Combine(Environment.GetEnvironmentVariable("ProgramData"), "ACE/config.txt");
            TemporaryFile appConfigFilePath = new TemporaryFile(appConfigFileName);
            TemporaryFile userConfigFilePath = new TemporaryFile(userConfigFileName);
            MySettings mySettings = new MySettings();
            mySettings.FileName = appConfigFilePath;

            //config.AppSettings.Settings[key].Value = value;
            //config.Save();
            //ConfigurationManager.RefreshSection("appSettings");
            var str = "";
            str.Should()
                .Be(_testdatainput);
        }


        [Theory(Skip = "trying to get an array of test data from the fixture to the test")]
        // [MemberData(nameof(Fixture.TestData))]
        //[InlineData(new Tuple<string,string,string,double>("k1=1","k2=1","c1=1",1.11))]
        [ClassData(typeof(ClassLevelTestData))]
        public void TestX((string k1, string k2, string c1, double hr)[] _testdatainput)
        {
            // _testdatainput.ToList().ForEach(x => output.WriteLine($"{x.k1} : {x.k2}"));
            foreach(var _indata in _testdatainput)
            {
                output.WriteLine($"{_indata.k1}");
            }
            Assert.Equal(1, 1);
        }

    }
}

