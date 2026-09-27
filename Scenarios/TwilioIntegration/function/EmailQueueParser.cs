using System.Text.Json;

namespace TwilioEmail;

// APIM POST /twilio-email/emails body as queued by Service Bus: id (request id), to, subject, body.
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

        EmailQueueMessage queued;
        try
        {
            queued = JsonSerializer.Deserialize<EmailQueueMessage>(message, JsonOptions)
                ?? throw new InvalidOperationException("Queue message is not valid email JSON.");
        }
        catch (JsonException ex)
        {
            throw new InvalidOperationException("Queue message is not valid email JSON.", ex);
        }

        if (string.IsNullOrWhiteSpace(queued.To)
            || string.IsNullOrWhiteSpace(queued.Subject)
            || string.IsNullOrWhiteSpace(queued.Body))
        {
            throw new InvalidOperationException("Queue message must include to, subject, and body.");
        }

        if (!EmailAddressFormat.IsWellFormed(queued.To))
        {
            throw new InvalidOperationException("Queue message to must be a well-formed email address.");
        }

        var id = string.IsNullOrWhiteSpace(queued.Id) ? null : queued.Id.Trim();
        return new ValidatedEmailMessage(queued.To.Trim(), queued.Subject.Trim(), queued.Body, id);
    }

    private sealed class EmailQueueMessage
    {
        public string? Id { get; set; }
        public string? To { get; set; }
        public string? Subject { get; set; }
        public string? Body { get; set; }
    }
}

public sealed record ValidatedEmailMessage(string To, string Subject, string Body, string? Id = null);
