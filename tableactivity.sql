rchar(m.tabschema,17) as tabschema, \
varchar(m.tabname,24) as tabname, rows_read, \
integer(rows_inserted) rows_inserted, integer(rows_updated) rows_updated, \
integer(rows_deleted) rows_deleted, integer(npages) npages, integer(card) card \
from table(Mon_GET_TABLE('','',-2)) as m  \
join syscat.tables t on m.tabschema = t.tabschema and m.tabname = t.tabname \
where t.tabname in ('MSEG', 'VBEP') order by rows_inserted desc \
fetch first 50 rows only 
