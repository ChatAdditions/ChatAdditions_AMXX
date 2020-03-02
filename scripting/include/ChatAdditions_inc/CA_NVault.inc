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

public Storage_Destroy()
	nvault_close(g_pNvault_Db);



/** Storage Controllers -> */
stock load_from_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	static szGagData[256];
	nvault_get(g_pNvault_Db, szAuthId, szGagData, charsmax(szGagData));
	/* nvault_get(g_pNvault_Db, szIP, aGagData, sizeof aGagData); */
	#pragma unused szIP
	
	// server_print("NVault_GetGag() -> szGagData(%i)='%s'", strlen(szGagData), szGagData);
	NVault_GagParse(szGagData, aGagData);
	
#if defined DEBUG
		DEBUG__Dump_GagFlags(aGagData);
#endif
}


stock save_to_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	static szGagData[256];
	formatex(szGagData, charsmax(szGagData), "%i.%i", aGagData[_bitFlags], aGagData[_Reason]);

	// server_print("save_to_storage() -> szGagData='%s'", szGagData);

	nvault_set(g_pNvault_Db, szAuthId, szGagData);

	#pragma unused szIP
	// nvault_set(g_pNvault_Db, szIP, aGagData);

#if defined DEBUG
	DEBUG__Dump_GagData("save_to_storage()", aGagData);
#endif
}

stock NVault_GagParse(szGagData[], aGagData[gag_s])
{
	static szFlags[3], szTime[32];

	strtok(szGagData,
		szFlags, charsmax(szFlags),
		szTime, charsmax(szTime),
		'.', 1
	);

	aGagData[_bitFlags]	= any: str_to_num(szFlags);
	aGagData[_Reason]		= str_to_num(szTime);

#if defined DEBUG2
	if(!aGagData[_bitFlags]) return 0;
	server_print("NVault_GagParse()-> _bitFlags=%i, _Reason=%i\nszGagData='%s'",
		aGagData[_bitFlags], aGagData[_Reason], szGagData);
#endif

	return 0;
}