#include <amxmodx>
#tryinclude <reapi>

#include <ChatAdditions>

#pragma ctrlchar '\'
#pragma tabsize 4

// Natives
native aes_get_player_level(const player);
native ar_get_user_level(const player, rankName[] = "", len = 0);
native crxranks_get_user_level(const player);
native cmsranks_get_user_level(player, level[] = "", len = 0);
native csstats_get_user_stats(const player, const stats[22]);
native Float:cmsstats_get_user_skill(player, skillname[] = "", namelen = 0, &skill_level = 0);
native get_user_skill(player, &Float: skill);
native get_user_stats(player, stats[STATSX_MAX_STATS], bodyhits[MAX_BODYHITS]);
//


enum any: eChatType {
    voice_chat,
    text_chat
}

enum any: eRankRestrictionsType {
    rr_type_none,
    rr_type_level,
    rr_type_frags
}

new ca_rankrestrictions_type,
    ca_rankrestrictions_type_kills,
    ca_rankrestrictions_min_kills_voice_chat,
    ca_rankrestrictions_min_kills_text_chat,
    ca_rankrestrictions_type_level,
    ca_rankrestrictions_min_level_voice_chat,
    ca_rankrestrictions_min_level_text_chat,
    ca_rankrestrictions_immunity_flag[16],
    ca_rankrestrictions_steam_immunity

public stock const PluginName[] = "CA Addon: Rank restrictions"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "steelzzz"
public stock const PluginURL[] = "https://github.com/ChatAdditions/"
public stock const PluginDescription[] = "Restrict chat until you reach the rank of a statistic"

public plugin_init() {
    register_plugin(PluginName, PluginVersion, PluginAuthor)
    register_dictionary("CA_Addon_RankRestrictions.txt")

    Create_CVars()

    AutoExecConfig(true, "CA_Addon_RankRestrictions", "ChatAdditions")
}

public plugin_natives() {
    set_native_filter("native_filter")
}

public native_filter(const name[], index, trap) {
    if (strcmp(name, "aes_get_player_level")) {
        return PLUGIN_HANDLED
    }

    if (strcmp(name, "ar_get_user_level")) {
        return PLUGIN_HANDLED
    }

    if (strcmp(name, "crxranks_get_user_level")) {
        return PLUGIN_HANDLED
    }

    if (strcmp(name, "csstats_get_user_stats")) {
        return PLUGIN_HANDLED
    }

    if (strcmp(name, "cmsranks_get_user_level")) {
        return PLUGIN_HANDLED
    }

    if (strcmp(name, "cmsstats_get_user_skill")) {
        return PLUGIN_HANDLED
    }

    if (strcmp(name, "get_user_stats")) {
        return PLUGIN_HANDLED
    }

    return PLUGIN_CONTINUE
}

Create_CVars() {
    bind_pcvar_num(create_cvar("ca_rankrestrictions_type", "1", 
        .description = "Restrictions Type\n\
            0 - Disable restrictions\n\
            1 - Level restrictions\n\
            2 - Kills count restrictions",
        .has_min = true, .min_val = 0.0,
        .has_max = true, .max_val = 2.0
        ), ca_rankrestrictions_type
    )

    bind_pcvar_num(create_cvar("ca_rankrestrictions_type_kills", "1",
        .description = "Kill System Types\n\
        0 - CSStats MySQL\n\
        1 - CSX Module",
        .has_min = true, .min_val = 0.0,
        .has_max = true, .max_val = 1.0
        ), ca_rankrestrictions_type_kills
    )

    bind_pcvar_num(create_cvar("ca_rankrestrictions_min_kills_voice_chat", "10",
        .description = "Min kills count to access VOICE chat",
        .has_min = true, .min_val = 0.0
        ), ca_rankrestrictions_min_kills_voice_chat
    )

    bind_pcvar_num(create_cvar("ca_rankrestrictions_min_kills_text_chat", "10",
        .description = "Min kills count to access TEXT chat",
        .has_min = true, .min_val = 0.0
        ), ca_rankrestrictions_min_kills_text_chat
    )

    bind_pcvar_num(create_cvar("ca_rankrestrictions_type_level", "1",
        .description = "Level System Types\n\
            0 - Advanced Experience System\n\
            1 - Army Ranks Ultimate\n\
            2 - OciXCrom's Rank System\n\
            3 - CMSStats Ranks\n\
            4 - CMSStats MySQL\n\
            5 - CSstatsX SQL\n\
            6 - CSX Module",
        .has_min = true, .min_val = 0.0,
        .has_max = true, .max_val = 6.0
        ), ca_rankrestrictions_type_level
    )

    bind_pcvar_num(create_cvar("ca_rankrestrictions_min_level_voice_chat", "2",
        .description = "Min Level to access VOICE chat",
        .has_min = true, .min_val = 0.0
        ), ca_rankrestrictions_min_level_voice_chat
    )

    bind_pcvar_num(create_cvar("ca_rankrestrictions_min_level_text_chat", "2",
        .description = "Min Level to access TEXT chat",
        .has_min = true, .min_val = 0.0
        ), ca_rankrestrictions_min_level_text_chat
    )

    bind_pcvar_string(create_cvar("ca_rankrestrictions_immunity_flag", "a",
        .description = "User immunity flag"
        ),
        ca_rankrestrictions_immunity_flag, charsmax(ca_rankrestrictions_immunity_flag)
    )

    bind_pcvar_num(create_cvar("ca_rankrestrictions_steam_immunity", "0",
        .description = "Enable immunity for steam players",
        .has_min = true, .min_val = 0.0,
        .has_max = true, .max_val = 1.0
        ), ca_rankrestrictions_steam_immunity
    )
}

public CA_Client_Say(player, const bool: isTeamMessage, const message[]) {
    if (!CanCommunicate(player, true, text_chat)) {
        return CA_SUPERCEDE
    }

    return CA_CONTINUE
}

public CA_Client_Voice(const listener, const sender) {
    if (!CanCommunicate(sender, false, voice_chat)) {
        // need chat notification?
        return CA_SUPERCEDE
    }
    
    return CA_CONTINUE
}

bool: CanCommunicate(const player, const bool: print, chatType) {
    if (ca_rankrestrictions_type <= rr_type_none) {
        return true
    }

    // check is gagged?
    if (get_user_flags(player) & read_flags(ca_rankrestrictions_immunity_flag)) {
        return true
    }

    if (ca_rankrestrictions_steam_immunity && _is_user_steam(player)) {
        return true
    }

    switch (chatType) {
        case voice_chat: {
            if (ca_rankrestrictions_type == rr_type_level && GetUserLevel(player) < ca_rankrestrictions_min_level_voice_chat) {
                if (print) {
                    client_print_color(player, print_team_red, "%L",
                        player, "RankRestrictions_Warning_MinLevel", ca_rankrestrictions_min_level_voice_chat
                    )
                }

                return false
            }

            if (ca_rankrestrictions_type == rr_type_frags && GetUserFragsFromStats(player) < ca_rankrestrictions_min_kills_voice_chat) {
                if (print) {
                    client_print_color(player, print_team_red, "%L",
                        player, "RankRestrictions_Warning_MinKills", ca_rankrestrictions_min_kills_voice_chat
                    )
                }

                return false
            }
        }

        case text_chat: {
            if (ca_rankrestrictions_type == rr_type_level && GetUserLevel(player) < ca_rankrestrictions_min_level_text_chat) {
                if (print) {
                    client_print_color(player, print_team_red, "%L",
                        player, "RankRestrictions_Warning_MinLevel", ca_rankrestrictions_min_level_text_chat
                    )
                }

                return false
            }

            if (ca_rankrestrictions_type == rr_type_frags && GetUserFragsFromStats(player) < ca_rankrestrictions_min_kills_text_chat) {
                if (print) {
                    client_print_color(player, print_team_red, "%L",
                        player, "RankRestrictions_Warning_MinKills", ca_rankrestrictions_min_kills_text_chat
                    )
                }

                return false
            }
        }
    }

    return true
}

GetUserLevel(const player) {
    switch (ca_rankrestrictions_type_level) {
        case 0: return aes_get_player_level(player)
        case 1: return ar_get_user_level(player)
        case 2: return crxranks_get_user_level(player)
        case 3: return cmsranks_get_user_level(player)
        case 4: {
            new iSkill
            cmsstats_get_user_skill(player, .skill_level = iSkill)
            return iSkill
        }
        case 5: {
            new Float:iSkill
            get_user_skill(player, iSkill)
            return floatround(iSkill)
        }
        case 6: {
            new stats[STATSX_MAX_STATS], hits[MAX_BODYHITS]
            get_user_stats(player, stats, hits)
            return stats[STATSX_RANK]
        }
    }

    return 0
}

GetUserFragsFromStats(const player) {
    enum { stats_Frags/* , stats_Deaths, stats_Rounds = 16 */ }

    switch (ca_rankrestrictions_type_kills) {
        case 0: {
            new stats[22]
            csstats_get_user_stats(player, stats)
            return stats[stats_Frags]
        }
        case 1: {
            new stats[STATSX_MAX_STATS], hits[MAX_BODYHITS]
            get_user_stats(player, stats, hits)
            return stats[STATSX_KILLS]
        }
    }

    return 0
}

static stock bool: _is_user_steam(const player) {
    #if (defined _reapi_reunion_included)
    if (has_reunion())
        return (REU_GetAuthtype(player) == CA_TYPE_STEAM)
    #endif

    static dp_r_id_provider
    if (dp_r_id_provider || (dp_r_id_provider = get_cvar_pointer("dp_r_id_provider"))) {
        server_cmd("dp_clientinfo %i", player)
        server_exec()

        #define DP_AUTH_STEAM 2
        if (get_pcvar_num(dp_r_id_provider) == DP_AUTH_STEAM)
            return true

        return false
    }

    return false
}
