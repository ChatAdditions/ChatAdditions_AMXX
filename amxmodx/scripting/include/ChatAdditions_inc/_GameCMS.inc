#if defined _CA_API_MySQL_included
	#endinput
#endif

#define _CA_API_MySQL_included

#include <sqlx>


#pragma semicolon 0
#include <gamecms5>
#pragma semicolon 1

new const SQL_TBL_GAGS[]	= "comms";



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

// GameCMS related
new g_iServerId;
new g_bitGameCMS_APILevel;

//#define _SQL_TESTDB

public plugin_cfg() {
	init_storage();
}

static init_storage() {
	g_fStartInitTime = get_gametime();

#if defined _SQL_TESTDB
	new const SQL_DBTYPE[] = "sqlite";
	if(!SQL_SetAffinity(SQL_DBTYPE))
		set_fail_state("Failed to use '%s' as DB driver. Check modules.ini", SQL_DBTYPE);

	g_hTuple = SQL_MakeDbTuple( "", "", "", "ChatAdditions");

	CreateTable();

	g_iServerId = 1337;
#endif
}

public OnAPIPluginLoaded(Handle: sqlTuple) {
	g_hTuple = sqlTuple;
	g_iServerId = cmsapi_get_server_id();
	g_bitGameCMS_APILevel |= UseGameCms;

	SQL_SetCharset(g_hTuple, "utf8");
	new const SQL_DBTYPE[] = "mysql";
	if(!SQL_SetAffinity(SQL_DBTYPE))
		set_fail_state("Failed to use '%s' as DB driver. Check modules.ini", SQL_DBTYPE);

	Storage_Inited(get_gametime() - g_fStartInitTime);
}

public OnAPIAdminsLoaded() {
	g_bitGameCMS_APILevel |= UseGameCmsAdmins;
}

public destroy_storage() {

}

static stock CreateTable() {
	new szQuery[QUERY_LENGTH * 3];
	formatex(szQuery, charsmax(szQuery),
	"CREATE TABLE IF NOT EXISTS comms ( \
		bid			INTEGER PRIMARY KEY AUTOINCREMENT, \
		authId		VARCHAR, \
		name		VARCHAR, \
		created		INTEGER, \
		expired		INTEGER, \
		length		INTEGER, \
		reason		VARCHAR, \
		admin_id	INTEGER, \
		admin_nick	VARCHAR, \
		server_id	INTEGER, \
		modified_by	VARCHAR, \
		type		INTEGER );"
	);

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
			if(g_aCurrentGags[target][_ExpireTime] <= get_systime()) { // TODO: remove by SQL logic
				Storage_PlayerLoaded(data[qd_UserID]);
				return;
			}

			g_aCurrentGags[target][_Time] = SQL_ReadResult(query, res_Time);
			g_aCurrentGags[target][_bitFlags] = gag_flags_s: _GCMS_FlagsTo_CAGAGFlags(SQL_ReadResult(query, res_Flags));
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
	new szQuery[QUERY_LENGTH * 3];

	#if defined _SQL_TESTDB
	formatex(szQuery, charsmax(szQuery),
	"SELECT length, expired, type, reason FROM `%s` WHERE \
		server_id = %i \
		AND authid = \"%s\" \
		AND ( \
				(expired > strftime('%%s','now') OR expired = '0') \
				AND length != '-1' \
				AND expired != '-1' \
			) \
		LIMIT 1;",
		SQL_TBL_GAGS, g_iServerId, aGagData[_AuthId]
	);

	#else

	formatex(szQuery, charsmax(szQuery),
	"SELECT length, expired, type, reason FROM `%s` WHERE \
		server_id = %i \
		AND authid = \"%s\" \
		AND ( \
				(expired > UNIX_TIMESTAMP(NOW()) OR expired = '0') \
				AND length != '-1' \
				AND expired != '-1' \
			) \
		LIMIT 1;",
		SQL_TBL_GAGS, g_iServerId, aGagData[_AuthId]
	);

	#endif
	g_sqlData[qd_Query_state] = LOAD_PLAYER;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public save_to_storage(const aGagData[gag_s]) {
	new szQuery[QUERY_LENGTH * 3];

	#if defined _SQL_TESTDB
	SQL_QuoteStringFmt(Empty_Handle, szQuery, charsmax(szQuery),
		"REPLACE INTO `%s` (bid, authId, name, created, expired, length, reason, admin_id, admin_nick, server_id, modified_by, type) \
		values (%i, \"%s\", \"%s\", %i, %i, %i, \"%s\", %i, \"%s\", %i, \"%s\", %i);",
		SQL_TBL_GAGS, 0, aGagData[_AuthId], aGagData[_Name], get_systime(), 
		aGagData[_ExpireTime], aGagData[_Time], aGagData[_Reason], 
		12345, aGagData[_AdminName], g_iServerId, "plBlockInfo[id][GModifiedBy]", aGagData[_bitFlags]
	);

	#else

	SQL_QuoteStringFmt(Empty_Handle, szQuery, charsmax(szQuery),
		"REPLACE INTO `%s` (bid, authId, name, created, expired, length, reason, admin_id, admin_nick, server_id, modified_by, type) \
		values (%i, \"%s\", \"%s\", %i, %i, %i, \"%s\", %i, \"%s\", %i, \"%s\", %i);",
		SQL_TBL_GAGS, 0, aGagData[_AuthId], aGagData[_Name], get_systime(), 
		aGagData[_ExpireTime], aGagData[_Time], aGagData[_Reason], 
		cmsapi_get_admin_ident(aGagData[_AdminId]), aGagData[_AdminName], g_iServerId, aGagData[_AdminName], _CAGAGFlags_to_GCMS_Flags(aGagData[_bitFlags])
	);

	#endif
	g_sqlData[qd_Query_state] = SAVE_PLAYER;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public remove_from_storage(const aGagData[gag_s]) {
	new szQuery[QUERY_LENGTH * 3];

	SQL_QuoteStringFmt(Empty_Handle, szQuery, charsmax(szQuery),
		"UPDATE `%s` SET expired=%i, modified_by=\"%s\" WHERE authId = \"%s\";",
		SQL_TBL_GAGS, aGagData[_ExpireTime], aGagData[_AdminName], aGagData[_AuthId]
	);

	g_sqlData[qd_Query_state] = REMOVE_BLOCK;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

static gag_flags_s: _GCMS_FlagsTo_CAGAGFlags(const flag) {
	switch(flag) {
		case BLOCK_STATUS_NONE:		return (m_REMOVED);
		case BLOCK_STATUS_ALL:		return (m_Say | m_SayTeam | m_Voice);
		case BLOCK_STATUS_CHAT:		return (m_Say | m_SayTeam);
		case BLOCK_STATUS_VOICE:	return (m_Voice);
	}

	CA_Log(_Warnings, "[WARN]: _GCMS_FlagsTo_CAGAGFlags() => Undefinded flag:%i", flag)
	return m_REMOVED;
}

static stock _CAGAGFlags_to_GCMS_Flags(const gag_flags_s: flags) {
	if(flags == m_Voice)
		return BLOCK_STATUS_VOICE;
	if(flags == (m_Say | m_SayTeam | m_Voice))
		return BLOCK_STATUS_ALL;
	if(flags == (m_Say | m_SayTeam))
		return BLOCK_STATUS_CHAT;

	return BLOCK_STATUS_NONE;
}