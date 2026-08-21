WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
be AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_EMAILS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
bd AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_DOMAIN) d FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_DOMAINS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
x AS (SELECT r.*, LENGTH(TRIM(b)) blen,
        REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|opt[- ]?out).*$$,'is') strong,
        REGEXP_LIKE(b,$$.*unsubscribe.*$$,'is') unsub
      FROM r WHERE NOT EXISTS(SELECT 1 FROM be WHERE be.ws=r.ws AND be.e=r.sender)
              AND NOT EXISTS(SELECT 1 FROM bd WHERE bd.ws=r.ws AND bd.d=r.sdom)),
act AS (SELECT ws,sender,sdom, MAX(b) b FROM x WHERE strong OR unsub
        GROUP BY 1,2,3 HAVING BOOLOR_AGG(strong) OR MIN(IFF(unsub,blen,NULL))<=250),
al AS (SELECT _EB_WORKSPACE ws, SPLIT_PART(LOWER(EMAIL),'@',2) sdom, COUNT(DISTINCT LOWER(EMAIL)) n
       FROM ANALYTICS.STAGING.STG_EMAILBISON__LEADS WHERE EMAIL IS NOT NULL GROUP BY 1,2),
scoped AS (SELECT a.*, COALESCE(al.n,0) dom_n,
    REGEXP_LIKE(a.b,$$.*(remove us|take us off|remove (the |our )?(company|organization|organisation|hotel|property|business|team|firm|school|district|club)|our (company|organization|organisation|team|staff|hotel|property|business|employees)|from (your|the) (email )?(distribution|mailing) list.{0,40}(we|our|us)|anyone (here|at)|all (of )?our|everyone (here|at)|company.?wide|we (are not|do not|don.t|aren.t)).*$$,'is') org_lang
  FROM act a LEFT JOIN al ON al.ws=a.ws AND al.sdom=a.sdom)
SELECT ws, sender, dom_n AS addrs_at_domain,
       REGEXP_REPLACE(SUBSTR(TRIM(b),1,230),$$\s+$$,' ',1,0) AS reply_text
FROM scoped WHERE org_lang ORDER BY dom_n DESC, sender
