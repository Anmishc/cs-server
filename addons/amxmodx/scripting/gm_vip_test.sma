#include <amxmodx>
#include <reapi>
#include <gm_time>
#include <nvault_array>

#define GetCvarDesc(%0) fmt("%L", LANG_SERVER, %0)

enum _:PCVAR
{
    TIME,
    TIMEOUT,
    REMOVE,
    FLAGS[26],
    IGN_FLAGS[64]
}
new g_pCvar[PCVAR];

enum ePlayerInfo
{
    AuthId[MAX_AUTHID_LENGTH],
    sTime,
    Set
}
new g_PlayerInfo[MAX_PLAYERS + 1][ePlayerInfo];

new g_hVault = INVALID_HANDLE;
new const VAULT_FILE[] = "gm_viptest_data";

public plugin_init()
{
    register_plugin("[GM] VIP Test","1.2.0","[GM] NWC");

    register_dictionary("gm_vip_test.txt");
    register_dictionary("gm_time.txt");

    register_clcmd("say /viptest","VipTest");
    register_clcmd("say_team /viptest","VipTest");

    CreateCvars();

    AutoExecConfig(true, "viptest", "gm_plugins");

    RegisterHookChain(RG_RoundEnd, "RG_RoundEnd_Pre", false);
}

public plugin_cfg()
{
	if((g_hVault = nvault_open(VAULT_FILE)) == INVALID_HANDLE)
    {
		set_fail_state("[GM VIPTEST] ERROR: Opening nVault failed!");
    }
}

public plugin_end() 
{
	if(g_hVault != INVALID_HANDLE)
    {
		nvault_close(g_hVault);
    }
}

public client_putinserver(id)
{
    g_PlayerInfo[id][AuthId][0] = 0;

    if(is_user_bot(id) || is_user_hltv(id))
    {
        return;
    }

    get_user_authid(id, g_PlayerInfo[id][AuthId], MAX_AUTHID_LENGTH - 1);

    if(nvault_get_array(g_hVault, g_PlayerInfo[id][AuthId], g_PlayerInfo[id], ePlayerInfo) > 0)
    {
        if(g_PlayerInfo[id][Set] == 1 && (g_PlayerInfo[id][sTime] + g_pCvar[TIME] * 60) > get_systime())
        {
            if(!is_access(id))
            {
                set_user_flags(id, read_flags(g_pCvar[FLAGS]));
                
                if(g_pCvar[REMOVE])
                {
                    remove_user_flags(id, ADMIN_USER);
                }
            }
        }
        else
        if(g_PlayerInfo[id][Set] == 1 && (g_PlayerInfo[id][sTime] + g_pCvar[TIME] * 60) < get_systime())
        {
            g_PlayerInfo[id][Set] = 0;
        }
    }
}

public VipTest(id)
{
    if(get_user_flags(id) & read_flags(g_pCvar[FLAGS]) || is_access(id))
    {
        client_print_color(id, print_team_red, "%L %L", -1, "VIPTEST_PREFIX", -1, "VIPTEST_YOU_VIP");
    }
    else 
    if(g_PlayerInfo[id][Set] == 0 && (g_PlayerInfo[id][sTime] + g_pCvar[TIMEOUT] * 86400) > get_systime())
    {
        new cTimeLength[128], iSecondsLeft = g_PlayerInfo[id][sTime] + g_pCvar[TIMEOUT]* 86400 - get_systime();

        get_str_time(id, iSecondsLeft, cTimeLength, charsmax(cTimeLength));

        client_print_color(id, print_team_red, "%L %L", -1, "VIPTEST_PREFIX", -1, "VIPTEST_TIMEOUT_VIP", cTimeLength);
    }
    else
    if(g_PlayerInfo[id][Set] == 0 && (g_PlayerInfo[id][sTime] + g_pCvar[TIMEOUT] * 86400) < get_systime())
    {
        g_PlayerInfo[id][Set] = 1;
        g_PlayerInfo[id][sTime] = get_systime();

        set_user_flags(id, read_flags(g_pCvar[FLAGS]));

        if(g_pCvar[REMOVE])
        {
            remove_user_flags(id, ADMIN_USER);
        }

        SaveUserInfo(id);

        new cTimeLength[128], iSecondsLeft = g_pCvar[TIME] * 60;

        get_str_time(id, iSecondsLeft, cTimeLength, charsmax(cTimeLength));

        client_print_color(id, print_team_blue, "%L %L", -1, "VIPTEST_PREFIX", -1, "VIPTEST_YOU_GIVE_VIP", cTimeLength);
    }

    return PLUGIN_HANDLED;
}

public RG_RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
    for(new id=1; id <= MaxClients; id++)
    {
        if((g_PlayerInfo[id][sTime] + g_pCvar[TIME] * 60) < get_systime() && g_PlayerInfo[id][Set] == 1)
        {
            g_PlayerInfo[id][Set] = 0;
            remove_user_flags(id, read_flags(g_pCvar[FLAGS]));

            if(g_pCvar[REMOVE])
            {
                set_user_flags(id, ADMIN_USER);
            }

            SaveUserInfo(id);

            new cTimeLength[128], iSecondsLeft = g_pCvar[TIMEOUT] * 86400;

            get_str_time(id, iSecondsLeft, cTimeLength, charsmax(cTimeLength));

            client_print_color(id, print_team_red, "%L %L", -1, "VIPTEST_PREFIX", -1, "VIPTEST_END", cTimeLength);
        }
    }
}

public client_disconnected(id)
{
    SaveUserInfo(id);
}

CreateCvars()
{
    bind_pcvar_num(create_cvar("viptest_time", "60", 
        .description = GetCvarDesc("VIPTEST_CVAR_TIME"), 
        .has_min = true, .min_val = 0.0),
        g_pCvar[TIME]
    );

    bind_pcvar_num(create_cvar("viptest_timeout", "30",
        .description = GetCvarDesc("VIPTEST_CVAR_TIMEOUT"),
        .has_min = true, .min_val = 1.0),
        g_pCvar[TIMEOUT]
    );

    bind_pcvar_num(create_cvar("viptest_remove_flag_z", "0",
        .description = GetCvarDesc("VIPTEST_CVAR_REMOVE"),
        .has_min = true, .min_val = 0.0,
        .has_max = true, .max_val = 1.0),
        g_pCvar[REMOVE]
    );

    bind_pcvar_string(create_cvar("viptest_flags", "t",
        .flags = FCVAR_NOEXTRAWHITEPACE, 
        .description = GetCvarDesc("VIPTEST_CVAR_FLAGS")), 
        g_pCvar[FLAGS], charsmax(g_pCvar[FLAGS])
    );
    
    bind_pcvar_string(create_cvar("viptest_ignor_flags", "t",
        .flags = FCVAR_NOEXTRAWHITEPACE, 
        .description = GetCvarDesc("VIPTEST_CVAR_IGN_FLAGS")), 
        g_pCvar[IGN_FLAGS], charsmax(g_pCvar[IGN_FLAGS])
    );
}

stock SaveUserInfo(const id)
{
	if(!is_user_bot(id) && !is_user_hltv(id))
    {
        nvault_set_array(g_hVault, g_PlayerInfo[id][AuthId], g_PlayerInfo[id], ePlayerInfo);
	}
}

stock is_access(const iPlayer)  // If you know a better function, then write)
{
    if(equal(g_pCvar[IGN_FLAGS], "")) return false;

    new flag[2], iFlags = get_user_flags(iPlayer);

    if(contain(g_pCvar[IGN_FLAGS], ":") != -1)
    {
        for(new i, y, str_len = strlen(g_pCvar[IGN_FLAGS]); i <= str_len; i++)
        {   
            copy(flag, 1, g_pCvar[IGN_FLAGS][i]);

            if(!equal(flag, ":") && !equal(flag, ""))
            {
                ++y;
            }

            if(equal(flag, ":") || equal(flag, "")) 
            {
                if(!y) continue;

                for(new x = i - y; x < i; x++)
                {
                    copy(flag, 1, g_pCvar[IGN_FLAGS][x]);
                    if(!(iFlags & read_flags(flag))) break;
                    if(x + 1 == i) return true;
                }

                y = 0;

                continue;
            }
            
            continue;
        }

        return false;
    }

    for(new i, str_len = strlen(g_pCvar[IGN_FLAGS]); i < str_len ; i++)
    {   
        copy(flag, 1, g_pCvar[IGN_FLAGS][i]);
        if(!(iFlags & read_flags(flag))) return false;
        if(i + 1 == str_len) return true;
    }

    return false;
}