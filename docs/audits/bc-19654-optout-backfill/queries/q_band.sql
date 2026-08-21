WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
fm AS (SELECT column1 d FROM VALUES ('gmail.com'),('yahoo.com'),('hotmail.com'),('outlook.com'),('aol.com'),('icloud.com'),('comcast.net'),('me.com'),('msn.com'),('live.com'),('sbcglobal.net'),('att.net'),('verizon.net'),('bellsouth.net'),('cox.net'),('mac.com'),('ymail.com'),('protonmail.com')),
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
act AS (SELECT ws,sender,sdom FROM x WHERE strong OR unsub
        GROUP BY 1,2,3 HAVING BOOLOR_AGG(strong) OR MIN(IFF(unsub,blen,NULL))<=250),
al AS (SELECT _EB_WORKSPACE ws, SPLIT_PART(LOWER(EMAIL),'@',2) sdom, COUNT(DISTINCT LOWER(EMAIL)) n
       FROM ANALYTICS.STAGING.STG_EMAILBISON__LEADS WHERE EMAIL IS NOT NULL GROUP BY 1,2),
tagged AS (SELECT a.ws, a.sender, a.sdom, COALESCE(al.n,0) dom_n,
             CASE WHEN a.sdom IN (SELECT d FROM fm) THEN 'free-mail'
                  WHEN COALESCE(al.n,0)<=2 THEN 'a. 1-2'  WHEN COALESCE(al.n,0)<=5 THEN 'b. 3-5'
                  WHEN COALESCE(al.n,0)<=10 THEN 'c. 6-10' WHEN COALESCE(al.n,0)<=25 THEN 'd. 11-25'
                  WHEN COALESCE(al.n,0)<=100 THEN 'e. 26-100' ELSE 'f. 100+' END band
           FROM act a LEFT JOIN al ON al.ws=a.ws AND al.sdom=a.sdom),
perdom AS (SELECT DISTINCT band, ws, sdom, dom_n FROM tagged)
SELECT t.band,
       (SELECT COUNT(DISTINCT sender) FROM tagged t2 WHERE t2.band=t.band) AS senders,
       COUNT(DISTINCT t.sdom) AS domains,
       SUM(t.dom_n) AS addrs_suppressed_if_domain_blocked
FROM perdom t GROUP BY t.band ORDER BY t.band
