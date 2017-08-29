-- create the error_log_tables.sql
--------------------------------------------------------
--  DDL for Table DEBUG
--------------------------------------------------------

  CREATE TABLE "error_log"."DEBUG" 
   (	"UNIT" VARCHAR2(35 CHAR) DEFAULT '*', 
	"USERNAME" VARCHAR2(128 CHAR) DEFAULT '*'
   ) SEGMENT CREATION IMMEDIATE 
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  STORAGE(INITIAL 40960 NEXT 40960 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE &error_log_data_tablespace;
--------------------------------------------------------
--  Constraints for Table DEBUG
--------------------------------------------------------

  ALTER TABLE "error_log"."DEBUG" MODIFY ("UNIT" NOT NULL ENABLE);
  ALTER TABLE "error_log"."DEBUG" MODIFY ("USERNAME" NOT NULL ENABLE);

