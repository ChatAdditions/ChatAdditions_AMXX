#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <grip>
#include <ChatAdditions>

#pragma tabsize 4
#pragma dynamic (8192 + 4096)


enum logType_s {
    _Default,
    _LogToDir,
    _LogToDirSilent
}

new logType_s: ca_log_type,
    logLevel_s: ca_log_level = logLevel_Debug,
    g_logsPath[PLATFORM_MAX_PATH],
    bool: ca_update_notify,
    ca_log_autodelete_time

new const LOG_FOLDER[] = "ChatAdditions"

new g_fwdClientSay,
    g_fwdClientVoice,
    g_fwdClientChangeName,
    g_retVal

// FROM https://github.com/s1lentq/ReGameDLL_CS/blob/master/regamedll/game_shared/voice_gamemgr.cpp

// Set to 1 for each player if the player wants to use voice in this mod.
// (If it's zero, then the server reports that the game rules are saying the player can't hear anyone).
new bool: g_PlayerModEnable[MAX_PLAYERS + 1]

// Tells which players don't want to hear each other.
// These are indexed as clients and each bit represents a client (so player entity is bit + 1).
new g_BanMasks[MAX_PLAYERS + 1]

new const g_versionLink[] = "https://api.github.com/repos/"
    + "ChatAdditions/ChatAdditions_AMXX"
    + "/releases/latest"

public stock const PluginName[]         = "ChatAdditions: Core"
public stock const PluginVersion[]      = CA_VERSION
public stock const PluginAuthor[]       = "Sergey Shorokhov"
public stock const PluginURL[]          = "https://github.com/ChatAdditions/"
public stock const PluginDescription[]  = "A core plugin for control different types of chat."

public plugin_precache() {
    register_plugin(PluginName, PluginVersion, PluginAuthor)

    create_cvar("ChatAdditions_version", PluginVersion, (FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED))

    GetLogsFilePath(g_logsPath, .dir = LOG_FOLDER)

    Create_CVars()

    AutoExecConfig(true, "ChatAdditions_core", "ChatAdditions")
}

public plugin_init() {
    register_clcmd("say",       "ClCmd_Say",      ADMIN_ALL)
    register_clcmd("say_team",  "ClCmd_Say",      ADMIN_ALL)

    register_forward(FM_Voice_SetClientListening, "Voice_SetClientListening_Pre", ._post = false)
    register_forward(FM_ClientUserInfoChanged, "ClientUserInfoChanged_Pre", ._post = false)

    register_clcmd("VModEnable",  "ClCmd_VModEnable",   ADMIN_ALL, .FlagManager = false)
    register_clcmd("vban",        "ClCmd_vban",         ADMIN_ALL, .FlagManager = false)

    g_fwdClientSay          = CreateMultiForward("CA_Client_Say", ET_STOP, FP_CELL, FP_CELL, FP_STRING)
    g_fwdClientVoice        = CreateMultiForward("CA_Client_Voice", ET_STOP, FP_CELL, FP_CELL)
    g_fwdClientChangeName   = CreateMultiForward("CA_Client_ChangeName", ET_STOP, FP_CELL, FP_STRING)

    CheckAutoDelete()

    CA_Log(logLevel_Debug, "Chat Additions: Core initialized!")

    set_task_ex(6.274, "_OnConfigsExecuted")
}

public plugin_end() {
    DestroyForward(g_fwdClientSay)
    DestroyForward(g_fwdClientVoice)
    DestroyForward(g_fwdClientChangeName)
}

public _OnConfigsExecuted() {
    CheckUpdate()
}

CheckAutoDelete() {
    if (ca_log_autodelete_time > 0) {
        if (dir_exists(g_logsPath)) {
            new logFile[PLATFORM_MAX_PATH]
            new dirHandle
            new subDirectory[PLATFORM_MAX_PATH]
            new deleteTime

            deleteTime = get_systime() - (ca_log_autodelete_time * 60 * 60 * 24)

            dirHandle = open_dir(g_logsPath, logFile, charsmax(logFile))

            if (dirHandle) {
                while (next_file(dirHandle, logFile, charsmax(logFile))) {
                    if (logFile[0] == '.')
                        continue

                    if (containi(logFile, ".log") == -1) {
                        formatex(subDirectory, charsmax(subDirectory), "%s/%s", g_logsPath, logFile)

                        ReadFolder(deleteTime, subDirectory)

                        continue
                    }
                }
                close_dir(dirHandle)
            }
        }
    }
}

ReadFolder(deleteTime, logPath[]) {
    new logFile[PLATFORM_MAX_PATH]
    new dirHandle = open_dir(logPath, logFile, charsmax(logFile))
    new fileTime

    if (dirHandle) {
        do 
        {
            if (logFile[0] == '.') {
                continue
            }

            if (containi(logFile, ".log") != -1) {
                fileTime = 0
                format(logFile, charsmax(logFile), "%s/%s", logPath, logFile)

                fileTime = GetFileTime(logFile, FileTime_Created)
                if (fileTime < deleteTime) {
                    unlink(logFile)
                }
            }
        } while (next_file(dirHandle, logFile, charsmax(logFile)))
    }
    close_dir(dirHandle)
}

Create_CVars() {

    bind_pcvar_num(create_cvar("ca_log_type", "1",
            .description = fmt("Log file type^n \
                0 = log to common amxx log file (logs/L*.log)^n \
                1 = log to plugins folder (logs/%s/[plugin name]/L*.log)^n \
                2 = silent log to plugins folder (logs/%s/[plugin name]/L*.log)", LOG_FOLDER, LOG_FOLDER),
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = float(_LogToDirSilent)
        ),
        ca_log_type
    )

    bind_pcvar_num(create_cvar("ca_log_level", "1",
            .description = "Log level^n 0 = disable logs^n 1 = add info messages logs^n 2 = add warinigs info^n 3 = add debug messages",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = float(logLevel_Debug)
        ),
        ca_log_level
    )

    bind_pcvar_num(create_cvar("ca_update_notify", "1",
            .description = "Enable update check?^n 0 = disable update checks",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0
        ),
        ca_update_notify
    )

    bind_pcvar_num(create_cvar("ca_log_autodelete_time", "7",
            .description = "The time in days after which the log files should be deleted.^n \
            0 - The logs won't be deleted.^n \
            > 0 - The logs will be deleted at the time inserted.",
            .has_min = true, .min_val = 0.0
            ), 
        ca_log_autodelete_time
    )
}

public plugin_natives() {
    register_library("ChatAdditions_Core")

    set_module_filter("ModuleFilter")
    set_native_filter("NativeFilter")

    register_native("CA_Log", "native_CA_Log")
    register_native("CA_PlayerHasBlockedPlayer", "native_CA_PlayerHasBlockedPlayer")
}

public ModuleFilter(const library[], LibType: type) {
    return strcmp("grip", library) == 0 ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public NativeFilter(const nativeName[], index, trap) {
    return strncmp(nativeName, "grip_", 5) == 0 ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public ClCmd_Say(const id) {
    static message[CA_MAX_MESSAGE_SIZE]
    read_argv(0, message, charsmax(message))
    new isTeamMessage = (message[3] == '_')
    read_args(message, charsmax(message))
    remove_quotes(message)

    ExecuteForward(g_fwdClientSay, g_retVal, id, isTeamMessage, message)

    return (g_retVal == CA_SUPERCEDE) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public Voice_SetClientListening_Pre(const receiver, const sender, bool: canListen) {
    if (receiver == sender)
        return FMRES_IGNORED

    if (!g_PlayerModEnable[receiver])
        return FMRES_IGNORED

    if (!is_user_connected(receiver) || !is_user_connected(sender))
        return FMRES_IGNORED

    ExecuteForward(g_fwdClientVoice, g_retVal, receiver, sender)
    if (g_retVal != CA_SUPERCEDE)
        return FMRES_IGNORED

    // Block voice
    engfunc(EngFunc_SetClientListening, receiver, sender, (canListen = false))
    return FMRES_SUPERCEDE
}

public ClientUserInfoChanged_Pre(const player, const infobuffer) {
    new currentName[32]
    get_user_name(player, currentName, charsmax(currentName))

    new newName[32]
    engfunc(EngFunc_InfoKeyValue, infobuffer, "name", newName, charsmax(newName))

    if (strcmp(currentName, newName) == 0)
        return

    ExecuteForward(g_fwdClientChangeName, g_retVal, player, newName)
    if (g_retVal != CA_SUPERCEDE)
        return

    // Change back name
    engfunc(EngFunc_SetClientKeyValue, player, infobuffer, "name", currentName)
}

public ClCmd_VModEnable(const id) {
    if (read_argc() < 2) {
        return
    }

    new arg[32]; read_argv(1, arg, charsmax(arg))
    g_PlayerModEnable[id] = bool: (strtol(arg) != 0)
}

public ClCmd_vban(const id) {
    if (read_argc() < 2) {
        return
    }

    new arg[32]; read_argv(1, arg, charsmax(arg))
    g_BanMasks[id] = strtol(arg, .base = 16)
}

public bool: native_CA_Log(const plugin_id, const argc) {
    enum { arg_level = 1, arg_msg, arg_format }

    new logLevel_s: level = logLevel_s: get_param(arg_level)

    if (ca_log_level < level) {
        return false
    }

    new msg[2048]
    vdformat(msg, charsmax(msg), arg_msg, arg_format)

    new logsFile[PLATFORM_MAX_PATH]

    if (ca_log_type > _Default)
    {
        new pluginName[32]
        get_plugin(plugin_id, pluginName, charsmax(pluginName))

        replace(pluginName, charsmax(pluginName), ".amxx", "")

        new logsPath[PLATFORM_MAX_PATH]
        formatex(logsPath, charsmax(logsPath), "%s/%s", g_logsPath, pluginName)

        if (!dir_exists(logsPath)) {
            mkdir(logsPath)
        }

        new year, month, day
        date(year, month, day)

        formatex(logsFile, charsmax(logsFile), "%s/%s__%i-%02i-%02i.log", logsPath, pluginName, year, month, day)
    }

    switch (ca_log_type) {
        case _LogToDir:         log_to_file(logsFile, msg)
        case _Default:          log_amx(msg)
        case _LogToDirSilent:   log_to_file_ex(logsFile, msg)
    }

    return true
}

public bool: native_CA_PlayerHasBlockedPlayer(const plugin_id, const argc) {
    enum { arg_receiver = 1, arg_sender }

    new receiver  = get_param(arg_receiver)
    new sender    = get_param(arg_sender)

    if (CVoiceGameMgr__PlayerHasBlockedPlayer(receiver, sender)) {
        return true
    }

    return false
}

static GetLogsFilePath(buffer[], len = PLATFORM_MAX_PATH, const dir[] = "ChatAdditions") {
    get_localinfo("amxx_logs", buffer, len)
    strcat(buffer, fmt("/%s", dir), len)

    if (!dir_exists(buffer) && mkdir(buffer) == -1) {
        set_fail_state("[Core API] Can't create folder! (%s)", buffer)
    }
}

static bool: CVoiceGameMgr__PlayerHasBlockedPlayer(const receiver, const sender) {
    #define CanPlayerHearPlayer(%0,%1)  ( ~g_BanMasks[%0] & ( 1 << (%1 - 1) ) )

    if (receiver <= 0 || receiver > MaxClients || sender <= 0 || sender > MaxClients) {
        return false
    }

    return bool: !CanPlayerHearPlayer(receiver, sender)
}

static CheckUpdate() {
    if (!ca_update_notify)
        return

    if (strcmp(CA_VERSION, "CA_VERSION") == 0 || contain(CA_VERSION, ".") == -1) // ignore custom builds
        return

    if (is_module_loaded("grip") == -1) {
        CA_Log(logLevel_Warning, "The `GRip` module is not loaded! The new version cannot be verified.")
        CA_Log(logLevel_Warning, "Please install GRip: `https://github.com/In-line/grip` or disable update checks (`ca_update_notify `0`).")

        return
    }

    RequestNewVersion(g_versionLink)
}

static RequestNewVersion(const link[]) {
    new GripRequestOptions: options = grip_create_default_options()
    new GripBody: body = grip_body_from_string("")

    grip_request(
        link,
        body,
        GripRequestTypeGet,
        "@RequestHandler",
        options
    )

    grip_destroy_body(body)
    grip_destroy_options(options)
}

@RequestHandler() {
    new response[8192]
    grip_get_response_body_string(response, charsmax(response))

    if (contain(response, "tag_name") == -1) {
        CA_Log(logLevel_Warning, " > Wrong response! (don't contain `tag_name`). res=`%s`", response)
        return
    }

    static errorBuffer[1024]
    new GripJSONValue: json = grip_json_parse_string(response, errorBuffer, charsmax(errorBuffer))

    if (json == Invalid_GripJSONValue) {
        CA_Log(logLevel_Warning, " > Can't parse response JSON! (error=`%s`)", errorBuffer)
        goto END
    }

    new tag_name[32]
    grip_json_object_get_string(json, "tag_name", tag_name, charsmax(tag_name))

    if (CmpVersions(CA_VERSION, tag_name) >= 0)
        goto END

    new html_url[256]
    grip_json_object_get_string(json, "html_url", html_url, charsmax(html_url))

    NotifyUpdate(tag_name, html_url)

    END:
    grip_destroy_json_value(json)
}

static NotifyUpdate(const newVersion[], const URL[]) {
    CA_Log(logLevel_Info, "^n^t ChatAdditions (%s) has update! New version `%s`.^n\
        Download link: `%s`", CA_VERSION, newVersion, URL
    )
}

static stock CmpVersions(const a[], const b[]) {
    new segmentsA[32][32]
    new segmentsB[32][32]

    new countA = explode_string(
        a[!isdigit(a[0]) ? 1 : 0],
        ".",
        segmentsA, sizeof segmentsA, charsmax(segmentsA[])
    )

    new countB = explode_string(
        b[!isdigit(b[0]) ? 1 : 0],
        ".",
        segmentsB, sizeof segmentsB, charsmax(segmentsB[])
    )

    for(new i, l = min(countA, countB); i < l; i++) {
        new diff = strtol(segmentsA[i]) - strtol(segmentsB[i])
        if (diff)
            return diff
    }

    return countA - countB
}

stock log_to_file_ex(const filePath[], message[]) {
    new file
    new bool:firstTime = true
    new date[32]

    format_time(date, charsmax(date), "%m/%d/%Y - %H:%M:%S")
    static modName[15], amxVersion[15]

    if (!modName[0]) {
        get_modname(modName, charsmax(modName))
    }

    if (!amxVersion[0]) {
        get_amxx_verstring(amxVersion, charsmax(amxVersion))
    }

    if ((file = fopen(filePath, "r"))) {
        firstTime = false
        fclose(file)
    }

    if (!(file = fopen(filePath, "at"))) {
        log_error(AMX_ERR_GENERAL, "Can't open ^"%s^" file for writing.", filePath)
        return PLUGIN_CONTINUE
    }

    if (firstTime) {
        fprintf(file, "L %s: Log file started (file ^"%s^") (game ^"%s^") (amx ^"%s^")^n", date, filePath, modName, amxVersion)
    }

    fprintf(file, "L %s: %s^n", date, message)

    fclose(file)

    return PLUGIN_HANDLED
}
