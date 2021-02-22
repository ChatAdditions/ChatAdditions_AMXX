
// #define DEBUG

#include <amxmodx>
#include <amxmisc>
#include <time>

#include <ChatAdditions>
#include <CA_GAG_API>
#include <CA_StorageAPI>

#pragma semicolon 1
#pragma ctrlchar '\'
#pragma dynamic 524288


		/* ----- START SETTINGS----- */
new const MSG_PREFIX[] = "\4[GAG]\1";

#define FLAGS_ACCESS    ( ADMIN_KICK )
#define FLAGS_IMMUNITY    ( ADMIN_IMMUNITY )
		/* ----- END OF SETTINGS----- */

new g_aCurrentGags[MAX_PLAYERS + 1][gag_s];
static g_aGags_AdminEditor[MAX_PLAYERS + 1][gag_s];

static Array: g_aReasons, g_iArraySize_Reasons;
static Array: g_aGagTimes, g_iArraySize_GagTimes;

new const LOG_DIR_NAME[] = "CA_Gag";
new g_sLogsFile[PLATFORM_MAX_PATH];

new ca_log_type,
	LogLevel_s: ca_log_level = _Info;

enum _:GagMenuType_s {
	_MenuType_Custom,
	_MenuType_Sequential
}
new ca_gag_menu_type;

public plugin_precache() {
	register_plugin("[CA] Gag", CA_VERSION, "Sergey Shorokhov");

	register_dictionary("CA_Gag.txt");
	register_dictionary("common.txt");
	register_dictionary("time.txt");

	g_aReasons = ArrayCreate(gag_s);
	g_aGagTimes = ArrayCreate();

	bind_pcvar_num(get_cvar_pointer("ca_log_type"), ca_log_type);
	hook_cvar_change(get_cvar_pointer("ca_log_level"), "Hook_CVar_LogLevel");
	GetLogsFilePath(g_sLogsFile, .sDir = LOG_DIR_NAME);

	hook_cvar_change(
		create_cvar("ca_gag_times", "1, 5, 30, 60, 1440, 10080"),
		"Hook_CVar_Times"
	);

	bind_pcvar_num(create_cvar("ca_gag_menu_type", "1"), ca_gag_menu_type);

	register_srvcmd("ca_gag_add_reason", "SrvCmd_AddReason");
	register_srvcmd("ca_gag_show_templates", "SrvCmd_ShowTemplates"); // debug
	register_srvcmd("ca_gag_reload_config", "SrvCmd_ReloadConfig");

	new const szCmd[] = "gag";
	new const szCtrlChar[][] = {"!", "/", "\\", "." , "?", ""};
	for(new i; i < sizeof(szCtrlChar); i++) {
		register_clcmd(fmt("%s%s", szCtrlChar[i], szCmd), "ClCmd_Gag", FLAGS_ACCESS);
		register_clcmd(fmt("say %s%s", szCtrlChar[i], szCmd), "ClCmd_Gag", FLAGS_ACCESS);
		register_clcmd(fmt("say_team %s%s", szCtrlChar[i], szCmd), "ClCmd_Gag", FLAGS_ACCESS);
	}

	register_clcmd("enter_GagReason", "ClCmd_EnterGagReason");
	register_clcmd("enter_GagTime", "ClCmd_EnterGagTime");

	const Float: UPDATER_FREQ = 3.0;
	set_task(UPDATER_FREQ, "Gags_Thinker", .flags = "b");
}

public plugin_init() {
	new sLogLevel[MAX_LOGLEVEL_LEN];
	get_cvar_string("ca_log_level", sLogLevel, charsmax(sLogLevel));
	ca_log_level = ParseLogLevel(sLogLevel);
	
	_LoadConfig();
	_ParseTimes();

	CA_Log(_Info, "[CA]: Gag initialized!")
}

public Hook_CVar_LogLevel(pcvar, const old_value[], const new_value[]) {
	ca_log_level = ParseLogLevel(new_value);
}

public plugin_natives() {
	register_library("ChatAdditions_GAG_API");
	set_native_filter("native_filter");
	
	// TODO: Need CRUD
	register_native("ca_set_user_gag", "native_ca_set_user_gag");
	register_native("ca_get_user_gag", "native_ca_get_user_gag");
	register_native("ca_has_user_gag", "native_ca_has_user_gag");
	// register_native("ca_update_user_gag", "native_ca_update_user_gag");
	register_native("ca_remove_user_gag", "native_ca_remove_user_gag");

	// TODO: Create forwards: gagged, ungagged, loaded from storage, saved to storage
}

public native_filter(const name[], index, trap) {
    return !trap ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}
public Gags_Thinker() {
	static aPlayers[MAX_PLAYERS], iCount;
	get_players_ex(aPlayers, iCount, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));

	static currentTime; currentTime = get_systime();

	for(new i; i < iCount; i++) {
		new id = aPlayers[i];

		new expireAt = g_aCurrentGags[id][_ExpireTime];
		if(expireAt != 0 && expireAt < currentTime) {
			GagExpired(id);
		}
	}
}

public ClCmd_Gag(id, level, cid) {
	#if !defined DEBUG
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	#endif

	if(get_playersnum() < 2) {
		client_print_color(id, print_team_default, "%s %L", MSG_PREFIX, id, "NotEnoughPlayers");
		return PLUGIN_HANDLED;
	}

	Menu_Show_PlayersList(id);
	return PLUGIN_HANDLED;
}

static Menu_Show_PlayersList(id) {
	if(!is_user_connected(id))
		return;

	new hMenu = menu_create(fmt("%L", id, "CA_Gag_TITLE"), "Menu_Handler_PlayersList");

	static hCallback;
	if(!hCallback)
		hCallback = menu_makecallback("Callback_PlayersMenu");

	static bool:bHaveImmunity = false;

	new aPlayers[MAX_PLAYERS], iCount;
	get_players_ex(aPlayers, iCount, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));
	for(new i; i < iCount; i++) {
		new target = aPlayers[i];

		if(target == id)
			continue;

		bHaveImmunity = !!(get_user_flags(target) & FLAGS_IMMUNITY);
		menu_additem(hMenu, fmt("%n %s", target, GetPostfix(id, target, bHaveImmunity)), fmt("%i", get_user_userid(aPlayers[i])), .callback = hCallback);
	}

	menu_setprop(hMenu, MPROP_BACKNAME, fmt("%L", id, "Gag_Menu_Back"));
	menu_setprop(hMenu, MPROP_NEXTNAME, fmt("%L", id, "Gag_Menu_Next"));
	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Exit"));

	menu_display(id, hMenu);
}

public Callback_PlayersMenu(id, menu, item) {
	static bool:bHaveImmunity = false;
	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), strtol(sInfo));
	bHaveImmunity = !!(get_user_flags(target) & FLAGS_IMMUNITY);

	return (!bHaveImmunity) ? ITEM_ENABLED : ITEM_DISABLED;
}

public Menu_Handler_PlayersList(id, menu, item) {
	if(item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);
	menu_destroy(menu);

	new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), strtol(sInfo));

	if(!is_user_connected(target)) {
		Menu_Show_PlayersList(id);
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");

		return PLUGIN_HANDLED;
	}

	if(g_aCurrentGags[target][_bitFlags] != m_REMOVED) {
		GagData_Copy(g_aGags_AdminEditor[id], g_aCurrentGags[target]);
		g_aGags_AdminEditor[id][_Player] = target;
		Menu_Show_ConfirmRemove(id);
	} else {
		GagData_GetPersonalData(id, target, g_aGags_AdminEditor[id]);
		if(ca_gag_menu_type == _MenuType_Custom) {
			Menu_Show_GagProperties(id);
		} else if (ca_gag_menu_type == _MenuType_Sequential) {
			Menu_Show_SelectReason(id);
		}
	}

	return PLUGIN_HANDLED;
}

// Confirm remove gag
static Menu_Show_ConfirmRemove(id) {
	if(!is_user_connected(id))
		return;

	new hMenu = menu_create(fmt("%L", id, "GAG_Confirm"), "Menu_Handler_ConfirmRemove");

	menu_additem(hMenu, fmt("%L", id, "CA_GAG_YES"));
	menu_additem(hMenu, fmt("%L", id, "CA_GAG_NO"));

	menu_addblank2(hMenu);
	menu_addblank2(hMenu);
	menu_addblank2(hMenu);
	menu_addblank2(hMenu);
	menu_addblank2(hMenu);
	menu_addblank2(hMenu);
	menu_addblank2(hMenu);

	menu_setprop(hMenu, MPROP_PERPAGE, 0);
	menu_setprop(hMenu, MPROP_EXIT, MEXIT_FORCE);

	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Cancel"));

	menu_display(id, hMenu);
}

public Menu_Handler_ConfirmRemove(id, menu, item) {
	menu_destroy(menu);

	enum { menu_Yes, menu_No };

	new target = g_aGags_AdminEditor[id][_Player];
	if(!is_user_connected(target)) {
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");
		Menu_Show_PlayersList(id);
		
		return PLUGIN_HANDLED;
	}

	if(item == MENU_EXIT || item < 0) {
		GagData_Reset(g_aGags_AdminEditor[id]);
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}
	
	switch(item) {
		case menu_Yes: {
			RemoveGag(id, target);
		}
		case menu_No: {
			// Copy target to temporary
			new aGagData[gag_s]; {
				GagData_GetPersonalData(id, target, aGagData);

				// Get old gag data
				copy(aGagData[_Reason], charsmax(aGagData[_Reason]), g_aCurrentGags[target][_Reason]);
				aGagData[_Time] = g_aCurrentGags[target][_Time];
				aGagData[_bitFlags] = g_aCurrentGags[target][_bitFlags];
			}
			GagData_Copy(g_aGags_AdminEditor[id], aGagData);

			// DEBUG__Dump_GagData("Menu_Handler_ConfirmRemove", g_aGags_AdminEditor[id]);

			Menu_Show_GagProperties(id);
			
			return PLUGIN_HANDLED;
		}
	}

	Menu_Show_PlayersList(id);

	return PLUGIN_HANDLED;
}

// Gag Properties menu
static Menu_Show_GagProperties(id) {
	if(!is_user_connected(id))
		return;
	
	new target = g_aGags_AdminEditor[id][_Player];
	new hMenu = menu_create(fmt("%L", id, "CA_Gag_Properties", target), "Menu_Handler_GagProperties");

	static hCallback;
	if(!hCallback)
		hCallback = menu_makecallback("Callback_GagProperties");

	new gag_flags_s: gagFlags = g_aGags_AdminEditor[id][_bitFlags];
	new bool: hasAlreadyGag = g_aCurrentGags[target][_bitFlags] != m_REMOVED;
	new bool: hasChanges = !GagData_Equal(g_aCurrentGags[target], g_aGags_AdminEditor[id]);	

	menu_additem(hMenu, fmt("%L [ %s ]", id, "CA_Gag_Say",
		(gagFlags & m_Say) ? " \\r+\\w " : "-")
	);
	menu_additem(hMenu, fmt("%L [ %s ]", id, "CA_Gag_SayTeam",
		(gagFlags & m_SayTeam) ? " \\r+\\w " : "-")
	);
	menu_additem(hMenu, fmt("%L [ %s ]", id, "CA_Gag_Voice",
		(gagFlags & m_Voice) ? " \\r+\\w " : "-")
	);

	if(ca_gag_menu_type == _MenuType_Custom) {
		menu_addblank(hMenu, false);

		menu_additem(hMenu, fmt("%L [ \\y%s\\w ]", id, "Gag_Menu_Reason",
			Get_GagStringReason(id, target)), .callback = hCallback
		);
		menu_additem(hMenu, fmt("%L [ \\y%s\\w ]", id, "CA_Gag_Time",
			GetStringTime_seconds(id, g_aGags_AdminEditor[id][_Time]))
		);
	}

	menu_addblank(hMenu, false);

	menu_additem(hMenu, fmt("%L %s", id, "CA_Gag_Confirm",
		(hasAlreadyGag && hasChanges) ? "edit" : ""), .callback = hCallback
	);

	menu_addtext(hMenu, fmt("\n%L", id, "Menu_WannaGag",
		GetStringTime_seconds(id, g_aGags_AdminEditor[id][_Time]),
		Get_GagStringReason(id, target)), false);

	if(ca_gag_menu_type == _MenuType_Sequential)
	{
		menu_addblank2(hMenu);
		menu_addblank2(hMenu);
	}

	menu_addblank2(hMenu);
	menu_addblank2(hMenu);
	menu_addblank2(hMenu);

	menu_setprop(hMenu, MPROP_PERPAGE, 0);
	menu_setprop(hMenu, MPROP_EXIT, MEXIT_FORCE);

	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Cancel"));

	menu_display(id, hMenu);
}

public Callback_GagProperties(id, menu, item) {
	enum { /* menu_Chat, menu_TeamChat, menu_VoiceChat, */
			/* menu_Reason = 3, */ /* menu_Time, */ menu_Confirm = 5
		};

	enum { sequential_Confirm = 3};

	new bool: IsConfirmItem = (
		item == menu_Confirm && ca_gag_menu_type == _MenuType_Custom
		|| item == sequential_Confirm && ca_gag_menu_type == _MenuType_Sequential
	);

	new bool: isReadyToGag = (g_aGags_AdminEditor[id][_bitFlags] != m_REMOVED);

	return (
		IsConfirmItem && !isReadyToGag
		) ? ITEM_DISABLED : ITEM_ENABLED;
}

public Menu_Handler_GagProperties(id, menu, item) {
	menu_destroy(menu);

	enum { menu_Chat, menu_TeamChat, menu_VoiceChat,
			menu_Reason, menu_Time, menu_Confirm
		};

	enum { sequential_Confirm = 3 };

	if(item == MENU_EXIT || item < 0) {
		GagData_Reset(g_aGags_AdminEditor[id]);
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}

	new target = g_aGags_AdminEditor[id][_Player];
	if(!is_user_connected(target)) {
		Menu_Show_PlayersList(id);
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");

		return PLUGIN_HANDLED;
	}

	switch(item) {
		case menu_Chat:			Gag_ToggleFlags(id, m_Say);
		case menu_TeamChat: 	Gag_ToggleFlags(id, m_SayTeam);
		case menu_VoiceChat:	Gag_ToggleFlags(id, m_Voice);
	}

	if(ca_gag_menu_type == _MenuType_Custom) {
		switch(item) {
			case menu_Reason: {
				Menu_Show_SelectReason(id);

				return PLUGIN_HANDLED;
			}
			case menu_Time:	{
				Menu_Show_SelectTime(id);

				return PLUGIN_HANDLED;
			}
			case menu_Confirm: {
				new time = g_aGags_AdminEditor[id][_Time];
				new flags = g_aGags_AdminEditor[id][_bitFlags];

				SaveGag(id, target, time, flags);

				return PLUGIN_HANDLED;
			}
		}
	} else {
		switch(item) {
			case sequential_Confirm: {
				new time = g_aGags_AdminEditor[id][_Time];
				new flags = g_aGags_AdminEditor[id][_bitFlags];

				SaveGag(id, target, time, flags);

				return PLUGIN_HANDLED;
			}
		}
	}

	Menu_Show_GagProperties(id);

	return PLUGIN_HANDLED;
}

static Menu_Show_SelectReason(id) {
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	new target = g_aGags_AdminEditor[id][_Player];
	if(!is_user_connected(target)) {
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");

		return PLUGIN_HANDLED;
	}

	new hMenu = menu_create(fmt("%L", id, "MENU_SelectReason"), "Menu_Handler_SelectReason");
	menu_additem(hMenu, fmt("%L\n", id, "EnterReason"), "-1");

	if(g_iArraySize_Reasons) {
		for(new i; i < g_iArraySize_Reasons; i++) {
			new aReason[gag_s];
			ArrayGetArray(g_aReasons, i, aReason);

			menu_additem(hMenu,
				fmt("%s (\\y%s\\w)", aReason[_Reason], GetStringTime_seconds(id, aReason[_Time])),
				fmt("%i", i));
			// server_print("ADDMNU[%i]:%s, szInfo(%s)", i, szItemName, szItemInfo);
		}
	} else menu_addtext(hMenu, fmt("\\d		%L", id, "NoHaveReasonsTemplates"), .slot = false);

	menu_setprop(hMenu, MPROP_BACKNAME, fmt("%L", id, "Gag_Menu_Back"));
	menu_setprop(hMenu, MPROP_NEXTNAME, fmt("%L", id, "Gag_Menu_Next"));
	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Exit"));

	return menu_display(id, hMenu);
}

public Menu_Handler_SelectReason(id, menu, item) {
	if(item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		
		if(ca_gag_menu_type == _MenuType_Custom) {
			Menu_Show_GagProperties(id);
		} else if(ca_gag_menu_type == _MenuType_Sequential) {
			Menu_Show_PlayersList(id);
		}
		return PLUGIN_HANDLED;
	}

	new target = g_aGags_AdminEditor[id][_Player];

	if(!is_user_connected(target)) {
		menu_destroy(menu);
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}

	static szItemInfo[3], dummy[1];
	menu_item_getinfo(menu, item, dummy[0], szItemInfo, charsmax(szItemInfo), dummy[0], charsmax(dummy), dummy[0]);

	new iReason = str_to_num(szItemInfo)/*  + 1 */;

	if(iReason == -1) {
		client_cmd(id, "messagemode enter_GagReason");
		menu_display(id, menu);
		return PLUGIN_HANDLED;
	}

	menu_destroy(menu);

	new aReason[gag_s];
	ArrayGetArray(g_aReasons, iReason, aReason);

	// Get predefined reason params
	copy(g_aGags_AdminEditor[id][_Reason], charsmax(g_aGags_AdminEditor[][_Reason]), aReason[_Reason]);
	g_aGags_AdminEditor[id][_bitFlags] = aReason[_bitFlags];
	g_aGags_AdminEditor[id][_Time] = aReason[_Time];

	if(ca_gag_menu_type == _MenuType_Custom) {
		Menu_Show_GagProperties(id);
	} else if(ca_gag_menu_type == _MenuType_Sequential) {
		Menu_Show_SelectTime(id);
	}

	return PLUGIN_HANDLED;
}

static Menu_Show_SelectTime(id) {
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	new target = g_aGags_AdminEditor[id][_Player];
	if(!is_user_connected(target)) {
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}

	new hMenu = menu_create(fmt("%L", id, "MENU_SelectTime"), "Menu_Handler_SelectTime");
	menu_additem(hMenu, fmt("%L", id, "SET_CustomTime"));
	// menu_additem(hMenu, fmt("%L", id, "CA_Gag_Perpapent"));
	menu_addblank(hMenu, .slot = false);

	new iSelectedTime = g_aGags_AdminEditor[id][_Time];

	if(g_iArraySize_GagTimes) {
		for(new i; i < g_iArraySize_GagTimes; i++) {
			new iTime = ArrayGetCell(g_aGagTimes, i) * SECONDS_IN_MINUTE;
			menu_additem(hMenu, fmt("%s%s", (iSelectedTime == iTime) ? "\\r" : "", GetStringTime_seconds(id, iTime)), fmt("%i", iTime));
		}
	} else menu_addtext(hMenu, fmt("\\d		%L", id, "NoHaveTimeTemplates"), .slot = false);

	menu_setprop(hMenu, MPROP_BACKNAME, fmt("%L", id, "Gag_Menu_Back"));
	menu_setprop(hMenu, MPROP_NEXTNAME, fmt("%L", id, "Gag_Menu_Next"));
	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Cancel"));

	return menu_display(id, hMenu);
}

public Menu_Handler_SelectTime(id, menu, item) {
	enum { menu_CustomTime/* , menu_Permament  */};

	if(item == MENU_EXIT || item < 0) {
		menu_destroy(menu);

		if(ca_gag_menu_type == _MenuType_Custom) {
			Menu_Show_GagProperties(id);
		} else if(ca_gag_menu_type == _MenuType_Sequential) {
			Menu_Show_PlayersList(id);
		}

		return PLUGIN_HANDLED;
	}
	
	new target = g_aGags_AdminEditor[id][_Player];
	if(!is_user_connected(target)) {
		menu_destroy(menu);
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}

	switch(item) {
		case menu_CustomTime: {
			menu_destroy(menu);
			client_cmd(id, "messagemode enter_GagTime");

			return PLUGIN_HANDLED;
		}
		/* case menu_Permament: {
			menu_destroy(menu);
			g_aGags_AdminEditor[id][_Time] = GAG_FOREVER;
			Menu_Show_GagProperties(id);

			return PLUGIN_HANDLED;
		} */
	}

	static sInfo[64], dummy[1];
	menu_item_getinfo(menu, item, dummy[0], sInfo, charsmax(sInfo), dummy[0], charsmax(dummy), dummy[0]);
	menu_destroy(menu);

	g_aGags_AdminEditor[id][_Time] = strtol(sInfo);

	if(ca_gag_menu_type == _MenuType_Custom || ca_gag_menu_type == _MenuType_Sequential)
		Menu_Show_GagProperties(id);

	return PLUGIN_HANDLED;
}

public ClCmd_EnterGagReason(id) {
	new target = g_aGags_AdminEditor[id][_Player];
	
	if(!is_user_connected(target))
		return PLUGIN_HANDLED;
	
	static szCustomReason[128];
	read_argv(1, szCustomReason, charsmax(szCustomReason));

	if(!szCustomReason[0])
	{
		Menu_Show_SelectReason(id);
		return PLUGIN_HANDLED;
	}

	copy(g_aGags_AdminEditor[id][_Reason], charsmax(g_aGags_AdminEditor[][_Reason]), szCustomReason);

	client_print(id, print_chat, "%L '%s'", id, "CustomReason_Setted", g_aGags_AdminEditor[id][_Reason]);

	Menu_Show_SelectTime(id);
	return PLUGIN_HANDLED;
}

public ClCmd_EnterGagTime(id) {
	new target = g_aGags_AdminEditor[id][_Player];
	
	if(!is_user_connected(target)) {
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}
	
	static sCustomTime[128];
	read_argv(1, sCustomTime, charsmax(sCustomTime));

	if(!sCustomTime[0]) {
		Menu_Show_SelectTime(id);
		return PLUGIN_HANDLED;
	}
	
	g_aGags_AdminEditor[id][_Time] = strtol(sCustomTime);

	client_print(id, print_chat, "%L '%s'", id, "CustomTime_Setted", GetStringTime_seconds(id, g_aGags_AdminEditor[id][_Time]));
	Menu_Show_GagProperties(id);

	return PLUGIN_HANDLED;
}

Gag_ToggleFlags(id, gag_flags_s: flag) {
	g_aGags_AdminEditor[id][_bitFlags] ^= flag;
}

stock GetStringTime_seconds(const id, const iSeconds) {
	new sTime[32];
	get_time_length(id, iSeconds, timeunit_seconds, sTime, charsmax(sTime));

	if(sTime[0] == EOS)
		formatex(sTime, charsmax(sTime), "%L", id, "CA_Gag_NotSet");

	return sTime;
}

Get_GagStringReason(const id, const target) {
	static sText[MAX_REASON_LEN], len = charsmax(sText);

	if(id != LANG_PLAYER)
		copy(sText, len, g_aGags_AdminEditor[id][_Reason]);
	else copy(sText, len, g_aCurrentGags[target][_Reason]);

	if(sText[0] == EOS)
		formatex(sText, len, "%L", id, "CA_Gag_NotSet");

	return sText;
}


public SrvCmd_AddReason() {
	enum any: args_s { arg0, arg1, arg2, arg3 };

	new szArgs[args_s][256];
	for(new iArg = arg0; iArg < sizeof szArgs; iArg++)
		read_argv(iArg, szArgs[iArg], charsmax(szArgs[]));

	new iArgsCount = read_argc();

	if(iArgsCount < 2){
		CA_Log(_Warnings, "\tUsage: ca_gag_add_reason <reason> [flags] [time in minutes]")
		return;
	}

	new aReason[gag_s];
	copy(aReason[_Reason], charsmax(aReason[_Reason]), szArgs[arg1]);
	aReason[_bitFlags] = gag_flags_s: flags_to_bit(szArgs[arg2]);
	aReason[_Time] = str_to_num(szArgs[arg3]) * SECONDS_IN_MINUTE;
	// num_to_str(str_to_num(szArgs[arg3]) * SECONDS_IN_MINUTE, aReason[_Time], charsmax(aReason[_Time]));
	
	ArrayPushArray(g_aReasons, aReason);
	g_iArraySize_Reasons = ArraySize(g_aReasons);

	CA_Log(_Debug, "ADD: Reason[#%i]: '%s' (Flags:'%s', Time:'%i s.')",\
		g_iArraySize_Reasons, aReason[_Reason], bits_to_flags(aReason[_bitFlags]), aReason[_Time]\
	)
}

public SrvCmd_ShowTemplates() {
	if(/* !g_iArraySize_GagTimes || */ !g_iArraySize_Reasons) {
		CA_Log(_Warnings, "\t[WARN] NO REASONS FOUNDED!")
		return PLUGIN_HANDLED;
	} else {
		for(new i; i < g_iArraySize_Reasons; i++) {
			new aReason[gag_s];
			ArrayGetArray(g_aReasons, i, aReason);

			CA_Log(_Info, "Reason[#%i]: '%s' (Flags:'%s', Time:'%i')",\
				i, aReason[_Reason], bits_to_flags(aReason[_bitFlags]), aReason[_Time]\
			)
		}
	}

	return PLUGIN_HANDLED;
}

public SrvCmd_ReloadConfig() {
	_LoadConfig();
	_ParseTimes();

	CA_Log(_Info, "Config re-loaded!")
}

public Hook_CVar_Times(pcvar, const old_value[], const new_value[]) {
	if(!strlen(new_value)) {
		CA_Log(_Warnings, "[WARN] not found times! ca_gag_add_time ='%s'", new_value)
		return;
	}

	_ParseTimes(new_value);
}

static _LoadConfig() {
	if(!g_aReasons) {
		ArrayCreate(g_aReasons);
	} else if(ArraySize(g_aReasons) > 0) {
		ArrayClear(g_aReasons);
	}

	new sConfigsDir[PLATFORM_MAX_PATH];
	get_configsdir(sConfigsDir, charsmax(sConfigsDir));
	server_cmd("exec %s/ChatAdditions/gag_reasons.cfg", sConfigsDir);
	server_exec();
}

static _ParseTimes(const _sTimes[] = "") {
	new sTimes[128];

	if(sTimes[0] == EOS)
		get_cvar_string("ca_gag_times", sTimes, charsmax(sTimes));
	else copy(sTimes, charsmax(sTimes), _sTimes);

	ArrayClear(g_aGagTimes);

	new ePos, stPos, rawPoint[32];
	do {
		ePos = strfind(sTimes[stPos],",");
		formatex(rawPoint, ePos, sTimes[stPos]);
		stPos += ePos + 1;

		trim(rawPoint);

		if(rawPoint[0])
			ArrayPushCell(g_aGagTimes, strtol(rawPoint));
	} while(ePos != -1);

	g_iArraySize_GagTimes = ArraySize(g_aGagTimes);
}

static SaveGag(const id, const target, const time, const flags) {
	GagData_Copy(g_aCurrentGags[target], g_aGags_AdminEditor[id]);
	GagData_Reset(g_aGags_AdminEditor[id]);
 
	new name[MAX_NAME_LENGTH]; get_user_name(target, name, charsmax(name));
	new authID[MAX_AUTHID_LENGTH]; get_user_authid(target, authID, charsmax(authID));
	new IP[MAX_IP_LENGTH]; get_user_ip(target, IP, charsmax(IP), .without_port = true);
	new reason[256]; copy(reason, charsmax(reason), Get_GagStringReason(LANG_PLAYER, target));

	new adminName[MAX_NAME_LENGTH]; get_user_name(id, adminName, charsmax(adminName));
	new adminAuthID[MAX_AUTHID_LENGTH]; get_user_authid(id, adminAuthID, charsmax(adminAuthID));
	new adminIP[MAX_IP_LENGTH]; get_user_ip(id, adminIP, charsmax(adminIP), .without_port = true);

	new expireAt = time + get_systime();

	CA_Storage_Save(
		name, authID, IP, reason,
		adminName, adminAuthID, adminIP,
		expireAt, flags
	);

	copy(g_aCurrentGags[target][_AdminName], charsmax(g_aCurrentGags[][_AdminName]), adminName);
	copy(g_aCurrentGags[target][_Reason], charsmax(g_aCurrentGags[][_Reason]), reason);
	g_aCurrentGags[target][_ExpireTime] = expireAt;
	g_aCurrentGags[target][_bitFlags] =  gag_flags_s: flags;

	client_cmd(target, "-voicerecord");
}

static RemoveGag(const id, const target) {
	if(g_aGags_AdminEditor[id][_bitFlags] != m_REMOVED) {
		GagData_Reset(g_aGags_AdminEditor[id]);
		GagData_Reset(g_aCurrentGags[target]);

		new authID[MAX_AUTHID_LENGTH]; get_user_authid(target, authID, charsmax(authID));
		CA_Storage_Remove(authID);


		client_print_color(0, print_team_default, "%s %L", MSG_PREFIX,
			LANG_PLAYER, "Player_UnGagged", id, target);
	} else {
		client_print(id, print_chat, "%s %L", MSG_PREFIX, id, "Player_AlreadyRemovedGag", target);
	}

	Menu_Show_PlayersList(id);

	return PLUGIN_HANDLED;
}

static GagExpired(const id) {
	GagData_Reset(g_aCurrentGags[id]);

	client_print_color(0, print_team_default, "%s %L", MSG_PREFIX, LANG_PLAYER, "Player_ExpiredGag", id);
}




	// TODO!
GetPostfix(const id, const target, const bHaveImmunity) {
	static szPostfix[32];

	if(bHaveImmunity)
		formatex(szPostfix, charsmax(szPostfix), " [\\r%L\\d]", id, "Immunity");
	else if(g_aCurrentGags[target][_bitFlags])
		formatex(szPostfix, charsmax(szPostfix), " [\\y%L\\w]", id, "Gag");
	else szPostfix[0] = '\0';

	return szPostfix;
}

public client_putinserver(id) {
	if(is_user_bot(id) || is_user_hltv(id)) {
		return;
	}

	new authID[MAX_AUTHID_LENGTH]; get_user_authid(id, authID, charsmax(authID));
	CA_Storage_Load(authID);
}

public client_disconnected(id) {
	GagData_Reset(g_aCurrentGags[id]);
}
/** <- On Players Events */



public CA_Client_Voice(const listener, const sender) {
	return (g_aCurrentGags[sender][_bitFlags] & m_Voice) ? CA_SUPERCEDE : CA_CONTINUE;
}

public CA_Client_SayTeam(id) {
	return (g_aCurrentGags[id][_bitFlags] & m_SayTeam) ? CA_SUPERCEDE : CA_CONTINUE;
}

public CA_Client_Say(id) {
	return (g_aCurrentGags[id][_bitFlags] & m_Say) ? CA_SUPERCEDE : CA_CONTINUE;
}

/** API -> */
public native_ca_set_user_gag(pPlugin, iParams) {
	enum { Player = 1, Reason, Time, Flags };
	CHECK_NATIVE_ARGS_NUM(iParams, 4, 0)

	new target = get_param(Player);
	CHECK_NATIVE_PLAYER(target, 0)

	static sReason[MAX_REASON_LEN]; get_array(Reason, sReason, sizeof sReason);
	new iTime = get_param(Time) * SECONDS_IN_MINUTE;
	new gag_flags_s: iFlags = gag_flags_s: get_param(Flags);

	GagData_GetPersonalData(0, target, g_aGags_AdminEditor[0]);
	g_aGags_AdminEditor[0][_Player] = 0;
	formatex(g_aGags_AdminEditor[0][_AdminName], charsmax(g_aGags_AdminEditor[][_AdminName]), "SERVER");
	copy(g_aGags_AdminEditor[0][_Reason], charsmax(g_aGags_AdminEditor[][_Reason]), sReason);
	g_aGags_AdminEditor[0][_Time] = iTime;
	g_aGags_AdminEditor[0][_bitFlags] = iFlags;

	// SaveGag(0, target);

	return 0;
}

public native_ca_get_user_gag(pPlugin, iParams) {
	enum { Player = 1, Reason, Time, Flags };
	CHECK_NATIVE_ARGS_NUM(iParams, 4, false)

	new id = get_param(Player);
	CHECK_NATIVE_PLAYER(id, false)

	set_array(Reason, g_aCurrentGags[id][_Reason], charsmax(g_aCurrentGags[][_Reason]));

	set_param_byref(Time, g_aCurrentGags[id][_Time]);
	set_param_byref(Flags, g_aCurrentGags[id][_bitFlags]);

	return (g_aCurrentGags[id][_bitFlags] != m_REMOVED);
}

public native_ca_has_user_gag(pPlugin, iParams) {
	enum { Player = 1 };
	CHECK_NATIVE_ARGS_NUM(iParams, 1, 0)

	new id = get_param(Player);
	CHECK_NATIVE_PLAYER(id, 0)

	return (g_aCurrentGags[id][_bitFlags] != m_REMOVED);
}

public native_ca_remove_user_gag(pPlugin, iParams) {
	/* 	
	enum { Player = 1 };
	CHECK_NATIVE_ARGS_NUM(iParams, 1, false)

	new id = get_param(Player);
	CHECK_NATIVE_PLAYER(id, false)
	*/
}
/** <- API */


/** Storage -> */
public CA_Storage_Initialized( ) {
	// todo
}
public CA_Storage_Saved(const name[], const authID[], const IP[], const reason[],
	const adminName[], const adminAuthID[], const adminIP[],
	const createdAt, const expireAt, const flags) {
	
	new gagTime = expireAt - createdAt;
	new gagTimeStr[32]; copy(gagTimeStr, charsmax(gagTimeStr), GetStringTime_seconds(LANG_PLAYER, gagTime));

	client_print_color(0, print_team_default, "%s %L", MSG_PREFIX,
		LANG_PLAYER, "Player_Gagged", adminName, name, gagTimeStr
	);

	client_print_color(0, print_team_default, "%L '\3%s\1'", LANG_PLAYER, "CA_Gag_Reason", reason);

	CA_Log(_Info, "Gag: \"%s\" add gag to \"%s\" (type:\"%s\") (time:\"%s\") (reason:\"%s\")", \
		adminName, name, bits_to_flags(gag_flags_s: flags), gagTimeStr, reason \
	)	
}
public CA_Storage_Loaded(const name[], const authID[], const IP[], const reason[],
	const adminName[], const adminAuthID[], const adminIP[],
	const createdAt, const expireAt, const flags) {
	
	new target = find_player_ex((FindPlayer_MatchAuthId | FindPlayer_ExcludeBots), authID);
	if(!target) {
		return;
	}

	copy(g_aCurrentGags[target][_AdminName], charsmax(g_aCurrentGags[][_AdminName]), adminName);
	copy(g_aCurrentGags[target][_Reason], charsmax(g_aCurrentGags[][_Reason]), reason);
	g_aCurrentGags[target][_ExpireTime] = expireAt;
	g_aCurrentGags[target][_bitFlags] = gag_flags_s: flags;
}
public CA_Storage_Removed( ) {
	// todo
}
/** <- Storage */
