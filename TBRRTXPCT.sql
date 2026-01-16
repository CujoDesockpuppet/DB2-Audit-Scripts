-- Tables performance analysis: TBRRTXPCT.SQL
-- For OLTP, when TBRRTX > 10, likely opportunity for improvement
--           when TBRRTX > 100, definitely opportunity for improvement
--           when TBRRTX > 1000, CRISIS
-- For DW, use TBRRTX to Focus your tuning attention
-- 
-- Results best viewed with command Window ** 200 characters wide **
-- Author: Scott.Hayes@DBIsoftware.com
-- Version: 3.0
-- Last Updated: 2014-03-06
-- Copyright 2014 DBI.  All Rights Reserved.
-- Licensed for use by IDUG 2014 Attendees and DBI Authorized Customers Only
--

select substr(a.tabschema,1,20) as TABSCHEMA, 
       substr(a.tabname,1,25) as TABNAME,
       a.rows_read as RowsRead,
       CAST((((A.ROWS_READ) * 100.0) 
        / (Select (SUM(Z.ROWS_READ) + 1.0)
             FROM SYSIBMADM.SNAPTAB Z 
            WHERE A.DBPARTITIONNUM = Z.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_DB_TB_ROWSREAD,
       CAST( (a.rows_read / (b.commit_sql_stmts + b.rollback_sql_stmts + 1.0)) 
         AS DECIMAL(13,3)) as TBRRTX
  from SYSIBMADM.snaptab a, 
       SYSIBMADM.snapdb b
where a.dbpartitionnum = b.dbpartitionnum
order by a.rows_read desc fetch first 20 rows only;