#include <amxmodx>
#include <reapi>

#include <ChatAdditions>

#pragma ctrlchar '\'
#pragma tabsize 2


enum logType_s {
	_Default,
	_LogToDir
}

new logType_s: ca_log_type,
  logLevel_s: ca_log_level = logLevel_Debug,
  g_logsFile[PLATFORM_MAX_PATH]

new const LOG_FOLDER[] = "ChatAdditions"

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
  create_cvar("ChatAdditions_version", PluginVersion, (FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED))

  GetLogsFilePath(g_logsFile, .dir = LOG_FOLDER)

  bind_pcvar_num(create_cvar("ca_log_type", "1",
      .description = fmt("Log file type\n 0 = log to common amxx log file (logs/L*.log)\n 1 = log to plugins folder (logs/%s/L*.log)", LOG_FOLDER),
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = float(_LogToDir)
    ),
    ca_log_type
  )
  bind_pcvar_num(create_cvar("ca_log_level", "3",
      .description = "Log level\n 0 = disable logs\n 1 = add info messages logs\n 2 = add warinigs info\n 3 = add debug messages",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = float(logLevel_Debug)
    ),
    ca_log_level
  )

  register_clcmd("say", "ClCmd_Say")
  register_clcmd("say_team", "ClCmd_SayTeam")
  RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "CSGameRules_CanPlayerHearPlayer", .post = false)

  g_fwdClientSay = CreateMultiForward("CA_Client_Say", ET_STOP, FP_CELL)
  g_fwdClientSayTeam = CreateMultiForward("CA_Client_SayTeam", ET_STOP, FP_CELL)
  g_fwdClientVoice = CreateMultiForward("CA_Client_Voice", ET_STOP, FP_CELL, FP_CELL)

  AutoExecConfig(.name = "ChatAdditions")

  CA_Log(logLevel_Debug, "Chat Additions: Core initialized!")
}

public plugin_end() {
  DestroyForward(g_fwdClientSay)
  DestroyForward(g_fwdClientSayTeam)
  DestroyForward(g_fwdClientVoice)
}

public plugin_natives() {
  register_library("ChatAdditions_Core")

  register_native("CA_Log", "native_CA_Log")
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

public bool: native_CA_Log(const plugin_id, const argc) {
  enum { arg_level = 1, arg_msg, arg_format }

  new logLevel_s: level = logLevel_s: get_param(arg_level)
  if(ca_log_level < level) {
    return false
  }

  new msg[2048]; vdformat(msg, charsmax(msg), arg_msg, arg_format);

  switch(ca_log_type) {
    case _LogToDir: log_to_file(g_logsFile, msg)
    case _Default: log_amx(msg)
  }

  return true
}


static GetLogsFilePath(buffer[], len = PLATFORM_MAX_PATH, const dir[] = "ChatAdditions") {
	get_localinfo("amxx_logs", buffer, len)
	strcat(buffer, fmt("/%s", dir), len)

	if(!dir_exists(buffer) && mkdir(buffer) == -1) {
		set_fail_state("[Core API] Can't create folder! (%s)", buffer)
	}

	new year, month, day
	date(year, month, day)

	strcat(buffer, fmt("/L%i%02i%02i.log", year, month, day), len)
}
