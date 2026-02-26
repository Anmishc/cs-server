/*-----------------------------------------НАСТРОЙКИ-----------------------------------------*/

// Сообщение о рестарте (%i - таймер, ^n - перенос строки)
#define MESSAGE "Игра начнётся через %i сек."

// Цвет сообщения в RGB (от 0 до 255)
// Если хотите случайные цвета каждую секунду, вместо чисел подставьте random_num(0, 255)
#define RED		255		// Количество красного цвета
#define GREEN	255		// Количество зелёного цвета
#define BLUE	255		// Количество синего цвета

// Координаты сообщения (от 0.0 до 1.0. -1.0 - по центру)
#define XPOS	-1.0	// Позиция по оси X
#define YPOS	0.06	// Позиция по оси Y

// Количество секунд до рестарта от начала карты
new g_iTimeToRestart = 15

/*---------------------------------ДЛЯ ОПЫТНЫХ ПОЛЬЗОВАТЕЛЕЙ---------------------------------*/

// ID set_task
#define TASK_ID 74

/*--------------------------------------------КОД--------------------------------------------*/

#include <amxmodx>
#include <reapi>

public plugin_init() {
	register_plugin("Lite Auto Restart", "1.0", "CHEL74")
	
	set_task(1.0, "ResTimer", TASK_ID, .flags = "b")
}

public ResTimer() {
	g_iTimeToRestart--
	
	set_dhudmessage(RED, GREEN, BLUE, XPOS, YPOS, _, _, 1.05, 0.0, 0.0)
	show_dhudmessage(0, MESSAGE, g_iTimeToRestart)
	
	if(g_iTimeToRestart < 1) {
		set_member_game(m_bCompleteReset, true)
		rg_round_end(0.0, WINSTATUS_DRAW, ROUND_END_DRAW, "", "", true)
		
		remove_task(TASK_ID)
	}
}