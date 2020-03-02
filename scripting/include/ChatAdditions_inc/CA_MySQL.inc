#if defined _CA_API_MySQL_included
    #endinput
#endif

#define _CA_API_MySQL_included

#include <sqlx>

new const SQL_HOSTNAME[]	= "127.0.0.1";
new const SQL_USERNAME[]	= "root";
new const SQL_PASSWORD[]	= "12345678";
new const SQL_DBNAME[]		= "ChatAdditions";
new const SQL_TBL_GAGS[]	= "players_gags";

new const SQL_DBTYPE[]		= "mysql";


const QUERY_LENGTH	= 1472;
new Handle: g_hTuple;

enum any: Query_state
{
// Database controlle
	SQL_INIT,
	TABLE_DROP,

// Players actions
	PLAYER_SAVE,
	PLAYER_LOAD,
	PLAYER_REMOVE,
};

enum qeury_data_s
{
	qd_Query_state,
	qd_Player
}

enum any: Table_s
{
	any: col_Id,
	any: col_Name,
	any: col_AuthId,
	any: col_IP,
	any: col_Name,
	any: col_Admin_AuthId,
	any: col_Admin_IP,
	any: col_CreateTime,
	any: col_ExpireTime,
	any: col_Flags
}

new g_sqlData[qeury_data_s];

public Init_Storage()
{
	// Thanks to serfreeman1337
	if(!SQL_SetAffinity(SQL_DBTYPE))
		set_fail_state("Failed to use '%s' as DB driver. Check modules.ini", SQL_DBTYPE);

	g_hTuple = SQL_MakeDbTuple(SQL_HOSTNAME, SQL_USERNAME, SQL_PASSWORD, SQL_DBNAME);
	SQL_SetCharset(g_hTuple, "utf8");

	CreateTable();

	return true;
}

public Storage_Destroy()
{
	SQL_FreeHandle(g_hTuple);

	return 1;
}

//	new const row_id[]	= "id",
// 	row_name[]			= "name",
// 	row_steamid[]		= "steamid",
// 	row_ip[]			= "ip",
// 	row_admin_name[]	= "admin_name",	
// 	row_admin_steamid[] = "admin_steamid",
// 	row_admin_ip[] 		= "admin_ip",
// 	row_create_time[] 	= "create_time",
// 	row_unban_time[] 	= "unban_time";
// 	row_flags[] 		= "flags";

CreateTable()
{
	static szQuery[QUERY_LENGTH * 2];

	formatex(szQuery, charsmax(szQuery),
		"CREATE TABLE IF NOT EXISTS `%s` (\
			`id`			int(11) NOT NULL AUTO_INCREMENT,\
			`name`			varchar(32) NOT NULL,\
			`steamid`		varchar(32) NOT NULL,\
			`ip`			varchar(15) NOT NULL,\
			`reason`		varchar(64) NOT NULL,\
			`admin_name`	varchar(32) NOT NULL,\
			`admin_steamid` varchar(32) NOT NULL,\
			`admin_ip`		varchar(32) NOT NULL,\
			`create_time`	int(11) NOT NULL,\
			`unban_time`	int(11) NOT NULL,\
			`flags`			int(11) NOT NULL,\
				PRIMARY KEY (`id`),\
				INDEX (`steamid`)\
			);", SQL_TBL_GAGS, SQL_TBL_GAGS
	);

	g_sqlData[qd_Query_state] = SQL_INIT;
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public SQL_Handler(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime)
{
	switch(failstate)
	{
		case TQUERY_CONNECT_FAILED:
		{
			log_amx("SQL: connection failed");
			log_amx("[ %d ] %s", errnum, error);

			return PLUGIN_HANDLED;
		}
		case TQUERY_QUERY_FAILED:
		{
			new lastQue[QUERY_LENGTH];
			SQL_GetQueryString(query, lastQue, charsmax(lastQue));
			
			log_amx("SQL: query failed");
			log_amx("[ %d ] %s", errnum, error);
			log_amx("[ QUERY ] %s", lastQue);
			
			return PLUGIN_HANDLED;
		}
	}

	switch(data[0])
	{
		case SQL_INIT: DB_Inited();
		case PLAYER_SAVE:
		{
			DB_PlayerSaved(.pPlayer = data[_Player]);
			server_print("\n   - SQL_Handler() PLAYER_SAVE(pPlayer=%i)", data[_Player]);
		}
		case PLAYER_LOAD:
		{
			if(SQL_NumResults(query))
			{
				static pPlayer;
				pPlayer = data[_Player];

#if defined DEBUG
				PrintQuery(query);
#endif	

				// Save on current ingame PlayersArray - gag
				g_PlayersGags[pPlayer][_ExpireTime] = SQL_ReadResult(query, col_ExpireTime);
				g_PlayersGags[pPlayer][_bitFlags] = any: SQL_ReadResult(query, col_Flags);

				server_print("\n   - SQL_Handler() FOUND (pPlayer=%i, iExpiredTime=%i)", pPlayer, SQL_ReadResult(query, col_ExpireTime));

			} else server_print("\n   - SQL_Handler() NOT_FOUND(pPlayer=%i)", data[_Player]);
		}
		case PLAYER_REMOVE:
		{
			if(SQL_NumResults(query) == 0)
				DB_PlayerRemoved(data[_Player]);
			else
			{
				static iGagId;
				iGagId = SQL_ReadResult(query, col_Id);

				static szQuery[QUERY_LENGTH];
				formatex(szQuery, charsmax(szQuery), "DELETE FROM `%s` WHERE `unban_time` = '0' AND `id` = '%i' LIMIT 1;", SQL_TBL_GAGS, iGagId);

				g_sqlData[qd_Query_state] = PLAYER_REMOVE;
				g_sqlData[qd_Player] = data[_Player];

				SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));

				server_print("\n   - SQL_Handler() FOUND (iGagId=%i)", iGagId);
			}
		}
	}

	server_print("\n   - SQL_Handler() queuetime='%.5f'", queuetime);

	return PLUGIN_CONTINUE;
}

// TODO!
DB_Inited()
{
	/* static bool: bInitState = false, dummy_ret;
	if(bInitState)
		ExecuteForward(g_fwd_Initialized, dummy_ret); */
#if defined DEBUG
	server_print("\n   - DB_Inited() DATABASE INITIALIZED.\n");
#endif
}

public load_from_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	static szQuery[QUERY_LENGTH * 2];
	formatex(szQuery, charsmax(szQuery),
		"SELECT * FROM `%s` WHERE (`ip` = '%s' OR `steamid` = '%s') AND `unban_time` >= '0'",
			SQL_TBL_GAGS, szIP, szAuthId
	);

	g_sqlData[qd_Query_state] = PLAYER_LOAD;
	g_sqlData[qd_Player] = aGagData[_Player];
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));

#if defined DEBUG
	server_print("\n   - load_from_storage(%s, %s)\n", szAuthId, szIP);
#endif
}

// From Main API
public save_to_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	static szQuery[QUERY_LENGTH], iLen;

// TODO!
	new szName[MAX_NAME_LENGTH],
		iSystime = get_systime(),
		pPlayer = aGagData[_Player];

	// User Data
	get_user_name(pPlayer, szName, charsmax(szName));
	get_user_ip(pPlayer, aGagData[_IP], 31);
	get_user_authid(pPlayer, aGagData[_AuthId], 31);
	
	// Admin Data
	get_user_name(aGagData[_AdminId], aGagData[_AdminName], 31);
	get_user_authid(aGagData[_AdminId], aGagData[_AdminAuthId], 31);
	get_user_ip(aGagData[_AdminId], aGagData[_AdminIP], 31, .without_port = true);

// TODO!
	if(aGagData[_bitFlags] == m_REMOVED)
	{
		// FORM & sent QUERY to remove player from table.
	
		formatex(szQuery, charsmax(szQuery), "\
			SELECT `id`, `name`, `steamid` FROM `%s`\
				WHERE (`ip` = '%s' OR `steamid` = '%s') AND `unban_time` = '0' LIMIT 1"
			, SQL_TBL_GAGS, aGagData[_IP], aGagData[_AuthId]
		);

		g_sqlData[qd_Query_state] = PLAYER_REMOVE;
		g_sqlData[qd_Player] = pPlayer;
		SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));

		return;
	}

	iLen = formatex(szQuery, charsmax(szQuery), "REPLACE INTO `%s` \
			(`name`, `steamid`, `ip`, `reason`, `admin_name`, `admin_steamid`, `admin_ip`, `create_time`, `unban_time`, `flags`) \
		VALUES('%s', '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i)",
			SQL_TBL_GAGS,
				szName, szAuthId, szIP, aGagData[_Reason],
				aGagData[_AdminName], aGagData[_AdminAuthId], aGagData[_AdminIP],
				iSystime, aGagData[_ExpireTime], aGagData[_bitFlags]
		);
	
// TODO: 
	#pragma unused iLen
	// server_print("aGagData[m_bitFlags]=%i", aGagData[m_bitFlags]);

	// server_print("QUERY='%s'", szQuery);

	g_sqlData[qd_Query_state] = PLAYER_SAVE;
	g_sqlData[qd_Player] = pPlayer;
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

// TODO!
DB_PlayerSaved(pPlayer)
{
	/* static bool: bSaveState = false, dummy_ret;
	if(bSaveState)
		ExecuteForward(g_fwd_Initialized, dummy_ret); */

	server_print("\n   - DB_PlayerSaved() Player[%i] SAVED to table!", pPlayer);
}

DB_PlayerRemoved(pPlayer)
{
	/* static bool: bSaveState = false, dummy_ret;
	if(bSaveState)
		ExecuteForward(g_fwd_Initialized, dummy_ret); */

	server_print("\n   - DB_PlayerRemoved() Player[%i] REMOVED from table!", pPlayer);
}



// Debug
stock PrintQuery(any: query)
{
	const s = 64;
	new col_0, col_8, col_9, col_10;
	new col_1[s], col_2[s], col_3[s], col_4[s], col_5[s], col_6[s], col_7[s];

	col_0 = SQL_ReadResult(query, 0);
	col_8 = SQL_ReadResult(query, 8);
	col_9 = SQL_ReadResult(query, 9);
	col_10 = SQL_ReadResult(query, 10);

	SQL_ReadResult(query, 1, col_1, charsmax(col_1));
	SQL_ReadResult(query, 2, col_2, charsmax(col_2));
	SQL_ReadResult(query, 3, col_3, charsmax(col_3));
	SQL_ReadResult(query, 4, col_4, charsmax(col_4));
	SQL_ReadResult(query, 5, col_5, charsmax(col_5));
	SQL_ReadResult(query, 6, col_6, charsmax(col_6));
	SQL_ReadResult(query, 7, col_7, charsmax(col_7));

	server_print("\n   - PrintQuery(query)\n\
		\t col0	= '%i'\n\
		\t col1	= '%s'\n\
		\t col2	= '%s'\n\
		\t col3	= '%s'\n\
		\t col4	= '%s'\n\
		\t col5	= '%s'\n\
		\t col6	= '%s'\n\
		\t col7	= '%s'\n\
		\t col8	= '%i'\n\
		\t col9	= '%i'\n\
		\t col10	= '%i'\n\
	",
		col_0, col_1, col_2, col_3,
		col_4, col_5, col_6, col_7,
		col_8, col_9, col_10
	);
}