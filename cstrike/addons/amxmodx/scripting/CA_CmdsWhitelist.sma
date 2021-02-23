#include <amxmodx>
#include <regex>

#include <ChatAdditions>

#pragma ctrlchar '\'
#pragma dynamic 131072


native bool: CA_cmd_in_whitelist(const cmd[]);



new error[512], errcode, ret, err
new Regex: g_regex = REGEX_PATTERN_FAIL

public stock const PluginName[] = "ChatAdditions: Cmds whitelist"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "https://Dev-CS.ru/"
public stock const PluginDescription[] = "Commands whitelist for ChatAdditions"

public plugin_cfg() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)
  RegisterCmds()


  CA_cmd_in_whitelist("/top15")
  CA_cmd_in_whitelist("/rs")
  CA_cmd_in_whitelist("asdadsads /top15")
}
public plugin_end() {
  regex_free(g_regex)
}
public parseSayCmds() {
  new const sayCmds[][] = { "say", "say_team" }

  new flag = -1
  for(new i, num = get_clcmdsnum(flag); i < num; i++) {
    new cmd[128], flags, info[256], bool: info_ml

    new ret = get_clcmd(i, cmd, charsmax(cmd), flags, info, charsmax(info), flag, info_ml)

    for(new j; j < sizeof(sayCmds); j++) {
      new bool: isSayCmd = (strncmp(cmd, sayCmds[j], strlen(sayCmds[j]), true) == 0)
      if(isSayCmd) {
        server_print("Cmd(#%i) ret = %i {'%s', %i, '%s', %i, %i}",
          i,  ret, cmd, flags, info, flag, info_ml
        )

        // sad story :(
      }
    }
  }
}

public RegisterCmds() {
  new CMDS[][] = { "/rs", "/top15" }
  new buffer[6144]

  strcat(buffer, "^(", charsmax(buffer))
  for(new i; i < sizeof CMDS; i++) {
    strcat(buffer, fmt("%s", CMDS[i]), charsmax(buffer))
    
    if(i != sizeof(CMDS) - 1) {
      strcat(buffer, "|", charsmax(buffer))
    }
  }
  strcat(buffer, ")$", charsmax(buffer))
  
  server_print("buffer=%s", buffer)

  g_regex = regex_compile_ex(buffer, PCRE_CASELESS, error, charsmax(error), errcode)
  if(g_regex == REGEX_PATTERN_FAIL) {
    set_fail_state("Regex compile error: '%s' (%i)", error, errcode)
  }
}







public plugin_natives() {
  register_native("CA_cmd_in_whitelist", "native_cmd_in_whitelist")
}
public bool: native_cmd_in_whitelist(const plugin_id, const argc) {
  enum { arg_cmd = 1 }
  new cmd[255]; get_string(arg_cmd, cmd, charsmax(cmd))

  new handle = regex_match_c(cmd, g_regex, ret)
  switch(handle) {
    case REGEX_MATCH_FAIL: {
      log_amx("match error: '%s' (%i)", cmd, err)
    }
    case REGEX_PATTERN_FAIL: {
      log_amx("pattern fail: '%s' (%i)", cmd, err)
    }
    case REGEX_NO_MATCH: {
      // log_amx("no match: '%s' (%i)", cmd, err)
    }
    default: {
      // log_amx("MATCH OK: '%s' (matches: %i)", cmd, err)

      return true
    }
  }

  return false
}