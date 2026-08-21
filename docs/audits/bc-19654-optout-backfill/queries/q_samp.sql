WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        COALESCE(IS_AUTOMATED_REPLY,FALSE) auto,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
be AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_EMAILS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
bd AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_DOMAIN) d FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_DOMAINS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
x AS (SELECT r.*,
        REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|opt[- ]?out).*$$,'is') strong,
        REGEXP_LIKE(b,$$.*unsubscribe.*$$,'is') unsub
      FROM r
      WHERE NOT EXISTS(SELECT 1 FROM be WHERE be.ws=r.ws AND be.e=r.sender)
        AND NOT EXISTS(SELECT 1 FROM bd WHERE bd.ws=r.ws AND bd.d=r.sdom)),
a AS (SELECT 'A-strong' bucket, sender, auto, REGEXP_REPLACE(SUBSTR(TRIM(b),1,180),$$\s+$$,' ',1,0) snip,
        ROW_NUMBER() OVER (PARTITION BY sender ORDER BY LENGTH(b)) rn2,
        DENSE_RANK() OVER (ORDER BY sender) rk FROM x WHERE strong),
c AS (SELECT 'C-unsub-only' bucket, sender, auto, REGEXP_REPLACE(SUBSTR(TRIM(b),1,180),$$\s+$$,' ',1,0) snip,
        ROW_NUMBER() OVER (PARTITION BY sender ORDER BY LENGTH(b)) rn2,
        DENSE_RANK() OVER (ORDER BY sender) rk FROM x WHERE unsub AND NOT strong)
SELECT bucket, sender, auto, snip FROM a WHERE rn2=1 AND rk%18=1
UNION ALL
SELECT bucket, sender, auto, snip FROM c WHERE rn2=1 AND rk%10=1
ORDER BY 1,2
