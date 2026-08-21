WITH our_dom AS (
  SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) AS d
  FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL
),
r AS (
  SELECT LOWER(FROM_EMAIL_ADDRESS) AS sender,
         COALESCE(TEXT_BODY,'') AS body_raw,
         REGEXP_REPLACE(COALESCE(TEXT_BODY,''),
           $$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,
           '', 1, 0, 'is') AS body_stripped
  FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
  WHERE FROM_EMAIL_ADDRESS IS NOT NULL
    AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)
)
SELECT
  COUNT(DISTINCT CASE WHEN REGEXP_LIKE(body_raw,      $$.*(unsubscribe|opt[- ]?out|remove (me|us)|take (me|us) off|do not (contact|email)|stop (emailing|sending)|please remove|no longer wish|distribution list).*$$, 'is') THEN sender END) AS senders_naive,
  COUNT(DISTINCT CASE WHEN REGEXP_LIKE(body_stripped, $$.*(unsubscribe|opt[- ]?out|remove (me|us)|take (me|us) off|do not (contact|email)|stop (emailing|sending)|please remove|no longer wish|distribution list).*$$, 'is') THEN sender END) AS senders_stripped,
  COUNT(DISTINCT sender) AS senders_all
FROM r
