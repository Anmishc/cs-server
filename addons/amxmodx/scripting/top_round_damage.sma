/*****************************************************************************
   Возможности:
1. Настроить сколько игроков выводить в список
2. Настроить минимальное количество игроков для вывода
3. Настроить с какого раунда выводить
4. Время показа
5. Мгновенное закрытие меню по нажатию на клавиши цифр
6. Отключение показа через команду /damage
7. Помимо урона рядом выводит также количество убийств
8. Префикс перед сообщением в чате
9. Настроить сколько денег давать лучшему игроку раунда
10. Возможность отключения выдачи награды

Только на реапи, без реапи делать не буду, не вижу смысла

Благодарности:
Vaqtincha - за куски кода, идею и помощь по коду
Ссылка на оригинал плагина: https://dev-cs.ru/threads/75/

Версии:
1.0.0 релиз
1.0.1 добавлена возможность выдавать денежную награду лучшему игроку
1.0.2 рефаторинг кода
1.0.3 перенес проверку на минимальное количество игроков с fnCompareDamage() в RoundEnd() и изменен подсчет наносимого урона
1.0.4 убрал вывод заголовка меню, если никто в раунде никого не ранил

*****************************************************************************/

#include <amxmodx>
#include <reapi>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
#endif

#define PLUGIN "Top Round Damage"
#define VERSION "1.0.4-f ReAPI"
#define AUTHOR "Dager* *.* -G-"

#if !defined MAX_PLAYERS
	#define MAX_PLAYERS 32
#endif

#if !defined MAX_NAME_LENGTH
	#define MAX_NAME_LENGTH 32
#endif

#define IsPlayer(%1)    (1 <= %1 <= g_iMaxPlayers)
#define ClearArr(%1)    arrayset(_:%1, _:0.0, sizeof(%1))
#define MENU_KEYS       (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9)

/* настройки */
#define CHAT_PREFIX     "^4#1FUP"  // префикс
#define TOP_PLAYERS     5             // количество выводимых игроков в топ по дамагу [больше 10 нет смысла указывать]
#define MIN_PLAYERS     2             // минимальное количество игроков для вывода топа
#define ROUND_NUMBER    1             // с какого раунда выводить
#define SHOW_TIME       5             // через сколько секунд закроется меню лучших игроков по дамагу за раунд [целое число]
#define GIVE_MONEY      500           // сколько денег давать лучшему игроку
#define GIVE_AWARD                    // закомментируйте если не хотите давать награду лучшему игроку

/* не трогать всё что ниже*/

enum _:ePlayerData
{
	PLAYER_ID,
	DAMAGE,
	KILLS
};

new g_arrData[MAX_PLAYERS + 1][ePlayerData];
new g_iPlayerDmg[MAX_PLAYERS + 1];
new g_iPlayerKills[MAX_PLAYERS + 1];
new g_iRoundCounter;
new g_iMaxPlayers;
new bool:g_bIsSwitch[MAX_PLAYERS + 1];
new g_iMenuID;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say /damage", "cmdTopDamageSwitch");
	register_clcmd("say_team /damage", "cmdTopDamageSwitch");
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true);
	RegisterHookChain(RG_RoundEnd, "RoundEnd", true);
	
	g_iMenuID = register_menuid("TopDmg");
	register_menucmd(g_iMenuID, MENU_KEYS, "fnTopDmgHandler");
	
	g_iMaxPlayers = get_member_game(m_nMaxPlayers);
}

public client_putinserver(id)
{
	// начальные значения зашедшему игроку
	g_iPlayerDmg[id] = 0;
	g_iPlayerKills[id] = 0;
	g_bIsSwitch[id] = true;
}

public cmdTopDamageSwitch(id)
{
	g_bIsSwitch[id] = !g_bIsSwitch[id];
	
	new szSwitch[20];
	formatex(szSwitch, charsmax(szSwitch), "%s", g_bIsSwitch[id] ? "включили" : "отключили");
	
	client_print_color(id, print_team_default,
		"%s ^1Вы %s показ ^4[топ-%d по урону] ^1за раунд!",
		CHAT_PREFIX, szSwitch, TOP_PLAYERS
	);
	
	return PLUGIN_CONTINUE;
}

public CSGameRules_RestartRound_Pre()
{
	if(get_member_game(m_bCompleteReset))
		g_iRoundCounter = 0;
	
	g_iRoundCounter++;
	
	// чистка массивов с данными
	ClearArr(g_iPlayerDmg);
	ClearArr(g_iPlayerKills);
	
	for(new i = 1; i <= g_iMaxPlayers; i++)
		arrayset(g_arrData[i], 0, ePlayerData);
}

public CBasePlayer_TakeDamage(const pevVictim, pevInflictor, const pevAttacker, Float:flDamage, bitsDamageType)
{
	if(pevVictim == pevAttacker || !IsPlayer(pevAttacker) || (bitsDamageType & DMG_BLAST))
		return HC_CONTINUE;
	
	if(rg_is_player_can_takedamage(pevVictim, pevAttacker))
		g_iPlayerDmg[pevAttacker] += floatround(flDamage);
	
	return HC_CONTINUE;
}

public CBasePlayer_Killed(const Victim, Attacker)
{
	if(!is_user_connected(Victim) || Victim == Attacker || !IsPlayer(Attacker) || get_member(Victim, m_iTeam) == get_member(Attacker, m_iTeam))
		return HC_CONTINUE;
	
	g_iPlayerKills[Attacker]++;
	
	return HC_CONTINUE;
}

public fnCompareDamage()
{
	new iPlayers[MAX_PLAYERS], iNum, iPlayer;
#if defined GIVE_AWARD
	new szName[MAX_NAME_LENGTH], pBestPlayerId, pBestPlayerDamage;
#endif
	get_players(iPlayers, iNum, "h");
	
	// цикл сбора инфы по всем игрокам
	for(new i; i < iNum; i++)
	{
		iPlayer = iPlayers[i];
		
		g_arrData[i][PLAYER_ID] = iPlayer;
		g_arrData[i][DAMAGE] = _:g_iPlayerDmg[iPlayer];
		g_arrData[i][KILLS] = _:g_iPlayerKills[iPlayer];
	}
	
	// сортировка массива
	SortCustom2D(g_arrData, sizeof(g_arrData), "SortRoundDamage");
	
#if defined GIVE_AWARD
	// получение ид лучшего игрока после сортировки (1й элемент массива)
	pBestPlayerId = g_arrData[0][PLAYER_ID];
	// также получение урона лучшего игрока
	pBestPlayerDamage = g_arrData[0][DAMAGE];
	
	// проверки на валидность данного игрока и урон (если урон 0, то не давать награду)
	if(IsPlayer(pBestPlayerId) && is_user_connected(pBestPlayerId) && pBestPlayerDamage >= 1)
	{
		get_user_name(pBestPlayerId, szName, charsmax(szName));
		rg_add_account(pBestPlayerId, GIVE_MONEY, AS_ADD, true);
		
		client_print_color(0, print_team_default,
			"%s ^3%s ^1нанес больше всего урона [^4%d^1] и получает [^4%d^3$^1].",
			CHAT_PREFIX, szName, pBestPlayerDamage, GIVE_MONEY
		);
	}
#endif
	
	return PLUGIN_HANDLED;
}

// функция сравнения для сортировки
public SortRoundDamage(const elem1[], const elem2[])
{
	// сравнение дамага
	return (elem1[DAMAGE] < elem2[DAMAGE]) ? 1 : (elem1[DAMAGE] > elem2[DAMAGE]) ? -1 : 0;
}

public RoundEnd()
{
	if(g_iRoundCounter >= ROUND_NUMBER)
	{
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "h");
		
		// если игроков меньше чем выставленное значение MIN_PLAYERS, то прерываем
		if(iNum >= MIN_PLAYERS)
		{
			// таск с задежкой для сравнения урона игроков (без него будет неточность последнего попадания)
			// при игре 1х1 и убийстве противника с одного патрона думаю станет ясно, что это значит и для чего таск
			set_task(0.1, "fnCompareDamage");
			// таск на отображение списка
			set_task(0.2, "fnShowStats");
		}
	}
}

public fnShowStats()
{
	new iPlayers[MAX_PLAYERS], iNum, szMenu[512], szName[MAX_NAME_LENGTH], iLen, iPlayer;
	new bool:bMenuDmgShow;
	get_players(iPlayers, iNum, "h");
	
	iLen = formatex(szMenu, charsmax(szMenu), "\w#. \r[\yУрон\r] [\yФраги\r] \wза раунд:^n^n");
	
	// проверка если игроков на сервере меньше чем выставлено TOP_PLAYERS
	if(iNum < TOP_PLAYERS)
	{
		// то не делаем лишних итераций до TOP_PLAYERS
		for(new i; i < iNum; i++)
		{
			// для тех, кому надо выводить игроков с 0 уроном, закомментировать 2 строки ниже
			if(g_arrData[i][DAMAGE] <= 0)
				continue;
			
			get_user_name(g_arrData[i][PLAYER_ID], szName, charsmax(szName));
			
			// форматирование красивого меню в столбик
			if(0 <= g_arrData[i][DAMAGE] < 10)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y00%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			else if(10 <= g_arrData[i][DAMAGE] < 100)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y0%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			
			bMenuDmgShow = true;
		}
	}
	else
	{
		// пробегаем лучших игроков до TOP_PLAYERS
		for(new i; i < TOP_PLAYERS; i++)
		{
			// для тех, кому надо выводить игроков с 0 уроном, закомментировать 2 строки ниже
			if(g_arrData[i][DAMAGE] <= 0)
				continue;
			
			get_user_name(g_arrData[i][PLAYER_ID], szName, charsmax(szName));
			
			// форматирование красивого меню в столбик
			if(0 <= g_arrData[i][DAMAGE] < 10)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y00%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			else if(10 <= g_arrData[i][DAMAGE] < 100)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y0%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			
			bMenuDmgShow = true;
		}
	}
	// если есть игроки в раунде с уроном
	if(bMenuDmgShow)
	{
		// показ всем игрокам список лучших игроков
		for(new i; i < iNum; i++)
		{
			iPlayer = iPlayers[i];
			
			// если игрок не выключил показ, то показываем
			if(g_bIsSwitch[iPlayer] && !is_player_see_menu(iPlayer, g_iMenuID))
				show_menu(iPlayer, MENU_KEYS, szMenu, SHOW_TIME, "TopDmg");
		}
	}
	
	return PLUGIN_HANDLED;
}

stock bool:is_player_see_menu(pPlayer, iMenuIdToIgnore = 0) {
	new iMenuID, iKeys;
	get_user_menu(pPlayer, iMenuID, iKeys);
	return (iMenuID && iMenuID != iMenuIdToIgnore);
}

// обработчик нажатия цифр для закрытия меню моментально
public fnTopDmgHandler(id, iKey)
{
	if(iKey >= 0 || iKey <= 9)
		return PLUGIN_CONTINUE;
	
	return PLUGIN_HANDLED;
}
