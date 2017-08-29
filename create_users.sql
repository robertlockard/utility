-- create users and privileges

create user ERROR_LOG identified by x;
create role error_log_admin_role identified by x;

-- in order to build the required objects,
-- the user needs create procedure and create table.
grant 
	create procedure, 
	create table 
to error_log_admin_role;

-- by default we are granting create session to error_log.
-- once we are done, we are going to lock and expire the
-- account with a lock script. the only time anyone should
-- be connecting to the error_log schema, is to do maintenance
-- on the schema.
grant 
	create session, 
	error_log_admin_role 
to error_log;

-- the packages depend on these objects. to get
-- the packages to compile, we need to grant the
-- schema access to the objects.
grant 
	execute on sys.utl_call_stack,
	select on SYS.V_$INSTANCE,
	select on sys.v_$reserved_words
to error_log;

-- the sys_select_role is going to be granted to 
-- the packages. it needs access to the following 
-- views to work.
create role sys_select_role;
grant 
	select on SYS.V_$INSTANCE,
	select on sys.v_$reserved_words
to sys_select_role;

-- we are granting with the delegate option so
-- the error_log schema can grant the the role
-- to the packages.
grant 
	sys_select_role
to error_log with delegate option;

-- the error_log user should not have anyone
-- privileges when connecting. the error_log
-- user is required to set the error_log_admin_role
-- with a password to do any maintenance.
alter user error_log default role none;