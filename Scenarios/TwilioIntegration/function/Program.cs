using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using TwilioEmail;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        services.AddHttpClient<SendEmail>(client =>
        {
            client.BaseAddress = new Uri("https://api.resend.com/");
            client.Timeout = TimeSpan.FromSeconds(30);
        });
    })
    .Build();

host.Run();
