import json
import jsonschema

body = {
    "product": "f6306f8a-202b-49ea-95fc-b46c56bc3838",
    "name": "chenyang",
    "bandwidth": 1,
    "expire_policy": "renewal",
    "pricing_rule": "bandwidth-volume-prepaid",
    "connection_z": {
        "type": "dc",
        "id": "con-0a164e862",
        "port_usage": "untag"
    },
    "connection_a": {
        "type": "cloud",
        "cloud": "aliyun",
        "id": "caaea6a7-b9ed-437b-b516-5256a21b5b12",
        "owner_id": "chenyang-12344"
    },
    "user": "50ee4b23-763b-4559-8b86-1a35774ba03c"
}


if __name__ == "__main__":
    with open("cb_vll.json") as fp:
        schema = json.load(fp)

    schemadir = "/Users/jacky/codesource/pythontest/sqlalchemy"
    resolver = jsonschema.RefResolver('file://' + schemadir + '/', None)
    validator = jsonschema.Draft4Validator(schema, resolver=resolver)
    validator.validate(body)
