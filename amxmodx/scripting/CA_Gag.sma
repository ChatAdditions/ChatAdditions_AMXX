
// #define DEBUG
// #define CHOOSE_STORAGE [0 .. 3]


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
 *		DB_NVault,
 *		DB_JSON,  // TODO: 
 *		DB_MySQL,
 *		DB_SQLite
 */
#define DATABASE_TYPE DB_SQLite

#define FLAGS_ACCESS    ( ADMIN_KICK )
#define FLAGS_IMMUNITY    ( ADMIN_IMMUNITY )
		/* ----- END OF SETTINGS----- */


enum any: TIME_CONST_s (+=1) { FOREVER = -1 };

new g_aCurrentGags[MAX_PLAYERS + 1][gag_s];
static g_aGags_AdminEditor[MAX_PLAYERS + 1][gag_s];

static Array: g_aReasons, g_iArraySize_Reasons;
static Array: g_aGagTimes, g_iArraySize_GagTimes;

#if defined DEBUG && defined CHOOSE_STORAGE
	#undef DATABASE_TYPE
	#define DATABASE_TYPE CHOOSE_STORAGE
#endif

#if defined DATABASE_TYPE
	#if DATABASE_TYPE == DB_NVault
		#include <ChatAdditions_inc/_NVault>
	#elseif DATABASE_TYPE == DB_JSON
		// #include <ChatAdditions_inc/_JSON>
	#elseif DATABASE_TYPE == DB_MySQL
		#include <ChatAdditions_inc/_MySQL>
	#elseif DATABASE_TYPE == DB_SQLite
		#include <ChatAdditions_inc/_SQLite>
	#endif
#else // DATABASE_TYPE
	#error Please uncomment DATABASE_TYPE and select!
#endif // DATABASE_TYPE

static bool: g_bStorageInitialized;

public plugin_precache() {
	register_plugin("[CA] Gag", "1.0.0-beta", "Sergey Shorokhov");

	register_dictionary("CA_Gag.txt");
	register_dictionary("common.txt");
	register_dictionary("time.txt");


	hook_cvar_change(
		create_cvar("ca_gag_times", "1, 5, 30, 60, 1440, 10080"),
		"Hook_CVar_Times"
	);

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

public OnConfigsExecuted() {
	_LoadConfig();
	_ParseTimes();
}

public plugin_natives() {
	register_library("ChatAdditions_GAG_API");

	// TODO: Need CRUD
	register_native("ca_set_user_gag", "native_ca_set_user_gag");
	register_native("ca_get_user_gag", "native_ca_get_user_gag");
	register_native("ca_has_user_gag", "native_ca_has_user_gag");
	// register_native("ca_update_user_gag", "native_ca_update_user_gag");
	register_native("ca_remove_user_gag", "native_ca_remove_user_gag");

	// TODO: Create forwards: gagged, ungagged, loaded from storage, saved to storage
}

public Gags_Thinker() {
	static aPlayers[MAX_PLAYERS], iCount;
	get_players_ex(aPlayers, iCount, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));

	static iSysTime; iSysTime = get_systime();

	for(new i; i < iCount; i++) {
		new id = aPlayers[i];

		// server_print("GAG TIME LEFT: %n (%i)", id, (g_aCurrentGags[id][_ExpireTime] - iSysTime));
		if(g_aCurrentGags[id][_bitFlags] != m_REMOVED && g_aCurrentGags[id][_ExpireTime] < iSysTime)
			GagExpired(id);
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

	new aPlayers[MAX_PLAYERS], iCount;
	get_players(aPlayers, iCount, .flags = "ch");

	new hCallback = menu_makecallback("Callback_PlayersMenu");

	for(new i; i < iCount; i++) {
		if(id != aPlayers[i])
			menu_additem(hMenu, "-", fmt("%i", get_user_userid(aPlayers[i])), .callback = hCallback);
	}

	menu_setprop(hMenu, MPROP_BACKNAME, fmt("%L", id, "Gag_Menu_Back"));
	menu_setprop(hMenu, MPROP_NEXTNAME  , fmt("%L", id, "Gag_Menu_Next"));
	menu_setprop(hMenu, MPROP_EXITNAME, fmt("%L", id, "Gag_Menu_Exit"));

	menu_display(id, hMenu);
}

public Callback_PlayersMenu(id, menu, item) {
	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), strtol(sInfo));
	new bool:bHaveImmunity = !!(get_user_flags(target) & FLAGS_IMMUNITY);

	menu_item_setname(menu, item, fmt("%n %s", target, GetPostfix(id, target, bHaveImmunity)));

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
	}else {
		GagData_GetPersonalData(id, target, g_aGags_AdminEditor[id]);

		Menu_Show_GagProperties(id);
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
	new hCallback = menu_makecallback("Callback_GagProperties");

	menu_additem(hMenu, "Chat:", .callback = hCallback);
	menu_additem(hMenu, "Team chat:", .callback = hCallback);
	menu_additem(hMenu, "Voice chat:", .callback = hCallback);
	menu_addblank(hMenu, false);
	menu_additem(hMenu, "Reason:", .callback = hCallback);
	menu_additem(hMenu, "Time:", .callback = hCallback);
	menu_addblank(hMenu, false);
	menu_additem(hMenu, "Confirm!", .callback = hCallback);

	menu_display(id, hMenu);
}

public Callback_GagProperties(id, menu, item) {
	enum { menu_Chat, menu_TeamChat, menu_VoiceChat,
			menu_Reason, menu_Time, menu_Confirm
		};

	new gag_flags_s: gagFlags = g_aGags_AdminEditor[id][_bitFlags];
	new target = g_aGags_AdminEditor[id][_Player];
	new bool: hasAlreadyGag = g_aCurrentGags[target][_bitFlags] != m_REMOVED;
	new bool: hasChanges = !GagData_Equal(g_aCurrentGags[target], g_aGags_AdminEditor[id]);

	// DEBUG__Dump_GagData("Callback_GagProperties", g_aGags_AdminEditor[id]);

	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	switch(item) {
		case menu_Chat:
			formatex(sName, charsmax(sName), "%L [ %s ]", id, "CA_Gag_Say", (gagFlags & m_Say) ? " \\r+\\w " : "-");
		case menu_TeamChat:
			formatex(sName, charsmax(sName), "%L [ %s ]", id, "CA_Gag_SayTeam", (gagFlags & m_SayTeam) ? " \\r+\\w " : "-");
		case menu_VoiceChat:
			formatex(sName, charsmax(sName), "%L [ %s ]", id, "CA_Gag_Voice", (gagFlags & m_Voice) ? " \\r+\\w " : "-");
		case menu_Reason:
			formatex(sName, charsmax(sName), "%L [ \\y%s\\w ]", id, "CA_Gag_Reason", Get_GagStringReason(id, target));
		case menu_Time:
			formatex(sName, charsmax(sName), "%L [ \\y%s\\w ]", id, "CA_Gag_Time", GetStringTime_seconds(id, g_aGags_AdminEditor[id][_Time]));
		case menu_Confirm: {
			formatex(sName, charsmax(sName), "%L %s", id, "CA_Gag_Confirm", (hasAlreadyGag && hasChanges) ? "edit" : "");
		}
	}

	menu_item_setname(menu, item, sName);

	return (
		item == menu_Confirm && !Ready_To_Gag(id)
		|| DATABASE_TYPE == DB_NVault && item == menu_Reason
		) ? ITEM_DISABLED : ITEM_ENABLED;
}

public Menu_Handler_GagProperties(id, menu, item) {	
	enum { menu_Chat, menu_TeamChat, menu_VoiceChat,
			menu_Reason, menu_Time, menu_Confirm
		};

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
		case menu_Reason: {
			menu_destroy(menu);
			Menu_Show_SelectReason(id, target);

			return PLUGIN_HANDLED;
		}
		case menu_Time:	{
			menu_destroy(menu);
			Menu_Show_SelectTime(id, target);

			return PLUGIN_HANDLED;
		}
		case menu_Confirm: {
			menu_destroy(menu);
			SaveGag(id ,target);

			return PLUGIN_HANDLED;
		}
	}

	menu_destroy(menu);
	Menu_Show_GagProperties(id);

	return PLUGIN_HANDLED;
}

stock bool: Ready_To_Gag(id)  {	
	return (g_aGags_AdminEditor[id][_bitFlags] != m_REMOVED ) ? true : false;
}


static Menu_Show_SelectReason(id, target) {
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

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
		Menu_Show_GagProperties(id);
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

	// log_amx("aReason[_Time]=%i, aReason[_Reason]=%s", aReason[_Time], aReason[_Reason]);

	menu_destroy(menu);
	Menu_Show_GagProperties(id);

	return PLUGIN_HANDLED;
}

static Menu_Show_SelectTime(id, target) {
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	if(!is_user_connected(target)) {
		client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected");
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}

	new hMenu = menu_create(fmt("%L", id, "MENU_SelectTime"), "Menu_Handler_SelectTime");
	menu_additem(hMenu, fmt("%L", id, "SET_CustomTime"));
	menu_additem(hMenu, fmt("%L", id, "CA_Gag_Perpapent"));
	menu_addblank(hMenu, .slot = false);

	if(g_iArraySize_GagTimes) {
		for(new i; i < g_iArraySize_GagTimes; i++) {
			new iTime = ArrayGetCell(g_aGagTimes, i) * SECONDS_IN_MINUTE;

			menu_additem(hMenu, GetStringTime_seconds(id, iTime), fmt("%i", iTime));
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
		Menu_Show_GagProperties(id);
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
			g_aGags_AdminEditor[id][_Time] = FOREVER;
			Menu_Show_GagProperties(id);

			return PLUGIN_HANDLED;
		}
	}

	static sInfo[64], dummy[1];
	menu_item_getinfo(menu, item, dummy[0], sInfo, charsmax(sInfo), dummy[0], charsmax(dummy), dummy[0]);

	g_aGags_AdminEditor[id][_Time] = strtol(sInfo);

	menu_destroy(menu);
	Menu_Show_GagProperties(id);
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
		Menu_Show_SelectTime(id, target);
		return PLUGIN_HANDLED;
	}
	
	g_aGags_AdminEditor[id][_Time] = strtol(sCustomTime);

	client_print(id, print_chat, "%L '%s'", id, "CustomTime_Setted", GetStringTime_seconds(id, g_aGags_AdminEditor[id][_Time]));
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
		Menu_Show_SelectReason(id, target);
		return PLUGIN_HANDLED;
	}

	copy(g_aGags_AdminEditor[id][_Reason], charsmax(g_aGags_AdminEditor[][_Reason]), szCustomReason);

	client_print(id, print_chat, "%L '%s'", id, "CustomReason_Setted", g_aGags_AdminEditor[id][_Reason]);
	Menu_Show_GagProperties(id);
	return PLUGIN_HANDLED;
}

Gag_ToggleFlags(id, gag_flags_s: flag) {
	g_aGags_AdminEditor[id][_bitFlags] ^= flag;
}

stock GetStringTime_seconds(const id, const iSeconds) {
	new sTime[32];
	get_time_length(id, iSeconds, timeunit_seconds, sTime, charsmax(sTime));

	if(iSeconds == FOREVER)
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
		log_amx("\tUsage: ca_gag_add_reason <reason> [flags] [time in minutes]");
		return;
	}

	new aReason[gag_s];
	copy(aReason[_Reason], charsmax(aReason[_Reason]), szArgs[arg1]);
	aReason[_bitFlags] = gag_flags_s: flags_to_bit(szArgs[arg2]);
	aReason[_Time] = str_to_num(szArgs[arg3]) * SECONDS_IN_MINUTE;
	// num_to_str(str_to_num(szArgs[arg3]) * SECONDS_IN_MINUTE, aReason[_Time], charsmax(aReason[_Time]));
	
	ArrayPushArray(g_aReasons, aReason);
	g_iArraySize_Reasons = ArraySize(g_aReasons);

	log_amx("ADD: Reason[#%i]: '%s' (Flags:'%s', Time:'%i s.')",
			g_iArraySize_Reasons, aReason[_Reason], bits_to_flags(aReason[_bitFlags]), aReason[_Time]
		);
}

public SrvCmd_ShowTemplates() {
	if(/* !g_iArraySize_GagTimes || */ !g_iArraySize_Reasons) {
		log_amx("\t[WARN] NO REASONS FOUNDED!");
		return PLUGIN_HANDLED;
	} else {
		for(new i; i < g_iArraySize_Reasons; i++) {
			new aReason[gag_s];
			ArrayGetArray(g_aReasons, i, aReason);

			server_print("Reason[#%i]: '%s' (Flags:'%s', Time:'%i')",
				i, aReason[_Reason], bits_to_flags(aReason[_bitFlags]), aReason[_Time]
			);
		}
	}

	return PLUGIN_HANDLED;
}

public SrvCmd_ReloadConfig() {
	_LoadConfig();
	_ParseTimes();

	log_amx("Config re-loaded!");
}

public Hook_CVar_Times(pcvar, const old_value[], const new_value[]) {
	if(!strlen(new_value)) {
		log_amx("[WARN] not found times! ca_gag_add_time ='%s'", new_value);
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
	} else {
		client_print_color(0, print_team_default, "%s %L", MSG_PREFIX,
			LANG_PLAYER, "Player_Gagged", id, target, GetStringTime_seconds(LANG_PLAYER, g_aCurrentGags[target][_Time]));
	}
	if(g_aCurrentGags[target][_Reason][0])
		client_print_color(0, print_team_default, "\4%L '\3%s\1'", LANG_PLAYER, "CA_Gag_Reason", Get_GagStringReason(LANG_PLAYER, target));

	if(g_aCurrentGags[target][_Time] == FOREVER)
		g_aCurrentGags[target][_ExpireTime] = FOREVER;
	else g_aCurrentGags[target][_ExpireTime] = get_systime() + g_aCurrentGags[target][_Time];

	GagData_Reset(g_aGags_AdminEditor[id]);
	
	client_cmd(target, "-voicerecord");

	save_to_storage(g_aCurrentGags[target]);

	return PLUGIN_CONTINUE;
}

static RemoveGag(const id, const target) {
	if(g_aGags_AdminEditor[id][_bitFlags] != m_REMOVED) {
		ResetTargetData(id);

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