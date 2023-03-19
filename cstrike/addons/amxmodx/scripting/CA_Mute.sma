#include <amxmodx>
#include <amxmisc>

#include <ChatAdditions>

#pragma ctrlchar '\'
#pragma tabsize 2

new bool: g_playersMute[MAX_PLAYERS + 1][MAX_PLAYERS + 1]
new bool: g_globalMute[MAX_PLAYERS + 1]

new Float: g_nextUse[MAX_PLAYERS + 1]

new Float: ca_mute_use_delay

new g_dummy, g_itemInfo[64], g_itemName[128]

enum {
  ITEM_NOT_ENOUTH_PLAYERS = -2,
  ITEM_MUTE_ALL = -1
}

public stock const PluginName[] = "CA: Mute"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "https://github.com/ChatAdditions/"
public stock const PluginDescription[] = "Players can choose who they can hear."

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)

  register_dictionary("CA_Mute.txt")
  register_dictionary("common.txt")

  bind_pcvar_float(create_cvar("ca_mute_use_delay", "3",
      .description = "How often players can use menu. (in seconds)",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 120.0
    ),
    ca_mute_use_delay
  )

  new const CMDS_Mute[][] = { "mute" }

  for(new i; i < sizeof(CMDS_Mute); i++) {
    register_trigger_clcmd(CMDS_Mute[i], "ClCmd_Mute", ADMIN_ALL, .FlagManager = false)
  }

  AutoExecConfig(true, "CA_Mute", "ChatAdditions")

  CA_Log(logLevel_Debug, "[CA]: Mute initialized!")
}


public ClCmd_Mute(const id) {
  if(!is_user_connected(id)) {
    return PLUGIN_CONTINUE
  }

  if(get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV) < 2) {
    client_print_color(id, print_team_default, "%L %L", id, "Mute_prefix", id, "Mute_NotEnoughPlayers")
    return PLUGIN_HANDLED
  }

  MenuShow_PlayersList(id)

  return PLUGIN_HANDLED
}

static MenuShow_PlayersList(const id) {
  if(!is_user_connected(id)) {
    return
  }

  new menu = menu_create(fmt("%L", id, "Mute_MenuTitle"), "MenuHandler_PlayersList")

  static callback

  if(!callback) {
    callback = menu_makecallback("MenuCallback_PlayersList")
  }

  new players[MAX_PLAYERS], count
  get_players_ex(players, count, .flags = (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV))

  if(count < 2) {
    menu_additem(menu, fmt("\\r %L", id, "Mute_NotEnoughPlayers"), fmt("%i", ITEM_NOT_ENOUTH_PLAYERS), .callback = callback)
  } else {
    menu_additem(menu, fmt("\\y %L %s\n", id, "Mute_MuteAll", g_globalMute[id] ? "\\w[ \\r+\\w ]" : ""), fmt("%i", ITEM_MUTE_ALL))

    new name[128]
    for(new i; i < count; i++) {
      new target = players[i]

      if(target == id) {
        continue
      }

      get_user_name(target, name, charsmax(name))

      if(g_playersMute[id][target] || CA_PlayerHasBlockedPlayer(id, target)) {
        strcat(name, " \\d[ \\r+\\d ]", charsmax(name))
      }

      if(g_globalMute[target] || g_playersMute[target][id] || CA_PlayerHasBlockedPlayer(target, id)) {
        strcat(name, fmt(" \\d(\\y%L\\d)", id, "Mute_PlayerMutedYou"), charsmax(name))
      }

      menu_additem(menu, name, fmt("%i", get_user_userid(target)), .callback = callback)
    }
  }

  menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
  menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
  menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))

  menu_display(id, menu)
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

  new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), userID)

  if(CA_PlayerHasBlockedPlayer(id, target)) {
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

  new Float: gametime = get_gametime()

  if(g_nextUse[id] > gametime) {
    client_print_color(id, print_team_red, "%L %L", id, "Mute_prefix", id, "Mute_UseTooOften")
    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  g_nextUse[id] = gametime + ca_mute_use_delay

  new userID = strtol(g_itemInfo)

  if(userID == ITEM_MUTE_ALL) {
    g_globalMute[id] ^= true

    client_print_color(0, print_team_default, "%L \3%n\1 %L ", id, "Mute_prefix",
      id, LANG_PLAYER, g_globalMute[id] ? "Mute_PlayerNowMutedAll" : "Mute_PlayerNowUnmutedAll"
    )

    CA_Log(logLevel_Info, "Mute: \"%N\" %sMuted everyone", id, g_globalMute[id] ? "" : "Un")
    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  new player = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), userID)

  if(player == 0) {
    client_print_color(id, print_team_red, "%L %L", id, "Mute_prefix", id, "Mute_PlayerNotConnected")
    MenuShow_PlayersList(id)
    return PLUGIN_HANDLED
  }

  g_playersMute[id][player] ^= true

  client_print_color(id, print_team_default, "%L %L \3%n\1", id, "Mute_prefix",
    id, g_playersMute[id][player] ? "Mute_YouMutePlayer" : "Mute_YouUnmutePlayer", player
  )

  client_print_color(player, print_team_default, "%L \3%n\1 %L ", id, "Mute_prefix",
    id, player, g_playersMute[id][player] ? "Mute_PlayerNowMutedYou" : "Mute_PlayerNowUnmutedYou"
  )

  CA_Log(logLevel_Info, "Mute: '%N' %smuted '%N'", id, g_playersMute[id][player] ? "" : "Un", player)
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
