select substr(indname,1,21) indname, card, fullkeycard,i.lastused from syscat.tables t \
join syscat.indexes i on t.tabschema = i.tabschema and t.tabname = i.tabname where i.tabname \
in ('MSEG', 'VBEP') order by i.tabname,fullkeycard, card desc
