using System.Net;

namespace TwilioEmail.Tests;

public class ResendEmailSenderTests
{
    [Fact]
    public async Task SendAsync_posts_bearer_and_plain_text_body()
    {
        HttpRequestMessage? captured = null;
        string? requestJson = null;
        var handler = new StubHandler(req =>
        {
            captured = req;
            requestJson = req.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("""{"id":"re_1"}""")
            };
        });
        var sender = new ResendEmailSender(new StubFactory(new HttpClient(handler)));

        var result = await sender.SendAsync(
            new ValidatedEmailMessage("a@b.com", "Hello", "plain"),
            new ResendSettings("re_test", "from@demo.com"));

        Assert.True(result.Succeeded);
        Assert.Equal(200, result.StatusCode);
        Assert.Equal("re_1", result.ProviderMessageId);
        Assert.Contains("re_1", result.ResponseBody);
        Assert.Equal(HttpMethod.Post, captured!.Method);
        Assert.Equal(ResendEmailSender.EmailsUrl, captured.RequestUri!.ToString());
        Assert.Equal("Bearer", captured.Headers.Authorization!.Scheme);
        Assert.Equal("re_test", captured.Headers.Authorization.Parameter);
        Assert.Contains("\"from\":\"from@demo.com\"", requestJson);
        Assert.Contains("\"to\":[\"a@b.com\"]", requestJson);
        Assert.Contains("\"subject\":\"Hello\"", requestJson);
        Assert.Contains("\"text\":\"plain\"", requestJson);
        Assert.DoesNotContain("html", requestJson);
    }

    [Fact]
    public async Task SendAsync_failed_status_is_not_success()
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.UnprocessableEntity)
        {
            Content = new StringContent("invalid from")
        });
        var sender = new ResendEmailSender(new StubFactory(new HttpClient(handler)));

        var result = await sender.SendAsync(
            new ValidatedEmailMessage("a@b.com", "Hello", "plain"),
            new ResendSettings("re_test", "from@demo.com"));

        Assert.False(result.Succeeded);
        Assert.Equal(422, result.StatusCode);
        Assert.Equal("invalid from", result.ResponseBody);
    }

    private sealed class StubHandler : HttpMessageHandler
    {
        private readonly Func<HttpRequestMessage, HttpResponseMessage> _respond;

        public StubHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) => _respond = respond;

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken) =>
            Task.FromResult(_respond(request));
    }

    private sealed class StubFactory : IHttpClientFactory
    {
        private readonly HttpClient _client;

        public StubFactory(HttpClient client) => _client = client;

        public HttpClient CreateClient(string name) => _client;
    }
}
