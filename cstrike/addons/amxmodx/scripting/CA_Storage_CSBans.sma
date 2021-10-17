#include <amxmodx>
#include <sqlx>

#include <cellqueue>

#include <ChatAdditions>
#include <CA_StorageAPI_endpoint>
#include <CA_GAG_API>

#pragma ctrlchar '\'
#pragma dynamic 131072
#pragma tabsize 2

#pragma reqlib mysql
#if !defined AMXMODX_NOAUTOLOAD
  #pragma loadlib mysql
#endif

new const SQL_TBL_GAGS[] = "chatadditions_gags"

const QUERY_LENGTH = 4096
const MAX_REASON_LENGTH = 256;
new g_query[QUERY_LENGTH]

new Handle: g_tuple = Empty_Handle
new Queue: g_queueLoad = Invalid_Queue,
  Queue: g_queueSave = Invalid_Queue

new ca_storage_host[64],
  ca_storage_user[128],
  ca_storage_pass[128],
  ca_storage_dbname[128]

public stock const PluginName[] = "ChatAdditions: CSBans storage"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "Sergey Shorokhov"
public stock const PluginURL[] = "github.com/ChatAdditions/ChatsAdditions_AMXX"
public stock const PluginDescription[] = "CSBans (MySQL) storage provider for ChatAdditions"

public plugin_init() {
  register_plugin(PluginName, PluginVersion, PluginAuthor)

  if(!SQL_SetAffinity("mysql")) {
    set_fail_state("Can't user 'MySQL'. Check modules.ini")
  }

  Register_CVars()
  AutoExecConfig(true, "CA_Storage_CSBans", "ChatAdditions")

  g_queueLoad = QueueCreate(MAX_AUTHID_LENGTH)
  g_queueSave = QueueCreate(gagData_s)
}

public OnConfigsExecuted() {
  g_tuple = SQL_MakeDbTuple(ca_storage_host, ca_storage_user, ca_storage_pass, ca_storage_dbname)

  Storage_Create()
}

public plugin_end() {
  if(g_tuple != Empty_Handle) {
    SQL_FreeHandle(g_tuple)
  }

  QueueDestroy(g_queueLoad)
  QueueDestroy(g_queueSave)
}

public plugin_natives() {
  RegisterNatives()
}

public plugin_cfg() {
  RegisterForwards()
}

Register_CVars() {
  bind_pcvar_string(create_cvar("ca_storage_host", "127.0.0.1", FCVAR_PROTECTED,
      .description = "CSBans MySQL database host address"
    ),
    ca_storage_host, charsmax(ca_storage_host)
  )

  bind_pcvar_string(create_cvar("ca_storage_user", "root", FCVAR_PROTECTED,
      .description = "CSBans MySQL database user"
    ),
    ca_storage_user, charsmax(ca_storage_user)
  )

  bind_pcvar_string(create_cvar("ca_storage_pass", "", FCVAR_PROTECTED,
      .description = "CSBans MySQL database host password"
    ),
    ca_storage_pass, charsmax(ca_storage_pass)
  )

  bind_pcvar_string(create_cvar("ca_storage_dbname", "players_gags", FCVAR_PROTECTED,
      .description = "CSBans MySQL database name (not recommended to change)"
    ),
    ca_storage_dbname, charsmax(ca_storage_dbname)
  )
}

Storage_Create() {
  formatex(g_query, charsmax(g_query), "CREATE TABLE IF NOT EXISTS %s ", SQL_TBL_GAGS); {
    strcat(g_query, "( id INTEGER PRIMARY KEY AUTO_INCREMENT,", charsmax(g_query))
    strcat(g_query, "name VARCHAR(32) NOT NULL,", charsmax(g_query))
    strcat(g_query, "authid VARCHAR(64) NOT NULL,", charsmax(g_query))
    strcat(g_query, "ip VARCHAR(22) NOT NULL,", charsmax(g_query))
    strcat(g_query, "reason VARCHAR(256) NOT NULL,", charsmax(g_query))
    strcat(g_query, "admin_name VARCHAR(32) NOT NULL,", charsmax(g_query))
    strcat(g_query, "admin_authid VARCHAR(64) NOT NULL,", charsmax(g_query))
    strcat(g_query, "admin_ip VARCHAR(22) NOT NULL,", charsmax(g_query))
    strcat(g_query, "created_at DATETIME NOT NULL,", charsmax(g_query))
    strcat(g_query, "expire_at DATETIME NOT NULL,", charsmax(g_query))
    strcat(g_query, "flags INTEGER NOT NULL,", charsmax(g_query))
    strcat(g_query, "UNIQUE INDEX authid_unique_idx (authid)", charsmax(g_query))
    strcat(g_query, ") CHARACTER SET utf8 COLLATE utf8_general_ci;", charsmax(g_query))
  }

  SQL_ThreadQuery(g_tuple, "handle_StorageCreated", g_query)
}

public handle_StorageCreated(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
  if(IsSQLQueryFailed(failstate, query, error, errnum)) {
    return
  }

  CA_Log(logLevel_Debug, "Table '%s' created! (queryTime: '%.3f' sec)", SQL_TBL_GAGS, queuetime)

  g_storageInitialized = true
  ExecuteForward(g_fwd_StorageInitialized, g_ret)

  // Load prepared data from storage
  new queueCounter

  for(new i, len = QueueSize(g_queueLoad); i < len; i++) {
    new authID[MAX_AUTHID_LENGTH]; QueuePopString(g_queueLoad, authID, charsmax(authID))
    Storage_Load(authID)

    ++queueCounter
  }

  if(queueCounter) {
    CA_Log(logLevel_Warning, "Loaded %i queue gags from DB (slow DB connection issue)", queueCounter)
    queueCounter = 0
  }

  // Save prepared data to storage
  for(new i, len = QueueSize(g_queueSave); i < len; i++) {
    new gagData[gagData_s]; QueuePopArray(g_queueSave, gagData, sizeof(gagData))

    Storage_Save(gagData[gd_name], gagData[gd_authID], gagData[gd_IP],
      gagData[gd_reason][r_name], gagData[gd_adminName], gagData[gd_adminAuthID],
      gagData[gd_adminIP], gagData[gd_expireAt], gagData[gd_reason][r_flags]
    )

    ++queueCounter
  }

  if(queueCounter) {
    CA_Log(logLevel_Warning, "Saved %i queue gags to DB (slow DB connection issue)", queueCounter)
    queueCounter = 0
  }
}


Storage_Save(const name[], const authID[], const IP[],
  const reason[], const adminName[], const adminAuthID[],
  const adminIP[], const expireAt, const flags) {

  if(!g_storageInitialized) {
    new gagData[gagData_s]; {
      copy(gagData[gd_name], charsmax(gagData[gd_name]), name)
      copy(gagData[gd_authID], charsmax(gagData[gd_authID]), authID)
      copy(gagData[gd_IP], charsmax(gagData[gd_IP]), IP)

      copy(gagData[gd_adminName], charsmax(gagData[gd_adminName]), adminName)
      copy(gagData[gd_adminAuthID], charsmax(gagData[gd_adminAuthID]), adminAuthID)
      copy(gagData[gd_adminIP], charsmax(gagData[gd_adminIP]), adminIP)

      copy(gagData[gd_reason][r_name], charsmax(gagData[r_name]), reason)
      gagData[gd_reason][r_flags] = gag_flags_s: flags

      gagData[gd_expireAt] = expireAt
    }

    QueuePushArray(g_queueSave, gagData)

    return
  }

  new name_safe[MAX_NAME_LENGTH * 2];
  SQL_QuoteString(Empty_Handle, name_safe, charsmax(name_safe), name);

  new reason_safe[MAX_REASON_LENGTH * 2];
  SQL_QuoteString(Empty_Handle, reason_safe, charsmax(reason_safe), reason);

  new adminName_safe[MAX_NAME_LENGTH * 2];
  SQL_QuoteString(Empty_Handle, adminName_safe, charsmax(adminName_safe), adminName);

  // TODO: Optimize this EPIC QUERY
  formatex(g_query, charsmax(g_query), "INSERT INTO %s ", SQL_TBL_GAGS); {
    strcat(g_query, "( name,authid,ip,", charsmax(g_query))
    strcat(g_query, "reason,admin_name,admin_authid,", charsmax(g_query))
    strcat(g_query, "admin_ip,created_at,expire_at,flags )", charsmax(g_query))

    strcat(g_query, fmt(" VALUES ( '%s',", name_safe), charsmax(g_query))
    strcat(g_query, fmt("'%s',", authID), charsmax(g_query))
    strcat(g_query, fmt("'%s',", IP), charsmax(g_query))
    strcat(g_query, fmt("'%s',", reason_safe), charsmax(g_query))
    strcat(g_query, fmt("'%s',", adminName_safe), charsmax(g_query))
    strcat(g_query, fmt("'%s',", adminAuthID), charsmax(g_query))
    strcat(g_query, fmt("'%s',", adminIP), charsmax(g_query))
    strcat(g_query, fmt("NOW(),"), charsmax(g_query))
    strcat(g_query, fmt("FROM_UNIXTIME(%i),", expireAt), charsmax(g_query))
    strcat(g_query, fmt("%i ) ", flags), charsmax(g_query))
    strcat(g_query, "ON DUPLICATE KEY UPDATE ", charsmax(g_query))
    strcat(g_query, fmt("name='%s',", name_safe), charsmax(g_query))
    strcat(g_query, fmt("ip='%s',", IP), charsmax(g_query))
    strcat(g_query, fmt("reason='%s',", reason_safe), charsmax(g_query))
    strcat(g_query, fmt("admin_name='%s',", adminName_safe), charsmax(g_query))
    strcat(g_query, fmt("admin_authid='%s',", adminAuthID), charsmax(g_query))
    strcat(g_query, fmt("admin_ip='%s',", adminIP), charsmax(g_query))
    strcat(g_query, "created_at=NOW(),", charsmax(g_query))
    strcat(g_query, fmt("expire_at=FROM_UNIXTIME(%i),", expireAt), charsmax(g_query))
    strcat(g_query, fmt("flags=%i; ", flags), charsmax(g_query))
  }

  SQL_ThreadQuery(g_tuple, "handle_Saved", g_query)
}

public handle_Saved(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
  if(IsSQLQueryFailed(failstate, query, error, errnum)) {
    return
  }

  formatex(g_query, charsmax(g_query), "SELECT \
    name,authid,ip,reason,\
    admin_name,admin_authid,admin_ip,\
    UNIX_TIMESTAMP(created_at),UNIX_TIMESTAMP(expire_at),flags")
  strcat(g_query, fmt(" FROM %s", SQL_TBL_GAGS), charsmax(g_query))
  strcat(g_query, fmt(" WHERE id=%i;", SQL_GetInsertId(query)), charsmax(g_query))

  SQL_ThreadQuery(g_tuple, "handle_SavedResult", g_query)
}

public handle_SavedResult(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
  if(IsSQLQueryFailed(failstate, query, error, errnum)) {
    return
  }

  enum { res_name, res_authid, res_ip, res_reason,
    res_admin_name, res_admin_authid, res_admin_ip,
    res_created_at, res_expire_at, res_flags
  }

  new name[MAX_NAME_LENGTH];            SQL_ReadResult(query, res_name, name, charsmax(name))
  new authID[MAX_AUTHID_LENGTH];        SQL_ReadResult(query, res_authid, authID, charsmax(authID))
  new IP[MAX_IP_LENGTH];                SQL_ReadResult(query, res_ip, IP, charsmax(IP))
  new reason[MAX_REASON_LENGTH];        SQL_ReadResult(query, res_reason, reason, charsmax(reason))

  new adminName[MAX_NAME_LENGTH];       SQL_ReadResult(query, res_admin_name, adminName, charsmax(adminName))
  new adminAuthID[MAX_AUTHID_LENGTH];   SQL_ReadResult(query, res_admin_authid, adminAuthID, charsmax(adminAuthID))
  new adminIP[MAX_IP_LENGTH];           SQL_ReadResult(query, res_admin_ip, adminIP, charsmax(adminIP))

  new createdAt   = SQL_ReadResult(query, res_created_at)
  new expireAt    = SQL_ReadResult(query, res_expire_at)
  new flags       = SQL_ReadResult(query, res_flags)

  CA_Log(logLevel_Debug, "Player gag saved {'%s', '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i} (queryTime: '%.3f' sec)", \
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
  if(!g_storageInitialized) {
    QueuePushString(g_queueLoad, authID)

    return
  }

  formatex(g_query, charsmax(g_query), "SELECT name, authid, ip, reason,\
    admin_name, admin_authid, admin_ip, \
    UNIX_TIMESTAMP(created_at), UNIX_TIMESTAMP(expire_at), flags FROM %s", SQL_TBL_GAGS); {
    strcat(g_query, fmt(" WHERE (authid = '%s')", authID), charsmax(g_query))
    strcat(g_query, " AND ( expire_at = FROM_UNIXTIME(9999999999) OR (expire_at > NOW()) ) LIMIT 1", charsmax(g_query))
  }

  SQL_ThreadQuery(g_tuple, "handle_Loaded", g_query)
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

  new name[MAX_NAME_LENGTH];            SQL_ReadResult(query, res_name, name, charsmax(name))
  new authID[MAX_AUTHID_LENGTH];        SQL_ReadResult(query, res_authid, authID, charsmax(authID))
  new IP[MAX_IP_LENGTH];                SQL_ReadResult(query, res_ip, IP, charsmax(IP))
  new reason[MAX_REASON_LENGTH];        SQL_ReadResult(query, res_reason, reason, charsmax(reason))

  new adminName[MAX_NAME_LENGTH];       SQL_ReadResult(query, res_admin_name, adminName, charsmax(adminName))
  new adminAuthID[MAX_AUTHID_LENGTH];   SQL_ReadResult(query, res_admin_authid, adminAuthID, charsmax(adminAuthID))
  new adminIP[MAX_IP_LENGTH];           SQL_ReadResult(query, res_admin_ip, adminIP, charsmax(adminIP))

  new createdAt   = SQL_ReadResult(query, res_created_at)
  new expireAt    = SQL_ReadResult(query, res_expire_at)
  new flags       = SQL_ReadResult(query, res_flags)

  CA_Log(logLevel_Debug, "Player gag loaded {'%s', '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i} (queryTime: '%.3f' sec)", \
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
  if(!g_storageInitialized || g_tuple == Empty_Handle) {
    CA_Log(logLevel_Warning, "Storage_Remove(): Storage connection not initialized. Query not executed. (g_storageInitialized=%i, g_tuple=%i)",
      g_storageInitialized, g_tuple
    )

    return
  }

  formatex(g_query, charsmax(g_query), "DELETE FROM %s ", SQL_TBL_GAGS); {
    strcat(g_query, fmt("WHERE (authid = '%s')", authID), charsmax(g_query))
  }

  SQL_ThreadQuery(g_tuple, "handle_Removed", g_query)
}

public handle_Removed(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
  if(IsSQLQueryFailed(failstate, query, error, errnum)) {
    return
  }

  CA_Log(logLevel_Debug, "Player gag removed { } (queryTime: '%.3f' sec)", \
    queuetime \
  )

  ExecuteForward(g_fwd_StorageRemoved, g_ret)
}
