#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1
#pragma ctrlchar '\'

#include <ChatAdditions>

new const MSG_PREFIX[] = "\4[MUTE]\1";

new bool: g_aMutes[MAX_PLAYERS + 1][MAX_PLAYERS + 1];
new bool: g_bGlobalMute[MAX_PLAYERS + 1];

new Float:g_fNextUse[MAX_PLAYERS + 1];
new Float:ca_mute_use_delay;

new const LOG_DIR_NAME[] = "CA_Mute";
new g_sLogsFile[PLATFORM_MAX_PATH];

new ca_log_type,
	LogLevel_s: ca_log_level = _Info;

public plugin_init()
{
	register_plugin("[CA] Mute menu", "1.0.0-beta", "Sergey Shorokhov");
	register_dictionary("CA_Mute.txt");

	bind_pcvar_num(get_cvar_pointer("ca_log_type"), ca_log_type);
	hook_cvar_change(get_cvar_pointer("ca_log_level"), "Hook_CVar_LogLevel");
	GetLogsFilePath(g_sLogsFile, .sDir = LOG_DIR_NAME);

	bind_pcvar_float(create_cvar("ca_mute_use_delay", "5.0",
		.description = "How often can players use menu.",
		.has_min = true, .min_val = 0.0,
		.has_max = true, .max_val = 60.0
	), ca_mute_use_delay);

	new const sCmd[] = "mute";
	new const sCtrlChar[][] = {"!", "/", "\\", "." , "?", ""};
	for(new i; i < sizeof(sCtrlChar); i++) {
		register_clcmd(fmt("%s%s", sCtrlChar[i], sCmd), "ClCmd_Mute");
		register_clcmd(fmt("say %s%s", sCtrlChar[i], sCmd), "ClCmd_Mute");
		register_clcmd(fmt("say_team %s%s", sCtrlChar[i], sCmd), "ClCmd_Mute");
	}

	CA_Log("[CA] Mute initialized!")
}

public plugin_cfg() {
	new sLogLevel[MAX_LOGLEVEL_LEN];
	get_cvar_string("ca_log_level", sLogLevel, charsmax(sLogLevel));
	ca_log_level = ParseLogLevel(sLogLevel);

	CA_Log(_Info, "[CA]: Mute initialized!")
}

public Hook_CVar_LogLevel(pcvar, const old_value[], const new_value[]) {
	ca_log_level = ParseLogLevel(new_value);
}


public ClCmd_Mute(id) {
	Menu_Show_PlayersList(id);

	return PLUGIN_HANDLED;
}

public Menu_Show_PlayersList(id) {
	if(!is_user_connected(id))
		return;

	new pMenu = menu_create(fmt("%L", id, "CA_Mute_TITLE"), "Menu_Handler_PlayersList");

	static hCallback;
	if(!hCallback)
		hCallback = menu_makecallback("Callback_PlayersList");

	new aPlayers[MAX_PLAYERS], iCount;
	get_players_ex(aPlayers, iCount, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));

	if(iCount < 2) {
		menu_additem(pMenu, fmt("\\r %L", id, "Mute_NotEnoughPlayers"), "-2", .callback = hCallback);
	} else {
		menu_additem(pMenu, fmt("\\y %L %s", id, "CA_Mute_MuteALL", g_bGlobalMute[id] ? "\\w[ \\r+\\w ]" : ""), "-1");
		menu_addblank(pMenu, .slot = false);

		new sName[128];

		for(new i; i < iCount; i++) {
			new target = aPlayers[i];

			if(target == id)
				continue;

			get_user_name(target, sName, charsmax(sName));

			if(g_aMutes[id][target])
				strcat(sName, " \\d[ \\r+\\d ]", charsmax(sName));

			if(g_bGlobalMute[target] || g_aMutes[target][id])
				strcat(sName, fmt(" \\d(\\y%L\\d)", id, "Menu_Muted_you"), charsmax(sName));

			menu_additem(pMenu, sName, fmt("%i", get_user_userid(target)), .callback = hCallback);
		}
	}

	menu_setprop(pMenu, MPROP_BACKNAME, fmt("%L", id, "CA_Mute_Back"));
	menu_setprop(pMenu, MPROP_NEXTNAME, fmt("%L", id, "CA_Mute_Next"));
	menu_setprop(pMenu, MPROP_EXITNAME, fmt("%L", id, "CA_Mute_Exit"));

	menu_display(id, pMenu);
}

public Callback_PlayersList(id, menu, item) {
	new null, sInfo[64], sName[128];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new iUserID = strtol(sInfo);

	return (
			(iUserID != -1 && g_bGlobalMute[id])
			|| iUserID == -2
		) ? ITEM_DISABLED : ITEM_ENABLED;
}

public Menu_Handler_PlayersList(id, menu, item) {
	if(item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new Float:gametime = get_gametime();
	if(g_fNextUse[id] > gametime) {
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Menu_UseToOften");

		menu_destroy(menu);
		Menu_Show_PlayersList(id);
		return PLUGIN_HANDLED;
	}

	new iUserID = strtol(sInfo);
	if(iUserID == -1) {
		g_bGlobalMute[id] ^= true;

		client_print_color(0, print_team_default, "%s \3%n\1 %L ", MSG_PREFIX,
			id, LANG_PLAYER, g_bGlobalMute[id] ? "Player_Muted_All" : "Player_UnMuted_All"
		);

		CA_Log("Mute: \"%N\" %smuted everyone", id, g_bGlobalMute[id] ? "" : "Un")

		menu_destroy(menu);
		Menu_Show_PlayersList(id);
		return PLUGIN_HANDLED;
	}

	new player = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), iUserID);
	if(!is_user_connected(player)) {
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");

		menu_destroy(menu);
		Menu_Show_PlayersList(id);
		return PLUGIN_HANDLED;
	}

	g_aMutes[id][player] ^= true;
	client_print_color(id, print_team_default, "%s %L \3%n\1", MSG_PREFIX,
		id, g_aMutes[id][player] ? "CA_Mute_Muted" : "CA_Mute_UnMuted", player
	);

	client_print_color(player, print_team_default, "%s \3%n\1 %L ", MSG_PREFIX,
		player, id, g_aMutes[id][player] ? "Player_Muted_you" : "Player_UnMuted_you"
	);

	CA_Log(_Info, "Mute: '%N' %smuted '%N'", id, player, g_aMutes[id][player] ? "" : "Un")

	g_fNextUse[id] = gametime + ca_mute_use_delay;

	menu_destroy(menu);
	Menu_Show_PlayersList(id);

	return PLUGIN_HANDLED;
}


public client_disconnected(id) {
	arrayset(g_aMutes[id], false, sizeof g_aMutes[]);
	g_bGlobalMute[id] = false;
	g_fNextUse[id] = 0.0;

	for(new i; i < sizeof g_aMutes[]; i++)
		g_aMutes[i][id] = false;
}

public CA_Client_Voice(const listener, const sender) {
	return (g_aMutes[listener][sender] == true || g_bGlobalMute[listener] || g_bGlobalMute[sender]) ? CA_SUPERCEDE : CA_CONTINUE;
}