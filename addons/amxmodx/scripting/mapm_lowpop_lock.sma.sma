#include <amxmodx>
#include <map_manager_consts>
#include <map_manager_stocks>

#pragma semicolon 1

#define PLUGIN  "MapManager: LowPop Dust2 Lock (RoundSwitch) + RTV Block"
#define VERSION "2.0"
#define AUTHOR  "chatgpt"

#define MIN_PLAYERS     15
#define CHECK_INTERVAL  180.0
new const LOCK_MAP[] = "de_dust2";

new bool:g_bLowPop;
new g_iHumans;

new bool:g_bPendingChange;     // ждём смену карты в конце раунда
new bool:g_bAnnouncedPending;  // чтобы не спамить сообщением каждые 180 сек

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    // Словарь для RU/EN текста
    register_dictionary("mapm_lowpop_lock.txt");

    // Блок RTV (Mistrick RTV обычно: rtv / say /rtv)
    register_clcmd("rtv", "cmd_block_rtv");
    register_clcmd("say rtv", "cmd_block_rtv");
    register_clcmd("say /rtv", "cmd_block_rtv");
    register_clcmd("say .rtv", "cmd_block_rtv");

    // На всякий случай
    register_clcmd("rockthevote", "cmd_block_rtv");
    register_clcmd("say /rockthevote", "cmd_block_rtv");
    register_clcmd("say rockthevote", "cmd_block_rtv");

    // Конец раунда (для смены карты “в следующем раунде”)
    register_logevent("onRoundEnd", 2, "1=Round_End");

    // Периодическая проверка
    set_task(CHECK_INTERVAL, "task_periodic_check", .flags="b");
}

public task_periodic_check()
{
    update_lowpop_state();

    // Если игроков уже достаточно — отменяем ожидание смены
    if(!g_bLowPop)
    {
        g_bPendingChange = false;
        g_bAnnouncedPending = false;
        return;
    }

    // lowpop: если карта не dust2 — готовим смену в конце раунда
    new curmap[32];
    get_mapname(curmap, charsmax(curmap));

    if(!equali(curmap, LOCK_MAP))
    {
        g_bPendingChange = true;

        // Сообщение один раз на “поставили в очередь”
        if(!g_bAnnouncedPending)
        {
            g_bAnnouncedPending = true;

            client_print_color(
                0, print_team_default,
                "%L",
                LANG_PLAYER,
                "MAPM_LOWPOP_SWITCH_NEXT",
                MIN_PLAYERS,
                LOCK_MAP
            );
        }
    }
    else
    {
        // Уже на dust2 — ничего не надо
        g_bPendingChange = false;
        g_bAnnouncedPending = false;
    }
}

public onRoundEnd()
{
    if(!g_bPendingChange)
        return;

    // Перед самой сменой ещё раз проверим онлайн: вдруг уже стало 15+
    update_lowpop_state();
    if(!g_bLowPop)
    {
        g_bPendingChange = false;
        g_bAnnouncedPending = false;
        return;
    }

    // Смена карты
    g_bPendingChange = false;
    g_bAnnouncedPending = false;

    server_cmd("changelevel %s", LOCK_MAP);
}

// Обновление количества людей и lowpop
stock update_lowpop_state()
{
    new players[32];
    get_players(players, g_iHumans, "ch"); // люди, без ботов и HLTV
    g_bLowPop = (g_iHumans < MIN_PLAYERS);
}

/**
 * На lowpop разрешаем ТОЛЬКО de_dust2 в голосованиях
 */
public mapm_can_be_in_votelist(const map[], type, index)
{
    if(g_bLowPop)
        return equali(map, LOCK_MAP) ? MAP_ALLOWED : MAP_BLOCKED;

    return MAP_ALLOWED;
}

/**
 * Если голосование дошло до конца — отменяем на lowpop
 */
public mapm_analysis_of_results(type, totalVotes)
{
    if(g_bLowPop)
        return ABORT_VOTE_WITH_FORWARD;

    return 0;
}

// RTV block (RU через словарь)
public cmd_block_rtv(id)
{
    // обновим онлайн сразу
    update_lowpop_state();

    if(g_bLowPop)
    {
        client_print_color(
            id, print_team_default,
            "%L",
            id,
            "MAPM_RTV_LOCKED",
            MIN_PLAYERS,
            g_iHumans
        );
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}