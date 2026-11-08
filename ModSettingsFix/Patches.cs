using HarmonyLib;
using KSA;

namespace ModSettingsFix;

[HarmonyPatch]
public static class ModSettingsFixPatch
{
    [HarmonyPatch(typeof(ModLibrary), nameof(ModLibrary.PrepareAll))]
    [HarmonyPostfix]
    public static void AfterPrepareAll()
    {
        try
        {
            var mods = ModLibrary.Manifest?.Mods;
            if (mods is not null)
            {
                for (var index = 0; index < mods.Count; index++)
                {
                    mods[index].Index = index;
                    Console.WriteLine($"Mod {mods[index].Id} index set to {index}");
                }
            }
        }
        catch (Exception exception)
        {
            Console.WriteLine($"ModSettingsFix: failed to normalize mod indices: {exception}");
        }
    }
}
