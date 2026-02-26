// Copyright © 2016 Vaqtincha
/******************************************************************
*	Credits: to
*
*	- ConnorMcLeod for plugin "Weapon Models"
*
*******************************************************************/

#define VERSION "0.0.1"

#define MAX_MODEL_LENGTH 	64
#define MAX_PATH_LENGTH 	128
#define MAX_PLAYERS			32
#define MAX_PARAMETERS		4

// --- FIX: rules support (multiple AccessFlag blocks for same weapon) ---
#define MAX_RULES           256

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define AllocString(%1) 		engfunc(EngFunc_AllocString,%1)
#define SetModel(%1,%2) 		engfunc(EngFunc_SetModel,%1,%2)
#define IsPlayer(%1)			(1 <= %1 <= g_iMaxPlayers)

// World models mapping (old world model -> new world model)
new Trie:g_tWorldModels

// --- FIX: store multiple rules instead of single model per weapon ---
new g_iRuleCount
new g_RuleAccess[MAX_RULES]
new g_RuleWeapon[MAX_RULES][32]
new g_RuleViewIsz[MAX_RULES]
new g_RuleWeaponIsz[MAX_RULES]

// keeps current AccessFlag while parsing config
new g_iAccessCurrent

// for world model forward quick filter (any access that has world mappings)
new g_iWorldAccessMask

new g_iMaxPlayers

public plugin_precache()
{
	new szConfigFile[MAX_PATH_LENGTH], szMsg[128]
	get_localinfo("amxx_configsdir", szConfigFile, charsmax(szConfigFile))
	add(szConfigFile, charsmax(szConfigFile), "/weapons_skins.ini")

	if(!file_exists(szConfigFile))
	{
		formatex(szMsg, charsmax(szMsg), "[ERROR] Config file ^"%s^" not found!", szConfigFile)
		set_fail_state(szMsg)
		return
	}

	new iFilePointer = fopen(szConfigFile, "rt")
	if(!iFilePointer)
	{
		return
	}

	new Trie:tRegisterWeaponDeploy = TrieCreate()

	new szDatas[192], szSetting[12], szSymb[3], szFlags[32]
	new szWeaponClass[32]
	new szViewModel[MAX_MODEL_LENGTH], szWeaponModel[MAX_MODEL_LENGTH], szWorldModel[MAX_MODEL_LENGTH]
	new szOldWorldModel[MAX_MODEL_LENGTH]

	// default flags in case config starts with models before AccessFlag
	g_iAccessCurrent = read_flags("a")
	g_iRuleCount = 0
	g_iWorldAccessMask = 0

	while(!feof(iFilePointer))
	{
		fgets(iFilePointer, szDatas, charsmax(szDatas))
		trim(szDatas)

		if(!szDatas[0] || szDatas[0] == ';' || szDatas[0] == '#')
		{
			continue
		}

		if(equal(szDatas, "AccessFlag", 10))
		{
			parse(szDatas, szSetting, charsmax(szSetting), szSymb, charsmax(szSymb), szFlags, charsmax(szFlags))
			g_iAccessCurrent = read_flags(szFlags)
			continue
		}

		if(parse(szDatas, szWeaponClass, charsmax(szWeaponClass),
			szViewModel, charsmax(szViewModel),
			szWeaponModel, charsmax(szWeaponModel),
			szWorldModel, charsmax(szWorldModel)) == MAX_PARAMETERS)
		{
			// register deploy forward once per weapon class
			if(!TrieKeyExists(tRegisterWeaponDeploy, szWeaponClass))
			{
				TrieSetCell
				(
					tRegisterWeaponDeploy,
					szWeaponClass,
					RegisterHam(Ham_Item_Deploy, szWeaponClass, "ItemDeploy_Post", true)
				)
			}

			// --- FIX: build full paths, precache, and store as rule (per AccessFlag) ---
			new iszV = 0, iszP = 0

			// View model (v_)
			if(szViewModel[0])
			{
				format(szViewModel, charsmax(szViewModel), "models/%s.mdl", szViewModel)
				if(file_exists(szViewModel))
				{
					precache_model(szViewModel)
					iszV = AllocString(szViewModel)
				}
			}

			// Weapon model (p_)
			if(szWeaponModel[0])
			{
				format(szWeaponModel, charsmax(szWeaponModel), "models/%s.mdl", szWeaponModel)
				if(file_exists(szWeaponModel))
				{
					precache_model(szWeaponModel)
					iszP = AllocString(szWeaponModel)
				}
			}

			// Store rule only if at least one model exists
			if((iszV || iszP) && g_iRuleCount < MAX_RULES)
			{
				copy(g_RuleWeapon[g_iRuleCount], charsmax(g_RuleWeapon[]), szWeaponClass)
				g_RuleAccess[g_iRuleCount] = g_iAccessCurrent
				g_RuleViewIsz[g_iRuleCount] = iszV
				g_RuleWeaponIsz[g_iRuleCount] = iszP
				g_iRuleCount++
			}

			// World model (w_) mapping (kept as in original plugin)
			if(szWorldModel[0])
			{
				format(szWorldModel, charsmax(szWorldModel), "models/%s.mdl", szWorldModel)
				if(file_exists(szWorldModel))
				{
					if(!g_tWorldModels)
					{
						g_tWorldModels = TrieCreate()
					}

					// for FM_SetModel quick filter: remember flags that have world mapping
					g_iWorldAccessMask |= g_iAccessCurrent

					if(szWeaponClass[10] == 'n') // weapon_mp5navy
					{
						// replace(szWeaponClass, charsmax(szWeaponClass), "navy", "")
						szWeaponClass[10] = EOS
					}

					formatex(szOldWorldModel, charsmax(szOldWorldModel), "models/w_%s.mdl", szWeaponClass[7])

					if(!TrieKeyExists(g_tWorldModels, szOldWorldModel))
					{
						TrieSetString(g_tWorldModels, szOldWorldModel, szWorldModel)
						precache_model(szWorldModel)
					}
				}
			}
		}
	}

	fclose(iFilePointer)
	TrieDestroy(tRegisterWeaponDeploy)
}

public plugin_init()
{
	register_plugin("Weapons Skins Manager", VERSION, "Vaqtincha (fixed multi-flags)")

	if(g_tWorldModels)
	{
		register_forward(FM_SetModel, "SetModel_Pre", 0)
	}

	g_iMaxPlayers = get_maxplayers()
}

public ItemDeploy_Post(wEnt)
{
	if(wEnt <= 0)
		return

	const m_pPlayer = 41

	new id = get_pdata_cbase(wEnt, m_pPlayer, .linuxdiff = 4)
	if(!IsPlayer(id))
		return

	new szWeaponClass[32]
	pev(wEnt, pev_classname, szWeaponClass, charsmax(szWeaponClass))

	new userFlags = get_user_flags(id)

	// --- FIX: pick first matching rule for this weapon and this player's flags ---
	for(new i = 0; i < g_iRuleCount; i++)
	{
		if(!equal(szWeaponClass, g_RuleWeapon[i]))
			continue

		if(!(userFlags & g_RuleAccess[i]))
			continue

		if(g_RuleViewIsz[i])
			set_pev(id, pev_viewmodel, g_RuleViewIsz[i])

		if(g_RuleWeaponIsz[i])
			set_pev(id, pev_weaponmodel, g_RuleWeaponIsz[i])

		return
	}
}

public SetModel_Pre(iEnt, const szModel[])
{
	// if(!pev_valid(iEnt))
		// return FMRES_IGNORED

	new id = pev(iEnt, pev_owner)

	// --- FIX: original plugin used a single g_iAccess; now allow any flags that had world mappings ---
	if(!IsPlayer(id) || !(get_user_flags(id) & g_iWorldAccessMask))
		return FMRES_IGNORED

	new szNewModel[MAX_MODEL_LENGTH]
	if(TrieGetString(g_tWorldModels, szModel, szNewModel, charsmax(szNewModel)))
	{
		SetModel(iEnt, szNewModel)
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public plugin_end()
{
	if(g_tWorldModels)
		TrieDestroy(g_tWorldModels)
}