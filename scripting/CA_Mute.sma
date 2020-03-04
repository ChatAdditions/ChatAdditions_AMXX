#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1
#pragma ctrlchar '\'

#include <ChatsAdditions_API>


#define get_bit(%1,%2)		(%1 & (1 << (%2 & 31)))
#define set_bit(%1,%2)		(%1 |= (1 << (%2 & 31)))
#define invert_bit(%1,%2)	(%1 ^= (1 << (%2 & 31)))
#define reset_bit(%1,%2)	(%1 &= ~(1 << (%2 & 31)))

new aMuted[MAX_PLAYERS + 1],
	g_iPlayerMenuPage[MAX_PLAYERS + 1],
	g_apPlayerMenuPlayers[MAX_PLAYERS + 1][32];

const PLAYERS_PER_PAGE = 7;

public plugin_init()
{
	register_plugin("[CA] Mute menu", "1.0.0-alpha", "Sergey Shorokhov");
	register_dictionary("CA_Mute.txt");
	register_menu("Players Mute Menu", 1023, "Menu_Handler_PlayersList", .outside = 1);

	Init_Cmds();
}

public ClCmd_Mute(pPlayer)
{
	Menu_Show_PlayersList(pPlayer, .iPage = 0);

	return PLUGIN_HANDLED;
}

public Menu_Show_PlayersList(pPlayer, iPage)
{
	if(iPage < 0)
		return PLUGIN_HANDLED;
	
	new aPlayersId[MAX_PLAYERS];
	new iCount, iPlayer;
	new szMenu[512], szName[MAX_NAME_LENGTH];

	get_players(aPlayersId, iCount);

	static i; i = min(iPage * PLAYERS_PER_PAGE, iCount);
	static iStart; iStart = i - (i % PLAYERS_PER_PAGE);
	static iEnd; iEnd = min(iStart + PLAYERS_PER_PAGE, iCount);

	iPage = iStart / PLAYERS_PER_PAGE;

	g_apPlayerMenuPlayers[pPlayer] = aPlayersId;
	g_iPlayerMenuPage[pPlayer] = iPage;

	static iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "%L\\R%i/%i\n\n", pPlayer, "CA_Mute_TITLE", iPage + 1, ((iCount - 1) / PLAYERS_PER_PAGE) + 1);

	new bitsKeys = MENU_KEY_0, iItem;

	for(i = iStart; i < iEnd; i++)
	{
		iPlayer = aPlayersId[i];

		if(pPlayer == iPlayer)
			continue;

		bitsKeys |= (1 << iItem);

		get_user_name(iPlayer, szName, charsmax(szName));
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\\r%i. \\w%s%s\n", ++iItem, szName, get_bit(aMuted[pPlayer], iPlayer) ? " (\\r+\\w)" : "" );
	}

	bitsKeys |= MENU_KEY_8;
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\n\n\\r8.\\w %L [\\r%L\\w]\n",
		pPlayer, "CA_Mute_MuteALL", pPlayer, AllMuted(pPlayer) ? "CA_Mute_ENABLED" : "CA_Mute_DISABLED"
	);

	if(iEnd < iCount)
	{
		bitsKeys |= MENU_KEY_9;
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\n \\r9.\\w%L\n \\r0. \\w%L", pPlayer, "CA_Mute_Next", pPlayer, iPage ? "CA_Mute_Back" : "CA_Mute_Exit");
	}
	else
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\n\\r0.\\w%L", pPlayer, iPage ? "CA_Mute_Back" : "CA_Mute_Exit");

	return show_menu(pPlayer, bitsKeys, szMenu, -1, "Players Mute Menu");
}

public Menu_Handler_PlayersList(pPlayer, iKey)
{
	switch (iKey)
	{
		case 7: 
		{
			MuteALL_Toggle(pPlayer);
			return Menu_Show_PlayersList(pPlayer, g_iPlayerMenuPage[pPlayer]);
		}
		case 8: return Menu_Show_PlayersList(pPlayer, ++g_iPlayerMenuPage[pPlayer]);
		case 9: return Menu_Show_PlayersList(pPlayer, --g_iPlayerMenuPage[pPlayer]);
	}

	Mute_Toggle(pPlayer, g_apPlayerMenuPlayers[pPlayer][(g_iPlayerMenuPage[pPlayer] * PLAYERS_PER_PAGE) + iKey]);

	Menu_Show_PlayersList(pPlayer, g_iPlayerMenuPage[pPlayer]);
	return PLUGIN_HANDLED;
}


public client_disconnected(pPlayer) {
	aMuted[pPlayer] = 0;
}

Mute_Toggle(pPlayer, pOther)
{
	if(!is_user_connected(pOther))
	{
		client_print(pPlayer, print_chat, "%L", pPlayer, "CA_Mute_PlayerNotAllowed", pOther);
		return;
	}

	invert_bit(aMuted[pPlayer], pOther);
	
	static szName[MAX_NAME_LENGTH];
	get_user_name(pOther, szName, charsmax(szName));

	client_print(pPlayer, print_chat, "%L", pPlayer, "CA_Mute_HasBeenMuted", szName, pPlayer, get_bit(aMuted[pPlayer], pOther) ? "CA_Mute_Muted" : "CA_Mute_UnMuted");
}

MuteALL_Toggle(pPlayer) {
	aMuted[pPlayer] = AllMuted(pPlayer) ? 0 : 0xFFFF;
}

bool: AllMuted(pPlayer) {
	return aMuted[pPlayer] == 0xFFFF;
}

public CA_Client_Voice(pPlayer, pOther)
	return get_bit(aMuted[pPlayer], pOther) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;



const MAX_CMD_LEN = 32;
new const g_szCmds[] = "mute";
new const szPreCmd[][] = {"say ", "say_team "/*, ""*/};
new const szCtrlChar[][] = {"!", "/", "\\", "." , "?", ""};
new const FUNC_NAME[] = "ClCmd_Mute";

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
}
