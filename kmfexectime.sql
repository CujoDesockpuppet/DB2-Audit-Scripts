-- SQL Analysis - SQL with Execution Times: SQLEXECTIME.SQL
-- Results best viewed with command Window 200 characters wide
-- Author: Scott.Hayes@DBIsoftware.com
-- Version: 3.0
-- Last Updated: 2014-03-11
-- Copyright 2014 DBI.  All Rights Reserved.
-- Licensed for use by paid IDUG 2014 Attendees and Authorized DBI Customers Only
--
--
SELECT CAST( (A.TOTAL_EXEC_TIME + 0.001) / (A.NUM_EXECUTIONS + 0.001)
             AS DECIMAL (13,4)) AS AVGEXECTIME,
       CAST (A.NUM_EXECUTIONS AS INTEGER) AS NUM_EXECS,
       CAST((((A.TOTAL_EXEC_TIME) * 100.0) 
        / (Select (SUM(B.TOTAL_EXEC_TIME) + 1.0)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_EXEC_TIME, 
       SUBSTR(A.STMT_TEXT,1,120) AS SLOW_POKE_SQL
FROM SYSIBMADM.SNAPDYN_SQL A
 WHERE A.TOTAL_EXEC_TIME > 0
   AND A.NUM_EXECUTIONS > 0
ORDER BY A.DBPARTITIONNUM ASC, 3 DESC, 1 DESC FETCH FIRST 25 ROWS ONLY;

