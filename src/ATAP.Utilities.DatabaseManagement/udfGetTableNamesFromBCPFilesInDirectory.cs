using System;
using System.Data.Sql;
using Microsoft.SqlServer.Server;
using System.Collections;
using System.Data.SqlTypes;

public class udfGetTableNamesFromBCPFilesInDirectory {
  [SqlFunction(FillRowMethodName = "FillRow")]
  public static IEnumerable InitMethod(String path, string matchPattern, string replacePattern) {
    // Validate path is a valid path
    // Turn the match-pattern into a regex
    // Get files in path that match the pattern into an array or list of tuples each having filepath and replace-results
    // Transform the filename into a table name using the replace-pattern
    return new (string tablename, string fullFilePath)[4] { ("Statement", "statementFilePath"), ("Class", "ClassFilePth"), ("Rule", "RuleFilePath"), ("RuleSet", "ruleSetFullFilePAth") };
  }

  public static void FillRow(Object inObj, out String tableName, out String fullFilePath) {
    tableName = ((Tuple<string, string>) inObj).Item1;
    fullFilePath = ((Tuple<string, string>) inObj).Item2;
  }
}
