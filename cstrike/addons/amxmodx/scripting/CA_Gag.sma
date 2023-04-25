#include <amxmodx>
#include <amxmisc>
#include <time>

#include <ChatAdditions>
#include <CA_GAG_API>
#include <CA_StorageAPI>

#pragma ctrlchar '\'
#pragma dynamic 524288
#pragma tabsize 2


  /* ----- START SETTINGS ----- */
const Float: GAG_THINKER_FREQ = 3.0
  /* ----- END OF SETTINGS ----- */

static g_currentGags[MAX_PLAYERS + 1][gagData_s]
static g_adminTempData[MAX_PLAYERS + 1][gagData_s]
static bool: g_inEditMenu[MAX_PLAYERS + 1] // HACK: need for transmit data per menus

static Array: g_gagReasonsTemplates, g_gagReasonsTemplates_size
static Array: g_gagTimeTemplates, g_gagTimeTemplates_size
static Array: g_chatWhitelistCmds, g_chatWhitelistCmds_size

new ca_gag_times[64],
  ca_gag_immunity_flags[16],
  ca_gag_access_flags[16],
  ca_gag_access_flags_own_reason[16],
  ca_gag_access_flags_own_time[16],
  ca_gag_access_flags_high[16],
  ca_gag_remove_only_own_gag,
  ca_gag_sound_ok[128],
  ca_gag_sound_error[128],
  bool: ca_gag_block_nickname_change,
  bool: ca_gag_block_admin_chat,
  bool: ca_gag_common_chat_block,
  ca_gag_own_reason_enabled

new g_dummy, g_itemInfo[64], g_itemName[128]

enum {
  ITEM_ENTER_GAG_REASON = -1,
  ITEM_ENTER_GAG_TIME = -2,
  ITEM_CONFIRM = -3,
  ITEM_REASON = -4,
}

new g_fwd_gag_setted,
  g_fwd_gag_removed,
  g_ret

new const g_adminChatCmds[][] = {
  "amx_say", "amx_asay", "amx_chat", "amx_psay",
  "amx_teamsay", "amx_bsay", "amx_bsay2", "amx_csay",
  "amx_csay2", "amx_rsay", "amx_rsay2", "amx_tsay",
  "amx_tsay2"
}

new const g_gagCmd[] = "gag"
new const g_unGagCmd[] = "ungag"

public stock const PluginName[] = "CA: Gag"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "https://github.com/ChatAdditions/"
public stock const PluginDescription[] = "Manage player chats for the admin."

public plugin_precache() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)

  register_dictionary("CA_Gag.txt")
  register_dictionary("common.txt")
  register_dictionary("time.txt")

  register_srvcmd("ca_gag_add_reason", "SrvCmd_AddReason")
  register_srvcmd("ca_gag_show_templates", "SrvCmd_ShowTemplates")
  register_srvcmd("ca_gag_add_chat_whitelist_cmd", "SrvCmd_AddWhitelistCmd")
  register_srvcmd("ca_gag_reload_config", "SrvCmd_ReloadConfig")

  Create_CVars()

  g_gagReasonsTemplates = ArrayCreate(reason_s)
  g_gagTimeTemplates = ArrayCreate()
  g_chatWhitelistCmds = ArrayCreate(MAX_WHITELIST_CMD_LEN)

  LoadConfig()

  if(ca_gag_sound_ok[0] != EOS && file_exists(fmt("sounds/%s", ca_gag_sound_ok))) {
    precache_sound(ca_gag_sound_ok)
  }

  if(ca_gag_sound_error[0] != EOS && file_exists(fmt("sounds/%s", ca_gag_sound_error))) {
    precache_sound(ca_gag_sound_error)
  }
}

public plugin_init() {
  set_task_ex(GAG_THINKER_FREQ, "Gags_Thinker", .flags = SetTask_Repeat)

  new accessFlagsHigh       = read_flags(ca_gag_access_flags_high)
  new accessFlags           = read_flags(ca_gag_access_flags)
  new accessFlagsOwnReason  = read_flags(ca_gag_access_flags_own_reason)
  new accessFlagsOwnTime    = read_flags(ca_gag_access_flags_own_time)

  register_clcmd("enter_GagReason", "ClCmd_EnterGagReason", (accessFlagsHigh | accessFlagsOwnReason), .FlagManager = false)
  register_clcmd("enter_GagTime", "ClCmd_EnterGagTime", (accessFlagsHigh | accessFlagsOwnTime), .FlagManager = false)

  register_concmd("amx_gag", "ConCmd_amx_gag", accessFlagsHigh, "Usage: amx_gag [nickname | STEAM_ID | userID | IP] <reason> <time> <flags>", .FlagManager = false)

  new const CMDS_GAG[][] = { "gag" }

  for(new i; i < sizeof(CMDS_GAG); i++) {
    register_trigger_clcmd(CMDS_GAG[i], "ClCmd_Gag", (accessFlags | accessFlagsHigh), .FlagManager = false)
  }

  register_clcmd("amx_gagmenu", "ClCmd_Gag", (accessFlags | accessFlagsHigh), .FlagManager = false)

  for(new i; i < sizeof g_adminChatCmds; i++)
    register_clcmd(g_adminChatCmds[i], "ClCmd_adminSay", ADMIN_CHAT)

  CA_Log(logLevel_Debug, "[CA]: Gag initialized!")

  Register_Forwards()
}

public plugin_end() {
  DestroyForward(g_fwd_gag_setted)
  DestroyForward(g_fwd_gag_removed)
}

Create_CVars() {
  bind_pcvar_string(create_cvar("ca_gag_times", "1i, 5i, 10i, 30i, 1h, 1d, 1w, 1m",
      .description = "Gag time values for choose\n \
        format: 1 = 1 second, 1i = 1 minute, 1h = 1 hour, 1d = 1 day, 1w = 1 week, 1m = 1 month, 1y = 1 year\n \
        NOTE: Changes will be applied only after reloading the map (or command `ca_gag_reload_config`)"
    ),
    ca_gag_times, charsmax(ca_gag_times)
  )

  bind_pcvar_string(create_cvar("ca_gag_immunity_flags", "a",
      .description = "User immunity flag\n users with this flag can't be gagged\n \
        NOTE: `ca_gag_access_flags_high` can gag this users"
    ),
    ca_gag_immunity_flags, charsmax(ca_gag_immunity_flags)
  )

  bind_pcvar_string(create_cvar("ca_gag_access_flags", "c",
      .description = "Admin flag\n \
        users with this flag can gag users with flag `z`, but can't with flag `ca_gag_immunity_flags`\n \
        users with this flag can't be gagged by same flags users (immunity)\n \
        NOTE: `ca_gag_access_flags_high` can gag this users"
    ),
    ca_gag_access_flags, charsmax(ca_gag_access_flags)
  )

  bind_pcvar_string(create_cvar("ca_gag_access_flags_own_reason", "d",
      .description = "Admin flag\n \
        users with this flag can enter their own gag reason"
    ),
    ca_gag_access_flags_own_reason, charsmax(ca_gag_access_flags_own_reason)
  )

  bind_pcvar_string(create_cvar("ca_gag_access_flags_own_time", "e",
      .description = "Admin flag\n \
        users with this flag can enter their own gag time"
    ),
    ca_gag_access_flags_own_time, charsmax(ca_gag_access_flags_own_time)
  )

  bind_pcvar_string(create_cvar("ca_gag_access_flags_high", "l",
      .description = "High admin flag\n \
        users with this flag can everyone\n \
        users with this flag can't be gagged\n \
        NOTE: `ca_gag_access_flags_high` can gag this users"
    ),
    ca_gag_access_flags_high, charsmax(ca_gag_access_flags_high)
  )

  bind_pcvar_num(create_cvar("ca_gag_remove_only_own_gag", "1",
      .description = "Remove gag access control\n \
        1 = remove only own gags\n \
        0 = no restrictions\n \
        NOTE: `ca_gag_access_flags_high` can remove every gag"
    ),
    ca_gag_remove_only_own_gag
  )

  get_pcvar_string(create_cvar("ca_gag_sound_ok", "buttons/blip2.wav",
      .description = "Sound for success action\n \
        NOTE: Changes will be applied only after reloading the map"
    ),
    ca_gag_sound_ok, charsmax(ca_gag_sound_ok)
  )

  get_pcvar_string(create_cvar("ca_gag_sound_error", "buttons/button2.wav",
      .description = "Sound for error action\n \
        NOTE: Changes will be applied only after reloading the map"
    ),
    ca_gag_sound_error, charsmax(ca_gag_sound_error)
  )

  bind_pcvar_num(create_cvar("ca_gag_block_nickname_change", "1",
      .description = "Block nickname change for gagged player\n \
        0 = no restrictions"
    ),
    ca_gag_block_nickname_change
  )

  bind_pcvar_num(create_cvar("ca_gag_block_admin_chat", "1",
      .description = "Also block adminchat if admin gagged\n \
        0 = no restrictions"
    ),
    ca_gag_block_admin_chat
  )

  bind_pcvar_num(create_cvar("ca_gag_common_chat_block", "1",
      .description = "Don't separate `say` & `say_team` chats\n \
        0 = disabled"
    ),
    ca_gag_common_chat_block
  )

  bind_pcvar_num(create_cvar("ca_gag_own_reason_enabled", "1",
      .description = "Enable own gag reason\n \
        0 = disabled (excluding when there are no reasons)\n \
        1 = enabled, at first position in reasons list\n \
        2 = enabled, at last position in reasons list"
    ),
    ca_gag_own_reason_enabled
  )
}

public client_putinserver(id) {
  if(is_user_bot(id) || is_user_hltv(id)) {
    return
  }

  new authID[MAX_AUTHID_LENGTH]; get_user_authid(id, authID, charsmax(authID))
  CA_Storage_Load(authID)
}

public client_disconnected(id) {
  GagData_Reset(g_adminTempData[id])
  GagData_Reset(g_currentGags[id])

  g_inEditMenu[id] = false
}

public Gags_Thinker() {
  static players[MAX_PLAYERS], count
  get_players_ex(players, count, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV))

  static currentTime; currentTime = get_systime()

  for(new i; i < count; i++) {
    new id = players[i]

    new expireAt = g_currentGags[id][gd_expireAt]
    new bool: hasGag = (expireAt != 0)

    if(hasGag && expireAt < currentTime) {
      Gag_Expired(id)
    }
  }
}


/*
 * @section Menus
 */

// Players list menu
static MenuShow_PlayersList(const id, const nickname[] = "") {
  GagData_Reset(g_adminTempData[id])

  g_inEditMenu[id] = false

  if(!is_user_connected(id)) {
    return
  }

  new nameLen
  new GetPlayersFlags: flags = (GetPlayers_ExcludeHLTV | GetPlayers_ExcludeBots)

  if(nickname[0] != EOS) {
    flags |= (GetPlayers_MatchNameSubstring | GetPlayers_CaseInsensitive)
    nameLen = strlen(nickname)
  }

  new players[MAX_PLAYERS], count
  get_players_ex(players, count, flags, nickname)

  if(count == 0) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")
    return
  }

  new menu = menu_create(fmt("%L \\r%s\\y", id, "Gag_MenuTitle_PlayersList", nickname), "MenuHandler_PlayersList")

  static callback

  if(!callback) {
    callback = menu_makecallback("MenuCallback_PlayersList")
  }

  for(new i; i < count; i++) {
    new target = players[i]

    if(target == id) {
      continue
    }

    new name[MAX_NAME_LENGTH + 16]
    get_user_name(target, name, charsmax(name))

    if(nameLen > 0) {
      new found = strfind(name, nickname, true)

      if(found != -1) {
        replace_stringex(name, charsmax(name),
          nickname, fmt("\\r%s\\w", nickname),
          .caseSensitive = false
        )
      }
    }

    new bool: hasImmunity = IsTargetHasImmunity(id, target)
    menu_additem(menu, fmt("%s %s", name, Get_PlayerPostfix(id, target, hasImmunity)), fmt("%i", get_user_userid(target)), .callback = callback)
  }

  menu_setprop(menu, MPROP_SHOWPAGE, false)

  menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
  menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)
}

public MenuCallback_PlayersList(const id, const menu, const item) {
  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)

  new userID = strtol(g_itemInfo)

  new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), userID)

  if(target == 0) {
    return ITEM_DISABLED
  }

  new bool: hasImmunity = IsTargetHasImmunity(id, target)

  if(hasImmunity) {
    return ITEM_DISABLED
  }

  return ITEM_ENABLED
}

public MenuHandler_PlayersList(const id, const menu, const item) {
  if(item == MENU_EXIT || item < 0) {
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)
  menu_destroy(menu)

  new userID = strtol(g_itemInfo)

  new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), userID)

  if(target == 0) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  // Remove already gagged player
  if(g_currentGags[target][gd_reason][r_flags] != gagFlag_Removed) {
    GagData_Copy(g_adminTempData[id], g_currentGags[target])

    g_adminTempData[id][gd_target] = target

    MenuShow_ShowGag(id)
    return PLUGIN_HANDLED
  }

  // Setup gag for target player
  GagData_GetPersonalData(id, target, g_adminTempData[id])

  MenuShow_SelectReason(id)
  return PLUGIN_HANDLED
}

// Reason choose menu
static MenuShow_SelectReason(const id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]
  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new menu = menu_create(fmt("%L [\\r%s\\y]", id, "Gag_MenuTitle_SelectReason", g_adminTempData[id][gd_name]), "MenuHandler_SelectReason")

  new playerFlags           = get_user_flags(id)
  new accessFlagsHigh       = read_flags(ca_gag_access_flags_high)
  new accessFlagsOwnReason  = read_flags(ca_gag_access_flags_own_reason)

  new bool: hasReasonsTemplates = bool: (g_gagReasonsTemplates_size != 0)

  if(ca_gag_own_reason_enabled == 1 && playerFlags & (accessFlagsHigh | accessFlagsOwnReason) || !hasReasonsTemplates) {
    menu_additem(menu, fmt("%L\n", id, "Gag_EnterReason"), fmt("%i", ITEM_ENTER_GAG_REASON))
  }

  if(hasReasonsTemplates) {
    for(new i; i < g_gagReasonsTemplates_size; i++) {
      new reason[reason_s]
      ArrayGetArray(g_gagReasonsTemplates, i, reason)

      new buffer[2048]
      formatex(buffer, charsmax(buffer), reason[r_name])

      new bool: reasonHasTime, bool: reasonHasFlags

      if(reason[r_time] > 0) {
        reasonHasTime = true
      }

      if(reason[r_flags] != gagFlag_Removed) {
        reasonHasFlags = true
      }

      if(reasonHasTime) {
        strcat(buffer, fmt(" (\\y%s", Get_TimeString_seconds(id, reason[r_time])), charsmax(buffer))
      }

      if(reasonHasFlags) {
        strcat(buffer, fmt("%s%s", reasonHasTime ? ", " : " \\y(", bits_to_flags(reason[r_flags])), charsmax(buffer))
      }

      if(reasonHasTime || reasonHasFlags) {
        strcat(buffer, "\\w)", charsmax(buffer))
      }

      menu_additem(menu, buffer,  fmt("%i", i))
    }

    if(ca_gag_own_reason_enabled == 2 && playerFlags & (accessFlagsHigh | accessFlagsOwnReason)) {
      menu_additem(menu, fmt("%L\n", id, "Gag_EnterReason"), fmt("%i", ITEM_ENTER_GAG_REASON))
    }
  } else {
    menu_addtext(menu, fmt("\\d		%L", id, "Gag_NoTemplatesAvailable_Reasons"), .slot = false)
  }

  menu_setprop(menu, MPROP_SHOWPAGE, false)

  menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
  menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "Gag_BackToPlayersMenu"))

  menu_display(id, menu)
  return PLUGIN_HANDLED
}

public MenuHandler_SelectReason(const id, const menu, const item) {
  if(item == MENU_EXIT || item < 0) {
    // Return to prev menu
    MenuShow_PlayersList(id)

    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)
  menu_destroy(menu)

  new reasonID = strtol(g_itemInfo)

  if(reasonID == ITEM_ENTER_GAG_REASON) {
    client_cmd(id, "messagemode enter_GagReason")
    return PLUGIN_HANDLED
  }

  new reason[reason_s]
  ArrayGetArray(g_gagReasonsTemplates, reasonID, reason)

  // Get predefined reason params
  g_adminTempData[id][gd_reason] = reason

  // Time not set
  if(reason[r_time] == 0) {
    MenuShow_SelectTime(id)
    return PLUGIN_HANDLED
  }

  if(g_inEditMenu[id]) {
    MenuShow_EditGag(id)
    return PLUGIN_HANDLED
  }

  if(reason[r_flags] == gagFlag_Removed) {
    MenuShow_SelectFlags(id)
    return PLUGIN_HANDLED
  }

  Gag_Save(id, target, reason[r_time], reason[r_flags])
  GagData_Reset(g_adminTempData[id])

  return PLUGIN_HANDLED
}

// Time choose menu
static MenuShow_SelectTime(const id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new menu = menu_create(fmt("%L", id, "Gag_MenuTitle_SelectTime"), "MenuHandler_SelectTime")

  new playerFlags         = get_user_flags(id)
  new accessFlagsHigh     = read_flags(ca_gag_access_flags_high)
  new accessFlagsOwnTime  = read_flags(ca_gag_access_flags_own_time)

  if(playerFlags & (accessFlagsHigh | accessFlagsOwnTime)) {
    menu_additem(menu, fmt("%L", id, "Gag_EnterTime"), fmt("%i", ITEM_ENTER_GAG_TIME))
    menu_addblank(menu, .slot = false)
  }

  if(g_gagTimeTemplates_size) {
    for(new i; i < g_gagTimeTemplates_size; i++) {
      new time = ArrayGetCell(g_gagTimeTemplates, i)

      menu_additem(menu, fmt("%s", Get_TimeString_seconds(id, time)), fmt("%i", i))
    }
  } else {
    menu_addtext(menu, fmt("\\d		%L", id, "Gag_NoTemplatesAvailable_Times"), .slot = false)
  }

  menu_setprop(menu, MPROP_SHOWPAGE, false)

  menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
  menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)
  return PLUGIN_HANDLED
}

public MenuHandler_SelectTime(const id, const menu, const item) {
  if(item == MENU_EXIT || item < 0) {
    MenuShow_PlayersList(id)

    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)
  menu_destroy(menu)

  new timeID = strtol(g_itemInfo)

  if(timeID == ITEM_ENTER_GAG_TIME) {
    client_cmd(id, "messagemode enter_GagTime")
    return PLUGIN_HANDLED
  }

  new time = ArrayGetCell(g_gagTimeTemplates, timeID)
  g_adminTempData[id][gd_reason][r_time] = time

  if(g_inEditMenu[id]) {
    MenuShow_EditGag(id)
    return PLUGIN_HANDLED
  }

  MenuShow_SelectFlags(id)
  return PLUGIN_HANDLED
}

// Select flags menu
static MenuShow_SelectFlags(const id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new menu = menu_create(fmt("%L", id, "Gag_SelectFlags", target), "MenuHandler_SelectFlags")

  static callback

  if(!callback) {
    callback = menu_makecallback("MenuCallback_SelectFlags")
  }

  new gag_flags_s: gagFlags = g_adminTempData[id][gd_reason][r_flags]

  menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropSay",
    (gagFlags & gagFlag_Say) ? " \\r+\\w " : "-"),
    fmt("%i", gagFlag_Say)
  )
  if(!ca_gag_common_chat_block) {
    menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropSayTeam",
      (gagFlags & gagFlag_SayTeam) ? " \\r+\\w " : "-"),
      fmt("%i", gagFlag_SayTeam)
    )
  }
  menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropVoice",
    (gagFlags & gagFlag_Voice) ? " \\r+\\w " : "-"),
    fmt("%i", gagFlag_Voice)
  )

  menu_addblank(menu, .slot = false)

  menu_additem(menu, fmt("%L", id, "Gag_MenuItem_Confirm"), fmt("%i", ITEM_CONFIRM), .callback = callback)

  menu_addtext(menu, fmt("\n%L", id, "Gag_MenuItem_Resolution",
    Get_TimeString_seconds(id, g_adminTempData[id][gd_reason][r_time]),
    Get_GagString_reason(id, target)), false
  )

  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)

  menu_setprop(menu, MPROP_PERPAGE, 0)
  menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE)
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)
  return PLUGIN_HANDLED
}

public MenuCallback_SelectFlags(const id, const menu, const item) {
  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)

  new itemIndex = strtol(g_itemInfo)

  new bool: isReadyToGag = (g_adminTempData[id][gd_reason][r_flags] != gagFlag_Removed)

  new target = g_adminTempData[id][gd_target]

  new bool: alreadyHasGag = (g_currentGags[target][gd_reason][r_flags] != gagFlag_Removed)
  new bool: hasChanges = !GagData_IsEqual(g_currentGags[target], g_adminTempData[id])

  if((itemIndex == ITEM_CONFIRM)) {
    if(!isReadyToGag) {
      return ITEM_DISABLED
    }

    if(alreadyHasGag && !hasChanges) {
      return ITEM_DISABLED
    }
  }

  return ITEM_ENABLED
}

public MenuHandler_SelectFlags(const id, const menu, const item) {
  if(item == MENU_EXIT || item < 0) {
    MenuShow_PlayersList(id)

    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)
  menu_destroy(menu)

  new itemIndex = strtol(g_itemInfo)

  switch(itemIndex) {
    case gagFlag_Say: {
      g_adminTempData[id][gd_reason][r_flags] ^= (!ca_gag_common_chat_block ? gagFlag_Say : (gagFlag_Say | gagFlag_SayTeam))
    }
    case gagFlag_SayTeam: g_adminTempData[id][gd_reason][r_flags] ^= gagFlag_SayTeam
    case gagFlag_Voice:   g_adminTempData[id][gd_reason][r_flags] ^= gagFlag_Voice

    case ITEM_CONFIRM: {
      new time      = g_adminTempData[id][gd_reason][r_time]
      new flags     = g_adminTempData[id][gd_reason][r_flags]
      new expireAt  = g_adminTempData[id][gd_expireAt]

      Gag_Save(id, target, time, flags, expireAt)
      GagData_Reset(g_adminTempData[id])

      return PLUGIN_HANDLED
    }
  }

  MenuShow_SelectFlags(id)
  return PLUGIN_HANDLED
}

// Show gag menu
static MenuShow_ShowGag(const id) {
  if(!is_user_connected(id)) {
    return
  }

  new menu = menu_create(fmt("%L", id, "Gag_MenuItem_ShowGag", g_adminTempData[id][gd_name]), "MenuHandler_ShowGag")

  static callback

  if(!callback) {
    callback = menu_makecallback("MenuCallback_ShowGag")
  }

  menu_additem(menu, fmt("%L", id, "Gag_MenuItem_RemoveGag"), .info = g_adminTempData[id][gd_adminAuthID], .callback = callback)
  menu_additem(menu, fmt("%L", id, "Gag_MenuItem_EditGag"), .info = g_adminTempData[id][gd_adminAuthID], .callback = callback)

  menu_addtext(menu, fmt("\n  \\d%L \\w%s", id, "Gag_MenuItem_Admin",
      g_adminTempData[id][gd_adminName]
    )
  )
  menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Reason",
      Get_GagString_reason(id, g_adminTempData[id][gd_target])
    )
  )
  menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Type",
      Get_GagFlags_Names(gag_flags_s: g_adminTempData[id][gd_reason][r_flags])
    )
  )

  menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Length",
      Get_TimeString_seconds(id, g_adminTempData[id][gd_reason][r_time])
    )
  )

  new hoursLeft = (g_adminTempData[id][gd_expireAt] - get_systime()) / SECONDS_IN_HOUR
  if(hoursLeft > 5) {
    new timeStr[32]; format_time(timeStr, charsmax(timeStr), "%d/%m/%Y (%H:%M)", g_adminTempData[id][gd_expireAt])
    menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Expire",
        timeStr
      )
    )
  } else {
    new expireLeft = g_adminTempData[id][gd_expireAt] - get_systime()
    new expireLeftStr[128]; get_time_length(id, expireLeft, timeunit_seconds, expireLeftStr, charsmax(expireLeftStr))

    menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Left",
        expireLeftStr
      )
    )
  }

  menu_addblank(menu, .slot = false)
  menu_addblank(menu, .slot = false)

  menu_setprop(menu, MPROP_PERPAGE, 0)
  menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE)
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)
}

public MenuCallback_ShowGag(const id, const menu, const item) {
  if(!ca_gag_remove_only_own_gag) {
    return ITEM_ENABLED
  }

  new flags = get_user_flags(id)

  if(flags & read_flags(ca_gag_access_flags_high)) {
    return ITEM_ENABLED
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)

  new authID[MAX_AUTHID_LENGTH]; get_user_authid(id, authID, charsmax(authID))
  new bool: isOwnGag = (strcmp(authID, g_itemInfo) == 0)

  if(isOwnGag) {
    return ITEM_ENABLED
  }

  return ITEM_DISABLED
}

public MenuHandler_ShowGag(const id, const menu, const item) {
  enum { menu_ComfirmRemove, menu_EditGagProperties }

  menu_destroy(menu)

  if(item == MENU_EXIT || item < 0) {
    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  // Remove player gag and exit from menu
  if(item == menu_ComfirmRemove) {
    Gag_Remove(id, target)

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  // Edit player gag properties
  if(item == menu_EditGagProperties) {
    new gagData[gagData_s]; {
      // Copy already used gag data
      GagData_Copy(gagData, g_currentGags[target])

      // Get updated player data like IP, nickname etc.
      GagData_GetPersonalData(id, target, gagData)
    }

    GagData_Copy(g_adminTempData[id], gagData)

    g_inEditMenu[id] = true

    MenuShow_EditGag(id)
    return PLUGIN_HANDLED
  }

  MenuShow_PlayersList(id)
  return PLUGIN_HANDLED
}

// Edit gag menu
static MenuShow_EditGag(const id) {
  if(!is_user_connected(id)) {
    return
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return
  }

  new menu = menu_create(fmt("%L [\\r%s\\y]", id, "Gag_MenuItem_EditGag", g_adminTempData[id][gd_name]), "MenuHandler_EditGag")

  static callback

  if(!callback) {
    callback = menu_makecallback("MenuCallback_EditGag")
  }

  new gag_flags_s: gagFlags = g_adminTempData[id][gd_reason][r_flags]

  menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropSay",
      (gagFlags & gagFlag_Say) ? " \\r+\\w " : "-"
    ),
    fmt("%i", gagFlag_Say)
  )

  if(!ca_gag_common_chat_block) {
    menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropSayTeam",
        (gagFlags & gagFlag_SayTeam) ? " \\r+\\w " : "-"
      ),
      fmt("%i", gagFlag_SayTeam)
    )
  }

  menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropVoice",
      (gagFlags & gagFlag_Voice) ? " \\r+\\w " : "-"
    ),
    fmt("%i", gagFlag_Voice)
  )

  menu_addblank(menu, .slot = false)

  menu_additem(menu, fmt("%L [ \\r%s\\w ]", id, "Gag_MenuItem_Reason",
      Get_GagString_reason(id, target)
    ),
    fmt("%i", ITEM_REASON)
  )
  menu_addtext(menu, fmt("      %L [ \\r%s\\w ]", id, "Gag_MenuItem_Time",
      Get_TimeString_seconds(id, g_adminTempData[id][gd_reason][r_time])
    ), .slot = false
  )

  menu_addblank(menu, .slot = false)

  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)

  if(ca_gag_common_chat_block) {
    menu_addblank2(menu)
  }

  menu_additem(menu, fmt("%L", id, "Gag_MenuItem_Confirm"), fmt("%i", ITEM_CONFIRM), .callback = callback)

  menu_setprop(menu, MPROP_PERPAGE, 0)
  menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE)
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)

  g_inEditMenu[id] = true
}

public MenuCallback_EditGag(const id, const menu, const item) {
  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)

  new itemIndex = strtol(g_itemInfo)

  if(itemIndex != ITEM_CONFIRM) {
    return ITEM_ENABLED
  }

  new bool: isReadyToGag = (g_adminTempData[id][gd_reason][r_flags] != gagFlag_Removed)

  if(!isReadyToGag) {
    return ITEM_DISABLED
  }

  new target = g_adminTempData[id][gd_target]
  new bool: hasChanges = !GagData_IsEqual(g_currentGags[target], g_adminTempData[id])

  if(!hasChanges) {
    return ITEM_DISABLED
  }

  return ITEM_ENABLED
}

public MenuHandler_EditGag(const id, const menu, const item) {
  if(item == MENU_EXIT || item < 0) {
    MenuShow_PlayersList(id)

    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]
  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)
  menu_destroy(menu)

  new itemIndex = strtol(g_itemInfo)

  switch(itemIndex) {
    case gagFlag_Say:      g_adminTempData[id][gd_reason][r_flags] ^= gagFlag_Say
    case gagFlag_SayTeam:  g_adminTempData[id][gd_reason][r_flags] ^= gagFlag_SayTeam
    case gagFlag_Voice:    g_adminTempData[id][gd_reason][r_flags] ^= gagFlag_Voice
    case ITEM_REASON: {
      MenuShow_SelectReason(id)
      return PLUGIN_HANDLED
    }
    case ITEM_CONFIRM: {
      new time              = g_adminTempData[id][gd_reason][r_time]
      new flags             = g_adminTempData[id][gd_reason][r_flags]

      new bool: timeChanged = (g_currentGags[target][gd_reason][r_time] != time)

      new expireAt          = timeChanged ? 0 : g_adminTempData[id][gd_expireAt]

      new gagTimeStr[32]; copy(gagTimeStr, charsmax(gagTimeStr), Get_TimeString_seconds(LANG_PLAYER, time))

      CA_Log(logLevel_Info, "Gag: \"%s\" edit gag for \"%s\" (type:\"%s\") (time:\"%s\") (reason:\"%s\")", \
        g_adminTempData[id][gd_adminName], g_adminTempData[id][gd_name], \
        bits_to_flags(gag_flags_s: g_adminTempData[id][gd_reason][r_flags]), \
        gagTimeStr, g_adminTempData[id][gd_reason][r_name] \
      )

      Gag_Save(id, target, time, flags, expireAt)

      GagData_Reset(g_adminTempData[id])
      g_inEditMenu[id] = false

      return PLUGIN_HANDLED
    }
  }

  MenuShow_EditGag(id)
  return PLUGIN_HANDLED
}
/*
 * @endsection Menus
 */


/*
 * @section user cmds handling
 */
public ClCmd_Gag(const id, const level, const cid) {
  if(!cmd_access(id, level, cid, 1)) {
    return PLUGIN_HANDLED
  }

  if(get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV) < 2) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_default, "%L %L", id, "Gag_prefix", id, "Gag_NotEnoughPlayers")
    return PLUGIN_HANDLED
  }

  MenuShow_PlayersList(id)
  return PLUGIN_HANDLED
}

public ClCmd_EnterGagReason(const id, const level, const cid) {
  if(!cmd_access(id, level, cid, 1)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  static customReasonName[128]
  read_argv(1, customReasonName, charsmax(customReasonName))

  if(!customReasonName[0]) {
    MenuShow_SelectReason(id)
    return PLUGIN_HANDLED
  }

  copy(g_adminTempData[id][gd_reason][r_name], charsmax(g_adminTempData[][r_name]), customReasonName)

  client_print_color(id, print_team_red, "%L %L (%s)", id, "Gag_prefix", id, "Gag_YouSetManual_Reason", g_adminTempData[id][gd_reason][r_name])

  MenuShow_SelectTime(id)
  return PLUGIN_HANDLED
}

public ClCmd_EnterGagTime(const id, const level, const cid) {
  if(!cmd_access(id, level, cid, 1)) {
    return PLUGIN_HANDLED
  }

  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminTempData[id][gd_target]

  if(!is_user_connected(target)) {
    UTIL_SendAudio(id, ca_gag_sound_error)
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  static timeStr[6]
  read_argv(1, timeStr, charsmax(timeStr))

  new time = strtol(timeStr) * SECONDS_IN_MINUTE

  if(time <= 0) {
    client_print_color(id, print_team_red, "%L %L (%s)!", id, "Gag_prefix", id, "Gag_NotValidTimeEntered", timeStr)

    MenuShow_SelectTime(id)
    return PLUGIN_HANDLED
  }

  client_print_color(id, print_team_red, "%L %L (%s)", id, "Gag_prefix", id, "Gag_YouSetManual_Time", Get_TimeString_seconds(id, time))

  g_adminTempData[id][gd_reason][r_time] = time

  if(g_inEditMenu[id]) {
    MenuShow_EditGag(id)

    return PLUGIN_HANDLED
  }

  MenuShow_SelectFlags(id)
  return PLUGIN_HANDLED
}

public ConCmd_amx_gag(const id, const level, const cid) {
  enum amx_gag_s { /* arg_cmd, */ arg_player = 1, arg_reason, arg_time, arg_flags }

  if(!cmd_access(id, level, cid, 1)) {
    return PLUGIN_HANDLED
  }

  new argc = read_argc()

  if(argc == 1) {
    console_print(id, "\t Usage: amx_gag [nickname | STEAM_ID | userID | IP] <reason> <time> <flags>\n")

    return PLUGIN_HANDLED
  }

  new args[amx_gag_s][255]
  for(new i; i < argc; i++) {
    read_argv(i, args[amx_gag_s: i], charsmax(args[]))
  }

  new target = FindPlayerByTarget(args[arg_player])

  if(!target || target == id) {
    console_print(id, "Can't find player by arg=`%s`", args[arg_player])

    return PLUGIN_HANDLED
  }

  if(g_currentGags[target][gd_reason][r_flags] != gagFlag_Removed) {
    console_print(id, "Player '%n' has already gagged.", target)

    return PLUGIN_HANDLED
  }

  trim(args[arg_reason])

  // Setup default gag for target player
  GagData_GetPersonalData(id, target, g_adminTempData[id])

  g_adminTempData[id][gd_reason][r_time]    = 60 * SECONDS_IN_MINUTE
  g_adminTempData[id][gd_reason][r_flags]   = gagFlag_Say | gagFlag_SayTeam | gagFlag_Voice

  copy(g_adminTempData[id][gd_reason][r_name], charsmax(g_adminTempData[][r_name]), "Not set")

  if(args[arg_reason][0] != EOS) {
    copy(g_adminTempData[id][gd_reason][r_name], charsmax(g_adminTempData[][r_name]), args[arg_reason])
  }

  if(args[arg_time][0] != EOS) {
    new seconds = strtol(args[arg_time]) * SECONDS_IN_MINUTE

    if(seconds > 0) {
      g_adminTempData[id][gd_reason][r_time] = seconds
    }
  }

  if(args[arg_flags][0] != EOS) {
    g_adminTempData[id][gd_reason][r_flags] = flags_to_bit(args[arg_flags][0])
  }

  Gag_Save(id, target, g_adminTempData[id][gd_reason][r_time], g_adminTempData[id][gd_reason][r_flags])
  return PLUGIN_HANDLED
}

public SrvCmd_AddReason() {
  enum any: args_s { arg_cmd, arg_reason, arg_flags, arg_time }

  new argCount = read_argc()
  if(argCount < 2 || argCount > 4) {
    server_print("\tUsage: ca_gag_add_reason <reason> [flags] [time]")
    return
  }

  new args[args_s][256]

  for(new arg = arg_cmd; arg < sizeof(args); arg++) {
    read_argv(arg, args[arg], charsmax(args[]))
  }

  new reason[reason_s]
  copy(reason[r_name], charsmax(reason[r_name]), args[arg_reason])

  trim(args[arg_time])

  new seconds = parseTime(args[arg_time])

  reason[r_time] = seconds
  reason[r_flags] = gag_flags_s: flags_to_bit(args[arg_flags])

  ArrayPushArray(g_gagReasonsTemplates, reason)
  g_gagReasonsTemplates_size = ArraySize(g_gagReasonsTemplates)

  CA_Log(logLevel_Debug, "ADD: Reason template[#%i]: '%s' (time='%s', flags='%s')",\
    g_gagReasonsTemplates_size, reason[r_name], args[arg_time], bits_to_flags(reason[r_flags])\
  )
}

public SrvCmd_AddWhitelistCmd() {
  enum { arg_chat_cmd = 1 }

  new argCount = read_argc()
  if(argCount != 2) {
    server_print("\tUsage: ca_gag_add_chat_whitelist_cmd <cmd>")
    return
  }

  new whitelistCmd[MAX_WHITELIST_CMD_LEN]
  read_argv(arg_chat_cmd, whitelistCmd, charsmax(whitelistCmd))

  ArrayPushArray(g_chatWhitelistCmds, whitelistCmd)
  g_chatWhitelistCmds_size = ArraySize(g_chatWhitelistCmds)

  CA_Log(logLevel_Debug, "ADD: Whitelist chat cmd[#%i]: %s", g_chatWhitelistCmds_size, whitelistCmd)
}

public SrvCmd_ShowTemplates() {
  if(!g_gagReasonsTemplates_size) {
    CA_Log(logLevel_Warning, "\t NO REASONS FOUNDED!")
    return PLUGIN_HANDLED
  }

  for(new i; i < g_gagReasonsTemplates_size; i++) {
    new reason[reason_s]
    ArrayGetArray(g_gagReasonsTemplates, i, reason)

    new timeStr[32]; get_time_length(LANG_SERVER, reason[r_time], timeunit_seconds, timeStr, charsmax(timeStr))

    server_print("\t Reason[#%i]: '%s' (Flags:'%s', Time:'%s')",\
      i + 1, reason[r_name], bits_to_flags(reason[r_flags]), timeStr\
    )
  }

  return PLUGIN_HANDLED
}

public SrvCmd_ReloadConfig() {
  LoadConfig()

  CA_Log(logLevel_Info, "Config re-loaded!")
}

static Message_ChatBlocked(const target) {
  new secondsLeft = g_currentGags[target][gd_expireAt] - get_systime()
  new hoursLeft = secondsLeft / SECONDS_IN_HOUR

  if(hoursLeft > 5) {
    new timeStr[32]; format_time(timeStr, charsmax(timeStr), "%d/%m/%Y (%H:%M)", g_currentGags[target][gd_expireAt])
    client_print_color(target, print_team_red, "%L %L %L %s", target, "Gag_prefix", target, "Gag_NotifyPlayer_BlockedChat", target, "Gag_MenuItem_Expire", timeStr)
  } else {
    new expireLeftStr[128]; get_time_length(target, secondsLeft, timeunit_seconds, expireLeftStr, charsmax(expireLeftStr))
    client_print_color(target, print_team_red, "%L %L %L %s", target, "Gag_prefix", target, "Gag_NotifyPlayer_BlockedChat", target, "Gag_MenuItem_Left", expireLeftStr)
  }
}

static bool: IsWhitelistCmd(const message[]) {
  new whitelistCmd[MAX_WHITELIST_CMD_LEN]

  for(new i; i < g_chatWhitelistCmds_size; i++) {
    ArrayGetArray(g_chatWhitelistCmds, i, whitelistCmd)

    if(strcmp(message, whitelistCmd) == 0) {
      return true
    }
  }

  return false
}
/*
 * @endsection user cmds handling
 */


/*
 * @section CA:Core API handling
 */
public CA_Client_Voice(const listener, const sender) {
  new bool: hasBlock = (g_currentGags[sender][gd_reason][r_flags] & gagFlag_Voice)

  if(!hasBlock) {
    return CA_CONTINUE
  }

  // UTIL_SendAudio(sender, ca_gag_sound_error) // TODO: implement later

  return CA_SUPERCEDE
}

public CA_Client_Say(id, const bool: isTeamMessage, const message[]) {
  if(CmdRouter(id, message))
    return CA_CONTINUE

  new bool: hasBlock
  if(isTeamMessage) {
    hasBlock = bool: (g_currentGags[id][gd_reason][r_flags] & (ca_gag_common_chat_block ? gagFlag_Say : gagFlag_SayTeam))
  } else {
    hasBlock = bool: (g_currentGags[id][gd_reason][r_flags] & gagFlag_Say)
  }

  if(!hasBlock) {
    return CA_CONTINUE
  }

  if(IsWhitelistCmd(message)) {
    return CA_CONTINUE
  }

  UTIL_SendAudio(id, ca_gag_sound_error)
  Message_ChatBlocked(id)

  return CA_SUPERCEDE
}

public CA_Client_ChangeName(const id, const newName[]) {
  if(!ca_gag_block_nickname_change) {
    return CA_CONTINUE
  }

  new bool: hasBlock = (g_currentGags[id][gd_reason][r_flags] & gagFlag_Say)

  if(!hasBlock) {
    return CA_CONTINUE
  }

  return CA_SUPERCEDE
}

public ClCmd_adminSay(const id) {
  new bool: hasBlock = (g_currentGags[id][gd_reason][r_flags] & gagFlag_Say)

  if(!hasBlock || !ca_gag_block_admin_chat) {
    return CA_CONTINUE
  }

  UTIL_SendAudio(id, ca_gag_sound_error)
  Message_ChatBlocked(id)

  return CA_SUPERCEDE
}
/*
 * @endsection CA:Core API handling
 */

/**
 * @section Storage handling
 */
public CA_Storage_Initialized( ) {
  CA_Log(logLevel_Debug, "[CA]: Gag > storage initialized!")
}

public CA_Storage_Saved(const name[], const authID[], const IP[], const reason[],
  const adminName[], const adminAuthID[], const adminIP[],
  const createdAt, const expireAt, const flags) {

  new gagTime = expireAt - createdAt
  new gagTimeStr[32]; copy(gagTimeStr, charsmax(gagTimeStr), Get_TimeString_seconds(LANG_PLAYER, gagTime))

  new admin = find_player_ex((FindPlayer_MatchAuthId | FindPlayer_ExcludeBots), adminAuthID)

  if(is_user_connected(admin)) {
    UTIL_SendAudio(admin, ca_gag_sound_ok)
  }

  // TODO: Rework this
  show_activity_ex(admin, adminName, "%l", "Gag_AdminGagPlayer", name)
  client_print(0, print_chat, "%l %s, %l %s (%s)",
    "Gag_MenuItem_Reason", reason,
    "Gag_MenuItem_Time", gagTimeStr,
    Get_GagFlags_Names(gag_flags_s: flags)
  )

  CA_Log(logLevel_Info, "Gag: \"%s\" add gag to \"%s\" (type:\"%s\") (time:\"%s\") (reason:\"%s\")", \
    adminName, name, bits_to_flags(gag_flags_s: flags), gagTimeStr, reason \
  )
}

public CA_Storage_Loaded(const name[], const authID[], const IP[], const reason[],
  const adminName[], const adminAuthID[], const adminIP[],
  const createdAt, const expireAt, const flags) {

  new target = find_player_ex((FindPlayer_MatchAuthId | FindPlayer_ExcludeBots), authID)

  if(!target) {
    return
  }

  copy(g_currentGags[target][gd_name], charsmax(g_currentGags[][gd_name]), name)

  // FIXME: Nickname can't change on DEAD player.
  // set_user_info(target, "name", name)

  copy(g_currentGags[target][gd_authID], charsmax(g_currentGags[][gd_authID]), authID)
  copy(g_currentGags[target][gd_IP], charsmax(g_currentGags[][gd_IP]), IP)

  copy(g_currentGags[target][gd_adminName], charsmax(g_currentGags[][gd_adminName]), adminName)
  copy(g_currentGags[target][gd_adminAuthID], charsmax(g_currentGags[][gd_adminAuthID]), adminAuthID)
  copy(g_currentGags[target][gd_adminIP], charsmax(g_currentGags[][gd_adminIP]), adminIP)

  copy(g_currentGags[target][gd_reason][r_name], charsmax(g_currentGags[][r_name]), reason)
  g_currentGags[target][gd_reason][r_time] = expireAt - createdAt
  g_currentGags[target][gd_reason][r_flags] = gag_flags_s: flags

  g_currentGags[target][gd_expireAt] = expireAt
}
public CA_Storage_Removed( ) {
  // TODO
}
/**
 * @endsection Storage handling
 */



static LoadConfig() {
  if(ArraySize(g_gagReasonsTemplates) > 0) {
    ArrayClear(g_gagReasonsTemplates)
    g_gagReasonsTemplates_size = 0
  }

  if(ArraySize(g_chatWhitelistCmds) > 0) {
    ArrayClear(g_chatWhitelistCmds)
    g_chatWhitelistCmds_size = 0
  }

  AutoExecConfig(true, "CA_Gag", "ChatAdditions")

  new configsDir[PLATFORM_MAX_PATH]
  get_configsdir(configsDir, charsmax(configsDir))

  server_cmd("exec %s/plugins/ChatAdditions/CA_Gag.cfg", configsDir)
  server_cmd("exec %s/plugins/ChatAdditions/ca_gag_reasons.cfg", configsDir)
  server_cmd("exec %s/plugins/ChatAdditions/ca_gag_chat_whitelist_cmds.cfg", configsDir)
  server_exec()

  ParseTimes()
}

static ParseTimes() {
  new buffer[128]; get_cvar_string("ca_gag_times", buffer, charsmax(buffer))

  if(strlen(buffer) > 0) {
    const MAX_TIMES_COUNT = 10

    new times[MAX_TIMES_COUNT][16]

    new count = explode_string(buffer, ",", times, sizeof(times), charsmax(times[]))

    if(g_gagTimeTemplates_size) {
      ArrayClear(g_gagTimeTemplates)
    }

    for(new i; i < count; i++) {
      trim(times[i])

      new time = parseTime(times[i])
      new timeStr[32]; get_time_length(LANG_SERVER, time, timeunit_seconds, timeStr, charsmax(timeStr))

      CA_Log(logLevel_Debug, "ADD: Time template[#%i]: %s",\
        i + 1, timeStr
      )

      ArrayPushCell(g_gagTimeTemplates, time)
    }
  }

  g_gagTimeTemplates_size = ArraySize(g_gagTimeTemplates)
}

static Get_TimeString_seconds(const id, const seconds) {
  new timeStr[32]
  get_time_length(id, seconds, timeunit_seconds, timeStr, charsmax(timeStr))

  if(timeStr[0] == EOS) {
    formatex(timeStr, charsmax(timeStr), "%L", id, "Gag_NotSet")
  }

  return timeStr
}

static Get_GagString_reason(const id, const target) {
  new buffer[MAX_REASON_LEN]

  if(id != LANG_PLAYER) {
    copy(buffer, charsmax(buffer), g_adminTempData[id][gd_reason][r_name])
  } else {
    copy(buffer, charsmax(buffer), g_currentGags[target][gd_reason][r_name])
  }

  if(buffer[0] == EOS) {
    formatex(buffer, charsmax(buffer), "%L", id, "Gag_NotSet")
  }

  return buffer
}

static Get_PlayerPostfix(const id, const target, const hasImmunity) {
  new postfix[32]

  if(hasImmunity) {
    formatex(postfix, charsmax(postfix), " [\\r%L\\d]", id, "Gag_Immunity")
  } else if(g_currentGags[target][gd_reason][r_flags]) {
    formatex(postfix, charsmax(postfix), " [\\y%L\\w]", id, "Gag_Gagged")
  }

  return postfix
}

static bool: IsTargetHasImmunity(const id, const target) {
  new accessFlagsImmunity   = read_flags(ca_gag_immunity_flags)
  new accessFlagsHigh       = read_flags(ca_gag_access_flags_high)
  new accessFlags           = read_flags(ca_gag_access_flags)

  new userFlags             = get_user_flags(id)
  new targetFlags           = get_user_flags(target)

  // main admin can gag everyone
  if(userFlags & accessFlagsHigh) {
    return false
  }

  // main admin can't be gagged by admins
  if(targetFlags & accessFlagsHigh) {
    return true
  }

  // target has immunity or admin flags
  if(targetFlags & (accessFlags|accessFlagsImmunity)) {
    return true
  }

  return false
}

static Get_GagFlags_Names(gag_flags_s: flags) {
  // TODO: ML this

  new buffer[64]
  new const GAG_FLAGS_STR[][] = {
    "Chat", "Team chat", "Voice"
  }

  if(ca_gag_common_chat_block && (flags & gagFlag_SayTeam))
    flags ^= gagFlag_SayTeam

  for(new i; i < sizeof(GAG_FLAGS_STR); i++) {
    if(flags & gag_flags_s: (1 << i)) {
      strcat(buffer, fmt("%s + ", GAG_FLAGS_STR[i]), charsmax(buffer))
    }
  }

  if(buffer[0] != EOS) {
    buffer[strlen(buffer) - 3] = EOS
  }

  return buffer
}


static bool: Gag_Save(const id, const target, const time, const flags, const expireAt = 0) {
  GagData_Copy(g_currentGags[target], g_adminTempData[id])
  GagData_Reset(g_adminTempData[id])

  new gag[gagData_s]
  GagData_GetPersonalData(id, target, gag); {
    copy(gag[gd_reason][r_name], charsmax(gag[r_name]), Get_GagString_reason(LANG_PLAYER, target))
    gag[gd_reason][r_time] = time
    gag[gd_reason][r_flags] = gag_flags_s: flags

    gag[gd_expireAt] = (expireAt != 0) ? (expireAt) : (time + get_systime())
  }

  ExecuteForward(g_fwd_gag_setted, g_ret,
    target,
    gag[gd_name],
    gag[gd_authID],
    gag[gd_IP],

    gag[gd_adminName],
    gag[gd_adminAuthID],
    gag[gd_adminIP],

    gag[gd_reason][r_name],
    gag[gd_reason][r_time],
    gag[gd_reason][r_flags],

    gag[gd_expireAt]
  )

  if(g_ret == CA_SUPERCEDE) {
    return false
  }

  CA_Storage_Save(
    gag[gd_name], gag[gd_authID], gag[gd_IP], gag[gd_reason][r_name],
    gag[gd_adminName], gag[gd_adminAuthID], gag[gd_adminIP],
    gag[gd_expireAt], gag[gd_reason][r_flags]
  )

  g_currentGags[target] = gag

  client_cmd(target, "-voicerecord")

  return true
}

static bool: Gag_Remove(const id, const target) {
  if(g_adminTempData[id][gd_reason][r_flags] != gagFlag_Removed) {
    ExecuteForward(g_fwd_gag_removed, g_ret,
      target,
      g_currentGags[target][gd_reason][r_name],
      g_currentGags[target][gd_reason][r_time],
      g_currentGags[target][gd_reason][r_flags]
    )

    if(g_ret == CA_SUPERCEDE) {
      return false
    }

    show_activity_ex(id, fmt("%n", id), "%l", "Gag_AdminUngagPlayer", g_currentGags[target][gd_name])

    GagData_Reset(g_adminTempData[id])
    GagData_Reset(g_currentGags[target])

    new authID[MAX_AUTHID_LENGTH]; get_user_authid(target, authID, charsmax(authID))
    CA_Storage_Remove(authID)
    return true
  } else {
    client_print_color(id, print_team_red, "%L %L", id, "Gag_prefix", id, "Gag_PlayerAlreadyRemoved", target)
  }

  return false
}

static Gag_Expired(const id) {
  GagData_Reset(g_currentGags[id])

  client_print_color(0, print_team_default, "%L %L", LANG_PLAYER, "Gag_prefix", LANG_PLAYER, "Gag_PlayerExpiredGag", id)
}

static bool: CmdRouter(const player, const message[]) {
  if(!(get_user_flags(player) & (read_flags(ca_gag_access_flags) | read_flags(ca_gag_access_flags_high))))
    return false

  new cmd[32], token[32]
  strtok2(message[1], cmd, charsmax(cmd), token, charsmax(token), .trim = true)

  if(strncmp(cmd, g_gagCmd, charsmax(g_gagCmd), true) == 0) {
    MenuShow_PlayersList(player, token)
    return true
  }

  if(strncmp(cmd, g_unGagCmd, charsmax(g_unGagCmd), true) == 0) {
    new targetUserID = strtol(token)
    if(targetUserID == 0)
      return false

    UnGag_ByUserID(player, targetUserID)
    return true
  }

  return false
}

static UnGag_ByUserID(const admin, const targetUserID) {
  new target = find_player_ex(FindPlayer_MatchUserId | FindPlayer_ExcludeBots, targetUserID)
  if(!is_user_connected(target)) {
      client_print_color(admin, print_team_red, "%L %L", admin, "Gag_prefix", admin, "Gag_PlayerNotConnected")
      return
    }

  new bool: hasBlock = g_currentGags[target][gd_reason][r_flags] != gagFlag_Removed
  if(!hasBlock) {
    client_print_color(admin, print_team_red, "%L %L", admin, "Gag_prefix", admin, "Gag_PlayerExpiredGag", target)
    return
  }

  GagData_Copy(g_adminTempData[admin], g_currentGags[target])
  g_adminTempData[admin][gd_target] = target

  Gag_Remove(admin, target)
}

Register_Forwards() {
  g_fwd_gag_setted = CreateMultiForward("CA_gag_setted", ET_STOP,
    FP_CELL, FP_STRING, FP_STRING, FP_STRING,
    FP_STRING, FP_STRING, FP_STRING,
    FP_STRING, FP_CELL, FP_CELL,
    FP_CELL
  )

  g_fwd_gag_removed = CreateMultiForward("CA_gag_removed", ET_STOP, FP_CELL, FP_STRING, FP_CELL, FP_CELL)
}

public plugin_natives() {
  register_native("ca_set_user_gag", "native_ca_set_user_gag")
  register_native("ca_get_user_gag", "native_ca_get_user_gag")
  register_native("ca_has_user_gag", "native_ca_has_user_gag")
  register_native("ca_remove_user_gag", "native_ca_remove_user_gag")
}

public bool: native_ca_set_user_gag(const plugin_id, const argc) {
  enum { arg_index = 1, arg_reason, arg_minutes, arg_flags }

  g_adminTempData[0][gd_target] = get_param(arg_index)

  get_string(arg_reason, g_adminTempData[0][gd_reason][r_name], charsmax(g_adminTempData[][r_name]))

  g_adminTempData[0][gd_reason][r_time] = get_param(arg_minutes) * SECONDS_IN_MINUTE
  g_adminTempData[0][gd_reason][r_flags] = gag_flags_s: get_param(arg_flags)

  return Gag_Save(0,
    g_adminTempData[0][gd_target],
    g_adminTempData[0][gd_reason][r_time],
    g_adminTempData[0][gd_reason][r_flags]
  )
}

public bool: native_ca_get_user_gag(const plugin_id, const argc) {
  enum { arg_index = 1, arg_reason, arg_minutes, arg_flags }

  new target = get_param(arg_index)
  new gag_flags_s: flags = g_currentGags[target][gd_reason][r_flags]

  if(!flags) {
    return false
  }

  set_string(arg_reason, g_currentGags[target][gd_reason][r_name], charsmax(g_adminTempData[][r_name]))
  set_param_byref(arg_minutes, g_currentGags[target][gd_reason][r_time] / SECONDS_IN_MINUTE)
  set_param_byref(arg_flags, flags)

  return true
}

public bool: native_ca_has_user_gag(const plugin_id, const argc) {
  enum { arg_index = 1 }

  new target = get_param(arg_index)
  new gag_flags_s: flags = g_currentGags[target][gd_reason][r_flags]

  return bool: (flags != gagFlag_Removed)
}

public bool: native_ca_remove_user_gag(const plugin_id, const argc) {
  enum { arg_target = 1, arg_admin }

  new target = get_param(arg_target)
  new gag_flags_s: flags = g_currentGags[target][gd_reason][r_flags]

  if(flags == gagFlag_Removed) {
    return false
  }

  new admin = get_param(arg_admin)
  GagData_Copy(g_adminTempData[admin], g_currentGags[target])
  g_adminTempData[admin][gd_target] = target

  return Gag_Remove(admin, target)
}
