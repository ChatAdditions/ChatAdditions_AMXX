#if defined _CA_API_NVault_included
    #endinput
#endif

#define _CA_API_NVault_included

#include <nvault>
#pragma dynamic 524288

new g_pNvault_Db;
new const NVAULT_NAME[] = "ChatAdditions_Gags";
const NVAULT_MAX_LEN = 256;

#define SAVE_TYPE _IP // _AuthId

static Float:g_fStartInitTime;
public plugin_cfg() {
	init_storage();
}

static init_storage() {
	g_pNvault_Db = nvault_open(NVAULT_NAME);
	if(g_pNvault_Db == INVALID_HANDLE)
		set_fail_state("Couldn't open NVault file '%s'", NVAULT_NAME);

	Storage_Inited(get_gametime() - g_fStartInitTime);
}

public plugin_end() {
	destroy_storage();
}
public destroy_storage() {
	nvault_close(g_pNvault_Db);
}

public load_from_storage(const aGagData[gag_s]) {
	new szGagData[NVAULT_MAX_LEN], timestamp;
	new bool:bFound = !!(nvault_lookup(g_pNvault_Db, aGagData[SAVE_TYPE], szGagData, charsmax(szGagData), timestamp));

	new target = aGagData[_Player];
	if(bFound)
		NVault_GagParse(szGagData, target);

	Storage_PlayerLoaded(get_user_userid(target), bFound);

	DEBUG__Dump_GagData("NVault::load_from_storage", g_aCurrentGags[target]);
}

public save_to_storage(const aGagData[gag_s]) {
	static szGagData[NVAULT_MAX_LEN];
	formatex(szGagData, charsmax(szGagData), "%i.%i",
		aGagData[_bitFlags], aGagData[_ExpireTime]
	);

	nvault_set(g_pNvault_Db, aGagData[SAVE_TYPE], szGagData);
	Storage_PlayerSaved(get_user_userid(aGagData[_Player]));
}

public remove_from_storage(const aGagData[gag_s]) {
	nvault_remove(g_pNvault_Db, aGagData[SAVE_TYPE]);
	DEBUG__Dump_GagData("NVault:remove_from_storage", aGagData);
	Storage_PlayerRemoved(get_user_userid(aGagData[_Player]));
}

stock NVault_GagParse(const szGagData[], const target) {
	new sFlags[3], sExpireTime[32];
	strtok(szGagData,
		sFlags, charsmax(sFlags),
		sExpireTime, charsmax(sExpireTime),
		'.', 1
	);

	g_aCurrentGags[target][_bitFlags]	= gag_flags_s: strtol(sFlags);
	g_aCurrentGags[target][_ExpireTime]	= strtol(sExpireTime);
}