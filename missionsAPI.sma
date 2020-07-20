#include <amxmodx>
#include <amxmisc>
#include <mg_missions_api_const>
#include <mg_regsystem_api>
#include <sqlx>

#define PLUGIN "[*MG*] Missions API"
#define VERSION "1.0.0"
#define AUTHOR "Vieni"

new gMissionStatus[33][MISSIONID_BLOCKSIZE]
new gMissionValue[33][MISSIONID_BLOCKSIZE]

new Array:arrayMissionId
new Array:arrayMissionName
new Array:arrayMissionDesc
new Array:arrayMissionRequired
new Array:arrayMissionNext
new Array:arrayMissionTargetValue
new Array:arrayMissionPrizeExp
new Array:arrayMissionPrizeMP

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
}

public plugin_natives()
{
    gSqlMissionTuple = SQL_MakeDbTuple("127.0.0.1", "MG_User", "fKj4zbI0wxwPoFzU", "account_informations")

    arrayMissionId = ArrayCreate(1)
    arrayMissionName = ArrayCreate(64)
    arrayMissionDesc = ArrayCreate(64)
    arrayMissionRequired = ArrayCreate(1)
    arrayMissionNext = ArrayCreate(1)
    arrayMissionTargetValue = ArrayCreate(1)
    arrayMissionPrizeExp = ArrayCreate(1)
    arrayMissionPrizeMP = ArrayCreate(1)

    serverLoadMissionList()
}

public sqlLoadMissionListHandle(FailState, Handle:Query, error[], errorcode, data[], datasize, Float:fQueueTime)
{
	if(FailState == TQUERY_CONNECT_FAILED || FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("%s", error)
        pause("d")
		return
	}

    new lMissionName[64], lMissionDesc[64]

    while(SQL_MoreResults(Query))
    {
        if(SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "missionActive")))
        {
            SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "missionName"), lMissionName, charsmax(lMissionName))
            SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "missionDesc"), lMissionDesc, charsmax(lMissionDesc))

            ArrayPushCell(arrayMissionId, SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "missionId")))
            ArrayPushString(arrayMissionName, lMissionName)
            ArrayPushString(arrayMissionDesc, lMissionDesc)
            ArrayPushCell(arrayMissionRequired, SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "missionRequired")))
            ArrayPushCell(arrayMissionNext, SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "missionNext")))
            ArrayPushCell(arrayMissionTargetValue, SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "targetValue")))
            ArrayPushCell(arrayMissionPrizeExp, SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "prizeExp")))
            ArrayPushCell(arrayMissionPrizeMP, SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "prizeMPoints")))
        }

        SQL_NextRow(Query)
    }
}

public sqlLoadMissionStatusHandle(FailState, Handle:Query, error[], errorcode, data[], datasize, Float:fQueueTime)
{
    new id = data[0]
    new accountId = data[1]

	if(FailState == TQUERY_CONNECT_FAILED || FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("%s", error)
		mg_reg_user_sqlload_finished(id, MG_SQLID_MISSIONS)
		return
	}

    if(!SQL_NumResults(Query))
    {
        userAddMissionStatus(id, accountId)
        return
    }


}

public sqlLoadMissionStatusHandle(FailState, Handle:Query, error[], errorcode, data[], datasize, Float:fQueueTime)
{
    new id = data[0]
    new accountId = data[1]

    if(FailState == TQUERY_CONNECT_FAILED || FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("%s^n accountId = ^"%d^"", error, accountId)
		mg_reg_user_sqlload_finished(id, MG_SQLID_MISSIONS)
		return
	}
}

public mg_fw_client_login_process(id, accountId)
{
    userLoadMissionStatus(id, accountId)

    mg_reg_user_sqlload_start(id, MG_SQLID_MISSIONS)
    return PLUGIN_HANDLED
}

serverLoadMissionList()
{
	new lSqlTxt[250]

	formatex(lSqlTxt, charsmax(lSqlTxt), "SELECT * FROM missionList;", accountId)
	SQL_ThreadQuery(gSqlMissionTuple, "sqlLoadMissionListHandle", lSqlTxt)
	
	return
}

userLoadMissionStatus(id, accountId)
{
	if(!is_user_connected(id))
		return false
	
	new lSqlTxt[250], data[2]
	
	data[0] = id
    data[1] = accountId
	
	formatex(lSqlTxt, charsmax(lSqlTxt), "SELECT * FROM accountStatus WHERE accountId=^"%s^";", accountId)
	SQL_ThreadQuery(gSqlMissionTuple, "sqlLoadMissionStatusHandle", lSqlTxt, data, 2)
	
	return true
}

userAddMissionStatus(id, acountId)
{
	if(!is_user_connected(id))
		return false
	
	new lSqlTxt[250], data[2]
	
	data[0] = id
    data[1] = accountId
	
	formatex(lSqlTxt, charsmax(lSqlTxt), "INSERT INTO accountStatus (accountId) VALUE (^"%d^");", accountId)
	SQL_ThreadQuery(gSqlMissionTuple, "sqlAddMissionStatusHandle", lSqlTxt, data, 2)
	
	return true
}