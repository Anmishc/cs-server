#include <amxmodx>
#include <reapi>

public plugin_init()
{
    register_plugin("[ReAPI] Parachute[Mute]", "1.1f", "ReHLDS Team+mx?!");
    RegisterHookChain(RG_PM_AirMove, "PM_AirMove", false);
    RegisterHookChain(RG_CBasePlayer_UseEmpty, "CBasePlayer_UseEmpty", false);
}

public CBasePlayer_UseEmpty(const playerIndex)
{
    if( (get_entvar(playerIndex, var_flags) & FL_ONGROUND) || get_entvar(playerIndex, var_waterlevel) > 0 ) {
        return HC_CONTINUE;
    }
    
    return HC_SUPERCEDE;
}

public PM_AirMove(const playerIndex)
{
    if (!(get_entvar(playerIndex, var_button) & IN_USE)
    || get_entvar(playerIndex, var_waterlevel) > 0) {
        return;
    }
    new Float:flVelocity[3];
    get_entvar(playerIndex, var_velocity, flVelocity);
    if (flVelocity[2] < 0.0)
    {
        flVelocity[2] = (flVelocity[2] + 40.0 < -100.0) ? flVelocity[2] + 40.0 : -100.0;
        set_entvar(playerIndex, var_sequence, ACT_WALK);
        set_entvar(playerIndex, var_gaitsequence, ACT_IDLE);
        set_pmove(pm_velocity, flVelocity);
    }
}