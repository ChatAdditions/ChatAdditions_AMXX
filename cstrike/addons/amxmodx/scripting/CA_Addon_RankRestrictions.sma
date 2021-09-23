#include <amxmodx>
#include <ChatAdditions>

#pragma ctrlchar '\'

native aes_get_player_level(const player)
native ar_get_user_level(const player, rankName[] = "", len = 0)
native crxranks_get_user_level(const player)

static ca_rankrestrictions_min_level,
  ca_rankrestrictions_type_level,
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

static Register_CVars() {
  bind_pcvar_num(create_cvar("ca_rankrestrictions_min_level", "2",
    .description = "Min Level to access voice & text chat",
    .has_min = true, .min_val = 0.0
    ), ca_rankrestrictions_min_level
  )

  bind_pcvar_num(create_cvar("ca_rankrestrictions_type_level", "2",
    .description = "Level System Types \n\
      0 - Advanced Experience System \n\
      1 - Army Ranks Ultimate \n\
      2 - OciXCrom's Rank System",
    .has_min = true, .min_val = 0.0,
    .has_max = true, .max_val = 2.0
    ), ca_rankrestrictions_type_level
  )

  bind_pcvar_string(create_cvar("ca_rankrestrictions_immunity_flag", "a",
    .description = "User immunity flag"
    ),
    ca_rankrestrictions_immunity_flag, charsmax(ca_rankrestrictions_immunity_flag)
  )
}

public CA_Client_Say(const player) {
  if(!CanCommunicate(player)) {
    client_print_color(player, print_team_default, "%L",
      player, "RankRestrictions_Warning_MinLevel", ca_rankrestrictions_min_level
    )
    return CA_SUPERCEDE
  }

  return CA_CONTINUE
}

public CA_Client_SayTeam(const player) {
  if(!CanCommunicate(player)) {
    client_print_color(player, print_team_default, "%L",
      player, "RankRestrictions_Warning_MinLevel", ca_rankrestrictions_min_level
    )
    return CA_SUPERCEDE
  }

  return CA_CONTINUE
}

public CA_Client_Voice(const listener, const sender) {
  // need chat notification?
  return CanCommunicate(sender) ? CA_CONTINUE : CA_SUPERCEDE
}

static bool: CanCommunicate(const player) {
  // check is gagged?
  if(get_user_flags(player) & read_flags(ca_rankrestrictions_immunity_flag))
    return true

  return (getUserLevel(player) >= ca_rankrestrictions_min_level)
}

static getUserLevel(const player) {
  switch(ca_rankrestrictions_type_level) {
    case 0: return aes_get_player_level(player)
    case 1: return ar_get_user_level(player)
    case 2: return crxranks_get_user_level(player)
  }

  return 0
}
