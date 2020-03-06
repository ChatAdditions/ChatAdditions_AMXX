/** Copyright © 2020 Sergey Shorokhov
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

/**
* Return types
*/
enum
{
	CA_CONTINUE = 0, // Plugin didn't take any action
	CA_SUPERCEDE    // Skip real function, use my return value
};

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