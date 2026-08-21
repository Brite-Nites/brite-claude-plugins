import sys, snowflake.connector
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

with open('/Users/corinnebrewer/.snowflake/rsa_key.p8','rb') as f:
    pk = serialization.load_pem_private_key(f.read(), password=None, backend=default_backend())
pkb = pk.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption())

con = snowflake.connector.connect(
    account='VKTQGEV-JBB38319', user='CORINNE', private_key=pkb,
    role='ACCOUNTADMIN', warehouse='TRANSFORMING_WH', database='ANALYTICS', schema='STAGING')

sql = sys.stdin.read()
cur = con.cursor()
for stmt in [s for s in sql.split(';\n--SPLIT--\n') if s.strip()]:
    cur.execute(stmt)
    cols = [c[0] for c in cur.description]
    rows = cur.fetchall()
    print('\t'.join(cols))
    for r in rows:
        print('\t'.join('' if v is None else str(v) for v in r))
    print(f'-- {len(rows)} rows')
con.close()
