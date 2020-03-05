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


enum DB_Types { DB_NVault, DB_JSON, DB_MySQL, DB_SQLite };
new stock const DB_Names[DB_Types][] = { "DB_NVault", "DB_JSON", "DB_MySQL", "DB_SQLite" };

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

stock GagData_Reset(aGagData[gag_s])
{
	aGagData[_bitFlags] = m_REMOVED;
	aGagData[_Reason] = EOS;
	aGagData[_ExpireTime] = 0;
}

// Debug functions

#include <fakemeta>
#define SERVER_PRINT(%1) engfunc(EngFunc_ServerPrint, %1)

stock Print_Console(szBuffer[])
{
	for(new i; i < strlen(szBuffer); i+=255)
	{
		SERVER_PRINT(fmt("%-255s", szBuffer[i]));
	}
	SERVER_PRINT("\n");
}

stock DEBUG__Dump_GagData(from[], const aGagData[gag_s]) {
	new szBuffer[5028];
	formatex(szBuffer, charsmax(szBuffer), "[call %s] DEBUG__Dump_GagData() -> \n\
		\t Player = '%i'\n\
		\t AuthId = '%s'\n\
		\t IP = '%s'\n\
		\t Name = '%s'\n\
\
		\t AdminId = '%i'\n\
		\t AdminName = '%s'\n\
		\t AdminAuthId = '%s'\n\
		\t AdminIP = '%s'\n\
\
		\t Reason = '%s'\n\
		\t ExpireTime = '%i'\n\
		\t Flags = '%s'\n\
		", from,
		aGagData[_Player], aGagData[_AuthId], aGagData[_IP], aGagData[_Name],
		aGagData[_AdminId], aGagData[_AdminName], aGagData[_AdminAuthId],
		aGagData[_AdminIP], aGagData[_Reason], aGagData[_ExpireTime], bits_to_flags(aGagData[_bitFlags])
	);

	Print_Console(szBuffer);
}

stock DEBUG__Dump_GagFlags(const aGagData[gag_s]) {
	if(!aGagData[_bitFlags]) {
		Print_Console(" DEBUG_Dump_GagFlags() -> No have any flags.");
		return;
	}

	new szBuffer[5028];
	formatex(szBuffer, charsmax(szBuffer), "	DEBUG_Dump_GagFlags() -> #FOUND\n\
			\t Flags='%i'\n\
			\t Reason='%s'\n\
			\t Time='%i'",
			aGagData[_bitFlags], aGagData[_Reason], aGagData[_Reason]
		);
	
	Print_Console(szBuffer);
}


// API

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
 * @param listener   Receiver index.
 * @param sender   	 Sender index.
 *
 * @return      PLUGIN_CONTINUE to allow send voice
 *              PLUGIN_HANDLED or higher to prevent the voice
 */
forward CA_Client_Voice(const listener, const sender);

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
 *
 * @noreturn
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native ca_remove_user_gag(index);

/**
 * Get api storage type.
 *
 * @return Storage type
 * 
 */
native DB_Types: ca_get_storage_type();