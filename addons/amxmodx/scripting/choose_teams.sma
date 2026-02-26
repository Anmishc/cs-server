#include <amxmodx>
#include <reapi>

// #define CUSTOM_MENU            // Меню с 3-мя пунктами. 1 - Войти в игру, 6 - Наблюдатели, 0 - Выход
#define TIME_CHANGE  5           // Пауза между сменой команд, в секундах (0 = без ограничений)
#define PLAYER_DIFF  2           // Разница между командами (если на n человек больше, за эту команду зайти нельзя)
#define MAXPLAYERS   32

new VGUIMenu:menus;

#if !defined CUSTOM_MENU
new g_MapName[32], bool:g_VIPMap = false;
#endif

new Float:g_fLastTeamChange[MAXPLAYERS + 1];
new HookChain:HookShowMenuPre;

public plugin_init()
{
    register_plugin("[ReAPI] Choose team", "2.1-human", "maFFyoZZyk + patch");

    register_clcmd("chooseteam", "CMD_ChooseTeam");

    RegisterHookChain(RG_ShowVGUIMenu, "ShowVGUIMenu_Pre", false);
    RegisterHookChain(RG_HandleMenu_ChooseTeam, "HandleMenu_ChooseTeam_Pre", false);

    // Подклассы/модели
    RegisterHookChain(RG_HandleMenu_ChooseAppearance, "HandleMenu_ChooseAppearance_Pre", false);

    HookShowMenuPre = RegisterHookChain(RG_ShowMenu, "ShowMenu_Pre", false);
    DisableHookChain(HookShowMenuPre);

#if !defined CUSTOM_MENU
    get_mapname(g_MapName, charsmax(g_MapName));
    if (containi(g_MapName, "as_") != -1) g_VIPMap = true;
#endif

    // Инициализация таймера, чтобы у новичка не блокировало
    for (new i = 1; i <= MAXPLAYERS; i++)
        g_fLastTeamChange[i] = 0.0;
}

public CMD_ChooseTeam(id)
{
    if (!is_user_connected(id))
        return HC_CONTINUE;

    // Разрешаем смену команды при открытии меню (важно для ReGameDLL)
    set_member(id, m_bTeamChanged, false);

    return HC_CONTINUE;
}

public ShowVGUIMenu_Pre(const id, VGUIMenu:menuType, const bitsSlots, szOldMenu[])
{
    if (!is_user_connected(id) || is_user_bot(id))
        return HC_CONTINUE;

    // Убираем выбор подразделений/класса
    if (menuType == VGUI_Menu_Class_T || menuType == VGUI_Menu_Class_CT)
    {
        client_cmd(id, "menuselect 5"); // авто-выбор модели
        return HC_SUPERCEDE;
    }

    new szMenu[MAX_MENU_LENGTH], iKeys = MENU_KEY_0;

    if (menuType == VGUI_Menu_Team)
    {
#if defined CUSTOM_MENU
        SetHookChainArg(3, ATYPE_INTEGER, MENU_KEY_0 | MENU_KEY_1 | MENU_KEY_6);
        SetHookChainArg(4, ATYPE_STRING, "\yВыберите действие:^n^n\y1. \rВойти в игру^n\y6. \wНаблюдение^n^n\y0. \wВыход");
#else
        new iTeamTT, iTeamCT; CalculateTeamNum(iTeamTT, iTeamCT);
        new TeamName:team = get_member(id, m_iTeam);

        new iLen = formatex(szMenu, charsmax(szMenu), "\r#1FUP - \yВыбор команды:^n^n");

        if ((iTeamTT - iTeamCT) >= PLAYER_DIFF || team == TEAM_TERRORIST)
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y1. \dТеррористы [\r%d\w]^n", iTeamTT);
        else
        {
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y1. \wТеррористы [\r%d\w]^n", iTeamTT);
            iKeys |= MENU_KEY_1;
        }

        if ((iTeamCT - iTeamTT) >= PLAYER_DIFF || team == TEAM_CT)
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y2. \dСпецназ [\r%d\w]^n^n", iTeamCT);
        else
        {
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y2. \wСпецназ [\r%d\w]^n^n", iTeamCT);
            iKeys |= MENU_KEY_2;
        }

        if (g_VIPMap)
        {
            if (team != TEAM_CT) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y3. \dVIP^n^n");
            else
            {
                iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y3. \wVIP^n^n");
                iKeys |= MENU_KEY_3;
            }
        }

        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y5. \yСлучайный выбор^n");
        iKeys |= MENU_KEY_5;

        if (team == TEAM_SPECTATOR)
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y6. \rНаблюдение^n^n^n");
        else
        {
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y6. \rНаблюдение^n^n^n");
            iKeys |= MENU_KEY_6;
        }

        formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y0. \wВыход");

        SetHookChainArg(3, ATYPE_INTEGER, iKeys);
        SetHookChainArg(4, ATYPE_STRING, szMenu);

        if (strlen(szMenu) > 175)
            EnableHookChain(HookShowMenuPre);
#endif
    }

    return HC_CONTINUE;
}

// Fix menu limit in ReGameDLL
public ShowMenu_Pre(const id, const keys, const time, const needMore, const menu[])
{
    DisableHookChain(HookShowMenuPre);
    show_menu(id, keys, menu, time);

    switch (menus)
    {
        case Menu_ChooseTeam: set_member(id, m_iMenu, Menu_ChooseTeam);
        case VGUI_Menu_Class_T: set_member(id, m_iMenu, VGUI_Menu_Class_T);
        case VGUI_Menu_Class_CT: set_member(id, m_iMenu, VGUI_Menu_Class_CT);
    }
    return HC_SUPERCEDE;
}

public HandleMenu_ChooseTeam_Pre(const id, const MenuChooseTeam:key)
{
    if (!is_user_connected(id) || is_user_bot(id))
        return HC_CONTINUE;

    // ВАЖНО: разрешаем смену в ReGameDLL (иначе “кнопки не работают”)
    set_member(id, m_bTeamChanged, false);

    // Ограничение по времени (если включено)
#if TIME_CHANGE > 0
    if (get_member(id, m_iTeam)) // если уже в команде (не первый выбор)
    {
        new Float:fNext = g_fLastTeamChange[id] + float(TIME_CHANGE);
        new Float:fNow  = get_gametime();
        if (fNext > fNow)
        {
            client_print_color(id, id,
                "^1[^4INFO^1] Сменить команду можно через ^4%d ^1секунд",
                floatround(fNext - fNow));
            // Не блокируем HC_SUPERCEDE (чтобы не ловить ошибки возврата),
            // просто закрываем меню:
            client_cmd(id, "slot10");
            return HC_CONTINUE;
        }
    }
#endif

    // Если игрок реально нажал на пункт, фиксируем время
    // (0 — выход, не трогаем)
    if (key != 0)
        g_fLastTeamChange[id] = get_gametime();

    return HC_CONTINUE;
}

// Всегда авто-выбор модели/подкласса
public HandleMenu_ChooseAppearance_Pre(const id, const MenuChooseAppearance:key)
{
    if (!is_user_connected(id) || is_user_bot(id))
        return HC_CONTINUE;

    SetHookChainArg(2, ATYPE_INTEGER, 5);
    return HC_CONTINUE;
}

stock CalculateTeamNum(&iTeamTT, &iTeamCT)
{
    for (new id = 1; id <= MAXPLAYERS; id++)
    {
        if (!is_user_connected(id)) continue;

        switch (get_member(id, m_iTeam))
        {
            case TEAM_CT: iTeamCT++;
            case TEAM_TERRORIST: iTeamTT++;
        }
    }
}