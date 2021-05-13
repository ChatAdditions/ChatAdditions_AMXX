#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <CA_GAG_API>

#include <CA_AutoPromt>		//Kostili <3

/* -------------------- */

// Время в секундах, через которое будет предложено заткнуть говорящего без остановки
#define AUTOPROMT_TIME 10.0

/* -------------------- */

const MENU_KEYS = MENU_KEY_1|MENU_KEY_2

new const MENU_IDENT_STRING[] = "MuteAuto"

enum { _KEY1_, _KEY2_, _KEY3_, _KEY4_, _KEY5_, _KEY6_, _KEY7_, _KEY8_, _KEY9_, _KEY0_ }

new g_iChooseNo[MAX_PLAYERS + 1][MAX_PLAYERS + 1]
new g_iUserId[MAX_PLAYERS + 1]
new g_iMenuID

public plugin_init() {
	register_plugin("Mute AutoPromt", "1.2", "mx?!")
}

public VTC_OnClientStartSpeak(const pPlayer) {
	remove_task(pPlayer)

	if(!ca_has_user_gag(pPlayer)) {
		set_task(AUTOPROMT_TIME, "task_AutoPromt", pPlayer)
	}
}

public VTC_OnClientStopSpeak(const pPlayer) {
	remove_task(pPlayer)
}

public client_disconnected(pPlayer) {
	remove_task(pPlayer)
}

public client_putinserver(pPlayer) {
	arrayset(g_iChooseNo[pPlayer], 0, sizeof(g_iChooseNo[]))
}

public task_AutoPromt(pPlayer) {
	if(!task_exists(pPlayer) || ca_has_user_gag(pPlayer)) {
		return
	}

	if(VTC_IsClientSpeaking(pPlayer)) {
		set_task(AUTOPROMT_TIME, "task_AutoPromt", pPlayer)
	}

	if(!g_iMenuID) {
		g_iMenuID = register_menuid(MENU_IDENT_STRING)
		register_menucmd(g_iMenuID, MENU_KEYS, "func_Menu_Handler")
	}

	new szMenu[MAX_MENU_LENGTH]

	formatex( szMenu, charsmax(szMenu),
		"\yВы хотите заткнуть \w%n \y?^n\
		^n\
		\r1. \wДа^n\
		\r2. \wНет",

		pPlayer
	);

	new pPlayers[MAX_PLAYERS], iPlCount, pGamer
	get_players_ex(pPlayers, iPlCount, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV)

	for(new i, iKeys, iUserId = get_user_userid(pPlayer); i < iPlCount; i++) {
		pGamer = pPlayers[i]

		if(
			g_iChooseNo[pGamer][pPlayer] != iUserId
				&&
			!ca_get_user_muted(pGamer, pPlayer)
				&&
			pGamer != pPlayer
		) {
			new iMenuID
			get_user_menu(pPlayer, iMenuID, iKeys)

			if(!iMenuID) {
				g_iUserId[pGamer] = iUserId
				show_menu(pGamer, MENU_KEYS, szMenu, -1, MENU_IDENT_STRING)
			}
		}
	}
}

public func_Menu_Handler(pPlayer, iKey) {
	new pTarget = find_player_ex(FindPlayer_MatchUserId, g_iUserId[pPlayer])

	if(!pTarget) {
		return PLUGIN_HANDLED
	}

	switch(iKey) {
		case _KEY1_: {
			ca_set_user_muted(pPlayer,pTarget,1);
		}
		case _KEY2_: {
			g_iChooseNo[pPlayer][pTarget] = g_iUserId[pPlayer]
		}
	}

	return PLUGIN_HANDLED
}