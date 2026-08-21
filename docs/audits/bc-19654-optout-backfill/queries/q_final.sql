WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
leads AS (SELECT DISTINCT _EB_WORKSPACE ws, LOWER(EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__LEADS WHERE EMAIL IS NOT NULL),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
be AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_EMAILS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
bd AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_DOMAIN) d FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_DOMAINS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
x AS (SELECT r.*,
        REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|opt[- ]?out).*$$,'is') strong,
        REGEXP_LIKE(b,$$.*unsubscribe.*$$,'is') unsub,
        LENGTH(TRIM(b)) blen,
        EXISTS(SELECT 1 FROM leads l WHERE l.ws=r.ws AND l.e=r.sender) is_our_lead,
        REGEXP_LIKE(r.sender,$$^(no-?reply|mail|info|hello|news|marketing|noreply)@$$||$$.*$$,'is') roleish
      FROM r
      WHERE NOT EXISTS(SELECT 1 FROM be WHERE be.ws=r.ws AND be.e=r.sender)
        AND NOT EXISTS(SELECT 1 FROM bd WHERE bd.ws=r.ws AND bd.d=r.sdom)),
agg AS (SELECT ws, sender, is_our_lead,
        BOOLOR_AGG(strong) strong, BOOLOR_AGG(unsub) unsub,
        MIN(IFF(strong OR unsub, blen, NULL)) min_hit_len
      FROM x WHERE strong OR unsub GROUP BY 1,2,3)
SELECT
  CASE WHEN strong THEN 'A. strong phrase'
       WHEN min_hit_len <= 250 THEN 'C1. short reply containing "unsubscribe"'
       ELSE 'C2. long body, "unsubscribe" in footer' END AS bucket,
  is_our_lead AS is_a_lead_we_mailed,
  COUNT(DISTINCT sender) senders
FROM agg GROUP BY 1,2 ORDER BY 1, 2 DESC
