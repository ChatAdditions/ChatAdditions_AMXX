#if defined _CA_API_SQLite_included
    #endinput
#endif

#define _CA_API_SQLite_included


#include <sqlx>

new const SQL_DBNAME[]		= "ChatAdditions";
new const SQL_TBL_GAGS[]	= "players_gags";

new const SQL_DBTYPE[]		= "sqlite";


const QUERY_LENGTH	= 1472;
new Handle: g_hTuple;

enum any: Query_state
{
	SQL_INIT,
	DROP_TABLE,
	LOAD_PLAYER,
	SAVE_PLAYER,
	REMOVE_BLOCK
};

enum qeury_data_s
{
	_Query_state,
	_Player
}

new g_sqlData[qeury_data_s];

public Init_Storage()
{
	// Thanks to serfreeman1337
	if(!SQL_SetAffinity(SQL_DBTYPE))
		set_fail_state("Failed to use '%s' as DB driver. Check modules.ini", SQL_DBTYPE);

	g_hTuple = SQL_MakeDbTuple( "", "", "", SQL_DBNAME);
	SQL_SetCharset(g_hTuple, "utf8");

	CreateTable();

	return true;
}

public Storage_Destroy()
{
	SQL_FreeHandle(g_hTuple);

	return 1;
}


// new const row_id[]		= "id",
// 	row_name[]			= "name",
// 	row_steamid[]		= "steamid",
// 	row_ip[]			= "ip",
// 	row_admin_name[]	= "admin_name",	
// 	row_admin_steamid[] = "admin_steamid",
// 	row_admin_ip[] 		= "admin_ip",
// 	row_create_time[] 	= "create_time",
// 	row_unban_time[] 	= "unban_time";

// /* enum Table_s
// {
// 	row_id[] = "asdasd",
// 	row_name,
// 	row_steamid,
// 	row_ip,
// 	row_admin_name,
// 	row_admin_steamid,


// } */



// /* 
// new const g_szRowNames[Table_s][] =
// {
// 	"row_id",
// 	"row_name",
// 	"row_steamid",
// 	"row_ip",
// 	"row_admin_name",
// 	"row_admin_steamid",

// } */

CreateTable()
{
	static szQuery[QUERY_LENGTH * 2];

	formatex(szQuery, charsmax(szQuery),
		"CREATE TABLE IF NOT EXISTS `%s` (\
			`id`			INTEGER PRIMARY KEY AUTOINCREMENT,\
			`name`			varchar(32) NOT NULL,\
			`steamid`		varchar(32) NOT NULL,\
			`ip`			varchar(15) NOT NULL,\
			`reason`		varchar(64) NOT NULL,\
			`admin_name`	varchar(32) NOT NULL,\
			`admin_steamid`	varchar(32) NOT NULL,\
			`admin_ip`		varchar(32) NOT NULL,\
			`create_time`	int(11) NOT NULL,\
			`unban_time`	int(11) NOT NULL\
			`flags`			int(11) NOT NULL,\
			)\
			CREATE UNIQUE INDEX t1b ON `%s`(steamid)", SQL_TBL_GAGS, SQL_TBL_GAGS
	);

	g_sqlData[_Query_state] = SQL_INIT;
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
		case LOAD_PLAYER:
		{
			if(SQL_NumResults(query))
			{
				static pPlayer; pPlayer = data[_Player];

				// for(new i; i <= SQL_NumColumns(query); i++)
				// {
				// 	g_PlayersGags[pPlayer][i] = SQL_ReadResult(query, i);
					
				// }
				// Get Expired time
				static any: iExpiredTime;
				iExpiredTime = SQL_ReadResult(query, 0);

				// set_user_gag(pPlayer, aGagData);

				g_PlayersGags[pPlayer][m_iExpireTime] = iExpiredTime;
				// SQL_ReadResult(query, g_PlayersGags[pPlayer][m_szReason], MAX_REASON_LEN - 1);

				server_print("SQL_Handler() FOUND (pPlayer=%i, iExpiredTime=%i)", pPlayer, iExpiredTime);
			} else server_print("SQL_Handler() NOT_FOUND(pPlayer=%i)", data[_Player]);
		}
		case SAVE_PLAYER:
		{
			server_print("SQL_Handler() SAVE_PLAYER(pPlayer=%i)", data[_Player]);
			DB_PlayerSaved(.pPlayer = data[_Player]);
		}
	}

	server_print("SQL_Handler() queuetime='%.5f'", queuetime);

	return PLUGIN_CONTINUE;
}

// TODO!
DB_Inited()
{
	/* static bool: bInitState = false, dummy_ret;
	if(bInitState)
		ExecuteForward(g_fwd_Initialized, dummy_ret); */

	server_print("DB_Inited() [OK!] DATABASE INITIALIZED!!!!!");
}

public load_from_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	static szQuery[QUERY_LENGTH * 2];
	formatex(szQuery, charsmax(szQuery),
		"SELECT * FROM `%s` WHERE (`ip` = '%s' OR `steamid` = '%s') AND `unban_time` >= '0'",
			SQL_TBL_GAGS, szIP, szAuthId
	);

	g_sqlData[_Query_state] = LOAD_PLAYER;
	g_sqlData[_Player] = aGagData[m_Player];
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public save_to_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	static szQuery[QUERY_LENGTH], iLen;

// TODO!
	new szName[MAX_NAME_LENGTH],
		iSystime = get_systime(),
		pPlayer = aGagData[m_Player];

	// User Data
	get_user_name(pPlayer, szName, charsmax(szName));
	
	// Admin Data
	get_user_name(aGagData[m_AdminId], aGagData[m_szAdminName], 31);
	get_user_authid(aGagData[m_AdminId], aGagData[m_szAdminAuthId], 31);
	get_user_ip(aGagData[m_AdminId], aGagData[m_szAdminIP], 31, .without_port = true);

#if DATABASE_TYPE == DB_SQLite
	#error NE GOTOVA DLYA SQLite SAVE()!
#endif

	// server_print("QUERY='%s'", szQuery);

	g_sqlData[_Query_state] = SAVE_PLAYER;
	g_sqlData[_Player] = pPlayer;
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

// TODO!
DB_PlayerSaved(pPlayer)
{
	/* static bool: bSaveState = false, dummy_ret;
	if(bSaveState)
		ExecuteForward(g_fwd_Initialized, dummy_ret); */

	server_print("DB_PlayerSaved() [OK!] Player[%i] SAVED!", pPlayer);
}