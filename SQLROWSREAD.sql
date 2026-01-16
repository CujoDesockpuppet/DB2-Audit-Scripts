-- SQL Analysis - Heavy Read I/O SQL: SQLROWSREAD.SQL
-- Results best viewed with command Window 200 characters wide
-- Author: Scott.Hayes@DBIsoftware.com
-- Version: 1.0
-- Last Updated: 2014-03-13
-- Copyright 2014 DBI.  All Rights Reserved.
-- Licensed for use by paid IDUG 2014 Attendees and Authorized DBI Customers Only
--
--
SELECT CAST (A.NUM_EXECUTIONS AS INTEGER) AS NUM_EXECS,
       CAST( (A.ROWS_READ + 0.001) / (A.NUM_EXECUTIONS + 0.001)
             AS DECIMAL (13,4)) AS AVG_ROWS_READ,
       CAST((((A.ROWS_READ) * 100.0) 
        / (Select (SUM(B.ROWS_READ) + 1.0)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_ROWS_READ, 
       SUBSTR(A.STMT_TEXT,1,110) AS HEAVY_READER_SQL
FROM SYSIBMADM.SNAPDYN_SQL A
 WHERE A.ROWS_READ > 0 AND A.NUM_EXECUTIONS > 0
ORDER BY A.DBPARTITIONNUM ASC, 3 DESC, 2 DESC FETCH FIRST 25 ROWS ONLY;

