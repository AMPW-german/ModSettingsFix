using Brutal.ImGuiApi;
using HarmonyLib;
using StarMap.API;

namespace ModSettingsFix;

[StarMapMod]
public class ModSettingsFix
{
    [StarMapBeforeMain]
    public void BeforeMain()
    {
        try
        {
            new Harmony("ModSettingsFix").PatchAll(typeof(ModSettingsFixPatch).Assembly);
            Console.WriteLine("ModSettingsFix: Harmony patches applied.");
        }
        catch (Exception exception)
        {
            Console.WriteLine($"ModSettingsFix: failed to apply Harmony patches: {exception}");
        }
    }
}
