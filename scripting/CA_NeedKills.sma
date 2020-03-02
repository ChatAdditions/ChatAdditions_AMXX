#include <amxmodx>
#include <hamsandwich>

#include <ChatsAdditions_API>

#if !defined MAX_PLAYERS
	const MAX_PLAYERS = 32;
#endif

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

const KILLS_NEED = 5;
new g_iKillsCount[MAX_PLAYERS + 1] = { KILLS_NEED, ... };

public plugin_init()
{
	register_plugin("Block Chat [Kills<5]", "0,01b", "wopox1337");
	RegisterHam(Ham_Killed, "player", "CBasePlayer_Killed", .Post = true, .specialbot = true);
}

public CBasePlayer_Killed(pPlayer, pKiller) {
	if(!is_user_connected(pKiller))
		return;

	if(--g_iKillsCount[pKiller] < 0)
		return;

	static szMsg[128];
	if(g_iKillsCount[pKiller] == 0)
		formatex(szMsg, charsmax(szMsg), "Your chat has been unlocked!");
	else formatex(szMsg, charsmax(szMsg), "To unlock chat %i kills left.", g_iKillsCount[pKiller]);
	
	client_print(pKiller, print_chat, szMsg);
}

public client_disconnected(pPlayer) {
	g_iKillsCount[pPlayer] = KILLS_NEED;
}

public CA_Client_Say(pPlayer) {
	return CanCommunicate(pPlayer) ? PLUGIN_CONTINUE : PLUGIN_HANDLED;
}

public CA_Client_SayTeam(pPlayer) {
	return CanCommunicate(pPlayer) ? PLUGIN_CONTINUE : PLUGIN_HANDLED;
}

public CA_Client_Voice(pPlayer, pOther) {
	return CanCommunicate(pPlayer) ? PLUGIN_CONTINUE : PLUGIN_HANDLED;
}

bool: CanCommunicate(pPlayer) {
	return g_iKillsCount[pPlayer] <= 0;
}