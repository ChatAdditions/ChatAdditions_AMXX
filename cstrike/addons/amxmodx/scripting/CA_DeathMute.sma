#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>

#include <ChatAdditions>

new ca_deathmute_prefix[32],
  Float: ca_deathmute_time


new bool: g_canSpeakWithAlive[MAX_PLAYERS + 1] = { false, ... }

public stock const PluginName[] = "ChatAdditions: Death mute"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "github.com/ChatAdditions/ChatsAdditions_AMXX"
public stock const PluginDescription[] = "Alive players don't hear dead players after 5secs"

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)
  register_dictionary("CA_DeathMute.txt")

  Register_CVars()

  AutoExecConfig(true, "CA_DeathMute")

  RegisterHamPlayer(Ham_Killed, "CBasePlayer_Killed", .Post = true)
  RegisterHamPlayer(Ham_Spawn, "CBasePlayer_Spawn", .Post = true)
}

Register_CVars() {
  bind_pcvar_string(create_cvar("ca_deathmute_prefix", "[Death mute]",
      .description = "Chat prefix for plugin actions"
    ), ca_deathmute_prefix, charsmax(ca_deathmute_prefix)
  )

  bind_pcvar_float(create_cvar("ca_deathmute_time", "5.0",
      .description = "Time (in seconds) for killed players, during which they can report information to living players.\n\
        0 - disabled functionality",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 240.0
    ), ca_deathmute_time
  )
}

public client_disconnected(id) {
  g_canSpeakWithAlive[id] = false
  if(task_exists(id)) {
    remove_task(id)
  }
}

public CBasePlayer_Spawn(const id) {
  if(!is_user_alive(id)) {
    return
  }

  g_canSpeakWithAlive[id] = true
}

public CBasePlayer_Killed(const id, const attacker) {
  if(ca_deathmute_time <= 0.0) {
    return
  }

  client_print_color(id, print_team_red, "%s %L", ca_deathmute_prefix, id, "DeathMute_ChatMessage", ca_deathmute_time)
  set_task_ex(ca_deathmute_time, "DisableSpeakWithAlive", .id = id)
}

public DisableSpeakWithAlive(const id) {
  g_canSpeakWithAlive[id] = false
  client_print_color(id, print_team_red, "%s %L", ca_deathmute_prefix, id, "DeathMute_YouMuted")
}

public CA_Client_Voice(const listener, const sender) {
  if(!g_canSpeakWithAlive[sender] && !is_user_alive(sender)) {
    return CA_SUPERCEDE
  }

  return CA_CONTINUE
}

