#include <amxmodx>
#include <reapi>

#include <ChatsAdditions>


#pragma semicolon 1
#pragma ctrlchar '\'

new g_pFwd_Client_Say,
	g_pFwd_Client_SayTeam,
	g_pFwd_Client_Voice;

public plugin_precache()
{
	register_plugin(
		.plugin_name	= "Chats Additions Core",
		.version		= "1.0.0-beta",
		.author			= "Sergey Shorokhov"
	);

	register_clcmd("say", "ClCmd_Hook_Say");
	register_clcmd("say_team", "ClCmd_Hook_SayTeam");
	RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "CSGameRules_CanPlayerHearPlayer", .post = false);

	g_pFwd_Client_Say = CreateMultiForward("CA_Client_Say", ET_STOP, FP_CELL);
	g_pFwd_Client_SayTeam = CreateMultiForward("CA_Client_SayTeam", ET_STOP, FP_CELL);
	g_pFwd_Client_Voice = CreateMultiForward("CA_Client_Voice", ET_STOP, FP_CELL, FP_CELL);
}

public plugin_natives() {
	register_library("ChatAdditions_Core");
}

public ClCmd_Hook_Say(id) {
	static retVal;
	ExecuteForward(g_pFwd_Client_Say, retVal, id);

	return (retVal == CA_SUPERCEDE) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}

public ClCmd_Hook_SayTeam(id) {
	static retVal;
	ExecuteForward(g_pFwd_Client_SayTeam, retVal, id);

	return (retVal == CA_SUPERCEDE) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}

public CSGameRules_CanPlayerHearPlayer(const listener, const sender) {
	if(listener == sender)
		return HC_CONTINUE;

	static retVal;
	ExecuteForward(g_pFwd_Client_Voice, retVal, listener, sender);

	if(retVal == CA_SUPERCEDE) {
		SetHookChainReturn(ATYPE_BOOL, false);

		return HC_BREAK;
	}

	return HC_CONTINUE;
}