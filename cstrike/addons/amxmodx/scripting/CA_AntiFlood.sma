#include <amxmodx>
#include <ChatAdditions>

#pragma ctrlchar '\'
#pragma tabsize 2

#define GetCvarDesc(%0) fmt("%L", LANG_SERVER, %0)

new g_OldMessage[MAX_PLAYERS + 1][CA_MAX_MESSAGE_SIZE]

enum _:Cvars
{
  Float:ca_anti_flood_time,
  ca_equal_messages
}

new g_pCvarValue[Cvars]

public stock const PluginName[] = "CA: Anti Flood"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Nordic Warrior"
public stock const PluginURL[] = "https://github.com/ChatAdditions"
public stock const PluginDescription[] = "Antiflood for chat"

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)

  register_dictionary("CA_AntiFlood.txt")

  CreateCvars()
  AutoExecConfig(true, "CA_AntiFlood", "ChatAdditions")
}

public plugin_cfg() {
  if(find_plugin_byfile("antiflood.amxx") != INVALID_PLUGIN_ID) {
    log_amx("Default plugin <antiflood.amxx> was found. Stopped.")
    pause("acd", "antiflood.amxx")
  }
}

public CA_Client_Say(id, const message[]) {
  return CheckMessage(id, message)
}

public CA_Client_SayTeam(id, const message[]) {
  return CheckMessage(id, message)
}

CheckMessage(id, const message[]) {
  if(message[0] == '/') {
    return CA_CONTINUE;
  }

  static Float:nextMessage[MAX_PLAYERS + 1]
  static equalMessage[MAX_PLAYERS + 1]

  new Float:nextSay = get_gametime()

  if(nextMessage[id] > nextSay) {
    client_print_color(id, print_team_red, "%L %L", id, "CA_ANTIFLOOD_CHAT_PREFIX", id, "CA_ANTIFLOOD_CHAT_STOP_FLOODING")
    nextMessage[id] = nextSay + g_pCvarValue[ca_anti_flood_time]

    return CA_SUPERCEDE
  }

  if(strcmp(message, g_OldMessage[id], true) == 0) {
    if(++equalMessage[id] >= g_pCvarValue[ca_equal_messages]) {
      client_print_color(id, print_team_red, "%L %L", id, "CA_ANTIFLOOD_CHAT_PREFIX", id, "CA_ANTIFLOOD_CHAT_EQUAL_MESSAGE")

      return CA_SUPERCEDE
    }
  }
  else {
    equalMessage[id] = 0
  }

  nextMessage[id] = nextSay + g_pCvarValue[ca_anti_flood_time]
  copy(g_OldMessage[id], charsmax(g_OldMessage[]), message)

  return CA_CONTINUE
}

public client_disconnected(id) {
  g_OldMessage[id][0] = EOS
}

CreateCvars() {
  bind_pcvar_float(
    create_cvar(
      .name = "ca_anti_flood_time",
      .string = "0.75",
      .description = GetCvarDesc("CA_ANTIFLOOD_CVAR_TIME"),
      .has_min = true,
      .min_val = 0.0
    ),

    g_pCvarValue[ca_anti_flood_time]
  )

  bind_pcvar_num(
    create_cvar(
      .name = "ca_equal_messages",
      .string = "2",
      .description = GetCvarDesc("CA_ANTIFLOOD_CVAR_EQUAL_MESSAGES"),
      .has_min = true,
      .min_val = 0.0
    ),

    g_pCvarValue[ca_equal_messages]
  )
}
