#define FLAGS_ACCESS    ( ADMIN_KICK )
#define FLAGS_IMMUNITY    ( ADMIN_IMMUNITY )

#include <amxmodx>
#include <amxmisc>
#include <time>

#pragma semicolon 1
#pragma ctrlchar '\'

#include <ChatsAdditions_API>

#define DEBUG


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



const PLAYERS_PER_PAGE = 7;

new g_iPlayerMenuPage[MAX_PLAYERS + 1],
	g_apPlayerMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS],
	g_iSelectedPlayer[MAX_PLAYERS + 1];

/* Cvars */
new ca_gag_flags_default[4];

new const MENU_PlayersList[]		= "Admin Gag Menu";
new const MENU_Gag_Properties[]		= "Gag properties on players";

new any: g_aGags[MAX_PLAYERS + 1][gag_s];
new Array: g_aReasons, g_iArraySize_Reasons;

new g_pMenu_GagProperties;

public plugin_init()
{
	register_plugin("[CA] Gag", "0.01b", "wopox1337");
	register_dictionary("CA_Gag.txt");
	register_dictionary("common.txt");
	register_dictionary("time.txt");

	register_menu(MENU_PlayersList, 1023, "Menu_Handler_PlayersList", .outside = 1);
	register_menu(MENU_Gag_Properties, 1023, "Menu_Handler_GagProperties", .outside = 1);

	bind_pcvar_string(
		create_cvar("ca_gag_flags_default", "abc", .description = "Default flags to set on gagged player."),
		ca_gag_flags_default, charsmax(ca_gag_flags_default)
	);

	// create_cvar("ca_gag_times", "1, 5, 30, 60, 1440, 10080, -1", .description = "Default times set."); // concept

	register_srvcmd("ca_gag_add_reason", "SrvCmd_AddReason");
	register_srvcmd("ca_gag_show_templates", "SrvCmd_ShowTemplates"); // debug


	
	// server_cmd("ca_gag_add_reason \"Reason #5\" \"bc\" \"25\"");

	Init_Cmds();
	
	g_pMenu_GagProperties = BuildMenu_GagProperties();
}

public ClCmd_Gag(pPlayer, level, cid)
{
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

	for(new i; i < iCount; i++)
		menu_additem(pMenu, "-", fmt("%i", get_user_userid(aPlayers[i])), .callback = hCallback);

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

	if(g_aGags[pOther][_bitFlags]) {
		ResetOtherData(pOther);
		ca_remove_user_gag(pOther);

		client_print(id, print_chat, "Player ungagged '%n'", pOther);

		return menu_display(id, menu);
	}

	menu_display(id, g_pMenu_GagProperties);
	g_iSelectedPlayer[id] = pOther;

	return PLUGIN_HANDLED;
}

	// TODO!
GetPostfix(pPlayer, bHaveImmunity)
{
	static szPostfix[32];

	if(bHaveImmunity)
		formatex(szPostfix, charsmax(szPostfix), " [\\r*]");
	else if(g_aGags[pPlayer][_bitFlags])
		formatex(szPostfix, charsmax(szPostfix), " [\\yGagged\\w]");
	else szPostfix[0] = '\0';

	return szPostfix;
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
	menu_additem(pMenu, "Confirm!", .callback = hCallback);

	return pMenu;
}

public Callback_GagProperties(id, menu, item)
{
	enum { menu_Chat, menu_TeamChat, menu_VoiceChat,
			menu_Reason, menu_Time, menu_Confirm
		};
	
	new pOther = g_iSelectedPlayer[id];
	new gag_flags_s: gagFlags = g_aGags[pOther][_bitFlags];

	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	switch(item) {
		case menu_Chat:
			formatex(sName, charsmax(sName), "Chat: [ %s ]", (gagFlags & m_Say) ? " \\r+\\w " : "-");
		case menu_TeamChat:
			formatex(sName, charsmax(sName), "Team chat: [ %s ]", (gagFlags & m_SayTeam) ? " \\r+\\w " : "-");
		case menu_VoiceChat:
			formatex(sName, charsmax(sName), "Voice chat: [ %s ]", (gagFlags & m_Voice) ? " \\r+\\w " : "-");
		case menu_Reason:
			formatex(sName, charsmax(sName), "Reason: [ %s ]", Get_GagStringReason(id, pOther));
		case menu_Time:
			formatex(sName, charsmax(sName), "Time: [ %s ]", GetStringTime_seconds(g_aGags[pOther][_ExpireTime]));
	}

	menu_item_setname(menu, item, sName);

	return (item == menu_Confirm && !Ready_To_Gag(pOther)) ? ITEM_DISABLED : ITEM_ENABLED;
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
	return (g_aGags[pOther][_bitFlags] != m_REMOVED ) ? true : false;
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

	copy(g_aGags[pOther][_Reason], MAX_REASON_LEN - 1, aReason[_Reason]);

// IF NEED OFC
	g_aGags[pOther][_ExpireTime] = aReason[_ExpireTime];

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

	g_aGags[pOther][_ExpireTime] = iTime;
	// num_to_str(iTime, g_aGags[pOther][_ExpireTime], 31);

	// server_print("SetGAGTIME: '%i'", g_aGags[pOther][_ExpireTime]);

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

	copy(g_aGags[pOther][_Reason], MAX_REASON_LEN - 1, szCustomReason);

	client_print(pPlayer, print_chat, "Вы установили причину затычки: '%s'", g_aGags[pOther][_Reason]);
	menu_display(pPlayer, g_pMenu_GagProperties);
	return PLUGIN_HANDLED;
}

Gag_Toggle(pOther, gag_flags_s: flag)
	g_aGags[pOther][_bitFlags] ^= flag;

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


stock Get_GagStringFlags(pOther, flag)
	return MENU_PlayersList;

Get_GagStringReason(pPlayer, pOther)
{
	static szText[MAX_REASON_LEN];
	if(!g_aGags[pOther][_Reason][0])
		formatex(szText, charsmax(szText), "%L", pPlayer, "CA_Gag_NotSet");
	else copy(szText, charsmax(szText), g_aGags[pOther][_Reason]);

	return szText;
}

stock Menu_Show_AdditionalModes(pPlayer) {
	return pPlayer;
}

// public CA_Client_Voice(pPlayer, pOther) {
	// return get_bit(aMuted[pPlayer], pOther) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
// }


const MAX_CMD_LEN = 32;
new const g_szCmds[] = "gag";
new const szPreCmd[][] = {"say ", "say_team ", ""};
new const szCtrlChar[][] = {"!", "/", "\\", "." , "?", ""};
new const FUNC_NAME[] = "ClCmd_Gag";

Init_Cmds()
{
	if(!strlen(g_szCmds))
		return;

	for(new i; i < sizeof(szPreCmd); i++)
	{
		for(new k; k < sizeof(szCtrlChar); k++)
		{
			new szCmd[MAX_CMD_LEN], ePos, stPos, rawPoint[32];

			do
			{
				ePos = strfind(g_szCmds[stPos],",");
				formatex(rawPoint, ePos, g_szCmds[stPos]);
				stPos += ePos + 1;

				trim(rawPoint);

				if(rawPoint[0])
				{
					formatex(szCmd, charsmax(szCmd),
						"%s%s%s",
						szPreCmd[i],
						szCtrlChar[k],
						rawPoint
					);
						
					register_clcmd(szCmd, FUNC_NAME, ADMIN_KICK);
				}
			}
			while(ePos != -1);
		}
	}

	register_clcmd("enter_GagReason", "ClCmd_EnterGagReason");
}

public SrvCmd_AddReason()
{
	if(!g_aReasons) g_aReasons = ArrayCreate(gag_s);

	enum any: args_s { arg0, arg1, arg2, arg3 };

	new szArgs[args_s][32];
	for(new iArg = arg0; iArg < sizeof szArgs; iArg++)
	{
		read_argv(iArg, szArgs[iArg], charsmax(szArgs[]));
		// server_print("\t szArg%i='%s'", iArg, szArgs[iArg]);
	}

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

	get_user_name(pPlayer, g_aGags[pOther][_AdminName], charsmax(g_aGags[][_AdminName]));
	get_user_name(pOther, g_aGags[pOther][_Name],  charsmax(g_aGags[][_Name]));

	g_aGags[pOther][_AdminId] = pPlayer;
	
#if defined DEBUG
	//DEBUG__Dump_GagData("SaveGag()", g_aGags[pOther]);
#endif

	client_print_color(0, print_team_default, "\3 \1Админ %s установил молчанку игроку \4%s\1 на \3%s\1",
		g_aGags[pOther][_AdminName], g_aGags[pOther][_Name], GetStringTime_seconds(g_aGags[pOther][_ExpireTime]));

	if(g_aGags[pOther][_Reason][0])
		client_print_color(0, print_team_default, "Причина: '%s'", Get_GagStringReason(pPlayer, pOther));

	if(g_aGags[pOther][_ExpireTime] == 0)
		g_aGags[pOther][_ExpireTime] += 99999999;

	ca_set_user_gag(pOther, g_aGags[pOther]);

	return PLUGIN_CONTINUE;
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

stock ResetAdminData(pPlayer)
{
	g_iPlayerMenuPage[pPlayer] = 0;
	g_apPlayerMenuPlayers[pPlayer] = "";
	g_iSelectedPlayer[pPlayer] = 0;
}

stock ResetOtherData(pOther)
{
	GagData_Reset(g_aGags[pOther]);
}