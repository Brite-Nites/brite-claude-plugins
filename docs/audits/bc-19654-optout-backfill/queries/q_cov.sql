WITH our_dom AS (
  SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) AS d
  FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL
),
r AS (
  SELECT _EB_WORKSPACE AS ws, LOWER(FROM_EMAIL_ADDRESS) AS sender,
         SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) AS sdom,
         COALESCE(TEXT_BODY,'') AS body_raw,
         REGEXP_REPLACE(COALESCE(TEXT_BODY,''),
           $$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$, '', 1, 0, 'is') AS body_str
  FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
  WHERE FROM_EMAIL_ADDRESS IS NOT NULL
    AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)
),
hits AS (
  SELECT DISTINCT ws, sender, sdom,
    MAX(CASE WHEN REGEXP_LIKE(body_raw, $$.*(unsubscribe|opt[- ]?out|remove (me|us)|take (me|us) off|do not (contact|email)|stop (emailing|sending)|please remove|no longer wish|distribution list).*$$,'is') THEN 1 ELSE 0 END) OVER (PARTITION BY ws,sender) AS naive_hit,
    MAX(CASE WHEN REGEXP_LIKE(body_str, $$.*(unsubscribe|opt[- ]?out|remove (me|us)|take (me|us) off|do not (contact|email)|stop (emailing|sending)|please remove|no longer wish|distribution list).*$$,'is') THEN 1 ELSE 0 END) OVER (PARTITION BY ws,sender) AS strip_hit
  FROM r
),
be AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_EMAILS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
bd AS (SELECT _EB_WORKSPACE ws, LOWER(BLACKLISTED_DOMAIN) d FROM ANALYTICS.STAGING.STG_EMAILBISON__BLACKLISTED_DOMAINS WHERE NOT COALESCE(IS_DELETED_IN_SOURCE,FALSE)),
cov AS (
  SELECT h.*,
    IFF(EXISTS(SELECT 1 FROM be WHERE be.ws=h.ws AND be.e=h.sender),1,0) AS by_email_same_ws,
    IFF(EXISTS(SELECT 1 FROM bd WHERE bd.ws=h.ws AND bd.d=h.sdom),1,0)   AS by_domain_same_ws,
    IFF(EXISTS(SELECT 1 FROM be WHERE be.e=h.sender),1,0)                AS by_email_any_ws
  FROM hits h
)
SELECT
  COUNT(DISTINCT IFF(naive_hit=1, sender, NULL)) AS naive_senders,
  COUNT(DISTINCT IFF(naive_hit=1 AND by_email_any_ws=0 AND by_domain_same_ws=0, sender, NULL)) AS naive_uncovered_anyws,
  COUNT(DISTINCT IFF(naive_hit=1 AND by_email_same_ws=0 AND by_domain_same_ws=0, sender, NULL)) AS naive_uncovered_samews,
  COUNT(DISTINCT IFF(strip_hit=1, sender, NULL)) AS strip_senders,
  COUNT(DISTINCT IFF(strip_hit=1 AND by_email_same_ws=0 AND by_domain_same_ws=0, sender, NULL)) AS strip_uncovered_samews
FROM cov
