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


enum _:LogType_s {
    _Default,
	_LogToDir
}

#define CA_Log(%1) {\
	if(ca_log_type == _LogToDir) {\
        log_to_file(g_sLogsFile, %1);\
    } else {\
        log_amx(%1);\
    }\
}

stock GetLogsFilePath(sBuffer[], iLen = PLATFORM_MAX_PATH, const sDir[] = "ChatAdditions") {
    get_localinfo("amxx_logs", sBuffer, iLen);

    new iYear, iMonth, iDay;
    date(iYear, iMonth, iDay);
    strcat(sBuffer, fmt("/%s/L%i%02i%02i.log", sDir, iYear, iMonth, iDay), iLen);

    server_print("==============sLogsDir:'%s'", sBuffer);
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