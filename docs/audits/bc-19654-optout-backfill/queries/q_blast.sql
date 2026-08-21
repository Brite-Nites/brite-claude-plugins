WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
freemail AS (SELECT column1 AS d FROM VALUES ('gmail.com'),('yahoo.com'),('hotmail.com'),('outlook.com'),('aol.com'),('icloud.com'),('comcast.net'),('me.com'),('msn.com'),('live.com'),('sbcglobal.net'),('att.net'),('verizon.net'),('bellsouth.net'),('cox.net'),('mac.com'),('ymail.com'),('protonmail.com')),
r AS (SELECT _EB_WORKSPACE ws, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
optout AS (SELECT DISTINCT ws, sdom FROM r
           WHERE REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish).*$$,'is')
             AND sdom NOT IN (SELECT d FROM freemail)),
al AS (SELECT _EB_WORKSPACE ws, SPLIT_PART(LOWER(EMAIL),'@',2) sdom, COUNT(DISTINCT LOWER(EMAIL)) n
       FROM ANALYTICS.STAGING.STG_EMAILBISON__LEADS WHERE EMAIL IS NOT NULL GROUP BY 1,2),
j AS (SELECT o.sdom, a.n FROM optout o JOIN al a ON a.ws=o.ws AND a.sdom=o.sdom)
SELECT COUNT(*) AS domains, SUM(n) AS total_addresses_at_those_domains,
       MEDIAN(n) AS median_per_domain, MAX(n) AS max_per_domain,
       SUM(IFF(n=1,1,0)) AS domains_with_1_addr,
       SUM(IFF(n BETWEEN 2 AND 5,1,0)) AS domains_2_to_5,
       SUM(IFF(n>5,1,0)) AS domains_over_5
FROM j
;
--SPLIT--
WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
freemail AS (SELECT column1 AS d FROM VALUES ('gmail.com'),('yahoo.com'),('hotmail.com'),('outlook.com'),('aol.com'),('icloud.com')),
r AS (SELECT _EB_WORKSPACE ws, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL),
optout AS (SELECT DISTINCT ws, sdom FROM r
           WHERE REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish).*$$,'is')
             AND sdom NOT IN (SELECT d FROM freemail) AND sdom NOT IN (SELECT d FROM our_dom)),
al AS (SELECT _EB_WORKSPACE ws, SPLIT_PART(LOWER(EMAIL),'@',2) sdom, COUNT(DISTINCT LOWER(EMAIL)) n
       FROM ANALYTICS.STAGING.STG_EMAILBISON__LEADS WHERE EMAIL IS NOT NULL GROUP BY 1,2)
SELECT o.sdom, a.n AS addresses_at_domain FROM optout o JOIN al a ON a.ws=o.ws AND a.sdom=o.sdom
ORDER BY a.n DESC LIMIT 10
