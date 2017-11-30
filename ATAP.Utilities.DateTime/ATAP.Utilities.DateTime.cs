using System;

namespace ATAP.Utilities.DateTime
{
    public static class Utilities
    {
        public static long ToUnixTime(this System.DateTime date, int uom)
        {
            return (date.ToUniversalTime().Ticks - 621355968000000000) / (10000 * uom);
        }
    }

}
