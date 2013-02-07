/**
* CS:GO Skins Chooser by Root
*
* Description:
*   Changes player's model on the fly without editing any configuration files.
*
* Version 1.1
* Changelog & more info at http://goo.gl/4nKhJ
*/

// ====[ SEMICOLON ]===========================================================
#pragma semicolon 1

// ====[ INCLUDES ]============================================================
#include <sdktools>
#include <cstrike>
#undef REQUIRE_PLUGIN
#include <updater>

// ====[ CONSTANTS ]===========================================================
#define PLUGIN_NAME    "CS:GO Skins Chooser"
#define PLUGIN_VERSION "1.1"
#define UPDATE_URL     "https://raw.github.com/zadroot/CSGO_SkinsChooser/master/updater.txt"
#define RANDOM_MODEL   0x64

// ====[ VARIABLES ]===========================================================
new	Handle:sc_enable     = INVALID_HANDLE,
	Handle:sc_random     = INVALID_HANDLE,
	Handle:sc_changetype = INVALID_HANDLE,
	Handle:sc_admflag    = INVALID_HANDLE,
	Handle:t_skins_menu  = INVALID_HANDLE,
	Handle:ct_skins_menu = INVALID_HANDLE,
	String:TerrorSkin[PLATFORM_MAX_PATH][64],
	String:CTerrorSkin[PLATFORM_MAX_PATH][64],
	AdmFlag, ConfigLevel, TSkins_All, CTSkins_All, ChosenSkin[MAXPLAYERS + 1];

// ====[ PLUGIN ]==============================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Simply skin chooser for CS:GO",
	version     = PLUGIN_VERSION,
	url         = "forums.alliedmods.net/showthread.php?p=1889086"
};


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ---------------------------------------------------------------------------- */
public OnPluginStart()
{
	// Create console variables
	CreateConVar("sm_csgo_skins_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY);
	sc_enable     = CreateConVar("sm_csgo_skins_enable",  "1", "Whether or not enable CS:GO Skins Chooser plugin",                                   FCVAR_PLUGIN, true, 0.0, true, 1.0);
	sc_random     = CreateConVar("sm_csgo_skins_random",  "1", "Whether or not randomly change models for all players on every respawn",             FCVAR_PLUGIN, true, 0.0, true, 1.0);
	sc_changetype = CreateConVar("sm_csgo_skins_change",  "0", "Determines when change selected player skin:\n0 = On next respawn\1 = Immediately",  FCVAR_PLUGIN, true, 0.0, true, 1.0);
	sc_admflag    = CreateConVar("sm_csgo_skins_admflag", "",  "If flag is specified (a-z), only admins with that flag will able to use skins menu", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	// Create/register client commands
	RegConsoleCmd("skin",   Command_SkinsMenu);
	RegConsoleCmd("skins",  Command_SkinsMenu);
	RegConsoleCmd("model",  Command_SkinsMenu);

	// Hook respawn_post event
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);

	// Create and exec plugin configuration file
	AutoExecConfig(true, "csgo_skins");

	if (LibraryExists("updater"))
	{
		// Adds plugin to the updater
		Updater_AddPlugin(UPDATE_URL);
	}
}

/* OnMapStart()
 *
 * When the map starts.
 * ---------------------------------------------------------------------------- */
public OnMapStart()
{
	// Declare string to load skin's config from sourcemod/configs folder
	decl String:file[PLATFORM_MAX_PATH], String:curmap[64];

	// Get current map
	GetCurrentMap(curmap, sizeof(curmap));

	// Let's check that custom skin configuration file is exists for this map
	BuildPath(Path_SM, file, sizeof(file), "configs/skins/%s.ini", curmap);

	// Could not read config for new map
	if (!FileExists(file))
	{
		// Then use default one
		BuildPath(Path_SM, file, sizeof(file), "configs/skins/any.ini");

		// No config?
		if (!FileExists(file)) SetFailState("\nUnable to open base configuration file: \"%s\"!", file);
	}

	// Create menus and parse a config then
	PrepareMenus();
	ParseConfigFile(file);
}

/* OnLibraryAdded()
 *
 * Called after a library is added that the current plugin references.
 * ---------------------------------------------------------------------------- */
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

/* OnPlayerSpawn()
 *
 * Called after a player spawns.
 * ---------------------------------------------------------------------------- */
public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Skip event if plugin is disabled
	if (GetConVarBool(sc_enable))
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		// Plugin should work only with valid clients
		if (IsValidClient(client))
		{
			// Get chosen model if avalible
			new model = ChosenSkin[client];

			// Set skin depends on client's team
			switch (GetClientTeam(client))
			{
				case CS_TEAM_T: // Terrorists
				{
					// If random model should be accepted, get random skin of all avalible skins
					if (GetConVarBool(sc_random) && !ChosenSkin[client])
					{
						SetEntityModel(client, TerrorSkin[GetRandomInt(0, TSkins_All-1)]);
					}
					else if (model > 0 && model <= TSkins_All)
					{
						SetEntityModel(client, TerrorSkin[model]);
					}
				}
				case CS_TEAM_CT: // Counter-Terrorists
				{
					// Also make sure that player havent chosen any skin yet
					if (GetConVarBool(sc_random) && !ChosenSkin[client])
					{
						SetEntityModel(client, CTerrorSkin[GetRandomInt(0, TSkins_All-1)]);
					}

					// Model index should be between zero and max amount of avalible skins
					else if (model > 0 && model <= CTSkins_All)
					{
						// And set the model
						SetEntityModel(client, CTerrorSkin[model]);
					}
				}
			}
		}
	}
}

/* Command_SkinsMenu()
 *
 * Shows skin's menu to a player.
 * ---------------------------------------------------------------------------- */
public Action:Command_SkinsMenu(client, args)
{
	if (GetConVarBool(sc_enable))
	{
		// Once again make sure that client is valid
		if (IsValidClient(client) || !GetConVarBool(sc_changetype))
		{
			// Get flag name from convar string and get client's access
			decl String:admflag[2];
			GetConVarString(sc_admflag, admflag, sizeof(admflag));

			// Converts a string of flag characters to a bit string
			AdmFlag = ReadFlagString(admflag);

			// Check if player is having any access (including NO-privilegies)
			if (AdmFlag == 0
			|| (AdmFlag >  0 && CheckCommandAccess(client, NULL_STRING, AdmFlag, true)))
			{
				// Show individual skin menu depends on client's team
				switch (GetClientTeam(client))
				{
					case CS_TEAM_T:  if (t_skins_menu  != INVALID_HANDLE) DisplayMenu(t_skins_menu,  client, MENU_TIME_FOREVER);
					case CS_TEAM_CT: if (ct_skins_menu != INVALID_HANDLE) DisplayMenu(ct_skins_menu, client, MENU_TIME_FOREVER);
				}
			}
		}
	}

	// That thing fixing 'unknown command' in client console on command call
	return Plugin_Handled;
}

/* MenuHandler_ChooseSkin()
 *
 * Menu to set player's skin.
 * ---------------------------------------------------------------------------- */
public MenuHandler_ChooseSkin(Handle:menu, MenuAction:action, client, param)
{
	// Called when player pressed something in a menu
	if (action == MenuAction_Select)
	{
		// Get model index which is covered under this title
		decl String:skin_id[32]; GetMenuItem(menu, param, skin_id, sizeof(skin_id));
		new skin = StringToInt(skin_id, sizeof(skin_id));

		// Save 'the chosen one'
		ChosenSkin[client] = skin;

		// Set player model immediately if needed
		if (GetConVarBool(sc_changetype))
		{
			// Depends on client team obviously
			switch (GetClientTeam(client))
			{
				case CS_TEAM_T:  SetEntityModel(client,  TerrorSkin[skin]);
				case CS_TEAM_CT: SetEntityModel(client, CTerrorSkin[skin]);
			}
		}
	}
}

/* PrepareMenus()
 *
 * Create menus if config is valid.
 * ---------------------------------------------------------------------------- */
PrepareMenus()
{
	// At first we should reset amount of avalible t/ct skins
	TSkins_All = 0, CTSkins_All = 0;

	// Then make sure that menu handler is closed
	if (t_skins_menu != INVALID_HANDLE)
	{
		CloseHandle(t_skins_menu);
		t_skins_menu = INVALID_HANDLE;
	}

	// For T and CT teams
	if (ct_skins_menu != INVALID_HANDLE)
	{
		CloseHandle(ct_skins_menu);
		ct_skins_menu = INVALID_HANDLE;
	}

	// Create specified menus depends on client teams
	t_skins_menu  = CreateMenu(MenuHandler_ChooseSkin, MenuAction_Select);
	ct_skins_menu = CreateMenu(MenuHandler_ChooseSkin, MenuAction_Select);

	// And finally set the menu's titles
	SetMenuTitle(t_skins_menu,  "Choose your Terrorist skin:");
	SetMenuTitle(ct_skins_menu, "Choose your Counter-Terrorist skin:");

	// Add random skins option if feature is enabled
	if (GetConVarBool(sc_random))
	{
		AddMenuItem(t_skins_menu,  NULL_STRING, "Random");
		AddMenuItem(ct_skins_menu, NULL_STRING, "Random");
	}
}

/* ParseConfigFile()
 *
 * Parses a config file.
 * ---------------------------------------------------------------------------- */
bool:ParseConfigFile(const String:file[])
{
	// Create parser with all sections (start & end)
	new Handle:parser = SMC_CreateParser();
	SMC_SetReaders (parser, Config_NewSection, Config_UnknownKeyValue, Config_EndSection);
	SMC_SetParseEnd(parser, Config_End);

	// Checking for error
	new String:error[256], line, col, SMCError:result = SMC_ParseFile(parser, file, line, col);

	// Close handle
	CloseHandle(parser);

	// Check result
	if (result != SMCError_Okay)
	{
		SMC_GetErrorString(result, error, sizeof(error));
		LogError("%s on line %i, col %i of %s", error, line, col, file);
	}
	return (result == SMCError_Okay);
}

/* Config_NewSection()
 *
 * Called when the parser is entering a new section or sub-section.
 * ---------------------------------------------------------------------------- */
public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes)
{
	// Ignore first config level ("Skins")
	ConfigLevel++;

	// Checking second config level
	if (ConfigLevel == 2)
	{
		// Checking if menu names is correct
		if (StrEqual("Terrorists", section, false))
			SMC_SetReaders(parser, Config_NewSection, Config_TerroristSkins, Config_EndSection);

		/* If correct - sets the three main reader functions */
		else if (StrEqual("Counter-Terrorists", section, false))
			SMC_SetReaders(parser, Config_NewSection, Config_CounterTerroristSkins, Config_EndSection);
	}
	// Anyway create pointers
	else SMC_SetReaders(parser, Config_NewSection, Config_UnknownKeyValue, Config_EndSection);
	return SMCParse_Continue;
}

/* Config_UnknownKeyValue()
 *
 * Called when the parser finds a new key/value pair.
 * ---------------------------------------------------------------------------- */
public SMCResult:Config_UnknownKeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	// Disable a plugin if unknown key value found in a config file
	SetFailState("\nDidn't recognize configuration: %s = %s!", key, value);
	return SMCParse_Continue;
}

/* Config_TerroristSkins()
 *
 * Called when the parser finds a first key/value pair.
 * ---------------------------------------------------------------------------- */
public SMCResult:Config_TerroristSkins(Handle:parser, const String:skin_fullpath[], const String:skin_name[], bool:key_quotes, bool:value_quotes)
{
	// Copy the full path of skin from config and save it
	decl String:skin_id[3];
	strcopy(TerrorSkin[TSkins_All], sizeof(TerrorSkin[]), skin_fullpath);

	// Calculate number of avalible terror skins
	FormatEx(skin_id, sizeof(skin_id), "%02.2X", TSkins_All++);
	AddMenuItem(t_skins_menu, skin_id, skin_name);

	// Precache every added model
	PrecacheModel(skin_fullpath);
	return SMCParse_Continue;
}

/* Config_CounterTerroristSkins()
 *
 * Called when the parser finds a second key/value pair.
 * ---------------------------------------------------------------------------- */
public SMCResult:Config_CounterTerroristSkins(Handle:parser, const String:skin_fullpath[], const String:skin_name[], bool:key_quotes, bool:value_quotes)
{
	decl String:skin_id[3];
	strcopy(CTerrorSkin[CTSkins_All], sizeof(CTerrorSkin[]), skin_fullpath);
	FormatEx(skin_id, sizeof(skin_id), "%02.2X", CTSkins_All++);

	// Add every skin as a CT menu item
	AddMenuItem(ct_skins_menu, skin_id, skin_name);

	// To prevent client crashes
	PrecacheModel(skin_fullpath);

	// continue
	return SMCParse_Continue;
}

/* Config_EndSection()
 *
 * Called when the parser finds the end of the current section.
 * ---------------------------------------------------------------------------- */
public SMCResult:Config_EndSection(Handle:parser)
{
	// Config is ready - return to original level ("Skins")
	ConfigLevel--;

	// I prefer textparse, because there is possible to easy add/remove weapons/sections with no issues
	SMC_SetReaders(parser, Config_NewSection, Config_UnknownKeyValue, Config_EndSection);
	return SMCParse_Continue;
}

/* Config_End()
 *
 * Called when the config is ready.
 * ---------------------------------------------------------------------------- */
public Config_End(Handle:parser, bool:halted, bool:failed)
{
	// Disable plugin because something is wroung around
	if (failed) SetFailState("\nPlugin configuration error!");
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * ---------------------------------------------------------------------------- */
bool:IsValidClient(client)
{
	// Default 'valid player' checking
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)) ? true : false;
}