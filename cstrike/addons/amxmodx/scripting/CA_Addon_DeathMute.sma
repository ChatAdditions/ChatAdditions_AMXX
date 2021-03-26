#include <amxmodx>
#include <amxmisc>
#include <reapi>

#include <ChatAdditions>

#pragma ctrlchar '\'
#pragma tabsize 2

new Float: ca_deathmute_time,
  bool: ca_deathmute_dead_hear_alive,
  NotifyType_s: ca_deathmute_notify_type,
  bool: ca_deathmute_notify_show_progressbar,
  Float: ca_deathmute_notify_hud_x,
  Float: ca_deathmute_notify_hud_y,
  ca_deathmute_notify_hud_r,
  ca_deathmute_notify_hud_g,
  ca_deathmute_notify_hud_b

enum NotifyType_s: {
  notify_Disabled,
  notify_Chat,
  notify_HUD
}

new bool: g_canSpeakWithAlive[MAX_PLAYERS + 1] = { false, ... }

public stock const PluginName[] = "CA Addon: Death mute"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "github.com/ChatAdditions/ChatsAdditions_AMXX"
public stock const PluginDescription[] = "Alive players don't hear dead players after 5 secs"

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)
  register_dictionary("CA_Addon_DeathMute.txt")

  Register_CVars()

  AutoExecConfig(true, "CA_Addon_DeathMute")

  RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", .post = true)
  RegisterHookChain(RG_CSGameRules_PlayerSpawn, "CBasePlayer_Spawn", .post = true)
}

Register_CVars() {
  bind_pcvar_float(create_cvar("ca_deathmute_time", "5.0",
      .description = "Time (in seconds) for killed players, during which they can report information to living players.\n\
        0 - disabled functionality",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 240.0
    ), ca_deathmute_time
  )

  bind_pcvar_num(create_cvar("ca_deathmute_dead_hear_alive", "1",
      .description = "Death mute mode \n\
        0 - alive hear only alive, dead hear all\n\
        1 - alive hear only alive, dead hear only dead"
    ), ca_deathmute_dead_hear_alive
  )

  bind_pcvar_num(create_cvar("ca_deathmute_notify_type", "1",
      .description = "Notification type for dead players \n\
        0 - disabled functionality\n\
        1 - chat message\n\
        2 - HUD message"
    ), ca_deathmute_notify_type
  )

  bind_pcvar_num(create_cvar("ca_deathmute_notify_show_progressbar", "1",
      .description = "Show progressbar \n\
        0 - disabled functionality"
    ), ca_deathmute_notify_show_progressbar
  )

  bind_pcvar_float(create_cvar("ca_deathmute_notify_hud_x", "-1.0",
      .description = "X position for HUD message\n\
        -1.0 - center",
      .has_min = true, .min_val = -1.0,
      .has_max = true, .max_val = 1.0
    ), ca_deathmute_notify_hud_x
  )

  bind_pcvar_float(create_cvar("ca_deathmute_notify_hud_y", "0.15",
      .description = "Y position for HUD message\n\
        -1.0 - center",
      .has_min = true, .min_val = -1.0,
      .has_max = true, .max_val = 1.0
    ), ca_deathmute_notify_hud_y
  )

  bind_pcvar_num(create_cvar("ca_deathmute_notify_hud_r", "200",
      .description = "Red color value (in RGB) [0...255]",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 255.0
    ), ca_deathmute_notify_hud_r
  )

  bind_pcvar_num(create_cvar("ca_deathmute_notify_hud_g", "50",
      .description = "Green color value (in RGB) [0...255]",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 255.0
    ), ca_deathmute_notify_hud_g
  )

  bind_pcvar_num(create_cvar("ca_deathmute_notify_hud_b", "0",
      .description = "Blue color value (in RGB) [0...255]",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 255.0
    ), ca_deathmute_notify_hud_b
  )
}

public client_disconnected(id) {
  g_canSpeakWithAlive[id] = false
  if(task_exists(id)) {
    remove_task(id)
  }
}

public CBasePlayer_Spawn(const id) {
  g_canSpeakWithAlive[id] = true
  if(task_exists(id)) {
    remove_task(id)
  }
}

public CBasePlayer_Killed(const id, const attacker) {
  if(ca_deathmute_time <= 0.0) {
    return
  }

  set_task_ex(ca_deathmute_time, "DisableSpeakWithAlive", .id = id)

  if(ca_deathmute_notify_type == notify_Disabled) {
    return
  }

  if(ca_deathmute_notify_type == notify_Chat) {
    client_print_color(id, print_team_red, "%L %L", id, "DeathMute_prefix", id, "DeathMute_ChatMessage", ca_deathmute_time)
  }

  if(ca_deathmute_notify_type == notify_HUD) {
    set_hudmessage(
      ca_deathmute_notify_hud_r,
      ca_deathmute_notify_hud_g,
      ca_deathmute_notify_hud_b,
      ca_deathmute_notify_hud_x,
      ca_deathmute_notify_hud_y,
      .fadeouttime = 0.0,
      .holdtime = ca_deathmute_time - 1.0
    )
    show_hudmessage(id, "%L", id, "DeathMute_ChatMessage", ca_deathmute_time)
  }

  if(ca_deathmute_notify_show_progressbar) {
    UTIL_BarTime(id, floatround(ca_deathmute_time))
  }
}

public DisableSpeakWithAlive(const id) {
  g_canSpeakWithAlive[id] = false

  if(ca_deathmute_notify_type == notify_Disabled) {
    return
  }

  if(ca_deathmute_notify_type == notify_Chat) {
    client_print_color(id, print_team_red, "%L %L", id, "DeathMute_prefix", id, "DeathMute_YouMuted")
  }

  if(ca_deathmute_notify_type == notify_HUD) {
    set_hudmessage(
      ca_deathmute_notify_hud_r,
      ca_deathmute_notify_hud_g,
      ca_deathmute_notify_hud_b,
      ca_deathmute_notify_hud_x,
      ca_deathmute_notify_hud_y,
      .fadeouttime = 0.0,
      .holdtime = ca_deathmute_time - 1.0
    )
    show_hudmessage(id, "%L", id, "DeathMute_YouMuted", ca_deathmute_time)
  }
}

public CA_Client_Voice(const listener, const sender) {
  if(ca_deathmute_time <= 0.0) {
    return CA_CONTINUE
  }

  new bool: listenerAlive = is_user_alive(listener)
  new bool: senderAlive = is_user_alive(sender)

  if(!g_canSpeakWithAlive[sender] && !senderAlive && listenerAlive) {
    return CA_SUPERCEDE
  }

  if(!ca_deathmute_dead_hear_alive && !listenerAlive && senderAlive) {
    return CA_SUPERCEDE
  }

  return CA_CONTINUE
}

