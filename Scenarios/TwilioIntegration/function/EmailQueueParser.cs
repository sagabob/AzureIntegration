using System.Text.Json;

namespace TwilioEmail;

// APIM POST /twilio-email/emails body as queued by Service Bus: to, subject, body.
internal static class EmailQueueParser
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public static ValidatedEmailMessage Parse(string? message)
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

    private sealed class EmailQueueMessage
    {
        public string? To { get; set; }
        public string? Subject { get; set; }
        public string? Body { get; set; }
    }
}

public sealed record ValidatedEmailMessage(string To, string Subject, string Body);
