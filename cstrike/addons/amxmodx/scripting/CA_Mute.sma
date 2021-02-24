#include <amxmodx>
#include <amxmisc>

#include <ChatAdditions>

#pragma ctrlchar '\'

new const MSG_PREFIX[] = "\4[MUTE]\1"

new bool: g_playersMute[MAX_PLAYERS + 1][MAX_PLAYERS + 1]
new bool: g_globalMute[MAX_PLAYERS + 1]

new Float: g_nextUse[MAX_PLAYERS + 1]
new Float: ca_mute_use_delay

new const LOG_DIR_NAME[] = "CA_Mute"
new g_sLogsFile[PLATFORM_MAX_PATH]

new ca_log_type,
  LogLevel_s: ca_log_level = _Info

new g_dummy, g_itemInfo[64], g_itemName[128]
enum {
  ITEM_NOT_ENOUTH_PLAYERS = -2,
  ITEM_MUTE_ALL = -1
}


public stock const PluginName[] = "CA: Mute"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "https://Dev-CS.ru/"
public stock const PluginDescription[] = "Players can choose who they can hear."

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)
  register_dictionary("CA_Mute.txt")
  register_dictionary("common.txt")

  bind_pcvar_num(get_cvar_pointer("ca_log_type"), ca_log_type)
  hook_cvar_change(get_cvar_pointer("ca_log_level"), "Hook_CVar_LogLevel")
  GetLogsFilePath(g_sLogsFile, .sDir = LOG_DIR_NAME)

  bind_pcvar_float(create_cvar("ca_mute_use_delay", "3.0",
    .description = "How often can players use menu.",
    .has_min = true, .min_val = 0.0,
    .has_max = true, .max_val = 60.0
  ), ca_mute_use_delay)

  new const CMDS_Mute[][] = { "mute" }
  for(new i; i < sizeof(CMDS_Mute); i++) {
    register_trigger_clcmd(CMDS_Mute[i], "ClCmd_Mute")
  }
}

public plugin_cfg() {
  new sLogLevel[MAX_LOGLEVEL_LEN]
  get_cvar_string("ca_log_level", sLogLevel, charsmax(sLogLevel))
  ca_log_level = ParseLogLevel(sLogLevel)

  CA_Log(_Info, "[CA]: Mute initialized!")
}

public Hook_CVar_LogLevel(pcvar, const old_value[], const new_value[]) {
  ca_log_level = ParseLogLevel(new_value)
}


public ClCmd_Mute(const id) {
  MenuShow_PlayersList(id)

  return PLUGIN_HANDLED
}

static MenuShow_PlayersList(const id) {
  if(!is_user_connected(id))
    return

  new menu = menu_create(fmt("%L", id, "CA_Mute_TITLE"), "MenuHandler_PlayersList")

  static callback
  if(!callback)
    callback = menu_makecallback("MenuCallback_PlayersList")

  new players[MAX_PLAYERS], count
  get_players_ex(players, count, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV))

  if(count < 2) {
    menu_additem(menu, fmt("\\r %L", id, "Mute_NotEnoughPlayers"), fmt("%i", ITEM_NOT_ENOUTH_PLAYERS), .callback = callback)
  } else {
    menu_additem(menu, fmt("\\y %L %s", id, "CA_Mute_MuteALL", g_globalMute[id] ? "\\w[ \\r+\\w ]" : ""), fmt("%i", ITEM_MUTE_ALL))
    menu_addblank(menu, .slot = false)

    new name[128]
    for(new i; i < count; i++) {
      new target = players[i]

      if(target == id) {
        continue
      }

      get_user_name(target, name, charsmax(name))

      if(g_playersMute[id][target]) {
        strcat(name, " \\d[ \\r+\\d ]", charsmax(name))
      }

      if(g_globalMute[target] || g_playersMute[target][id]) {
        strcat(name, fmt(" \\d(\\y%L\\d)", id, "Menu_Muted_you"), charsmax(name))
      }

      menu_additem(menu, name, fmt("%i", get_user_userid(target)), .callback = callback)
    }
  }

  menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
  menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu, .time = 10)
}

public MenuCallback_PlayersList(const id, const menu, const item) {
  menu_item_getinfo(menu, item, g_dummy, g_itemInfo, charsmax(g_itemInfo), g_itemName, charsmax(g_itemName), g_dummy)

  new userID = strtol(g_itemInfo)
  if(userID == ITEM_NOT_ENOUTH_PLAYERS) {
    return ITEM_DISABLED
  }

  // Disable all players in menu when local user muted all
  if(userID != ITEM_MUTE_ALL && g_globalMute[id]) {
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

  new Float: gametime = get_gametime()
  if(g_nextUse[id] > gametime) {
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Menu_UseToOften")

    menu_destroy(menu)
    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  g_nextUse[id] = gametime + ca_mute_use_delay

  new userID = strtol(g_itemInfo)
  if(userID == ITEM_MUTE_ALL) {
    g_globalMute[id] ^= true

    client_print_color(0, print_team_default, "%s \3%n\1 %L ", MSG_PREFIX,
      id, LANG_PLAYER, g_globalMute[id] ? "Player_Muted_All" : "Player_UnMuted_All"
    )

    CA_Log(_Info, "Mute: \"%N\" %smuted everyone", id, g_globalMute[id] ? "" : "Un")

    menu_destroy(menu)
    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new player = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), userID)
  if(player == 0) {
    client_print_color(id, print_team_red, "%s %L", MSG_PREFIX, id, "Player_NotConnected")

    menu_destroy(menu)
    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  g_playersMute[id][player] ^= true
  client_print_color(id, print_team_default, "%s %L \3%n\1", MSG_PREFIX,
    id, g_playersMute[id][player] ? "CA_Mute_Muted" : "CA_Mute_UnMuted", player
  )

  client_print_color(player, print_team_default, "%s \3%n\1 %L ", MSG_PREFIX,
    id, player, g_playersMute[id][player] ? "Player_Muted_you" : "Player_UnMuted_you"
  )

  CA_Log(_Info, "Mute: '%N' %smuted '%N'", id, g_playersMute[id][player] ? "" : "Un", player)

  menu_destroy(menu)
  MenuShow_PlayersList(id)
  return PLUGIN_HANDLED
}


public client_disconnected(id) {
  arrayset(g_playersMute[id], false, sizeof(g_playersMute[]))
  g_globalMute[id] = false
  g_nextUse[id] = 0.0

  for(new i; i < sizeof(g_playersMute[]); i++)
    g_playersMute[i][id] = false
}

public CA_Client_Voice(const listener, const sender) {
  if(g_globalMute[listener]) {
    return CA_SUPERCEDE
  }

  if(g_globalMute[sender]) {
    return CA_SUPERCEDE
  }

  if(g_playersMute[listener][sender] == true) {
    return CA_SUPERCEDE
  }

  return CA_CONTINUE
}
