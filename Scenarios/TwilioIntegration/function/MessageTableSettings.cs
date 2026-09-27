namespace TwilioEmail;

// TABLE_SERVICE_URI and MESSAGE_TABLE_NAME come from Function app settings (not secrets).
public sealed record MessageTableSettings(string TableServiceUri, string TableName)
{
    public static MessageTableSettings FromEnvironment()
    {
        var uri = Environment.GetEnvironmentVariable("TABLE_SERVICE_URI");
        var name = Environment.GetEnvironmentVariable("MESSAGE_TABLE_NAME");
        if (string.IsNullOrWhiteSpace(uri) || string.IsNullOrWhiteSpace(name))
        {
            throw new InvalidOperationException("TABLE_SERVICE_URI and MESSAGE_TABLE_NAME must be set.");
        }

        return new MessageTableSettings(uri.Trim(), name.Trim());
    }
}
