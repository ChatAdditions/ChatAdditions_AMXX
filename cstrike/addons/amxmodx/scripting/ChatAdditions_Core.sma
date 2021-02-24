#include <amxmodx>
#include <reapi>

#include <ChatAdditions>

#pragma ctrlchar '\'

new const LOG_DIR_NAME[] = "CA_Core"
new g_sLogsFile[PLATFORM_MAX_PATH]

new ca_log_type,
  LogLevel_s: ca_log_level = _Info

new g_fwdClientSay,
  g_fwdClientSayTeam,
  g_fwdClientVoice,
  g_retVal


public stock const PluginName[] = "ChatAdditions: Core"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "https://Dev-CS.ru/"
public stock const PluginDescription[] = "A core plugin for control different types of chat."

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)

  bind_pcvar_num(create_cvar("ca_log_type", "1"), ca_log_type)
  hook_cvar_change(create_cvar("ca_log_level", "abc"), "Hook_CVar_LogLevel")
  GetLogsFilePath(g_sLogsFile, .sDir = LOG_DIR_NAME)

  register_clcmd("say", "ClCmd_Say")
  register_clcmd("say_team", "ClCmd_SayTeam")
  RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "CSGameRules_CanPlayerHearPlayer", .post = false)

  g_fwdClientSay = CreateMultiForward("CA_Client_Say", ET_STOP, FP_CELL)
  g_fwdClientSayTeam = CreateMultiForward("CA_Client_SayTeam", ET_STOP, FP_CELL)
  g_fwdClientVoice = CreateMultiForward("CA_Client_Voice", ET_STOP, FP_CELL, FP_CELL)
}

public plugin_end() {
  DestroyForward(g_fwdClientSay)
  DestroyForward(g_fwdClientSayTeam)
  DestroyForward(g_fwdClientVoice)
}

public plugin_natives() {
  register_library("ChatAdditions_Core")
}

public plugin_cfg() {
  new sLogLevel[MAX_LOGLEVEL_LEN]
  get_cvar_string("ca_log_level", sLogLevel, charsmax(sLogLevel))
  ca_log_level = ParseLogLevel(sLogLevel)

  CA_Log(_Info, "Chat Additions Core initialized!")
}

public Hook_CVar_LogLevel(pcvar, const old_value[], const new_value[]) {
  ca_log_level = ParseLogLevel(new_value)
}


public ClCmd_Say(const id) {
  ExecuteForward(g_fwdClientSay, g_retVal, id)

	return (g_retVal == CA_SUPERCEDE) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public ClCmd_SayTeam(const id) {
  ExecuteForward(g_fwdClientSayTeam, g_retVal, id)

return (g_retVal == CA_SUPERCEDE) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public CSGameRules_CanPlayerHearPlayer(const listener, const sender) {
  if(listener == sender) {
    return HC_CONTINUE
  }

  ExecuteForward(g_fwdClientVoice, g_retVal, listener, sender)

  if(g_retVal == CA_SUPERCEDE) {
    SetHookChainReturn(ATYPE_BOOL, false)

    return HC_BREAK
  }

  return HC_CONTINUE
}
