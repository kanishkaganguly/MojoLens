#!/usr/bin/env python3

import json
import urllib.parse as urlparse

import requests as rq

# Global params
key_id = "KEY-ATN563405-456"
key_value = "e8311505a2d3a6d2156152e206839910"
header = {'Content-Type': 'application/json'}

# Login to Mojo Launchpad
dashboard_url = "https://dashboard.mojonetworks.com/rest/api/v2/"
auth_url = "kvs/login"
auth_r = rq.get(url=dashboard_url + auth_url, params={"key_id": key_id, "key_value": key_value, "session_timeout": 60})
if auth_r.status_code == 200:
    print("Authenticated Successfully")
    print("Got cookie: ", auth_r.cookies.get("ATN_CLOUD_DASHBOARD"))
else:
    print("Authentication Failed")

# Fetch service URL
service_url = "services"
service_r = rq.get(url=dashboard_url + service_url, params={"type": "amc"}, cookies=auth_r.cookies, headers=header)
if service_r.status_code == 200:
    print("MWM URL Fetched Successfully")
    service_json = json.loads(service_r.text)
    if "wireless".lower() in (service_json["data"]["customerServices"][0]["customer_service_name"]).lower():
        mwm_url = service_json["data"]["customerServices"][0]["service"]["service_url"]
        print("MWM URL: ", mwm_url)
    else:
        print("MWM URL Not Found")
else:
    print("MWM URL Fetch Failed")

# Login to Mojo Wireless Manager
mwm_login_url = "/new/webservice/login/key/api-client/3600?getClusterChildrenData=true"
mwm_payload = {'type': 'apikeycredentials', 'keyId': key_id, 'keyValue': key_value}
mwm_auth_r = rq.post(url=mwm_url + mwm_login_url, json=mwm_payload, \
                     headers=header, cookies=auth_r.cookies)
mwm_cookies = None
if mwm_auth_r.status_code == 200:
    print("MWM Login Successful")
    mwm_cookies = mwm_auth_r.cookies
    print("Got MWM Cookie: ", mwm_cookies.get("JSESSIONID"))
else:
    print("MWM Login Failed")

# Fetch client by username
fetch_client_url = "/new/webservice/v3/devices/clients/0/1"
search_filter = {
    "property": "username",
    "value"   : ["chahat"],
    "operator": "="
}
fetch_client_url_parsed = mwm_url + fetch_client_url + "?filter=" + urlparse.quote(json.dumps(search_filter))
fetch_client_r = rq.request(method="get", url=fetch_client_url_parsed, cookies=mwm_cookies, headers=header)
client_box_id = None
if fetch_client_r.status_code == 200:
    print("Search Filter Successful")
    client_json = json.loads(fetch_client_r.text)
    client_box_id = client_json["clientList"][0]["boxId"]
    client_name = client_json["clientList"][0]["name"]
    print("Client Name: ", client_name)
    print("Client Box ID: ", client_box_id)
else:
    print("Search Failed")

# Fetch observing devices from client ID
if client_box_id is not None:
    fetch_observing_devices_url = "/new/webservice/V3/devices/clients/" + str(client_box_id) + \
                                  "/observingmanageddevices"
    fetch_observing_devices_url_parsed = mwm_url + fetch_observing_devices_url
    fetch_observing_devices_r = rq.request(method="get", url=fetch_observing_devices_url_parsed, cookies=mwm_cookies,
                                           headers=header)
    if fetch_observing_devices_r.status_code == 200:
        print("Fetching List of Observing Devices Successful")
        observing_devices_json = json.loads(fetch_observing_devices_r.text)
        print(("There are %d devices observing client %s") % (len(observing_devices_json), client_name))
        device_list = observing_devices_json
        for i in range(len(device_list)):
            print(("Device: %s Box ID: %d Signal Strength: %d%%") % (device_list[i]["name"], device_list[i]["boxId"],
                                                                     100 + device_list[i]["signalStrength"]))
else:
    print("Client Box ID Required")
