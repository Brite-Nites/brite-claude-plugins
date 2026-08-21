WITH our_dom AS (
  SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) AS d
  FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
r AS (
  SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender,
         SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
         COALESCE(IS_AUTOMATED_REPLY,FALSE) auto,
         REGEXP_REPLACE(COALESCE(TEXT_BODY,''),
           $$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
  FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
  WHERE FROM_EMAIL_ADDRESS IS NOT NULL
    AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
be AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_EMAILS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
bd AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_DOMAIN) d FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_DOMAINS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
m AS (
  SELECT ws, sender, sdom,
    BOOLOR_AGG(REGEXP_LIKE(b,$$.*(remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|opt[- ]?out).*$$,'is')) AS strong,
    BOOLOR_AGG(REGEXP_LIKE(b,$$.*unsubscribe.*$$,'is')) AS has_unsub,
    BOOLOR_AGG(REGEXP_LIKE(b,$$.*distribution list.*$$,'is')) AS has_distlist,
    BOOLOR_AGG(NOT auto) AS any_human
  FROM r GROUP BY 1,2,3),
u AS (
  SELECT m.* FROM m
  WHERE NOT EXISTS(SELECT 1 FROM be WHERE be.ws=m.ws AND be.e=m.sender)
    AND NOT EXISTS(SELECT 1 FROM bd WHERE bd.ws=m.ws AND bd.d=m.sdom)
    AND (strong OR has_unsub OR has_distlist))
SELECT
  CASE WHEN strong THEN 'A. strong phrase (remove me / please remove / opt out / do not contact)'
       WHEN has_distlist THEN 'B. distribution list only'
       ELSE 'C. the word "unsubscribe" only' END AS bucket,
  any_human AS has_a_human_reply,
  COUNT(DISTINCT sender) AS senders
FROM u GROUP BY 1,2 ORDER BY 1,2 DESC
