#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1
#pragma ctrlchar '\'

#include <ChatsAdditions_API>


new bool: g_aMutes[MAX_PLAYERS + 1][MAX_PLAYERS + 1];
new bool: g_bGlobalMute[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("[CA] Mute menu", "1.0.0-alpha", "Sergey Shorokhov");
	register_dictionary("CA_Mute.txt");
	register_menu("Players Mute Menu", 1023, "Menu_Handler_PlayersList", .outside = 1);

	Init_Cmds();
}

Init_Cmds()
{
	new const szCmd[] = "mute";
	new const szPreCmd[][] = {"say ", "say_team "/*, ""*/};
	new const szCtrlChar[][] = {"!", "/", "\\", "." , "?", ""};

	for(new i; i < sizeof(szPreCmd); i++) {
		for(new k; k < sizeof(szCtrlChar); k++) {
			register_clcmd(fmt("%s%s%s", szPreCmd[i], szCtrlChar[k], szCmd), "ClCmd_Mute");
		}
	}
}


public ClCmd_Mute(id) {
	Menu_Show_PlayersList(id);

	return PLUGIN_HANDLED;
}

public Menu_Show_PlayersList(id) {
	new pMenu = menu_create("Players for mute:", "Menu_Handler_PlayersList");
	new hCallback = menu_makecallback("Callback_PlayersList");

	new aPlayers[MAX_PLAYERS], iCount;
	get_players_ex(aPlayers, iCount, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));

	if(iCount < 2) {
		menu_additem(pMenu, "\\rNot enough players!", "-2", .callback = hCallback);
	} else {
		menu_additem(pMenu, fmt("\\r%sute all?", g_bGlobalMute[id] ? "Unm" : "m"), "-1");
		menu_addblank(pMenu, .slot = false);

		for(new i; i < MaxClients; i++) {
			if(i != id && is_user_connected(i))
				menu_additem(pMenu, "Name", fmt("%i", get_user_userid(i)), .callback = hCallback);
		}
	}

	menu_display(id, pMenu);
}

public Callback_PlayersList(id, menu, item) {
	new null, sInfo[64], sName[64];
	menu_item_getinfo(menu, item, null, sInfo, charsmax(sInfo), sName, charsmax(sName), null);

	new iUserID = strtol(sInfo);
	if(iUserID > 0) {
		new player = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), iUserID);
		menu_item_setname(menu, item, fmt("%n   %s", player, g_aMutes[id][player] ? "[ \\r+\\w ]" : ""));
	}

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

	new iUserID = strtol(sInfo);
	if(iUserID == -1) {
		g_bGlobalMute[id] ^= true;

		menu_destroy(menu);
		Menu_Show_PlayersList(id);
		return PLUGIN_HANDLED;
	}

	new player = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), iUserID);
	if(!is_user_connected(player)) {
		client_print(id, print_chat, "Player not connected!");

		menu_destroy(menu);
		Menu_Show_PlayersList(id);
		return PLUGIN_HANDLED;
	}

	g_aMutes[id][player] ^= true;
	client_print_color(id, print_team_default, "^1^4Player %n - %smuted.", player, g_aMutes[id][player] ? "" : "un");

	menu_destroy(menu);
	Menu_Show_PlayersList(id);

	return PLUGIN_HANDLED;
}


public client_disconnected(id) {
	arrayset(g_aMutes[id], false, sizeof g_aMutes[]);
	g_bGlobalMute[id] = false;

	for(new i; i < sizeof g_aMutes[]; i++)
		g_aMutes[i][id] = false;
}

public CA_Client_Voice(const listener, const sender) {
	return (g_aMutes[listener][sender] == true || g_bGlobalMute[listener] || g_bGlobalMute[sender]) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}