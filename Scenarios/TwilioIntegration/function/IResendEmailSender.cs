using System.Text.Json;

namespace TwilioEmail;

/// <summary>Sends one email through Resend. Implemented by ResendEmailSender, not the function class.</summary>
public interface IResendEmailSender
{
    Task<ResendSendResult> SendAsync(
        ValidatedEmailMessage email,
        ResendSettings settings,
        CancellationToken cancellationToken = default);
}

public sealed record ResendSendResult(int StatusCode, string RequestJson, string ResponseBody)
{
    public bool Succeeded => StatusCode is >= 200 and < 300;

    /// <summary>Resend 2xx body is typically {"id":"..."}.</summary>
    public string? ProviderMessageId
    {
        get
        {
            if (string.IsNullOrWhiteSpace(ResponseBody))
            {
                return null;
            }

            try
            {
                using var doc = JsonDocument.Parse(ResponseBody);
                if (doc.RootElement.TryGetProperty("id", out var id) && id.ValueKind == JsonValueKind.String)
                {
                    var value = id.GetString();
                    return string.IsNullOrWhiteSpace(value) ? null : value;
                }
            }
            catch (JsonException)
            {
            }

            return null;
        }
    }
}
