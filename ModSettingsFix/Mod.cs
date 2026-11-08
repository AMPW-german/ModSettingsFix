using Brutal.ImGuiApi;
using HarmonyLib;
using StarMap.API;

namespace ModSettingsFix;

[StarMapMod]
public class ModSettingsFix
{
	private bool _showWelcome = true;

	[StarMapAllModsLoaded]
	public void AllModsLoaded()
	{
		new Harmony("ModSettingsFix").PatchAll();
	}

	[StarMapAfterGui]
	public void AfterGui(double dt)
	{
		if (!_showWelcome)
			return;

		if (ImGui.Begin("Welcome to ModSettingsFix", ref _showWelcome, ImGuiWindowFlags.NoSavedSettings))
		{
			ImGui.Text("Hello from ModSettingsFix!");
			ImGui.TextDisabled("This window is drawn from [StarMapAfterGui]. Close it to dismiss.");
			ImGui.End();
		}
	}
}
