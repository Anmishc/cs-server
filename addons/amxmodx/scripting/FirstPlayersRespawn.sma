#include <amxmisc>
#include <reapi>

#define FNullString(%0)     (!%0[0] || %0[0] == '0' || strlen(%0) <= 0)
#define VALID_PLAYER(%0)	(1 <= %0 <= MaxClients)

// ConVars
new fpr_round;
new fpr_min_players;
new fpr_domination;
new fpr_respawn[TeamName];
new fpr_money;
new fpr_money_firstround;
new fpr_prevent_suicide;
new fpr_only_once;
new Float:fpr_time;
new Float:fpr_protection;
new fpr_flag[16];
new fpr_sound[64];
new fpr_chat_message;

new g_pAccessFlag;
new g_iRespawnCount[TeamName];

public plugin_precache()
{
	register_plugin("FirstPlayersRespawn", "23.08.2025", "@emmajule");
	
	parse_cfg();
	
	if (!FNullString(fpr_sound)) {
		precache_sound(fpr_sound);
	}
}

public plugin_init()
{
	register_dictionary("FirstPlayersRespawn.txt");
	
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", true);
}

public plugin_cfg()
{
	g_pAccessFlag = read_flags_ex(fpr_flag);
}

public CSGameRules_RestartRound()
{
	g_iRespawnCount[TEAM_CT] = 0;
	g_iRespawnCount[TEAM_TERRORIST] = 0;
}

public CBasePlayer_Killed(const id, const attacker, gib)
{
	if (rg_get_current_round() < fpr_round) {
		return;
	}
	
	if (g_pAccessFlag > 0 && !(get_user_flags(id) & g_pAccessFlag)) {
		return;
	}
	
	new Float:gameTime = get_gametime();
	if (gameTime - Float:get_member_game(m_fRoundStartTimeReal) > fpr_time) {
		return;
	}
	
	if (fpr_prevent_suicide && (id == attacker || !VALID_PLAYER(attacker))) {
		return;
	}
	
	if (fpr_only_once && get_member(id, m_iNumSpawns) != 1) {
		return;
	}
	
	if (get_member_game(m_iNumSpawnableTerrorist) + get_member_game(m_iNumSpawnableCT) < fpr_min_players) {
		return;
	}
	
	new TeamName:team = get_member(id, m_iTeam);
	if (fpr_domination > 0 && team == rg_get_team_wins_row(fpr_domination)) {
		return;
	}
	
	new spawnCount = g_iRespawnCount[team];
	if (spawnCount >= fpr_respawn[team]) {
		return;
	}
	
	// set_entvar(id, var_deadflag, DEAD_RESPAWNABLE);
	set_member(id, m_flRespawnPending, gameTime + 0.1);
	set_member(id, m_flSpawnProtectionEndTime, gameTime + fpr_protection);
	g_iRespawnCount[team] = spawnCount + 1;
	
	if (fpr_money_firstround && rg_get_current_round() == 1)
	{
		rg_add_account(id, get_cvar_num("mp_startmoney"), AS_SET, false);
	}
	else if (fpr_money > 0)
	{
		rg_add_account(id, fpr_money, .bTrackChange = false);
	}
	
	if (fpr_chat_message) {
		client_print_color(id, 0, "%l %l", "FPR_TAG", "FPR_MSG", fpr_respawn[team]);
	}
	
	if (!FNullString(fpr_sound)) {
		client_cmd(id, "spk ^"%s^"", fpr_sound);
	}
}

parse_cfg()
{
	bind_pcvar_num(create_cvar("fpr_round", "0", .description = "С какого раунда работает плагин"), fpr_round);
	bind_pcvar_num(create_cvar("fpr_min_players", "24", .description = "Минимальное количество игроков для работы плагина (не считая зрителей)"), fpr_min_players);
	bind_pcvar_num(create_cvar("fpr_domination", "0", .description = "Если одна команда доминирует над другой (побед подряд) то для этой команды плагин работать не будет"), fpr_domination);
	bind_pcvar_num(create_cvar("fpr_respawn_t", "2", .description = "Сколько максимально игроков из команды TERRORIST сможет возродить плагин"), fpr_respawn[TEAM_TERRORIST]);
	bind_pcvar_num(create_cvar("fpr_respawn_ct", "2", .description = "Сколько максимально игроков из команды CT сможет возродить плагин"), fpr_respawn[TEAM_CT]);
	bind_pcvar_num(create_cvar("fpr_money", "300", .description = "Денежная компенсация при спавне игрока этим плагином"), fpr_money);
	bind_pcvar_num(create_cvar("fpr_money_firstround", "1", .description = "Если это первый раунд то при спавне игрок получит 800$."), fpr_money_firstround);
	bind_pcvar_num(create_cvar("fpr_prevent_suicide", "1", .description = "Если игрок совершил суицид, плагин в любом случае его проигнорирует"), fpr_prevent_suicide);
	bind_pcvar_num(create_cvar("fpr_only_once", "1", .description = "Плагин не будет работать для тех кто уже был заспавнен как то еще в этом раунде."), fpr_only_once);
	bind_pcvar_float(create_cvar("fpr_time", "6", .description = "Плагин будет работать только первые Х сек. раунда"), fpr_time);
	bind_pcvar_float(create_cvar("fpr_protection", "0", .description = "Защита при спавне для возрожденного игрока"), fpr_protection);
	bind_pcvar_string(create_cvar("fpr_flag", "qrst", .description = "Флаг доступа к действиям плагина^nИспользуйте 0 чтобы работало для всех без исключения, или пустые ковычки"), fpr_flag, charsmax(fpr_flag));
	bind_pcvar_string(create_cvar("fpr_sound", "", .description = "Проигрывание звук в момент спавна^nИспользуйте 0 чтобы отключить или пустые ковычки"), fpr_sound, charsmax(fpr_sound));
	bind_pcvar_num(create_cvar("fpr_chat_message", "1", .description = "Показывать чат сообщение в момент спавна"), fpr_chat_message);
	
	new path[PLATFORM_MAX_PATH];
	get_configsdir(path, charsmax(path));
	// strcat(path, "/plugins/FirstPlayersRespawn.cfg", charsmax(path));
	strcat(path, "/FirstPlayersRespawn.cfg", charsmax(path));
	
	server_cmd("exec %s", path);
	server_exec();
}

stock rg_get_current_round()
{
	return (get_member_game(m_iTotalRoundsPlayed) + 1);
}

stock TeamName:rg_get_team_wins_row(const wins)
{
	if (get_member_game(m_iNumConsecutiveCTLoses) >= wins)
		return TEAM_TERRORIST;
	else if (get_member_game(m_iNumConsecutiveTerroristLoses) >= wins)
		return TEAM_CT;
	
	// Noting to found
	return TEAM_UNASSIGNED;
}

stock read_flags_ex(const flags[])
{
	if (FNullString(flags)) {
		return ADMIN_ALL;
	}
	
	return read_flags(flags);
}
