
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <json>
#include <nvault>

#include <emma_jule>

// Для поддержки VIP-статуса в ScoreAttrib
#if !defined SCORE_STATUS_VIP
#define SCORE_STATUS_VIP (1<<2)
#endif

// ...existing code...

const EntVars:viewmodel = var_noise1;
const EntVars:playermodel = var_noise2;
const EntVars:gunmodel = var_message;
stock const EntVars:weapon_access = var_iuser4;
stock const EntVars:weapon_speed = var_fuser4;

const FFADE_IN = 0x0000;
const UNIT_SECOND = (1 << 12);
const INVALID_ACCESS = (1 << 31);

// Special menu action ID for clearing saved weapon (beyond any weapon/section index)
const VIP_CLEAR_SAVED_WEAPON_ACTION = 250;

// Максимальное допустимое кол-во кастомных оружий
const MAX_CUSTOM_WEAPONS = 64;

enum _:CVARS
{
	// Core
	ACCESS_MODE,
	MENU_ROUND,
	
	// Info
	TAB_ACCESS,
	ONLINE_ACCESS,
	ONLINE_PLAYERS,
	CONNECT_ACCESS,
	
	// Equip
	EQUIP_ROUND,
	EQUIP_ONLY_1,
	EQUIP_HE_ACCESS,
	EQUIP_HE_NUMS,
	EQUIP_FLASH_ACCESS,
	EQUIP_FLASH_NUMS,
	EQUIP_SMOKE_ACCESS,
	EQUIP_SMOKE_NUMS,
	EQUIP_AUTO_RELOAD_ACCESS,
	EQUIP_ARMOR_ACCESS,
	EQUIP_DKIT_ACCESS,
	EQUIP_NIGHTVISION_ACCESS,
	EQUIP_KNIFE_ACCESS,
	EQUIP_SILENT_RUN_ACCESS,
	
	// Abilities
	FALL_DAMAGE_ACCESS,
	PLANT_UNFREEZE_ACCESS,
	ANTIFLASH_ACCESS,
	DJUMP_ACCESS,
	DJUMPS,
	HOOK_DAMAGE_ACCESS,
	HOOK_DAMAGE_CHANCE,
	// WALL_DAMAGE_ACCESS,
	HEALTH_ACCESS,
	Float:HEALTH_AMOUNT,
	MENU_MODE,
	ONLY_IN_BUYZONE,
	EXPIRED,
	Float:EXPIRED_TIME,
	INSTANT_RELOAD_ACCESS,
	INSTANT_RELOAD,
	
	// Bonuses
	BONUS_ACCESS,
	BONUS_FRAGS,
	BONUS_KILLED,
	BONUS_EXPLODE_BOMB,
	BONUS_PLANT_BOMB,
	BONUS_DEFUSED_BOMB,
	BONUS_HOSTAGE_TOOK,
	BONUS_HOSTAGE_RESCUED,
	BONUS_VIP_KILLED,
	BONUS_VIP_RESCUED_MYSELF,
	Float:BONUS_ROUND,
	Float:BONUS_DISCOUNT,
	
	// Vampire
	VAMPIRE_ACCESS,
	Float:VAMPIRE_HEALTH,
	Float:VAMPIRE_HEALTH_HS,
	Float:VAMPIRE_HEALTH_NADE,
	Float:VAMPIRE_HEALTH_MAX,
	VAMPIRE_SCREENFADE,
	VAMPIRE_HUD,
	// VAMPIRE_OBEY_LIMIT,
	VAMPIRE_PREVENT_MULTIPLY,
	VAMPIRE_SAMPLE[MAX_RESOURCE_PATH_LENGTH]
	
};	new CVAR[CVARS];

enum _:WEAPON_DATA
{
	NAME[64],	// ArrayFindString
	
	ACCESS,
	BASE_NAME[24],
	V_MODEL[MAX_RESOURCE_PATH_LENGTH],
	P_MODEL[MAX_RESOURCE_PATH_LENGTH],
	W_MODEL[MAX_RESOURCE_PATH_LENGTH],
	Float:STAB_DISTANCE,
	Float:SWING_DISTANCE,
	Float:STAB_DAMAGE,
	Float:SWING_DAMAGE,
	Float:BASE_DAMAGE,
	Float:SPEED_MULTIPLY,
	AMMO,
	BPAMMO,
	GIVE_MODE,
	COST,
	ROUND,
	NO_TOUCHES,
	TeamName: TEAM,
	FREE,	// NULL
	MENU_FOLDER[64]	// NULL

};	new Array:g_aCustomWeapons, g_iCustomWeaponsNum;

enum (<<=1)
{
	NO_PRIMARY = 1, // 1
	DIE_IN_PREVIOUS_ROUND, // 2
	LEFT_ITEMS, // 4
};

enum _:SECTION_STRUCT {
	SECTION_MENU[64],
	SECTION_FLAGS,
};

new g_iUsageCount[MAX_PLAYERS + 1], g_iCustomWeaponLeftRounds[MAX_PLAYERS + 1][MAX_CUSTOM_WEAPONS];
new Array:g_aSampleConnectMusic, Array:g_aMenuSections, g_SamplesConnectNum;
new g_hSavedWeaponsVault = INVALID_HANDLE;
new Trie:g_tMaxUsages, Trie:g_tUsagesRoundRestrictions, Trie:g_tDefaultWeapons; // Trie:g_tWallClassNames
new bool:g_IsNoVIPMenuOnThisMap = false, bool:g_IsNoEquipOnThisMap = false;
new HamHook:fw_C4_PrimaryAttack;
new g_iDefaultMaxUses;
new g_szMapName[64];

public plugin_precache()
{
	register_plugin("VIP System", "2.1.1", "Emma Jule");
	
	g_hSavedWeaponsVault = nvault_open("vip_saved_weapons");
	
	// Get current map name
	get_mapname(g_szMapName, charsmax(g_szMapName));
	
	// Хранилища
	g_aCustomWeapons = ArrayCreate(WEAPON_DATA, 0);
	g_aSampleConnectMusic = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 0);
	g_aMenuSections = ArrayCreate(SECTION_STRUCT, 0);
	g_tMaxUsages = TrieCreate();
	g_tUsagesRoundRestrictions = TrieCreate();
	// g_tWallClassNames = TrieCreate();
	
	// Fix get_weaponid() после релоада сервера всегда будет 0
	g_tDefaultWeapons = TrieCreate();
	{
		enum eWeapons { NAME[17], CSW };
		static const eDefWeapons[][eWeapons] = {
			{ "p228" , CSW_P228 }, { "scout" , CSW_SCOUT }, { "hegrenade" , CSW_HEGRENADE }, { "xm1014" , CSW_XM1014 },
			{ "mac10" , CSW_MAC10 }, { "aug" , CSW_AUG }, { "smokegrenade" , CSW_SMOKEGRENADE }, { "elite" , CSW_ELITE },
			{ "fiveseven" , CSW_FIVESEVEN }, { "ump45" , CSW_UMP45 }, { "sg550" , CSW_SG550 }, { "galil" , CSW_GALIL },
			{ "famas" , CSW_FAMAS }, { "usp" , CSW_USP }, { "glock18" , CSW_GLOCK18 }, { "awp" , CSW_AWP },
			{ "mp5navy" , CSW_MP5NAVY }, { "m249" , CSW_M249 }, { "m3" , CSW_M3 }, { "m4a1" , CSW_M4A1 },
			{ "tmp" , CSW_TMP }, { "g3sg1" , CSW_G3SG1 }, { "flashbang" , CSW_FLASHBANG }, { "deagle" , CSW_DEAGLE },
			{ "sg552" , CSW_SG552 }, { "ak47" , CSW_AK47 }, { "knife" , CSW_KNIFE }, { "p90" , CSW_P90 }
		};
		
		for (new i = sizeof(eDefWeapons) - 1; i >= 0; --i)
			TrieSetCell(g_tDefaultWeapons, eDefWeapons[i][NAME], eDefWeapons[i][CSW]);
	}
	
	// Load system
	if (!LoadSettings())
		set_fail_state("Something went wrong");
	
	if (g_aCustomWeapons)
		server_print("#1FUP: Успешно загружено %i кастомных оружий!", g_iCustomWeaponsNum = ArraySize(g_aCustomWeapons));
	
	if (!g_aSampleConnectMusic)
		ArrayDestroy(g_aSampleConnectMusic);
	else
		g_SamplesConnectNum = ArraySize(g_aSampleConnectMusic);
	
	if (!g_tMaxUsages)
		TrieDestroy(g_tMaxUsages);
/*
	if (!g_tWallClassNames)
		TrieDestroy(g_tWallClassNames);
*/
	TrieDestroy(g_tDefaultWeapons);
}

public plugin_init()
{
	if (register_dictionary("vip_system.txt") == 0) {
		//createLangFile();
	}
	
	if (CVAR[TAB_ACCESS])
		register_message(get_user_msgid("ScoreAttrib"), "Message_ScoreAttrib");
	
	//if (CVAR[ONLY_IN_BUYZONE])
		// register_event("StatusIcon", "Event_HideStatusIcon", "b", "1=0", "2=buyzone");
	
	if (!g_IsNoEquipOnThisMap)
		RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip", true);
	
	if (get_member_game(m_bMapHasBombTarget))
	{
		if (CVAR[PLANT_UNFREEZE_ACCESS])
		{
			// ConnorMcLeod
			RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "CBaseWeapon_C4_PrimaryAttack", false);
			DisableHamForward(fw_C4_PrimaryAttack = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "CBaseWeapon_C4_PrimaryAttack_P", true));
			
			RegisterHookChain(RG_CGrenade_DefuseBombStart, "CGrenade_DefuseBombStart", true);
		}
		
		if (CVAR[BONUS_ACCESS])
		{
			if (CVAR[BONUS_EXPLODE_BOMB])
				RegisterHookChain(RG_CGrenade_ExplodeBomb, "CGrenade_ExplodeBomb", false);
			
			if (CVAR[BONUS_PLANT_BOMB])
				RegisterHookChain(RG_PlantBomb, "PlantBomb", true);
			
			if (CVAR[BONUS_DEFUSED_BOMB])
				RegisterHookChain(RG_CGrenade_DefuseBombEnd, "CGrenade_DefuseBombEnd", true);
		}
	}
	
	if (CVAR[BONUS_ACCESS])
	{
		RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount", false);
		if (CVAR[BONUS_FRAGS])
			RegisterHookChain(RG_CBasePlayer_AddPoints, "CBasePlayer_AddPoints", false);
	}
	
	if (CVAR[DJUMP_ACCESS])
		RegisterHookChain(RG_CBasePlayer_Jump, "CBasePlayer_Jump", true);
	
	if (CVAR[FALL_DAMAGE_ACCESS])
		RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "CSGameRules_FlPlayerFallDamage", true);
	
	if (CVAR[ANTIFLASH_ACCESS])
		RegisterHookChain(RG_PlayerBlind, "CBasePlayer_PlayerBlind", false);
	
	if (CVAR[HOOK_DAMAGE_ACCESS])
		RegisterHookChain(RG_CSGameRules_FPlayerCanTakeDamage, "CSGameRules_FPlayerCanTakeDamage", false);
	
	// RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true);
	RegisterHookChain(RG_CBasePlayer_ThrowGrenade, "CBasePlayer_ThrowGrenade", true);
	// RG_CBasePlayerWeapon_DefaultDeploy not supported in current ReAPI version
	// RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy", false);
	RegisterHookChain(RG_CWeaponBox_SetModel, "CWeaponBox_SetModel", false);
	
	RegisterHam(Ham_Touch, "weaponbox", "CWeaponBox_Touch", false);
	
	if (g_iCustomWeaponsNum > 0)
		RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", false);
	
/*
	if (CVAR[ADVANCED_SCOPE])
	{
		static const szWeapon[][] = {
			"weapon_scout", "weapon_awp", "weapon_sg550", "weapon_g3sg1"
		};
		
		for (new i; i < sizeof(szWeapon); i++);
			RegisterHam(Ham_Item_Deploy, szWeapon[i], "CBaseWeapon_", true);
	}
*/

}

public client_disconnected(id)
{
	// if (!UTIL_IsAccessGranted(id, ADMIN_ADMIN))
		// return;
	
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));
	{
		TrieSetArray(g_tUsagesRoundRestrictions, szAuth, g_iCustomWeaponLeftRounds[id], sizeof(g_iCustomWeaponLeftRounds[]));
	}
}

public client_authorized(id, const szAuth[])
{
	if (!TrieGetArray(g_tUsagesRoundRestrictions, szAuth, g_iCustomWeaponLeftRounds[id], sizeof(g_iCustomWeaponLeftRounds[])))
	{
		g_iCustomWeaponLeftRounds[id][0] = '^0';
	}
}

public client_putinserver(id)
{
	if (!CVAR[CONNECT_ACCESS])
		return;
	
	set_task(1.25, "@print_vip", id);
}

@print_vip(id)
{
	if (!is_user_connected(id))
		return;
	
	if (!UTIL_IsAccessGranted(id, CVAR[CONNECT_ACCESS]))
		return;
	
	client_print_color(0, id, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_CONNECT_INFO", id);
	
	if (g_SamplesConnectNum > 0)
		rg_send_audio(0, fmt("sound/%a", ArrayGetStringHandle(g_aSampleConnectMusic, random(g_SamplesConnectNum))));
}

public clcmd_vip_menu(id)
{
	if (g_iCustomWeaponsNum < 1)
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_NO_CUSTOM_WEAPONS");
		return PLUGIN_HANDLED;
	}
	
	if (g_IsNoVIPMenuOnThisMap)
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_NO_CUSTOM_WEAPONS_ON_THIS_MAP");
		return PLUGIN_HANDLED;
	}
	
	if (rg_get_current_round() < CVAR[MENU_ROUND])
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_ROUND", CVAR[MENU_ROUND]);
		return PLUGIN_HANDLED;
	}

	if (!rg_user_in_buyzone(id))
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_NOT_IN_BUYZONE");
		return PLUGIN_HANDLED;
	}
	
	if (!is_user_alive(id))
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_NOT_ALIVE");
		return PLUGIN_HANDLED;
	}
	
	if (UTIL_IsTimeExpired(id, CVAR[EXPIRED_TIME]))
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_TIME_EXPIRED");
		return PLUGIN_HANDLED;
	}
	
	if (UTIL_IsMaxTimesReached(id))
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_MAX_USE");
		return PLUGIN_HANDLED;
	}
	
	// Show vip weapons
	show_vip_menu(id);
	
	return PLUGIN_HANDLED;
}

show_vip_menu(id)
{
	new menu = menu_create(fmt("%L", LANG_PLAYER, "VIP_MENU_TITLE", g_iUsageCount[id]), "vip_menu_handler");
	
	// Show saved weapon option at top if exists
	new iSavedIdx = GetSavedWeaponIndex(id);
	if (iSavedIdx >= 0 && iSavedIdx < g_iCustomWeaponsNum)
	{
		new aSaved[WEAPON_DATA];
		ArrayGetArray(g_aCustomWeapons, iSavedIdx, aSaved);
		menu_additem(menu, fmt("%L", LANG_PLAYER, "VIP_MENU_SAVED_WEAPON", aSaved[NAME]), fmt("%d", VIP_CLEAR_SAVED_WEAPON_ACTION));
	}
	
	// Load sections
	for (new i, Section[SECTION_STRUCT], aSize = ArraySize(g_aMenuSections), iFlags = get_user_flags(id); i < aSize; i++)
	{
		ArrayGetArray(g_aMenuSections, i, Section);
		if (iFlags & Section[SECTION_FLAGS])
			menu_additem(menu, Section[SECTION_MENU], fmt("%i", MAX_CUSTOM_WEAPONS + i));
	}
	
	// Load weapons
	FillCustomWeapons(id, menu);
	
	if (menu_items(menu) < 1)
	{
		// client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_NO_ACCESS");
		menu_destroy(menu);
		return;
	}
	
	menu_setprop(menu, MPROP_SHOWPAGE, false);
	menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "VIP_MENU_NEXT"));
	menu_setprop(menu, MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "VIP_MENU_BACK"));
	menu_setprop(menu, MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "VIP_MENU_EXIT"));
	
	menu_display(id, menu);
}

public vip_menu_handler(id, menu, item)
{
	// Just EXIT
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	if (!is_user_alive(id))
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_NOT_ALIVE");
		return PLUGIN_HANDLED;
	}
	
	if (UTIL_IsTimeExpired(id, CVAR[EXPIRED_TIME]))
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_TIME_EXPIRED");
		return PLUGIN_HANDLED;
	}
	
	if (!rg_user_in_buyzone(id))
	{
		client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_NOT_IN_BUYZONE");
		return PLUGIN_HANDLED;
	}
	
	new szID[6], szMenu[64];
	menu_item_getinfo(menu, item, .info = szID, .infolen = charsmax(szID), .name = szMenu, .namelen = charsmax(szMenu));
	menu_destroy(menu);
	new i = strtol(szID);
	
	if (i == VIP_CLEAR_SAVED_WEAPON_ACTION)
	{
		ClearSavedWeapon(id);
		client_print_color(id, print_team_blue, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_SAVED_WEAPON_CLEARED");
		return PLUGIN_HANDLED;
	}
	else if (i < MAX_CUSTOM_WEAPONS)
	{
		new aWeapon[WEAPON_DATA];
		ArrayGetArray(g_aCustomWeapons, i, aWeapon);
		
		if (get_member(id, m_iAccount) < aWeapon[COST])
		{
			UTIL_BlinkAcct(MSG_ONE_UNRELIABLE, id, 2);
			return PLUGIN_HANDLED;
		}
		
		if (give_item(id, aWeapon))
		{
			//
			rg_add_account(id, -aWeapon[COST]);
			client_print_color(id, print_team_blue, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_BUY_CUSTOM_GUN", aWeapon[NAME])
			if (aWeapon[ROUND] > 0)
				g_iCustomWeaponLeftRounds[id][i] = aWeapon[ROUND];
			
			g_iUsageCount[id]++;
			// Show save prompt (it will re-show vip menu if LEFT_ITEMS after choice)
			show_vip_save_menu(id, i);
		}
	}
	else
	{
		menu = menu_create(NULL_STRING, "vip_menu_handler");
		
		// Load weapons
		FillCustomWeapons(id, menu, szMenu);
		
		if ((i = menu_items(menu)) < 1)
		{
			// client_print_color(id, print_team_red, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_NO_ACCESS");
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		
		menu_setprop(menu, MPROP_TITLE, fmt("%L", LANG_PLAYER, "VIP_SECTION_MENU_TITLE", szMenu, i));
		menu_setprop(menu, MPROP_SHOWPAGE, false);
		menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "VIP_MENU_NEXT"));
		menu_setprop(menu, MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "VIP_MENU_BACK"));
		menu_setprop(menu, MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "VIP_MENU_EXIT"));
		
		menu_display(id, menu);
	}
	
	return PLUGIN_HANDLED;
}

// Load custom weapons
FillCustomWeapons(const id, const menu, const folder[] = "")
{
	for (new i, TeamName:team = get_member(id, m_iTeam), iAccount = get_member(id, m_iAccount), aWeapon[WEAPON_DATA]; i < g_iCustomWeaponsNum; i++)
	{
		ArrayGetArray(g_aCustomWeapons, i, aWeapon);
		
		if (!aWeapon[NAME][0])
			continue;
		
		if (strcmp(folder, aWeapon[MENU_FOLDER]) != 0)
			continue;
		
		if (TEAM_UNASSIGNED < aWeapon[TEAM] < TEAM_SPECTATOR && team != aWeapon[TEAM])
			continue;
		
		if (iAccount < aWeapon[COST])
			menu_additem(menu, fmt("%L", LANG_PLAYER, "VIP_WEAPON_NO_MONEY", aWeapon[NAME], aWeapon[COST]), .paccess = INVALID_ACCESS);
		else if (g_iCustomWeaponLeftRounds[id][i] > 0)
			menu_additem(menu, fmt("%L", LANG_PLAYER, "VIP_WEAPON_INVALID_ROUND", aWeapon[NAME], g_iCustomWeaponLeftRounds[id][i]), .paccess = INVALID_ACCESS);
		else
			menu_additem(menu, aWeapon[NAME], fmt("%i", i), aWeapon[ACCESS]);
	}
}

// Команда /vips
public clcmd_vip_online(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	new aPlayers[MAX_PLAYERS], iPlayers, pVIP, iCount, szText[192];
	new iMaxVisiblePlayers = CVAR[ONLINE_PLAYERS];
	get_players(aPlayers, iPlayers, "ch");
	
	while (--iPlayers >= 0)
	{
		pVIP = aPlayers[iPlayers];
		
		if (!UTIL_IsAccessGranted(pVIP, CVAR[ONLINE_ACCESS]))
			continue;
		
		if (++iCount == 1)
			strcat(szText, fmt("%n", pVIP), charsmax(szText));
		else if (iCount <= iMaxVisiblePlayers)
			strcat(szText, fmt(", %n", pVIP), charsmax(szText));
	}
	
	if (iCount > 0)
	{
		if (iCount > iMaxVisiblePlayers)
			strcat(szText, fmt(iCount - iMaxVisiblePlayers == 1 ? " и ещё 1" : " и %i других", iCount - iMaxVisiblePlayers), charsmax(szText));
		
		client_print_color(id, print_team_blue, "%L %L %s", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_ONLINE", szText);
	}
	else
		client_print_color(id, print_team_red, "%L %L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_ONLINE", LANG_PLAYER, "VIP_ONLINE_NO");
	
	return PLUGIN_HANDLED;
}

public Event_HideStatusIcon(const id)
{
	// UTIL_CloseMenu(id);
}

public CSGameRules_RestartRound()
{
	if (get_member_game(m_bCompleteReset))
	{
		arrayset(g_iCustomWeaponLeftRounds[0][0], 0, sizeof g_iCustomWeaponLeftRounds[] * sizeof g_iCustomWeaponLeftRounds);
		
		TrieClear(g_tUsagesRoundRestrictions);
	}
	else
	{
		for (new i = MaxClients; i > 0; i--)
		{
			for (new pWeapon; pWeapon < MAX_CUSTOM_WEAPONS; pWeapon++)
			{
				max(--g_iCustomWeaponLeftRounds[i][pWeapon], 0);
			}
		}
		
		new TrieIter:iter = TrieIterCreate(g_tUsagesRoundRestrictions);
		
		for (new szAuth[MAX_AUTHID_LENGTH], aArray[MAX_CUSTOM_WEAPONS], aSize; !TrieIterEnded(iter); TrieIterNext(iter))
		{
			TrieIterGetKey(iter, szAuth, charsmax(szAuth));
			TrieIterGetArray(iter, aArray, aSize = sizeof(aArray));
			
			for (new i; i < aSize; i++)
				max(--aArray[i], 0);
			
			TrieSetArray(g_tUsagesRoundRestrictions, szAuth, aArray, aSize);
		}
		
		TrieIterDestroy(iter);
	}
}

public CBasePlayer_OnSpawnEquip(const id)
{
	if (UTIL_IsAccessGranted(id, CVAR[HEALTH_ACCESS]))
	{
		set_entvar(id, var_health, Float: get_entvar(id, var_health) + CVAR[HEALTH_AMOUNT]);
	}
	
	if (rg_get_current_round() < CVAR[EQUIP_ROUND])
		return;
	
	if (CVAR[EQUIP_ONLY_1] && !rg_is_user_first_spawn(id))
		return;
	
	// Reset counter
	g_iUsageCount[id] = 0;
	
	// Last Additions
	if (UTIL_IsAccessGranted(id, CVAR[EQUIP_HE_ACCESS]))
	{
		rg_give_item(id, "weapon_hegrenade");
		rg_set_user_bpammo(id, WEAPON_HEGRENADE, CVAR[EQUIP_HE_NUMS]);
	}
	
	if (UTIL_IsAccessGranted(id, CVAR[EQUIP_FLASH_ACCESS]))
	{
		rg_give_item(id, "weapon_flashbang");
		rg_set_user_bpammo(id, WEAPON_FLASHBANG, CVAR[EQUIP_FLASH_NUMS]);
	}
	
	if (UTIL_IsAccessGranted(id, CVAR[EQUIP_SMOKE_ACCESS]))
	{
		rg_give_item(id, "weapon_smokegrenade");
		rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, CVAR[EQUIP_SMOKE_NUMS]);
	}
	
	if (UTIL_IsAccessGranted(id, CVAR[EQUIP_AUTO_RELOAD_ACCESS]))
		rg_instant_reload_weapons(id);
	
	if (UTIL_IsAccessGranted(id, CVAR[EQUIP_ARMOR_ACCESS]))
		rg_give_item(id, "item_assaultsuit");
	
	if (UTIL_IsAccessGranted(id, CVAR[EQUIP_NIGHTVISION_ACCESS]))
		set_member(id, m_bHasNightVision, true);
	
	if (UTIL_IsAccessGranted(id, CVAR[EQUIP_SILENT_RUN_ACCESS]))
		rg_set_user_footsteps(id, true);
	
	if (UTIL_IsAccessGranted(id, CVAR[EQUIP_DKIT_ACCESS]) && get_member(id, m_iTeam) == TEAM_CT)
		rg_give_defusekit(id, true);
	
	//
	if (g_iCustomWeaponsNum < 1)
		return;
	
	// Its free weapons
	for (new i, aWeapon[WEAPON_DATA]; i < g_iCustomWeaponsNum; i++)
	{
		ArrayGetArray(g_aCustomWeapons, i, aWeapon);
		
		if (!UTIL_IsAccessGranted(id, aWeapon[FREE]))
			continue;
		
		give_item(id, aWeapon);
	}
	
	// Fixes
	if (rg_get_current_round() < CVAR[MENU_ROUND])
		return;
	
	// Show vip menu or auto-give saved weapon?
	if ((CVAR[MENU_MODE] & NO_PRIMARY) && !rg_user_has_primary(id) || (CVAR[MENU_MODE] & DIE_IN_PREVIOUS_ROUND) && !get_member(id, m_bNotKilled))
	{
		new iSavedIdx = GetSavedWeaponIndex(id);
		if (iSavedIdx >= 0 && iSavedIdx < g_iCustomWeaponsNum)
		{
			new aSaved[WEAPON_DATA];
			ArrayGetArray(g_aCustomWeapons, iSavedIdx, aSaved);
			
			if (aSaved[NAME][0] && UTIL_IsAccessGranted(id, aSaved[ACCESS]) && g_iCustomWeaponLeftRounds[id][iSavedIdx] <= 0)
			{
				if (give_item(id, aSaved))
				{
					rg_add_account(id, -aSaved[COST]);
					if (aSaved[ROUND] > 0)
						g_iCustomWeaponLeftRounds[id][iSavedIdx] = aSaved[ROUND];
					g_iUsageCount[id]++;
					client_print_color(id, print_team_blue, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_AUTO_WEAPON", aSaved[NAME]);
					return; // skip showing menu
				}
			}
		}
		show_vip_menu(id);
	}
}

public CBaseWeapon_C4_PrimaryAttack(const pWeapon)
{
	new id = get_member(pWeapon, m_pPlayer);
	
	// ConnorMcLeod
	if (UTIL_IsAccessGranted(id, CVAR[PLANT_UNFREEZE_ACCESS]) && !get_member(pWeapon, m_C4_bStartedArming) && rg_user_in_bombzone(id) && (get_entvar(id, var_flags) & FL_ONGROUND) == FL_ONGROUND)
	{
		EnableHamForward(fw_C4_PrimaryAttack);
	}
}

public CBaseWeapon_C4_PrimaryAttack_P(const pWeapon)
{
    DisableHamForward(fw_C4_PrimaryAttack);
	
	// Def speed with bomb
    set_entvar(get_member(pWeapon, m_pPlayer), var_maxspeed, 250.0);
}

public PlantBomb(id, Float:vecStart[3], Float:vecVelocity[3])
{
	if (UTIL_IsAccessGranted(id, CVAR[BONUS_ACCESS]))
	{
		rg_add_account(id, CVAR[BONUS_PLANT_BOMB]);		
	}
}

public CGrenade_ExplodeBomb(const this, tracehandle, const dmg_bits)
{
	new id = get_entvar(this, var_owner);
	
	if (is_user_connected(id) && UTIL_IsAccessGranted(id, CVAR[BONUS_ACCESS]))
	{
		rg_add_account(id, CVAR[BONUS_EXPLODE_BOMB]);
	}
}

public CGrenade_DefuseBombStart(const ent, const id)
{
	if (UTIL_IsAccessGranted(id, CVAR[PLANT_UNFREEZE_ACCESS]))
	{
		new Float:fSpeed = 250.0;
		new pWeapon = get_member(id, m_pActiveItem);
		
		if (!is_nullent(pWeapon))
			ExecuteHamB(Ham_CS_Item_GetMaxSpeed, pWeapon, fSpeed);
		
		set_entvar(id, var_maxspeed, fSpeed);
	}
}

public CGrenade_DefuseBombEnd(const this, const id, bool:bDefused)
{
	if (bDefused && UTIL_IsAccessGranted(id, CVAR[BONUS_ACCESS]))
	{
		rg_add_account(id, CVAR[BONUS_DEFUSED_BOMB]);
	}
}

public CBasePlayer_AddAccount(const id, amount, RewardType:type, bool:bTrackChange)
{
	if (!UTIL_IsAccessGranted(id, CVAR[BONUS_ACCESS]))
		return;
	
	// Def game bonuses
	if (CVAR[BONUS_KILLED] && type == RT_ENEMY_KILLED)
		SetHookChainArg(2, ATYPE_INTEGER, CVAR[BONUS_KILLED]);
	else if (CVAR[BONUS_HOSTAGE_TOOK] && type == RT_HOSTAGE_TOOK)
		SetHookChainArg(2, ATYPE_INTEGER, CVAR[BONUS_HOSTAGE_TOOK]);
	else if (CVAR[BONUS_HOSTAGE_RESCUED] && type == RT_HOSTAGE_RESCUED)
		SetHookChainArg(2, ATYPE_INTEGER, CVAR[BONUS_HOSTAGE_RESCUED]);	
	else if (CVAR[BONUS_VIP_KILLED] && type == RT_VIP_KILLED)
		SetHookChainArg(2, ATYPE_INTEGER, CVAR[BONUS_VIP_KILLED]);
	else if (CVAR[BONUS_VIP_RESCUED_MYSELF] && type == RT_VIP_RESCUED_MYSELF)
		SetHookChainArg(2, ATYPE_INTEGER, CVAR[BONUS_VIP_RESCUED_MYSELF]);
	else if (CVAR[BONUS_DISCOUNT] && type == RT_PLAYER_BOUGHT_SOMETHING) // shop discount
		SetHookChainArg(2, ATYPE_INTEGER, floatround(float(amount) - (amount / 100.0 * CVAR[BONUS_DISCOUNT]), floatround_ceil));
	else if (CVAR[BONUS_ROUND] && type == RT_ROUND_BONUS) // round terminating
		SetHookChainArg(2, ATYPE_INTEGER, floatround(float(amount) * CVAR[BONUS_ROUND]));
}

// Скорее всего в будущем этот форвард будет более функциональней
// Допустим это также будет вызыватся когда +3 от подрыва или разминирования бомбы
public CBasePlayer_AddPoints(const id, score, bAllowNegativeScore)
{
	if (UTIL_IsAccessGranted(id, CVAR[BONUS_ACCESS]))
	{
		SetHookChainArg(2, ATYPE_INTEGER, score + CVAR[BONUS_FRAGS]);
	}
}

public CSGameRules_FlPlayerFallDamage(const id)
{
	if (UTIL_IsAccessGranted(id, CVAR[FALL_DAMAGE_ACCESS]))
	{
		SetHookChainReturn(ATYPE_FLOAT, 0.0);
	}
}

public CBasePlayer_PlayerBlind(const id, inflictor, attacker, Float:fadetime, const Float:fadehold, const alpha, const Float:color[3])
{
	if (UTIL_IsAccessGranted(id, CVAR[ANTIFLASH_ACCESS]))
	{
		SetHookChainReturn(ATYPE_INTEGER, false);
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}

public CBasePlayer_Jump(id)
{
	if (!UTIL_IsAccessGranted(id, CVAR[DJUMP_ACCESS]))
		return;
	
	new flags = get_entvar(id, var_flags);
	
	// Fixes
	if (~flags & FL_WATERJUMP && get_entvar(id, var_waterlevel) < 2 && get_member(id, m_afButtonPressed) & IN_JUMP)
	{
		static _j[MAX_PLAYERS + 1];
		
		if (flags & FL_ONGROUND)
		{
			_j[id] = 0;
		}
		else if (Float: get_member(id, m_flFallVelocity) < CS_PLAYER_MAX_SAFE_FALL_SPEED && _j[id]++ < CVAR[DJUMPS])
		{
			static Float:vecSrc[3];
			get_entvar(id, var_velocity, vecSrc);
			vecSrc[2] = 268.328157;
			set_entvar(id, var_velocity, vecSrc);
		}
	}
}

public CSGameRules_FPlayerCanTakeDamage(id, attacker)
{
	if (!VALID_PLAYER(attacker))
		return HC_CONTINUE;
		
	if (id == attacker)
		return HC_CONTINUE;
	
	if (UTIL_IsAccessGranted(id, CVAR[HOOK_DAMAGE_ACCESS]) && random_num(1, 100) < CVAR[HOOK_DAMAGE_CHANCE])
	{
		// set_member(id, m_flVelocityModifier, 1.0);
		SetHookChainReturn(ATYPE_INTEGER, false);
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}

public CBasePlayer_Killed(const pPlayer, const pevAttacker)
{
	// UTIL_CloseMenu(pPlayer);
	
	if (pPlayer == pevAttacker || !VALID_PLAYER(pevAttacker))
		return;
	
	if (UTIL_IsAccessGranted(pevAttacker, CVAR[INSTANT_RELOAD_ACCESS]))
	{
		if (CVAR[INSTANT_RELOAD])
		{
			new pWeapon = get_member(pevAttacker, m_pActiveItem);
			if (!is_nullent(pWeapon))
				rg_instant_reload_weapons(pevAttacker, pWeapon);
		}
		else
			rg_instant_reload_weapons(pevAttacker);
	}
	
	if (UTIL_IsAccessGranted(pevAttacker, CVAR[VAMPIRE_ACCESS]))
	{
		if (CVAR[VAMPIRE_PREVENT_MULTIPLY])
		{
			new Float:fCurTime = get_gametime();
			static Float:fLastKill[MAX_CLIENTS + 1];
			if (fCurTime - fLastKill[pevAttacker] < 0.2)
				return;
			
			// Update as well
			fLastKill[pevAttacker] = fCurTime + 0.2;
		}
		
		new Float:fHealth
			= get_member(pPlayer, m_bKilledByGrenade) ? CVAR[VAMPIRE_HEALTH_NADE]
			: get_member(pPlayer, m_bHeadshotKilled) ? CVAR[VAMPIRE_HEALTH_HS]
			: CVAR[VAMPIRE_HEALTH]
		;
		
		new Float:fClientHealth, Float:fMaxHealth;
		get_entvar(pevAttacker, var_health, fClientHealth);
		
		if ((fMaxHealth = CVAR[VAMPIRE_HEALTH_MAX]) <= 0.0)
			fMaxHealth = Float: get_entvar(pevAttacker, var_max_health);
		
		if (fClientHealth < fMaxHealth)
		{
			// Set new health
			set_entvar(pevAttacker, var_health, floatmin(fClientHealth + fHealth, fMaxHealth));
			
			if (CVAR[VAMPIRE_HUD])
			{
				set_hudmessage(50, 225, 80, -1.0, 0.25, 0, 0.0, 1.75, 0.1, 0.4);
				show_hudmessage(pevAttacker, "%L", LANG_PLAYER, "VIP_VAMPIRE_HUD_INFO", fHealth);
			}
			
			if (CVAR[VAMPIRE_SAMPLE][0])
				client_cmd(pevAttacker, "spk ^"%s^"", CVAR[VAMPIRE_SAMPLE]);
			
			if (CVAR[VAMPIRE_SCREENFADE])
				UTIL_ScreenFade(pevAttacker);
		}
	}
}

public CBasePlayerWeapon_DefaultDeploy(pWeapon, viewModel[], weaponModel[], anim, animExt[], skiplocal)
{
	// new id = get_member(pWeapon, m_pPlayer);
	
	new szModel[MAX_RESOURCE_PATH_LENGTH];
	get_entvar(pWeapon, viewmodel, szModel, charsmax(szModel));
	
	// v_ model
	if (szModel[0])
		SetHookChainArg(2, ATYPE_STRING, szModel);
	
	get_entvar(pWeapon, playermodel, szModel, charsmax(szModel));
	
	// p_ model
	if (szModel[0])
		SetHookChainArg(3, ATYPE_STRING, szModel);
}

public CWeaponBox_SetModel(pWeaponBox, const szModel[])
{
	new pWeapon = UTIL_GetWeaponBoxWeapon(pWeaponBox);
	if (pWeapon == NULLENT)
		return;
	
	// w_ model
	new szModel[MAX_RESOURCE_PATH_LENGTH];
	get_entvar(pWeapon, gunmodel, szModel, charsmax(szModel));
	if (szModel[0])
		SetHookChainArg(2, ATYPE_STRING, szModel);
}

public CBasePlayer_ThrowGrenade()
{
	new pWeapon = GetHookChainReturn(ATYPE_INTEGER);
	if (is_nullent(pWeapon))
		return;
	
	// w_ model (nades)
	new szModel[MAX_RESOURCE_PATH_LENGTH];
	get_entvar(pWeapon, gunmodel, szModel, charsmax(szModel));
	if (szModel[0])
		engfunc(EngFunc_SetModel, pWeapon, szModel);
}

public CWeaponBox_Touch(pWeaponBox, id)
{
	if (!ExecuteHam(Ham_IsPlayer, id))
		return HAM_IGNORED;
	
	new pWeapon = UTIL_GetWeaponBoxWeapon(pWeaponBox);
	if (pWeapon == NULLENT)
		return HAM_IGNORED;
	
	new pAccess = get_entvar(pWeapon, weapon_access);
	if (pAccess > 0 && !UTIL_IsAccessGranted(id, pAccess))
	{
		client_print(id, print_center, "%L", LANG_PLAYER, "VIP_CUSTOM_WEAPONS_BLOCK_PICKUP");
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public CS_Item_GetMaxSpeed(const pWeapon)
{
	new Float:fSpeed;
	get_entvar(pWeapon, weapon_speed, fSpeed);
	
	if (fSpeed > 0.0)
	{
		new pPlayer = get_member(pWeapon, m_pPlayer);
		
		set_entvar(pPlayer, var_maxspeed, Float: get_entvar(pPlayer, var_maxspeed) * fSpeed);
	}
}

public Message_ScoreAttrib(msg_id, msg_type, msg_entity)
{
	if (get_msg_arg_int(2) > 0)
		return;
	
	if (!UTIL_IsAccessGranted(get_msg_arg_int(1), CVAR[TAB_ACCESS]))
		return;
	
	set_msg_arg_int(2, ARG_BYTE, SCORE_STATUS_VIP);
}

// ============================================================
// VIP Saved Weapon helpers
// ============================================================

GetSavedWeaponIndex(id)
{
	if (g_hSavedWeaponsVault == INVALID_HANDLE)
		return -1;
	
	new szAuth[MAX_AUTHID_LENGTH], szBuf[8];
	get_user_authid(id, szAuth, charsmax(szAuth));
	
	if (!nvault_get(g_hSavedWeaponsVault, szAuth, szBuf, charsmax(szBuf)))
		return -1;
	
	new idx = str_to_num(szBuf);
	return (idx >= 0 && idx < g_iCustomWeaponsNum) ? idx : -1;
}

SaveWeapon(id, idx)
{
	if (g_hSavedWeaponsVault == INVALID_HANDLE)
		return;
	
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));
	nvault_set(g_hSavedWeaponsVault, szAuth, fmt("%d", idx));
}

ClearSavedWeapon(id)
{
	if (g_hSavedWeaponsVault == INVALID_HANDLE)
		return;
	
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));
	nvault_remove(g_hSavedWeaponsVault, szAuth);
}

show_vip_save_menu(id, weaponIdx)
{
	new aWeapon[WEAPON_DATA];
	ArrayGetArray(g_aCustomWeapons, weaponIdx, aWeapon);
	
	new menu = menu_create(fmt("%L", LANG_PLAYER, "VIP_SAVE_MENU_TITLE", aWeapon[NAME]), "vip_save_menu_handler");
	menu_additem(menu, fmt("%L", LANG_PLAYER, "VIP_SAVE_MENU_YES"), fmt("%d", weaponIdx));
	menu_additem(menu, fmt("%L", LANG_PLAYER, "VIP_SAVE_MENU_NO"), "-1");
	menu_setprop(menu, MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "VIP_MENU_EXIT"));
	menu_display(id, menu);
}

public vip_save_menu_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		if (!UTIL_IsMaxTimesReached(id) && (CVAR[MENU_MODE] & LEFT_ITEMS))
			show_vip_menu(id);
		return PLUGIN_HANDLED;
	}
	
	new szID[6];
	menu_item_getinfo(menu, item, .info = szID, .infolen = charsmax(szID));
	menu_destroy(menu);
	
	new weaponIdx = str_to_num(szID);
	if (weaponIdx >= 0)
	{
		SaveWeapon(id, weaponIdx);
		new aWeapon[WEAPON_DATA];
		ArrayGetArray(g_aCustomWeapons, weaponIdx, aWeapon);
		client_print_color(id, print_team_blue, "%L %L", LANG_PLAYER, "VIP_PREFIX", LANG_PLAYER, "VIP_WEAPON_SAVED", aWeapon[NAME]);
	}
	
	if (!UTIL_IsMaxTimesReached(id) && (CVAR[MENU_MODE] & LEFT_ITEMS))
		show_vip_menu(id);
	
	return PLUGIN_HANDLED;
}

// ============================================================

LoadSettings()
{
	new szPath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/plugins");
	
	if (!dir_exists(szPath))
		return false;
	
	add(szPath, charsmax(szPath), "/vip_system.json");

	if (!file_exists(szPath))
		return false;
	
	new JSON:jCFG = json_parse(szPath, true, .with_comments = true);

	if (jCFG == Invalid_JSON)
		return false;
	
	new szBuffer[128];
	new JSON:jMain = json_object_get_value(jCFG, "core");
	
	if (json_is_object(jMain))
	{
		new JSON:jCommands = json_object_get_value(jMain, "commands");
		
		if (json_is_array(jCommands))
		{
			for (new i; i < json_array_get_count(jCommands); i++)
			{
				json_array_get_string(jCommands, i, szBuffer, charsmax(szBuffer));
				
				// 
				if (szBuffer[0] == '/' || szBuffer[0] == '!' || szBuffer[0] == '.')
				{
					register_clcmd(fmt("say %s", szBuffer), "clcmd_vip_menu");
					register_clcmd(fmt("say_team %s", szBuffer), "clcmd_vip_menu");
				}
				else
				{
					register_clcmd(szBuffer, "clcmd_vip_menu");
				}
			}
			
			json_free(jCommands);
		}
		
		CVAR[ACCESS_MODE] = json_object_get_number(jMain, "access_mode");
		CVAR[MENU_ROUND] = json_object_get_number(jMain, "round");
		
		new JSON:jMaps = json_object_get_value(jMain, "maps");
		
		if (json_is_array(jMaps))
		{
			for (new i; i < json_array_get_count(jMaps); i++)
			{
				json_array_get_string(jMaps, i, szBuffer, charsmax(szBuffer));
				
				if (containi(g_szMapName, szBuffer) != -1)
				{
					g_IsNoVIPMenuOnThisMap = true;
					
					server_print("#1FUP: На этой карте VIP меню отключёно.");
					break;
				}
			}
			
			json_free(jMaps);
		}
		
		json_free(jMain);
	}
	
	new JSON:jInformation = json_object_get_value(jCFG, "info");
	
	if (json_is_object(jInformation))
	{
		json_object_get_string(jInformation, "tab", szBuffer, charsmax(szBuffer));
		CVAR[TAB_ACCESS] = read_flags(szBuffer);
		
		new JSON:jOnline = json_object_get_value(jInformation, "online");
		
		if (json_is_object(jOnline))
		{
			json_object_get_string(jOnline, "online_access", szBuffer, charsmax(szBuffer));
			CVAR[ONLINE_ACCESS] = read_flags(szBuffer);
			
			if (CVAR[ONLINE_ACCESS] > 0)
			{
				CVAR[ONLINE_PLAYERS] = json_object_get_number(jOnline, "online_players");
				json_object_get_string(jOnline, "online_command", szBuffer, charsmax(szBuffer));
				
				if (szBuffer[0] == '/' || szBuffer[0] == '!' || szBuffer[0] == '.')
				{
					register_clcmd(fmt("say %s", szBuffer), "clcmd_vip_online");
					register_clcmd(fmt("say_team %s", szBuffer), "clcmd_vip_online");
				}
				else
				{
					register_clcmd(szBuffer, "clcmd_vip_online");
				}
			}
			
			json_free(jOnline);
		}
		
		new JSON:jConnect = json_object_get_value(jInformation, "connect");
		
		if (json_is_object(jConnect))
		{
			json_object_get_string(jConnect, "connect_access", szBuffer, charsmax(szBuffer));
			CVAR[CONNECT_ACCESS] = read_flags(szBuffer);
			
			new JSON:jMusic = json_object_get_value(jConnect, "connect_samples");
			
			if (json_is_array(jMusic))
			{
				for (new i; i < json_array_get_count(jMusic); i++)
				{
					json_array_get_string(jMusic, i, szBuffer, charsmax(szBuffer));
					
					if (file_exists(fmt("sound/%s", szBuffer), .use_valve_fs = true) == 1)
					{
						precache_sound(szBuffer);
						ArrayPushString(g_aSampleConnectMusic, szBuffer);
					}
				}
				
				json_free(jMusic);
			}
			
			json_free(jConnect);
		}
		
		new JSON:jMaps = json_object_get_value(jInformation, "maps");
		
		if (json_is_array(jMaps))
		{
			for (new i; i < json_array_get_count(jMaps); i++)
			{
				json_array_get_string(jMaps, i, szBuffer, charsmax(szBuffer));
				
				if (containi(g_szMapName, szBuffer) != -1)
				{
					//
					CVAR[TAB_ACCESS] = CVAR[ONLINE_ACCESS] = CVAR[CONNECT_ACCESS] = 0;
					ArrayDestroy(g_aSampleConnectMusic);
					
					server_print("#1FUP: На этой карте раздел информирования отключён.");
					break;
				}
			}
			
			json_free(jMaps);
		}
		
		json_free(jInformation);
	}
	
	new JSON:jEquip = json_object_get_value(jCFG, "equip_manager");
	
	if (json_is_object(jEquip))
	{
		CVAR[EQUIP_ROUND] = json_object_get_number(jEquip, "equip_round");
		CVAR[EQUIP_ONLY_1] = json_object_get_number(jEquip, "equip_only_first_spawn");
		
		json_object_get_string(jEquip, "he", szBuffer, charsmax(szBuffer));
		CVAR[EQUIP_HE_ACCESS] = read_flags(szBuffer);
		CVAR[EQUIP_HE_NUMS] = json_object_get_number(jEquip, "he_value");
		
		json_object_get_string(jEquip, "flash", szBuffer, charsmax(szBuffer));
		CVAR[EQUIP_FLASH_ACCESS] = read_flags(szBuffer);
		CVAR[EQUIP_FLASH_NUMS] = json_object_get_number(jEquip, "flash_value");
		
		json_object_get_string(jEquip, "smoke", szBuffer, charsmax(szBuffer));
		CVAR[EQUIP_SMOKE_ACCESS] = read_flags(szBuffer);
		CVAR[EQUIP_SMOKE_NUMS] = json_object_get_number(jEquip, "smoke_value");
		
		json_object_get_string(jEquip, "auto_reload", szBuffer, charsmax(szBuffer));
		CVAR[EQUIP_AUTO_RELOAD_ACCESS] = read_flags(szBuffer);
		
		json_object_get_string(jEquip, "kevlar", szBuffer, charsmax(szBuffer));
		CVAR[EQUIP_ARMOR_ACCESS] = read_flags(szBuffer);
		
		json_object_get_string(jEquip, "defuse", szBuffer, charsmax(szBuffer));
		CVAR[EQUIP_DKIT_ACCESS] = read_flags(szBuffer);
		
		json_object_get_string(jEquip, "nightvision", szBuffer, charsmax(szBuffer));
		CVAR[EQUIP_NIGHTVISION_ACCESS] = read_flags(szBuffer);
		
		json_object_get_string(jEquip, "silent", szBuffer, charsmax(szBuffer));
		CVAR[EQUIP_SILENT_RUN_ACCESS] = read_flags(szBuffer);
		
		new JSON:jMaps = json_object_get_value(jEquip, "maps");
		
		if (json_is_array(jMaps))
		{
			for (new i; i < json_array_get_count(jMaps); i++)
			{
				json_array_get_string(jMaps, i, szBuffer, charsmax(szBuffer));
				
				if (containi(g_szMapName, szBuffer) != -1)
				{
					// CVAR[EQUIP_ROUND] = 99999;
					g_IsNoEquipOnThisMap = true;
					
					server_print("#1FUP: На этой карте раздел экипировки отключён.");
					break;
				}
			}
			
			json_free(jMaps);
		}
		
		json_free(jEquip);
	}
	
	new JSON:jAbilities = json_object_get_value(jCFG, "abilities");
	
	if (json_is_object(jAbilities))
	{
		json_object_get_string(jAbilities, "no_fall_dmg", szBuffer, charsmax(szBuffer));
		CVAR[FALL_DAMAGE_ACCESS] = read_flags(szBuffer);
		
		json_object_get_string(jAbilities, "plant_unfreeze", szBuffer, charsmax(szBuffer));
		CVAR[PLANT_UNFREEZE_ACCESS] = read_flags(szBuffer);
		
		json_object_get_string(jAbilities, "antiflash", szBuffer, charsmax(szBuffer));
		CVAR[ANTIFLASH_ACCESS] = read_flags(szBuffer);
		
		new JSON:jJumps = json_object_get_value(jAbilities, "jump");
		
		if (json_is_object(jJumps))
		{
			json_object_get_string(jJumps, "jump_access", szBuffer, charsmax(szBuffer));
			
			CVAR[DJUMP_ACCESS] = read_flags(szBuffer);
			CVAR[DJUMPS] = json_object_get_number(jJumps, "jump_count");
			
			json_free(jJumps);
		}
		
		new JSON:jDamage = json_object_get_value(jAbilities, "hook_damage");
		
		if (json_is_object(jDamage))
		{
			json_object_get_string(jDamage, "hook_damage_access", szBuffer, charsmax(szBuffer));
			
			CVAR[HOOK_DAMAGE_ACCESS] = read_flags(szBuffer);
			CVAR[HOOK_DAMAGE_CHANCE] = json_object_get_number(jDamage, "hook_damage_chance");
			
		/*
			json_object_get_string(jDamage, "wall_damage", szBuffer, charsmax(szBuffer));
			
			if ((CVAR[WALL_DAMAGE_ACCESS] = read_flags(szBuffer)))
			{
				TrieSetCell(g_tWallClassNames, "func_door", 0);
				TrieSetCell(g_tWallClassNames, "func_door_rotating", 0);
				TrieSetCell(g_tWallClassNames, "func_wall", 0);
				TrieSetCell(g_tWallClassNames, "worldspawn", 0);
			}
		*/
			
			json_free(jDamage);
		}
		
		new JSON:jHealth = json_object_get_value(jAbilities, "bonus_health");
		
		if (json_is_object(jHealth))
		{
			json_object_get_string(jHealth, "bonus_health_access", szBuffer, charsmax(szBuffer));
			
			CVAR[HEALTH_ACCESS] = read_flags(szBuffer);
			CVAR[HEALTH_AMOUNT] = json_object_get_real(jHealth, "bonus_health_amount");
			
			json_free(jHealth);
		}
		
		json_object_get_string(jAbilities, "menu_mode", szBuffer, charsmax(szBuffer));
		CVAR[MENU_MODE] = read_flags(szBuffer);
		
		json_object_get_string(jAbilities, "only_in_buyzone", szBuffer, charsmax(szBuffer));
		CVAR[ONLY_IN_BUYZONE] = read_flags(szBuffer);
		
		json_object_get_string(jAbilities, "expired", szBuffer, charsmax(szBuffer));
		CVAR[EXPIRED] = read_flags(szBuffer);
		CVAR[EXPIRED_TIME] = json_object_get_real(jAbilities, "expired_time");
		
		new JSON:jMaxUsage = json_object_get_value(jAbilities, "max_usage");
		
		if (json_is_object(jMaxUsage))
		{
			for (new i, szAccess[2]; i < json_object_get_count(jMaxUsage) - 1; i++)
			{
				json_object_get_name(jMaxUsage, i, szAccess, charsmax(szAccess));
				
				TrieSetCell(g_tMaxUsages, szAccess, json_object_get_number(jMaxUsage, szAccess));
			}
			
			g_iDefaultMaxUses = json_object_get_number(jMaxUsage, "def");
			
			json_free(jMaxUsage);
		}
		
		new JSON:jInstantReload = json_object_get_value(jAbilities, "instant_reload");
		
		if (json_is_object(jInstantReload))
		{
			json_object_get_string(jInstantReload, "instant_reload_weapons_access", szBuffer, charsmax(szBuffer));
			
			CVAR[INSTANT_RELOAD_ACCESS] = read_flags(szBuffer);
			CVAR[INSTANT_RELOAD] = json_object_get_number(jInstantReload, "instant_reload_weapons_mode");
			
			json_free(jInstantReload);
		}
		
		new JSON:jMaps = json_object_get_value(jAbilities, "maps");
		
		if (json_is_array(jMaps))
		{
			for (new i; i < json_array_get_count(jMaps); i++)
			{
				json_array_get_string(jMaps, i, szBuffer, charsmax(szBuffer));
				
				if (containi(g_szMapName, szBuffer) != -1)
				{
					//
					CVAR[FALL_DAMAGE_ACCESS] =
						CVAR[PLANT_UNFREEZE_ACCESS] =
							CVAR[DJUMP_ACCESS] =
								CVAR[HOOK_DAMAGE_ACCESS] =
									CVAR[HEALTH_ACCESS] =
										CVAR[ONLY_IN_BUYZONE] =
											CVAR[INSTANT_RELOAD_ACCESS] =
												0;
					
					server_print("#1FUP: На этой карте раздел спец. возможностей отключён.");
					break;
				}
			}
			
			json_free(jMaps);
		}
		
		json_free(jAbilities);
	}
	
	new JSON:jBonuses = json_object_get_value(jCFG, "bonuses");
	
	if (json_is_object(jBonuses))
	{
		json_object_get_string(jBonuses, "bonus_access", szBuffer, charsmax(szBuffer));
		CVAR[BONUS_ACCESS] = read_flags(szBuffer);
		
		CVAR[BONUS_FRAGS] = json_object_get_number(jBonuses, "frags");
		CVAR[BONUS_KILLED] = json_object_get_number(jBonuses, "killed");
		CVAR[BONUS_PLANT_BOMB] = json_object_get_number(jBonuses, "bomb_planted");
		CVAR[BONUS_EXPLODE_BOMB] = json_object_get_number(jBonuses, "bomb_explode");
		CVAR[BONUS_DEFUSED_BOMB] = json_object_get_number(jBonuses, "bomb_defused");
		CVAR[BONUS_HOSTAGE_TOOK] = json_object_get_number(jBonuses, "hostage_took");
		CVAR[BONUS_HOSTAGE_RESCUED] = json_object_get_number(jBonuses, "hostage_rescued");
		CVAR[BONUS_VIP_KILLED] = json_object_get_number(jBonuses, "vip_killed");
		CVAR[BONUS_VIP_RESCUED_MYSELF] = json_object_get_number(jBonuses, "vip_rescued_myself");
		CVAR[BONUS_ROUND] = json_object_get_real(jBonuses, "terminating");
		CVAR[BONUS_DISCOUNT] = json_object_get_real(jBonuses, "discount");
		
		new JSON:jMaps = json_object_get_value(jBonuses, "maps");
		
		if (json_is_array(jMaps))
		{
			for (new i; i < json_array_get_count(jMaps); i++)
			{
				json_array_get_string(jMaps, i, szBuffer, charsmax(szBuffer));
				
				if (containi(g_szMapName, szBuffer) != -1)
				{
					//
					CVAR[BONUS_ACCESS] = 0;
					
					server_print("#1FUP: На этой карте раздел дополнительных бонусов отключён.");
					break;
				}
			}
			
			json_free(jMaps);
		}
		
		json_free(jBonuses);
	}
	
	new JSON:jVampire = json_object_get_value(jCFG, "vampire");
	
	if (json_is_object(jVampire))
	{
		json_object_get_string(jVampire, "vampire_access", szBuffer, charsmax(szBuffer));
		CVAR[VAMPIRE_ACCESS] = read_flags(szBuffer);
		
		CVAR[VAMPIRE_HEALTH] = json_object_get_real(jVampire, "vampire_health");
		CVAR[VAMPIRE_HEALTH_HS] = json_object_get_real(jVampire, "vampire_health_hs");
		CVAR[VAMPIRE_HEALTH_NADE] = json_object_get_real(jVampire, "vampire_health_nade");
		CVAR[VAMPIRE_HEALTH_MAX] = json_object_get_real(jVampire, "vampire_health_max");
		CVAR[VAMPIRE_SCREENFADE] = json_object_get_number(jVampire, "vampire_screenfade");
		CVAR[VAMPIRE_HUD] = json_object_get_number(jVampire, "vampire_hud");
		// CVAR[VAMPIRE_OBEY_LIMIT] = json_object_get_number(jVampire, "vampire_obey_limit");
		CVAR[VAMPIRE_PREVENT_MULTIPLY] = json_object_get_number(jVampire, "vampire_prevent_multiply");
		
		json_object_get_string(jVampire, "vampire_sample", CVAR[VAMPIRE_SAMPLE], charsmax(CVAR[VAMPIRE_SAMPLE]));
		
		// Fixes
		if (CVAR[VAMPIRE_SAMPLE][0])
		{
			if (file_exists(fmt("sound/%s", CVAR[VAMPIRE_SAMPLE]), .use_valve_fs = true) == 1)
				precache_sound(CVAR[VAMPIRE_SAMPLE]);
			else
				CVAR[VAMPIRE_SAMPLE][0] = '^0';
		}
		
		new JSON:jMaps = json_object_get_value(jVampire, "maps");
		
		if (json_is_array(jMaps))
		{
			for (new i; i < json_array_get_count(jMaps); i++)
			{
				json_array_get_string(jMaps, i, szBuffer, charsmax(szBuffer));
				
				if (containi(g_szMapName, szBuffer) != -1)
				{
					//
					CVAR[VAMPIRE_ACCESS] = 0;
					
					server_print("#1FUP: На этой карте раздел вампиризма отключён.");
					break;
				}
			}
			
			json_free(jMaps);
		}
		
		json_free(jVampire);
	}
	
	new JSON:jCustomWeapons = json_object_get_value(jCFG, "custom_weapons");
	
	if (json_is_object(jCustomWeapons))
	{
		new iId, iSectionId;
		new Array:aWeaponSpeed = ArrayCreate(32, 0);
		new aWeapon[WEAPON_DATA], Section[SECTION_STRUCT], szName[64];
		for (new i, JSON:jWeapon, jSize = json_object_get_count(jCustomWeapons) - 1; i < jSize; i++)
		{
			json_object_get_name(jCustomWeapons, i, szName, charsmax(szName));
		
			if (json_is_object((jWeapon = json_object_get_value(jCustomWeapons, szName))))
			{
				json_object_get_string(jWeapon, "base_name", szName, charsmax(szName));
				
				// if ((iId = get_weaponid(fmt("weapon_%s", szName))) == 0)
				if (!TrieGetCell(g_tDefaultWeapons, szName, iId) || iId == CSW_NONE)
				{
					server_print("#1FUP: Оружие %s не подходит.", szName);
					continue;
				}
				
			/*
				if (!((1 << iId) & (CSW_ALL_GUNS | CSW_ALL_GRENADES | (1 << CSW_KNIFE))))
				{
					server_print("#1FUP: Оружие %s не подходит.", szName);
					continue;
				}
			*/
				
				copy(szName, charsmax(szName), fmt("weapon_%s", szName));
				copy(aWeapon[BASE_NAME], charsmax(aWeapon[BASE_NAME]), szName);
				
				// access
				if (json_object_has_value(jWeapon, "access", JSONString))
				{

					json_object_get_string(jWeapon, "access", szBuffer, charsmax(szBuffer));
					aWeapon[ACCESS] = read_flags(szBuffer);
				}
				else
					aWeapon[ACCESS] = 0;
				
				// name
				if (json_object_has_value(jWeapon, "name", JSONString))
				{
					json_object_get_string(jWeapon, "name", aWeapon[NAME], charsmax(aWeapon[NAME]));
				}
				else
					aWeapon[NAME][0] = '^0';
				
				// v model
				if (json_object_has_value(jWeapon, "v_model", JSONString))
				{
					json_object_get_string(jWeapon, "v_model", aWeapon[V_MODEL], charsmax(aWeapon[V_MODEL]));
					
					if (file_exists(aWeapon[V_MODEL]) > 0)
					{
						precache_model(aWeapon[V_MODEL]);
					}
					else
						aWeapon[V_MODEL][0] = '^0';
				}
				else
					aWeapon[V_MODEL][0] = '^0';
				
				// p model
				if (json_object_has_value(jWeapon, "p_model", JSONString))
				{
					json_object_get_string(jWeapon, "p_model", aWeapon[P_MODEL], charsmax(aWeapon[P_MODEL]));
					
					if (file_exists(aWeapon[P_MODEL]) > 0)
					{
						precache_model(aWeapon[P_MODEL]);
					}
					else
						aWeapon[P_MODEL][0] = '^0';
				}
				else
					aWeapon[P_MODEL][0] = '^0';
				
				// w model
				if (json_object_has_value(jWeapon, "w_model", JSONString))
				{
					json_object_get_string(jWeapon, "w_model", aWeapon[W_MODEL], charsmax(aWeapon[W_MODEL]));
					
					if (file_exists(aWeapon[W_MODEL]) > 0)
					{
						precache_model(aWeapon[W_MODEL]);
					}
					else
						aWeapon[W_MODEL][0] = '^0';
				}
				else
					aWeapon[W_MODEL][0] = '^0';
				
				// attrib
				switch (iId)
				{
					case CSW_KNIFE:
					{
						// 2at distance
						if (json_object_has_value(jWeapon, "stab_distance", JSONNumber))
							aWeapon[STAB_DISTANCE] = json_object_get_real(jWeapon, "stab_distance");
						else
							aWeapon[STAB_DISTANCE] = 0.0;
						
						// 1at distance
						if (json_object_has_value(jWeapon, "swing_distance", JSONNumber))
							aWeapon[SWING_DISTANCE] = json_object_get_real(jWeapon, "swing_distance");
						else
							aWeapon[SWING_DISTANCE] = 0.0;
							
						// 2at damage
						if (json_object_has_value(jWeapon, "stab_damage", JSONNumber))
							aWeapon[STAB_DAMAGE] = json_object_get_real(jWeapon, "stab_damage");
						else
							aWeapon[STAB_DAMAGE] = 0.0;
							
						// 1at damage
						if (json_object_has_value(jWeapon, "swing_damage", JSONNumber))
							aWeapon[SWING_DAMAGE] = json_object_get_real(jWeapon, "swing_damage");
						else
							aWeapon[SWING_DAMAGE] = 0.0;
					}
					
					case CSW_HEGRENADE, CSW_FLASHBANG, CSW_SMOKEGRENADE:
					{
						
					}
					
					default:
					{
						if (json_object_has_value(jWeapon, "damage", JSONNumber))
							aWeapon[BASE_DAMAGE] = json_object_get_real(jWeapon, "damage");
						else
							aWeapon[BASE_DAMAGE] = 0.0;
						
						if (json_object_has_value(jWeapon, "ammo", JSONNumber))
							aWeapon[AMMO] = json_object_get_number(jWeapon, "ammo");
						else
							aWeapon[AMMO] = 0;
						
						if (json_object_has_value(jWeapon, "bpammo", JSONNumber))
							aWeapon[BPAMMO] = json_object_get_number(jWeapon, "bpammo");
						else
							aWeapon[BPAMMO] = 0;
					}
				}
				
				if (json_object_has_value(jWeapon, "speed_power", JSONNumber))
				{
					aWeapon[SPEED_MULTIPLY] = json_object_get_real(jWeapon, "speed_power");
					
					if (ArrayFindString(aWeaponSpeed, szName) == -1)
					{
						ArrayPushString(aWeaponSpeed, szName);
						
						RegisterHam(Ham_CS_Item_GetMaxSpeed, szName, "CS_Item_GetMaxSpeed", true);
					}
				}
				else
					aWeapon[SPEED_MULTIPLY] = 0.0;
				
				if (json_object_has_value(jWeapon, "give_type", JSONNumber))
					aWeapon[GIVE_MODE] = json_object_get_number(jWeapon, "give_type");
				else
					aWeapon[GIVE_MODE] = 0;
				
				if (json_object_has_value(jWeapon, "cost", JSONNumber))
					aWeapon[COST] = json_object_get_number(jWeapon, "cost");
				else
					aWeapon[COST] = 0;
				
				if (json_object_has_value(jWeapon, "round", JSONNumber))
					aWeapon[ROUND] = json_object_get_number(jWeapon, "round");
				else
					aWeapon[ROUND] = 0;
				
				if (json_object_has_value(jWeapon, "touches", JSONNumber))
					aWeapon[NO_TOUCHES] = json_object_get_number(jWeapon, "touches");
				else
					aWeapon[NO_TOUCHES] = 0;
				
				if (json_object_has_value(jWeapon, "team", JSONString))
				{
					json_object_get_string(jWeapon, "team", szBuffer, charsmax(szBuffer));
					
					aWeapon[TEAM] = szBuffer[0] == 'T' ? TEAM_TERRORIST : szBuffer[0] == 'C' ? TEAM_CT : TEAM_UNASSIGNED;
				/*
					switch (szBuffer[0])
					{
						case 'T':
						{
							aWeapon[TEAM] = TEAM_TERRORIST;
							break;
						}
						case 'C':
						{
							aWeapon[TEAM] = TEAM_CT;
							break;
						}
					}
				*/
				}
				// Fixes
				else
					aWeapon[TEAM] = TEAM_UNASSIGNED;
				
				// Бесплатная выдача при спавне
				if (json_object_has_value(jWeapon, "free_access", JSONString))
				{
					json_object_get_string(jWeapon, "free_access", szBuffer, charsmax(szBuffer));
					aWeapon[FREE] = read_flags(szBuffer);
				}
				// В противном случае вы обязательно должны указать имя
				else
				{
					aWeapon[FREE] = 0;
					
					if (!aWeapon[NAME][0] || !aWeapon[ACCESS])
					{
						server_print("#1FUP: Не указано имя или флаг доступа к оружию %i.", i);
						// server_print("#1FUP: Использование параметра free_access освободит вас от этих ограничений");
						continue;
					}
				}
				
				if (json_object_has_value(jWeapon, "menu_folder", JSONString))
				{
					json_object_get_string(jWeapon, "menu_folder", aWeapon[MENU_FOLDER], charsmax(aWeapon[MENU_FOLDER]));
					
					iSectionId = ArrayFindString(g_aMenuSections, aWeapon[MENU_FOLDER]);
					if (iSectionId == -1)
					{
						copy(Section[SECTION_MENU], charsmax(Section[SECTION_MENU]), aWeapon[MENU_FOLDER]);
						Section[SECTION_FLAGS] = aWeapon[ACCESS];
						ArrayPushArray(g_aMenuSections, Section);
					}
					else if (aWeapon[ACCESS] > 0)
					{
						ArrayGetArray(g_aMenuSections, iSectionId, Section);
						Section[SECTION_FLAGS] |= aWeapon[ACCESS];
						ArraySetArray(g_aMenuSections, iSectionId, Section);
						
					}
				}
				else
					aWeapon[MENU_FOLDER][0] = '^0';
				
				ArrayPushArray(g_aCustomWeapons, aWeapon);
				
				json_free(jWeapon);
				
				if (++g_iCustomWeaponsNum >= MAX_CUSTOM_WEAPONS)
					break;
			}
		}
		
		if (aWeaponSpeed)
			ArrayDestroy(aWeaponSpeed);
		
		new JSON:jMaps = json_object_get_value(jCustomWeapons, "maps");
		
		if (json_is_array(jMaps))
		{
			for (new i; i < json_array_get_count(jMaps); i++)
			{
				json_array_get_string(jMaps, i, szBuffer, charsmax(szBuffer));
				
				if (containi(g_szMapName, szBuffer) != -1)
				{
					//
					ArrayDestroy(g_aCustomWeapons);
					g_iCustomWeaponsNum = 0;
					// g_IsNoVIPMenuOnThisMap = true;
					
					server_print("#1FUP: На этой карте раздел кастомных оружий отключён.");
					break;
				}
			}
			
			json_free(jMaps);
		}
		
		json_free(jCustomWeapons);
	}
	
	json_free(jCFG);
	return true;
}

bool:give_item(id, any:array[])
{
	new iId = rg_get_weapon_info(array[BASE_NAME], WI_ID);
	
/*
	if (iId == CSW_KNIFE)
	{
		rg_remove_item(id, "weapon_knife");
	}
	else (array[GIVE_MODE] && 1 << iId & CSW_ALL_GUNS)
	{
		rg_drop_items_by_slot(id, (1 << iId & CSW_ALL_PISTOLS) ? PISTOL_SLOT : PRIMARY_WEAPON_SLOT);
	}
*/
	
	new GiveType:type = GT_APPEND;
	
	if (iId == CSW_KNIFE)
	{
		type = GT_REPLACE;
	}
	else if (1 << iId & CSW_ALL_GUNS)
	{
		if (array[GIVE_MODE] == 2)
			type = GT_REPLACE;
		else if (array[GIVE_MODE] == 1)
			type = GT_DROP_AND_REPLACE;
	}
	
	// Ignore API things
	new pWeapon = rg_give_custom_item(id, array[BASE_NAME], type);
	
	if (is_nullent(pWeapon))
		return false;
	
	if (iId == CSW_KNIFE)
	{
		// Дистанция ПКМ
		if (array[STAB_DISTANCE] > 0.0)
			set_member(pWeapon, m_Knife_flStabDistance, Float: get_member(pWeapon, m_Knife_flStabDistance) * array[STAB_DISTANCE]);
		
		// Дистанция ЛКМ
		if (array[SWING_DISTANCE] > 0.0)
			set_member(pWeapon, m_Knife_flSwingDistance, Float: get_member(pWeapon, m_Knife_flSwingDistance) * array[SWING_DISTANCE]);
		
		// Урон ПКМ
		if (array[STAB_DAMAGE] > 0.0)
			set_member(pWeapon, m_Knife_flStabBaseDamage, Float: get_member(pWeapon, m_Knife_flStabBaseDamage) * array[STAB_DAMAGE]);
		
		// Урон ЛКМ
		if (array[SWING_DAMAGE] > 0.0)
		{
			set_member(pWeapon, m_Knife_flSwingBaseDamage, Float: get_member(pWeapon, m_Knife_flSwingBaseDamage) * array[SWING_DAMAGE]);
			set_member(pWeapon, m_Knife_flSwingBaseDamage_Fast, Float: get_member(pWeapon, m_Knife_flSwingBaseDamage_Fast) * array[SWING_DAMAGE]);
		}
	}
	else if (!(1 << iId & NOCLIP_WEAPONS))
	{
		// Магазин
		if (array[AMMO] > 0)
		{
			rg_set_iteminfo(pWeapon, ItemInfo_iMaxClip, array[AMMO]);
			rg_set_user_ammo(id, WeaponIdType:iId, array[AMMO]);
		}
		
		// Запас
		if (array[BPAMMO] > 0)
		{
			rg_set_iteminfo(pWeapon, ItemInfo_iMaxAmmo1, array[BPAMMO]);
			rg_set_user_bpammo(id, WeaponIdType:iId, array[BPAMMO]);
		}
	
		if (array[BASE_DAMAGE] > 0.0)
		{
			if (iId == CSW_USP)
				set_member(pWeapon, m_USP_flBaseDamageSil, Float: get_member(pWeapon, m_USP_flBaseDamageSil) * array[BASE_DAMAGE]);
			else if (iId == CSW_M4A1)
				set_member(pWeapon, m_M4A1_flBaseDamageSil, Float: get_member(pWeapon, m_M4A1_flBaseDamageSil) * array[BASE_DAMAGE]);
			else if (iId == CSW_FAMAS)
				set_member(pWeapon, m_Famas_flBaseDamageBurst, Float: get_member(pWeapon, m_Famas_flBaseDamageBurst) * array[BASE_DAMAGE]);
			else
				set_member(pWeapon, m_Weapon_flBaseDamage, Float: get_member(pWeapon, m_Weapon_flBaseDamage) * array[BASE_DAMAGE]);
		}
	}
	
	// Скорость
	if (array[SPEED_MULTIPLY] > 0.0)
		set_entvar(pWeapon, weapon_speed, array[SPEED_MULTIPLY]);
	
	// Касание
	if (array[NO_TOUCHES] > 0)
		set_entvar(pWeapon, weapon_access, array[ACCESS]);
	
	// Вид в руке
	if (array[V_MODEL][0])
		set_entvar(pWeapon, viewmodel, array[V_MODEL]);
	
	// Вид у игрока
	if (array[P_MODEL][0])
		set_entvar(pWeapon, playermodel, array[P_MODEL]);
	
	// Вид лежит на земле
	if (array[W_MODEL][0])
		set_entvar(pWeapon, gunmodel, array[W_MODEL]);
	
	// engclient_cmd(id, array[BASE_NAME]);
	// ExecuteHam(Ham_Item_Deploy, pWeapon);
	if (get_member(id, m_pActiveItem) == pWeapon)
		rg_switch_weapon(id, pWeapon);
	
	return true;
}

stock SignalState:rg_get_user_mapzones(const id)
{
	new iSignals[UnifiedSignals];
	get_member(id, m_signals, iSignals);

	return SignalState:iSignals[US_State];
}

stock bool:rg_user_in_buyzone(const id)
{
	if (!UTIL_IsAccessGranted(id, CVAR[ONLY_IN_BUYZONE]))
		return true;
	
	return bool:(rg_get_user_mapzones(id) & SIGNAL_BUY);
}

stock bool:rg_user_in_bombzone(const id)
{
	return bool:(rg_get_user_mapzones(id) & SIGNAL_BOMB);
}

stock bool:rg_user_has_primary(const id)
{
	return bool:((get_member(id, m_rgpPlayerItems, PRIMARY_WEAPON_SLOT) > 0) || get_member(id, m_bHasPrimary));
}

stock UTIL_ScreenFade(const id, const Float:fxtime = 1.0, const Float:holdtime = 0.15, const color[3] = { 0, 255, 100 }, const alpha = 150)
{
	// blind players
	if (Float: get_member(id, m_blindUntilTime) > get_gametime())
		return;
	
	static iMsgScreenFade;
	if (iMsgScreenFade || (iMsgScreenFade = get_user_msgid("ScreenFade")))
	{
		message_begin(MSG_ONE_UNRELIABLE, iMsgScreenFade, .player = id);
		write_short(clamp(floatround(fxtime * UNIT_SECOND), 0, 0xFFFF));
		write_short(clamp(floatround(holdtime * UNIT_SECOND), 0, 0xFFFF));
		write_short(FFADE_IN);
		write_byte(color[0]);
		write_byte(color[1]);
		write_byte(color[2]);
		write_byte(alpha);
		message_end();
	}
}

stock UTIL_IsMaxTimesReached(const id)
{
	if (g_tMaxUsages == Invalid_Trie)
		return 0;
	
	new szAccess[2], iAmount;
	get_flags(get_user_flags(id), szAccess, charsmax(szAccess));
	
	if (!TrieGetCell(g_tMaxUsages, szAccess, iAmount))
		iAmount = g_iDefaultMaxUses;
	else if (iAmount == 0)
		return 0;
	
	return (g_iUsageCount[id] >= iAmount);
}

stock UTIL_IsTimeExpired(const id, const Float:timeleft)
{
	if (!UTIL_IsAccessGranted(id, CVAR[EXPIRED]))
		return false;
	
	if (timeleft == -1.0)
	{
		static mp_buytime;
		if (mp_buytime || (mp_buytime = get_cvar_pointer("mp_buytime")))
		{
			new Float:buytime = get_pcvar_float(mp_buytime);
			
			if (buytime == -1.0)	// infinity
				return 0;
			
			if (buytime == 0.0)		// disabled
				return 1;
			
			return (get_gametime() - Float: get_member_game(m_fRoundStartTime) > (buytime * 60.0));
		}
	}
	
	return (rg_is_time_expired(timeleft) != 0);
}

stock UTIL_BlinkAcct(const dest, const id, const times)
{
	static iMsgBlinkAcct;
	if (iMsgBlinkAcct || (iMsgBlinkAcct = get_user_msgid("BlinkAcct")))
	{
		message_begin(dest, iMsgBlinkAcct, .player = id);
		write_byte(times);
		message_end();
	}
}

stock UTIL_GetWeaponBoxWeapon(const pWeaponBox)
{
	for (new item, InventorySlotType:i = PRIMARY_WEAPON_SLOT; i <= GRENADE_SLOT; i++)
	{
		if (!is_nullent((item = get_member(pWeaponBox, m_WeaponBox_rgpPlayerItems, i))))
			return item;
	}
	
	return NULLENT;
}

stock UTIL_IsAccessGranted(id, const flags)
{
	new __user_flags = get_user_flags(id);
	
	if (flags == ADMIN_ADMIN)
	{
		static _amx_default_access;
		if (!_amx_default_access)
		{
			_amx_default_access = get_cvar_pointer("amx_default_access");
			
			if (_amx_default_access == 0)
			{
				// def
				_amx_default_access = ADMIN_USER;
			}
			else
			{
				static szAccess[16]; get_pcvar_string(_amx_default_access, szAccess, charsmax(szAccess));
				_amx_default_access = read_flags(szAccess);
			}
		}
		
		return (__user_flags > ADMIN_ALL && !(__user_flags & _amx_default_access));
	}
	else if (flags == ADMIN_ALL)
	{
		return 0;	// в данном случае обратный эффект
	}
	else if (CVAR[ACCESS_MODE] && (__user_flags & flags) >= flags) /* игрок должен иметь хоть строго все указанные флаги */
	{
		return 1;
	}
	
	// classic
	return (__user_flags & flags);
}


