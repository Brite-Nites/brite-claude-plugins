WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
leads AS (SELECT DISTINCT _EB_WORKSPACE ws, LOWER(EMAIL) e FROM ANALYTICS.STAGING.STG_EMAILBISON__LEADS WHERE EMAIL IS NOT NULL AND OVERALL_EMAILS_SENT>0),
r AS (SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, DATE_RECEIVED,
        COALESCE(IS_AUTOMATED_REPLY,FALSE) auto, COALESCE(IS_READ,FALSE) rd,
        REGEXP_REPLACE(COALESCE(TEXT_BODY,''),$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
      WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
c AS (SELECT r.*, EXISTS(SELECT 1 FROM leads l WHERE l.ws=r.ws AND l.e=r.sender) is_lead,
   REGEXP_LIKE(b,$$.*(unsubscribe|remove (me|us)|take (me|us) off|please remove|do not (contact|email)|stop (emailing|sending)|no longer wish|distribution list|opt[- ]?out).*$$,'is') optout,
   REGEXP_LIKE(b,$$.*(out of (the )?office|currently closed|automatic reply|auto.?reply|i am away|on vacation|no longer with|is retired|delivery has failed|undeliverable|couldn.t be delivered|mailer-daemon|thank you for (contacting|reaching out to) us|will be answered|received your (message|email)).*$$,'is') ooo,
   REGEXP_LIKE(b,$$.*(not interested|no thank|no thanks|we.re all set|already have|not a (hotel|venue|fit)|doesn.t apply|does not apply|we handle|in-house|internally).*$$,'is') declines,
   LENGTH(TRIM(b)) blen FROM r)
SELECT * FROM (
  SELECT DATE_RECEIVED::date dt, sender, REGEXP_REPLACE(SUBSTR(TRIM(b),1,155),$$\s+$$,' ',1,0) snip,
         ROW_NUMBER() OVER (ORDER BY DATE_RECEIVED DESC) rn
  FROM c WHERE NOT auto AND NOT rd AND is_lead AND NOT optout AND NOT ooo AND NOT declines
    AND blen BETWEEN 20 AND 1200 AND DATE_RECEIVED>='2026-01-01')
WHERE rn % 22 = 1 ORDER BY dt DESC
