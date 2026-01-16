#!/bin/bash
echo 'Policy       Obj Type  Sub Obj Type   Schema     Object Name'
echo "------       --------  ------------   ------     -----------"
db2 -x "SELECT substr(AUDITPOLICYNAME,1,12), OBJECTTYPE, SUBOBJECTTYPE, substr(OBJECTSCHEMA,1, 10),substr(OBJECTNAME,1,20) FROM SYSCAT.AUDITUSE order by AUDITPOLICYNAME, OBJECTTYPE, SUBOBJECTTYPE, OBJECTSCHEMA, OBJECTNAME"
