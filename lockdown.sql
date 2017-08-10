-- this is the lockdown of the utility schema
-- to be done after maintaniance is complete.

alter user utility account lock;
alter user errors account lock;
-- we might as well expire the accounts too
-- because we have a 90 day expire policy.
alter user utility account expire;
alter user errors account expire;
-- then we take away create session.
revoke create session from utility;
revoke create session from errors;