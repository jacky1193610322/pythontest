#!/usr/bin/env python
# encoding: utf-8

import sys
import logging

from contextlib import contextmanager
from sqlalchemy.ext.automap import automap_base
from sqlalchemy import create_engine
from sqlalchemy import func
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm import scoped_session


logging.basicConfig(stream=sys.stdout, level=logging.WARNING)
logger = logging.getLogger(__name__)


db = 'mysql://boss:boss@127.0.0.1:3306/test?charset=utf8&use_unicode=1'


Base = automap_base()
engine = create_engine(db, echo=False)
Base.prepare(engine, reflect=True)

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


person = Base.classes.Person


def add_persons():
    with session_scope() as session:
        bodys = []
        for i in xrange(100000):
            body = {
                "age": i,
                "firstname": "auto" + str(i)
            }
            bodys.append(body)
        session.bulk_insert_mappings(person, bodys)


def count():
    with session_scope() as session:
        return session.query(func.count(person.id)).scalar()


def count_1():
    with session_scope() as session:
        session.query(person).count()


def count_2():
    with session_scope() as session:
        session.query(person).statement.with_only_columns([func.count()]).scalar()


if __name__ == '__main__':
    add_persons()
    print(count())
