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
		if(!aGagData[_bitFlags]) return;
		server_print("	NVault_GetGag('%s', '%s') -> #FOUND\n\
			\t Flags='%i'\n\
			\t Reason='%s'\n\
			\t Time='%i'", szAuthId, szIP,
			aGagData[_bitFlags], aGagData[_Reason], aGagData[_Reason]
		);
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
	// LOG DAT FKIN BUGGY ARRAYS! ;(

	server_print(" save_to_storage() -> \n\
		aGagData[_Player] = '%i'\n\
		aGagData[_AuthId] = '%s'\n\
		aGagData[_IP] = '%s'\n\
		aGagData[_AdminId] = '%i'\n\
		aGagData[_AdminName] = '%s'\n\
		aGagData[_AdminAuthId] = '%s'\n\
		aGagData[_AdminIP] = '%s'\n\
		aGagData[_Reason] = '%s'\n\
		aGagData[_ExpireTime] = '%i'\n\
		", aGagData[_Player], aGagData[_AuthId], aGagData[_IP],
		aGagData[_AdminId], aGagData[_AdminName], aGagData[_AdminAuthId],
		aGagData[_AdminIP], aGagData[_Reason], aGagData[_ExpireTime]
	);

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