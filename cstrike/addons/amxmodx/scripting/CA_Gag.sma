#include <amxmodx>
#include <amxmisc>
#include <time>

#include <ChatAdditions>
#include <CA_GAG_API>
#include <CA_StorageAPI>

#pragma ctrlchar '\'
#pragma dynamic 524288


  /* ----- START SETTINGS----- */
new const MSG_PREFIX[] = "\4[GAG]\1"

#define FLAGS_ACCESS    ( ADMIN_KICK )
#define FLAGS_IMMUNITY  ( ADMIN_IMMUNITY )

const Float: GAG_THINKER_FREQ = 3.0
  /* ----- END OF SETTINGS----- */

static g_currentGags[MAX_PLAYERS + 1][gagData_s]
static g_adminGagsEditor[MAX_PLAYERS + 1][gagData_s]

static Array: g_gagReasonsTemplates, g_gagReasonsTemplates_size
static Array: g_gagTimeTemplates, g_gagTimeTemplates_size

enum GagMenuType_s {
  _MenuType_Custom,
  _MenuType_Sequential
}; new GagMenuType_s: ca_gag_menu_type

new g_dummy, g_itemInfo[64], g_itemName[128]
enum {
  ITEM_ENTER_GAG_REASON = -1
}

new const LOG_DIR_NAME[] = "CA_Gag"
new g_sLogsFile[PLATFORM_MAX_PATH]

new ca_log_type,
  LogLevel_s: ca_log_level = _Info

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

  bind_pcvar_num(get_cvar_pointer("ca_log_type"), ca_log_type)
  hook_cvar_change(get_cvar_pointer("ca_log_level"), "Hook_CVar_LogLevel")
  GetLogsFilePath(g_sLogsFile, .sDir = LOG_DIR_NAME)

  hook_cvar_change(
    create_cvar("ca_gag_times", "1, 5, 30, 60, 1440, 10080"),
    "Hook_CVar_Times"
  )

  bind_pcvar_num(create_cvar("ca_gag_menu_type", "1"), ca_gag_menu_type)

  register_srvcmd("ca_gag_add_reason", "SrvCmd_AddReason")
  register_srvcmd("ca_gag_show_templates", "SrvCmd_ShowTemplates");
  register_srvcmd("ca_gag_reload_config", "SrvCmd_ReloadConfig")

  set_task_ex(GAG_THINKER_FREQ, "Gags_Thinker", .flags = SetTask_Repeat)

  new const CMDS_Mute[][] = { "gag" }
  for(new i; i < sizeof(CMDS_Mute); i++) {
    register_trigger_clcmd(CMDS_Mute[i], "ClCmd_Gag", FLAGS_ACCESS)
  }

  register_clcmd("enter_GagReason", "ClCmd_EnterGagReason")
  register_clcmd("enter_GagTime", "ClCmd_EnterGagTime")
}

public plugin_cfg() {
  new sLogLevel[MAX_LOGLEVEL_LEN]
  get_cvar_string("ca_log_level", sLogLevel, charsmax(sLogLevel))
  ca_log_level = ParseLogLevel(sLogLevel)

  LoadConfig()
  ParseTimes()

  CA_Log(_Info, "[CA]: Gag initialized!")
}

public Hook_CVar_LogLevel(pcvar, const old_value[], const new_value[]) {
  ca_log_level = ParseLogLevel(new_value)
}

public Hook_CVar_Times(pcvar, const old_value[], const new_value[]) {
  if(!strlen(new_value)) {
    CA_Log(_Warnings, "[WARN] not found times! ca_gag_add_time ='%s'", new_value)
    return
  }

  ParseTimes(new_value)
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

  new menu = menu_create(fmt("%L", id, "CA_Gag_TITLE"), "MenuHandler_PlayersList")

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

    new bool: hasImmunity = bool: (get_user_flags(target) & FLAGS_IMMUNITY)
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

  new bool: hasImmunity = bool: (get_user_flags(target) & FLAGS_IMMUNITY)
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
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  // Remove already gagged player
  if(g_currentGags[target][gd_reason][r_flags] != gagFlag_Removed) {
    GagData_Copy(g_adminGagsEditor[id], g_currentGags[target])
    g_adminGagsEditor[id][gd_target] = target

    MenuShow_ConfirmRemove(id)
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

// Confirm remove gag menu
static MenuShow_ConfirmRemove(const id) {
  if(!is_user_connected(id)) {
    return
  }

  new menu = menu_create(fmt("%L", id, "GAG_Confirm"), "MenuHandler_ConfirmRemove")

  menu_additem(menu, fmt("%L", id, "CA_GAG_YES"))
  menu_additem(menu, fmt("%L", id, "CA_GAG_NO"))

  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)
  menu_addblank2(menu)

  menu_setprop(menu, MPROP_PERPAGE, 0)
  menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE)
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)
}

public MenuHandler_ConfirmRemove(const id, const menu, const item) {
  enum { menu_ComfirmRemove, menu_EditGagProperties }

  if(item == MENU_EXIT || item < 0) {
    GagData_Reset(g_adminGagsEditor[id])

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

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
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

    MenuShow_PlayersList(id)
    return
  }

  new menu = menu_create(fmt("%L", id, "CA_Gag_Properties", target), "MenuHandler_GagProperties")

  static callback
  if(!callback) {
    callback = menu_makecallback("MenuCallback_GagProperties")
  }

  new gag_flags_s: gagFlags = g_adminGagsEditor[id][gd_reason][r_flags]
  new bool: alreadyHasGag = (g_currentGags[target][gd_reason][r_flags] != gagFlag_Removed)
  new bool: hasChanges = !GagData_IsEqual(g_currentGags[target], g_adminGagsEditor[id])

  menu_additem(menu, fmt("%L [ %s ]", id, "CA_Gag_Say",
    (gagFlags & gagFlag_Say) ? " \\r+\\w " : "-")
  )
  menu_additem(menu, fmt("%L [ %s ]", id, "CA_Gag_SayTeam",
    (gagFlags & gagFlag_SayTeam) ? " \\r+\\w " : "-")
  )
  menu_additem(menu, fmt("%L [ %s ]", id, "CA_Gag_Voice",
    (gagFlags & gagFlag_Voice) ? " \\r+\\w " : "-")
  )

  if(ca_gag_menu_type == _MenuType_Custom) {
    menu_addblank(menu, false)

    menu_additem(menu, fmt("%L [ \\y%s\\w ]", id, "Gag_Menu_Reason",
      Get_GagString_reason(id, target)), .callback = callback
    )
    menu_additem(menu, fmt("%L [ \\y%s\\w ]", id, "CA_Gag_Time",
      Get_TimeString_seconds(id, g_adminGagsEditor[id][gd_reason][r_time]))
    )
  }

  menu_addblank(menu, false)

  menu_additem(menu, fmt("%L %s", id, "CA_Gag_Confirm",
    (alreadyHasGag && hasChanges) ? "edit" : ""), .callback = callback
  )

  menu_addtext(menu, fmt("\n%L", id, "Menu_WannaGag",
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
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

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

        Gag_Save(id, target, time, flags)

        menu_destroy(menu)
        return PLUGIN_HANDLED
      }
    }
  } else {
    switch(item) {
      case sequential_Confirm: {
        new time = g_adminGagsEditor[id][gd_reason][r_time]
        new flags = g_adminGagsEditor[id][gd_reason][r_flags]

        Gag_Save(id, target, time, flags)

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
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new menu = menu_create(fmt("%L", id, "MENU_SelectReason"), "MenuHandler_SelectReason")
  menu_additem(menu, fmt("%L\n", id, "EnterReason"), fmt("%i", ITEM_ENTER_GAG_REASON))

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
    menu_addtext(menu, fmt("\\d		%L", id, "NoHaveReasonsTemplates"), .slot = false)
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
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

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
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new menu = menu_create(fmt("%L", id, "MENU_SelectTime"), "MenuHandler_SelectTime")

  menu_additem(menu, fmt("%L", id, "SET_CustomTime"))
  // menu_additem(menu, fmt("%L", id, "CA_Gag_Perpapent"))
  menu_addblank(menu, .slot = false)

  new selectedTime = g_adminGagsEditor[id][gd_reason][r_time]

  if(g_gagTimeTemplates_size) {
    for(new i; i < g_gagTimeTemplates_size; i++) {
      new time = ArrayGetCell(g_gagTimeTemplates, i) * SECONDS_IN_MINUTE
      menu_additem(menu, fmt("%s%s", (selectedTime == time) ? "\\r" : "",
        Get_TimeString_seconds(id, time)),
        fmt("%i", time)
      )
    }
  } else {
    menu_addtext(menu, fmt("\\d		%L", id, "NoHaveTimeTemplates"), .slot = false)
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
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

    MenuShow_PlayersList(id)
    menu_destroy(menu)
    return PLUGIN_HANDLED
  }

  switch(item) {
    case menu_CustomTime: {
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
  }

  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)
  g_adminGagsEditor[id][gd_reason][r_time] = strtol(g_itemInfo)

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
    client_print_color(id, print_team_default, "%s %L", MSG_PREFIX, id, "NotEnoughPlayers")
    return PLUGIN_HANDLED
  }

  MenuShow_PlayersList(id)
  return PLUGIN_HANDLED
}

public ClCmd_EnterGagReason(const id) {
  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

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

  client_print(id, print_chat, "%L '%s'", id, "CustomReason_Setted", g_adminGagsEditor[id][gd_reason][r_name])

  MenuShow_SelectTime(id)
  return PLUGIN_HANDLED
}

public ClCmd_EnterGagTime(id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED
  }

  new target = g_adminGagsEditor[id][gd_target]
  if(!is_user_connected(target)) {
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  static timeStr[128]
  read_argv(1, timeStr, charsmax(timeStr))

  new time = strtol(timeStr)
  if(time == 0) {
    client_print_color(id, print_team_red, "%s Not valid time (%s)!", MSG_PREFIX, timeStr)

    MenuShow_SelectTime(id)
    return PLUGIN_HANDLED
  }

  g_adminGagsEditor[id][gd_reason][r_time] = time

  client_print(id, print_chat, "%L '%s'", id, "CustomTime_Setted", Get_TimeString_seconds(id, time))

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
    CA_Log(_Warnings, "\tUsage: ca_gag_add_reason <reason> [flags] [time in minutes]")
    return
  }

  new reason[reason_s]
  copy(reason[r_name], charsmax(reason[r_name]), args[arg_reason])
  reason[r_time] = (strtol(args[arg_time]) * SECONDS_IN_MINUTE)
  reason[r_flags] = gag_flags_s: flags_to_bit(args[arg_flags])

  ArrayPushArray(g_gagReasonsTemplates, reason)
  g_gagReasonsTemplates_size = ArraySize(g_gagReasonsTemplates)

  CA_Log(_Debug, "ADD: Reason[#%i]: '%s' (Flags:'%s', Time:'%i s.')",\
    g_gagReasonsTemplates_size, reason[r_name], bits_to_flags(reason[r_flags]), reason[r_time]\
  )
}

public SrvCmd_ShowTemplates() {
  if(!g_gagReasonsTemplates_size) {
    CA_Log(_Warnings, "\t NO REASONS FOUNDED!")
    return PLUGIN_HANDLED
  }

  for(new i; i < g_gagReasonsTemplates_size; i++) {
    new reason[reason_s]
    ArrayGetArray(g_gagReasonsTemplates, i, reason)

    CA_Log(_Info, "Reason[#%i]: '%s' (Flags:'%s', Time:'%i')",\
      i + 1, reason[r_name], bits_to_flags(reason[r_flags]), reason[r_time]\
    )
  }

  return PLUGIN_HANDLED
}

public SrvCmd_ReloadConfig() {
  LoadConfig()
  ParseTimes()

  CA_Log(_Info, "Config re-loaded!")
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
  // TODO
}
public CA_Storage_Saved(const name[], const authID[], const IP[], const reason[],
  const adminName[], const adminAuthID[], const adminIP[],
  const createdAt, const expireAt, const flags) {

  new gagTime = expireAt - createdAt
  new gagTimeStr[32]; copy(gagTimeStr, charsmax(gagTimeStr), Get_TimeString_seconds(LANG_PLAYER, gagTime))

  client_print_color(0, print_team_default, "%s %L", MSG_PREFIX,
    LANG_PLAYER, "Player_Gagged", adminName, name, gagTimeStr
  )

  client_print_color(0, print_team_default, "%L '\3%s\1'", LANG_PLAYER, "CA_Gag_Reason", reason)

  CA_Log(_Info, "Gag: \"%s\" add gag to \"%s\" (type:\"%s\") (time:\"%s\") (reason:\"%s\")", \
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

  copy(g_currentGags[target][gd_adminName], charsmax(g_currentGags[][gd_adminName]), adminName)

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

  new sConfigsDir[PLATFORM_MAX_PATH]
  get_configsdir(sConfigsDir, charsmax(sConfigsDir))
  server_cmd("exec %s/ChatAdditions/gag_reasons.cfg", sConfigsDir)
  server_exec()
}

static ParseTimes(const _buffer[] = "") {
  new buffer[128]

  if(buffer[0] == EOS) {
    get_cvar_string("ca_gag_times", buffer, charsmax(buffer))
  } else {
    copy(buffer, charsmax(buffer), _buffer)
  }

  ArrayClear(g_gagTimeTemplates)

  new ePos, stPos, rawPoint[32]
  do {
    ePos = strfind(buffer[stPos],",")
    formatex(rawPoint, ePos, buffer[stPos])
    stPos += ePos + 1

    trim(rawPoint)

    if(rawPoint[0])
      ArrayPushCell(g_gagTimeTemplates, strtol(rawPoint))
  } while(ePos != -1)

  g_gagTimeTemplates_size = ArraySize(g_gagTimeTemplates)
}

static Get_TimeString_seconds(const id, const seconds) {
  new timeStr[32]
  get_time_length(id, seconds, timeunit_seconds, timeStr, charsmax(timeStr))

  if(timeStr[0] == EOS) {
    formatex(timeStr, charsmax(timeStr), "%L", id, "CA_Gag_NotSet")
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
    formatex(buffer, charsmax(buffer), "%L", id, "CA_Gag_NotSet")
  }

  return buffer
}

static Get_PlayerPostfix(const id, const target, const hasImmunity) {
  new postfix[32]

  if(hasImmunity) {
    formatex(postfix, charsmax(postfix), " [\\r%L\\d]", id, "Immunity")
  } else if(g_currentGags[target][gd_reason][r_flags]) {
    formatex(postfix, charsmax(postfix), " [\\y%L\\w]", id, "Gag")
  }

  return postfix
}


static Gag_Save(const id, const target, const time, const flags) {
  GagData_Copy(g_currentGags[target], g_adminGagsEditor[id])
  GagData_Reset(g_adminGagsEditor[id])

  new gag[gagData_s]
  GagData_GetPersonalData(id, target, gag); {
    copy(gag[gd_reason][r_name], charsmax(gag[r_name]), Get_GagString_reason(LANG_PLAYER, target))
    gag[gd_reason][r_time] = time
    gag[gd_reason][r_flags] = gag_flags_s: flags

    gag[gd_expireAt] = time + get_systime()
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
    GagData_Reset(g_adminGagsEditor[id])
    GagData_Reset(g_currentGags[target])

    new authID[MAX_AUTHID_LENGTH]; get_user_authid(target, authID, charsmax(authID))
    CA_Storage_Remove(authID)

    client_print_color(0, print_team_default, "%s %L", MSG_PREFIX,
      LANG_PLAYER, "Player_UnGagged", id, target)
  } else {
    client_print(id, print_chat, "%s %L", MSG_PREFIX, id, "Player_AlreadyRemovedGag", target)
  }

  MenuShow_PlayersList(id)

  return PLUGIN_HANDLED
}

static Gag_Expired(const id) {
  GagData_Reset(g_currentGags[id])

  client_print_color(0, print_team_default, "%s %L", MSG_PREFIX, LANG_PLAYER, "Player_ExpiredGag", id)
}
