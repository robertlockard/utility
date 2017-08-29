--------------------------------------------------------
--  DDL for Package LOG_STACK
--------------------------------------------------------

CREATE OR REPLACE EDITIONABLE PACKAGE "error_log"."LOG_STACK" 
authid definer AS

  function create_entry(pUnit  VARCHAR2 default null,
					   pLine  number default null,
					   pStime timestamp default current_timestamp,
					   pEtime timestamp default null,
					   pParms clob      default null) return number;

	procedure end_entry(pLogID number,
						pEtime timestamp default current_timestamp,
						pResults in clob default null);
end;
/

--------------------------------------------------------
--  DDL for Package Body LOG_STACK
--------------------------------------------------------

CREATE OR REPLACE EDITIONABLE PACKAGE BODY "error_log"."LOG_STACK" AS
 
	-- this checks to see if we are dubugging. If we are 
	-- then we can start logging.
	function debug(pUnit varchar2,
				   pUser varchar2) return number IS
	x number; -- just a dumb variable
	begin
		-- check to see if we are debugging for a unit or a user.
		select count(*)
		into x
		from error_log.debug
		where (unit = pUnit or unit = '*')
		  and (username = pUser or username = '*');

		-- test to see if anything was returned.
		return x;
	end;

	-- create a log entry.
	function create_entry(pUnit  VARCHAR2 default null,
					   pLine  number default null,
					   pStime timestamp default current_timestamp,
					   pEtime timestamp default null,
					   pParms clob      default null) return number IS
	PRAGMA AUTONOMOUS_TRANSACTION;

	iId number; -- temp holder of the primary key

	begin
    -- check to see if debugging is turned on
    if error_log.log_stack.debug(pUnit => pUnit, pUser => user) > 0 then
      -- if so, insert a row.
      -- grab the next id for the primary key.
      select errors.log_stack_seq.nextval into iId from dual;

      insert into error_log.app_log values (iId,
        			pUnit,
          			pLine,
            		user,
              		pStime,
                	null, 	-- we dont have the end time yet.
                  	pParms,
                    null);	-- we will wait for the results
      -- this is an atonomus transaction, so a commit is safe.
      commit;
      return iID;
    else
      return 0;
    end if;
	exception when others then
		rollback;					-- execute a rollback to be safe.
		return sqlcode * -1;		-- return the error code and flip the sign so we know if it's an error.
	end;

	procedure end_entry(pLogID number,
						pEtime timestamp default current_timestamp,
						pResults in clob default null) is
	PRAGMA AUTONOMOUS_TRANSACTION;
	BEGIN
		-- check to see if we are logging. if pLogId = 0 then logging did not 
		-- start.
		if pLogId != 0 then
			update errors.app_log set etime = pEtime, results = pResults 
			where id = pLogId;
			commit;
		end if;
	END end_entry;

end;
/

--------------------------------------------------------
--  DDL for Package GENERIC_PKG
--------------------------------------------------------

CREATE OR REPLACE EDITIONABLE PACKAGE "error_log"."GENERIC_PKG" 
AUTHID DEFINER
as
  FUNCTION fgetinstance RETURN VARCHAR2;
  -- the function fReserved has some issues, I would no depend
  -- on this. oneday, comeback and revisit.
  FUNCTION fReserved(pString IN VARCHAR2) RETURN BOOLEAN;
  PROCEDURE pDebugYN(pUnit IN VARCHAR2 DEFAULT NULL,
					 pUser IN VARCHAR2 DEFAULT NULL,
					 pOn   IN VARCHAR2 DEFAULT 'Y');
END generic_pkg;
/
--------------------------------------------------------
--  DDL for Package Body GENERIC_PKG
--------------------------------------------------------

CREATE OR REPLACE EDITIONABLE PACKAGE BODY "error_log"."GENERIC_PKG" as


	function fgetinstance return varchar2 as
	sInstanceName VARCHAR2(16);
	iLog INTEGER;
	begin
	SELECT INSTANCE_NAME
		INTO sInstanceName
		FROM SYS.V_$INSTANCE;
	RETURN sInstanceName;
	EXCEPTION WHEN OTHERS THEN
		error_log.errorstack_pkg.pMain(pErrorId => iLog);
	RETURN null;
	END fgetinstance;

	FUNCTION fReserved(pString IN VARCHAR2) RETURN boolean IS
	iCnt INTEGER;
	BEGIN
	SELECT count(*)
	INTO icnt
	FROM sys.v_$reserved_words
	WHERE instr(' ' || upper(pString) || ' ', ' ' || keyword || ' ') > 0;
	IF iCnt > 0 THEN
	  RETURN TRUE;
	ELSE 
	  RETURN FALSE;
	END IF;
	END fReserved;
	-- Turn debugging on and off. First off check to see if 
	-- pUnit or pUser is not null. One or both off these need
	-- to be populated.
	PROCEDURE pDebugYN(pUnit IN VARCHAR2 DEFAULT NULL,
					 pUser IN VARCHAR2 DEFAULT NULL,
					 pOn   IN VARCHAR2 DEFAULT 'Y') IS
	BEGIN
		/* TODO - fill in the logic. */
		NULL;
	END;
  
END generic_pkg;
/

--------------------------------------------------------
--  DDL for Package ERRORSTACK_PKG
--------------------------------------------------------

CREATE OR REPLACE EDITIONABLE PACKAGE "error_log"."ERRORSTACK_PKG" 
AUTHID DEFINER
AS
	PROCEDURE pMain(pErrorId 	OUT INTEGER);
END errorstack_pkg;
/

--------------------------------------------------------
--  DDL for Package Body ERRORSTACK_PKG
--------------------------------------------------------

CREATE OR REPLACE EDITIONABLE PACKAGE BODY "error_log"."ERRORSTACK_PKG" AS

	-- this procedure will get the stack values for each call in the stack.
	-- we are not exposing this to the specification because it will only
	-- be used interal to this package. Because of this, we are forward
	-- defining it.
	PROCEDURE pCallStackValues(pDepth 			IN 		INTEGER,
								pOwner 				OUT VARCHAR2,
								pLexical_depth		OUT INTEGER,
								pUnit_Line			OUT INTEGER,
								pSubProgram			OUT VARCHAR2,
								pError_Number		OUT INTEGER,
								pError_Msg		    OUT VARCHAR2) IS

	BEGIN
		-- get the values from the stack that we are going to be 
		-- putting into error_log.error_lines.
		pOwner 			    := sys.utl_call_stack.owner(pDepth);
		pLexical_Depth		:= sys.utl_call_stack.lexical_depth(pDepth);
		pUnit_Line		  	:= sys.utl_call_stack.unit_line(pDepth);
		pSubProgram		    := sys.utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(pDepth));
		BEGIN
			pError_Number	  	:= sys.utl_call_stack.error_number(pDepth);
			pError_Msg		  	:= sys.utl_call_stack.error_msg(pDepth);
			-- This exception is to be expected when there are no errors.
		EXCEPTION WHEN OTHERS THEN
			pError_Number := 0;
			pError_Msg := NULL;
		END;
	--
	END pCallStackValues;

	-- pass in the error number, this will gather the details of
	-- the error stack. Lets think about this, do we really need
	-- the ErrorId at this point?
	PROCEDURE pCallStackMain(pErrorId IN INTEGER) IS

		iLineId				INTEGER;	    -- the error_line pk.
		sOwner 				VARCHAR2(128);  -- populated by pCallStackValues
		iLexical_Depth		INTEGER;        -- populated by pCallStackValues
		iUnit_Line			INTEGER;        -- populated by pCallStackValues
		sSubProgram			VARCHAR2(256);  -- populated by pCallStackValues
		iError_Number		INTEGER;        -- populated by pCallStackValues
		sError_Msg			VARCHAR2(256);  -- populated by pCallStackValues
	BEGIN
		FOR i IN REVERSE 1 .. utl_call_stack.dynamic_depth()
		LOOP
			pCallStackValues(pDepth			=> i,
							 pOwner			        => sOwner,
							 pLexical_Depth	    => iLexical_Depth,
							 pUnit_Line		      => iUnit_Line,
							 pSubProgram	      => sSubProgram,
							 pError_Number	    => iError_Number,
							 pError_Msg	        => sError_Msg);
			-- get the next sequence number.
			SELECT errors.error_lines_seq.nextval
			INTO iLineId
			FROM dual;
			-- insert the line into error_log.error_lines.
			INSERT INTO errors.error_lines VALUES (
					iLineId,		-- primary key
					pErrorId,		-- fk to error_log.errors.
					i,				-- dynamic_depth
					sOwner,			-- pl/sql unit owner
					sSubProgram,  	-- pl/sql unit and sub program 1st value.
					iError_Number,	-- error number
					sError_Msg,		-- error message
					iUnit_Line		-- pl/sql line number
					);
		END LOOP;
		COMMIT;
	END pCallStackMain;

	-- the main calling procedure for the error stack package.
	PROCEDURE pMain (pErrorId OUT INTEGER)IS
	PRAGMA AUTONOMOUS_TRANSACTION;
	iErrorId 	INTEGER;		-- errors.errors pk.
	BEGIN
		-- get the next sequence for errors.
		SELECT errors.errors_seq.nextval
		INTO pErrorId
		FROM dual;
		-- create the base error in error_log.errors table.
		INSERT INTO errors.errors VALUES (pErrorId, -- error_log.errors pk
							sys_context('userenv', 'session_user'),
							sys_context('userenv', 'ip_address'),
							current_timestamp
							);
		-- populate the error_lines table using pCallStackMain.
		pCallStackMain(pErrorId => pErrorId);
		-- commit the transaction sense this is an AUTONOMOUS TRANSACTION
		-- we are not worried about the commit having side effects.
		COMMIT;
		-- return the error id.
		-- this is done through the OUT parameter pErrorId. so 
		-- there is not going to be a formal RETURN.
	END pMain;
END errorstack_pkg;
/