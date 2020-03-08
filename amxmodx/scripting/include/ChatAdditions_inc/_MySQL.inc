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

new const SQL_DBTYPE[]		= "mysql";


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
	qd_Query_state,
	qd_UserID
}

new g_sqlData[qeury_data_s];

public Init_Storage()
{
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

public CreateTable()
{
	new szQuery[QUERY_LENGTH];

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
		create_time		int(11) NOT NULL,\
		unban_time		int(11) NOT NULL,\
		flags			int(11) NOT NULL,\
				PRIMARY KEY (`id`),\
			INDEX (`authid`)\
	)", SQL_TBL_GAGS);

	g_sqlData[qd_Query_state] = SQL_INIT;
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public SQL_Handler(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime)
{
	switch(failstate) {
		case TQUERY_CONNECT_FAILED:	{
			log_amx("SQL: connection failed");
			log_amx("[ %d ] %s", errnum, error);

			return;
		}
		case TQUERY_QUERY_FAILED: {
			new lastQue[QUERY_LENGTH * 4];
			SQL_GetQueryString(query, lastQue, charsmax(lastQue));
			
			log_amx("SQL: query failed\n [%i] %s\n[QUERY]:'%s'", errnum, error, lastQue);
			return;
		}
	}

	new q_state = qeury_data_s:data[qd_Query_state];
	switch(q_state)
	{
		case SQL_INIT: DB_Inited();
		case LOAD_PLAYER: {
			if(!SQL_NumResults(query)) {
				server_print("SQL_Handler()::LOAD_PLAYER(UserID=#%i) NOT FOUND in DB", data[qd_UserID]);
				return;
		}

			enum { res_UnbanTime, res_Flags };
			new pPlayer = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), data[qd_UserID]);

			g_PlayersGags[pPlayer][_ExpireTime] = SQL_ReadResult(query, res_UnbanTime);
			g_PlayersGags[pPlayer][_bitFlags]	= gag_flags_s:SQL_ReadResult(query, res_Flags);

			server_print("SQL_Handler()::LOAD_PLAYER(pPlayer=%i)", pPlayer);

			#if defined DEBUG
				DEBUG__Dump_GagData("SQL_Handler()::LOAD_PLAYER()", g_PlayersGags[pPlayer]);
			#endif
		}
		case SAVE_PLAYER: {
			new pPlayer = find_player_ex((FindPlayer_MatchUserId | FindPlayer_ExcludeBots), data[qd_UserID]);
			server_print("SQL_Handler()::SAVE_PLAYER(Player=%i)", pPlayer);
			DB_PlayerSaved(.pPlayer = pPlayer);
			}
		case REMOVE_BLOCK: {
			server_print("SQL_Handler()::REMOVE_BLOCK(UserID=#%i)", data[qd_UserID]);
		}
	}

	server_print("SQL_Handler() queuetime='%.5f'", queuetime);
}

// TODO!
DB_Inited()
{
	/* static bool: bInitState = false, dummy_ret;
	if(bInitState)
		ExecuteForward(g_fwd_Initialized, dummy_ret); */

	server_print("DB_Inited() [OK!] DATABASE INITIALIZED!!!!!");
}

public load_from_storage(sAuthId[], sIP[], aGagData[gag_s])
{
	new szQuery[QUERY_LENGTH * 2];
	formatex(szQuery, charsmax(szQuery), "SELECT unban_time, flags FROM %s WHERE ( \
		authid = '%s' OR ip = '%s') AND unban_time >= %i LIMIT 1",
	SQL_TBL_GAGS, sAuthId, sIP, aGagData[_AuthId], get_systime()
	);

	g_sqlData[qd_Query_state] = LOAD_PLAYER;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);
	SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public save_to_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	new szQuery[QUERY_LENGTH * 3];

// TODO!
	formatex(szQuery, charsmax(szQuery), "REPLACE INTO `%s` (	\
		name,authid,ip,reason,admin_name,admin_authid,			\
		admin_ip,create_time,unban_time,flags					\
	) VALUES('%s','%s','%s','%s','%s','%s','%s',%i,%i,%i)",		\
	SQL_TBL_GAGS,
		aGagData[_Name], aGagData[_AuthId], aGagData[_IP], aGagData[_Reason],
		aGagData[_AdminName], aGagData[_AdminAuthId], aGagData[_AdminIP],
		get_systime(), aGagData[_ExpireTime], aGagData[_bitFlags]
		);

	g_sqlData[qd_Query_state] = SAVE_PLAYER;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);
		SQL_ThreadQuery(g_hTuple, "SQL_Handler", szQuery, g_sqlData, sizeof(g_sqlData));
}

public remove_from_storage(szAuthId[], szIP[], aGagData[gag_s])
{
	new szQuery[QUERY_LENGTH * 3];

	formatex(szQuery, charsmax(szQuery), "DELETE FROM `%s` WHERE ( \
		authid = '%s' AND ip = '%s')",
			SQL_TBL_GAGS,
		aGagData[_AuthId], aGagData[_IP]
		);
	
	g_sqlData[qd_Query_state] = REMOVE_BLOCK;
	g_sqlData[qd_UserID] = get_user_userid(aGagData[_Player]);

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

