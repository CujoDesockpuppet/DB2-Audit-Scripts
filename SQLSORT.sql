-- SQL Analysis - Heavy SORT SQL: SQLSORT.SQL
-- Results best viewed with command Window 200 characters wide
-- Author: Scott.Hayes@DBIsoftware.com
-- Version: 1.0
-- Last Updated: 2014-03-14
-- Copyright 2014 DBI.  All Rights Reserved.
-- Licensed for use by paid IDUG 2014 Attendees and Authorized DBI Customers Only
--
SELECT CAST (A.NUM_EXECUTIONS AS INTEGER) AS NUM_EXECS,
       CAST( (A.TOTAL_SORT_TIME + 0.0000) / (A.NUM_EXECUTIONS + 0.0001)
             AS DECIMAL (13,4)) AS AVG_SORT_MS,
       CAST((((A.TOTAL_SORT_TIME) * 100.0) 
        / (Select (SUM(B.TOTAL_SORT_TIME) + 1.0)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_SORT_TIME, 
       SUBSTR(A.STMT_TEXT,1,110) AS HEAVY_SORT_SQL
FROM SYSIBMADM.SNAPDYN_SQL A
 WHERE A.TOTAL_SORT_TIME > 0 AND A.NUM_EXECUTIONS > 0
ORDER BY A.DBPARTITIONNUM ASC, 3 DESC, 2 DESC FETCH FIRST 10 ROWS ONLY;

