-- account unlock scripts
--
-- unlock the accounts.
alter user errors account unlock;
alter user utility account unlock;
-- reset the passwords for the account.
-- to unexpire the accounts.
alter user errors identified by &NewErrorsPassword;
alter user utility identified by &NewUtilityPassword;
-- now lets give back create session
grant 
	create session
to errors;
grant 
	create session
to utiltiy;