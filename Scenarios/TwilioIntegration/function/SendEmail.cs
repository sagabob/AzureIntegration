using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace TwilioEmail;

public sealed class SendEmail
{
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
        var queued = EmailSendValidator.ParseQueueMessage(message);
        var melbourne = MelbourneTime.Now();
        _logger.LogInformation(
            "sendEmail received at {MelbourneTime}. to={To} subject={Subject} body={Body}",
            melbourne,
            queued.To,
            queued.Subject,
            queued.Body);

        var (apiKey, from) = EmailSendValidator.RequireResendSettings();

        using var request = new HttpRequestMessage(HttpMethod.Post, "emails");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Content = JsonContent.Create(new
        {
            from,
            to = new[] { queued.To },
            subject = queued.Subject,
            text = queued.Body
        });

        using var response = await _http.SendAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            var detail = await response.Content.ReadAsStringAsync();
            _logger.LogError(
                "Resend rejected email at {MelbourneTime} to {To} with {Status}.",
                melbourne,
                queued.To,
                (int)response.StatusCode);
            throw new InvalidOperationException($"Resend returned {(int)response.StatusCode}: {detail}");
        }

        _logger.LogInformation(
            "Resend accepted email at {MelbourneTime} to {To}.",
            melbourne,
            queued.To);
    }
}
