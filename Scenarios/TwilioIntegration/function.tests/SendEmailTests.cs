using Microsoft.Extensions.Logging.Abstractions;
using Moq;

namespace TwilioEmail.Tests;

public class SendEmailTests
{
    private static readonly ResendSettings Settings = new("re_test", "from@demo.com");
    private const string ValidQueueJson = """{"id":"req-1","to":"a@b.com","subject":"s","body":"b"}""";

    [Fact]
    public async Task Run_does_not_throw_when_Resend_accepts()
    {
        var resend = new Mock<IResendEmailSender>();
        resend
            .Setup(s => s.SendAsync(
                It.Is<ValidatedEmailMessage>(m => m.To == "a@b.com" && m.Subject == "s" && m.Body == "b" && m.Id == "req-1"),
                Settings,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ResendSendResult(200, "{}", """{"id":"re_1"}"""));
        var status = new Mock<IMessageStatusStore>();
        status
            .Setup(s => s.EnsureQueuedAsync(
                MessageStatuses.EmailPartition,
                "req-1",
                ValidQueueJson,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new MessageTableRow(MessageStatuses.Queued, null, ValidQueueJson));

        var fn = new SendEmail(resend.Object, status.Object, Settings, NullLogger<SendEmail>.Instance);

        await fn.Run(ValidQueueJson);
        resend.VerifyAll();
        status.Verify(s => s.SetStatusAsync(
            MessageStatuses.EmailPartition,
            "req-1",
            MessageStatuses.Sent,
            "re_1",
            It.IsAny<CancellationToken>()));
    }

    [Fact]
    public async Task Run_skips_Resend_when_table_already_sent()
    {
        var resend = new Mock<IResendEmailSender>(MockBehavior.Strict);
        var status = new Mock<IMessageStatusStore>();
        status
            .Setup(s => s.EnsureQueuedAsync(
                MessageStatuses.EmailPartition,
                "req-1",
                ValidQueueJson,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new MessageTableRow(MessageStatuses.Sent, "re_existing", ValidQueueJson));

        var fn = new SendEmail(resend.Object, status.Object, Settings, NullLogger<SendEmail>.Instance);

        await fn.Run(ValidQueueJson);
        resend.VerifyNoOtherCalls();
        status.Verify(s => s.SetStatusAsync(
            It.IsAny<string>(),
            It.IsAny<string?>(),
            It.IsAny<string>(),
            It.IsAny<string?>(),
            It.IsAny<CancellationToken>()), Times.Never);
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
        var status = new Mock<IMessageStatusStore>();
        status
            .Setup(s => s.EnsureQueuedAsync(
                MessageStatuses.EmailPartition,
                "req-1",
                ValidQueueJson,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new MessageTableRow(MessageStatuses.Queued, null, ValidQueueJson));

        var fn = new SendEmail(resend.Object, status.Object, Settings, NullLogger<SendEmail>.Instance);

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() => fn.Run(ValidQueueJson));
        Assert.Contains("422", error.Message);
        status.Verify(s => s.SetStatusAsync(
            MessageStatuses.EmailPartition,
            "req-1",
            MessageStatuses.Failed,
            null,
            It.IsAny<CancellationToken>()));
    }

    [Fact]
    public async Task Run_throws_before_Resend_when_queue_json_is_invalid()
    {
        var resend = new Mock<IResendEmailSender>(MockBehavior.Strict);
        var status = new Mock<IMessageStatusStore>(MockBehavior.Strict);
        var fn = new SendEmail(resend.Object, status.Object, Settings, NullLogger<SendEmail>.Instance);

        await Assert.ThrowsAsync<InvalidOperationException>(() => fn.Run("{}"));
        resend.VerifyNoOtherCalls();
        status.VerifyNoOtherCalls();
    }
}
