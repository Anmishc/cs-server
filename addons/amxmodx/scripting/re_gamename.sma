#include <amxmodx>
#include <reapi>

// Частота смены в секундах
const Float:FREQ = 5.0

new const NAMES[][] = {
    "Бесплатные VIP",
    "1000FPS + FREE VIP"
}

public plugin_init()
{
    register_plugin("GameName Changer", "1.0", "mx?!");

    set_task(FREQ, "task_Change", .flags = "b");
}

public task_Change() {
    static iPtr;

    set_member_game(m_GameDesc, NAMES[iPtr]);

    if(++iPtr == sizeof(NAMES)) {
        iPtr = 0;
    }
}