#pragma semicolon 1

#include <amxmodx>
#include <reapi>

// Maximum enemies one player can shoot in a round
#define MAX_TRACKED_ENEMIES 32

// Per-player tracking: for each shooter, track victims they damaged this round
new g_iVictimId[MAX_PLAYERS + 1][MAX_TRACKED_ENEMIES];
new g_iTotalDamage[MAX_PLAYERS + 1][MAX_TRACKED_ENEMIES];
new g_iSlotCount[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("Round Damage Info", "1.0.0", "Custom");
	
	// Track damage dealt to enemies
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "@OnTakeDamage_Post", true);
	
	// Show info at round end (before next round)
	register_logevent("@OnRoundEnd", 2, "1=Round_End");
	
	// Reset at new round start
	register_event("HLTV", "@OnNewRound", "a", "1=0", "2=0");
}

// Track damage: record how much attacker dealt to victim
@OnTakeDamage_Post(victim, inflictor, attacker, Float:damage, bitsDamageType)
{
	if (victim == attacker || !is_user_connected(attacker) || !is_user_connected(victim))
		return;
	
	// Skip team damage
	if (!rg_is_player_can_takedamage(victim, attacker))
		return;
	
	// Find existing slot for this victim
	new slot = -1;
	for (new i = 0; i < g_iSlotCount[attacker]; i++)
	{
		if (g_iVictimId[attacker][i] == victim)
		{
			slot = i;
			break;
		}
	}
	
	// Allocate new slot
	if (slot == -1)
	{
		if (g_iSlotCount[attacker] >= MAX_TRACKED_ENEMIES)
			return;
		
		slot = g_iSlotCount[attacker]++;
		g_iVictimId[attacker][slot] = victim;
		g_iTotalDamage[attacker][slot] = 0;
	}
	
	g_iTotalDamage[attacker][slot] += floatround(damage);
}

// Round ends — show damage info after short delay (so HP values settle)
@OnRoundEnd()
{
	set_task(0.3, "@ShowDamageInfo_All");
}

@ShowDamageInfo_All()
{
	for (new attacker = 1; attacker <= MaxClients; attacker++)
	{
		if (!is_user_connected(attacker) || g_iSlotCount[attacker] < 1)
			continue;
		
		ShowDamageInfoToPlayer(attacker);
	}
}

ShowDamageInfoToPlayer(attacker)
{
	new szLine[128];
	new count = g_iSlotCount[attacker];
	
	client_print_color(attacker, print_team_default, "^4#1FUP ^3| ^1Урон за раунд:");
	
	for (new slot = 0; slot < count; slot++)
	{
		new victim = g_iVictimId[attacker][slot];
		new dmg = g_iTotalDamage[attacker][slot];
		new szName[32];
		
		if (is_user_connected(victim))
		{
			get_user_name(victim, szName, charsmax(szName));
			
			if (is_user_alive(victim))
			{
				new hp = get_user_health(victim);
				formatex(szLine, charsmax(szLine),
					"  ^3%s ^1— ^4лишилось: ^3%d/100 HP ^1(урон: ^4-%d^1)",
					szName, hp, dmg);
			}
			else
			{
				formatex(szLine, charsmax(szLine),
					"  ^3%s ^1— ^4[мертвий] ^1(урон: ^4-%d^1)",
					szName, dmg);
			}
		}
		else
		{
			formatex(szLine, charsmax(szLine),
				"  ^3[відключився] ^1(урон: ^4-%d^1)", dmg);
		}
		
		client_print_color(attacker, print_team_default, szLine);
	}
}

// Reset on new round start
@OnNewRound()
{
	for (new i = 1; i <= MaxClients; i++)
		ResetPlayerData(i);
}

ResetPlayerData(id)
{
	g_iSlotCount[id] = 0;
}

