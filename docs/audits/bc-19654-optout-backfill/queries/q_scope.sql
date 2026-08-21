WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
be AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_EMAILS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
bd AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_DOMAIN) d FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_DOMAINS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
x AS (SELECT r.*, LENGTH(TRIM(b)) blen,
        REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|opt[- ]?out).*$$,'is') strong,
        REGEXP_LIKE(b,$$.*unsubscribe.*$$,'is') unsub,
        REGEXP_LIKE(b,$$.*(remove us|take us off|our (company|organization|team|hotel|property|business)|we are not|we do not|from your list.*(we|our)|everyone (here|at)|all (of )?our staff|company.wide).*$$,'is') company_scope
      FROM r
      WHERE NOT EXISTS(SELECT 1 FROM be WHERE be.ws=r.ws AND be.e=r.sender)
        AND NOT EXISTS(SELECT 1 FROM bd WHERE bd.ws=r.ws AND bd.d=r.sdom)),
q AS (SELECT ws,sender,sdom, BOOLOR_AGG(strong) strong, BOOLOR_AGG(unsub) unsub,
        BOOLOR_AGG(company_scope) cscope, MIN(IFF(strong OR unsub,blen,NULL)) mhl
      FROM x WHERE strong OR unsub GROUP BY 1,2,3)
SELECT
  IFF(cscope,'company-wide language ("remove us", "our team")','individual only ("remove me")') AS request_scope,
  COUNT(DISTINCT sender) senders,
  COUNT(DISTINCT sdom) distinct_domains
FROM q WHERE strong OR (unsub AND mhl<=250)
GROUP BY 1 ORDER BY 2 DESC
;
--SPLIT--
WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom, LOWER(FROM_EMAIL_ADDRESS) sender,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
optout AS (SELECT DISTINCT ws, sdom FROM r WHERE REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish).*$$,'is')),
allleads AS (SELECT _EB_WORKSPACE ws, SPLIT_PART(LOWER(EMAIL),'@',2) sdom, COUNT(DISTINCT LOWER(EMAIL)) n
             FROM ANALYTICS.STAGING.STG_EMAILBISON__LEADS WHERE EMAIL IS NOT NULL GROUP BY 1,2)
SELECT SUM(a.n) AS mailable_addresses_at_optout_domains, COUNT(*) AS domains
FROM optout o JOIN allleads a ON a.ws=o.ws AND a.sdom=o.sdom
