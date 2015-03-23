#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define MAXENTITIES 2048

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
	
*/

public Plugin:myinfo = {
	name = "Decoy Dodgeball",
	description = "A Decoy Dodgeball plugin for Counter-Strike: Global Offensive.",
	author = "[GFL] Roy (Christian Deacon)",
	version = "1.3",
	url = "GFLClan.com"
};

// ConVars
new Handle:g_givetime = INVALID_HANDLE;
new Handle:g_print = INVALID_HANDLE;
new Handle:g_removetimer = INVALID_HANDLE;
new Handle:g_bounces = INVALID_HANDLE;
new Handle:g_random = INVALID_HANDLE;
new Handle:g_randomMax = INVALID_HANDLE;
new Handle:g_randomMin = INVALID_HANDLE;
new Handle:g_roundstartad = INVALID_HANDLE;
new Handle:g_clienthealth = INVALID_HANDLE;
new Handle:g_clientarmor = INVALID_HANDLE;
new Handle:g_dbdamage = INVALID_HANDLE;
new Handle:g_debug = INVALID_HANDLE;
new Handle:g_customhitreg = INVALID_HANDLE;
new Handle:g_minigames = INVALID_HANDLE;

// FindConVars
new Handle:f_gravity;
new Handle:f_friction;
new Handle:f_timescale;
new Handle:f_accelerate;

// ConVar Values
new Float:fGiveTime;
new bool:bPrint;
new Float:fRemoveTimer;
new iBounces;
new iRandom;
new iRandomMax;
new iRandomMin;
new bool:bRoundStartAd;
new iClientHealth;
new iClientArmor;
new Float:fDBDamage;
new bool:bDebug;
new bool:bCustomHitReg;
new bool:bMinigames;

// Other Values
new iBounceCount[MAXENTITIES+1];
new iBouncesRand;	
new iBouncesRandClient[MAXPLAYERS+1];
new String:recc2[MAX_NAME_LENGTH];


public OnPluginStart() {
	// Hook the player spawn event.
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	// Convars
	g_givetime = CreateConVar("sm_db_give_time", "1.0", "The delay on giving decoys after being thrown.");
	g_print = CreateConVar("sm_db_equip_notify", "0", "Whether to print to chat or not when a client spawns with a dodgeball.");
	g_removetimer = CreateConVar("sm_db_remove_timer", "30.0", "Every X seconds, it will remove all decoys on the map (already does this on player_death, but this is just for saftey).");
	g_bounces = CreateConVar("sm_db_bounces", "1", "Amount of bounces the decoy can have (off a surface), before destorying. This is ineffective if random mode is on.");
	g_random = CreateConVar("sm_db_random", "0", "If enabled, a random number depending on \"sm_db_random_max\" and \"sm_db_random_min\" will be used for the amount of bounces a decoy (dodgeball) can have. (1 = Mode 1, 2 = Mode 2, 3 = Mode 3 0 = Off). More information about the modes at GFLClan.com.");
	g_randomMax = CreateConVar("sm_db_random_max", "3", "The maximum amount of bounces the decoy (dodgeball) can have using random mode.");
	g_randomMin = CreateConVar("sm_db_random_min", "1", "The minimum amount of bounces the decoy (dodgeball) can have using random mode.");
	g_roundstartad = CreateConVar("sm_db_rs_advert", "1", "Enables the Round Start advertisement.");
	g_clienthealth = CreateConVar("sm_db_client_health", "1", "Set the health to this number on client spawn.");
	g_clientarmor = CreateConVar("sm_db_client_armor", "0", "Set the armor to this number on client spawn.");
	g_dbdamage = CreateConVar("sm_db_damage", "200.0", "The amount of damage the decoys (dodgeballs) do.");
	g_debug = CreateConVar("sm_db_debug", "0", "Enables debugging for dodgeball (will spam the SourceMod logs if enabled).");
	g_customhitreg = CreateConVar("sm_db_custom_hit_detection", "0", "This lets the plugin decide the dodgeball hit detection. This will force the victim to suicide after being hit by a dodgeball, therefore, there will be no kills awarded to the attacker. This *may* provide better dodgeball hit detection.");
	g_minigames = CreateConVar("sm_db_minigames", "0", "Enables the Minigames mode. More information about this at GFLClan.com.");
	
	// FindConVars
	f_gravity = FindConVar("sv_gravity");
	f_friction = FindConVar("sv_friction");
	f_timescale = FindConVar("host_timescale");
	f_accelerate = FindConVar("sv_accelerate");
	
	// Hook ConVar Changes
	HookConVarChange(g_givetime, CVarChanged);
	HookConVarChange(g_print, CVarChanged);
	HookConVarChange(g_removetimer, CVarChanged);
	HookConVarChange(g_bounces, CVarChanged);
	HookConVarChange(g_random, CVarChanged);
	HookConVarChange(g_randomMax, CVarChanged);
	HookConVarChange(g_randomMin, CVarChanged);
	HookConVarChange(g_roundstartad, CVarChanged);
	HookConVarChange(g_clienthealth, CVarChanged);
	HookConVarChange(g_clientarmor, CVarChanged);
	HookConVarChange(g_dbdamage, CVarChanged);
	HookConVarChange(g_debug, CVarChanged);
	HookConVarChange(g_customhitreg, CVarChanged);
	HookConVarChange(g_minigames, CVarChanged);
	
	// Auto execute the config!
	AutoExecConfig(true, "sm_dodgeball");
	
	// Late Loading
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public CVarChanged(Handle:convar, const String:oldv[], const String:newv[]) {
	OnConfigsExecuted();
}

public OnConfigsExecuted() {
	// Set all the convars!
	fGiveTime = GetConVarFloat(g_givetime);
	bPrint = GetConVarBool(g_print);
	fRemoveTimer = GetConVarFloat(g_removetimer);
	iBounces = GetConVarInt(g_bounces);
	iRandom = GetConVarInt(g_random);
	iRandomMax = GetConVarInt(g_randomMax);
	iRandomMin = GetConVarInt(g_randomMin);
	bRoundStartAd = GetConVarBool(g_roundstartad);
	iClientHealth = GetConVarInt(g_clienthealth);
	iClientArmor = GetConVarInt(g_clientarmor);
	fDBDamage = GetConVarFloat(g_dbdamage);
	bDebug = GetConVarBool(g_debug);
	bCustomHitReg = GetConVarBool(g_customhitreg);
	bMinigames = GetConVarBool(g_minigames);
	
	if (bMinigames) {
		// Set the flags of the FindConVars.
		SetConVarFlags(f_gravity, GetConVarFlags(f_gravity)&~FCVAR_NOTIFY);
		SetConVarFlags(f_friction, GetConVarFlags(f_friction)&~FCVAR_NOTIFY);
		SetConVarFlags(f_timescale, (GetConVarFlags(f_timescale) & ~(FCVAR_NOTIFY|FCVAR_CHEAT)));
		SetConVarFlags(f_timescale, GetConVarFlags(f_timescale)&FCVAR_REPLICATED);
		SetConVarFlags(f_accelerate, GetConVarFlags(f_accelerate)&~FCVAR_NOTIFY);
	}
	
	CreateTimer(fRemoveTimer, Timer_RemoveDecoys, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_RemoveDecoys(Handle:timer, any:data)
{
	new iMaxEnts = GetMaxEntities();
	decl String:sClassName[64];
	for(new i=MaxClients;i<iMaxEnts;i++)
	{
		if(IsValidEntity(i) && IsValidEdict(i) && GetEdictClassname(i, sClassName, sizeof(sClassName)) && StrEqual(sClassName, "weapon_decoy") && GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == -1) {
			//RemoveEdict(i);
			AcceptEntityInput(i, "kill");	// Safer solution to remove items?
		}
	}
}

public OnClientPutInServer(client) {
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client) {
	// Reset iBouncesRandClient for saftey reasons.
	iBouncesRandClient[client] = 0;
}

public Action:OnWeaponSwitch(client, weapon) {
	// Block weapon switching.
    decl String:sWeapon[32];
    GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
    
    if(!StrEqual(sWeapon, "weapon_decoy"))
        return Plugin_Handled;
    
    return Plugin_Continue;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	decl String:sWeapon[32];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));

	if(StrEqual(sWeapon, "weapon_decoy") || StrEqual(sWeapon, "decoy_projectile")) {
		// Set the damage of the decoy using the ConVar: "sm_db_damage"
		if (bDebug) {
			LogMessage("[DB Debug]%N is taking damage from a dodgeball! Damage: %f", victim, fDBDamage);
		}
		
		damage = fDBDamage;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Remove all player weapons.
	RemoveClientWeapons(client);
	
	// Give the client a decoy at spawn.
	RequestFrame(GiveDecoy, client);
	
	// Set the client's health and armor depending on the ConVars.
	SetEntityHealth(client, iClientHealth);
	SetEntProp(client, Prop_Send, "m_ArmorValue", iClientArmor);
	
	// Random Bounces Per Player (mode 2 for sm_db_random)
	if (iRandom == 2) {
		iBouncesRandClient[client] = GetRandomInt(iRandomMin, iRandomMax);
		
		// Check
		if (iBouncesRandClient[client] < 1) {
			iBouncesRandClient[client] = 1;
		}
		if (bDebug) {
			LogMessage("[DB Debug]iRandom is two. %N has the bounce count of %i", client, iBouncesRandClient[client]);
		}
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) { 
	// Now let's remove decoys right after player death.
	new iMaxEnts = GetMaxEntities();
	decl String:sClassName[64];
	for(new i=MaxClients;i<iMaxEnts;i++)
	{
		if(IsValidEntity(i) && IsValidEdict(i) && GetEdictClassname(i, sClassName, sizeof(sClassName)) && StrEqual(sClassName, "weapon_decoy") && GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == -1) {
			//RemoveEdict(i);
			AcceptEntityInput(i, "kill");	// Safer solution to remove items?
		}
	}
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	if (bRoundStartAd) {
		for (new i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && !IsFakeClient(i)) {
				PrintToChat(i, "\x02[DB]\x03 Decoy Dodgeball plugin made by [GFL] Roy (download at \x02GFLClan.com\x03).");
			}
		}
	}
	
	if (iRandom == 1) {
		// Mode one.
		iBouncesRand = GetRandomInt(iRandomMin, iRandomMax);
		
		if (bDebug) {
			LogMessage("[DB Debug]iRandom is one. Bounce count is %i for this round.", iBouncesRand);
		}
	}
	
	if (bMinigames) {
		// Minigames mode is enabled.
		new Handle:kv = CreateKeyValues("Minigames");
		decl String:filepath[255];
		BuildPath(Path_SM, filepath, sizeof(filepath), "configs/dodgeball_minigames.cfg");
		FileToKeyValues(kv, filepath);
		
		// To get the random minigame.
		new MaxMinigames = 0;
		new Minigame = 1;
		new blocksize =  ByteCountToCells(PLATFORM_MAX_PATH);
		new Handle:MinigameNames = CreateArray(blocksize);
		
		// Factors for each minigame.
		new Float:gravity, Float:friction, Float:timescale, Float:accelerate, String:rscc[MAX_NAME_LENGTH], String:recc[MAX_NAME_LENGTH], String:kname[MAX_NAME_LENGTH], announce, idefault;
		
		if (KvGotoFirstSubKey(kv)) {
			do {
				MaxMinigames++;
				decl String:buffer[255];
				KvGetSectionName(kv, buffer, sizeof(buffer));
				PushArrayString(MinigameNames, buffer);
				
			} while (KvGotoNextKey(kv));		
			KvRewind(kv);
			KvGotoFirstSubKey(kv)
			
			// Now pick a random minigame.
			Minigame = GetRandomInt(1, MaxMinigames);
			if (bDebug) {
				LogMessage("[DB Debug]Minigames: 1-%i", MaxMinigames);
			}
			
			new String:keyname[255];
			GetArrayString(MinigameNames, Minigame - 1, keyname, sizeof(keyname));
			
			decl String:buffer[255];
			do {
				KvGetSectionName(kv, buffer, sizeof(buffer));
				if (bDebug) {
					LogMessage("[DB Debug]Going through Minigame: \"%s\"... \"%s\" is the selected Minigame.", buffer, keyname);
				}
				if (StrEqual(buffer, keyname)) {
					if (bDebug) {
						LogMessage("[DB Debug]\"%s\" minigame selected...", buffer);
					}
					KvGetString(kv, "name", kname, sizeof(kname));
					gravity = KvGetFloat(kv, "gravity");
					friction = KvGetFloat(kv, "friction");
					timescale = KvGetFloat(kv, "timescale");
					accelerate = KvGetFloat(kv, "accelerate");
					announce = KvGetNum(kv, "announce");
					idefault = KvGetNum(kv, "default");
					KvGetString(kv, "rscc", rscc, sizeof(rscc));
					KvGetString(kv, "recc", recc, sizeof(recc));
				}
			} while (KvGotoNextKey(kv));
			// Now let's setup the game!
			if (!StrEqual(name, "")) {
				SetConVarFloat(f_gravity, gravity);
				SetConVarFloat(f_friction, friction);
				if (idefault || timescale == 1.0) {
					SetTimeScale(timescale, true);
				} else {
					SetTimeScale(timescale, false);
				}
				SetConVarFloat(f_accelerate, accelerate);
				if (!StrEqual(rscc, "")) {
					ServerCommand("exec %s", rscc);
				}
				if (announce) {
					PrintToChatAll("\x02[DB]\x03 Special Minigame \"\x02%s\x03\" is being played!", kname);
				}
				
				// Do the round end custom config
				strcopy(recc2, sizeof(recc2), recc);
			}
		}
		
		CloseHandle(kv);
		CloseHandle(MinigameNames);
	}
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	// Set all the factors back to default if Minigames is enabled.
	if (bMinigames) {
		SetConVarFloat(f_gravity, 800.0);
		SetConVarFloat(f_friction, 5.2);
		SetConVarFloat(f_accelerate, 5.5);
		SetTimeScale(1.0, true);
		
		if (!StrEqual(recc2, "")) {
			ServerCommand("exec %s", recc2);
		}
	}
}

public OnEntityCreated(entity, const String:classname[]) {
	if (StrEqual(classname, "decoy_projectile", false)) {
		SDKHook(entity, SDKHook_Spawn, OnEntitySpawned);
		SDKHook(entity, SDKHook_StartTouch, OnEntityTouch);
	}
}

public OnEntitySpawned(entity) {
	new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	// Remove all player weapons.
	RemoveClientWeapons(client);
	
	// Give the client a decoy on the next frame (safe)!
	RequestFrame(GiveDecoy2, client);
}

public OnEntityTouch(entity, tentity) {
	new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner > MaxClients || owner < 1) {
		// Not a valid owner...
		if (bDebug) {
			LogMessage("[DB Debug]OnEntityTouch reported the owner isn't valid. %i is the owner index.", owner);
		}
		return;
	}
	
	if (0 < tentity < MaxClients) {	// I guess I could do if (0 > tentity > MaxClients) { // Kill code } but meh...
		// This is a player.
		// Let's do the custom hits.
		if(GetClientTeam(tentity) != GetClientTeam(owner) && GetClientTeam(tentity) > 1 && bCustomHitReg) {
			// Not on the same team.
			new curhp = GetClientHealth(tentity);
			new newhp = curhp - RoundFloat(fDBDamage);
			if (newhp < 1) {
				ForcePlayerSuicide(tentity);
			} else {
				SetEntityHealth(tentity, newhp);
			}
		}
	} else {
		iBounceCount[entity] += 1;
		
		if (!iRandom) {
			if (bDebug) {
				LogMessage("[DB Debug]iRandom isn't enabled.");
			}
			// Random mode is off, continue with the default setup.
			if (iBounceCount[entity] >= iBounces) {
				if (bDebug) {
					LogMessage("[DB Debug]iRandom isn't enabled. Bounces exceeded. %i/%i", iBounceCount[entity], iBounces);
				}
				KillDodgeball(entity);
			}
		} else if (iRandom == 1) {
			// Mode one.
			if (bDebug) {
				LogMessage("[DB Debug]iRandom is set to mode one.");
			}
			
			if (iBounceCount[entity] >= iBouncesRand) {
				if (bDebug) {
					LogMessage("[DB Debug]iRandom is set to mode one. Bounces exceeded. %i/%i", iBounceCount[entity], iBouncesRand);
				}
				KillDodgeball(entity);
			}
		} else if (iRandom == 2) {
			// Mode two.
			if (bDebug) {
				LogMessage("[DB Debug]iRandom is set to mode two.");
			}
			
			if (iBounceCount[entity] >= iBouncesRandClient[owner]) {
				if (bDebug) {
					LogMessage("[DB Debug]iRandom is set to mode two. Bounces exceeded. %i/%i", iBounceCount[entity], iBouncesRandClient[owner]);
				}
				KillDodgeball(entity);
			}
		} else if (iRandom == 3) {
			// Mode three.
			if (bDebug) {
				LogMessage("[DB Debug]iRandom is set to mode three.");
			}
			
			if (iBounceCount[entity] >= iBouncesRandClient[owner]) {
				if (bDebug) {
					LogMessage("[DB Debug]iRandom is set to mode three. Bounces exceeded. %i/%i", iBounceCount[entity], iBouncesRandClient[owner]);
				}
				KillDodgeball(entity);
			}
		} else {
			if (bDebug) {
				LogMessage("[DB Debug]iRandom isn't recognized. iRandom isn't enabled.");
			}
			// Random mode isn't recognized, setting to the default setup.
			if (iBounceCount[entity] >= iBounces) {
				if (bDebug) {
					LogMessage("[DB Debug]iRandom isn't recognized. iRandom isn't enabled. Bounces exceeded. %i/%i", iBounceCount[entity], iBounces);
				}
				KillDodgeball(entity);
			}
		}
	}
}

public GiveDecoy(any:client) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		GiveDodgeball(client);
	}
	
	if (bPrint) {
		PrintToChat(client, "\x02[DB]\x03 Decoy equipped! Go play some dodgeball!");
	}
}

public GiveDecoy2(any:client) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		// Delay giving dodgeballs so it isn't spamming dodgeballs...
		CreateTimer(fGiveTime, GiveDecoy2Timer, client);
	}
}

public Action:GiveDecoy2Timer(Handle:timer, any:client) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		new ent = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE);
		new String:weaponname[64];
		if (ent != -1) {
			GetEntityClassname(ent, weaponname, sizeof(weaponname));
		}
		
		// Now to give the item again.
		if (!StrEqual(weaponname, "weapon_decoy", false)) {
			GiveDodgeball(client);
		}
	}
}

// Dodgeball specific functions (not sure whether to use public or stock).
stock KillDodgeball(entity) {
	if (bDebug) {
		LogMessage("[DB Debug]Attempting to kill the dodgeball.");
	}
	// Kill the entity.
	AcceptEntityInput(entity, "kill");
	
	// Reset the entity index bounce count.
	iBounceCount[entity] = 0;
}

stock GiveDodgeball(client) {
	GivePlayerItem(client, "weapon_decoy");
	
	if (iRandom == 3) {
		iBouncesRandClient[client] = GetRandomInt(iRandomMin, iRandomMax);
		
		// Check
		if (iBouncesRandClient[client] < 1) {
			iBouncesRandClient[client] = 1;
		}
	}
}

stock SetTimeScale(Float:ts, bool:reset) {
	SetConVarFloat(f_timescale, ts);
	
	if (reset) {
		UpdateClientCheats(0);
	} else {
		UpdateClientCheats(1);
	}
	
	ServerCommand("host_timescale %f", ts);
}

stock UpdateClientCheats(const value) {
	new Handle:cheats = FindConVar("sv_cheats");
	if (cheats == INVALID_HANDLE) {
		return;
	}
	
	for (new i = 1; i <= MaxClients; i++) {
		if (IsValidEdict(i) && IsClientConnected(i) && !IsFakeClient(i)) {
			decl String:svalue[11];
			IntToString(value, svalue, sizeof(svalue));
			SendConVarValue(i, cheats, svalue);
		}
	}
}

stock RemoveClientWeapons(client) {
	for (new i=0; i <= 5; i++) {
		new ent = -1;
		ent = GetPlayerWeaponSlot(client, i);
		if (ent != -1) {
			RemovePlayerItem(client, ent);
			RemoveEdict(ent);
		}
	}
}