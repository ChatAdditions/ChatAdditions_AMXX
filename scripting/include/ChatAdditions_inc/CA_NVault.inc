#if defined _CA_API_NVault_included
    #endinput
#endif

#define _CA_API_NVault_included

#include <nvault>
// #pragma dynamic 32768

new g_pNvault_Db;
	new const NVAULT_NAME[] = "ChatAdditions_API";

public Init_Storage()
{
	g_pNvault_Db = nvault_open(NVAULT_NAME);
	if(g_pNvault_Db == INVALID_HANDLE)
		set_fail_state("Couldn't open vault file '%s'", NVAULT_NAME);
	
	return true;
}

public Storage_Destroy() {
	nvault_close(g_pNvault_Db);
}


/** Storage Controllers -> */
public load_from_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	new szGagData[256], timestamp;
	new bFound = nvault_lookup(g_pNvault_Db, szAuthId, szGagData, charsmax(szGagData), timestamp);

	if(!bFound) {
		server_print("NVault()::load_from_storage() '%s' NOT FOUND in DB", szAuthId);
		return;
	}

	NVault_GagParse(szGagData, aGagData);

#if defined DEBUG
	DEBUG__Dump_GagData("NVault()::load_from_storage()", aGagData);
#endif
}


public save_to_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	static szGagData[256];
	formatex(szGagData, charsmax(szGagData), "%i.%i",
		aGagData[_bitFlags], aGagData[_ExpireTime]
	);

	// server_print("save_to_storage() -> szGagData='%s'", szGagData);

	nvault_set(g_pNvault_Db, szAuthId, szGagData);

#if defined DEBUG
	DEBUG__Dump_GagData("save_to_storage()", aGagData);
#endif
}

public remove_from_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	nvault_remove(g_pNvault_Db, szAuthId);
	server_print("NVault::remove_from_storage() authID:'%s'", szAuthId);
}

stock NVault_GagParse(szGagData[], aGagData[gag_s])
{
	new sFlags[3], sExpireTime[32];

	strtok(szGagData,
		sFlags, charsmax(sFlags),
		sExpireTime, charsmax(sExpireTime),
		'.', 1
	);

	aGagData[_bitFlags]		= gag_flags_s: strtol(sFlags);
	aGagData[_ExpireTime]	= strtol(sExpireTime);
}