using UnrealBuildTool;

public class Blackweb : ModuleRules
{
    public Blackweb(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        CppStandard = CppStandardVersion.Cpp17;
        PublicDependencyModuleNames.AddRange(new[] { "Core", "CoreUObject", "Engine", "InputCore", "AIModule", "NavigationSystem" });
    }
}
