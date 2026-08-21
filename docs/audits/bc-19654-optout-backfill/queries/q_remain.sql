WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        COALESCE(IS_AUTOMATED_REPLY,FALSE) auto,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
x AS (SELECT r.*, LENGTH(TRIM(b)) blen,
        REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|opt[- ]?out).*$$,'is') strong,
        REGEXP_LIKE(b,$$.*unsubscribe.*$$,'is') unsub FROM r)
SELECT ws, sender, sdom,
  BOOLAND_AGG(auto) all_auto,
  BOOLOR_AGG(REGEXP_LIKE(b,$$.*(out of (the )?office|currently closed|in observance of|automatic reply|no longer with|if you (do not|don.t) wish to receive).*$$,'is')) ooo_or_corpfooter,
  MAX(REGEXP_REPLACE(SUBSTR(TRIM(b),1,120),$$\s+$$,' ',1,0)) samp_txt
FROM x WHERE strong OR unsub GROUP BY 1,2,3
HAVING BOOLOR_AGG(strong) OR MIN(IFF(unsub,blen,NULL))<=250
