-- SQL Analysis - SQL with Execution Times: SQLCPUTIME.SQL
-- Results best viewed with command Window 200 characters wide
-- Author: Scott.Hayes@DBIsoftware.com
-- Version: 1.0
-- Last Updated: 2014-03-12
-- Copyright 2014 DBI.  All Rights Reserved.
-- Licensed for use by paid IDUG 2014 Attendees and Authorized DBI Customers Only
SELECT 
       CAST( ( 
               ( (A.TOTAL_USR_CPU_TIME * 1000000) + A.TOTAL_USR_CPU_TIME_MS
               + (A.TOTAL_SYS_CPU_TIME * 1000000) + A.TOTAL_SYS_CPU_TIME_MS 
               )
           / A.NUM_EXECUTIONS ) 
             AS DECIMAL (15,0)) AS AVG_CPU_TIME_MS,
       CAST (A.NUM_EXECUTIONS AS INTEGER) AS NUM_EXECS,
       CAST(((
              ((A.TOTAL_USR_CPU_TIME * 1000000) + A.TOTAL_USR_CPU_TIME_MS
              + (A.TOTAL_SYS_CPU_TIME * 1000000) + A.TOTAL_SYS_CPU_TIME_MS) 
             * 100.0) 
        / (Select (SUM(B.TOTAL_USR_CPU_TIME) * 1000000) 
                + (SUM(B.TOTAL_SYS_CPU_TIME) * 1000000)
                + SUM(B.TOTAL_USR_CPU_TIME_MS) 
                + SUM(B.TOTAL_SYS_CPU_TIME_MS) + 1.0
  FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_CPU_TIME,
       SUBSTR(A.STMT_TEXT,1,510) AS CPU_SUCKING_SQL
FROM SYSIBMADM.SNAPDYN_SQL A
 WHERE A.NUM_EXECUTIONS > 0
ORDER BY A.DBPARTITIONNUM ASC, 3 DESC, 1 DESC FETCH FIRST 25 ROWS ONLY;

