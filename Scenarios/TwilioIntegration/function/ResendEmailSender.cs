using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace TwilioEmail;

// Named HttpClient + absolute Resend URL. Isolated Functions ignore
// AddHttpClient<SendEmail>(BaseAddress = ...).
internal sealed class ResendEmailSender : IResendEmailSender
{
    public const string HttpClientName = "resend";
    public const string EmailsUrl = "https://api.resend.com/emails";

    private readonly IHttpClientFactory _httpFactory;

    public ResendEmailSender(IHttpClientFactory httpFactory)
    {
        _httpFactory = httpFactory;
    }

    public async Task<ResendSendResult> SendAsync(
        ValidatedEmailMessage email,
        ResendSettings settings,
        CancellationToken cancellationToken = default)
    {
        // Resend "text" is the APIM/queue field "body" (plain text, not html).
        var payload = new
        {
            from = settings.FromAddress,
            to = new[] { email.To },
            subject = email.Subject,
            text = email.Body
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, EmailsUrl);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", settings.ApiKey);
        request.Content = JsonContent.Create(payload);

        using var response = await _httpFactory.CreateClient(HttpClientName)
            .SendAsync(request, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);

        return new ResendSendResult(
            (int)response.StatusCode,
            JsonSerializer.Serialize(payload),
            responseBody);
    }
}
