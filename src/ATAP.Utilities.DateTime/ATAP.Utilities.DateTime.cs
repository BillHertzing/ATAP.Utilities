using System;

namespace ATAP.Utilities.DateTime
{
    public static class Utilities
    {
        public static long ToUnixTime(this System.DateTime date, int uom)
        {
            if (uom <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(uom), uom, "The unit divisor must be positive.");
            }

            return (date.ToUniversalTime().Ticks - 621355968000000000) / (10000L * uom);
        }
    }


}
