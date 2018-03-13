#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import mock
import logging
import sys

rootdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, rootdir)

from smartcontrol.common.utils import parse_uri


def test_parse_uri():
    req = mock.Mock()
    req.path = '/v2/cloud_connections/123456/pcl_select'
    req.method = "GET"

    apikey, resources = parse_uri(req)
    return apikey, resources


if __name__ == "__main__":
    apikey, res = test_parse_uri()
    print(apikey)
    module, oper = apikey.split(':')[-2], apikey.split(':')[-1]
    print(module, oper)
