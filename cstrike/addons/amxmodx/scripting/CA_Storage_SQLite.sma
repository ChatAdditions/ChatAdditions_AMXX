#include <amxmodx>
#include <sqlx>

#include <ChatAdditions>
#include <CA_StorageAPI_endpoint>

#pragma ctrlchar '\'
#pragma dynamic 131072

new const SQL_DBNAME[] = "ChatAdditions"
new const SQL_TBL_GAGS[] = "players_gags"

const QUERY_LENGTH = 4096
const MAX_REASON_LENGTH = 256;

new Handle: g_tuple = Empty_Handle

new const LOG_DIR_NAME[] = "CA_Storage";
new g_sLogsFile[PLATFORM_MAX_PATH];
new ca_log_type, LogLevel_s: ca_log_level = _Debug

public stock const PluginName[] = "ChatAdditions: SQLite storage"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "https://Dev-CS.ru/"
public stock const PluginDescription[] = "SQLite storage provider for ChatAdditions"

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)

  bind_pcvar_num(get_cvar_pointer("ca_log_type"), ca_log_type);
  hook_cvar_change(get_cvar_pointer("ca_log_level"), "Hook_CVar_LogLevel");
  GetLogsFilePath(g_sLogsFile, .sDir = LOG_DIR_NAME);

  SQL_SetAffinity("sqlite")
  g_tuple = SQL_MakeDbTuple("", "", "", SQL_DBNAME)

  Storage_Create()
}
public plugin_end() {
  SQL_FreeHandle(g_tuple)
}
public plugin_natives() {
  RegisterNatives();
}
public plugin_cfg() {
  RegisterForwards();
}
public Hook_CVar_LogLevel(pcvar, const old_value[], const new_value[]) {
	ca_log_level = ParseLogLevel(new_value);
}

Storage_Create() {
  new query[QUERY_LENGTH]

  formatex(query, charsmax(query), "CREATE TABLE IF NOT EXISTS %s ", SQL_TBL_GAGS); {
    strcat(query, "( id INTEGER PRIMARY KEY AUTOINCREMENT,", charsmax(query))
    strcat(query, "name VARCHAR NOT NULL,", charsmax(query))
    strcat(query, "authid VARCHAR NOT NULL,", charsmax(query))
    strcat(query, "ip VARCHAR NOT NULL,", charsmax(query))
    strcat(query, "reason VARCHAR NOT NULL,", charsmax(query))
    strcat(query, "admin_name VARCHAR NOT NULL,", charsmax(query))
    strcat(query, "admin_authid VARCHAR NOT NULL,", charsmax(query))
    strcat(query, "admin_ip VARCHAR NOT NULL,", charsmax(query))
    strcat(query, "created_at DATETIME NOT NULL,", charsmax(query))
    strcat(query, "expire_at DATETIME NOT NULL,", charsmax(query))
    strcat(query, "flags INTEGER NOT NULL", charsmax(query))
    strcat(query, ");", charsmax(query))
  }
  strcat(query, fmt("CREATE UNIQUE INDEX IF NOT EXISTS authid_unique_idx ON %s (authid)", SQL_TBL_GAGS), charsmax(query))

  SQL_ThreadQuery(g_tuple, "handle_StorageCreated", query)
}
public handle_StorageCreated(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
  if(IsSQLQueryFailed(failstate, query, error, errnum)) {
    return
  }

  CA_Log(_Debug, "Table '%s' created! (queryTime: '%.3f' sec)", SQL_TBL_GAGS, queuetime)

  ExecuteForward(g_fwd_StorageInitialized, g_ret)
}

Storage_Save(const name[], const authID[], const IP[],
  const reason[], const adminName[], const adminAuthID[],
  const adminIP[], const expireAt, const flags) {

  new name_safe[MAX_NAME_LENGTH * 2];
  SQL_QuoteString(Empty_Handle, name_safe, charsmax(name_safe), name);

  new reason_safe[MAX_REASON_LENGTH * 2];
  SQL_QuoteString(Empty_Handle, reason_safe, charsmax(reason_safe), reason);

  new adminName_safe[MAX_NAME_LENGTH * 2];
  SQL_QuoteString(Empty_Handle, adminName_safe, charsmax(adminName_safe), adminName);

  new query[QUERY_LENGTH]
  formatex(query, charsmax(query), "INSERT OR REPLACE INTO %s ", SQL_TBL_GAGS); {
    strcat(query, "( name,authid,ip,", charsmax(query))
    strcat(query, "reason,admin_name,admin_authid,", charsmax(query))
    strcat(query, "admin_ip,created_at,expire_at,flags )", charsmax(query))

    strcat(query, fmt("VALUES ( '%s',", name_safe), charsmax(query))
    strcat(query, fmt("'%s',", authID), charsmax(query))
    strcat(query, fmt("'%s',", IP), charsmax(query))
    strcat(query, fmt("'%s',", reason_safe), charsmax(query))
    strcat(query, fmt("'%s',", adminName_safe), charsmax(query))
    strcat(query, fmt("'%s',", adminAuthID), charsmax(query))
    strcat(query, fmt("'%s',", adminIP), charsmax(query))
    strcat(query, fmt("DateTime('now'),"), charsmax(query))
    strcat(query, fmt("DateTime(%i, 'unixepoch'),", expireAt), charsmax(query))
    strcat(query, fmt("%i ); ", flags), charsmax(query))
  }

  strcat(query, "SELECT \
    name,authid,ip,reason,\
    admin_name,admin_authid,admin_ip,\
    strftime('%s',created_at),strftime('%s',expire_at),flags", charsmax(query))
  strcat(query, fmt(" FROM %s", SQL_TBL_GAGS), charsmax(query))
  strcat(query, fmt(" WHERE authid='%s'", authID), charsmax(query))

  SQL_ThreadQuery(g_tuple, "handle_Saved", query)
}
public handle_Saved(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
  if(IsSQLQueryFailed(failstate, query, error, errnum)) {
    return
  }

  enum { res_name, res_authid, res_ip, res_reason,
    res_admin_name, res_admin_authid, res_admin_ip,
    res_created_at, res_expire_at, res_flags
  }

  new name[MAX_NAME_LENGTH]; SQL_ReadResult(query, res_name, name, charsmax(name))
  new authID[MAX_AUTHID_LENGTH]; SQL_ReadResult(query, res_authid, authID, charsmax(authID))
  new IP[MAX_IP_LENGTH]; SQL_ReadResult(query, res_ip, IP, charsmax(IP))
  new reason[MAX_REASON_LENGTH]; SQL_ReadResult(query, res_reason, reason, charsmax(reason))

  new adminName[MAX_NAME_LENGTH]; SQL_ReadResult(query, res_admin_name, adminName, charsmax(adminName))
  new adminAuthID[MAX_AUTHID_LENGTH]; SQL_ReadResult(query, res_admin_authid, adminAuthID, charsmax(adminAuthID))
  new adminIP[MAX_IP_LENGTH]; SQL_ReadResult(query, res_admin_ip, adminIP, charsmax(adminIP))

  new createdAt = SQL_ReadResult(query, res_created_at)
  new expireAt = SQL_ReadResult(query, res_expire_at)
  new flags = SQL_ReadResult(query, res_flags)

  CA_Log(_Debug, "Player gag saved {'%s', '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i} (queryTime: '%.3f' sec)", \
    name, authID, IP, reason, adminName, adminAuthID, adminIP, createdAt, expireAt, flags,\
    queuetime \
  )

  ExecuteForward(g_fwd_StorageSaved, g_ret,
    name, authID, IP, reason,
    adminName, adminAuthID, adminIP,
    createdAt, expireAt, flags
  )
}

Storage_Load(const authID[]) {
  new query[QUERY_LENGTH]
  formatex(query, charsmax(query), "SELECT name, authid, ip, reason,\
    admin_name, admin_authid, admin_ip, \
    strftime('%%s', created_at), strftime('%%s', expire_at), flags FROM %s", SQL_TBL_GAGS); {
    strcat(query, fmt(" WHERE (authid = '%s')", authID), charsmax(query))
    strcat(query, " AND ( expire_at = DateTime(9999999999, 'unixepoch') OR (expire_at > DateTime('now')) ) LIMIT 1", charsmax(query))
  }

  SQL_ThreadQuery(g_tuple, "handle_Loaded", query)
}
public handle_Loaded(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
  if(IsSQLQueryFailed(failstate, query, error, errnum)) {
    return
  }

  enum { res_name, res_authid, res_ip, res_reason,
    res_admin_name, res_admin_authid, res_admin_ip,
    res_created_at, res_expire_at, res_flags
  }

  new bool: found = (SQL_NumResults(query) != 0)
  if(!found) {
    return;
  }

  new name[MAX_NAME_LENGTH]; SQL_ReadResult(query, res_name, name, charsmax(name))
  new authID[MAX_AUTHID_LENGTH]; SQL_ReadResult(query, res_authid, authID, charsmax(authID))
  new IP[MAX_IP_LENGTH]; SQL_ReadResult(query, res_ip, IP, charsmax(IP))
  new reason[MAX_REASON_LENGTH]; SQL_ReadResult(query, res_reason, reason, charsmax(reason))

  new adminName[MAX_NAME_LENGTH]; SQL_ReadResult(query, res_admin_name, adminName, charsmax(adminName))
  new adminAuthID[MAX_AUTHID_LENGTH]; SQL_ReadResult(query, res_admin_authid, adminAuthID, charsmax(adminAuthID))
  new adminIP[MAX_IP_LENGTH]; SQL_ReadResult(query, res_admin_ip, adminIP, charsmax(adminIP))

  new createdAt = SQL_ReadResult(query, res_created_at)
  new expireAt = SQL_ReadResult(query, res_expire_at)
  new flags = SQL_ReadResult(query, res_flags)

  CA_Log(_Debug, "Player gag loaded {'%s', '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i} (queryTime: '%.3f' sec)", \
    name, authID, IP, reason, adminName, adminAuthID, adminIP, createdAt, expireAt, flags,\
    queuetime \
  )

  ExecuteForward(g_fwd_StorageLoaded, g_ret,
    name, authID, IP, reason,
    adminName, adminAuthID, adminIP,
    createdAt, expireAt, flags
  )
}

Storage_Remove(const authID[]) {
  new query[QUERY_LENGTH]
  formatex(query, charsmax(query), "DELETE FROM %s ", SQL_TBL_GAGS); {
    strcat(query, fmt("WHERE (authid = '%s')", authID), charsmax(query))
  }

  SQL_ThreadQuery(g_tuple, "handle_Removed", query)
}
public handle_Removed(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
  if(IsSQLQueryFailed(failstate, query, error, errnum)) {
    return
  }

  CA_Log(_Debug, "Player gag removed { } (queryTime: '%.3f' sec)", \
    queuetime \
  )

  ExecuteForward(g_fwd_StorageRemoved, g_ret)
}
