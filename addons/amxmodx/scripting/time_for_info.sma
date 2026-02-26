#include <amxmodx>
#include <fakemeta>
#include <reapi>

#define VIP_ACCESS ADMIN_LEVEL_A

#define TIME_FOR_INFO 5.0 // Время после смерти, через которое живые не услышат игрока

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if AMXX_VERSION_NUM < 183
    #define client_disconnected client_disconnect
    #include <dhudmessage>
    #include <colorchat>
#endif

#define is_user_vip(%0) (get_user_flags(%0) & VIP_ACCESS)

const DELAY_TASK_ID = 32173;

new bool:g_bBlockVoice[MAX_PLAYERS + 1];
new g_iUserAlive[MAX_PLAYERS + 1];

public plugin_init()
{
    register_plugin("Time for info", "1.2", "Devil Judge");
    
    RegisterHookChain(RG_CBasePlayer_Spawn, "fwdPlayerSpawnPost", true);
    RegisterHookChain(RG_CBasePlayer_Killed, "fwdPlayerKilledPost", true);
    
    register_forward(FM_Voice_SetClientListening, "FwdSetClientListening", false);
}

public client_putinserver(id)
{
    if(is_user_vip(id))
    {
        g_iUserAlive[id] = false;
        g_bBlockVoice[id] = false;
    }
    else
    {
        g_iUserAlive[id] = false;
        g_bBlockVoice[id] = true;       
    }
}   

public fwdPlayerSpawnPost(id)
{
    if(is_user_vip(id)) return;
    
    g_iUserAlive[id] = is_user_alive(id);
    if(g_iUserAlive[id])
        g_bBlockVoice[id] = false;
}

public fwdPlayerKilledPost(const id)
{
        if(is_user_vip(id)) return;
        
        g_iUserAlive[id] = false;
        g_bBlockVoice[id] = false;
        
        g_iUserAlive[id] = 0;
        set_hudmessage(70, 150, 0, -1.0, 0.3, 1, 5.0, 5.0, TIME_FOR_INFO);
        show_hudmessage(id, "У тебя есть 5 секунд, чтобы дать инфу.");		
	client_print_color(id, 0, "^4#1FUP: ^1У тебя есть ^3%.0f сек^1, чтобы дать инфу, после - живые тебя ^3не услышат^1.", TIME_FOR_INFO);
	set_task(TIME_FOR_INFO, "BlockVoice", id+DELAY_TASK_ID);
}

public FwdSetClientListening(iReciever, iSender)
{
    if(iSender != iReciever && g_bBlockVoice[iSender] && g_iUserAlive[iReciever])
    {   
        engfunc(EngFunc_SetClientListening, iReciever, iSender, false);
        forward_return(FMV_CELL, false);
        return FMRES_SUPERCEDE;
    }
    return FMRES_IGNORED;
}

public BlockVoice(id)
{
    id-=DELAY_TASK_ID;
    if(!g_iUserAlive[id])
    {
        g_bBlockVoice[id] = true;		
        set_hudmessage(255, 100, 0, -1.0, 0.25, 1, 8.0, 8.0, 0.1, 0.5, 4);
        show_hudmessage(id, "Живые товарищи по команде^n больше не слышат тебя.");
	client_print_color(id, 0, "^4#1FUP: ^1Время для инфы ^3истекло^1. Живые игроки тебя ^3не слышат^1.");		
    }   
}