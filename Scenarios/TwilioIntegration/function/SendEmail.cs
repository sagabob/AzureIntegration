using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace TwilioEmail;

public sealed class SendEmail
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly HttpClient _http;
    private readonly ILogger<SendEmail> _logger;

    public SendEmail(HttpClient http, ILogger<SendEmail> logger)
    {
        _http = http;
        _logger = logger;
    }

    [Function("sendEmail")]
    public async Task Run(
        [ServiceBusTrigger("%TWILIO_EMAIL_QUEUE_NAME%", Connection = "ServiceBusConnection")] string message)
    {
        var queued = JsonSerializer.Deserialize<EmailQueueMessage>(message, JsonOptions)
            ?? throw new InvalidOperationException("Queue message is not valid email JSON.");

        if (string.IsNullOrWhiteSpace(queued.To)
            || string.IsNullOrWhiteSpace(queued.Subject)
            || string.IsNullOrWhiteSpace(queued.Body))
        {
            throw new InvalidOperationException("Queue message must include to, subject, and body.");
        }

        var apiKey = Environment.GetEnvironmentVariable("EMAIL_SERVICE_API_KEY");
        var from = Environment.GetEnvironmentVariable("EMAIL_FROM_ADDRESS");
        if (string.IsNullOrWhiteSpace(apiKey) || string.IsNullOrWhiteSpace(from))
        {
            throw new InvalidOperationException("EMAIL_SERVICE_API_KEY and EMAIL_FROM_ADDRESS must be set.");
        }

        using var request = new HttpRequestMessage(HttpMethod.Post, "emails");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Content = JsonContent.Create(new
        {
            from,
            to = new[] { queued.To.Trim() },
            subject = queued.Subject,
            text = queued.Body
        });

        using var response = await _http.SendAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            var detail = await response.Content.ReadAsStringAsync();
            _logger.LogError("Resend rejected email to {To} with {Status}.", queued.To, (int)response.StatusCode);
            throw new InvalidOperationException($"Resend returned {(int)response.StatusCode}: {detail}");
        }

        _logger.LogInformation("Resend accepted email to {To}.", queued.To);
    }

    private sealed class EmailQueueMessage
    {
        public string? To { get; set; }
        public string? Subject { get; set; }
        public string? Body { get; set; }
    }
}
