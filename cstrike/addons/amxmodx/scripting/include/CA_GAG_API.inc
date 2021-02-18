/** Copyright © 2020 Sergey Shorokhov
 *
 * Chat Additions: Gag [API] include file.
 *
*/

#if defined _CA_GAG_API_included
	#endinput
#endif

#define _CA_GAG_API_included

#pragma reqlib ChatAdditions_GAG_API
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib ChatAdditions_GAG_API
#endif


#pragma semicolon 1
#pragma dynamic 524288

enum _:DB_Types { DB_NVault, DB_MySQL, DB_SQLite, DB_GameCMS };
new stock const DB_Names[DB_Types][] = { "DB_NVault", "DB_MySQL", "DB_SQLite", "DB_GameCMS" };

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
	_Name[MAX_NAME_LENGTH],

	_AdminId,
	_AdminName[MAX_NAME_LENGTH],
	_AdminAuthId[32],
	_AdminIP[32],

	_Reason[MAX_REASON_LEN],
	_Time,
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
	aGagData[_Player] = 0;
	aGagData[_AuthId][0] = EOS;
	aGagData[_IP][0] = EOS;
	aGagData[_Name][0] = EOS;
	
	aGagData[_AdminId] = 0;
	aGagData[_AdminName][0] = EOS;
	aGagData[_AdminAuthId][0] = EOS;
	aGagData[_AdminIP][0] = EOS;

	aGagData[_Reason][0] = EOS;
	aGagData[_Time] = 0;
	aGagData[_ExpireTime] = 0;

	aGagData[_bitFlags] = m_REMOVED;
}

stock GagData_Copy(to[gag_s], const from[gag_s]) {
	to[_Player] = from[_Player];
	copy(to[_AuthId], charsmax(to[_AuthId]), from[_AuthId]);
	copy(to[_IP], charsmax(to[_IP]), from[_IP]);
	copy(to[_Name], charsmax(to[_Name]), from[_Name]);
	
	to[_AdminId] = from[_AdminId];
	copy(to[_AdminName], charsmax(to[_AdminName]), from[_AdminName]);
	copy(to[_AdminAuthId], charsmax(to[_AdminAuthId]), from[_AdminAuthId]);
	copy(to[_AdminIP], charsmax(to[_AdminIP]), from[_AdminIP]);

	copy(to[_Reason], charsmax(to[_Reason]), from[_Reason]);
	to[_ExpireTime] = from[_ExpireTime];
	to[_Time] = from[_Time];

	to[_bitFlags] = from[_bitFlags];
}

bool: GagData_Equal(const arr1[gag_s], const arr2[gag_s]) {
	return (
		strcmp(arr1[_Reason], arr2[_Reason]) == 0
		/* || arr1[_Time] == arr2[_Time] */
		|| arr1[_bitFlags] == arr2[_bitFlags]
	);
}

GagData_GetPersonalData(const id = 0, const target, aGagData[gag_s]) {
	// get's target data
	aGagData[_Player] = target;
	get_user_authid(target, aGagData[_AuthId], charsmax(aGagData[_AuthId]));
	get_user_ip(target, aGagData[_IP], charsmax(aGagData[_IP]), .without_port = true);
	get_user_name(target, aGagData[_Name], charsmax(aGagData[_Name]));

	if(id == 0)
		return;

	// get's admin data
	aGagData[_AdminId] = id;
	get_user_name(id, aGagData[_AdminName], charsmax(aGagData[_AdminName]));
	get_user_authid(id, aGagData[_AdminAuthId], charsmax(aGagData[_AdminAuthId]));
	get_user_ip(id, aGagData[_AdminIP], charsmax(aGagData[_AdminIP]), .without_port = true);
}

// Debug functions
#if defined DEBUG
#include <fakemeta>
#define SERVER_PRINT(%1) engfunc(EngFunc_ServerPrint, %1)

stock Print_Console(szBuffer[]) {
	for(new i; i < strlen(szBuffer); i+=255) {
		SERVER_PRINT(fmt("%-255s", szBuffer[i]));
	}
	SERVER_PRINT("\n");
}

#pragma ctrlchar '\'
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
		\t Time = '%i'\n\
		\t ExpireTime = '%i'\n\
		\t Flags = '%s'\n\
		", from,
		aGagData[_Player], aGagData[_AuthId], aGagData[_IP], aGagData[_Name],
		aGagData[_AdminId], aGagData[_AdminName], aGagData[_AdminAuthId],
		aGagData[_AdminIP], aGagData[_Reason], aGagData[_Time], aGagData[_ExpireTime], bits_to_flags(aGagData[_bitFlags])
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

#pragma ctrlchar '^'
#endif




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
native ca_set_user_gag(index, const reason[], const time, const gag_flags_s: flags = (m_Say | m_SayTeam | m_Voice));

/**
 * Get client's gag data.
 *
 * @param index         Client index
 * @param reason		Gag reason
 * @param time			Time (in seconds)
 * @param flags			flags
 *
 * @return				True if has Gag.
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native bool: ca_get_user_gag(index, reason[], &time, &gag_flags_s: flags);

/**
 * Has client gag?
 *
 * @param index         Client index
 *
 * @return				True if has Gag.
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native bool: ca_has_user_gag(index);

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
native DB_Types: ca_get_gag_storage_type();
