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
}

public ClCmd_Gag(pPlayer)
{
	/* if(!IsUserHaveAccessToUse(pPlayer))
		return PLUGIN_HANDLED; */

	if(get_playersnum() < 2)
	{
		client_print_color(pPlayer, print_team_default, "\3Не достаточно игроков, что бы открыть меню Gag'ов!");
		return PLUGIN_HANDLED;
	}

	Menu_Show_PlayersList(pPlayer, .iPage = 0);
	return PLUGIN_HANDLED;
}

public Menu_Show_PlayersList(pPlayer, iPage)
{
	if(iPage < 0)
		return PLUGIN_HANDLED;

	if(iPage == 0)
	{
		// ResetOtherData(g_iSelectedPlayer[pPlayer]);
		ResetAdminData(pPlayer);
	}

	new aPlayersId[MAX_PLAYERS];
	static iCount, iPlayer;
	new szMenu[512], szName[MAX_NAME_LENGTH];

#if defined DEBUG
	get_players(aPlayersId, iCount, .flags = "h");
#else
	get_players(aPlayersId, iCount, .flags = "ch");
#endif

	static i; i = min(iPage * PLAYERS_PER_PAGE, iCount);
	static iStart; iStart = i - (i % PLAYERS_PER_PAGE);
	static iEnd; iEnd = min(iStart + PLAYERS_PER_PAGE, iCount);

	iPage = iStart / PLAYERS_PER_PAGE;

	g_apPlayerMenuPlayers[pPlayer] = aPlayersId;
	g_iPlayerMenuPage[pPlayer] = iPage;

	static iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "%L\\R%i/%i\n\n", pPlayer, "CA_Gag_TITLE", iPage + 1, ((iCount - 1) / PLAYERS_PER_PAGE) + 1);

	new bitsKeys = MENU_KEY_0, iItem;
	new bitsFlags;

	for(i = iStart; i < iEnd; i++)
	{
		iPlayer = aPlayersId[i];
		
		/* if(pPlayer == iPlayer){
			server_print("SKIPPED %i", iPlayer);
			continue;
		} */

		get_user_name(iPlayer, szName, charsmax(szName));

		bitsFlags = get_user_flags(iPlayer);
		static bHaveImmunity; bHaveImmunity = bitsFlags & FLAGS_IMMUNITY;

		if(pPlayer != iPlayer && !bHaveImmunity)
			bitsKeys |= (1 << iItem);

		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r%i. %s%s%s\n", ++iItem, (bHaveImmunity || (pPlayer == iPlayer)) ? "\\d" : "\\w" ,szName, GetPostfix(iPlayer, bHaveImmunity));
	}

		// TODO!
	// bitsKeys |= MENU_KEY_8;
	// iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\n\n\\r8. \\w%L\n", pPlayer, "CA_Gag_AdditionalModes");

	if(iEnd < iCount)
	{
		bitsKeys |= MENU_KEY_9;
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\n\\r9. \\w%L\n\\r0. \\w%L", pPlayer, "MORE", pPlayer, iPage ? "BACK" : "EXIT");
	}
	else
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\n\\r0. \\w%L", pPlayer, iPage ? "BACK" : "EXIT");

	return show_menu(pPlayer, bitsKeys, szMenu, -1, MENU_PlayersList);
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

#define GetPlayerIdByMenuKey(%1,%2) g_apPlayerMenuPlayers[%1][(g_iPlayerMenuPage[%1] * PLAYERS_PER_PAGE) + %2]

public Menu_Handler_PlayersList(pPlayer, iKey)
{
	switch(iKey)
	{
		case 7: return Menu_Show_AdditionalModes(pPlayer);
		case 8: return Menu_Show_PlayersList(pPlayer, ++g_iPlayerMenuPage[pPlayer]);
		case 9: return Menu_Show_PlayersList(pPlayer, --g_iPlayerMenuPage[pPlayer]);
	}

	static pOther; pOther = GetPlayerIdByMenuKey(pPlayer, iKey);
	// server_print("pPlayer=%i, pOther=%i, iKey=%i", pPlayer, pOther, iKey);

	if(g_aGags[pOther][_bitFlags]) {
		ResetOtherData(pOther);

		static szName[MAX_NAME_LENGTH]; get_user_name(pOther, szName, charsmax(szName));
		client_print(pPlayer, print_chat, "Вы сняли блокировку с игрока '%s'", szName);

		return Menu_Show_PlayersList(pPlayer, g_iPlayerMenuPage[pPlayer]);
	}


	Menu_Show_OnPlayerSelect(pPlayer, pOther);

	g_iSelectedPlayer[pPlayer] = pOther;

	// Menu_Show_PlayersList(pPlayer, g_iPlayerMenuPage[pPlayer]);
	return PLUGIN_HANDLED;
}

Menu_Show_OnPlayerSelect(pPlayer, pOther)
{
	if(!is_user_connected(pOther))
		return PLUGIN_HANDLED;

	new szMenu[512],
		szName[MAX_NAME_LENGTH],
		bitsKeys = MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_0;

	if(Ready_To_Gag(pOther))
		bitsKeys |= MENU_KEY_7;

	get_user_name(pOther, szName, charsmax(szName));

	static gag_flags_s: gagFlags; gagFlags = g_aGags[pOther][_bitFlags];
	
	static iLen;
	iLen =	formatex(szMenu, charsmax(szMenu), "%L\n", pPlayer, "CA_Gag_Properties", szName);
	// iLen +=	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\dФлаги:\\w [\\r%s\\w]\n", szGagFlags));
	iLen +=	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r1\\w. %L\n", pPlayer, "CA_Gag_Say", pPlayer, (gagFlags & m_Say) ? "CA_GAG_YES" : "CA_GAG_NO");
	iLen +=	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r2\\w. %L\n", pPlayer, "CA_Gag_SayTeam", pPlayer, (gagFlags & m_SayTeam) ? "CA_GAG_YES" : "CA_GAG_NO");
	iLen +=	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r3\\w. %L\n\n", pPlayer, "CA_Gag_Voice", pPlayer, (gagFlags & m_Voice) ? "CA_GAG_YES" : "CA_GAG_NO");

	iLen +=	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r5\\w. %L\n", pPlayer, "CA_Gag_Reason", Get_GagStringReason(pPlayer, pOther));
	iLen +=	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r6\\w. %L\n\n", pPlayer, "CA_Gag_Time", GetStringTime_seconds(g_aGags[pOther][_ExpireTime]));
	iLen +=	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r7\\w. %s%L\n", Ready_To_Gag(pOther) ? "\\y" : "\\d", pPlayer, "CA_Gag_Confirm");
	iLen +=	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r0\\w. \\r%L", pPlayer, "BACK");

	// log_amx("g_aGags[pOther][_ExpireTime]='%s'", g_aGags[pOther][_ExpireTime]);

	return show_menu(pPlayer, bitsKeys, szMenu, -1, MENU_Gag_Properties);
}

stock bool: Ready_To_Gag(pOther)
{	
	return (g_aGags[pOther][_ExpireTime] != 0 && g_aGags[pOther][_bitFlags] != m_REMOVED ) ? true : false;
}

public Menu_Handler_GagProperties(pPlayer, iKey)
{
	static pOther; pOther = g_iSelectedPlayer[pPlayer];

	switch(++iKey)
	{
		case 1: Gag_Toggle(pOther, m_Say);
		case 2: Gag_Toggle(pOther, m_SayTeam);
		case 3: Gag_Toggle(pOther, m_Voice);
		case 5: return Menu_Show_SelectReason(pPlayer, pOther);
		case 6: return Menu_Show_SelectTime(pPlayer, pOther);

		case 7: return SaveGag(pPlayer ,pOther);
		default: {
			ResetOtherData(pOther);
			return Menu_Show_PlayersList(pPlayer, .iPage = g_iPlayerMenuPage[pPlayer]);
		}
	}

	return Menu_Show_OnPlayerSelect(pPlayer, pOther);
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
	if(iItem == MENU_EXIT)
		return Menu_Show_OnPlayerSelect(pPlayer, pOther);

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

	return Menu_Show_OnPlayerSelect(pPlayer, pOther);

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

	if(iItem == MENU_EXIT)
		return Menu_Show_OnPlayerSelect(pPlayer, pOther);
	
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

	return Menu_Show_OnPlayerSelect(pPlayer, pOther);
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
	return Menu_Show_OnPlayerSelect(pPlayer, pOther);
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
						
					register_clcmd(szCmd, FUNC_NAME);
				}
			}
			while(ePos != -1);
		}
	}

	register_clcmd("enter_GagReason", "ClCmd_EnterGagReason");
}

stock IsUserHaveAccessToUse(const pPlayer) {

		// Anytime we can add other checks, like cached bool

		return (get_user_flags(pPlayer) & ACCESS_FLAGS);

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

stock flags_to_bit(szFlags[])
{
	new gag_flags_s: bits = m_REMOVED;
	if(containi(szFlags, "a") != -1) bits |= m_Say;
	if(containi(szFlags, "b") != -1) bits |= m_SayTeam;
	if(containi(szFlags, "c") != -1) bits |= m_Voice;

	// server_print("flags_to_bit() '%s'=%i",szFlags, bits);

	return bits;
}

stock bits_to_flags(gag_flags_s: bits)
{
	new szFlags[4];
	if(bits & m_Say) add(szFlags, charsmax(szFlags), "a");
	if(bits & m_SayTeam) add(szFlags, charsmax(szFlags), "b");
	if(bits & m_Voice) add(szFlags, charsmax(szFlags), "c");

	// server_print("bits_to_flags()='%s'", szFlags);

	return szFlags;
}

SaveGag(pPlayer, pOther)
{
	// ca_remove_user_gag(pOther);

	get_user_name(pPlayer, g_aGags[pOther][_AdminName], 31);
	get_user_name(pOther, g_aGags[pOther][_Name], 31);

	g_aGags[pOther][_AdminId] = pPlayer;

// LOG DAT FKIN BUGGY ARRAYS! ;(
	server_print(" SaveGag() -> \n\
		g_aGags[_Player] = '%i'\n\
		g_aGags[_AuthId] = '%s'\n\
		g_aGags[_IP] = '%s'\n\
		g_aGags[_Name] = '%s'\n\
		g_aGags[_AdminId] = '%i'\n\
		g_aGags[_AdminName] = '%s'\n\
		g_aGags[_AdminAuthId] = '%s'\n\
		g_aGags[_AdminIP] = '%s'\n\
		g_aGags[_Reason] = '%s'\n\
		g_aGags[_ExpireTime] = '%i'\
		", g_aGags[pOther][_Player], g_aGags[pOther][_AuthId], g_aGags[pOther][_IP], g_aGags[pOther][_Name],
		g_aGags[pOther][_AdminId], g_aGags[pOther][_AdminName], g_aGags[pOther][_AdminAuthId],
		g_aGags[pOther][_AdminIP], g_aGags[pOther][_Reason], g_aGags[pOther][_ExpireTime]
	);

	ca_set_user_gag(pOther, g_aGags[pOther]);

	client_print_color(0, print_team_default, "\3 \1Админ %s установил молчанку игроку \4%s\1 на \3%s\1 по причине:\"%s\"",
		g_aGags[pOther][_AdminName], g_aGags[pOther][_Name], GetStringTime_seconds(g_aGags[pOther][_ExpireTime]), Get_GagStringReason(pPlayer, pOther));

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
	g_aGags[pOther][_bitFlags] = 0;
	g_aGags[pOther][_Reason] = 0;
	g_aGags[pOther][_ExpireTime] = 0;
}
