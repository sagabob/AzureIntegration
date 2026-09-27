using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
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

        var payload = new
        {
            from,
            to = new[] { queued.To },
            subject = queued.Subject,
            text = queued.Body
        };
        var resendRequest = JsonSerializer.Serialize(payload);
        _logger.LogInformation(
            "sendEmail calling Resend at {MelbourneTime}. request={ResendRequest}",
            melbourne,
            resendRequest);

        using var request = new HttpRequestMessage(HttpMethod.Post, "emails");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Content = JsonContent.Create(payload);

        using var response = await _http.SendAsync(request);
        var resendBody = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError(
                "Resend rejected email at {MelbourneTime} to {To} with {Status}. request={ResendRequest} response={ResendResponse}",
                melbourne,
                queued.To,
                (int)response.StatusCode,
                resendRequest,
                resendBody);
            throw new InvalidOperationException($"Resend returned {(int)response.StatusCode}: {resendBody}");
        }

        _logger.LogInformation(
            "Resend accepted email at {MelbourneTime} to {To}. request={ResendRequest} response={ResendResponse}",
            melbourne,
            queued.To,
            resendRequest,
            resendBody);
    }
}
