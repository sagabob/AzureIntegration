using Microsoft.Extensions.Logging.Abstractions;
using Moq;

namespace TwilioEmail.Tests;

public class SendEmailTests
{
    private static readonly ResendSettings Settings = new("re_test", "from@demo.com");
    private const string ValidQueueJson = """{"to":"a@b.com","subject":"s","body":"b"}""";

    [Fact]
    public async Task Run_does_not_throw_when_Resend_accepts()
    {
        var resend = new Mock<IResendEmailSender>();
        resend
            .Setup(s => s.SendAsync(
                It.Is<ValidatedEmailMessage>(m => m.To == "a@b.com" && m.Subject == "s" && m.Body == "b"),
                Settings,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ResendSendResult(200, "{}", """{"id":"re_1"}"""));

        var fn = new SendEmail(resend.Object, Settings, NullLogger<SendEmail>.Instance);

        await fn.Run(ValidQueueJson);
        resend.VerifyAll();
    }

    [Fact]
    public async Task Run_throws_when_Resend_rejects()
    {
        var resend = new Mock<IResendEmailSender>();
        resend
            .Setup(s => s.SendAsync(
                It.IsAny<ValidatedEmailMessage>(),
                It.IsAny<ResendSettings>(),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ResendSendResult(422, "{}", "invalid"));

        var fn = new SendEmail(resend.Object, Settings, NullLogger<SendEmail>.Instance);

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() => fn.Run(ValidQueueJson));
        Assert.Contains("422", error.Message);
    }

    [Fact]
    public async Task Run_throws_before_Resend_when_queue_json_is_invalid()
    {
        var resend = new Mock<IResendEmailSender>(MockBehavior.Strict);
        var fn = new SendEmail(resend.Object, Settings, NullLogger<SendEmail>.Instance);

        await Assert.ThrowsAsync<InvalidOperationException>(() => fn.Run("{}"));
        resend.VerifyNoOtherCalls();
    }
}
