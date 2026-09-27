using System.Text.Json;

namespace TwilioEmail;

internal static class EmailSendValidator
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public static ValidatedEmailMessage ParseQueueMessage(string? message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            throw new InvalidOperationException("Queue message is empty.");
        }

        var queued = JsonSerializer.Deserialize<EmailQueueMessage>(message, JsonOptions)
            ?? throw new InvalidOperationException("Queue message is not valid email JSON.");

        if (string.IsNullOrWhiteSpace(queued.To)
            || string.IsNullOrWhiteSpace(queued.Subject)
            || string.IsNullOrWhiteSpace(queued.Body))
        {
            throw new InvalidOperationException("Queue message must include to, subject, and body.");
        }

        return new ValidatedEmailMessage(queued.To.Trim(), queued.Subject.Trim(), queued.Body);
    }

    public static (string ApiKey, string FromAddress) RequireResendSettings()
    {
        var apiKey = Environment.GetEnvironmentVariable("EMAIL_SERVICE_API_KEY");
        var from = Environment.GetEnvironmentVariable("EMAIL_FROM_ADDRESS");
        if (string.IsNullOrWhiteSpace(apiKey)
            || string.IsNullOrWhiteSpace(from)
            || apiKey.StartsWith("@Microsoft.KeyVault", StringComparison.OrdinalIgnoreCase)
            || from.StartsWith("@Microsoft.KeyVault", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "EMAIL_SERVICE_API_KEY and EMAIL_FROM_ADDRESS must be resolved Key Vault values, not empty or @Microsoft.KeyVault references.");
        }

        return (apiKey, from.Trim());
    }

    private sealed class EmailQueueMessage
    {
        public string? To { get; set; }
        public string? Subject { get; set; }
        public string? Body { get; set; }
    }
}

internal sealed record ValidatedEmailMessage(string To, string Subject, string Body);
