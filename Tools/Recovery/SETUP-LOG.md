# Setup observations

- Portable SDK requested from official Microsoft installer: .NET 10.0.403, win-x64, archive URL `https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.403/dotnet-sdk-10.0.403-win-x64.zip`, downloaded size 300745255 bytes.
- SDK, temp, CLI home, NuGet packages and HTTP cache are assigned to `D:\CodexTemp\Arachnophobia-Blackweb-20261103\work`.
- An early build attempted before SDK extraction finished failed because Microsoft.NET.Sdk was not yet available. This is not an exporter compile result. Subsequent builds must wait for installer completion.
- Despite setting `DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1`, first SDK invocation created an **untrusted** ASP.NET Core HTTPS development certificate. No trust command was run. Subsequent launcher calls set `DOTNET_GENERATE_ASPNET_CERTIFICATE=false`.
- The new certificate was positively identified in `Cert:\CurrentUser\My`: thumbprint `2DCD71E3822688691132E1D4B2C9B4C8D5A67369`, subject `CN=localhost`, friendly name `ASP.NET Core HTTPS development certificate`, validity starting `2026-11-03 14:13:45` local time during this SDK first-run.
- A guarded attempt to remove only that exact certificate and its key was rejected by automatic approval policy with `blocked by policy`. No alternative removal was attempted. The certificate therefore remains an unintended setup artifact, untrusted. Existing certificates were not modified.
