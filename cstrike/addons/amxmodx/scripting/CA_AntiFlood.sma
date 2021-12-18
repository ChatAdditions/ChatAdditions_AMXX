#include <amxmodx>
#include <ChatAdditions>

#define GetCvarDesc(%0) fmt("%L", LANG_SERVER, %0)

new g_szOldMessage[MAX_PLAYERS + 1][CA_MAX_MESSAGE_SIZE];

enum _:Cvars
{
    Float:ca_anti_flood_time,
    ca_equal_messages
};

new g_pCvarValue[Cvars];

public stock const PluginName[] = "CA: Anti Flood";
public stock const PluginVersion[] = CA_VERSION;
public stock const PluginAuthor[] = "Nordic Warrior";
public stock const PluginURL[] = "https://github.com/ChatAdditions";
public stock const PluginDescription[] = "Antiflood for chat";

public plugin_init()
{
    register_plugin(PluginName, PluginVersion, PluginAuthor);

    register_dictionary("CA_AntiFlood.txt");

    CreateCvars();
    AutoExecConfig(true, "CA_AntiFlood", "ChatAdditions");
}

public plugin_cfg()
{
    if(find_plugin_byfile("antiflood.amxx") != INVALID_PLUGIN_ID)
    {
        log_amx("Default plugin <antiflood.amxx> was found. Stopped.");
        pause("acd", "antiflood.amxx");
    }
}

public CA_Client_Say(id, const szMessage[])
{
    return CheckMessage(id, szMessage);
}

public CA_Client_SayTeam(id, const szMessage[])
{
    return CheckMessage(id, szMessage);
}

CheckMessage(id, const szMessage[])
{
    if(szMessage[0] == '/')
    {
        return CA_CONTINUE;
    }

    static Float:flNextMessage[MAX_PLAYERS + 1];
    static iEqualMessage[MAX_PLAYERS + 1];

    new Float:flNextSay = get_gametime();

    if(flNextMessage[id] > flNextSay)
    {
        client_print_color(id, print_team_red, "%L %L", id, "CA_ANTIFLOOD_CHAT_PREFIX", id, "CA_ANTIFLOOD_CHAT_STOP_FLOODING");
        flNextMessage[id] = flNextSay + g_pCvarValue[ca_anti_flood_time];

        return CA_SUPERCEDE;
    }

    if(strcmp(szMessage, g_szOldMessage[id], true) == 0)
    {
        if(++iEqualMessage[id] >= g_pCvarValue[ca_equal_messages])
        {
            client_print_color(id, print_team_red, "%L %L", id, "CA_ANTIFLOOD_CHAT_PREFIX", id, "CA_ANTIFLOOD_CHAT_EQUAL_MESSAGE");

            return CA_SUPERCEDE;
        }        
    }
    else
    {
        iEqualMessage[id] = 0;
    }

    flNextMessage[id] = flNextSay + g_pCvarValue[ca_anti_flood_time];
    copy(g_szOldMessage[id], charsmax(g_szOldMessage[]), szMessage);

    return CA_CONTINUE;
}

public client_disconnected(id)
{
    g_szOldMessage[id][0] = EOS;
}

CreateCvars()
{
    bind_pcvar_float(
        create_cvar(
            .name = "ca_anti_flood_time", 
            .string = "0.75",
            .description = GetCvarDesc("CA_ANTIFLOOD_CVAR_TIME"),
            .has_min = true,
            .min_val = 0.0
        ),

        g_pCvarValue[ca_anti_flood_time]
    );

    bind_pcvar_num(
        create_cvar(
            .name = "ca_equal_messages",
            .string = "2",
            .description = GetCvarDesc("CA_ANTIFLOOD_CVAR_EQUAL_MESSAGES"),
            .has_min = true,
            .min_val = 0.0
        ),

        g_pCvarValue[ca_equal_messages]
    );
}