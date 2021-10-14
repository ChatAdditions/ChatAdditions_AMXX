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

#if !defined CA_VERSION
  #define CA_VERSION "%CA_VERSION%"
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

new stock const BASE_CHAT_TRIGGERS[][] = { /* "",  */"/", "\", "!", "." };


stock parseTime(const value[]) {
  const _SECONDS_IN_MINUTE = 60;
  const _SECONDS_IN_HOUR = 3600;
  const _SECONDS_IN_DAY = 86400;
  const _SECONDS_IN_WEEK = 604800;
  const _SECONDS_IN_MONTH = _SECONDS_IN_DAY * 31;
  const _SECONDS_IN_YEAR = _SECONDS_IN_MONTH * 12;

  new t, k;
  for (new i; value[i] != EOS; i++) {
    switch (value[i]) {
      case '0'..'9': {
        t = (t * 10) + (value[i] - '0');
      }

      case 'i': {
        k += t * _SECONDS_IN_MINUTE;
        t = 0;
      }

      case 'h': {
        k += t * _SECONDS_IN_HOUR;
        t = 0;
      }

      case 'd': {
        k += t * _SECONDS_IN_DAY;
        t = 0;
      }

      case 'w': {
        k += t * _SECONDS_IN_WEEK;
        t = 0;
      }

      case 'm': {
        k += t * _SECONDS_IN_MONTH;
        t = 0;
      }

      case 'y': {
        k += t * _SECONDS_IN_YEAR;
        t = 0;
      }

      default: {
        break;
      }
    }
  }

  return k + t;
}

stock show_activity_ex(const actorId, const actorName[], const message[], any: ...) {
  enum { arg_format = 4 }

  static _amx_show_activity;
  if(!_amx_show_activity) {
    _amx_show_activity = get_cvar_pointer("amx_show_activity");
    if(!_amx_show_activity) {
      _amx_show_activity = create_cvar("amx_show_activity", "2");
    }
  }

  new prefix[] = "PLAYER";
  if(is_user_admin(actorId)) {
    copy(prefix, charsmax(prefix), "ADMIN");
  }

  static buffer[512];
  for(new i = 1; i <= MaxClients; i++) {
    if(!is_user_connected(i) && !is_user_bot(i)) {
      continue;
    }

    new bool: isAdmin = bool: is_user_admin(i);
    SetGlobalTransTarget(i);
    vformat(buffer, charsmax(buffer), message, arg_format);

    switch(get_pcvar_num(_amx_show_activity)) {
      case 1: { // Hide name for all
        client_print_color(i, i, "%L %s", i, prefix, buffer);
      }
      case 2: { // Show name to all
        client_print_color(i, i, "%L %s: %s", i, prefix, actorName, buffer);
      }
      case 3: { // show name only to admins, hide name from normal users
        client_print_color(i, i, "%L %s: %s", i, prefix, isAdmin ? actorName : "", buffer);
      }
      case 4: { // show name only to admins, show nothing to normal users
        if(isAdmin) {
          client_print_color(i, i, "%L %s: %s", i, prefix, actorName, buffer);
        }
      }
      case 5: { // show only to admins without actor name
        if(isAdmin) {
          client_print_color(i, i, "%L: %s", i, prefix, buffer);
        }
      }
    }
  }
}

stock FindPlayerByTarget(const buffer[]) {
  if(buffer[0] == '#' && buffer[1]) {
    return find_player_ex(FindPlayer_MatchUserId, strtol(buffer[1]));
  }

  new result = find_player_ex(FindPlayer_MatchAuthId, buffer);
  if (!result) {
    result = find_player_ex(FindPlayer_MatchIP, buffer);
  }

  if (!result) {
    result = find_player_ex(FindPlayer_MatchNameSubstring | FindPlayer_CaseInsensitive | FindPlayer_LastMatched, buffer);
  }

  return result;
}

stock UTIL_SendAudio(const id, const sample[]) {
  if(sample[0] == EOS) {
    return
  }

  static msgId_SendAudio
  if(!msgId_SendAudio) {
    msgId_SendAudio = get_user_msgid("SendAudio")
  }

  message_begin(MSG_ONE_UNRELIABLE, msgId_SendAudio, .player = id)
  write_byte(id)
  write_string(sample)
  write_short(PITCH_NORM)
  message_end()
}

stock UTIL_BarTime(const id, const time) {
  static msgId_BarTime
  if(!msgId_BarTime) {
    msgId_BarTime = get_user_msgid("BarTime")
  }

  message_begin(MSG_ONE_UNRELIABLE, msgId_BarTime, .player = id)
  write_short(time)
  message_end()
}


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
 * Called to determine if the Receiver has muted (blocked) the Sender.
 * NOTE: Setting from client menu (Players list -> Mute)
 *
 * @param receiver  Receiver client id.
 * @param sender    Sender client id.
 *
 * @return          Returns true if the receiver has blocked the sender
 */

native bool: CA_PlayerHasBlockedPlayer(const receiver, const sender);

/**
 * Called when player say to chat.
 *
 * @param index   Client index.
 *
 * @return      CA_CONTINUE to allow send message
 *              CA_SUPERCEDE or higher to prevent message
 */
forward CA_Client_Say(index);

/**
 * Called when player say to team chat.
 *
 * @param index   Client index.
 *
 * @return      CA_CONTINUE to allow send message
 *              CA_SUPERCEDE or higher to prevent message
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
 * @return      CA_CONTINUE to allow send voice
 *              CA_SUPERCEDE or higher to prevent the voice
 */
forward CA_Client_Voice(const listener, const sender);


/**
 * Called when player change nickname.
 *
 * @note
 *
 * @param id        Client index.
 * @param newName   New name.
 *
 * @return      CA_CONTINUE to allow change nickname
 *              CA_SUPERCEDE or higher to prevent
 */
forward CA_Client_ChangeName(const id, const newName[]);
