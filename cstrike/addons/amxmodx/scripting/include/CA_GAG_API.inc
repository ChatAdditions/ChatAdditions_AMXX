/** Copyright © 2021 Sergey Shorokhov
 *
 * Chat Additions: Gag [API] include file.
 *
*/

#if defined _CA_GAG_API_included
  #endinput
#endif

#define _CA_GAG_API_included

enum any: gag_flags_s ( <<=1 ) {
  gagFlag_Removed = 0,
  gagFlag_Say = 1,  // a
  gagFlag_SayTeam,  // b
  gagFlag_Voice     // c
}

const MAX_REASON_LEN = 128;
const MAX_WHITELIST_CMD_LEN = 32;

enum reason_s {
  r_name[MAX_REASON_LEN],
  r_time,
  gag_flags_s: r_flags
}

enum gagData_s {
  gd_target,
  gd_name[MAX_NAME_LENGTH],
  gd_authID[MAX_AUTHID_LENGTH],
  gd_IP[MAX_IP_LENGTH],

  gd_admin,
  gd_adminName[MAX_NAME_LENGTH],
  gd_adminAuthID[MAX_AUTHID_LENGTH],
  gd_adminIP[MAX_IP_LENGTH],

  gd_reason[reason_s],
  gd_expireAt
}

stock gag_flags_s: flags_to_bit(const flagsStr[]) {
  new gag_flags_s: bits = gagFlag_Removed;

  if(containi(flagsStr, "a") != -1) bits |= gagFlag_Say;
  if(containi(flagsStr, "b") != -1) bits |= gagFlag_SayTeam;
  if(containi(flagsStr, "c") != -1) bits |= gagFlag_Voice;

  return bits;
}

stock bits_to_flags(const gag_flags_s: bits) {
  new flagsStr[4];
  if(bits & gagFlag_Say)      add(flagsStr, charsmax(flagsStr), "a");
  if(bits & gagFlag_SayTeam)  add(flagsStr, charsmax(flagsStr), "b");
  if(bits & gagFlag_Voice)    add(flagsStr, charsmax(flagsStr), "c");

  return flagsStr;
}

stock GagData_Reset(gagData[gagData_s]) {
  gagData[gd_target] = 0;
  gagData[gd_name][0] = EOS;
  gagData[gd_authID][0] = EOS;
  gagData[gd_IP][0] = EOS;

  gagData[gd_admin] = 0;
  gagData[gd_adminName][0] = EOS;
  gagData[gd_adminAuthID][0] = EOS;
  gagData[gd_adminIP][0] = EOS;

  gagData[gd_reason][r_name][0] = EOS;
  gagData[gd_reason][r_time] = 0;
  gagData[gd_reason][r_flags] = gagFlag_Removed;

  gagData[gd_expireAt] = 0;
}

stock GagData_Copy(to[gagData_s], const from[gagData_s]) {
  to[gd_target] = from[gd_target];
  copy(to[gd_name], charsmax(to[gd_name]), from[gd_name]);
  copy(to[gd_authID], charsmax(to[gd_authID]), from[gd_authID]);
  copy(to[gd_IP], charsmax(to[gd_IP]), from[gd_IP]);

  to[gd_admin] = from[gd_admin];
  copy(to[gd_adminName], charsmax(to[gd_adminName]), from[gd_adminName]);
  copy(to[gd_adminAuthID], charsmax(to[gd_adminAuthID]), from[gd_adminAuthID]);
  copy(to[gd_adminIP], charsmax(to[gd_adminIP]), from[gd_adminIP]);

  copy(to[gd_reason][r_name], charsmax(to[r_name]), from[gd_reason][r_name])
  to[gd_reason][r_time] = from[gd_reason][r_time]
  to[gd_reason][r_flags] = from[gd_reason][r_flags]

  to[gd_expireAt] = from[gd_expireAt];
}

stock bool: GagData_IsEqual(const arr1[gagData_s], const arr2[gagData_s]) {
  if(arr1[gd_reason][r_time] != arr2[gd_reason][r_time]) {
    return false;
  }

  if(arr1[gd_reason][r_flags] != arr2[gd_reason][r_flags]) {
    return false;
  }

  if(strcmp(arr1[gd_reason][r_name], arr2[gd_reason][r_name]) != 0) {
    return false;
  }

  return true;
}

stock GagData_GetPersonalData(const admin = 0, const target, buffer[gagData_s]) {
  // get's target data
  buffer[gd_target] = target;
  get_user_name(target, buffer[gd_name], charsmax(buffer[gd_name]));
  get_user_authid(target, buffer[gd_authID], charsmax(buffer[gd_authID]));
  get_user_ip(target, buffer[gd_IP], charsmax(buffer[gd_IP]), .without_port = true);

  // get's admin data
  buffer[gd_admin] = admin;
  get_user_name(admin, buffer[gd_adminName], charsmax(buffer[gd_adminName]));
  get_user_authid(admin, buffer[gd_adminAuthID], charsmax(buffer[gd_adminAuthID]));
  get_user_ip(admin, buffer[gd_adminIP], charsmax(buffer[gd_adminIP]), .without_port = true);
}





/**
 * Sets client's gag data.
 *
 * @param index         Client index
 * @param reason        Reason
 * @param Minutes       Minutes
 * @param Flags         Flags
 *
 * @noreturn
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native bool: ca_set_user_gag(const index, const reason[], const minutes, const gag_flags_s: flags);

/**
 * Get client's gag data.
 *
 * @param index       Client index
 * @param reason		  Gag reason
 * @param minutes			minutes
 * @param flags			  flags
 *
 * @return				      True if has Gag.
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native bool: ca_get_user_gag(const index, reason[], &minutes, &gag_flags_s: flags);

/**
 * Has client gag?
 *
 * @param index         Client index
 *
 * @return				      True if has Gag.
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native bool: ca_has_user_gag(const index);

/**
 * Remove client's gag data..
 *
 * @param target        Target Index
 * @param admin         Admin Index (0 - server)
 *
 * @return				      True if gag has been removed.
 * @error               If the client index is not within the range of 1 to
 *                      MaxClients, or the client is not connected, an error
 *                      will be thrown.
 */
native bool: ca_remove_user_gag(const target, admin = 0);

/**
 * Called on Gag save.
 *
 * @param target        Targed index
 * @param name          Targed name
 * @param authID        Targed AuthID
 * @param IP            Targed IP
 * @param adminName     Admin name
 * @param adminAuthID   Admin authID
 * @param adminIP       Admin IP
 * @param reason        Reason
 * @param time          Time (in seconds)
 * @param flags         Flags (chat, teamChat, voice)
 * @param expireAt      Time when gag expire
 *
 * @return              Return CA_SUPERCEDE for prevent Gag.
 */
forward CA_gag_setted(
  const target, name[], authID[], IP[],
  adminName[], adminAuthID[], adminIP[],
  reason[], time, gag_flags_s: flags,
  expireAt);

/**
 * Called on gag remove action.
 *
 * @param target    Target index
 * @param target    Reason
 * @param minutes   Time (in seconds)
 * @param flags     Flags (chat, teamChat, voice)
 *
 * @return              Return CA_SUPERCEDE for prevent Gag remove.
 */
forward CA_gag_removed(const target, reason[], minutes, gag_flags_s: flags);
