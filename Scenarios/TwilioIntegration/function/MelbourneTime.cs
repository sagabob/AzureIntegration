namespace TwilioEmail;

internal static class MelbourneTime
{
    private static readonly TimeZoneInfo Zone = ResolveZone();

    public static string Now()
    {
        var local = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, Zone);
        return local.ToString("yyyy-MM-dd HH:mm:ss") + " Melbourne";
    }

    private static TimeZoneInfo ResolveZone()
    {
        foreach (var id in new[] { "Australia/Melbourne", "AUS Eastern Standard Time" })
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(id);
            }
            catch (TimeZoneNotFoundException)
            {
            }
        }

        return TimeZoneInfo.Utc;
    }
}
