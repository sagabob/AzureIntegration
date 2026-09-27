namespace TwilioEmail;

// Values come from Function app settings that are Key Vault references.
// Azure resolves them before the process starts; do not call Key Vault here.
public sealed record ResendSettings(string ApiKey, string FromAddress)
{
    public static ResendSettings FromEnvironment()
    {
        var apiKey = Environment.GetEnvironmentVariable("EMAIL_SERVICE_API_KEY");
        var from = Environment.GetEnvironmentVariable("EMAIL_FROM_ADDRESS");
        if (IsMissing(apiKey) || IsMissing(from))
        {
            throw new InvalidOperationException(
                "EMAIL_SERVICE_API_KEY and EMAIL_FROM_ADDRESS must be resolved Key Vault values, not empty or @Microsoft.KeyVault references.");
        }

        return new ResendSettings(apiKey!, from!.Trim());
    }

    private static bool IsMissing(string? value) =>
        string.IsNullOrWhiteSpace(value)
        || value.StartsWith("@Microsoft.KeyVault", StringComparison.OrdinalIgnoreCase);
}
