#include <amxmodx>
#include <CA_GAG_API>

#if AMXX_VERSION_NUM < 183
	#define client_disconnected client_disconnect
	#include <colorchat>
#endif


/* ======== SETTINGS ======== */
#define PREFIX 		"CA: VoteGAG" 	// Префикс сообщений в чате
#define REPEAT_VOTE_MIN	2		// Частота повторных голосований
#define PERCENT_VOTE_OK	60		// Процент голосов для успешного голосования
#define BLOCK_TIME_MIN	180		// Время GAG'a игрока
#define CHECK_VOTE_TIME	15.0		// Продолжительность голосования
const IMMUNITY_FLAGS = ADMIN_IMMUNITY; 	// Иммунитет к функциям VoteGAG'а
/* ======== LANG ======== */
#define MSG_PLMENU_TITLE "\d[\rVoteGag\d] \yВыберите игрока"
#define MSG_VMENU_TITLE "\d[\rVoteGag\d] \yЗаткнуть игрока \r%s\y?"
#define MSG_MENU_YES 	"\rДа"
#define MSG_MENU_NO 	"\yНет"
#define MSG_MENU_NEXT 	"\yДалее"
#define MSG_MENU_BACK	"\rНазад"
#define MSG_MENU_EXIT	"\rВыход"

#define MSG_VOTE_EXISTS		"^1[^4%s^1] ^4Голосование за ^1gag ^4игрока ^3уже запужено!"
#define MSG_VOTE_BLOCK		"^1[^4%s^1] ^4Голосование будет доступно через ^3%d сек."
#define MSG_VOTING_FAIL 	"^1[^4%s^1] ^4Голосование завершилось ^3неудачно^4. Недостаточно голосов ^1[^3%d^1/^3%d^1]"
#define MSG_VOTING_OK_ALL	"^1[^4%s^1] ^4Голосование завершилось ^3удачно^4. Игрок ^3%s ^4GAG'нут на ^3%d ^4мин."
#define MSG_VOTING_OK_PL 	"^1[^4%s^1] ^4Голосование за Ваш GAG завершилось ^3удачно^4. Вам отключены чаты на ^3%d ^4мин."
#define MSG_VOTING_DISC 	"^1[^4%s^1] ^4Игрок, за которого Вы запускали GAG голосование, покинул сервер"
/* ======== EndLANG ======== */


#if !defined MAX_PLAYERS
	const MAX_PLAYERS = 32;
#endif

new g_VotingMenu;
new g_iVotingIndex, g_iVotingLasttime;
new g_arrPlayers[MAX_PLAYERS], g_iPnum;
new bool:g_bPlayerVoted[MAX_PLAYERS + 1], g_iPlayersVotedCount;


public plugin_init()
{
	register_plugin("CA: VoteGAG", "1.0.0-alpha", "Sergey Shorokhov");

	register_clcmd("say /votegag", "clcmd_VoteGag");
	register_clcmd("say_team /votegag", "clcmd_VoteGag");
	register_clcmd("votegag", "clcmd_VoteGag")
}

public plugin_cfg()
{
	g_VotingMenu = menu_create("Title", "voting_handler");
	menu_setprop(g_VotingMenu, MPROP_EXIT, MEXIT_NEVER);
	menu_additem(g_VotingMenu, MSG_MENU_YES, "1");
	menu_additem(g_VotingMenu, MSG_MENU_NO, "0");
}

public client_disconnected(id)
{
	if(g_bPlayerVoted[id])
	{
		g_bPlayerVoted[id] = false;
		g_iPlayersVotedCount--;
	}
}

public clcmd_VoteGag(id)
{
	if(g_iVotingIndex)
	{
		ChatColor(id, 0, MSG_VOTE_EXISTS, PREFIX);
		return PLUGIN_HANDLED;
	}
	new time = g_iVotingLasttime + REPEAT_VOTE_MIN * 60 - get_systime();
	if(time > 0)
	{
		ChatColor(id, 0, MSG_VOTE_BLOCK, PREFIX, time % 60);
		return PLUGIN_HANDLED;
	}

	new szName[32], num[3], menu, callback;
	menu = menu_create(MSG_PLMENU_TITLE, "players_handler");
	callback = menu_makecallback("players_callback");

	menu_setprop(menu, MPROP_NEXTNAME, MSG_MENU_NEXT);
	menu_setprop(menu, MPROP_BACKNAME, MSG_MENU_BACK);
	menu_setprop(menu, MPROP_EXITNAME, MSG_MENU_EXIT);

	get_players(g_arrPlayers, g_iPnum, "h");

	for(new i; i < g_iPnum; i++)
	{
		if(g_arrPlayers[i] == id)
			continue;

		get_user_name(g_arrPlayers[i], szName, charsmax(szName));
		num_to_str(g_arrPlayers[i], num, charsmax(num));
		menu_additem(menu, szName, num, .callback = callback);
	}

	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public players_callback(id, menu, item)
{
	new _access, item_data[3], callback;
	menu_item_getinfo(menu, item, _access, item_data, charsmax(item_data), .callback = callback);

	new index = str_to_num(item_data);
	if(!is_user_connected(index))
		return ITEM_DISABLED;
	if(ca_has_user_gag(index))
		return ITEM_DISABLED;
	if(get_user_flags(index) & IMMUNITY_FLAGS)
		return ITEM_DISABLED;

	return ITEM_ENABLED;
}

public players_handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new _access, item_data[3], callback;
	menu_item_getinfo(menu, item, _access, item_data, charsmax(item_data), .callback = callback);
	g_iVotingIndex = str_to_num(item_data);
	menu_destroy(menu);

	new szTitle[128], szName[32];
	get_user_name(g_iVotingIndex, szName, charsmax(szName));

	formatex(szTitle, charsmax(szTitle), MSG_VMENU_TITLE, szName);
	menu_setprop(g_VotingMenu, MPROP_TITLE, szTitle);

	for(new i; i < g_iPnum; i++)
	{
		if(g_arrPlayers[i] == g_iVotingIndex)
			continue;

		if(is_user_connected(g_arrPlayers[i]))
			menu_display(g_arrPlayers[i], g_VotingMenu);
	}

	set_task(CHECK_VOTE_TIME, "task__CheckVotes", id);
	return PLUGIN_HANDLED;
}

public voting_handler(id, menu, item)
{
	if(item == MENU_EXIT)
		return PLUGIN_HANDLED;

	new _access, item_data[3], callback;
	menu_item_getinfo(menu, item, _access, item_data, charsmax(item_data), .callback = callback);

	if(str_to_num(item_data))
	{
		g_iPlayersVotedCount++;
		g_bPlayerVoted[id] = true;
	}
	return PLUGIN_HANDLED;
}

public task__CheckVotes(id)
{
	for(new i; i < g_iPnum; i++)
	{
		if(is_user_connected(g_arrPlayers[i]))
			show_menu(g_arrPlayers[i], 0, "^n");
	}

	new iVoteCount = floatround(g_iPnum  * PERCENT_VOTE_OK / 100.0);

	if(g_iPlayersVotedCount >= iVoteCount)
	{
		if(is_user_connected(g_iVotingIndex))
		{
      ca_set_user_gag(g_iVotingIndex, PREFIX, (BLOCK_TIME_MIN / 60), (gagFlag_Say | gagFlag_SayTeam | gagFlag_Voice));

			new szName[32];
			get_user_name(g_iVotingIndex, szName, charsmax(szName));
			ChatColor(0, g_iVotingIndex, MSG_VOTING_OK_ALL, PREFIX, szName, BLOCK_TIME_MIN);
			ChatColor(g_iVotingIndex, 0, MSG_VOTING_OK_PL, PREFIX, BLOCK_TIME_MIN);
		}
		else	ChatColor(id, 0, MSG_VOTING_DISC, PREFIX);
	}
	else	ChatColor(0, g_iVotingIndex, MSG_VOTING_FAIL, PREFIX, g_iPlayersVotedCount, iVoteCount);

	arrayset(g_bPlayerVoted, false, sizeof g_bPlayerVoted);
	g_iPlayersVotedCount = 0;
	g_iVotingIndex = 0;
	g_iVotingLasttime = get_systime();
}

stock ChatColor(id, id2, const szMessage[], any:...)
{
	new szMsg[190];
	vformat(szMsg, charsmax(szMsg), szMessage, 4);

	if(id)
	{
		client_print_color(id, print_team_default, szMsg);
	}
	else
	{
		new players[32], pnum;
		get_players(players, pnum, "c");
		for(new i; i < pnum; ++i)
		{
			if(players[i] != id2)
			{
				client_print_color(players[i], print_team_default, szMsg);
			}
		}
	}
}
