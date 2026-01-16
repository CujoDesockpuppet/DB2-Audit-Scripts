-- This CLP file was created using DB2LOOK Version "12.1" 
-- Timestamp: Wed Jul  9 22:04:06 WAUST 2025
-- Database Name: CAI            
-- Database Manager Version: DB2/AIX64 Version 12.1.0      
-- Database Codepage: 1208
-- Database Collating Sequence is: IDENTITY_16BIT
-- Alternate collating sequence(alt_collate): null
-- varchar2 compatibility(varchar2_compat): OFF


CONNECT TO CAI;

------------------------------------------------
-- DDL Statements for Table "AUDIT   "."ARCHIVELOGGING"
------------------------------------------------
 

CREATE TABLE "AUDIT   "."ARCHIVELOGGING"  (
		  "LOG_ID" INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (  
		    START WITH +1  
		    INCREMENT BY +1  
		    MINVALUE +1  
		    MAXVALUE +2147483647  
		    NO CYCLE  
		    CACHE 20  
		    NO ORDER ) , 
		  "LOG_DATE" TIMESTAMP NOT NULL , 
		  "ARCHIVE_FILE" VARCHAR(255 OCTETS) NOT NULL , 
		  "CHECKSUM" CHAR(64 OCTETS) , 
		  "ARCHIVED_BY" VARCHAR(64 OCTETS) )   
		 IN "CAI#BTABD"  
		 ORGANIZE BY ROW; 

COMMENT ON TABLE "AUDIT   "."ARCHIVELOGGING" IS 'Records details of DB2 audit files archived by audsweep.sh';

COMMENT ON COLUMN "AUDIT   "."ARCHIVELOGGING"."ARCHIVED_BY" IS 'User who executed the archiving script.';

COMMENT ON COLUMN "AUDIT   "."ARCHIVELOGGING"."ARCHIVE_FILE" IS 'Full path to the archived audit file.';

COMMENT ON COLUMN "AUDIT   "."ARCHIVELOGGING"."CHECKSUM" IS 'SHA256 checksum of the archived file for integrity verification.';

COMMENT ON COLUMN "AUDIT   "."ARCHIVELOGGING"."LOG_DATE" IS 'Timestamp when the audit file was archived.';


-- DDL Statements for Primary Key on Table "AUDIT   "."ARCHIVELOGGING"

ALTER TABLE "AUDIT   "."ARCHIVELOGGING" 
	ADD PRIMARY KEY
		("LOG_ID")
	ENFORCED;



ALTER TABLE "AUDIT   "."ARCHIVELOGGING" ALTER COLUMN "LOG_ID" RESTART WITH 61;







COMMIT WORK;

CONNECT RESET;

TERMINATE;

