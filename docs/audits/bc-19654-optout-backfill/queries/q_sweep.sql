WITH our_dom AS (SELECT DISTINCT SPLIT_PART(LOWER(EMAIL_ADDRESS),'@',2) d FROM ANALYTICS.STAGING.STG_EMAILBISON__SENDER_EMAILS WHERE EMAIL_ADDRESS IS NOT NULL),
raw AS (
  SELECT _EB_WORKSPACE ws, LOWER(FROM_EMAIL_ADDRESS) sender, SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) sdom,
    DATE_RECEIVED,
    COALESCE(SUBJECT,'') || ' ~~ ' ||
    COALESCE(NULLIF(TEXT_BODY,''), REGEXP_REPLACE(COALESCE(HTML_BODY,''),'<[^>]+>',' ',1,0,'s'), '') AS full_txt
  FROM ANALYTICS.STAGING.STG_EMAILBISON__REPLIES
  WHERE FROM_EMAIL_ADDRESS IS NOT NULL AND SPLIT_PART(LOWER(FROM_EMAIL_ADDRESS),'@',2) NOT IN (SELECT d FROM our_dom)),
s AS (SELECT ws, sender, sdom, DATE_RECEIVED,
        REGEXP_REPLACE(full_txt,$$(\n_{10,}|\nFrom:\s|\nOn .{0,150}wrote:|\n>|-----Original Message-----).* $$,'',1,0,'is') b
      FROM raw),
hit AS (SELECT ws, sender, sdom,
  BOOLOR_AGG(REGEXP_LIKE(b,$$.*(unsubscribe|opt[- ]?out|remove (me|us|my|this|our)|take (me|us) off|do not (contact|email)|stop (emailing|sending)|please remove|no longer wish|distribution list).*$$,'is')) old_set,
  BOOLOR_AGG(REGEXP_LIKE(b,$$.*(cease and desist|cease contact|stop contacting|quit (emailing|sending|contacting)|get (me|us) off|delete (me|us|my email|my address|this address)|leave (me|us) alone|drop (me|us) from|exclude (me|us)|discontinue (all )?(contact|email)|withdraw (me|us)|do not (call|solicit|reach out)|no (further|more) (emails|contact|communication)|stop all (contact|communication|emails)|never (contact|email) (me|us)|remove from (your |the )?(list|database|mailing)|no longer monitored|not to be contacted|last warning|report(ed|ing) (you|this) (as|for) spam|mark(ed|ing) (this )?as spam|this is spam|harass).*$$,'is')) new_set,
  MAX(DATE_RECEIVED) last_dt,
  MAX(REGEXP_REPLACE(SUBSTR(TRIM(b),1,150),$$\s+$$,' ',1,0)) samp_txt
 FROM s GROUP BY 1,2,3)
SELECT ws, sender, sdom, last_dt::date dt, samp_txt
FROM hit WHERE new_set AND NOT old_set ORDER BY dt DESC
