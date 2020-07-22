#include <amxmodx>
#include <amxmisc>
#include <mg_core>
#include <mg_missions_api_const>
#include <mg_regsystem_api>
#include <sqlx>

#define PLUGIN "[*MG*] Missions API"
#define VERSION "1.0.0"
#define AUTHOR "Vieni"

new gMissionPoints[33]
new gMissionStatus[33][MISSIONID_BLOCKSIZE]
new gMissionValue[33][MISSIONID_BLOCKSIZE]

new Array:arrayMissionId
new Array:arrayMissionServer
new Array:arrayMissionName
new Array:arrayMissionDesc
new Array:arrayMissionRequired
new Array:arrayMissionNext
new Array:arrayMissionTargetValue
new Array:arrayMissionPrizeExp
new Array:arrayMissionPrizeMP

new gForwardClientMissionDone, gForwardClientMissionAvailable

new retValue

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    gForwardClientMissionDone = CreateMultiForward("mg_fw_client_mission_done", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL)// id, missionId, missionPrizeExp
    gForwardClientMissionAvailable = CreateMultiForward("mg_fw_client_mission_unlocked", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL)// id, missionId, unlockerMissionId

    serverLoadMissionList()
}

public plugin_natives()
{
    gSqlMissionTuple = SQL_MakeDbTuple("127.0.0.1", "MG_User", "fKj4zbI0wxwPoFzU", "account_informations")

    arrayMissionId = ArrayCreate(1)
    arrayMissionServer = ArrayCreate(1)
    arrayMissionName = ArrayCreate(64)
    arrayMissionDesc = ArrayCreate(64)
    arrayMissionRequired = ArrayCreate(1)
    arrayMissionNext = ArrayCreate(1)
    arrayMissionTargetValue = ArrayCreate(1)
    arrayMissionPrizeExp = ArrayCreate(1)
    arrayMissionPrizeMP = ArrayCreate(1)

    register_native("mg_missions_arrayid_get", "native_arrayid_get")

    register_native("mg_missions_client_mpoint_set", "native_client_mpoint_set")
    register_native("mg_missions_client_mpoint_get", "native_client_mpoint_get")
    register_native("mg_missions_client_mpoint_add", "native_client_mpoint_add")

    register_native("mg_missions_client_status_set", "native_client_status_set")
    register_native("mg_missions_client_status_get", "native_client_status_get")

    register_native("mg_missions_client_value_set", "native_client_value_set")
    register_native("mg_missions_client_value_get", "native_client_value_get")
    register_native("mg_missions_client_value_add", "native_client_value_add")
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
            ArrayPushCell(arrayMissionServer, SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "missionServer")))
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

    new lArraySize = ArraySize(arrayMissionId)
    new lMissionId
    new lUserMStatusName[32]
    new lUserMValueName[32]

    for(new i; i < lArraySize; i++)
    {
        lMissionId = ArrayGetCell(arrayMissionId, i)

        lUserMStatusName[0] = EOS
        lUserMValueName[0] = EOS

        formatex(lUserMStatusName, charsmax(lUserMStatusName), "mission%dDone", lMissionId)
        formatex(lUserMValueName, charsmax(lUserMValueName), "mission%dValue", lMissionId)

        gMissionStatus[id][lMissionId] = SQL_ReadResult(Query, SQL_FieldNameToNum(Query, lUserMStatusName))
        gMissionValue[id][lMissionId] = SQL_ReadResult(Query, SQL_FieldNameToNum(Query, lUserMValueName))
    }

    mg_reg_user_sqlload_finished(id, MG_SQLID_MISSIONS)
}

public sqlAddMissionStatusHandle(FailState, Handle:Query, error[], errorcode, data[], datasize, Float:fQueueTime)
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

public sqlUpdateClientMissonsHandle(FailState, Handle:Query, error[], errorcode, data[], datasize, Float:fQueueTime)
{
    if(FailState == TQUERY_CONNECT_FAILED || FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("%s", error)
	}
}

public native_arrayid_get(plugin_id, param_num)
{
    if(get_param(1) != -1)
        set_param_byref(1, int:arrayMissionId)
    
    if(get_param(2) != -1)
        set_param_byref(2, int:arrayMissionServer)

    if(get_param(3) != -1)
        set_param_byref(3, int:arrayMissionName)
        
    if(get_param(4) != -1)
        set_param_byref(4, int:arrayMissionDesc)
        
    if(get_param(5) != -1)
        set_param_byref(5, int:arrayMissionRequired)
        
    if(get_param(6) != -1)
        set_param_byref(6, int:arrayMissionNext)
        
    if(get_param(7) != -1)
        set_param_byref(7, int:arrayMissionTargetValue)
        
    if(get_param(8) != -1)
        set_param_byref(8, int:arrayMissionPrizeExp)
        
    if(get_param(9) != -1)
        set_param_byref(9, int:arrayMissionPrizeMP)
}

public native_client_mpoint_set(plugin_id, param_num)
{
    new id = get_param(1)

    if(!mg_reg_user_loggedin(id))
        return false

    new lMissionPoints = get_param(2)

    gMissionPoints[id] = lMissionPoints

    return true
}

public native_client_mpoint_get(plugin_id, param_num)
{
    new id = get_param(1)

    if(!mg_reg_user_loggedin(id))
        return 0

    return gMissionPoints[id]
}

public native_client_mpoint_add(plugin_id, param_num)
{
    new id = get_param(1)
    
    if(!mg_reg_user_loggedin(id))
        return 0

    new lMissionPoints = get_param(2)

    gMissionPoints[id] += lMissionPoints
    
    return gMissionPoints[id]
}

public native_client_status_set(plugin_id, param_num)
{
    new id = get_param(1)

    if(!mg_reg_user_loggedin(id))
        return false

    new lMissionId = get_param(2)
    new lArrayId = ArrayFindValue(arrayMissionId, lMissionId)

    if(lArrayId == -1)
        return false
    
    new lMissionServer = ArrayGetCell(arrayMissionServer, lArrayId)

    if(isMissionServerInvalid(lMissionServer))
        return false

    new lStatus = get_param(3)

    gMissionStatus[id][lMissionId] = lStatus
    
    return true
}

public native_client_status_get(plugin_id, param_num)
{
    new id = get_param(1)

    if(!mg_reg_user_loggedin(id))
        return false

    new lMissionId = get_param(2)

    return gMissionStatus[id][lMissionId]
}

public native_client_value_set(plugin_id, param_num)
{
    new id = get_param(1)

    if(!mg_reg_user_loggedin(id))
        return false

    new lMissionId = get_param(2)
    new lArrayId = ArrayFindValue(arrayMissionId, lMissionId)

    if(lArrayId == -1)
        return false

     new lMissionServer = ArrayGetCell(arrayMissionServer, lArrayId)

    if(isMissionServerInvalid(lMissionServer))
        return false

    new lMissionValue = get_param(3)

    gMissionValue[id][lMissionId] = lMissionValue

    return true
}

public native_client_value_get(plugin_id, param_num)
{
    new id = get_param(1)

    if(!mg_reg_user_loggedin(id))
        return false

    new lMissionId = get_param(2)

    return gMissionValue[id][lMissionId]
}

public native_client_value_add(plugin_id, param_num)
{
    new id = get_param(1)

    if(!mg_reg_user_loggedin(id))
        return false

    new lMissionId = get_param(2)
    new lArrayId = ArrayFindValue(arrayMissionId, lMissionId)

    if(lArrayId == -1)
        return false

    new lMissionServer = ArrayGetCell(arrayMissionServer, lArrayId)

    if(isMissionServerInvalid(lMissionServer))
        return false
    
    new lMissionValue = get_param(3)

    gMissionValue[id][lMissionId] += lMissionValue

    return gMissionValue[id][lMissionId]
}

public mg_fw_client_login_process(id, accountId)
{
    userLoadMissionStatus(id, accountId)

    mg_reg_user_sqlload_start(id, MG_SQLID_MISSIONS)
    return PLUGIN_HANDLED
}

public mg_fw_client_sql_save(id, accountId)
{
    new lSqlTxt[1024], len
    new lArraySize = ArraySize(arrayMissionId)
    new lMissionId

    len += formatex(lSqlTxt[len], charsmax(lSqlTxt) - len, "UPDATE missionList SET")
    len += formatex(lSqlTxt[len], charsmax(lSqlTxt) - len, "accountMP = ^"%d^"", gMissionPoints[id])
    for(new i; i < lArraySize; i++)
    {
        lMissionId = ArrayGetCell(arrayMissionId, i)

        len += formatex(lSqlTxt[len], charsmax(lSqlTxt) - len, ", mission%dDone = ^"%d^"", lMissionId, gMissionStatus[id][lMissionId])
        len += formatex(lSqlTxt[len], charsmax(lSqlTxt) - len, ", mission%dValue = ^"%d^"", lMissionId, gMissionValue[id][lMissionId])
    }
    len += formatex(lSqlTxt[len], charsmax(lSqlTxt) - len, ";")
    SQL_ThreadQuery(gSqlMissionTuple, "sqlUpdateClientMissonsHandle", lSqlTxt)
}

public mg_fw_client_clean(id)
{
    for(new i; i < MISSIONID_BLOCKSIZE; i++)
    {
        gMissionPoints[id][i] = 0
        gMissionStatus[id][i] = 0
        gMissionValue[id][i] = 0
    }
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

userCheckMissionStatus(id, missionId)
{
    if(!mg_reg_user_loggedin(id))
        return

    if(gMissionStatus[id][missionId])
        return
    
    new lArrayId = ArrayFindValue(arrayMissionId, missionId)

    if(lArrayId == -1)
        return
    
    if(gMissionValue[id][missionId] >= ArrayGetCell(arrayMissionTargetValue, lArrayId))
    {
        gMissionStatus[id][missionId] = 1
        ExecuteForward(gForwardClientMissionDone, retValue, id, missionId, ArrayGetCell(arrayMissionPrizeExp, lArrayId))
        gMissionValue[id][ArrayGetCell(arrayMissionNext, lArrayId)] += gMissionValue[id][missionId]
        checkLockedMissions(id, missionId, lArrayId)
    }
}

checkLockedMissions(id, missionId, arrayId) // Basically called when a mission has been done
{
    if(!mg_reg_user_loggedin(id))
        return
    
    new lArraySize = ArraySize(arrayMissionId)

    for(new i; i < lArraySize; i++)
    {
        if(ArrayGetCell(arrayMissionRequired, arrayId) == missionId)
            ExecuteForward(gForwardClientMissionAvailable, retValue, id, ArrayGetCell(arrayMissionId, i), missionId)
    }
}

isMissionServerInvalid(missionServer)
{
    if(lMissionServer != MG_SERVER_GLOBAL && lMissionServer != MG_SERVER_CURRENT)
        return true
    
    return false
}