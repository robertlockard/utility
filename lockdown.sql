-- this is the lockdown of the utility schema
-- to be done after maintaniance is complete.

alter user error_log account lock;
-- we might as well expire the accounts too
-- because we have a 90 day expire policy.
alter user error_log account expire;

-- then we take away create session.
revoke create session from error_log;
