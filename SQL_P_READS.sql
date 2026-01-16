-- SQL Analysis - Heavy Physcial Reads SQL: SQL_P_READS.SQL
-- Only looks at Bufferpool Data and Index Physical Reads
-- Could be enhanced to include TEMP & XDA Physical Reads if appropriate
-- TRY SORTING BY PCT_IX_P_READS (5) DESC to find heavy IX Access
-- TRY SORTING BY PCT_PREADS (3) DESC to find heavy total L Read Access
-- Results best viewed with command Window 200 characters wide
-- Author: Scott.Hayes@DBIsoftware.com
-- Version: 1.0
-- Last Updated: 2014-03-13
-- Copyright 2014 DBI.  All Rights Reserved.
-- Licensed for use by paid IDUG 2014 Attendees and Authorized DBI Customers Only
--
SELECT CAST (A.NUM_EXECUTIONS AS INTEGER) AS NUMEXECS,
       CAST( (A.POOL_DATA_P_READS + A.POOL_INDEX_P_READS + 0.001) / (A.NUM_EXECUTIONS + 0.001)
             AS DECIMAL (13,4)) AS AV_P_READS,
       CAST((((A.POOL_DATA_P_READS + A.POOL_INDEX_P_READS) * 100.0) 
        / (Select (SUM(B.POOL_DATA_P_READS) + SUM(B.POOL_INDEX_P_READS) + 0.01)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_PREADS, 
       CAST( (A.POOL_INDEX_P_READS + 0.001) / (A.NUM_EXECUTIONS + 0.001)
             AS DECIMAL (13,4)) AS AV_IX_PREADS,
       CAST((((A.POOL_INDEX_P_READS) * 100.0) 
        / (Select (SUM(B.POOL_INDEX_P_READS) + 0.01)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_IX_P_READS, 
       CAST( (A.POOL_DATA_P_READS + 0.001) / (A.NUM_EXECUTIONS + 0.001)
             AS DECIMAL (13,4)) AS AV_DT_PREADS,
       CAST((((A.POOL_DATA_P_READS) * 100.0) 
        / (Select (SUM(B.POOL_DATA_P_READS) + 0.01)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_DT_PREADS, 
       SUBSTR(A.STMT_TEXT,1,110) AS HEAVY_P_READ_SQL
FROM SYSIBMADM.SNAPDYN_SQL A
 WHERE A.NUM_EXECUTIONS > 0 
   AND ( (A.POOL_DATA_P_READS > 0) OR (A.POOL_INDEX_P_READS > 0) )
ORDER BY A.DBPARTITIONNUM ASC, 5 DESC, 4 DESC FETCH FIRST 25 ROWS ONLY;

