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
act AS (SELECT ws,sender,sdom,MAX(b) b FROM x WHERE strong OR unsub GROUP BY 1,2,3
        HAVING BOOLOR_AGG(strong) OR MIN(IFF(unsub,blen,NULL))<=250)
SELECT * FROM (
  SELECT sender, sdom,
    CASE WHEN REGEXP_LIKE(sdom,$$.*\.(ca|co\.uk|uk|de|fr|au|nz|ie|eu|es|it|nl|be|ch|at|se|no|dk|fi|pt|mx|br|jp|in|za|sg)$$,'i') THEN 'ccTLD'
         WHEN REGEXP_LIKE(b,$$.*\b(Ontario|Quebec|Alberta|Manitoba|Saskatchewan|Nova Scotia|New Brunswick|British Columbia|Toronto|Vancouver|Montreal|Calgary|Edmonton|Winnipeg|Halifax)\b.*$$,'is') THEN 'CA place'
         WHEN REGEXP_LIKE(b,$$.*\+(44|61|64|353|49|33|34|39|31|32|41|43|46|47|45|351|52|55|81|91|27|65|971)[ 0-9()\-]{6,}.*$$,'is') THEN 'intl phone'
         WHEN REGEXP_LIKE(b,$$.*\b[A-Z][0-9][A-Z] ?[0-9][A-Z][0-9]\b.*$$,'cs') THEN 'CA postal (noisy)'
         ELSE NULL END AS flag
  FROM act) WHERE flag IS NOT NULL ORDER BY flag, sender
