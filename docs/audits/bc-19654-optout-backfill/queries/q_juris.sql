WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
be AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_EMAILS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
x AS (SELECT r.*, LENGTH(TRIM(b)) blen,
        REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|opt[- ]?out).*$$,'is') strong,
        REGEXP_LIKE(b,$$.*unsubscribe.*$$,'is') unsub
      FROM r WHERE NOT EXISTS(SELECT 1 FROM be WHERE be.ws=r.ws AND be.e=r.sender)),
act AS (SELECT ws,sender,sdom FROM x WHERE strong OR unsub GROUP BY 1,2,3
        HAVING BOOLOR_AGG(strong) OR MIN(IFF(unsub,blen,NULL))<=250),
tld AS (SELECT a.*, SPLIT_PART(sdom,'.',-1) AS tld,
          REGEXP_LIKE(sdom,$$.*\.(ca|co\.uk|uk|de|fr|au|nz|ie|eu|es|it|nl|be|ch|at|se|no|dk|fi|pt|pl|mx|br|jp|cn|in|za|sg|hk|ae)$$,'i') AS nonus_tld
        FROM act a)
SELECT nonus_tld AS non_us_cctld, COUNT(*) senders FROM tld GROUP BY 1
;
--SPLIT--
WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
be AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_EMAILS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
x AS (SELECT r.*, LENGTH(TRIM(b)) blen,
        REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|opt[- ]?out).*$$,'is') strong,
        REGEXP_LIKE(b,$$.*unsubscribe.*$$,'is') unsub
      FROM r WHERE NOT EXISTS(SELECT 1 FROM be WHERE be.ws=r.ws AND be.e=r.sender)),
act AS (SELECT ws,sender,sdom FROM x WHERE strong OR unsub GROUP BY 1,2,3
        HAVING BOOLOR_AGG(strong) OR MIN(IFF(unsub,blen,NULL))<=250),
cv AS (SELECT a.sender, a.sdom,
         MAX(IFF(LOWER(c.value:name::string)='state', c.value:value::string, NULL)) st,
         MAX(IFF(LOWER(c.value:name::string)='city', c.value:value::string, NULL)) city,
         MAX(IFF(LOWER(c.value:name::string) IN ('company address','address'), c.value:value::string, NULL)) addr,
         MAX(IFF(LOWER(c.value:name::string)='company phone', c.value:value::string, NULL)) phone
       FROM act a JOIN ANALYTICS.STAGING.STG_EMAILBISON__LEADS l
         ON l._EB_WORKSPACE=a.ws AND LOWER(l.EMAIL)=a.sender,
       LATERAL FLATTEN(input=>l.CUSTOM_VARIABLES) c GROUP BY 1,2)
SELECT sender, sdom, st, city, addr, phone FROM cv
WHERE (phone IS NOT NULL AND NOT REGEXP_LIKE(phone,$$^\+?1?[ (\-]*[0-9]{3}[) \-]*[0-9]{3}[ \-]*[0-9]{4}.*$$))
   OR (addr IS NOT NULL AND NOT REGEXP_LIKE(addr,$$.*\b[A-Z]{2}\b[ ,]*[0-9]{5}.*$$))
ORDER BY 1 LIMIT 30
