#if defined _CA_STORAGE_API_ENDPOINT_included
    #endinput
#endif

#define _CA_STORAGE_API_ENDPOINT_included

#pragma dynamic 131072

new bool: g_storageInitialized

stock bool: IsSQLQueryFailed(const failstate, const Handle: query, const error[], const errNum) {
    switch (failstate) {
        case TQUERY_CONNECT_FAILED:	{
            log_amx("SQL: connection failed [%i] `%s`", errNum, error)
            return true
        }
        case TQUERY_QUERY_FAILED: {
            log_amx("SQL: query failed [%i] %s", errNum, error);

            server_print("^n^n ===> Query:")
            new buffer[8192]; SQL_GetQueryString(query, buffer, charsmax(buffer));
            for(new i, len = strlen(buffer); i < len; i+=255) {
                server_print(fmt("%-255s", buffer[i]));
            }

            return true
        }
    }

    return false
}

// Should be realized in each storage
RegisterNatives() {
    register_native("CA_Storage_Save", "native_Storage_Save");
    register_native("CA_Storage_Load", "native_Storage_Load");
    register_native("CA_Storage_Remove", "native_Storage_Remove");
    register_native("CA_Storage_IsInitialized", "native_Storage_IsInitialized");
}
public native_Storage_Save(const plugin_id, const argc) {
    enum { arg_name = 1, arg_authID, arg_IP, arg_reason, arg_adminName, arg_adminAuthID, arg_adminIP, arg_expireAt, arg_flags }

    new name[MAX_NAME_LENGTH]; get_string(arg_name, name, charsmax(name));
    new authID[MAX_AUTHID_LENGTH]; get_string(arg_authID, authID, charsmax(authID));
    new IP[MAX_IP_LENGTH]; get_string(arg_IP, IP, charsmax(IP));
    new reason[256]; get_string(arg_reason, reason, charsmax(reason));
    new adminName[MAX_NAME_LENGTH]; get_string(arg_adminName, adminName, charsmax(adminName));
    new adminAuthID[MAX_AUTHID_LENGTH]; get_string(arg_adminAuthID, adminAuthID, charsmax(adminAuthID));
    new adminIP[MAX_IP_LENGTH]; get_string(arg_adminIP, adminIP, charsmax(adminIP));
    new expireAt = get_param(arg_expireAt);
    new flags = get_param(arg_flags);

    Storage_Save(name, authID, IP, reason, adminName, adminAuthID, adminIP, expireAt, flags);
}
public native_Storage_Load(const plugin_id, const argc) {
    enum { arg_authID = 1 }

    new authID[MAX_AUTHID_LENGTH]; get_string(arg_authID, authID, charsmax(authID));
    Storage_Load(authID);
}
public native_Storage_Remove(const plugin_id, const argc) {
    enum { arg_authID = 1 }

    new authID[MAX_AUTHID_LENGTH]; get_string(arg_authID, authID, charsmax(authID));
    Storage_Remove(authID);
}
public bool: native_Storage_IsInitialized(const plugin_id, const argc) {
    return g_storageInitialized;
}


// Forwards handlers
new g_fwd_StorageInitialized = INVALID_HANDLE;
new g_fwd_StorageSaved = INVALID_HANDLE;
new g_fwd_StorageLoaded = INVALID_HANDLE;
new g_fwd_StorageRemoved = INVALID_HANDLE;
new g_ret;
// Should be realized in each storage
RegisterForwards() {
    g_fwd_StorageInitialized = CreateMultiForward("CA_Storage_Initialized", ET_IGNORE);
    g_fwd_StorageSaved = CreateMultiForward("CA_Storage_Saved", ET_IGNORE,
        FP_STRING, FP_STRING, FP_STRING, FP_STRING,
        FP_STRING, FP_STRING, FP_STRING,
        FP_CELL, FP_CELL, FP_CELL
    );
    g_fwd_StorageLoaded = CreateMultiForward("CA_Storage_Loaded", ET_IGNORE,
        FP_STRING, FP_STRING, FP_STRING, FP_STRING,
        FP_STRING, FP_STRING, FP_STRING,
        FP_CELL, FP_CELL, FP_CELL
    );
    g_fwd_StorageRemoved = CreateMultiForward("CA_Storage_Removed", ET_IGNORE);
}



/* TEST

        public CA_Storage_Initialized() {
        new name[] = "Some safe name"
        new authID[] = "0:1:2345678"
        new IP[] = "123.123.123.123"
        new reason[] = "Some safe reason"
        new adminName[] = "Some safe admin name"
        new adminAuthID[] = "Some safe admin authID"
        new adminIP[] = "Some safe admin IP"
        new expireAt = 1624232019
        new flags = 3

        CA_Storage_Save(name, authID, IP, reason, adminName, adminAuthID, adminIP, expireAt, flags)
        }
        public CA_Storage_Saved() {
        new authID[] = "0:1:2345678"
        CA_Storage_Load(authID)
        }
        public CA_Storage_Loaded(const name[], const authID[], const IP[], const reason[],
        const adminName[], const adminAuthID[], const adminIP[],
        const createdAt, const expireAt, const flags) {
        log_amx(" > CA_Storage_Loaded{`%s`,`%s`,%s`,`%s`,`%s`,`%s`,`%s`,%i,%i,%i}",
                name, authID, reason, IP,
                adminName, adminAuthID, adminIP,
                createdAt, expireAt, flags)
        CA_Storage_Remove(authID)
        }
        public CA_Storage_Removed() {

        }
*/
