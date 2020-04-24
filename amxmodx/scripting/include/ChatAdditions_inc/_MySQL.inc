#if defined _CA_API_MySQL_included
    #endinput
#endif

#define _CA_API_MySQL_included

#include <sqlx>

// Configure your connect to MySQL Server
new const SQL_HOSTNAME[]	= "127.0.0.1";
new const SQL_USERNAME[]	= "root";
new const SQL_PASSWORD[]	= "pw";
new const SQL_DBNAME[]		= "db";

new const SQL_TBL_GAGS[]	= "players_gags";



const QUERY_LENGTH	= 1472;
new Handle: g_hTuple;

enum any: Query_state {
	SQL_INIT,
	DROP_TABLE,
	LOAD_PLAYER,
	SAVE_PLAYER,
	REMOVE_BLOCK
};

enum qeury_data_s {
	qd_Query_state,
	qd_UserID
}

new g_sqlData[qeury_data_s];

static Float:g_fStartInitTime;

public plugin_cfg() {
	init_storage();
}

static init_storage() {
	g_fStartInitTime = get_gametime();
	
	new const SQL_DBTYPE[] = "mysql";
	if(!SQL_SetAffinity(SQL_DBTYPE))
		set_fail_state("Failed to use '%s' as DB driver. Check modules.ini", SQL_DBTYPE);

	g_hTuple = SQL_MakeDbTuple(SQL_HOSTNAME, SQL_USERNAME, SQL_PASSWORD, SQL_DBNAME);
	SQL_SetCharset(g_hTuple, "utf8");

	CreateTable();
}

public destroy_storage() {
	SQL_FreeHandle(g_hTuple);
}

public CreateTable() {
	new szQuery[QUERY_LENGTH * 3];

	// TODO: Disable autocreate table
	formatex(szQuery, charsmax(szQuery), "CREATE TABLE IF NOT EXISTS `%s` (\
		id				int(11) NOT NULL AUTO_INCREMENT,\
		name			varchar(32) NOT NULL,\
		authid			varchar(32) NOT NULL,\
		ip				varchar(15) NOT NULL,\
		reason			varchar(64) NOT NULL,\
		admin_name		varchar(32) NOT NULL,\
		admin_authid 	varchar(32) NOT NULL,\
		admin_ip		varchar(32) NOT NULL,\
		time			int(11) NOT NULL,\
		create_time		int(11) NOT NULL,\
		expire_time		int(11) NOT NULL,\
		flags			int(11) NOT NULL,\
				PRIMARY KEY (`id`),\
			INDEX (`authid`)\
	)", SQL_TBL_GAGS);

	g_sqlData[qd_Query_state] = SQL_INIT;
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public SQL_Handler(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime) {
	switch(failstate) {
		case TQUERY_CONNECT_FAILED:	{
			CA_Log(_Warnings, "SQL: connection failed\n[%i] %s", errnum, error)
			return;
		}
		case TQUERY_QUERY_FAILED: {
			new lastQue[QUERY_LENGTH * 3];
			SQL_GetQueryString(query, lastQue, charsmax(lastQue));

			CA_Log(_Warnings, "SQL: query failed\n[%i] %s\n[QUERY]:'%s'", errnum, error, lastQue)
			return;
		}
	}

	new q_state = qeury_data_s:data[qd_Query_state];
	switch(q_state) {
		case SQL_INIT: Storage_Inited(get_gametime() - g_fStartInitTime);
		case LOAD_PLAYER: {
			new bool: bFound = SQL_NumResults(query) != 0;
			if(!bFound) {
				Storage_PlayerLoaded(data[qd_UserID]);
				return;
			}

			enum { res_Time, res_ExpireTime, res_Flags, res_Reason };
			new target = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), data[qd_UserID]);

			g_aCurrentGags[target][_ExpireTime] = SQL_ReadResult(query, res_ExpireTime);
			if(g_aCurrentGags[target][_ExpireTime] <= get_systime()) {
				Storage_PlayerLoaded(data[qd_UserID]);
				return;
			}
			
			g_aCurrentGags[target][_Time] = SQL_ReadResult(query, res_Time);
			g_aCurrentGags[target][_bitFlags]	= gag_flags_s:SQL_ReadResult(query, res_Flags);
			SQL_ReadResult(query, res_Reason, g_aCurrentGags[target][_Reason], charsmax(g_aCurrentGags[][_Reason]));

			Storage_PlayerLoaded(data[qd_UserID], .bFound = true);
		}
		case SAVE_PLAYER: {
			Storage_PlayerSaved(data[qd_UserID]);
		}
		case REMOVE_BLOCK: {
			Storage_PlayerRemoved(data[qd_UserID]);
		}
	}

	CA_Log(_Debug, "SQL_Handler() queuetime='%.5f'", queuetime)
}

public load_from_storage(const aGagData[gag_s]) {
	new szQuery[QUERY_LENGTH * 2];
	formatex(szQuery, charsmax(szQuery), "SELECT time, expire_time, flags, reason FROM `%s` WHERE ( \
		authid = \"%s\" OR ip = \"%s\") AND expire_time >= %i LIMIT 1",
	SQL_TBL_GAGS,
		aGagData[_AuthId], aGagData[_IP], get_systime()
	);

	g_sqlData[qd_Query_state] = LOAD_PLAYER;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public save_to_storage(const aGagData[gag_s]) {
	new szQuery[QUERY_LENGTH * 3];

	new sName_safe[MAX_NAME_LENGTH * 2];
	SQL_QuoteStringFmt(Empty_Handle, sName_safe, charsmax(sName_safe), aGagData[_Name]);
	new sAdminName_safe[MAX_NAME_LENGTH * 2];
	SQL_QuoteStringFmt(Empty_Handle, sAdminName_safe, charsmax(sAdminName_safe), aGagData[_AdminName]);
	new sReason_safe[MAX_REASON_LEN * 2];
	SQL_QuoteStringFmt(Empty_Handle, sReason_safe, charsmax(sReason_safe), aGagData[_Reason]);

	formatex(szQuery, charsmax(szQuery), "REPLACE INTO `%s` (\
		name,authid,ip,reason,admin_name,admin_authid,\
		admin_ip,time,create_time,expire_time,flags\
	) VALUES(\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",%i,%i,%i,%i)",\
	SQL_TBL_GAGS,
		sName_safe, aGagData[_AuthId], aGagData[_IP], sReason_safe,
		sAdminName_safe, aGagData[_AdminAuthId], aGagData[_AdminIP],
		aGagData[_Time], get_systime(), aGagData[_ExpireTime], aGagData[_bitFlags]
	);

	g_sqlData[qd_Query_state] = SAVE_PLAYER;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public remove_from_storage(aGagData[gag_s]) {
	new szQuery[QUERY_LENGTH * 3];

	formatex(szQuery, charsmax(szQuery), "DELETE FROM `%s` WHERE ( \
		authid = \"%s\" AND ip = \"%s\")",
	SQL_TBL_GAGS,
		aGagData[_AuthId], aGagData[_IP]
	);

	g_sqlData[qd_Query_state] = REMOVE_BLOCK;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);

	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}
