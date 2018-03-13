from smartcontrol.external_account.model import ExternalAccountSession
from contextlib import contextmanager
from sqlalchemy import create_engine
from sqlalchemy.orm import scoped_session
from sqlalchemy.orm import sessionmaker
from smartcontrol.config import conf


engine = create_engine(conf.database.connection,
                       pool_recycle=3600, encoding='utf8', echo=True)
factory = sessionmaker(bind=engine)
Session = scoped_session(factory)


@contextmanager
def session_scope():
    session = Session()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()

params = {}
params["provider_id"] = "p-single"
# params["provider_id"] = "p-t1"
params["account_type"] = 2
params["cascade"] = True
filters = []

str_ = """
SELECT external_account.accountid AS external_account_accountid FROM external_account LEFT OUTER JOIN external_access_key ON external_access_key.external_account_id = external_account.uid AND external_access_key.`default` IS true 
WHERE external_account.deleted = 0 AND external_account.provider_id = :provider_id AND external_account.account_type = :account_type ORDER BY field(external_account.status, "enabled", "disabled")

"""

str_ = """
SELECT external_account.accountid AS external_account_accountid FROM external_account LEFT OUTER JOIN external_access_key ON external_access_key.external_account_id = external_account.uid AND external_access_key.`default` IS true 
WHERE external_account.deleted = 0 AND external_account.provider_id = :provider_id AND external_account.account_type = :account_type ORDER BY external_account.status

"""

with session_scope() as session:
    result = session.execute(str_, params).fetchall()
    print(result)
    # accounts = ExternalAccountSession.list(session, *filters, **params)
    # # print(accounts)
    # for i in accounts:
    #     print(i.accountid)
    # print(accounts[0].accountid)

