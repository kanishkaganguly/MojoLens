#!/usr/bin/env python3

import json
import urllib.parse as urlparse

import cv2
import numpy as np
import requests as rq

''' 
STEPS TAKEN FOR LOCALIZATION
----------------------------
1. Login to Mojo Dashboard
2. Get Mojo Wireless Manager URL
3. Login to MWM and get cookie
4. Fetch necessary client by name
5. Fetch observing managed devices from client box ID
6. Fetch floor layout for mapping
7. Fetch managed devices location and plot on floor layout
'''

# Global params
key_id = "KEY-ATN563405-456"
key_value = "e8311505a2d3a6d2156152e206839910"
header = {'Content-Type': 'application/json', 'Accept-Encoding': 'gzip'}

# Login to Mojo Launchpad
dashboard_url = "https://dashboard.mojonetworks.com/rest/api/v2"
auth_url = "/kvs/login"
auth_r = rq.request(method="get", url=dashboard_url + auth_url, params={"key_id"         : key_id,
                                                                        "key_value"      : key_value,
                                                                        "session_timeout": 60})
if auth_r.status_code == 200:
    print("Authenticated Successfully")
    print("Got cookie: ", auth_r.cookies.get("ATN_CLOUD_DASHBOARD"))
else:
    print("Authentication Failed")
    exit(0)
print()

# Fetch service URL
service_url = "/services"
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
    exit(0)
print()

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
    exit(0)
print()

# Fetch client by username
mwm_client_url = "/new/webservice/v3/devices"
fetch_client_paginated_url = "/clients/0/1"
search_filter = {
    "property": "username",
    "value"   : ["chahat"],
    "operator": "="
}
fetch_client_url_parsed = mwm_url + mwm_client_url + fetch_client_paginated_url + "?filter=" + urlparse.quote(
    json.dumps(
        search_filter))
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
    exit(0)
print()

# Fetch observing devices from client ID
if client_box_id is not None:
    fetch_observing_devices_url = ("/clients/%s/observingmanageddevices" % str(client_box_id))
    fetch_observing_devices_url_parsed = mwm_url + mwm_client_url + fetch_observing_devices_url
    fetch_observing_devices_r = rq.request(method="get", url=fetch_observing_devices_url_parsed, cookies=mwm_cookies,
                                           headers=header)
    if fetch_observing_devices_r.status_code == 200:
        print("Fetching List of Observing Devices Successful")
        observing_devices_json = json.loads(fetch_observing_devices_r.text)
        print(("There are %d devices observing client <%s>") % (len(observing_devices_json), client_name))
        for i in range(5):
            print(("[Device: %s] [Box ID: %02d] [Signal Strength: %d%%]") % (
                observing_devices_json[i]["name"], observing_devices_json[i][
                    "boxId"], 100 + observing_devices_json[i]["signalStrength"]))
else:
    print("Client Box ID Required")
    exit(0)
print()

# Fetch floor layout key
third_floor_id = 4
fourth_floor_id = 2
mwm_location_url = "/new/webservice/v3"
fetch_layout_url = ("/layouts?locationid=%s" % str(fourth_floor_id))
fetch_layout_url_parsed = mwm_url + mwm_location_url + fetch_layout_url
fetch_layout_r = rq.request(method="get", url=fetch_layout_url_parsed, cookies=mwm_cookies, headers=header)
if fetch_layout_r.status_code == 200:
    print("Layout Fetch Successful")
    floor_layout_json = json.loads(fetch_layout_r.text)
    floor_image_key = floor_layout_json["imageKey"]
    print("Floor Plan Image Key: %s" % floor_image_key)
else:
    print("Layout Fetch Failed")
    exit(0)
print()

# Get floor image
mwm_image_url = "/new/webservice"
fetch_image_url = "/sfiles"
fetch_image_url_parsed = mwm_url + mwm_image_url + fetch_image_url
fetch_image_r = rq.request(method="get", url=fetch_image_url_parsed, cookies=mwm_cookies, headers=header,
                           params={"id": floor_image_key})
if fetch_image_r.status_code == 200:
    print("Fetch Floor Image Successful")
    img_arr = np.fromstring(fetch_image_r.content, np.uint8)
    floor_img = cv2.imdecode(img_arr, cv2.IMREAD_ANYCOLOR)
    h, w, _ = floor_img.shape
    print(h, w)
else:
    print("Fetch Floor Image Failed")
print()

# Get managed devices locations
fetch_placement_url = "/layouts/placement"
fetch_placement_url_parsed = mwm_url + mwm_location_url + fetch_placement_url
fetch_placement_r = rq.request(method="get", url=fetch_placement_url_parsed, cookies=mwm_cookies, headers=header,
                               params={"locationid": fourth_floor_id})
if fetch_placement_r.status_code == 200:
    fetch_placement_json = json.loads(fetch_placement_r.text)
    print("Fetched %d Sensor Placements" % len(fetch_placement_json["placedSensors"]))
    for i in range(len(fetch_placement_json["placedSensors"])):
        device_name = fetch_placement_json["placedSensors"][i]["device"]["name"]
        device_box_id = fetch_placement_json["placedSensors"][i]["device"]["boxId"]
        x_coord = fetch_placement_json["placedSensors"][i]["coOrdinates"]["xCordinate"]
        y_coord = fetch_placement_json["placedSensors"][i]["coOrdinates"]["yCordinate"]
        print(("[Device: %s] [Box ID: %02d] [Location: (%02f,%02f)]") % (device_name, device_box_id, x_coord, y_coord))

        cv2.circle(floor_img, (int(x_coord / 0.480), int(y_coord / 0.480)), 5, (0, 0, 255), -1)

cv2.imshow("Floor", floor_img)
k = cv2.waitKey(0)
cv2.destroyAllWindows()
