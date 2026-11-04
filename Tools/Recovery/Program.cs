using CUE4Parse;
using CUE4Parse.Compression;
using CUE4Parse.FileProvider;
using CUE4Parse.MappingsProvider.Usmap;
using CUE4Parse.UE4.Assets.Exports;
using CUE4Parse.UE4.Assets.Exports.Animation;
using CUE4Parse.UE4.Assets.Exports.Engine;
using CUE4Parse.UE4.Assets.Exports.StaticMesh;
using CUE4Parse.UE4.Assets.Exports.Texture;
using CUE4Parse.UE4.Assets.Exports.Sound;
using CUE4Parse_Conversion.Sounds;
using CUE4Parse.UE4.Objects.Engine;
using CUE4Parse.UE4.Versions;
using CUE4Parse_Conversion;
using CUE4Parse_Conversion.Dto;
using CUE4Parse_Conversion.Options;
using Newtonsoft.Json;
using Serilog;

var options = Parse(args);
var input = Required(options, "input");
var output = Path.GetFullPath(Required(options, "out"));
var formatName = options.GetValueOrDefault("format")?.FirstOrDefault() ?? "USD";
var format = Enum.Parse<EMeshFormat>(formatName, true);
var packages = options.GetValueOrDefault("package") ?? [];
if (options.TryGetValue("packages-file", out var listFiles))
    foreach (var listFile in listFiles) packages.AddRange(File.ReadAllLines(listFile).Select(s => s.Trim()).Where(s => s.Length > 0 && !s.StartsWith("#")));
Directory.CreateDirectory(output);
var logPath = Path.Combine(output, "recovery-results.jsonl");
var json = new JsonSerializerSettings { Formatting = Formatting.Indented, ReferenceLoopHandling = ReferenceLoopHandling.Ignore };
Log.Logger = new LoggerConfiguration().MinimumLevel.Information().WriteTo.Console().CreateLogger();
CUE4ParseLog.UseLogger(Log.Logger);
var nativeDirectory = options.GetValueOrDefault("native-dir")?.FirstOrDefault() ?? AppContext.BaseDirectory;
Directory.CreateDirectory(nativeDirectory);
if (!options.ContainsKey("loose"))
    await OodleHelper.InitializeAsync(Path.Combine(nativeDirectory, OodleHelper.OodleFileName));

using var provider = new DefaultFileProvider(input, SearchOption.AllDirectories,
    new VersionContainer(EGame.GAME_UE5_3), StringComparer.OrdinalIgnoreCase);
if (options.TryGetValue("mappings", out var mapping))
    provider.MappingsContainer = new FileUsmapTypeMappingsProvider(mapping.Single());
provider.Initialize();
provider.Mount();
provider.PostMount();
Console.WriteLine($"Indexed {provider.Files.Count} files; engine UE5.3; output {output}; format {format}.");
if (options.ContainsKey("all-project"))
    packages = provider.Files.Keys.Where(x => x.StartsWith("Arachnophobia/Content/", StringComparison.OrdinalIgnoreCase)
        && (x.EndsWith(".uasset", StringComparison.OrdinalIgnoreCase) || x.EndsWith(".umap", StringComparison.OrdinalIgnoreCase)))
        .OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList();
if (packages.Count == 0) throw new ArgumentException("Supply --package paths or --all-project.");

var failureCount = 0;
foreach (var packagePath in packages.Distinct(StringComparer.OrdinalIgnoreCase))
{
    Console.WriteLine($"LOAD {packagePath}");
    var started = DateTimeOffset.UtcNow;
    try
    {
        var package = provider.LoadPackage(packagePath);
        var exports = package.GetExports().ToArray();
        var relative = packagePath.Replace('\\', '/').TrimStart('/');
        if (relative.Split('/').Any(x => x is ".." or ".")) throw new ArgumentException("Unexpected path traversal in asset path.");
        var evidencePath = Path.Combine(output, "Metadata", relative + ".json");
        Directory.CreateDirectory(Path.GetDirectoryName(evidencePath)!);
        File.WriteAllText(evidencePath, JsonConvert.SerializeObject(exports, json));
        var types = exports.Select(x => new { x.Name, ClrType = x.GetType().FullName, ObjectPath = x.GetPathName() }).ToArray();
        var session = new ExportSession { MaxDegreeOfParallelism = 2 };
        foreach (var obj in exports)
        {
            if (obj is UWorld world)
            {
                try
                {
                    using var dto = new WorldDto(world);
                    File.WriteAllText(evidencePath + ".scene.json", JsonConvert.SerializeObject(dto, json));
                    Console.WriteLine($"WORLD {world.Name}: {dto.Actors.Count} root actors, {dto.StreamingLevels.Count} streaming levels");
                    Record(new { packagePath, stage = "scene-metadata", parsed = true, rootActors = dto.Actors.Count,
                        streamingLevels = dto.StreamingLevels.Count, metadata = evidencePath + ".scene.json" });
                }
                catch (Exception sceneError)
                {
                    failureCount++;
                    Record(new { packagePath, stage = "scene-metadata", parsed = true, error = sceneError.ToString() });
                    Console.WriteLine($"SCENE METADATA FAIL {world.Name}: {sceneError.Message}");
                }
            }
            if (options.ContainsKey("metadata-only")) continue;
            if (obj is USoundWave sound)
            {
                try
                {
                    sound.Decode(true, out var audioFormat, out var audioData);
                    if (audioData is null || audioData.Length == 0) throw new NotSupportedException("No decoded sound data returned.");
                    var extension = new string(audioFormat.ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());
                    if (extension.Length == 0) extension = "bin";
                    var soundPath = Path.Combine(output, "Audio", Path.ChangeExtension(relative, extension));
                    Directory.CreateDirectory(Path.GetDirectoryName(soundPath)!);
                    File.WriteAllBytes(soundPath, audioData);
                    var magic = System.Text.Encoding.ASCII.GetString(audioData, 0, Math.Min(4, audioData.Length));
                    var playableContainer = magic is "OggS" or "RIFF" or "fLaC";
                    Record(new { packagePath, stage = "sound", parsed = true, soundPath, audioFormat, bytes = audioData.Length, playableContainer });
                    Console.WriteLine($"SOUND {(playableContainer ? "CONTAINER OK" : "RAW CODEC ONLY")} {soundPath}: {audioFormat}, {audioData.Length} bytes");
                }
                catch (Exception soundError)
                {
                    failureCount++;
                    Record(new { packagePath, stage = "sound", parsed = true, error = soundError.ToString() });
                    Console.WriteLine($"SOUND FAIL {sound.Name}: {soundError.Message}");
                }
                continue;
            }
            if (obj is UWorld && format != EMeshFormat.USD) continue;
            if (obj is UAnimationAsset && format == EMeshFormat.Gltf2) continue;
            if (obj is UWorld or UStaticMesh or USkinnedAsset or UTexture or USkeleton or UAnimationAsset)
                session.Add(obj);
        }
        var results = session.HasQueuedItems
            ? await session.RunAsync(output, new ExportOptions(meshFormat: format, exportMaterials: !options.ContainsKey("geometry-only")))
            : [];
        foreach (var result in results)
        {
            if (!result.Success) failureCount++;
            Console.WriteLine($"EXPORT {(result.Success ? "OK" : "FAIL")} {result.ObjectPath}: {result.Error?.Message}");
        }
        Record(new { packagePath, started, completed = DateTimeOffset.UtcNow, parsed = true, metadata = evidencePath,
            exports = types, results = results.Select(r => new { r.Success, r.ObjectPath, r.DiskFilePaths, error = r.Error?.ToString() }) });
    }
    catch (Exception ex)
    {
        failureCount++;
        Console.WriteLine($"PACKAGE FAIL {packagePath}: {ex}");
        Record(new { packagePath, started, completed = DateTimeOffset.UtcNow, parsed = false, error = ex.ToString() });
    }
}
Environment.ExitCode = failureCount == 0 ? 0 : 1;
Console.WriteLine($"Done: {packages.Count} input packages, {failureCount} reported failures. See {logPath}");

void Record(object item) => File.AppendAllText(logPath, JsonConvert.SerializeObject(item, Formatting.None) + Environment.NewLine);

static string Required(Dictionary<string,List<string>> options, string name)
    => options.TryGetValue(name, out var values) && values.Count == 1 ? values[0] : throw new ArgumentException($"Expected --{name} value.");

static Dictionary<string,List<string>> Parse(string[] input)
{
    var result = new Dictionary<string,List<string>>(StringComparer.OrdinalIgnoreCase);
    string? key = null;
    foreach (var item in input)
    {
        if (item.StartsWith("--"))
        {
            key = item[2..];
            result.TryAdd(key, []);
        }
        else if (key is not null) result[key].Add(item);
        else throw new ArgumentException($"Unexpected argument {item}");
    }
    return result;
}
