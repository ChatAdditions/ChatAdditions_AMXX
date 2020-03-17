
// #define DEBUG
// #define CHOOSE_STORAGE [0 .. 2]


#include <amxmodx>
#include <amxmisc>
#include <time>

#include <ChatAdditions>
#include <CA_GAG_API>

#pragma semicolon 1
#pragma ctrlchar '\'
#pragma dynamic 524288


		/* ----- START SETTINGS----- */
new const MSG_PREFIX[] = "\4[GAG]\1";

/**
 *	Database type for storage gags
 *	DB_NVault, DB_MySQL, DB_SQLite, DB_GameCMS
 */
#define DATABASE_TYPE DB_SQLite

#define FLAGS_ACCESS    	( ADMIN_KICK )
#define FLAGS_ADMIN_ACCESS  ( ADMIN_RCON )
#define FLAGS_IMMUNITY    	( ADMIN_IMMUNITY )
		/* ----- END OF SETTINGS----- */


enum any: TIME_CONST_s (+=1) { GAG_REMOVED = -1, GAG_FOREVER = 0 };

new g_aCurrentGags[MAX_PLAYERS + 1][gag_s];
static g_aGags_AdminEditor[MAX_PLAYERS + 1][gag_s];

static Array: g_aReasons, g_iArraySize_Reasons;
static Array: g_aGagTimes, g_iArraySize_GagTimes;

static bool: g_bStorageInitialized;

new const LOG_DIR_NAME[] = "CA_Gag";
new g_sLogsFile[PLATFORM_MAX_PATH];

new ca_log_type,
	LogLevel_s: ca_log_level = _Info;

enum _:GagMenuType_s {
	_MenuType_Custom,
	_MenuType_Sequential
}
new ca_gag_menu_type;

#if (defined DEBUG && defined CHOOSE_STORAGE)
	#undef DATABASE_TYPE
	#define DATABASE_TYPE CHOOSE_STORAGE
#endif

#if (defined DATABASE_TYPE)
	#if (DATABASE_TYPE == DB_NVault || DATABASE_TYPE == 0)
		#include <ChatAdditions_inc/_NVault>
	#elseif (DATABASE_TYPE == DB_MySQL || DATABASE_TYPE == 1)
		#include <ChatAdditions_inc/_MySQL>
	#elseif (DATABASE_TYPE == DB_SQLite || DATABASE_TYPE == 2)
		#include <ChatAdditions_inc/_SQLite>
	#elseif (DATABASE_TYPE == DB_GameCMS || DATABASE_TYPE == 3)
		#include <ChatAdditions_inc/_GameCMS>
	#endif
#else
	#error Please uncomment DATABASE_TYPE and select!
#endif // DATABASE_TYPE

public plugin_precache() {
	register_plugin("[CA] Gag", "1.0.0-beta", "Sergey Shorokhov");

	register_dictionary("CA_Gag.txt");
	register_dictionary("common.txt");
	register_dictionary("time.txt");

	bind_pcvar_num(get_cvar_pointer("ca_log_type"), ca_log_type);
	hook_cvar_change(get_cvar_pointer("ca_log_level"), "Hook_CVar_LogLevel");
	GetLogsFilePath(g_sLogsFile, .sDir = LOG_DIR_NAME);

	hook_cvar_change(
		create_cvar("ca_gag_times", "1, 5, 30, 60, 1440, 10080"),
		"Hook_CVar_Times"
	);

	bind_pcvar_num(create_cvar("ca_gag_menu_type", "1"), ca_gag_menu_type);

	g_aReasons = ArrayCreate(gag_s);
	g_aGagTimes = ArrayCreate();

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

	CA_Log(_Info, "[CA]: Gag initialized!")
}

public Hook_CVar_LogLevel(pcvar, const old_value[], const new_value[]) {
	ca_log_level = ParseLogLevel(new_value);
}

public OnConfigsExecuted() {
	_LoadConfig();
	_ParseTimes();
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

	static iSysTime; iSysTime = get_systime();

	for(new i; i < iCount; i++) {
		new id = aPlayers[i];

		// server_print("GAG TIME LEFT: %n (%i)", id, (g_aCurrentGags[id][_ExpireTime] - iSysTime));
		new iExpireTime = g_aCurrentGags[id][_ExpireTime];
		if(g_aCurrentGags[id][_bitFlags] != m_REMOVED && iExpireTime != GAG_REMOVED
			&& (iExpireTime != GAG_FOREVER && iExpireTime < iSysTime)
		) GagExpired(id);
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

	new aPlayers[MAX_PLAYERS], iCount;
	get_players_ex(aPlayers, iCount, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));
	new flags = get_user_flags(id);

	for(new i; i < iCount; i++) {
		new target = aPlayers[i];

		if(target == id)
			continue;

		new bool: bHaveImmunity = _IsHaveImmunity(flags, get_user_flags(target));
		
		menu_additem(hMenu, fmt("%n %s", target, GetPostfix(id, target, bHaveImmunity)), fmt("%i", get_user_userid(aPlayers[i])), .callback = hCallback);
	}

	menu_setprop(hMenu, MPROP_BACKNAME, fmt("%L", id, "Gag_Menu_Back"));
	menu_setprop(hMenu, MPROP_NEXTNAME, fmt("%L", id, "Gag_Menu_Next"));
	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Exit"));

	menu_display(id, hMenu);
}

public Callback_PlayersMenu(id, menu, item) {
	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), strtol(sInfo));
	new bool: bHaveImmunity = _IsHaveImmunity(flags, get_user_flags(target));

	return (!bHaveImmunity) ? ITEM_ENABLED : ITEM_DISABLED;
}

public Menu_Handler_PlayersList(id, menu, item) {
	if(item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), strtol(sInfo));

	if(!is_user_connected(target)) {
		menu_destroy(menu);
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

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

// Confirm remove gag
static Menu_Show_ConfirmRemove(id) {
	if(!is_user_connected(id))
		return;

	new hMenu = menu_create(fmt("%L", id, "GAG_Confirm"), "Menu_Handler_ConfirmRemove");

	menu_additem(hMenu, fmt("%L", id, "CA_GAG_YES"));
	menu_additem(hMenu, fmt("%L", id, "CA_GAG_NO"));

	menu_display(id, hMenu);
}

public Menu_Handler_ConfirmRemove(id, menu, item) {
	enum { menu_Yes, menu_No };

	new target = g_aGags_AdminEditor[id][_Player];
	if(!is_user_connected(target)) {
		menu_destroy(menu);
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");
		Menu_Show_PlayersList(id);
		
		return PLUGIN_HANDLED;
	}

	if(item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		ResetTargetData(id);
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

	menu_destroy(menu);
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

		menu_additem(hMenu, fmt("%L [ \\y%s\\w ]", id, "CA_Gag_Reason",
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

	menu_setprop(hMenu, MPROP_BACKNAME, fmt("%L", id, "Gag_Menu_Back"));
	menu_setprop(hMenu, MPROP_NEXTNAME  , fmt("%L", id, "Gag_Menu_Next"));
	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Exit"));

	menu_display(id, hMenu);
}

public Callback_GagProperties(id, menu, item) {
	enum { /* menu_Chat, menu_TeamChat, menu_VoiceChat, */
			menu_Reason = 3, /* menu_Time, */ menu_Confirm = 5
		};

	enum { sequential_Confirm = 3};

	new bool: IsConfirmItem = (
		item == menu_Confirm && ca_gag_menu_type == _MenuType_Custom
		|| item == sequential_Confirm && ca_gag_menu_type == _MenuType_Sequential
	);

	return (
		IsConfirmItem && !Ready_To_Gag(id)
		|| (DATABASE_TYPE == DB_NVault && item == menu_Reason && ca_gag_menu_type == _MenuType_Custom)
		) ? ITEM_DISABLED : ITEM_ENABLED;
}

public Menu_Handler_GagProperties(id, menu, item) {
	enum { menu_Chat, menu_TeamChat, menu_VoiceChat,
			menu_Reason, menu_Time, menu_Confirm
		};

	enum { sequential_Confirm = 3 };

	if(item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		ResetTargetData(id);
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}

	new target = g_aGags_AdminEditor[id][_Player];
	if(!is_user_connected(target)) {
		menu_destroy(menu);
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
				menu_destroy(menu);
				Menu_Show_SelectReason(id);

				return PLUGIN_HANDLED;
			}
			case menu_Time:	{
				menu_destroy(menu);
				Menu_Show_SelectTime(id);

				return PLUGIN_HANDLED;
			}
			case menu_Confirm: {
				menu_destroy(menu);
				SaveGag(id ,target);

				return PLUGIN_HANDLED;
			}
		}
	} else {
		switch(item) {
			case sequential_Confirm: {
				menu_destroy(menu);
				SaveGag(id ,target);

				return PLUGIN_HANDLED;
			}
		}
	}

	menu_destroy(menu);
	Menu_Show_GagProperties(id);

	return PLUGIN_HANDLED;
}

stock bool: Ready_To_Gag(id)  {	
	return (g_aGags_AdminEditor[id][_bitFlags] != m_REMOVED ) ? true : false;
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
	menu_additem(hMenu, fmt("%L", id, "EnterReason"), "-1");

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
	menu_setprop(hMenu, MPROP_NEXTNAME  , fmt("%L", id, "Gag_Menu_Next"));
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
		return PLUGIN_HANDLED;
	}

	new aReason[gag_s];
	ArrayGetArray(g_aReasons, iReason, aReason);

	copy(g_aGags_AdminEditor[id][_Reason], charsmax(g_aGags_AdminEditor[][_Reason]), aReason[_Reason]);

	// IF NEED OFC
	g_aGags_AdminEditor[id][_Time] = aReason[_Time];

	// CA_Log("aReason[_Time]=%i, aReason[_Reason]=%s", aReason[_Time], aReason[_Reason])

	menu_destroy(menu);

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
	menu_additem(hMenu, fmt("%L", id, "CA_Gag_Perpapent"));
	menu_addblank(hMenu, .slot = false);

	new iSelectedTime = g_aGags_AdminEditor[id][_Time];

	if(g_iArraySize_GagTimes) {
		for(new i; i < g_iArraySize_GagTimes; i++) {
			new iTime = ArrayGetCell(g_aGagTimes, i) * SECONDS_IN_MINUTE;
			menu_additem(hMenu, fmt("%s%s", (iSelectedTime == iTime) ? "\\r" : "", GetStringTime_seconds(id, iTime)), fmt("%i", iTime));
		}
	} else menu_addtext(hMenu, fmt("\\d		%L", id, "NoHaveTimeTemplates"), .slot = false);

	menu_setprop(hMenu, MPROP_BACKNAME, fmt("%L", id, "Gag_Menu_Back"));
	menu_setprop(hMenu, MPROP_NEXTNAME  , fmt("%L", id, "Gag_Menu_Next"));
	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Exit"));

	return menu_display(id, hMenu);
}

public Menu_Handler_SelectTime(id, menu, item) {
	enum { menu_CustomTime, menu_Permament };

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
		case menu_Permament: {
			menu_destroy(menu);
			g_aGags_AdminEditor[id][_Time] = GAG_FOREVER;
			Menu_Show_GagProperties(id);

			return PLUGIN_HANDLED;
		}
	}

	static sInfo[64], dummy[1];
	menu_item_getinfo(menu, item, dummy[0], sInfo, charsmax(sInfo), dummy[0], charsmax(dummy), dummy[0]);

	g_aGags_AdminEditor[id][_Time] = strtol(sInfo);

	menu_destroy(menu);

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

	if(iSeconds == GAG_FOREVER)
		formatex(sTime, charsmax(sTime), "%L", id, "CA_Gag_Perpapent");

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

	new szArgs[args_s][32];
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

	CA_Log(_Warnings, "ADD: Reason[#%i]: '%s' (Flags:'%s', Time:'%i s.')",\
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

			CA_Log(_Warnings, "Reason[#%i]: '%s' (Flags:'%s', Time:'%i')",\
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
	ArrayClear(g_aReasons);
	new sConfigsDir[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", sConfigsDir, charsmax(sConfigsDir));
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

static SaveGag(const id, const target) {
	GagData_Copy(g_aCurrentGags[target], g_aGags_AdminEditor[id]);

	if(id == 0) {
		client_print_color(0, print_team_default, "%s %L", MSG_PREFIX,
			LANG_PLAYER, "Player_Gagged_ByServer", target, GetStringTime_seconds(LANG_PLAYER, g_aCurrentGags[target][_Time]));

		CA_Log(_Info, "Gag: \"SERVER\" add gag to \"%N\" (type:\"%s\") (time:\"%s\") (reason:\"%s\")", \
        	target, bits_to_flags(g_aCurrentGags[target][_bitFlags]), \
			GetStringTime_seconds(LANG_SERVER, g_aCurrentGags[target][_Time]), \
			g_aCurrentGags[target][_Reason] \
    	)
	} else {
		client_print_color(0, print_team_default, "%s %L", MSG_PREFIX,
			LANG_PLAYER, "Player_Gagged", id, target, GetStringTime_seconds(LANG_PLAYER, g_aCurrentGags[target][_Time]));

		CA_Log(_Info, "Gag: \"%N\" add gag to \"%N\" (type:\"%s\") (time:\"%s\") (reason:\"%s\")", \
        	id, target, bits_to_flags(g_aCurrentGags[target][_bitFlags]), \
			GetStringTime_seconds(LANG_SERVER, g_aCurrentGags[target][_Time]), \
			g_aCurrentGags[target][_Reason] \
    	)
	}
	if(g_aCurrentGags[target][_Reason][0])
		client_print_color(0, print_team_default, "%L '\3%s\1'", LANG_PLAYER, "CA_Gag_Reason", Get_GagStringReason(LANG_PLAYER, target));

	if(g_aCurrentGags[target][_Time] == GAG_FOREVER)
		g_aCurrentGags[target][_ExpireTime] = GAG_FOREVER;
	else g_aCurrentGags[target][_ExpireTime] = get_systime() + g_aCurrentGags[target][_Time];
  
	GagData_Reset(g_aGags_AdminEditor[id]);
	
	client_cmd(target, "-voicerecord");

	save_to_storage(g_aCurrentGags[target]);

	return PLUGIN_CONTINUE;
}

static RemoveGag(const id, const target) {
	if(g_aGags_AdminEditor[id][_bitFlags] != m_REMOVED) {
		ResetTargetData(id);

		g_aCurrentGags[target][_ExpireTime] = GAG_REMOVED;
		remove_from_storage(g_aCurrentGags[id]);

		GagData_Reset(g_aCurrentGags[target]);
		client_print_color(0, print_team_default, "%L",
			LANG_PLAYER, "Player_UnGagged", id, target);
	} else {
		client_print(id, print_chat, "%s %L", MSG_PREFIX, id, "Player_AlreadyRemovedGag", target);
	}

	Menu_Show_PlayersList(id);

	return PLUGIN_HANDLED;
}

static GagExpired(const id) {
	g_aCurrentGags[id][_bitFlags] = m_REMOVED;

	remove_from_storage(g_aCurrentGags[id]);

	client_print_color(0, print_team_default, "%s %L",MSG_PREFIX, LANG_PLAYER, "Player_ExpiredGag", id);
}

static LoadGag(const target) {
	new aGagData[gag_s]; {
		GagData_GetPersonalData(0, target, aGagData);
	}

	load_from_storage(aGagData);
}

stock ResetTargetData(const id) {
	GagData_Reset(g_aGags_AdminEditor[id]);
}

	// TODO!
GetPostfix(const id, const target, const bHaveImmunity) {
	static szPostfix[32];

	if(bHaveImmunity)
		formatex(szPostfix, charsmax(szPostfix), " [\\r%L]", id, "Immunity");
	else if(g_aCurrentGags[target][_bitFlags])
		formatex(szPostfix, charsmax(szPostfix), " [\\y%L\\w]", id, "Gag");
	else szPostfix[0] = '\0';

	return szPostfix;
}


stock bool: _IsHaveImmunity(id_flags, target_flags) {
	if(id_flags & FLAGS_ADMIN_ACCESS)
		return false;
	
	if(target_flags & FLAGS_ADMIN_ACCESS)
		return true;
	
	if(target_flags & FLAGS_IMMUNITY)
		return true;
	
	return false;
}

public client_putinserver(id) {
	if(!g_bStorageInitialized)
		return;

	LoadGag(id);
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

	SaveGag(0, target);

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

public DB_Types: native_ca_get_storage_type(pPlugin, iParams) {
	return DB_Types:DATABASE_TYPE;
}
/** <- API */


// Storage
Storage_Inited(Float: fTime) {
	g_bStorageInitialized = true;
	server_print("[%s] Storage initialized! (%.4f sec)", DB_Names[DATABASE_TYPE], fTime);
}

Storage_PlayerSaved(const iUserID) {
	new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), iUserID);

	server_print("[%s] Target [%s] SAVED!", DB_Names[DATABASE_TYPE],
		is_user_connected(target) ?
			fmt("%n (UsedID:%i)", target, iUserID) :
			fmt("UsedID:%i", iUserID)
	);
}

Storage_PlayerLoaded(const iUserID, bool: bFound = false) {
	new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), iUserID);
	GagData_GetPersonalData(0, target, g_aCurrentGags[target]);

	if(!bFound)
		return;

#if defined DEBUG
	server_print("[%s] Target [%s] Loaded! (gag found)", DB_Names[DATABASE_TYPE],
		is_user_connected(target) ?
			fmt("%n (UsedID:%i)", target, iUserID) :
			fmt("UsedID:%i", iUserID)
	);
#endif
}

Storage_PlayerRemoved(const iUserID) {
#pragma unused iUserID
#if defined DEBUG
	new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), iUserID);

	server_print("[%s] Target [%s] removed!", DB_Names[DATABASE_TYPE],
		is_user_connected(target) ?
			fmt("%n (UsedID:%i)", target, iUserID) :
			fmt("UsedID:%i", iUserID)
	);
#endif
}