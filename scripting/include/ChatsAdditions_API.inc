/** Copyright © 2017 wopox1337
 *
 * Chat Additions API include file.
 *
*/

#if defined _Ca_API_included
	#endinput
#endif

#define _Ca_API_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib Chats_Additions_API
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib Chats_Additions_API
	#endif
#else
	#pragma library Chats_Additions_API
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