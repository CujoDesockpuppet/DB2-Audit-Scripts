-- ANALYZE Indexes for Low IXCARD on High Write Tables: IXLOWCARDV3.SQL
-- INDEXES must be HIGH QUALITY on Top 10 Write I/O Tables
-- Results best viewed with command Window ** 200 characters wide **
-- Author: Scott.Hayes@DBIsoftware.com
-- Version: 3.0
-- Last Updated: 2014-03-14
-- Copyright 2014 DBI.  All Rights Reserved.
-- Licensed for use by paid IDUG Attendees and DBI Authorized Customers Only
--
-- For the top 10 most highly written to tables, indentify the indexes having very low cardinality
-- compared to the table cardinality.

select substr(a.tabschema,1,8) as schema,
       substr(a.tabname,1,20) as table,
       substr(a.indschema,1,8) as indschema, 
       substr(a.indname,1,20) as index,
       a.fullkeycard as IXFULLKEYCARD,
       b.card as TBCARD,
       int((float(a.fullkeycard)/float(b.card)) * 100) as ratio,
       a.lastused as LAST_USED
from SYSCAT.INDEXES A inner join SYSCAT.TABLES B
       on A.tabschema = B.tabschema
       and A.tabname = B.tabname
where A.fullkeycard > 0
--     and A.tabschema <> 'SYSIBM'
     and B.card > 100 and A.uniquerule <> 'U'
     and int((float(a.fullkeycard)/float(b.card)) * 100) < 5
     and A.tabname in
        (SELECT C.TABNAME FROM sysibmadm.snaptab C 
          order by C.ROWS_WRITTEN DESC fetch first 10 ROWS ONLY)
    order by 7 ASC;
