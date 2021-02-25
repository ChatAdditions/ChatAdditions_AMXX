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


enum logLevel_s {
	logLevel_Off = 0,
	logLevel_Info = 1,
	logLevel_Warning,
	logLevel_Debug
}

#define register_trigger_clcmd(%0,%1) \
    for (new iter = 0; iter < sizeof(BASE_CHAT_TRIGGERS); iter++) \
    { \
        register_clcmd(fmt("%s%s", BASE_CHAT_TRIGGERS[iter], %0), %1); \
        register_clcmd(fmt("say %s%s", BASE_CHAT_TRIGGERS[iter], %0), %1); \
        register_clcmd(fmt("say_team %s%s", BASE_CHAT_TRIGGERS[iter], %0), %1); \
    }

new stock const BASE_CHAT_TRIGGERS[][] = { "", "/", "\", "!", "." };


/**
 * Log a message for every ChatAdditions module.
 *
 * @param level     Log level, see logLevel_* destination constants in ChatAdditions.inc
 * @param message   Formatting rules.
 * @param ...       Variable number of formatting parameters
 *
 * @return          True if a message logged, false otherwise.
 */

native bool: CA_Log(logLevel_s: level, const message[], any:...);

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
