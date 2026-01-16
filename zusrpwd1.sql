-- This CLP file was created using DB2LOOK Version "12.1" 
-- Timestamp: Fri Jun 20 19:11:53 WAUST 2025
-- Database Name: CAI            
-- Database Manager Version: DB2/AIX64 Version 12.1.0      
-- Database Codepage: 1208
-- Database Collating Sequence is: IDENTITY_16BIT
-- Alternate collating sequence(alt_collate): null
-- varchar2 compatibility(varchar2_compat): OFF


CONNECT TO CAI;

------------------------------------------------
-- DDL Statements for Table "SAPCAP  "."ZUSRPWD1"
------------------------------------------------
 

CREATE TABLE "SAPCAP  "."ZUSRPWD1"  (
		  "BNAME" VARCHAR(36 OCTETS) NOT NULL WITH DEFAULT ' ' )   
		 COMPRESS YES ADAPTIVE  
		 IN "CAI#USER1D" INDEX IN "CAI#USER1I"  
		 ORGANIZE BY ROW; 


-- DDL Statements for Indexes on Table "SAPCAP  "."ZUSRPWD1"

SET SYSIBM.NLS_STRING_UNITS = 'SYSTEM';

CREATE UNIQUE INDEX "SAPCAP  "."ZUSRPWD1~0" ON "SAPCAP  "."ZUSRPWD1" 
		("BNAME" ASC)
		PCTFREE 0 
		COMPRESS YES 
		INCLUDE NULL KEYS ALLOW REVERSE SCANS;
-- DDL Statements for Primary Key on Table "SAPCAP  "."ZUSRPWD1"

ALTER TABLE "SAPCAP  "."ZUSRPWD1" 
	ADD CONSTRAINT "ZUSRPWD1~0" PRIMARY KEY
		("BNAME")
	ENFORCED;










COMMIT WORK;

CONNECT RESET;

TERMINATE;

