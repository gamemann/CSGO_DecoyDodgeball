#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define MAXENTITIES 2048
#define PL_VERSION "1.5"

/*
Versions:
1.0:
	- Release
1.1:
	- Added a ConVar: GFL_db_bounces which controls how many bounces (off a surface), before destroying.
	- Fixed up some code.
	- Added a quick round start advertisement.
1.2:
	- Added a ConVar: sm_db_random - If enabled, a random number depending on "sm_db_random_max" and "sm_db_random_min" will be used for the amount of bounces a decoy (dodgeball) can have. (1 = Mode 1, 2 = Mode 2, 3 = Mode 3 0 = Off). More information about the modes at GFLClan.com.
	- Added a ConVar: sm_db_random_max - The maximum amount of bounces the decoy (dodgeball) can have using random mode.
	- Added a ConVar: sm_db_random_min - The minimum amount of bounces the decoy (dodgeball) can have using random mode.
	- Added a ConVar: sm_db_rs_advert - Enables the Round Start advertisement.
	- Added a ConVar: sm_db_client_health - Set the health to this number on client spawn.
	- Added a ConVar: sm_db_client_armor - Set the armor to this number on client spawn.
	- Added a ConVar: sm_db_damage - The amount of damage the decoys (dodgeballs) do.
	- Added a ConVar: sm_db_debug - Enables debugging for dodgeball (will spam the SourceMod logs if enabled).
	- Added a ConVar: sm_db_custom_hit_detection - This lets the plugin decide the dodgeball hit detection. This will force the victim to suicide after being hit by a dodgeball, therefore, there will be no kills awarded to the attacker. This *may* provide better dodgeball hit detection.
	- Renamed all ConVars to begin with "sm_" instead of "GFL_".
	- Renamed the config "GFL_dodgeball" to "sm_dodgeball".
	- Cleaned/Organized code (e.g. There is an one character indicator to tell what a ConVar Value's type is.
	- Edited "myinfo" and included more information.
	- Added support for late plugin loading (e.g. You can now load the Dodgeball plugin half way through the round, etc).
	
	"Random" Modes explained:
	0:
		Random mode is disabled and Dodgeball is normal along with the amount of decoy (dodgeball) bounces depending on the "sm_db_bounces" ConVar.
	1:
		Random mode is set to one (1). On every round start, there is a random number generated between "sm_db_random_min" and "sm_db_random_max" that represents the amount of bounces a decoy (dodgeball) can have for that round.
	2:
		Random mode is set to two (2). On every player spawn, there is a random number generated between "sm_db_random_min" and "sm_db_random_max" that represents the amount of bounces a decoy (dodgeball) can have for that round for the client only. Therefore, client X could have 2 bounces for every decoy (dodgeball) they throw while client Y can have 3 bounces for every decoy (dodgeball) they throw.
	3:
		Random mode is set to three (3). On every thrown decoy (dodgeball), there is a random number generated between "sm_db_random_min" and "sm_db_random_max" that represents the amount of bounces that decoy (dodgeball) can have for that client. Therefore, client X could throw two decoys (dodgeballs), with the first decoy (dodgeball) having 1 bounce and the second decoy (dodgeball) having 3 bounces while client Y could throw two decoys (dodgeballs), with the first decoy (dodgeball) having 2 bounces and the second decoy (dodgeball) having 1 bounce.
	Other (3+ and below 0):
		Random mode isn't recognized (likely a number higher than 3). Therefore, the random mode isn't enabled.
1.3:
	- Added a Minigames game mode!
	- Advertisements/Notifications now begin with [DB] instead of [GFL].
	- "sm_db_equip_notify" is now off by default.
	- Plugin-side functions are now "stock" instead of "public".
1.4:
	- Cleaned up code.
1.5:
	- Organized Code
	- Renamed a few PrintToChat() strings.
	- Added a ConVar: sm_db_automode - If 1, if the HP/Armor ConVar is changed, all current alive players will be set to the new values.
*/

public Plugin:myinfo = {
	name = "[CS:GO] Decoy Dodgeball",
	description = "A Decoy Dodgeball plugin for Counter-Strike: Global Offensive.",
	author = "Roy (Christian Deacon)",
	version = PL_VERSION,
	url = "GFLClan.com & Alliedmods.net & TheDevelopingCommunity.com"
};

// ConVars
new Handle:g_hGiveTime = INVALID_HANDLE;
new Handle:g_hPrint = INVALID_HANDLE;
new Handle:g_hRemovetimer = INVALID_HANDLE;
new Handle:g_hBounces = INVALID_HANDLE;
new Handle:g_hRandom = INVALID_HANDLE;
new Handle:g_hRandomMax = INVALID_HANDLE;
new Handle:g_hRandomMin = INVALID_HANDLE;
new Handle:g_hRoundStartAdvert = INVALID_HANDLE;
new Handle:g_hClientHealth = INVALID_HANDLE;
new Handle:g_hClientArmor = INVALID_HANDLE;
new Handle:g_hDBDamage = INVALID_HANDLE;
new Handle:g_hDebug = INVALID_HANDLE;
new Handle:g_hCustomHitReg = INVALID_HANDLE;
new Handle:g_hMinigamesMode = INVALID_HANDLE;
new Handle:g_hAutoMode = INVALID_HANDLE;

// FindConVars
new Handle:g_hGravity;
new Handle:g_hFriction;
new Handle:g_hTimeScale;
new Handle:g_hAccelerate;

// ConVar Values
new Float:g_fGiveTime;
new bool:g_bPrint;
new Float:g_fRemoveTimer;
new g_iBounces;
new g_iRandom;
new g_iRandomMax;
new g_iRandomMin;
new bool:g_bRoundStartAd;
new g_iClientHealth;
new g_iClientArmor;
new Float:g_fDBDamage;
new bool:g_bDebug;
new bool:g_bCustomHitReg;
new bool:g_bMinigames;
new bool:g_bAutoMode;

// Other Values
new g_iBounceCount[MAXENTITIES+1];
new g_iBouncesRand;	
new g_iBouncesRandClient[MAXPLAYERS+1];
new String:g_sRECC2[MAX_NAME_LENGTH];

public OnPluginStart() {
	// Events.
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	// Convars.
	g_hGiveTime = CreateConVar("sm_db_give_time", "1.0", "The delay on giving decoys after being thrown.");
	g_hPrint = CreateConVar("sm_db_equip_notify", "0", "Whether to print to chat or not when a client spawns with a dodgeball.");
	g_hRemovetimer = CreateConVar("sm_db_remove_timer", "30.0", "Every X seconds, it will remove all decoys on the map (already does this on player_death, but this is just for safety).");
	g_hBounces = CreateConVar("sm_db_bounces", "1", "Amount of bounces the decoy can have (off a surface), before destroying. This is ineffective if random mode is on.");
	g_hRandom = CreateConVar("sm_db_random", "0", "If enabled, a random number depending on \"sm_db_random_max\" and \"sm_db_random_min\" will be used for the amount of bounces a decoy (dodgeball) can have. (1 = Mode 1, 2 = Mode 2, 3 = Mode 3 0 = Off). More information about the modes on the AlliedMods thread.");
	g_hRandomMax = CreateConVar("sm_db_random_max", "3", "The maximum amount of bounces the decoy (dodgeball) can have using random mode.");
	g_hRandomMin = CreateConVar("sm_db_random_min", "1", "The minimum amount of bounces the decoy (dodgeball) can have using random mode.");
	g_hRoundStartAdvert = CreateConVar("sm_db_rs_advert", "1", "Enables the Round Start advertisement.");
	g_hClientHealth = CreateConVar("sm_db_client_health", "1", "Set the health to this number on client spawn.");
	g_hClientArmor = CreateConVar("sm_db_client_armor", "0", "Set the armor to this number on client spawn.");
	g_hDBDamage = CreateConVar("sm_db_damage", "200.0", "The amount of damage the decoys (dodgeballs) do.");
	g_hDebug = CreateConVar("sm_db_debug", "0", "Enables debugging for dodgeball (will spam the SourceMod logs if enabled).");
	g_hCustomHitReg = CreateConVar("sm_db_custom_hit_detection", "0", "This lets the plugin decide the dodgeball hit detection. This will force the victim to suicide after being hit by a dodgeball, therefore, there will be no kills awarded to the attacker. This *may* provide better dodgeball hit detection.");
	g_hMinigamesMode = CreateConVar("sm_db_minigames", "0", "Enables the Minigames mode. More information about this on the AlliedMods thread.");
	g_hAutoMode = CreateConVar("sm_db_automode", "1", "If 1, if the HP/Armor ConVar is changed, all current alive players will be set to the values.");
	
	// AlliedMods Release.
	CreateConVar("sm_db_version", PL_VERSION, "The current version of CS:GO Decoy Dodgeball.");
	
	// FindConVars
	g_hGravity = FindConVar("sv_gravity");
	g_hFriction = FindConVar("sv_friction");
	g_hTimeScale = FindConVar("host_timescale");
	g_hAccelerate = FindConVar("sv_accelerate");
	
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
	HookConVarChange(g_hCustomHitReg, CVarChanged);
	HookConVarChange(g_hMinigamesMode, CVarChanged);
	HookConVarChange(g_hAutoMode, CVarChanged);
	
	// Auto execute the config!
	AutoExecConfig(true, "sm_dodgeball");
	
	// Late Loading
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public CVarChanged(Handle:hCvar, const String:sOldv[], const String:sNewv[]) {
	OnConfigsExecuted();
	
	// Auto-Mode
	if (g_bAutoMode) {
		if (hCvar == g_hClientHealth) {
			for (new i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i) && IsPlayerAlive(i)) {
					SetEntityHealth(i, StringToInt(sNewv));
				}
			}
		} else if (hCvar == g_hClientArmor) {
			for (new i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i) && IsPlayerAlive(i)) {
					SetEntProp(i, Prop_Send, "m_ArmorValue", StringToInt(sNewv));
				}
			}
		}
	}
}

public OnConfigsExecuted() {
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
	g_bCustomHitReg = GetConVarBool(g_hCustomHitReg);
	g_bMinigames = GetConVarBool(g_hMinigamesMode);
	g_bAutoMode = GetConVarBool(g_hAutoMode);
	
	if (g_bMinigames) {
		// Set the flags of the FindConVars.
		SetConVarFlags(g_hGravity, GetConVarFlags(g_hGravity)&~FCVAR_NOTIFY);
		SetConVarFlags(g_hFriction, GetConVarFlags(g_hFriction)&~FCVAR_NOTIFY);
		SetConVarFlags(g_hTimeScale, (GetConVarFlags(g_hTimeScale) & ~(FCVAR_NOTIFY|FCVAR_CHEAT)));
		SetConVarFlags(g_hTimeScale, GetConVarFlags(g_hTimeScale)&FCVAR_REPLICATED);
		SetConVarFlags(g_hAccelerate, GetConVarFlags(g_hAccelerate)&~FCVAR_NOTIFY);
	}
	
	CreateTimer(g_fRemoveTimer, Timer_RemoveDecoys, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_RemoveDecoys(Handle:timer, any:data)
{
	RemoveDecoys();
}

public OnClientPutInServer(iClient) {
	SDKHook(iClient, SDKHook_WeaponSwitch, OnWeaponSwitch);
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(iClient) {
	// Reset g_iBouncesRandClient for saftey reasons.
	g_iBouncesRandClient[iClient] = 0;
}

public Action:OnWeaponSwitch(iClient, iWeapon) {
	// Block weapon switching.
    decl String:sWeapon[32];
    GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));
    
    if(!StrEqual(sWeapon, "weapon_decoy"))
        return Plugin_Handled;
    
    return Plugin_Continue;
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType) {
	decl String:sWeapon[32];
	GetEdictClassname(iInflictor, sWeapon, sizeof(sWeapon));

	if(StrEqual(sWeapon, "weapon_decoy") || StrEqual(sWeapon, "decoy_projectile")) {
		// Set the damage of the decoy using the ConVar: "sm_db_damage"
		if (g_bDebug) {
			LogMessage("[DB Debug]%N is taking damage from a dodgeball! Damage: %f", iVictim, g_fDBDamage);
		}
		
		fDamage = g_fDBDamage;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Event_PlayerSpawn(Handle:hEvent, const String:sName[], bool:bDontBroadcast) {
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	// Remove all player weapons.
	RemoveClientWeapons(iClient);
	
	// Give the iClient a decoy at spawn.
	RequestFrame(GiveDecoy, iClient);
	
	// Set the iClient's health and armor depending on the ConVars.
	SetEntityHealth(iClient, g_iClientHealth);
	SetEntProp(iClient, Prop_Send, "m_ArmorValue", g_iClientArmor);
	
	// Random Bounces Per Player (mode 2 for sm_db_random)
	if (g_iRandom == 2) {
		g_iBouncesRandClient[iClient] = GetRandomInt(g_iRandomMin, g_iRandomMax);
		
		// Check
		if (g_iBouncesRandClient[iClient] < 1) {
			g_iBouncesRandClient[iClient] = 1;
		}
		if (g_bDebug) {
			LogMessage("[DB Debug]g_iRandom is two. %N has the bounce count of %i", iClient, g_iBouncesRandClient[iClient]);
		}
	}
}

public Event_PlayerDeath(Handle:hEvent, const String:sName[], bool:bDontBroadcast) {
	RemoveDecoys();
}

public Event_RoundStart(Handle:hEvent, const String:sName[], bool:bDontBroadcast) {
	if (g_bRoundStartAd) {
		for (new i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && !IsFakeClient(i)) {
				PrintToChat(i, "\x02[DB]\x03 Decoy Dodgeball plugin made by Christian Deacon (download at \x02AlliedMods.net\x03).");
			}
		}
	}
	
	if (g_iRandom == 1) {
		// Mode one.
		g_iBouncesRand = GetRandomInt(g_iRandomMin, g_iRandomMax);
		
		if (g_bDebug) {
			LogMessage("[DB Debug]g_iRandom is one. Bounce count is %i for this round.", g_iBouncesRand);
		}
	}
	
	if (g_bMinigames) {
		// Minigames mode is enabled. Honestly, this is my first time working with Key Values in SourcePawn.
		new Handle:hKV = CreateKeyValues("Minigames");
		decl String:sFilePath[255];
		BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "configs/dodgeball_minigames.cfg");
		FileToKeyValues(hKV, sFilePath);
		
		// To get the random minigame.
		new iMaxMinigames = 0;
		new iMinigame = 1;
		new iBlockSize =  ByteCountToCells(PLATFORM_MAX_PATH);
		new Handle:hMinigameNames = CreateArray(iBlockSize);
		
		// Factors for each minigame.
		new Float:fGravity, Float:fFriction, Float:fTimeScale, Float:fAccelerate, String:sRSCC[MAX_NAME_LENGTH], String:sRECC[MAX_NAME_LENGTH], String:skName[MAX_NAME_LENGTH], iAnnounce, iDefault;
		
		if (KvGotoFirstSubKey(hKV)) {
			do {
				iMaxMinigames++;
				decl String:sBuffer[255];
				KvGetSectionName(hKV, sBuffer, sizeof(sBuffer));
				PushArrayString(hMinigameNames, sBuffer);
				
			} while (KvGotoNextKey(hKV));		
			KvRewind(hKV);
			KvGotoFirstSubKey(hKV)
			
			// Now pick a random minigame.
			iMinigame = GetRandomInt(1, iMaxMinigames);
			if (g_bDebug) {
				LogMessage("[DB Debug]Minigames: 1-%i", iMaxMinigames);
			}
			
			new String:sKeyName[255];
			GetArrayString(hMinigameNames, iMinigame - 1, sKeyName, sizeof(sKeyName));
			
			decl String:sBuffer[255];
			do {
				KvGetSectionName(hKV, sBuffer, sizeof(sBuffer));
				if (g_bDebug) {
					LogMessage("[DB Debug]Going through Minigame: \"%s\"... \"%s\" is the selected Minigame.", sBuffer, sKeyName);
				}
				if (StrEqual(sBuffer, sKeyName)) {
					if (g_bDebug) {
						LogMessage("[DB Debug]\"%s\" minigame selected...", sBuffer);
					}
					KvGetString(hKV, "name", skName, sizeof(skName));
					fGravity = KvGetFloat(hKV, "gravity");
					fFriction = KvGetFloat(hKV, "friction");
					fTimeScale = KvGetFloat(hKV, "timescale");
					fAccelerate = KvGetFloat(hKV, "accelerate");
					iAnnounce = KvGetNum(hKV, "announce");
					iDefault = KvGetNum(hKV, "default");
					KvGetString(hKV, "rscc", sRSCC, sizeof(sRSCC));
					KvGetString(hKV, "recc", sRECC, sizeof(sRECC));
				}
			} while (KvGotoNextKey(hKV));
			// Now let's setup the game!
			if (!StrEqual(skName, "")) {
				SetConVarFloat(g_hGravity, fGravity);
				SetConVarFloat(g_hFriction, fFriction);
				if (iDefault || fTimeScale == 1.0) {
					SetTimeScale(fTimeScale, true);
				} else {
					SetTimeScale(fTimeScale, false);
				}
				SetConVarFloat(g_hAccelerate, fAccelerate);
				if (!StrEqual(sRSCC, "")) {
					ServerCommand("exec %s", sRSCC);
				}
				if (iAnnounce) {
					PrintToChatAll("\x02[DB]\x03 Special Minigame \"\x02%s\x03\" is being played!", skName);
				}
				
				// Do the round end custom config
				strcopy(g_sRECC2, sizeof(g_sRECC2), sRECC);
			}
		}
		CloseHandle(hKV);
		CloseHandle(hMinigameNames);
	}
}

public Event_RoundEnd(Handle:hEvent, const String:sName[], bool:bDontBroadcast) {
	// Set all the factors back to default if Minigames is enabled.
	if (g_bMinigames) {
		SetConVarFloat(g_hGravity, 800.0);
		SetConVarFloat(g_hFriction, 5.2);
		SetConVarFloat(g_hAccelerate, 5.5);
		SetTimeScale(1.0, true);
		
		if (!StrEqual(g_sRECC2, "")) {
			ServerCommand("exec %s", g_sRECC2);
		}
	}
}

public OnEntityCreated(iEntity, const String:sClassName[]) {
	if (StrEqual(sClassName, "decoy_projectile", false)) {
		SDKHook(iEntity, SDKHook_Spawn, OnEntitySpawned);
		SDKHook(iEntity, SDKHook_StartTouch, OnEntityTouch);
	}
}

public OnEntitySpawned(iEntity) {
	new iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	// Remove all player weapons.
	RemoveClientWeapons(iClient);
	
	// Give the iClient a decoy on the next frame.
	RequestFrame(GiveDecoy2, iClient);
}

public OnEntityTouch(iEntity, itEntity) {
	new owner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if (owner > MaxClients || owner < 1) {
		// Not a valid owner...
		if (g_bDebug) {
			LogMessage("[DB Debug]OnEntityTouch reported the owner isn't valid. %i is the owner index.", owner);
		}
		return;
	}
	
	if (0 < itEntity < MaxClients) {
		// This is a player.
		// Let's do the custom hits.
		if(GetClientTeam(itEntity) != GetClientTeam(owner) && GetClientTeam(itEntity) > 1 && g_bCustomHitReg) {
			// Not on the same team.
			new curhp = GetClientHealth(itEntity);
			new newhp = curhp - RoundFloat(g_fDBDamage);
			if (newhp < 1) {
				ForcePlayerSuicide(itEntity);
			} else {
				SetEntityHealth(itEntity, newhp);
			}
		}
	} else {
		g_iBounceCount[iEntity] += 1;
		
		if (!g_iRandom) {
			if (g_bDebug) {
				LogMessage("[DB Debug]g_iRandom isn't enabled.");
			}
			// Random mode is off, continue with the default setup.
			if (g_iBounceCount[iEntity] >= g_iBounces) {
				if (g_bDebug) {
					LogMessage("[DB Debug]g_iRandom isn't enabled. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBounces);
				}
				KillDodgeball(iEntity);
			}
		} else if (g_iRandom == 1) {
			// Mode one.
			if (g_bDebug) {
				LogMessage("[DB Debug]g_iRandom is set to mode one.");
			}
			
			if (g_iBounceCount[iEntity] >= g_iBouncesRand) {
				if (g_bDebug) {
					LogMessage("[DB Debug]g_iRandom is set to mode one. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBouncesRand);
				}
				KillDodgeball(iEntity);
			}
		} else if (g_iRandom == 2) {
			// Mode two.
			if (g_bDebug) {
				LogMessage("[DB Debug]g_iRandom is set to mode two.");
			}
			
			if (g_iBounceCount[iEntity] >= g_iBouncesRandClient[owner]) {
				if (g_bDebug) {
					LogMessage("[DB Debug]g_iRandom is set to mode two. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBouncesRandClient[owner]);
				}
				KillDodgeball(iEntity);
			}
		} else if (g_iRandom == 3) {
			// Mode three.
			if (g_bDebug) {
				LogMessage("[DB Debug]g_iRandom is set to mode three.");
			}
			
			if (g_iBounceCount[iEntity] >= g_iBouncesRandClient[owner]) {
				if (g_bDebug) {
					LogMessage("[DB Debug]g_iRandom is set to mode three. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBouncesRandClient[owner]);
				}
				KillDodgeball(iEntity);
			}
		} else {
			if (g_bDebug) {
				LogMessage("[DB Debug]g_iRandom isn't recognized. g_iRandom isn't enabled.");
			}
			// Random mode isn't recognized, setting to the default setup.
			if (g_iBounceCount[iEntity] >= g_iBounces) {
				if (g_bDebug) {
					LogMessage("[DB Debug]g_iRandom isn't recognized. g_iRandom isn't enabled. Bounces exceeded. %i/%i", g_iBounceCount[iEntity], g_iBounces);
				}
				KillDodgeball(iEntity);
			}
		}
	}
}

public GiveDecoy(any:iClient) {
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient)) {
		GiveDodgeball(iClient);
	}
	
	if (g_bPrint) {
		PrintToChat(iClient, "\x02[DB]\x03 Decoy equipped! Go play some dodgeball!");
	}
}

public GiveDecoy2(any:iClient) {
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient)) {
		// Delay giving dodgeballs so it isn't spamming dodgeballs...
		CreateTimer(g_fGiveTime, GiveDecoy2Timer, iClient);
	}
}

public Action:GiveDecoy2Timer(Handle:hTimer, any:iClient) {
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient)) {
		new ent = GetPlayerWeaponSlot(iClient, CS_SLOT_GRENADE);
		new String:sWepName[64];
		if (ent != -1) {
			GetEntityClassname(ent, sWepName, sizeof(sWepName));
		}
		
		// Now to give the item again.
		if (!StrEqual(sWepName, "weapon_decoy", false)) {
			GiveDodgeball(iClient);
		}
	}
}

// Dodgeball specific functions (not sure whether to use public or stock).
stock KillDodgeball(iEntity) {
	if (g_bDebug) {
		LogMessage("[DB Debug]Attempting to kill the dodgeball.");
	}
	// Kill the iEntity.
	AcceptEntityInput(iEntity, "kill");
	
	// Reset the iEntity index bounce count.
	g_iBounceCount[iEntity] = 0;
}

stock GiveDodgeball(iClient) {
	GivePlayerItem(iClient, "weapon_decoy");
	
	if (g_iRandom == 3) {
		g_iBouncesRandClient[iClient] = GetRandomInt(g_iRandomMin, g_iRandomMax);
		
		// Check
		if (g_iBouncesRandClient[iClient] < 1) {
			g_iBouncesRandClient[iClient] = 1;
		}
	}
}

stock SetTimeScale(Float:fTS, bool:bReset) {
	SetConVarFloat(g_hTimeScale, fTS);
	
	if (bReset) {
		UpdateClientCheats(0);
	} else {
		UpdateClientCheats(1);
	}
	
	ServerCommand("host_timescale %f", fTS);
}

stock UpdateClientCheats(const iValue) {
	new Handle:cheats = FindConVar("sv_cheats");
	if (cheats == INVALID_HANDLE) {
		return;
	}
	
	for (new i = 1; i <= MaxClients; i++) {
		if (IsValidEdict(i) && IsClientConnected(i) && !IsFakeClient(i)) {
			decl String:svalue[11];
			IntToString(iValue, svalue, sizeof(svalue));
			SendConVarValue(i, cheats, svalue);
		}
	}
}

stock RemoveClientWeapons(iClient) {
	for (new i=0; i <= 5; i++) {
		new iEnt = -1;
		iEnt = GetPlayerWeaponSlot(iClient, i);
		if (iEnt != -1) {
			RemovePlayerItem(iClient, iEnt);
			RemoveEdict(iEnt);
		}
	}
}

stock RemoveDecoys() {
	decl String:sClassName[64];
	for(new i = MaxClients; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i) && IsValidEdict(i) && GetEdictClassname(i, sClassName, sizeof(sClassName)) && StrEqual(sClassName, "weapon_decoy") && GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == -1) {
			AcceptEntityInput(i, "kill");
		}
	}
}