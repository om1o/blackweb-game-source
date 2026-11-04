using UnrealBuildTool;
using System.Collections.Generic;

public class BlackwebEditorTarget : TargetRules
{
    public BlackwebEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V4;
        IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_3;
        ExtraModuleNames.Add("Blackweb");
    }
}
