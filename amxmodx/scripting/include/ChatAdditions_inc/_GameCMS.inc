#if defined _CA_API_MySQL_included
    #endinput
#endif

#define _CA_API_MySQL_included

#include <sqlx>
#include <gamecms5>


// Configure your connect to MySQL Server
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

// GameCMS related
new g_iServerId;


public plugin_cfg() {
    init_storage();
}

static init_storage() {
    g_fStartInitTime = get_gametime();
}

public OnAPIPluginLoaded(Handle: sqlTuple) {
    g_hTuple = sqlTuple;
    g_iServerId = cmsapi_get_server_id();

    SQL_SetCharset(g_hSqlHandle, "utf8");

    Storage_Inited(get_gametime() - g_fStartInitTime);
}

public destroy_storage() {

}


public load_from_storage(const aGagData[gag_s]) {
	/*  formatex(szQuery, charsmax(szQuery), "SELECT * FROM `%s` WHERE `server_id` = '%d' AND `authid` = '%s'\
    AND ((`expired` > UNIX_TIMESTAMP(NOW()) OR `expired` = '0' ) AND `length` != '-1' AND `expired` != '-1') LIMIT 1;",
    sqlTable, g_iServerId, szAuthid); */
}

public save_to_storage(const aGagData[gag_s]) {
	new szQuery[QUERY_LENGTH * 3];
    
/*     "INSERT INTO `%s` (bid, authId, name, created, expired, length, reason, admin_id, admin_nick, server_id, modified_by, type) \
    values ('%d', '%s', '%s', '%d', '%d', '%d', '%s', '%d', '%s', '%d', '%s', '%d');",
    sqlTable, plBlockInfo[id][GBid], plBlockInfo[id][GAuthId], plBlockInfo[id][GName], plBlockInfo[id][GCreated], 
    plBlockInfo[id][GExpired], plBlockInfo[id][GBlockTime], plBlockInfo[id][GBlockReason], 
    plBlockInfo[id][GAdminId], plBlockInfo[id][GAdminNick], g_iServerId, plBlockInfo[id][GModifiedBy], plBlockInfo[id][GBlockType]); */
}

public remove_from_storage(const aGagData[gag_s]) {
/* 	formatex(szQuery, charsmax(szQuery), "UPDATE `%s` SET expired='%d', modified_by='%s' WHERE `bid` = '%d';",
                    sqlTable, plBlockInfo[id][GExpired], plBlockInfo[id][GModifiedBy], plBlockInfo[id][GBid]); */
}
