#include <amxmodx>
#include <amxmisc>

#include <ChatAdditions>
#include <CA_GAG_API>

#pragma tabsize 4

new Float: g_userNextRequestTime[MAX_PLAYERS + 1]

new ca_requestungag_cmd[32],
    Float: ca_requestungag_delay,
    ca_gag_access_flags_high[32],
    ca_gag_access_flags[32]

public stock const PluginName[] = "CA Addon: Request UnGAG"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "steelzzz"
public stock const PluginURL[] = "https://github.com/ChatAdditions/"
public stock const PluginDescription[] = "A player can apologize to the administration"

public plugin_init() {
    register_plugin(PluginName, PluginVersion, PluginAuthor)
    register_dictionary("CA_Addon_RequestUngag.txt")

    Create_CVars()

    AutoExecConfig(true, "CA_Addon_RequestUnGag", "ChatAdditions")
}

public Create_CVars() {
    bind_pcvar_string(create_cvar("ca_requestungag_cmd", "/sorry",
            .description = "Request ungag command"),
        ca_requestungag_cmd, charsmax(ca_requestungag_cmd)
    )

    bind_pcvar_float(create_cvar("ca_requestungag_delay", "40.0",
            .description = "delay time request ungag",
            .has_min = true, .min_val = 1.0),
        ca_requestungag_delay
    )

    bind_pcvar_string(get_cvar_pointer("ca_gag_access_flags_high"),
        ca_gag_access_flags_high, charsmax(ca_gag_access_flags_high)
    )

    bind_pcvar_string(get_cvar_pointer("ca_gag_access_flags"),
        ca_gag_access_flags, charsmax(ca_gag_access_flags)
    )
}

// TODO: Create `_PRE` hook forward instead this.
public CA_Client_Say(player, const bool: isTeamMessage, const message[]) {
    if (strcmp(message, ca_requestungag_cmd) != 0)
        return CA_CONTINUE

    if (!ca_has_user_gag(player)) {
        client_print_color(player, print_team_default, "%L", player, "RequestUnGag_NoAccess")

        return CA_SUPERCEDE
    }

    new Float: gametime = get_gametime()
    if (g_userNextRequestTime[player] > gametime) {
        new timeLeft = floatround(g_userNextRequestTime[player] - gametime, floatround_ceil)
        client_print_color(player, print_team_default, "%L", player, "RequestUnGag_TimeOut", timeLeft)

        return CA_SUPERCEDE
    }

    new userID = get_user_userid(player)

    new players[MAX_PLAYERS], count
    get_players_ex(players, count, (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV))

    new accessFlagsHigh       = read_flags(ca_gag_access_flags_high)
    new accessFlags           = read_flags(ca_gag_access_flags)

    for(new i; i < count; i++) {
        new receiver = players[i]

        if (receiver == player)
            continue

        if (!(get_user_flags(receiver) & (accessFlags | accessFlagsHigh)))
            continue

        client_print_color(receiver, print_team_default, "%L",
            receiver, "RequestUnGag_Requested",
            player, userID
        )
    }

    g_userNextRequestTime[player] = gametime + ca_requestungag_delay

    client_print_color(player, print_team_default, "%L", player, "RequestUnGag_YouRequested")
    return CA_SUPERCEDE
}
