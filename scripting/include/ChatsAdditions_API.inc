/** Copyright © 2017 wopox1337
 *
 * Chat Additions API include file.
 *
*/

#if defined _Ca_API_included
	#endinput
#endif

#define _Ca_API_included

#pragma reqlib Chats_Additions_API
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib Chats_Additions_API
#endif


enum any: gag_flags_s ( <<=1 )
{
	m_REMOVED = 0,
	m_Say = 1,		// a
	m_SayTeam,		// b
	m_Voice			// c
}

const MAX_REASON_LEN = 128;

enum any: gag_s (+=1)
{
	_Player,
	_AuthId[32],
	_IP[32],
	_Name[32],

	_AdminId,
	_AdminName[MAX_NAME_LENGTH],
	_AdminAuthId[32],
	_AdminIP[32],

	_Reason[MAX_REASON_LEN],
	_ExpireTime,

	gag_flags_s: _bitFlags
}

// Debug functions
stock DEBUG__Dump_GagData(const aGagData[gag_s]) {
	server_print(" DEBUG__Dump_GagData() -> \n\
		Player = '%i'\n\
		AuthId = '%s'\n\
		IP = '%s'\n\
		AdminId = '%i'\n\
		AdminName = '%s'\n\
		AdminAuthId = '%s'\n\
		AdminIP = '%s'\n\
		Reason = '%s'\n\
		ExpireTime = '%i'\n\
		", aGagData[_Player], aGagData[_AuthId], aGagData[_IP],
		aGagData[_AdminId], aGagData[_AdminName], aGagData[_AdminAuthId],
		aGagData[_AdminIP], aGagData[_Reason], aGagData[_ExpireTime]
	);
}

stock DEBUG__Dump_GagFlags(const aGagData[gag_s]) {
	if(!aGagData[_bitFlags]) {
		server_print(" DEBUG_Dump_GagFlags() -> No have any flags.");
		return;
	}

	server_print("	DEBUG_Dump_GagFlags() -> #FOUND\n\
			\t Flags='%i'\n\
			\t Reason='%s'\n\
			\t Time='%i'",
			aGagData[_bitFlags], aGagData[_Reason], aGagData[_Reason]
		);
}

/**
 * Called when player say to chat.
 *
 * @param index   Client index.
 *
 * @return      PLUGIN_CONTINUE to allow send message
 *              PLUGIN_HANDLED or higher to prevent message
 */
forward CA_Client_Say(index);

/**
 * Called when player say to team chat.
 *
 * @param index   Client index.
 *
 * @return      PLUGIN_CONTINUE to allow send message
 *              PLUGIN_HANDLED or higher to prevent message
 */
forward CA_Client_SayTeam(index);


/**
 * Called when player begins to speak.
 *
 * @note 
 *
 * @param index   Receiver index.
 * @param pOther   Sender index.
 *
 * @return      PLUGIN_CONTINUE to allow send voice
 *              PLUGIN_HANDLED or higher to prevent the voice
 */
forward CA_Client_Voice(index, pOther);

/**
 * Sets client's gag data.
 *
 * @param index         Client index
 * @param aGagData      Gag data with gag_s
 *
 * @noreturn
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native ca_set_user_gag(index, aGagData[gag_s]);

/**
 * Remove client's gag data..
 *
 * @param index         Client index
 * @param aGagData      Gag data with gag_s
 *
 * @noreturn
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native ca_remove_user_gag(index);