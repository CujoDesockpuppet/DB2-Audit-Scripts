#!/bin/bash
echo "################################################################################################################"
echo "#                           DB2 AUDIT SETTINGS - AUDIT POLICY CAPSCHEMA                                        #"
echo "################################################################################################################"

db2 "SELECT 'AUDITPOLICYNAME' AS Policy, \
CAST(AUDITPOLICYNAME AS VARCHAR(18)) AS Value \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'AUDITSTATUS' AS Policy, CAST(AUDITSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'CONTEXTSTATUS' AS Policy, CAST(CONTEXTSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'VALIDATESTATUS' AS Policy, CAST(VALIDATESTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'CHECKINGSTATUS' AS Policy, CAST(CHECKINGSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'SECMAINTSTATUS' AS Policy, CAST(SECMAINTSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'OBJMAINTSTATUS' AS Policy, CAST(OBJMAINTSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'SYSADMINSTATUS' AS Policy, CAST(SYSADMINSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'EXECUTESTATUS' AS Policy, CAST(EXECUTESTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA' \
UNION ALL \
SELECT 'EXECUTEWITHDATA' AS Policy, CAST(EXECUTEWITHDATA AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'CAPSCHEMA'"
echo "################################################################################################################"
echo "#                           DB2 AUDIT SETTINGS - AUDIT POLICY ADMINSPOLICY                                     #"
echo "################################################################################################################"
db2 "SELECT 'AUDITPOLICYNAME' AS Policy, \
CAST(AUDITPOLICYNAME AS VARCHAR(18)) AS Value \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'AUDITSTATUS' AS Policy, CAST(AUDITSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'CONTEXTSTATUS' AS Policy, CAST(CONTEXTSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'VALIDATESTATUS' AS Policy, CAST(VALIDATESTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'CHECKINGSTATUS' AS Policy, CAST(CHECKINGSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'SECMAINTSTATUS' AS Policy, CAST(SECMAINTSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'OBJMAINTSTATUS' AS Policy, CAST(OBJMAINTSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'SYSADMINSTATUS' AS Policy, CAST(SYSADMINSTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'EXECUTESTATUS' AS Policy, CAST(EXECUTESTATUS AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY' \
UNION ALL \
SELECT 'EXECUTEWITHDATA' AS Policy, CAST(EXECUTEWITHDATA AS VARCHAR(18)) AS VALUE \
FROM SYSCAT.AUDITPOLICIES WHERE AUDITPOLICYNAME = 'ADMINSPOLICY'"
echo "################################################################################################################"
echo "#                           DB2 AUDIT SETTINGS OBJECT TYPES AUDITED                                            #"
echo "################################################################################################################"
echo 'Policy       Obj Type  Sub Obj Type   Schema     Object Name'
echo "------       --------  ------------   ------     -----------"
db2 -x "SELECT substr(AUDITPOLICYNAME,1,12), OBJECTTYPE, SUBOBJECTTYPE, substr(OBJECTSCHEMA,1, 10),substr(OBJECTNAME,1,20) FROM SYSCAT.AUDITUSE order by AUDITPOLICYNAME, OBJECTTYPE, SUBOBJECTTYPE, OBJECTSCHEMA, OBJECTNAME"
echo "################################################################################################################"
echo "#                           DB2 AUDIT SETTINGS AUDIT EXCEPTIONS LISTING                                        #"
echo "################################################################################################################"
db2 'select substr(OBJECTNAME,1,8), substr(EXOBJECTNAME,1,20), substr(CREATE_TIME,1,19) from syscat.AUDITEXCEPTIONS'
echo "################################################################################################################"
echo "#                           DB2 AUDIT SETTINGS AUDIT ATTRIBUTES LISTING                                        #"
echo "################################################################################################################"
db2 "select substr(a.CONTEXTNAME,1,20) as CONTEXTNAME, substr(a.ATTR_NAME,1,20) as ATTR_NAME, substr(a.ATTR_VALUE,1,30) as ATTR_VALUE from syscat.contextattributes a where a.contextname <> 'SYSATSCONTEXT'"
echo "################################################################################################################"
echo "#                           DB2 AUDIT SETTINGS AUDIT CONTEXT WORK PROCESS LISTING                              #"
echo "################################################################################################################"
db2 "select substr(application_handle,1,20) as apl_handle, substr(application_name,1,20) as apl_name, substr(application_id,1,35) as application_id, substr(client_pid,1,10) as client_pid, substr(client_wrkstnname, 1, 20) as client_wrkstnname, substr(system_auth_id, 1, 8) as system_auth_idm, substr(trusted_ctx_name,1, 20) as trusted_ctx_name from table (mon_get_connection(null, null)) as t"
echo "################################################################################################################"
echo "#                          AUDIT SCHEMA TABLES                                                                 #"
echo "################################################################################################################"
db2 "list tables for schema audit"
echo "################################################################################################################"
echo "#                           DB2 AUDIT SETTINGS                                                                 #"
echo "################################################################################################################"
db2audit describe
