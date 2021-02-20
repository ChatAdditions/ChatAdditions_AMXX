/** Copyright © 2020 Sergey Shorokhov
 *
 * Chat Additions API include file.
 *
*/

#if defined _CA_API_included
	#endinput
#endif

#define _CA_API_included

#pragma reqlib ChatAdditions_Core
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib ChatAdditions_Core
#endif

#define CA_VERSION "%CA_VERSION%"

/**
* Return types
*/
enum
{
	CA_CONTINUE = 0, // Plugin didn't take any action
	CA_SUPERCEDE    // Skip real function, use my return value
};

#define CHECK_NATIVE_ARGS_NUM(%1,%2,%3) \
	if (%1 < %2) { \
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", %1, %2); \
		return %3; \
	}

#define CHECK_NATIVE_PLAYER(%1,%2) \
	if (!is_user_connected(%1)) { \
		log_error(AMX_ERR_NATIVE, "Invalid player %d", %1); \
		return %2; \
	}


const MAX_LOGLEVEL_LEN = 10;
enum LogLevel_s ( <<=1 ) {
	_Off = 0,
	_Info = 1,
	_Warnings,
	_Debug
}

stock LogLevel_s: ParseLogLevel(const sLogLevel[]) {
	new LogLevel_s: logFlags = _Off;
	for(new i; i < strlen(sLogLevel); i++) {
		switch(sLogLevel[i]) {
			case 'a': logFlags += _Info;
			case 'b': logFlags += _Warnings;
			case 'c': logFlags += _Debug;
		}
	}

	return LogLevel_s: logFlags;
}

enum _:LogType_s {
	_Default,
	_LogToDir
}

#define CA_Log(%0,%1) {\
	if(ca_log_level & %0) {\
		if(ca_log_type == _LogToDir) {\
    	    log_to_file(g_sLogsFile, %1);\
    	} else {\
    	    log_amx(%1);\
    	}\
	}\
}

stock GetLogsFilePath(sBuffer[], iLen = PLATFORM_MAX_PATH, const sDir[] = "ChatAdditions") {
	get_localinfo("amxx_logs", sBuffer, iLen);
	strcat(sBuffer, fmt("/%s", sDir), iLen);

	if(!dir_exists(sBuffer) && mkdir(sBuffer) == -1) {
		set_fail_state("[Core API] Can't create folder! (%s)", sBuffer);
	}

	new iYear, iMonth, iDay;
	date(iYear, iMonth, iDay);
	strcat(sBuffer, fmt("/L%i%02i%02i.log", iYear, iMonth, iDay), iLen);
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
 * @param listener   Receiver index.
 * @param sender   Sender index.
 *
 * @return      PLUGIN_CONTINUE to allow send voice
 *              PLUGIN_HANDLED or higher to prevent the voice
 */
forward CA_Client_Voice(const listener, const sender);