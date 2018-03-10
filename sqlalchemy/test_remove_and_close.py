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

person = Base.classes.Person


if __name__ == '__main__':
    s1 = Session()
    p = Session.query(person).filter(person.id == 50000).first()
    print(p.firstname)
    Session.remove()
    s2 = Session()
    print(s1 is s2)
