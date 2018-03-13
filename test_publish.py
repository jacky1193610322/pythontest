from smartcontrol.qcloud.controllers import QcloudController
from smartcontrol.cloud_connection.controllers import CConnectionController
import json

my_str = {"query":[{"field":"type","op":"=","value":"qcloud"}]}
q = json.dumps(my_str)


class Req(object):
    params = {"bandwidth": 10}


mana = QcloudController()
cc = CConnectionController()
# mana.publish_qcloud_connect_port(None, 'dc-zCSPfdvN')
# mana.revoke_qcloud_connect_port(None, 'dc-zCSPfdvN')
# cloud_manager = CConnectionController()
# res = cloud_manager.list_cloud_connections(Req)
res = cc.choose_qc_by_cloud_connection(Req, '922dba17-dcc3-47a2-b737-092081f0d072')
print(res)
