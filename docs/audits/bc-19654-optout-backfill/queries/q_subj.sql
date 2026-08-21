WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom, DATE_RECEIVED,
        COALESCE(SUBJECT,'') subj,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
p AS (SELECT $$.*(unsubscribe|opt[- ]?out|remove (me|us|my|from)|take (me|us) off|delete (me|us|my)|do not (contact|email)|stop (emailing|sending|contacting)|please remove|no longer wish|distribution list|get (me|us) off).*$$ pat)
SELECT ws, sender, sdom, DATE_RECEIVED::date dt, subj,
       REGEXP_REPLACE(SUBSTR(TRIM(b),1,90),$$\s+$$,' ',1,0) body_start
FROM r, p
WHERE REGEXP_LIKE(subj, pat, 'is') AND NOT REGEXP_LIKE(b, pat, 'is')
ORDER BY dt DESC
