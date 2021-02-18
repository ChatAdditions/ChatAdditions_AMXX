#if defined AMXX_182
	#endinput
#endif
#if defined _gamecms_user_settings
	#endinput
#endif
#define _gamecms_user_settings
#include <json>

#define MAX_CMS_SETTINGS_LENGTH 1024

new Trie:g_trhUserSettings;
new bool:g_bSettingsError;

FnGetUserSetting(id, szSettings[], szValue[], iLen)
{
	new szUserSettings[MAX_CMS_SETTINGS_LENGTH];
	if(!TrieGetString(g_trhUserSettings, g_szAuthIDs[id], szUserSettings, charsmax(szUserSettings)))
		return 0;

	new JSON:hjUserSettings;
	if(FnGetJsonParse(hjUserSettings, szUserSettings))
	{
		if(json_object_get_string(hjUserSettings, szSettings, szValue, iLen))
		{
			if(get_pcvar_num(cpCvarsData[Debug]) > 2)
				log_amx("FnGetUserSetting: settings (%s), value (%s)", szSettings, szValue);
			json_free(hjUserSettings);
			return 1;
		}
	}

	json_free(hjUserSettings);
	return 0;
}

FnSetUserSetting(id, szSettings[], szValue[], bool:delete)
{
	new szUserSettings[MAX_CMS_SETTINGS_LENGTH];
	new JSON:hjUserSettings;
	new bool:bStatus;
	if(TrieGetString(g_trhUserSettings, g_szAuthIDs[id], szUserSettings, charsmax(szUserSettings)))
	{
		FnGetJsonParse(hjUserSettings, szUserSettings);
	}
	else
	{
		hjUserSettings = json_init_object();

		if(get_pcvar_num(cpCvarsData[Debug]) > 2)
			log_amx("FnSetUserSetting JSON json_init_object %d", hjUserSettings);

		if(hjUserSettings == Invalid_JSON)
		{
			if(get_pcvar_num(cpCvarsData[Debug]) > 2)
				log_amx("FnSetUserSetting JSON error");
			return bStatus;
		}
	}

	bStatus = delete ? json_object_remove(hjUserSettings, szSettings) : json_object_set_string(hjUserSettings, szSettings, szValue);

	if(json_serial_size(hjUserSettings) > 5)
	{
		json_serial_to_string(hjUserSettings, szUserSettings, charsmax(szUserSettings));
	}
	else
	{
		szUserSettings[0] = EOS;
	}

	TrieSetString(g_trhUserSettings, g_szAuthIDs[id], szUserSettings);

	if(get_pcvar_num(cpCvarsData[Debug]) > 2)
		log_amx("FnSetUserSetting: settings (%s), value (%s) delete: %d | string %s", szSettings, szValue, delete, szUserSettings);
	
	json_free(hjUserSettings);
	return bStatus;
}

FnGetJsonParse(&JSON:hjUserSettings, szUserSettings[])
{
	hjUserSettings = json_parse(szUserSettings);
	if(hjUserSettings == Invalid_JSON)
	{
		if(get_pcvar_num(cpCvarsData[Debug]) > 2)
			log_amx("FnGetUserSetting JSON error");
		return 0;
	}
	
	return 1;
}