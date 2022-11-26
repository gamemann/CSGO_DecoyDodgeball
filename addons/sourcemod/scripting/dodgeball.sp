#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define MAXENTITIES 2048
#define PL_VERSION "1.1"

public Plugin myinfo = 
{
	name = "[CS:GO] Decoy Dodgeball (Stable)",
	author = "Roy (Christian Deacon)",
	description = "A Decoy Dodgeball plugin for Counter-Strike: Global Offensive.",
	version = PL_VERSION,
	url = "GFLClan.com & TheDevelopingCommunity.com & Alliedmods.net"
};

// ConVars
ConVar g_hGiveTime = null;
ConVar g_hPrint = null;
ConVar g_hRemovetimer = null;
ConVar g_hBounces = null;
ConVar g_hRandom = null;
ConVar g_hRandomMax = null;
ConVar g_hRandomMin = null;
ConVar g_hRoundStartAdvert = null;
ConVar g_hClientHealth = null;
ConVar g_hClientArmor = null;
ConVar g_hDBDamage = null;
ConVar g_hDebug = null;
ConVar g_hMinigamesMode = null;
ConVar g_hAutoMode = null;
ConVar g_hLogFile = null;
ConVar g_hEnabled = null;
ConVar g_hGEnabled = null;
ConVar g_hBotThrow = null;

// ConVar Values
float g_fGiveTime;
bool g_bPrint;
float g_fRemoveTimer;
int g_iBounces;
int g_iRandom;
int g_iRandomMax;
int g_iRandomMin;
bool g_bRoundStartAd;
int g_iClientHealth;
int g_iClientArmor;
float g_fDBDamage;
bool g_bDebug;
bool g_bMinigames;
bool g_bAutoMode;
char g_sLogFile[PLATFORM_MAX_PATH];
bool g_bEnabled;
bool g_bGEnabled;
bool g_bBotThrow;

// Other Values
int g_iBounceCount[MAXENTITIES+1];
int g_iBouncesRand;	
int g_iBouncesRandClient[MAXPLAYERS+1];
char g_sRECC2[MAX_NAME_LENGTH];
char g_sLogFilePath[PLATFORM_MAX_PATH];
bool g_bPlayerThrow[MAXPLAYERS+1];
Handle g_hBotResetTimer = null;
Handle g_hRemoveTimer = null;

public void OnPluginStart() 
{
	// Events.
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	// Convars.
	g_hGiveTime = CreateConVar("sm_db_give_time", "1.0", "The delay on giving decoys after being thrown.");
	g_hPrint = CreateConVar("sm_db_equip_notify", "0", "Whether to print to chat or not when a client spawns with a dodgeball.");
	g_hRemovetimer = CreateConVar("sm_db_remove_timer", "30.0", "Every X seconds, it will remove all decoys on the map.");
	g_hBounces = CreateConVar("sm_db_bounces", "1", "Amount of bounces the decoy can have (off a surface), before destroying. This is ineffective if random mode is on.");
	g_hRandom = CreateConVar("sm_db_random", "0", "If enabled, a random number depending on \"sm_db_random_max\" and \"sm_db_random_min\" will be used for the amount of bounces a decoy (dodgeball) can have. (1 = Mode 1, 2 = Mode 2, 3 = Mode 3 0 = Off). More information about the modes on the AlliedMods thread.");
	g_hRandomMax = CreateConVar("sm_db_random_max", "3", "The maximum amount of bounces the decoy (dodgeball) can have using random mode.");
	g_hRandomMin = CreateConVar("sm_db_random_min", "1", "The minimum amount of bounces the decoy (dodgeball) can have using random mode.");
	g_hRoundStartAdvert = CreateConVar("sm_db_rs_advert", "1", "Enables the Round Start advertisement.");
	g_hClientHealth = CreateConVar("sm_db_client_health", "1", "Set the health to this number on client spawn.");
	g_hClientArmor = CreateConVar("sm_db_client_armor", "0", "Set the armor to this number on client spawn.");
	g_hDBDamage = CreateConVar("sm_db_damage", "200.0", "The amount of damage the decoys (dodgeballs) do.");
	g_hDebug = CreateConVar("sm_db_debug", "0", "Enables debugging for dodgeball (will spam the SourceMod logs if enabled).");
	g_hMinigamesMode = CreateConVar("sm_db_minigames", "0", "Enables the Minigames mode. More information about this on the AlliedMods thread.");
	g_hAutoMode = CreateConVar("sm_db_automode", "1", "If 1, if the HP/Armor ConVar is changed, all current alive players will be set to the values.");
	g_hLogFile = CreateConVar("sm_db_logfile", "logs/dodgeball.log", "The logging file starting from the SourceMod directory.");
	g_hEnabled = CreateConVar("sm_db_enabled", "1", "Enables Decoy Dodgeball.");
	g_hGEnabled = CreateConVar("sm_db_give_enabled", "1", "Enable/Disable the plugin giving decoys.");
	g_hBotThrow = CreateConVar("sm_db_bot_throw", "1", "Once a decoy is equipped to a bot, it will automatically trigger \"IN_ATTACK\" a couple seconds later.");
	
	// AlliedMods Release.
	CreateConVar("sm_db_version", PL_VERSION, "The current version of CS:GO Decoy Dodgeball.");
	
	// Hook ConVar Changes
	HookConVarChange(g_hGiveTime, CVarChanged);
	HookConVarChange(g_hPrint, CVarChanged);
	HookConVarChange(g_hRemovetimer, CVarChanged);
	HookConVarChange(g_hBounces, CVarChanged);
	HookConVarChange(g_hRandom, CVarChanged);
	HookConVarChange(g_hRandomMax, CVarChanged);
	HookConVarChange(g_hRandomMin, CVarChanged);
	HookConVarChange(g_hRoundStartAdvert, CVarChanged);
	HookConVarChange(g_hClientHealth, CVarChanged);
	HookConVarChange(g_hClientArmor, CVarChanged);
	HookConVarChange(g_hDBDamage, CVarChanged);
	HookConVarChange(g_hDebug, CVarChanged);
	HookConVarChange(g_hMinigamesMode, CVarChanged);
	HookConVarChange(g_hAutoMode, CVarChanged);
	HookConVarChange(g_hLogFile, CVarChanged);
	HookConVarChange(g_hEnabled, CVarChanged);
	HookConVarChange(g_hGEnabled, CVarChanged);
	HookConVarChange(g_hBotThrow, CVarChanged);
	
	// Auto execute the config!
	AutoExecConfig(true, "plugin.dodgeball");
	
	// Late Loading
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i)) 
		{
			OnClientPutInServer(i);
		}
	}
}

public void CVarChanged(Handle hCvar, const char[] sOldv, const char[] sNewv) 
{
	OnConfigsExecuted();
	
	// Auto-Mode
	if (g_bAutoMode) 
	{
		if (hCvar == g_hClientHealth || hCvar == g_hClientArmor) 
		{
			for (int i = 1; i <= MaxClients; i++) 
			{
				if (!IsClientInGame(i) || !IsPlayerAlive(i))
				{
					continue;
				}
				
				if (hCvar == g_hClientHealth)
				{
					SetEntityHealth(i, StringToInt(sNewv));
				}
				else if (hCvar == g_hClientArmor)
				{
					SetEntProp(i, Prop_Send, "m_ArmorValue", StringToInt(sNewv));
				}
			}
		}
	}
}

public void OnConfigsExecuted() 
{
	// Set all the convars!
	g_fGiveTime = GetConVarFloat(g_hGiveTime);
	g_bPrint = GetConVarBool(g_hPrint);
	g_fRemoveTimer = GetConVarFloat(g_hRemovetimer);
	g_iBounces = GetConVarInt(g_hBounces);
	g_iRandom = GetConVarInt(g_hRandom);
	g_iRandomMax = GetConVarInt(g_hRandomMax);
	g_iRandomMin = GetConVarInt(g_hRandomMin);
	g_bRoundStartAd = GetConVarBool(g_hRoundStartAdvert);
	g_iClientHealth = GetConVarInt(g_hClientHealth);
	g_iClientArmor = GetConVarInt(g_hClientArmor);
	g_fDBDamage = GetConVarFloat(g_hDBDamage);
	g_bDebug = GetConVarBool(g_hDebug);
	g_bMinigames = GetConVarBool(g_hMinigamesMode);
	g_bAutoMode = GetConVarBool(g_hAutoMode);
	GetConVarString(g_hLogFile, g_sLogFile, sizeof(g_sLogFile));
	g_bEnabled = GetConVarBool(g_hEnabled);
	g_bGEnabled = GetConVarBool(g_hGEnabled);
	g_bBotThrow = GetConVarBool(g_hBotThrow);
	
	BuildPath(Path_SM, g_sLogFilePath, sizeof(g_sLogFilePath), g_sLogFile);
	
	if (g_bEnabled)
	{	
		g_hRemoveTimer = CreateTimer(g_fRemoveTimer, Timer_RemoveGroundWeapons, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		
		if (g_bBotThrow)
		{	
			g_hBotResetTimer = CreateTimer(3.0, Timer_ResetBots, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		}
	}
}

public void OnMapEnd()
{
	if (g_hRemoveTimer != null)
	{
		delete g_hRemoveTimer;
	}
	
	if (g_hBotResetTimer != null)
	{
		delete g_hBotResetTimer;
	}
}

public Action Timer_RemoveGroundWeapons(Handle hTimer, any data)
{
	if (g_bEnabled)
	{
		RemoveGroundWeapons();
	}
}

public Action Timer_ResetBots (Handle hTimer)
{
	if (!g_bBotThrow)
	{
		return Plugin_Stop;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
		{
			g_bPlayerThrow[i] = true;
		}
	}
	
	return Plugin_Handled;
}

public void OnClientPutInServer(int iClient) 
{
	if (g_bEnabled)
	{
		SDKHook(iClient, SDKHook_WeaponSwitch, OnWeaponSwitch);
		SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
		SDKHook(iClient, SDKHook_WeaponDrop, OnWeaponDrop);
	}
}

public void OnClientDisconnect(int iClient) 
{
	// Reset g_iBouncesRandClient for saftey reasons.
	g_iBouncesRandClient[iClient] = 0;
}

public Action OnWeaponSwitch(int iClient, int iWeapon) 
{
	if (!g_bEnabled)
	{
		return Plugin_Continue;
	}
	
	// Block weapon switching.
	char sWeapon[32];
	GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));
    
	if(!StrEqual(sWeapon, "weapon_decoy"))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType) 
{
	if (!g_bEnabled)
	{
		return Plugin_Continue;
	}
	
	char sWeapon[32];
	GetEdictClassname(iInflictor, sWeapon, sizeof(sWeapon));

	if(StrEqual(sWeapon, "weapon_decoy") || StrEqual(sWeapon, "decoy_projectile")) 
	{
		if (g_bDebug) 
		{
			LogToFile(g_sLogFilePath, "[NOTE]%N is taking damage from a dodgeball! Damage: %f", iVictim, g_fDBDamage);
		}
		
		fDamage = g_fDBDamage;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action OnWeaponCanUse(int iClient, int iWeapon)
{
	if (!g_bEnabled)
	{
		return Plugin_Continue;
	}
	
	char sClassName[MAX_NAME_LENGTH];
	int iOwner = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	GetEntityClassname(iWeapon, sClassName, sizeof(sClassName));
	
	if (!StrEqual(sClassName, "weapon_decoy", false) || iOwner > 0)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnWeaponDrop(int iClient, int iWeapon)
{
	if (!g_bEnabled)
	{
		return Plugin_Continue;
	}
	
	if (iWeapon > 0)
	{
		AcceptEntityInput(iWeapon, "kill");
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event eEvent, const char[] sName, bool bDontBroadcast) 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	int iClient = GetClientOfUserId(GetEventInt(eEvent, "userid"));
	
	// Remove all player weapons.
	RemoveClientWeapons(iClient);
	
	// Give the iClient a decoy at spawn.
	RequestFrame(GiveDecoy, iClient);
	
	// Set the iClient's health and armor depending on the ConVars.
	SetEntityHealth(iClient, g_iClientHealth);
	SetEntProp(iClient, Prop_Send, "m_ArmorValue", g_iClientArmor);
	
	// Random Bounces Per Player (mode 2 for sm_db_random)
	if (g_iRandom == 2) 
	{
		g_iBouncesRandClient[iClient] = GetRandomInt(g_iRandomMin, g_iRandomMax);
		
		if (g_iBouncesRandClient[iClient] < 1) 
		{
			g_iBouncesRandClient[iClient] = 1;
		}
		
		if (g_bDebug) 
		{
			LogToFile(g_sLogFilePath, "[NOTE]g_iRandom is two. %N has the bounce count of %i", iClient, g_iBouncesRandClient[iClient]);
		}
	}
}

public Action Event_RoundStart(Event eEvent, const char[] sName, bool bDontBroadcast) 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	RemoveGroundWeapons();
	
	if (g_bRoundStartAd) 
	{
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
			{
				continue;
			}
			
			PrintToChat(i, "\x02[DB]\x03 Decoy Dodgeball plugin made by Christian Deacon (download at \x02AlliedMods.net\x03).");
		}
	}
	
	if (g_iRandom == 1) 
	{
		g_iBouncesRand = GetRandomInt(g_iRandomMin, g_iRandomMax);
		
		if (g_iBouncesRand < 1)
		{
			g_iBouncesRand = 1;
		}
		
		if (g_bDebug) 
		{
			LogToFile(g_sLogFilePath, "[NOTE]g_iRandom is one. Bounce count is %i for this round.", g_iBouncesRand);
		}
	}
	
	if (g_bMinigames) 
	{
		Handle hKV = CreateKeyValues("Minigames");
		char sFilePath[256];
		BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "configs/dodgeball/minigames.cfg");
		FileToKeyValues(hKV, sFilePath);
		
		int iMinigame = 1; 
		int iMaxMinigames = 0; 
		int iAnnounce;
		
		Handle hMinigameNames = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
		
		char sRSCC[MAX_NAME_LENGTH];
		char sRECC[MAX_NAME_LENGTH];
		char skName[MAX_NAME_LENGTH];
		
		if (KvGotoFirstSubKey(hKV)) 
		{
			do 
			{
				iMaxMinigames++;
				char sBuffer[256];
				KvGetSectionName(hKV, sBuffer, sizeof(sBuffer));
				PushArrayString(hMinigameNames, sBuffer);
				
			} while (KvGotoNextKey(hKV));		
			KvRewind(hKV);
			KvGotoFirstSubKey(hKV);
			
			iMinigame = GetRandomInt(1, iMaxMinigames);
			if (g_bDebug) 
			{
				LogToFile(g_sLogFilePath, "[NOTE]Minigames: 1-%i", iMaxMinigames);
			}
			
			char sKeyName[256], sBuffer[256];
			GetArrayString(hMinigameNames, iMinigame - 1, sKeyName, sizeof(sKeyName));
		
			do 
			{
				KvGetSectionName(hKV, sBuffer, sizeof(sBuffer));
				if (g_bDebug) 
				{
					LogToFile(g_sLogFilePath, "[NOTE]Going through Minigame: \"%s\"... \"%s\" is the selected Minigame.", sBuffer, sKeyName);
				}
				if (StrEqual(sBuffer, sKeyName)) 
				{
					if (g_bDebug) 
					{
						LogToFile(g_sLogFilePath, "[NOTE]\"%s\" minigame selected...", sBuffer);
					}
					KvGetString(hKV, "name", skName, sizeof(skName));
					iAnnounce = KvGetNum(hKV, "announce");
					KvGetString(hKV, "rscc", sRSCC, sizeof(sRSCC));
					KvGetString(hKV, "recc", sRECC, sizeof(sRECC));
				}
			} while (KvGotoNextKey(hKV));
			
			if (!StrEqual(skName, "")) 
			{
				if (!StrEqual(sRSCC, "")) 
				{
					ServerCommand("exec %s", sRSCC);
				}
				
				if (iAnnounce) 
				{
					PrintToChatAll("\x02[DB]\x03 Special Minigame \"\x02%s\x03\" is being played!", skName);
				}
				
				strcopy(g_sRECC2, sizeof(g_sRECC2), sRECC);
			}
		}
		
		if (hKV != null)
		{
			delete hKV;
		}
		
		if (hMinigameNames != null)
		{
			delete hMinigameNames;
		}
	}
}

public Action Event_RoundEnd(Event eEvent, const char[] sName, bool bDontBroadcast) 
{
	// Set all the factors back to default if Minigames is enabled.
	if (g_bMinigames) 
	{
		if (!StrEqual(g_sRECC2, "")) 
		{
			ServerCommand("exec %s", g_sRECC2);
		}
	}
}

public void OnEntityCreated(int iEntity, const char[] sClassName) 
{
	if (StrEqual(sClassName, "decoy_projectile", false) && g_bEnabled) 
	{
		SDKHook(iEntity, SDKHook_Spawn, OnDecoySpawned);
		SDKHook(iEntity, SDKHook_StartTouch, OnDecoyTouch);
	}
}

public void OnDecoySpawned(int iEntity) 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	int iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	if (!iClient || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
	{
		if (g_bDebug) 
		{
			LogToFile(g_sLogFilePath, "[ERROR]OnDecoySpawned function returned: Client is not valid.");
		}
		
		return;
	}

	// Delay giving dodgeballs so it isn't spamming dodgeballs...
	CreateTimer(g_fGiveTime, GiveDecoy2Timer, GetClientUserId(iClient));
}

public void OnDecoyTouch(int iEntity, int itEntity) 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	int iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	if (iOwner > MaxClients || iOwner < 1) 
	{
		if (g_bDebug) 
		{
			LogToFile(g_sLogFilePath, "[ERROR]OnDecoyTouch function reported: Owner is not valid.");
		}
		
		KillDodgeball(iEntity);
		
		return;
	}
	
	g_iBounceCount[iEntity] += 1;
	
	if (!g_iRandom || g_iRandom > 3) 
	{	
		if (g_iBounceCount[iEntity] >= g_iBounces) 
		{
			if (g_bDebug) 
			{
				LogToFile(g_sLogFilePath, "[NOTE]g_iRandom isn't enabled. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBounces);
			}
			
			KillDodgeball(iEntity);
		}
	} 
	else if (g_iRandom == 1) 
	{
		if (g_iBounceCount[iEntity] >= g_iBouncesRand) 
		{
			if (g_bDebug) 
			{
				LogToFile(g_sLogFilePath, "[NOTE]g_iRandom is set to mode one. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBouncesRand);
			}
			
			KillDodgeball(iEntity);
		}
	} 
	else if (g_iRandom == 2) 
	{
		if (g_iBounceCount[iEntity] >= g_iBouncesRandClient[iOwner]) 
		{
			if (g_bDebug) 
			{
				LogToFile(g_sLogFilePath, "[NOTE]g_iRandom is set to mode two. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBouncesRandClient[iOwner]);
			}
			
			KillDodgeball(iEntity);
		}
	} 
	else if (g_iRandom == 3) 
	{
		if (g_iBounceCount[iEntity] >= g_iBouncesRandClient[iOwner]) 
		{
			if (g_bDebug) 
			{
				LogToFile(g_sLogFilePath, "[NOTE]g_iRandom is set to mode three. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBouncesRandClient[iOwner]);
			}
			
			KillDodgeball(iEntity);
		}
	}
}

public void GiveDecoy(any iClient) 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	if (!iClient || !IsClientInGame(iClient))
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFilePath, "[ERROR]GiveDecoy() function returned: Client is not valid.");
		}
		
		return;
	}
	
	if (!IsPlayerAlive(iClient))
	{
		if (g_bDebug)
		{
			char sClientName[MAX_NAME_LENGTH], sSteamID[32];
			GetClientName(iClient, sClientName, sizeof(sClientName));
			GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));
			LogToFile(g_sLogFilePath, "[ERROR]GiveDecoy() function returned: Client is not alive. Client Name: %s -- Client Steam ID: %s", sClientName, sSteamID);
		}
		
		return;
	}
	
	GiveDodgeball(iClient);
	
	if (g_bPrint) 
	{
		PrintToChat(iClient, "\x02[DB]\x03 Decoy equipped! Go play some dodgeball!");
	}
}

public Action GiveDecoy2Timer(Handle hTimer, any iUserID) 
{
	if (!g_bEnabled)
	{
		return Plugin_Stop;
	}
	
	int iClient = GetClientOfUserId(iUserID);
	
	if (!iClient || !IsClientInGame(iClient) || !IsPlayerAlive(iClient)) 
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFilePath, "[ERROR]GiveDecoy2Timer timer returned: Client is not valid.");
		}
		
		return Plugin_Stop;
	}
	
	// Remove client's weapons.
	RemoveClientWeapons(iClient);
	
	// Give the dodgeball!
	GiveDodgeball(iClient);
	
	return Plugin_Stop;
}

// Dodgeball specific functions (not sure whether to use public or stock).
stock void KillDodgeball(int iEntity) 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	if (iEntity < 1)
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFilePath, "[WARNING]KillDodgeball function returned: Entity not valid.");
		}
		
		return;
	}
	
	// Kill the iEntity.
	AcceptEntityInput(iEntity, "kill");
	
	// Reset the iEntity index bounce count.
	g_iBounceCount[iEntity] = 0;
}

stock void GiveDodgeball(int iClient) 
{
	if (!g_bEnabled || !g_bGEnabled)
	{
		return;
	}
	
	GivePlayerItem(iClient, "weapon_decoy");
	
	if (g_iRandom == 3) 
	{
		g_iBouncesRandClient[iClient] = GetRandomInt(g_iRandomMin, g_iRandomMax);
		
		if (g_iBouncesRandClient[iClient] < 1) 
		{
			g_iBouncesRandClient[iClient] = 1;
		}
	}
	
	/* Bot Throw. */
	if (g_bBotThrow && IsFakeClient(iClient))
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFilePath, "[WARNING]Fake client and g_bBotThrow is on.");
		}
	}
}

stock void RemoveClientWeapons(int iClient) 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	for (int i=0; i < 5; i++) 
	{
		int iEnt = GetPlayerWeaponSlot(iClient, i);
		
		if (iEnt > 0) 
		{
			RemovePlayerItem(iClient, iEnt);
			RemoveEdict(iEnt);
		}
	}
}

stock void RemoveGroundWeapons()
{
	if (!g_bEnabled)
	{
		return;
	}
	
	char sClassname[MAX_NAME_LENGTH];
	int iOwner;
	
	for (int i = MaxClients; i <= MAXENTITIES; i++)
	{
		if (!IsValidEntity(i) || !IsValidEdict(i))
		{
			continue;
		}
		
		GetEntityClassname(i, sClassname, sizeof(sClassname));
		
		if (StrContains(sClassname, "weapon_", false) == -1)
		{
			continue;
		}
		
		iOwner = GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity");
		
		if (iOwner > 0)
		{
			continue;
		}
		
		AcceptEntityInput(i, "kill");
		RemoveEdict(i);
	}
}

// Not currently used.
stock void RemoveDecoys() 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	int iEnt = -1;
	
	while ((iEnt = FindEntityByClassname(iEnt, "weapon_decoy")) != INVALID_ENT_REFERENCE) 
	{
		if (GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == -1) 
		{
			AcceptEntityInput(iEnt, "kill");
		}
	}
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAngles[3], int &iWeapons)
{
	if (!g_bBotThrow)
	{
		PrintToServer("Bot Throw Not Enabled.");
		return Plugin_Continue;
	}
	
	if (g_bPlayerThrow[iClient] && IsFakeClient(iClient))
	{
		if (!(iButtons & IN_ATTACK))
		{
			iButtons |= IN_ATTACK;
			RequestFrame(funcRemoveFlags, iButtons);
		}
		else
		{
			iButtons &= ~IN_ATTACK;
		}
		
		g_bPlayerThrow[iClient] = false;
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void funcRemoveFlags(int iButtons)
{
	iButtons &= ~IN_ATTACK;
}