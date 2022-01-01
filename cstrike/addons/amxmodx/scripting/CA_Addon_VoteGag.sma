
#include <amxmisc>
#include <ChatAdditions>
#include <CA_GAG_API>

const INVALID_ACCESS = (-1 ^ (-1 << 29));

enum _:CVARS
{
	CMDS[512],
	REASON[128],
	TIME,
	PERCENTAGE,
	MAX_VOTES,
	MIN_PLAYERS,
	SAMPLE_OK[MAX_RESOURCE_PATH_LENGTH],
	SAMPLE_ERROR[MAX_RESOURCE_PATH_LENGTH],

};	new CVAR[CVARS];

new bool:g_bVotedPlayers[MAX_PLAYERS + 1][MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("CA: VoteGAG", "1.0.0-alpha", "Sergey Shorokhov");
	
	register_dictionary("CA_VoteGag.txt");
	register_dictionary("time.txt");
	
/*
	static const CMDS[][] = { "votegag" };
	for (new i; i < sizeof(CMDS); i++)
		register_trigger_clcmd(CMDS[i], "clcmd_votegag");
*/
	
	Register_CVars();
	
	new szName[32];
	
	while (argbreak(CVAR[CMDS], szName, charsmax(szName), CVAR[CMDS], charsmax(CVAR[CMDS])) != -1)
	{
		if (szName[0] == '/' || szName[0] == '!' || szName[0] == '.')
		{
			register_clcmd(fmt("say %s", szName), "clcmd_votegag");
			register_clcmd(fmt("say_team %s", szName), "clcmd_votegag");
		}
		else
			register_clcmd(szName, "clcmd_votegag");
	}
	
	CA_Log(logLevel_Debug, "[CA]: Vote Gag initialized!");
}

public client_disconnected(id)
{
	arrayset(g_bVotedPlayers[id], false, sizeof(g_bVotedPlayers[]));
	
	for (new i, aSize = sizeof(g_bVotedPlayers[]); i < aSize; i++) g_bVotedPlayers[i][id] = false;
}

public clcmd_votegag(id)
{
	if (get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV) < CVAR[MIN_PLAYERS])
	{
		client_print_color(id, print_team_red, "%L %L", id, "VoteGag_prefix", id, "VoteGag_NotEnoughtPlayers");
		
		UTIL_SendAudio(id, CVAR[SAMPLE_ERROR]);
	}
	else
		_show_votegag_menu(id);
	
	return PLUGIN_HANDLED;
}

_show_votegag_menu(id)
{	
	new votes = GetVotesByPlayer(id);
	
	if (votes)
	{
		new menu = menu_create(fmt("%L", id, "VoteGag_MaimMenu"), "menu_votegag_handler");
		
		if (votes < CVAR[MAX_VOTES])
			menu_additem(menu, fmt("%L", id, "VoteGag_MakeVote", votes, CVAR[MAX_VOTES]));
		else
			menu_additem(menu, fmt("%L %L", id, "VoteGag_MakeVote", id, "VoteGag_LimitReached"), .paccess = INVALID_ACCESS);
		
		menu_additem(menu, fmt("%L", id, "Gag_RemoveVote"));
		
		menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"));
		
		menu_display(id, menu);
	}
	else
		_show_make_gag_menu(id);
}

public menu_votegag_handler(id, menu, item)
{
	menu_destroy(menu);
	
	if (item == 1)
		_show_remove_gag_menu(id);
	else if (item == 0)
		_show_make_gag_menu(id);
	
	return PLUGIN_HANDLED;
}

_show_make_gag_menu(id)
{
	new menu = menu_create(NULL_STRING, "make_votegag_handler");
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (is_user_bot(i))
			continue;
		
		if (i == id)
			continue;
		
		if (g_bVotedPlayers[id][i])
			continue;
		
		if (ca_has_user_gag(i))
			continue;
		
		menu_additem(menu,
			fmt("%n \%c(%i%%)",
				i,
				GetPercentageOfVotes(i) > CVAR[PERCENTAGE] / 2 ? 'r' : 'w',
				GetPercentageOfVotes(i)),
				fmt("%i", get_user_userid(i)
			)
		);
		
	/*
		if (++pNum % 6 == 0)
		{
			menu_addblank(menu, .slot = false);
			menu_additem(menu, fmt("%L %L", id, "VoteGag_Reason")
		}
	*/
	}
	
	new pNum = menu_items(menu);
	
	if (pNum < 1)
	{
		client_print_color(id, print_team_red, "%L %L", id, "VoteGag_prefix", id, "VoteGag_NotEnoughtPlayers");
		UTIL_SendAudio(id, CVAR[SAMPLE_ERROR]);
		menu_destroy(menu);
		return;
	}
	
	// menu_setprop(menu, MPROP_PERPAGE, 6);
	menu_setprop(menu, MPROP_SHOWPAGE, false);
	menu_setprop(menu, MPROP_TITLE, fmt("%L", id, "VoteGag_MakeVote", pNum));
	menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "NEXT"));
	menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"));
	menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"));
	
	menu_display(id, menu);
}

public make_votegag_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		
		//if (is_user_connected(id))
			//_show_votegag_menu(id);
		
		return PLUGIN_HANDLED;
	}
	
	if (get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV) < CVAR[MIN_PLAYERS])
	{
		client_print_color(id, print_team_red, "%L %L", id, "VoteGag_prefix", id, "VoteGag_NotEnoughtPlayers");
		UTIL_SendAudio(id, CVAR[SAMPLE_ERROR]);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new szName[64];
	
	menu_item_getinfo(menu, item, _, szName, charsmax(szName), _, _, _);
	menu_destroy(menu);
	
	new pPlayer = find_player_ex(FindPlayer_MatchUserId, str_to_num(szName));
	
	if (pPlayer == 0 || ca_has_user_gag(pPlayer))
	{
		client_print_color(id, print_team_red, "%L %L", id, "VoteGag_prefix", id, "VoteGag_AccessDenid");
		
		UTIL_SendAudio(id, CVAR[SAMPLE_ERROR]);
	}
	else
	{
		exec_gag(id, pPlayer);
		
		UTIL_SendAudio(id, CVAR[SAMPLE_OK]);
	}
	
	return PLUGIN_HANDLED;
}

_show_remove_gag_menu(id)
{
	new menu = menu_create(NULL_STRING, "remove_votegag_handler");
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (!g_bVotedPlayers[id][i])
			continue;
		
		menu_additem(menu, fmt("%n \d[\r%d\d]", i, GetVotes(i)), fmt("%i", get_user_userid(i)));
	}
	
	if (menu_items(menu) < 1)
	{
		client_print_color(id, print_team_red, "%L %L", id, "VoteGag_prefix", id, "VoteGag_NotEnoughtPlayers");
		UTIL_SendAudio(id, CVAR[SAMPLE_ERROR]);
		menu_destroy(menu);
		return;
	}
	
	menu_setprop(menu, MPROP_SHOWPAGE, false);
	menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "NEXT"));
	menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"));
	menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"));
	
	menu_display(id, menu);
}

public remove_votegag_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		
		//if (is_user_connected(id))
			//_show_votegag_menu(id);
		
		return PLUGIN_HANDLED;
	}
	
	new szName[64];
	
	menu_item_getinfo(menu, item, _, szName, charsmax(szName), _, _, _);
	menu_destroy(menu);
	
	new pPlayer = find_player_ex(FindPlayer_MatchUserId, str_to_num(szName));
	
	if (pPlayer == 0)
	{
		client_print_color(id, print_team_red, "%L %L", id, "VoteGag_prefix", id, "VoteGag_AccessDenid");
		
		UTIL_SendAudio(id, CVAR[SAMPLE_ERROR]);
	}
	else
	{
		g_bVotedPlayers[id][pPlayer] = false;
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!is_user_connected(i))
				continue;
			
			if (i == pPlayer)
				continue;
			
			client_print_color(i, pPlayer, "%L %L", i, "VoteGag_prefix", i, "VoteGag_RemoveVote", id, pPlayer);
		}
		
		CA_Log(logLevel_Info, "[CA]: %N убрал свой голос против %N", id, pPlayer);
	}
	
	return PLUGIN_HANDLED;
}

exec_gag(pIniciator, pBanned)
{
	g_bVotedPlayers[pIniciator][pBanned] = true;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (i == pBanned)
			continue;
		
		client_print_color(i, pBanned, "%L %L", i, "VoteGag_prefix", i, "VoteGag_Vote", pIniciator, pBanned);
	}
	
	CA_Log(logLevel_Info, "[CA]: %N проголосовал за гаг против %N", pIniciator, pBanned);
	
	if (GetPercentageOfVotes(pBanned) > CVAR[PERCENTAGE])
	{
		ca_set_user_gag(pBanned, CVAR[REASON], CVAR[TIME], gagFlag_Voice);
		
		CA_Log(logLevel_Info, "[CA]: %N был заткнут вотегагом на %i минут, голосов против него: %i", pBanned, GetVotes(pBanned));
	}
}

public CA_gag_setted(const id, reason[], minutes, gag_flags_s: flags)
{
	if (~flags & gagFlag_Voice)
		return;
	
	for (new i, aSize = sizeof(g_bVotedPlayers[]); i < aSize; i++)
		g_bVotedPlayers[i][id] = false;
}

GetVotesByPlayer(id)
{
	new iVotes;
	
	for (new i, aSize = sizeof(g_bVotedPlayers[]); i < aSize; i++)
	{
		if (g_bVotedPlayers[id][i])
		{
			iVotes++;
		}
	}
	
	return iVotes;
}

GetVotes(id)
{
	new iVotes;
	
	for (new i, aSize = sizeof(g_bVotedPlayers[]); i < aSize; i++)
	{
		if (g_bVotedPlayers[i][id])
		{
			iVotes++;
		}
	}
	
	return iVotes;
}

GetPercentageOfVotes(id)
{
	return floatround(
		GetVotes(id) * 100.0 / get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV)
	);
}

Register_CVars()
{
	bind_pcvar_string(create_cvar(
		"ca_votegag_commands",
		"votegag /votegag /мщеупфп",
		.description = "Команды для открытия меню"),
		CVAR[CMDS], charsmax(CVAR[CMDS])
	);
	
	bind_pcvar_string(create_cvar(
		"ca_votegag_reason",
		"VoteGAG",
		.description = "Причина вотегага"),
		CVAR[REASON], charsmax(CVAR[REASON])
	);
	
	bind_pcvar_num(create_cvar(
		"ca_votegag_time",
		"30",
		.description = "Время вотегага"),
		CVAR[TIME]
	);
	
	bind_pcvar_num(create_cvar(
		"ca_votegag_percentage",
		"60",
		.description = "Сколько необходимо набрать процентов голосов для реализации гага"),
		CVAR[PERCENTAGE]
	);
	
	bind_pcvar_num(create_cvar(
		"ca_votegag_max_votes",
		"60",
		.description = "Сколько максимально может своершить голосов один игрок"),
		CVAR[MAX_VOTES]
	);
	
	bind_pcvar_num(create_cvar(
		"ca_votegag_min_players",
		"60",
		.description = "Минимальное допустимое кол-во игроков на сервере"),
		CVAR[MIN_PLAYERS]
	);
	
	// Выстави его в '^0' при не найденном звуке
	bind_pcvar_string(get_cvar_pointer(
		"ca_gag_sound_ok"),
		CVAR[SAMPLE_OK], charsmax(CVAR[SAMPLE_OK])
	)
	
	bind_pcvar_string(get_cvar_pointer(
		"ca_gag_sound_error"),
		CVAR[SAMPLE_ERROR], charsmax(CVAR[SAMPLE_ERROR])
	)
	
	AutoExecConfig(true, "CA_VoteGag", "ChatAdditions");
}


