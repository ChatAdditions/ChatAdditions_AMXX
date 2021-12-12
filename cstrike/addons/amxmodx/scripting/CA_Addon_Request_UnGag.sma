#include <amxmodx>
#include <amxmisc>

#include <ChatAdditions>
#include <CA_GAG_API>

#pragma ctrlchar '\'
#pragma tabsize 2

static Float: g_userNextRequestTime[MAX_PLAYERS + 1]

static ca_requestungag_cmd[32],
  ca_requestungag_admin_flag[16],
  Float: ca_requestungag_delay

public stock const PluginName[] = "CA Addon: Request UnGAG"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "steelzzz"
public stock const PluginURL[] = "github.com/ChatAdditions/ChatsAdditions_AMXX"
public stock const PluginDescription[] = "A player can apologize to the administration"

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)
  register_dictionary("CA_Addon_RequestUngag.txt")

  Register_CVars()
  AutoExecConfig(true, "CA_Addon_RequestUnGag", "ChatAdditions")

  register_clcmd(ca_requestungag_cmd, "Command_RequestUngag")

  new accessFlag = read_flags(ca_requestungag_admin_flag)
  register_clcmd("say", "Hook_Say", accessFlag, .FlagManager = false)
}

public Register_CVars() {
  bind_pcvar_string(create_cvar("ca_requestungag_cmd", "say /sorry",
      .description = "Request ungag command"),
    ca_requestungag_cmd, charsmax(ca_requestungag_cmd)
  )

  bind_pcvar_string(create_cvar("ca_requestungag_admin_flag", "a",
      .description = "Admin Flag"),
    ca_requestungag_admin_flag, charsmax(ca_requestungag_admin_flag)
  )

  bind_pcvar_float(create_cvar("ca_requestungag_delay", "5.0",
      .description = "delay time request ungag",
      .has_min = true, .min_val = 1.0),
    ca_requestungag_delay
  )
}

public Command_RequestUngag(const player) {
  if(!ca_has_user_gag(player)) {
    client_print_color(player, print_team_default, "%L", player, "RequestUnGag_NoAccess")

    return PLUGIN_HANDLED
  }

  new Float: gametime = get_gametime()

  if(g_userNextRequestTime[player] > gametime) {
    new timeLeft = floatround(g_userNextRequestTime[player] - gametime, floatround_ceil)
    client_print_color(player, print_team_default, "%L", player, "RequestUnGag_TimeOut", timeLeft)

    return PLUGIN_HANDLED
  }

  new userID = get_user_userid(player)

  new players[MAX_PLAYERS], count
  get_players_ex(players, count, (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV))

  for(new i; i < count; i++) {
    if(!(get_user_flags(i) & read_flags(ca_requestungag_admin_flag)))
      continue

    client_print_color(i, print_team_default, "%L",
      player, "RequestUnGag_Requested",
      player, userID
    )
  }

  g_userNextRequestTime[player] = gametime + ca_requestungag_delay

  client_print_color(player, print_team_default, "%L", player, "RequestUnGag_YouRequested")
  return PLUGIN_HANDLED
}

public Hook_Say(const player, const accessLevel, const cid) {
  if(!cmd_access(player, accessLevel, cid, true))
    return PLUGIN_CONTINUE

  new args[20]
  read_args(args, charsmax(args))
  remove_quotes(args)

  new const strFind[] = "/unmute"
  if(strncmp(args, strFind, charsmax(strFind)) != 0)
    return PLUGIN_CONTINUE

  new targetStr[3]
  copy(targetStr, charsmax(targetStr), args[charsmax(strFind)]) // TODO: do it better later

  new target = find_player_ex(FindPlayer_MatchUserId | FindPlayer_ExcludeBots, strtol(targetStr))

  if(!is_user_connected(target))
    return PLUGIN_CONTINUE

  if(!ca_has_user_gag(target))
    return PLUGIN_CONTINUE

  new ret = ca_remove_user_gag(target, player)

  client_print_color(player, print_team_default, "%L", player,
    ret ? "RequestUnGag_Unblocked" : "RequestUnGag_NonUnblocked", target
  )

  return PLUGIN_CONTINUE
}
