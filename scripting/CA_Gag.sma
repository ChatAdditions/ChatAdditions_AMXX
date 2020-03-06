/* // CRUD - Create, Read, Update, Delete
static add_user_gag(const id, const aGagData[gag_s]) {
    // Готовый набор параметров гага передаём в БД.
}
static get_user_gag(const id, aGagData[gag_s]) {
    // Получаем из БД готовый набор гагов.
}
static update_user_gag(const id, aGagData[gag_s]) {
    // Обновляем на сервере и в БД параметры гага.
}
static remove_user_gag(const id, aGagData[gag_s]) {
    // Удаляем с сервера и БД гаг.
}

 */



#include <amxmodx>
#include <amxmisc>
#include <time>

#include <ChatsAdditions>
#include <CA_GAG_API>

#pragma semicolon 1
#pragma ctrlchar '\'
#pragma dynamic 524288


		/* ----- START SETTINGS----- */
#define DEBUG

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

#if DATABASE_TYPE == DB_NVault
	#include <ChatAdditions_inc/CA_NVault>
#elseif DATABASE_TYPE == DB_JSON
	// #include <ChatAdditions_inc/CA_JSON>
#elseif DATABASE_TYPE == DB_MySQL
	#include <ChatAdditions_inc/CA_MySQL>
#elseif DATABASE_TYPE == DB_SQLite
	#include <ChatAdditions_inc/CA_SQLite>
#endif

#if !defined DATABASE_TYPE
	#error Please uncomment DATABASE_TYPE and select!
#endif

/** Time settings */
enum any: TIME_CONST_s (+=1) { CUSTOMTIME = -10, FOREVER = 0 };
new const g_aTimes[] = {
	// CUSTOMTIME,
	1,
	5,
	30,
	60,
	1440,
	10080,
	FOREVER
};

new any: g_aCurrentGags[MAX_PLAYERS + 1][gag_s];
new g_PlayersGags[MAX_PLAYERS + 1][gag_s];

new g_aAdminGagsEditor[MAX_PLAYERS + 1][gag_s];

new Array: g_aReasons, g_iArraySize_Reasons;

new g_pMenu_GagProperties, g_pMenu_ConfirmRemove;


public plugin_precache() {
	register_plugin("[CA] Gag", "1.0.0-alpha", "Sergey Shorokhov");

	register_dictionary("CA_Gag.txt");
	register_dictionary("common.txt");
	register_dictionary("time.txt");

	register_srvcmd("ca_gag_add_reason", "SrvCmd_AddReason");
	register_srvcmd("ca_gag_show_templates", "SrvCmd_ShowTemplates"); // debug

	new sConfigsDir[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", sConfigsDir, charsmax(sConfigsDir));
    server_cmd("exec %s/gag_reasons.cfg", sConfigsDir);
    server_exec();

	g_pMenu_GagProperties = BuildMenu_GagProperties();
	g_pMenu_ConfirmRemove = BuildMenu_ConfirmRemove();
	
	new const szCmd[] = "gag";
	new const szCtrlChar[][] = {"!", "/", "\\", "." , "?", ""};
	for(new i; i < sizeof(szCtrlChar); i++) {
		register_clcmd(fmt("%s%s", szCtrlChar[i], szCmd), "ClCmd_Gag", FLAGS_ACCESS);
		register_clcmd(fmt("say %s%s", szCtrlChar[i], szCmd), "ClCmd_Gag", FLAGS_ACCESS);
		register_clcmd(fmt("say_team %s%s", szCtrlChar[i], szCmd), "ClCmd_Gag", FLAGS_ACCESS);
	}

	register_clcmd("enter_GagReason", "ClCmd_EnterGagReason");

	const Float: UPDATER_FREQ = 3.0;
	set_task(UPDATER_FREQ, "Gags_Thinker", .flags = "b");
}

public plugin_natives() {
	register_library("ChatAdditions_GAG_API");

	// TODO: Need CRUD
	register_native("ca_set_user_gag", "native_ca_set_user_gag");
	register_native("ca_get_user_gag", "native_ca_get_user_gag");
	// register_native("ca_update_user_gag", "native_ca_update_user_gag");
	register_native("ca_remove_user_gag", "native_ca_remove_user_gag");

	// TODO: Create forwards: gagged, ungagged, loaded from storage, saved to storage
}

public Gags_Thinker()
{
	static aPlayers[MAX_PLAYERS], iCount;
	get_players_ex(aPlayers, iCount, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));

	for(new i; i < iCount; i++)
		check_user_gag(aPlayersId[i]);
}

//
public ClCmd_Gag(pPlayer, level, cid) {
#if !defined DEBUG
	if(!cmd_access(pPlayer, level, cid, 1))
		return PLUGIN_HANDLED;
#endif

	if(get_playersnum() < 2)
	{
		client_print_color(pPlayer, print_team_default, "\3Не достаточно игроков, что бы открыть меню Gag'ов!");
		return PLUGIN_HANDLED;
	}

	Menu_Show_PlayersList(pPlayer);
	return PLUGIN_HANDLED;
}


// Players menu
public Menu_Show_PlayersList(pPlayer)
{
	new pMenu = menu_create("Choose player to gag", "Menu_Handler_PlayersList");

	new aPlayers[MAX_PLAYERS], iCount;
	get_players(aPlayers, iCount, .flags = "ch");

	new hCallback = menu_makecallback("Callback_PlayersMenu");

	for(new i; i < iCount; i++) {
		if(pPlayer != aPlayers[i])
			menu_additem(pMenu, "-", fmt("%i", get_user_userid(aPlayers[i])), .callback = hCallback);
	}
	menu_display(pPlayer, pMenu);
}

public Callback_PlayersMenu(id, menu, item)
{
	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new pPlayer = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), strtol(sInfo));
	new bool:bHaveImmunity = !!(get_user_flags(pPlayer) & FLAGS_IMMUNITY);

	menu_item_setname(menu, item, fmt("%n %s", pPlayer, GetPostfix(pPlayer, bHaveImmunity)));

	return (id != pPlayer && !bHaveImmunity) ? ITEM_ENABLED : ITEM_DISABLED;
}

public Menu_Handler_PlayersList(id, menu, item)
{
	if(item == MENU_EXIT || item < 0)
		return PLUGIN_HANDLED;

	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new pOther = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), strtol(sInfo));

	if(!is_user_connected(pOther)) {
		client_print_color(id, print_team_red, "Player not connected!");
		return PLUGIN_HANDLED;
	}

	menu_display(id, (g_aCurrentGags[pOther][_bitFlags] != m_REMOVED) ? g_pMenu_ConfirmRemove : g_pMenu_GagProperties);

	g_iSelectedPlayer[id] = pOther;

	return PLUGIN_HANDLED;
}

	// TODO!
GetPostfix(pPlayer, bHaveImmunity)
{
	static szPostfix[32];

	if(bHaveImmunity)
		formatex(szPostfix, charsmax(szPostfix), " [\\r*]");
	else if(g_aCurrentGags[pPlayer][_bitFlags])
		formatex(szPostfix, charsmax(szPostfix), " [\\yGagged\\w]");
	else szPostfix[0] = '\0';

	return szPostfix;
}

// Confirm remove gag
BuildMenu_ConfirmRemove()
{
	new pMenu = menu_create("Confirm remove:", "Menu_Handler_ConfirmRemove");
	new hCallback = menu_makecallback("Callback_ConfirmRemove");

	menu_additem(pMenu, "Yes", .callback = hCallback);

	return pMenu;
}

public Callback_ConfirmRemove(id, menu, item)
{
	enum { menu_Yes };
	
	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	switch(item) {
		case menu_Yes:
			formatex(sName, charsmax(sName), "\\y%L", id, "CA_GAG_YES");
	}

	menu_item_setname(menu, item, sName);

	return ITEM_ENABLED;
}


public Menu_Handler_ConfirmRemove(id, menu, item)
{
	enum { menu_Yes };

	new pOther = g_iSelectedPlayer[id];
	if(!is_user_connected(pOther)) {
		client_print_color(id, print_team_red, "Player not connected!");
		Menu_Show_PlayersList(id);
		
		return PLUGIN_HANDLED;
	}

	if(item == MENU_EXIT || item < 0) {
		ResetOtherData(pOther);
		Menu_Show_PlayersList(id);

		return PLUGIN_HANDLED;
	}
	
	switch(item) {
		case menu_Yes: {
			RemoveGag(id, pOther);
		}
	}

	Menu_Show_PlayersList(id);

	return PLUGIN_HANDLED;
}

// Gag Properties menu
BuildMenu_GagProperties()
{
	new pMenu = menu_create("Gag properties:", "Menu_Handler_GagProperties");
	new hCallback = menu_makecallback("Callback_GagProperties");

	menu_additem(pMenu, "Chat:", .callback = hCallback);
	menu_additem(pMenu, "Team chat:", .callback = hCallback);
	menu_additem(pMenu, "Voice chat:", .callback = hCallback);
	menu_addblank(pMenu, false);
	menu_additem(pMenu, "Reason:", .callback = hCallback);
	menu_additem(pMenu, "Time:", .callback = hCallback);
	menu_addblank(pMenu, false);
	menu_additem(pMenu, "Confirm!", .callback = hCallback);

	return pMenu;
}

public Callback_GagProperties(id, menu, item)
{
	enum { menu_Chat, menu_TeamChat, menu_VoiceChat,
			menu_Reason, menu_Time, menu_Confirm
		};
	
	new pOther = g_iSelectedPlayer[id];
	new gag_flags_s: gagFlags = g_aCurrentGags[pOther][_bitFlags];

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
			formatex(sName, charsmax(sName), "%L [ \\y%s\\w ]", id, "CA_Gag_Reason", Get_GagStringReason(id, pOther));
		case menu_Time:
			formatex(sName, charsmax(sName), "%L [ \\y%s\\w ]", id, "CA_Gag_Time", GetStringTime_seconds(g_aCurrentGags[pOther][_ExpireTime]));
		case menu_Confirm:
			formatex(sName, charsmax(sName), "%L", id, "CA_Gag_Confirm");
	}

	menu_item_setname(menu, item, sName);

	return (
		item == menu_Confirm && !Ready_To_Gag(pOther)
		|| DATABASE_TYPE == DB_NVault && item == menu_Reason
		) ? ITEM_DISABLED : ITEM_ENABLED;
}

public Menu_Handler_GagProperties(id, menu, item)
{	
	enum { menu_Chat, menu_TeamChat, menu_VoiceChat,
			menu_Reason, menu_Time, menu_Confirm
		};

	new pOther = g_iSelectedPlayer[id];

	if(item == MENU_EXIT || item < 0) {
		ResetOtherData(pOther);
		return PLUGIN_HANDLED;
	}

	if(!is_user_connected(pOther)) {
		Menu_Show_PlayersList(id);
		client_print_color(id, print_team_red, "Player not connected!");

		return PLUGIN_HANDLED;
	}

	switch(item) {
		case menu_Chat:			Gag_Toggle(pOther, m_Say);
		case menu_TeamChat: 	Gag_Toggle(pOther, m_SayTeam);
		case menu_VoiceChat:	Gag_Toggle(pOther, m_Voice);
		case menu_Reason: {
			Menu_Show_SelectReason(id, pOther);

			return PLUGIN_HANDLED;
		}
		case menu_Time:	{
			Menu_Show_SelectTime(id, pOther);

			return PLUGIN_HANDLED;
		}
		case menu_Confirm: {
			SaveGag(id ,pOther);
			return PLUGIN_HANDLED;
		}
	}

	menu_display(id, g_pMenu_GagProperties);

	return PLUGIN_HANDLED;
}

stock bool: Ready_To_Gag(pOther)
{	
	return (g_aCurrentGags[pOther][_bitFlags] != m_REMOVED ) ? true : false;
}


public Menu_Show_SelectReason(pPlayer, pOther)
{
	if(!is_user_connected(pOther))
		return PLUGIN_HANDLED;

	new szTemp[MAX_REASON_LEN];
	formatex(szTemp, charsmax(szTemp), "%L", pPlayer, "MENU_SelectReason");

	new pMenu = menu_create(szTemp, "Menu_Handler_SelectReason");

	formatex(szTemp, charsmax(szTemp), "%L", pPlayer, "EnterReason");
	menu_additem(pMenu, szTemp, "-1");

	if(g_iArraySize_Reasons)
	{
		for(new i; i < g_iArraySize_Reasons; i++)
		{
			new aReason[gag_s];
			ArrayGetArray(g_aReasons, i, aReason);

			new szItemInfo[4];
			num_to_str(i, szItemInfo, charsmax(szItemInfo));
			
			new szItemName[64];
			formatex(szItemName, charsmax(szItemName), "%s (\\y%s\\w)", aReason[_Reason], GetStringTime_seconds( aReason[_ExpireTime]) );

			menu_additem(pMenu, szItemName, szItemInfo);
			// server_print("ADDMNU[%i]:%s, szInfo(%s)", i, szItemName, szItemInfo);
		}
	} else menu_addtext(pMenu, "\\d		Нет добавленных шаблонов причин.", .slot = false);

	return menu_display(pPlayer, pMenu);
}

public Menu_Handler_SelectReason(pPlayer, pMenu, iItem)
{
	new pOther = g_iSelectedPlayer[pPlayer];

	if(iItem == MENU_EXIT || iItem < 0) {
		menu_display(pPlayer, g_pMenu_GagProperties);
		return PLUGIN_HANDLED;
	}

	static szItemInfo[3], dummy[1];
	menu_item_getinfo(pMenu, iItem, dummy[0], szItemInfo, charsmax(szItemInfo), dummy[0], charsmax(dummy), dummy[0]);

	new iReason = str_to_num(szItemInfo)/*  + 1 */;

	if(iReason == -1)
	{
		client_cmd(pPlayer, "messagemode enter_GagReason");
		return PLUGIN_HANDLED;
	}

	if(!g_iArraySize_Reasons)
		return PLUGIN_HANDLED;

	new aReason[gag_s];
	ArrayGetArray(g_aReasons, iReason, aReason);

	copy(g_aCurrentGags[pOther][_Reason], MAX_REASON_LEN - 1, aReason[_Reason]);

// IF NEED OFC
	g_aCurrentGags[pOther][_ExpireTime] = aReason[_ExpireTime];

	// log_amx("aReason[_ExpireTime]=%i, aReason[_Reason]=%s", aReason[_ExpireTime], aReason[_Reason]);

	menu_display(pPlayer, g_pMenu_GagProperties);

	return PLUGIN_HANDLED;
	// server_print("iItem=%i", iItem);
	// server_print("Data[%s]", szItemInfo);
}

public Menu_Show_SelectTime(pPlayer, pOther)
{
	if(!is_user_connected(pOther))
		return PLUGIN_HANDLED;

	new szTemp[64];
	formatex(szTemp, charsmax(szTemp), "%L", pPlayer, "MENU_SelectTime");

	new pMenu = menu_create(szTemp, "Menu_Handler_SelectTime");

	// if(sizeof g_aTimes)
	{
		for(new i, szItemName[64], szItemInfo[64]; i < sizeof g_aTimes; i++)
		{
			switch(g_aTimes[i])
			{
				case CUSTOMTIME: formatex(szItemName, charsmax(szItemName), "%L", pPlayer, "SET_CustomTime");
				case FOREVER:	formatex(szItemName, charsmax(szItemName), "%L", pPlayer, "CA_Gag_Perpapent");
				default:	get_time_length(pPlayer, g_aTimes[i] * SECONDS_IN_MINUTE, timeunit_seconds, szItemName, charsmax(szItemName));
			}

			// server_print("Menu_Show_SelectTime(): g_aTimes=%i'", g_aTimes[i]);
			num_to_str(g_aTimes[i] * SECONDS_IN_MINUTE, szItemInfo, charsmax(szItemInfo));
			menu_additem(pMenu, szItemName, szItemInfo);
		}
	}/*  else menu_addtext(pMenu, "\\d		Нет добавленных шаблонов времени.", .slot = false); */

	return menu_display(pPlayer, pMenu);
}

public Menu_Handler_SelectTime(pPlayer, pMenu, iItem)
{
	new pOther = g_iSelectedPlayer[pPlayer];

	if(iItem == MENU_EXIT || iItem < 0) {
		menu_display(pPlayer, g_pMenu_GagProperties);
		return PLUGIN_HANDLED;
	}

	static szItemInfo[16], dummy[1];
	menu_item_getinfo(pMenu, iItem, dummy[0], szItemInfo, charsmax(szItemInfo), dummy[0], charsmax(dummy), dummy[0]);

	new iTime = str_to_num(szItemInfo);
	// server_print("szItemInfo='%s', iTime='%i'", szItemInfo, iTime);
	/*
	if(!iTime)
	{
		// engclient_cmd(pPlayer, "messagemode", "Enter Time");
		client_cmd(pPlayer, "messagemode enter_GagTime");
		return PLUGIN_HANDLED;
	}
	*/

	// if(sizeof g_aTimes > 0)

	g_aCurrentGags[pOther][_ExpireTime] = iTime;
	// num_to_str(iTime, g_aCurrentGags[pOther][_ExpireTime], 31);

	// server_print("SetGAGTIME: '%i'", g_aCurrentGags[pOther][_ExpireTime]);

	menu_display(pPlayer, g_pMenu_GagProperties);
	return PLUGIN_HANDLED;
}

public ClCmd_EnterGagReason(pPlayer)
{
	new pOther = g_iSelectedPlayer[pPlayer];
	
	if(!is_user_connected(pOther))
		return PLUGIN_HANDLED;
	
	static szCustomReason[128];
	read_argv(1, szCustomReason, charsmax(szCustomReason));

	if(!szCustomReason[0])
	{
		Menu_Show_SelectReason(pPlayer, pOther);
		return PLUGIN_HANDLED;
	}

	copy(g_aCurrentGags[pOther][_Reason], MAX_REASON_LEN - 1, szCustomReason);

	client_print(pPlayer, print_chat, "Вы установили причину затычки: '%s'", g_aCurrentGags[pOther][_Reason]);
	menu_display(pPlayer, g_pMenu_GagProperties);
	return PLUGIN_HANDLED;
}

Gag_Toggle(pOther, gag_flags_s: flag)
	g_aCurrentGags[pOther][_bitFlags] ^= flag;

stock GetStringTime_seconds(iSeconds)
{
	// server_print("iSeconds = '%i'", iSeconds);

	new szTime[32];
	get_time_length(0, iSeconds, timeunit_seconds, szTime, charsmax(szTime));

	if(iSeconds == FOREVER)
		formatex(szTime, charsmax(szTime), "%L", LANG_SERVER, "CA_Gag_Perpapent");

	if(!szTime[0])
		formatex(szTime, charsmax(szTime), "%L", LANG_SERVER, "CA_Gag_NotSet");

	return szTime;
}

Get_GagStringReason(pPlayer, pOther)
{
	static szText[MAX_REASON_LEN];
	if(!g_aCurrentGags[pOther][_Reason][0])
		formatex(szText, charsmax(szText), "%L", pPlayer, "CA_Gag_NotSet");
	else copy(szText, charsmax(szText), g_aCurrentGags[pOther][_Reason]);

	return szText;
}


public CA_Client_Voice(const listener, const sender) {
	return (g_aCurrentGags[sender][_bitFlags] & m_Voice) ? CA_SUPERCEDE : CA_CONTINUE;
}

public CA_Client_SayTeam(id) {
	return (g_aCurrentGags[id][_bitFlags] & m_SayTeam) ? CA_SUPERCEDE : CA_CONTINUE;
}

public CA_Client_Say(id) {
	return (g_aCurrentGags[id][_bitFlags] & m_Say) ? CA_SUPERCEDE : CA_CONTINUE;
}

public SrvCmd_AddReason()
{
	if(!g_aReasons) g_aReasons = ArrayCreate(gag_s);

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
	aReason[_ExpireTime] = str_to_num(szArgs[arg3]) * SECONDS_IN_MINUTE;
	// num_to_str(str_to_num(szArgs[arg3]) * SECONDS_IN_MINUTE, aReason[_ExpireTime], charsmax(aReason[_ExpireTime]));
	
	ArrayPushArray(g_aReasons, aReason);
	g_iArraySize_Reasons = ArraySize(g_aReasons);

	log_amx("ADD: Reason[#%i]: '%s' (Flags:'%s', Time:'%i s.')",
			g_iArraySize_Reasons, aReason[_Reason], bits_to_flags(aReason[_bitFlags]), aReason[_ExpireTime]
		);
}

public SrvCmd_ShowTemplates()
{
	if(!g_aReasons || !g_iArraySize_Reasons)
	{
		log_amx("\t[WARN] NO REASONS FOUNDED!");
		return PLUGIN_HANDLED;
	}
	else
	{
		for(new i; i < g_iArraySize_Reasons; i++)
		{
			new aReason[gag_s];
			ArrayGetArray(g_aReasons, i, aReason);

			server_print("Reason[#%i]: '%s' (Flags:'%s', Time:'%i')",
				i, aReason[_Reason], bits_to_flags(aReason[_bitFlags]), aReason[_ExpireTime]
			);
		}
	}

	for(new i; i < sizeof g_aTimes; i++)
		server_print("Time[#%i]: '%i'", i, g_aTimes[i]);

	return PLUGIN_HANDLED;
}

SaveGag(pPlayer, pOther)
{
	// ca_remove_user_gag(pOther);

	get_user_name(pPlayer, g_aCurrentGags[pOther][_AdminName], charsmax(g_aCurrentGags[][_AdminName]));
	get_user_name(pOther, g_aCurrentGags[pOther][_Name],  charsmax(g_aCurrentGags[][_Name]));

	g_aCurrentGags[pOther][_AdminId] = pPlayer;
	
#if defined DEBUG
	//DEBUG__Dump_GagData("SaveGag()", g_aCurrentGags[pOther]);
#endif

	client_print_color(0, print_team_default, "%L",
		LANG_PLAYER, "Player_Gagged", pPlayer, pOther, GetStringTime_seconds(g_aCurrentGags[pOther][_ExpireTime]));

	if(g_aCurrentGags[pOther][_Reason][0])
		client_print_color(0, print_team_default, "Причина: '%s'", Get_GagStringReason(pPlayer, pOther));

	if(g_aCurrentGags[pOther][_ExpireTime] == 0)
		g_aCurrentGags[pOther][_ExpireTime] += 99999999;

	ca_set_user_gag(pOther, g_aCurrentGags[pOther]);

	return PLUGIN_CONTINUE;
}

RemoveGag(pPlayer, pOther)
{
	if(g_aCurrentGags[pOther][_bitFlags] != m_REMOVED) {
		ResetOtherData(pOther);
		ca_remove_user_gag(pOther);

		client_print_color(0, print_team_default, "%L",
			LANG_PLAYER, "Player_UnGagged", pPlayer, pOther);
	} else {
		client_print(pPlayer, print_chat, "Player '%n' gag already removed!", pOther);
	}

	Menu_Show_PlayersList(pPlayer);

	return PLUGIN_HANDLED;

}
/* 
public plugin_cfg()
{
	new szTimes[64];
	get_cvar_string("ca_gag_add_time", szTimes, charsmax(szTimes));

	if(!strlen(g_szCmds))
	{
		log_amx("[WARN] not found times! ca_gag_add_time ='%s'", szTimes);
		return;
	}

	new ePos, stPos, rawPoint[32], i;
	do
	{
		ePos = strfind(szTimes[stPos],",");
		formatex(rawPoint, ePos, szTimes[stPos]);
		stPos += ePos + 1;

		trim(rawPoint);

		if(rawPoint[0])
			g_aTimes[i++] = str_to_num(rawPoint);
	}
	while(ePos != -1);	
} */

stock ResetOtherData(pOther)
{
	GagData_Reset(g_aCurrentGags[pOther]);
}

/** On Players Events -> */
	// Client Connected & Authorized 
public client_putinserver(pPlayer)
{
	// Get player gag from Storage
	load_user_gag(pPlayer);
}

	// The client left the server
public client_disconnected(pPlayer)
{
	GagData_Reset(g_PlayersGags[pPlayer]);
}
/** <- On Players Events */

stock Player_GagSet(pPlayer, aGagData[])
{
	g_PlayersGags[pPlayer][_bitFlags]		= any: aGagData[_bitFlags];
	g_PlayersGags[pPlayer][_Reason]			= any: aGagData[_Reason];
	g_PlayersGags[pPlayer][_ExpireTime]		= any: aGagData[_ExpireTime];
}

stock Player_GagReset(pPlayer)
{
	GagData_Reset(g_PlayersGags[pPlayer]);

	// Remove player gag from Storage
	get_user_authid(pPlayer, g_PlayersGags[pPlayer][_AuthId], 31);
	get_user_ip(pPlayer, g_PlayersGags[pPlayer][_IP], 31, .without_port = true);
	remove_from_storage(g_PlayersGags[pPlayer][_AuthId], g_PlayersGags[pPlayer][_IP], g_PlayersGags[pPlayer]);
}


save_user_gag(pPlayer, aGagData[gag_s])
{
	// static szAuthId[32], szIP[32], szName[MAX_NAME_LENGTH];
	get_user_authid(pPlayer, aGagData[_AuthId], 31);
	get_user_ip(pPlayer, aGagData[_IP], 31, .without_port = true);
	// get_user_name(pPlayer, szName, charsmax(szName));
	aGagData[_Player] = pPlayer;
	get_user_authid(aGagData[_AdminId], aGagData[_AdminAuthId], 31);
	get_user_ip(aGagData[_AdminId], aGagData[_AdminIP], 31, .without_port = true);

	Player_GagSet(pPlayer, aGagData);

	// Save player gag on Storage
	save_to_storage(aGagData[_AuthId], aGagData[_IP], aGagData);

	client_cmd(pPlayer, "-voicerecord");
}

load_user_gag(pPlayer)
{
	static any: aGagData[gag_s];

	static szIP[32]; get_user_ip(pPlayer, szIP, charsmax(szIP), .without_port = true);
	static szAuthId[32]; get_user_authid(pPlayer, szAuthId, charsmax(szAuthId));
	aGagData[_Player] = pPlayer;

	load_from_storage(szAuthId, szIP, aGagData);
}

check_user_gag(pPlayer)
{
	static iSysTime; iSysTime = get_systime();

	if(g_PlayersGags[pPlayer][_bitFlags] != m_REMOVED && g_PlayersGags[pPlayer][_ExpireTime] < iSysTime)
	{
		// The user has expired gag - should reset
		g_PlayersGags[pPlayer][_bitFlags] = m_REMOVED;

			// TODO
			// Reset user gag
		// save_user_gag(pPlayer, aGagData);
#if defined DEBUG
		server_print("\n   - check_user_gag() USER[%i] HAS EXPIRED GAG - RESETED!", pPlayer);
#endif
	}
}



/** API -> */
public native_ca_set_user_gag(pPlugin, iParams)
{
	enum { Player = 1, m_GagData };

	static pPlayer; pPlayer = get_param(Player);
	static aGagData[gag_s]; get_array(m_GagData, aGagData, sizeof aGagData);

	// Sets next ungag time
	aGagData[_ExpireTime] += get_systime();
	aGagData[Player] = pPlayer;

	save_user_gag(pPlayer, aGagData);
}


public native_ca_get_user_gag(pPlugin, iParams) {
	enum { Player = 1, m_GagData };

	new pPlayer = get_param(Player);

	if(g_PlayersGags[pPlayer][_bitFlags] != m_REMOVED) {
		set_array(m_GagData, g_PlayersGags[pPlayer], sizeof g_PlayersGags[]);
		return true;
	}

	return false;
}

public native_ca_remove_user_gag(pPlugin, iParams)
{
	enum { Player = 1 };

	static pPlayer; pPlayer = get_param(Player);
	Player_GagReset(pPlayer);
}

public DB_Types: native_ca_get_storage_type(pPlugin, iParams)
{
	return DATABASE_TYPE;
}
/** <- API */
