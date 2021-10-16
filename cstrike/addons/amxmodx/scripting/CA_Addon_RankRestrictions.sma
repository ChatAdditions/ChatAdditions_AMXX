#include <amxmodx>
#include <ChatAdditions>

#pragma ctrlchar '\'

// Natives
native aes_get_player_level(const player)
native ar_get_user_level(const player, rankName[] = "", len = 0)
native crxranks_get_user_level(const player)

native csstats_get_user_stats(const player, const stats[22])
//


static ca_rankrestrictions_type,
  ca_rankrestrictions_min_kills,
  ca_rankrestrictions_type_level,
  ca_rankrestrictions_min_level,
  ca_rankrestrictions_immunity_flag[16]

public stock const PluginName[] = "CA Addon: Rank restrictions"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "steelzzz"
public stock const PluginURL[] = "github.com/ChatAdditions/ChatsAdditions_AMXX"
public stock const PluginDescription[] = "Restrict chat until you reach the rank of a statistic"

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)
  register_dictionary("CA_Addon_RankRestrictions.txt")

  Register_CVars()

  AutoExecConfig(true, "CA_Addon_RankRestrictions", "ChatAdditions")
}

public plugin_natives() {
  set_native_filter("native_filter")
}

public native_filter(const name[], index, trap) {
  if(strcmp(name, "aes_get_player_level"))
    return  PLUGIN_HANDLED

  if(strcmp(name, "ar_get_user_level"))
    return  PLUGIN_HANDLED

  if(strcmp(name, "crxranks_get_user_level"))
    return  PLUGIN_HANDLED

  if(strcmp(name, "csstats_get_user_stats"))
    return  PLUGIN_HANDLED

  return PLUGIN_CONTINUE
}

static Register_CVars() {
  bind_pcvar_num(create_cvar("ca_rankrestrictions_type", "1",
    .description = "Restrictions Types\n\
      0 - Disable restrictions\n\
      1 - Level restrictions\n\
      2 - Kills count restrictions",
    .has_min = true, .min_val = 0.0,
    .has_max = true, .max_val = 2.0
    ), ca_rankrestrictions_type
  )

  bind_pcvar_num(create_cvar("ca_rankrestrictions_min_kills", "10",
    .description = "Min kills count to access voice & text chat",
    .has_min = true, .min_val = 0.0
    ), ca_rankrestrictions_min_kills
  )

  bind_pcvar_num(create_cvar("ca_rankrestrictions_type_level", "1",
    .description = "Level System Types\n\
      0 - Advanced Experience System\n\
      1 - Army Ranks Ultimate\n\
      2 - OciXCrom's Rank System",
    .has_min = true, .min_val = 0.0,
    .has_max = true, .max_val = 2.0
    ), ca_rankrestrictions_type_level
  )

  bind_pcvar_num(create_cvar("ca_rankrestrictions_min_level", "2",
    .description = "Min Level to access voice & text chat",
    .has_min = true, .min_val = 0.0
    ), ca_rankrestrictions_min_level
  )

  bind_pcvar_string(create_cvar("ca_rankrestrictions_immunity_flag", "a",
    .description = "User immunity flag"
    ),
    ca_rankrestrictions_immunity_flag, charsmax(ca_rankrestrictions_immunity_flag)
  )
}

public CA_Client_Say(player) {
  if(!CanCommunicate(player)) {
    return CA_SUPERCEDE
  }

  return CA_CONTINUE
}

public CA_Client_SayTeam(player) {
  if(!CanCommunicate(player)) {
    return CA_SUPERCEDE
  }

  return CA_CONTINUE
}

public CA_Client_Voice(const listener, const sender) {
  // need chat notification?
  return CanCommunicate(sender, false) ? CA_CONTINUE : CA_SUPERCEDE
}

static bool: CanCommunicate(const player, const bool: print = true) {
  if(ca_rankrestrictions_type <= 0)
    return true

  // check is gagged?
  if(get_user_flags(player) & read_flags(ca_rankrestrictions_immunity_flag))
    return true

  if(ca_rankrestrictions_type == 1 && GetUserLevel(player) < ca_rankrestrictions_min_level) {
    if(print) {
      client_print_color(player, print_team_red, "%L",
        player, "RankRestrictions_Warning_MinLevel", ca_rankrestrictions_min_level
      )
    }

    return false
  }

  if(ca_rankrestrictions_type == 2 && GetUserFragsFromStats(player) < ca_rankrestrictions_min_kills) {
    if(print) {
      client_print_color(player, print_team_red, "%L",
        player, "RankRestrictions_Warning_MinKills", ca_rankrestrictions_min_kills
      )
    }

    return false
  }

  return true
}

static GetUserLevel(const player) {
  switch(ca_rankrestrictions_type_level) {
    case 0: return aes_get_player_level(player)
    case 1: return ar_get_user_level(player)
    case 2: return crxranks_get_user_level(player)
  }

  return 0
}

static GetUserFragsFromStats(const player) {
  enum { stats_Frags/* , stats_Deaths, stats_Rounds = 16 */ }

  new stats[22]
  csstats_get_user_stats(player, stats)

  return stats[stats_Frags]
}
