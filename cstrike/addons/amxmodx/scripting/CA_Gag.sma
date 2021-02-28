#include <amxmodx>
#include <amxmisc>
#include <time>

#include <ChatAdditions>
#include <CA_GAG_API>
#include <CA_StorageAPI>

#pragma ctrlchar '\'
#pragma dynamic 524288
#pragma tabsize 2


  /* ----- START SETTINGS----- */
const Float: GAG_THINKER_FREQ = 3.0
  /* ----- END OF SETTINGS----- */

static g_currentGags[MAX_PLAYERS + 1][gagData_s]
static g_adminGagsEditor[MAX_PLAYERS + 1][gagData_s]

static Array: g_gagReasonsTemplates, g_gagReasonsTemplates_size
static Array: g_gagTimeTemplates, g_gagTimeTemplates_size

enum GagMenuType_s {
  _MenuType_Custom,
  _MenuType_Sequential
};
new GagMenuType_s: ca_gag_menu_type,
  ca_gag_prefix[32],
  ca_gag_times[64],
  ca_gag_immunity_flags[16],
  ca_gag_access_flags[16],
  ca_gag_access_flags_high[16],
  ca_gag_remove_only_own_gag

new g_dummy, g_itemInfo[64], g_itemName[128]
enum {
  ITEM_ENTER_GAG_REASON = -1,
  ITEM_ENTER_GAG_TIME = -2
}

public stock const PluginName[] = "CA: Gag"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "https://Dev-CS.ru/"
public stock const PluginDescription[] = "Manage player chats for the admin."

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)

  register_dictionary("CA_Gag.txt")
  register_dictionary("common.txt")
  register_dictionary("time.txt")

  g_gagReasonsTemplates = ArrayCreate(reason_s)
  g_gagTimeTemplates = ArrayCreate()

  bind_pcvar_num(create_cvar("ca_gag_menu_type", "1",
      .description = "Gag menu type\n 0 = show only one menu with gag properties\n 1 = sequential menu with control every step",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = float(_: _MenuType_Sequential)
    ),
    ca_gag_menu_type
  )

  bind_pcvar_string(create_cvar("ca_gag_prefix", "[GAG]",
      .description = "Chat prefix for plugin actions"
    ),
    ca_gag_prefix, charsmax(ca_gag_prefix)
  )

  bind_pcvar_string(create_cvar("ca_gag_times", "1i, 5i, 10i, 30i, 1h, 1d, 1w, 1m",
      .description = "Gag time values for choose\n \
        format: 1 = 1 second, 1i = 1 minute, 1h = 1 hour, 1d = 1 day, 1w = 1 week\n \
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

  register_srvcmd("ca_gag_add_reason", "SrvCmd_AddReason")
  register_srvcmd("ca_gag_show_templates", "SrvCmd_ShowTemplates");
  register_srvcmd("ca_gag_reload_config", "SrvCmd_ReloadConfig")

  set_task_ex(GAG_THINKER_FREQ, "Gags_Thinker", .flags = SetTask_Repeat)

  LoadConfig()

  new accessFlagsHigh = read_flags(ca_gag_access_flags_high)
  new accessFlags = read_flags(ca_gag_access_flags)

  register_clcmd("enter_GagReason", "ClCmd_EnterGagReason", accessFlagsHigh)
  register_clcmd("enter_GagTime", "ClCmd_EnterGagTime", accessFlagsHigh)

  new const CMDS_Mute[][] = { "gag" }
  for(new i; i < sizeof(CMDS_Mute); i++) {
    register_trigger_clcmd(CMDS_Mute[i], "ClCmd_Gag", (accessFlags | accessFlagsHigh))
  }

  CA_Log(logLevel_Debug, "[CA]: Gag initialized!")
}

public client_putinserver(id) {
  if(is_user_bot(id) || is_user_hltv(id)) {
    return
  }

  new authID[MAX_AUTHID_LENGTH]; get_user_authid(id, authID, charsmax(authID))
  CA_Storage_Load(authID)
}

public client_disconnected(id) {
  GagData_Reset(g_currentGags[id])
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
static MenuShow_PlayersList(const id) {
  if(!is_user_connected(id)) {
    return
  }

  new menu = menu_create(fmt("%L", id, "Gag_MenuTitle_PlayersList"), "MenuHandler_PlayersList")

  static callback
  if(!callback) {
    callback = menu_makecallback("MenuCallback_PlayersList")
  }

  new players[MAX_PLAYERS], count
  get_players_ex(players, count, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV))
  for(new i; i < count; i++) {
    new target = players[i]

    if(target == id) {
      continue
    }

    new bool: hasImmunity = IsTargetHasImmunity(id, target)
    menu_additem(menu, fmt("%n %s", target, Get_PlayerPostfix(id, target, hasImmunity)), fmt("%i", get_user_userid(players[i])), .callback = callback)
  }

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

  new userID = strtol(g_itemInfo)

  new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), userID)
  if(target == 0) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  // Remove already gagged player
  if(g_currentGags[target][gd_reason][r_flags] != gagFlag_Removed) {
    GagData_Copy(g_adminGagsEditor[id], g_currentGags[target])
    g_adminGagsEditor[id][gd_target] = target

    MenuShow_ShowGag(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  // Setup gag for target player
  GagData_GetPersonalData(id, target, g_adminGagsEditor[id])

  // Select the next menu by CVar settings
  switch(ca_gag_menu_type) {
    case _MenuType_Custom: MenuShow_GagProperties(id)
    case _MenuType_Sequential: MenuShow_SelectReason(id)
  }

  menu_destroy(menu)
  return PLUGIN_HANDLED
}

// Show gag menu
static MenuShow_ShowGag(const id) {
  if(!is_user_connected(id)) {
    return
  }

  new menu = menu_create(fmt("%L", id, "Gag_MenuItem_ShowGag", g_adminGagsEditor[id][gd_name]), "MenuHandler_ShowGag")

  static callback
  if(!callback) {
    callback = menu_makecallback("MenuCallback_ShowGag")
  }

  menu_additem(menu, fmt("%L", id, "Gag_MenuItem_RemoveGag"), .info = g_adminGagsEditor[id][gd_adminAuthID], .callback = callback)
  menu_additem(menu, fmt("%L", id, "Gag_MenuItem_EditGag"), .info = g_adminGagsEditor[id][gd_adminAuthID], .callback = callback)

  menu_addtext(menu, fmt("\n  \\d%L \\w%s", id, "Gag_MenuItem_Admin",
      g_adminGagsEditor[id][gd_adminName]
    )
  )
  menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Reason",
      Get_GagString_reason(id, g_adminGagsEditor[id][gd_target])
    )
  )
  menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Type",
      Get_GagFlags_Names(gagFlags_s: g_adminGagsEditor[id][gd_reason][r_flags])
    )
  )

  menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Length",
      Get_TimeString_seconds(id, g_adminGagsEditor[id][gd_reason][r_time])
    )
  )


  new hoursLeft = (g_adminGagsEditor[id][gd_expireAt] - get_systime()) / SECONDS_IN_HOUR
  if(hoursLeft > 5) {
    new timeStr[32]; format_time(timeStr, charsmax(timeStr), "%d/%m/%Y (%H:%M)", g_adminGagsEditor[id][gd_expireAt])
    menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Expire",
        timeStr
      )
    )
  } else {
    new expireLeft = g_adminGagsEditor[id][gd_expireAt] - get_systime()
    new expireLeftStr[128]; get_time_length(id, expireLeft, timeunit_seconds, expireLeftStr, charsmax(expireLeftStr))
    menu_addtext(menu, fmt("  \\d%L \\w%s", id, "Gag_MenuItem_Left",
        expireLeftStr
      )
    )
  }

  menu_addblank(menu)
  menu_addblank(menu)

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

  if(item == MENU_EXIT || item < 0) {
    GagData_Reset(g_adminGagsEditor[id])

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  // Remove player gag and exit from menu
  if(item == menu_ComfirmRemove) {
    Gag_Remove(id, target)

    menu_destroy(menu)
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
    GagData_Copy(g_adminGagsEditor[id], gagData)

    MenuShow_GagProperties(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  MenuShow_PlayersList(id)
  menu_destroy(menu)
  return PLUGIN_HANDLED
}

// Gag Properties menu
static MenuShow_GagProperties(const id) {
  if(!is_user_connected(id)) {
    return
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return
  }

  new menu = menu_create(fmt("%L", id, "Gag_GagProperties", target), "MenuHandler_GagProperties")

  static callback
  if(!callback) {
    callback = menu_makecallback("MenuCallback_GagProperties")
  }

  new gag_flags_s: gagFlags = g_adminGagsEditor[id][gd_reason][r_flags]

  menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropSay",
    (gagFlags & gagFlag_Say) ? " \\r+\\w " : "-")
  )
  menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropSayTeam",
    (gagFlags & gagFlag_SayTeam) ? " \\r+\\w " : "-")
  )
  menu_additem(menu, fmt("%L [ %s ]", id, "Gag_MenuItem_PropVoice",
    (gagFlags & gagFlag_Voice) ? " \\r+\\w " : "-")
  )

  if(ca_gag_menu_type == _MenuType_Custom) {
    menu_addblank(menu, false)

    menu_additem(menu, fmt("%L [ \\y%s\\w ]", id, "Gag_MenuItem_Reason",
      Get_GagString_reason(id, target)), .callback = callback
    )
    menu_additem(menu, fmt("%L [ \\y%s\\w ]", id, "Gag_MenuItem_Time",
      Get_TimeString_seconds(id, g_adminGagsEditor[id][gd_reason][r_time]))
    )
  }

  menu_addblank(menu, false)

  menu_additem(menu, fmt("%L", id, "Gag_MenuItem_Confirm"), .callback = callback)

  menu_addtext(menu, fmt("\n%L", id, "Gag_MenuItem_Resolution",
    Get_TimeString_seconds(id, g_adminGagsEditor[id][gd_reason][r_time]),
    Get_GagString_reason(id, target)), false
  )

  if(ca_gag_menu_type == _MenuType_Sequential) {
    menu_addblank2(menu)
    menu_addblank2(menu)
  }

  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)

  menu_setprop(menu, MPROP_PERPAGE, 0)
  menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE)
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)
}

public MenuCallback_GagProperties(const id, const menu, const item) {
  enum { /* menu_Chat, menu_TeamChat, menu_VoiceChat, */
      /* menu_Reason = 3, */ /* menu_Time, */ menu_Confirm = 5
  }

  enum { sequential_Confirm = 3 }

  new bool: isReadyToGag = (g_adminGagsEditor[id][gd_reason][r_flags] != gagFlag_Removed)

  new bool: isConfirmItem = (
    item == menu_Confirm && ca_gag_menu_type == _MenuType_Custom
    || item == sequential_Confirm && ca_gag_menu_type == _MenuType_Sequential
  )

  new target = g_adminGagsEditor[id][gd_target]
  new bool: alreadyHasGag = (g_currentGags[target][gd_reason][r_flags] != gagFlag_Removed)
  new bool: hasChanges = !GagData_IsEqual(g_currentGags[target], g_adminGagsEditor[id])

  if(isConfirmItem) {
    if(!isReadyToGag) {
      return ITEM_DISABLED
    }

    if(alreadyHasGag && !hasChanges) {
      return ITEM_DISABLED
    }
  }

  return ITEM_ENABLED
}

public MenuHandler_GagProperties(const id, const menu, const item) {
  enum { menu_Chat, menu_TeamChat, menu_VoiceChat,
      menu_Reason, menu_Time, menu_Confirm
    }

  enum { sequential_Confirm = 3 }

  if(item == MENU_EXIT || item < 0) {
    GagData_Reset(g_adminGagsEditor[id])

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  switch(item) {
    case menu_Chat:       g_adminGagsEditor[id][gd_reason][r_flags] ^= gagFlag_Say
    case menu_TeamChat:   g_adminGagsEditor[id][gd_reason][r_flags] ^= gagFlag_SayTeam
    case menu_VoiceChat:  g_adminGagsEditor[id][gd_reason][r_flags] ^= gagFlag_Voice
  }

  if(ca_gag_menu_type == _MenuType_Custom) {
    switch(item) {
      case menu_Reason: {
        MenuShow_SelectReason(id)
        menu_destroy(menu)
        return PLUGIN_HANDLED
      }
      case menu_Time:	{
        MenuShow_SelectTime(id)
        menu_destroy(menu)
        return PLUGIN_HANDLED
      }
      case menu_Confirm: {
        new time = g_adminGagsEditor[id][gd_reason][r_time]
        new flags = g_adminGagsEditor[id][gd_reason][r_flags]
        new expireAt = g_adminGagsEditor[id][gd_expireAt]

        Gag_Save(id, target, time, flags, expireAt)

        menu_destroy(menu)
        return PLUGIN_HANDLED
      }
    }
  } else {
    switch(item) {
      case sequential_Confirm: {
        new time = g_adminGagsEditor[id][gd_reason][r_time]
        new flags = g_adminGagsEditor[id][gd_reason][r_flags]
        new expireAt = g_adminGagsEditor[id][gd_expireAt]

        Gag_Save(id, target, time, flags, expireAt)

        menu_destroy(menu)
        return PLUGIN_HANDLED
      }
    }
  }

  MenuShow_GagProperties(id)
  menu_destroy(menu)
  return PLUGIN_HANDLED
}

// Reason choose menu
static MenuShow_SelectReason(const id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new menu = menu_create(fmt("%L", id, "Gag_MenuTitle_SelectReason"), "MenuHandler_SelectReason")

  if(get_user_flags(id) & read_flags(ca_gag_access_flags_high)) {
    menu_additem(menu, fmt("%L\n", id, "Gag_EnterReason"), fmt("%i", ITEM_ENTER_GAG_REASON))
  }

  if(g_gagReasonsTemplates_size) {
    for(new i; i < g_gagReasonsTemplates_size; i++) {
      new reason[reason_s]
      ArrayGetArray(g_gagReasonsTemplates, i, reason)

      menu_additem(menu,
        fmt("%s (\\y%s\\w)", reason[r_name], Get_TimeString_seconds(id, reason[r_time])),
        fmt("%i", i)
      )
    }
  } else {
    menu_addtext(menu, fmt("\\d		%L", id, "Gag_NoTemplatesAvailable_Reasons"), .slot = false)
  }

  menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
  menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)
  return PLUGIN_HANDLED
}

public MenuHandler_SelectReason(const id, const menu, const item) {
  if(item == MENU_EXIT || item < 0) {
    // Return to prev menu
    switch(ca_gag_menu_type) {
      case _MenuType_Custom: MenuShow_GagProperties(id)
      case _MenuType_Sequential: MenuShow_PlayersList(id)
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)

  new reasonID = strtol(g_itemInfo)
  if(reasonID == ITEM_ENTER_GAG_REASON) {
    client_cmd(id, "messagemode enter_GagReason")

    menu_display(id, menu)
    return PLUGIN_HANDLED
  }

  new reason[reason_s]
  ArrayGetArray(g_gagReasonsTemplates, reasonID, reason)

  // Get predefined reason params
  g_adminGagsEditor[id][gd_reason] = reason

  switch(ca_gag_menu_type) {
    case _MenuType_Custom: MenuShow_GagProperties(id)
    case _MenuType_Sequential: MenuShow_SelectTime(id)
  }

  menu_destroy(menu)
  return PLUGIN_HANDLED
}

// Time choose menu
static MenuShow_SelectTime(const id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new menu = menu_create(fmt("%L", id, "Gag_MenuTitle_SelectTime"), "MenuHandler_SelectTime")

  if(get_user_flags(id) & read_flags(ca_gag_access_flags_high)) {
    menu_additem(menu, fmt("%L", id, "Gag_EnterTime"), fmt("%i", ITEM_ENTER_GAG_REASON))
    menu_addblank(menu, .slot = false)
  }

  // menu_additem(menu, fmt("%L", id, "Gag_Permanent"))

  if(g_gagTimeTemplates_size) {
    for(new i; i < g_gagTimeTemplates_size; i++) {
      new time = ArrayGetCell(g_gagTimeTemplates, i)
      menu_additem(menu, fmt("%s%s", (selectedTime == time) ? "\\r" : "",
        Get_TimeString_seconds(id, time)),
        fmt("%i", time)
      )
    }
  } else {
    menu_addtext(menu, fmt("\\d		%L", id, "Gag_NoTemplatesAvailable_Times"), .slot = false)
  }

  menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
  menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  return menu_display(id, menu)
}

public MenuHandler_SelectTime(const id, const menu, const item) {
  enum { menu_CustomTime/* , menu_Permament  */}

  if(item == MENU_EXIT || item < 0) {
    switch(ca_gag_menu_type) {
      case _MenuType_Custom: MenuShow_GagProperties(id)
      case _MenuType_Sequential: MenuShow_PlayersList(id)
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)

  new timeID = strtol(g_itemInfo)
  if(timeID == ITEM_ENTER_GAG_TIME) {
    client_cmd(id, "messagemode enter_GagTime")

    menu_destroy(menu)
    return PLUGIN_HANDLED
  }
    /* case menu_Permament: {
      g_adminGagsEditor[id][gd_time] = GAG_FOREVER

      MenuShow_GagProperties(id)
      menu_destroy(menu)
      return PLUGIN_HANDLED
    } */

  new time = ArrayGetCell(g_gagTimeTemplates, timeID)
  g_adminGagsEditor[id][gd_reason][r_time] = time

  MenuShow_GagProperties(id)
  menu_destroy(menu)
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
    client_print_color(id, print_team_default, "%s %L", ca_gag_prefix, id, "Gag_NotEnoughPlayers")
    return PLUGIN_HANDLED
  }

  MenuShow_PlayersList(id)
  return PLUGIN_HANDLED
}

public ClCmd_EnterGagReason(const id, const level, const cid) {
  if(!cmd_access(id, level, cid, 1)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  static customReasonName[128]
  read_argv(1, customReasonName, charsmax(customReasonName))

  if(!customReasonName[0]) {
    MenuShow_SelectReason(id)
    return PLUGIN_HANDLED
  }

  copy(g_adminGagsEditor[id][gd_reason][r_name], charsmax(g_adminGagsEditor[][r_name]), customReasonName)

  client_print_color(id, print_team_red, "%s %L (%s)", ca_gag_prefix, id, "Gag_YouSetManual_Reason", g_adminGagsEditor[id][gd_reason][r_name])

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

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerNotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  static timeStr[128]
  read_argv(1, timeStr, charsmax(timeStr))

  new time = strtol(timeStr)
  if(time <= 0) {
    client_print_color(id, print_team_red, "%s %L (%s)!", ca_gag_prefix, id, "Gag_NotValidTimeEntered", timeStr)

    MenuShow_SelectTime(id)
    return PLUGIN_HANDLED
  }

  time *= SECONDS_IN_MINUTE
  g_adminGagsEditor[id][gd_reason][r_time] = time

  client_print_color(id, print_team_red, "%s %L (%s)", ca_gag_prefix, id, "Gag_YouSetManual_Time", Get_TimeString_seconds(id, time))

  MenuShow_GagProperties(id)
  return PLUGIN_HANDLED
}

public SrvCmd_AddReason() {
  enum any: args_s { arg_cmd, arg_reason, arg_flags, arg_time }

  new args[args_s][256]
  for(new arg = arg_cmd; arg < sizeof(args); arg++) {
    read_argv(arg, args[arg], charsmax(args[]))
  }

  new argsCount = read_argc()
  if(argsCount < 2){
    server_print("\tUsage: ca_gag_add_reason <reason> [flags] [time]")
    return
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
/*
 * @endsection user cmds handling
 */


/*
 * @section CA:Core API handling
 */
public CA_Client_Voice(const listener, const sender) {
  return (g_currentGags[sender][gd_reason][r_flags] & gagFlag_Voice) ? CA_SUPERCEDE : CA_CONTINUE
}

public CA_Client_SayTeam(id) {
  return (g_currentGags[id][gd_reason][r_flags] & gagFlag_SayTeam) ? CA_SUPERCEDE : CA_CONTINUE
}

public CA_Client_Say(id) {
  return (g_currentGags[id][gd_reason][r_flags] & gagFlag_Say) ? CA_SUPERCEDE : CA_CONTINUE
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

  // TODO: Rework this
  show_activity_ex(admin, adminName, "%l", "Gag_AdminGagPlayer", name)
  client_print(0, print_chat, "%l %s, %l %s (%s)",
    "Gag_MenuItem_Reason", reason,
    "Gag_MenuItem_Time", gagTimeStr,
    Get_GagFlags_Names(gagFlags_s: flags)
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

  new targetName[MAX_NAME_LENGTH]; get_user_name(target, targetName, charsmax(targetName))

  copy(g_currentGags[target][gd_name], charsmax(g_currentGags[][gd_name]), targetName)
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
  if(!g_gagReasonsTemplates) {
    g_gagReasonsTemplates = ArrayCreate(reason_s)
  } else if(ArraySize(g_gagReasonsTemplates) > 0) {
    ArrayClear(g_gagReasonsTemplates)
  }

  AutoExecConfig(.name = "CA_Gag")

  new configsDir[PLATFORM_MAX_PATH]
  get_configsdir(configsDir, charsmax(configsDir))

  server_cmd("exec %s/plugins/ca_gag_reasons.cfg", configsDir)
  server_exec()

  ParseTimes()
}

static ParseTimes() {
  new buffer[128]; get_cvar_string("ca_gag_times", buffer, charsmax(buffer))

  if(strlen(buffer) > 0) {
    const MAX_TIMES_COUNT = 10
    new times[MAX_TIMES_COUNT][16]

    new count = explode_string(buffer, ",", times, sizeof(times), charsmax(times[]))

    ArrayClear(g_gagTimeTemplates)

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
    copy(buffer, charsmax(buffer), g_adminGagsEditor[id][gd_reason][r_name])
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
  new accessFlagsImmunity = read_flags(ca_gag_immunity_flags)
  new accessFlagsHigh = read_flags(ca_gag_access_flags_high)
  new accessFlags = read_flags(ca_gag_access_flags)

  new flags = get_user_flags(id)
  new targetFlags = get_user_flags(target)

  // main admin can gag everyone
  if(flags & accessFlagsHigh) {
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

static Get_GagFlags_Names(const gagFlags_s: flags) {
  new buffer[64]

  // TODO: ML this
  if(flags & gagFlag_Say)      add(buffer, charsmax(buffer), "Chat, ");
  if(flags & gagFlag_SayTeam)  add(buffer, charsmax(buffer), "Team chat, ");
  if(flags & gagFlag_Voice)    add(buffer, charsmax(buffer), "Voice");

  return buffer
}


static Gag_Save(const id, const target, const time, const flags, const expireAt = 0) {
  GagData_Copy(g_currentGags[target], g_adminGagsEditor[id])
  GagData_Reset(g_adminGagsEditor[id])

  new gag[gagData_s]
  GagData_GetPersonalData(id, target, gag); {
    copy(gag[gd_reason][r_name], charsmax(gag[r_name]), Get_GagString_reason(LANG_PLAYER, target))
    gag[gd_reason][r_time] = time
    gag[gd_reason][r_flags] = gag_flags_s: flags

    gag[gd_expireAt] = (expireAt != 0) ? (expireAt) : (time + get_systime())
  }

  CA_Storage_Save(
    gag[gd_name], gag[gd_authID], gag[gd_IP], gag[gd_reason][r_name],
    gag[gd_adminName], gag[gd_adminAuthID], gag[gd_adminIP],
    gag[gd_expireAt], gag[gd_reason][r_flags]
  )

  g_currentGags[target] = gag

  client_cmd(target, "-voicerecord")
}

static Gag_Remove(const id, const target) {
  if(g_adminGagsEditor[id][gd_reason][r_flags] != gagFlag_Removed) {
    show_activity_ex(id, g_currentGags[target][gd_adminName], "%l", "Gag_AdminUngagPlayer", g_currentGags[target][gd_name])

    GagData_Reset(g_adminGagsEditor[id])
    GagData_Reset(g_currentGags[target])

    new authID[MAX_AUTHID_LENGTH]; get_user_authid(target, authID, charsmax(authID))
    CA_Storage_Remove(authID)
  } else {
    client_print_color(id, print_team_red, "%s %L", ca_gag_prefix, id, "Gag_PlayerAlreadyRemoved", target)
  }

  MenuShow_PlayersList(id)

  return PLUGIN_HANDLED
}

static Gag_Expired(const id) {
  GagData_Reset(g_currentGags[id])

  client_print_color(0, print_team_default, "%s %L", ca_gag_prefix, LANG_PLAYER, "Gag_PlayerExpiredGag", id)
}
