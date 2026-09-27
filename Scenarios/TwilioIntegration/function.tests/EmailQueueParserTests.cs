namespace TwilioEmail.Tests;

public class EmailQueueParserTests
{
    [Fact]
    public void Parse_trims_to_and_subject()
    {
        var parsed = EmailQueueParser.Parse("""{"to":" a@b.com ","subject":" Hi ","body":"ok"}""");

        Assert.Equal("a@b.com", parsed.To);
        Assert.Equal("Hi", parsed.Subject);
        Assert.Equal("ok", parsed.Body);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("{}")]
    [InlineData("""{"to":"a@b.com","subject":"s"}""")]
    [InlineData("not-json")]
    public void Parse_rejects_incomplete_messages(string? message)
    {
        Assert.Throws<InvalidOperationException>(() => EmailQueueParser.Parse(message));
    }

    [Theory]
    [InlineData("not-an-email")]
    [InlineData("foo@")]
    [InlineData("foo@bar")]
    [InlineData("a @b.com")]
    public void Parse_rejects_malformed_to(string to)
    {
        var message = $$"""{"to":"{{to}}","subject":"s","body":"b"}""";
        var error = Assert.Throws<InvalidOperationException>(() => EmailQueueParser.Parse(message));
        Assert.Contains("well-formed", error.Message);
    }

    [Fact]
    public void Parse_accepts_plus_tag_address()
    {
        var parsed = EmailQueueParser.Parse("""{"to":"user+tag@example.com","subject":"s","body":"b"}""");
        Assert.Equal("user+tag@example.com", parsed.To);
        Assert.Null(parsed.Id);
    }

    [Fact]
    public void Parse_reads_request_id()
    {
        var parsed = EmailQueueParser.Parse("""{"id":" req-1 ","to":"a@b.com","subject":"s","body":"b"}""");
        Assert.Equal("req-1", parsed.Id);
    }
}
