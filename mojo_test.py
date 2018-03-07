#!/usr/bin/env python3

import json
import urllib.parse as urlparse
from collections import defaultdict

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

# API URLs
dashboard_url = "https://dashboard.mojonetworks.com/rest/api/v2"
service_url = "/services"
webservice_url = "/new/webservice"
webservice_version_url = "/v3"
mwm_login_url = "/login/key/api-client/3600?getClusterChildrenData=true"
mwm_devices_url = "/devices"
fetch_client_paginated_url = "/clients/0/1"
fetch_image_url = "/sfiles"
fetch_placement_url = "/layouts/placement"
fetch_layout_url = "/layouts?locationid=%s"

# Login to Mojo Launchpad
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

# Fetch service URL
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

# Login to Mojo Wireless Manager
mwm_payload = {'type': 'apikeycredentials', 'keyId': key_id, 'keyValue': key_value}
mwm_auth_r = rq.post(url=mwm_url + webservice_url + mwm_login_url, json=mwm_payload, headers=header,
                     cookies=auth_r.cookies)
mwm_cookies = None
if mwm_auth_r.status_code == 200:
    print("MWM Login Successful")
    mwm_cookies = mwm_auth_r.cookies
    print("Got MWM Cookie: ", mwm_cookies.get("JSESSIONID"))
else:
    print("MWM Login Failed")
    exit(0)

# Fetch client by username
search_filter = {
    "property": "username",
    "value"   : ["chahat"],
    "operator": "="
}
fetch_client_url_parsed = mwm_url + webservice_url + webservice_version_url + mwm_devices_url + \
                          fetch_client_paginated_url + "?filter=" + \
                          urlparse.quote(json.dumps(search_filter))
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

# Fetch observing devices from client ID
if client_box_id is not None:
    fetch_observing_devices_url = ("/clients/%s/observingmanageddevices" % str(client_box_id))
    fetch_observing_devices_url_parsed = mwm_url + webservice_url + webservice_version_url + mwm_devices_url + \
                                         fetch_observing_devices_url
    fetch_observing_devices_r = rq.request(method="get", url=fetch_observing_devices_url_parsed, cookies=mwm_cookies,
                                           headers=header)
    observing_device_list = defaultdict(int)
    if fetch_observing_devices_r.status_code == 200:
        print("Fetching List of Observing Devices Successful")
        observing_devices_json = json.loads(fetch_observing_devices_r.text)
        print(("There are %d devices observing client <%s>") % (len(observing_devices_json), client_name))
        for i in range(len(observing_devices_json)):
            device_name = observing_devices_json[i]["name"]
            device_box_id = observing_devices_json[i]["boxId"]
            device_signal_strength = 100 + observing_devices_json[i]["signalStrength"]
            print(device_name)
            if "RM4" in device_name or "HW4" in device_name:
                observing_device_list[device_box_id] = device_signal_strength
                # print(("[Device: %s] [Box ID: %02d] [Signal Strength: %d%%]") % (device_name,
                #                                                                  device_box_id,
                #                                                                  device_signal_strength))
    else:
        print("Fetching List of Observing Devices Failed")
else:
    print("Client Box ID Required")
    exit(0)

# Fetch floor layout key
third_floor_id = 4
fourth_floor_id = 2
fetch_layout_url_parsed = mwm_url + webservice_url + webservice_version_url + (fetch_layout_url % str(fourth_floor_id))
fetch_layout_r = rq.request(method="get", url=fetch_layout_url_parsed, cookies=mwm_cookies, headers=header)
if fetch_layout_r.status_code == 200:
    print("Layout Fetch Successful")
    floor_layout_json = json.loads(fetch_layout_r.text)
    floor_image_key = floor_layout_json["imageKey"]
    floor_length = floor_layout_json["length"]
    floor_width = floor_layout_json["width"]
    print("Floor Plan Image Key: %s" % floor_image_key)
else:
    print("Layout Fetch Failed")
    exit(0)

# Get floor image
fetch_image_url_parsed = mwm_url + webservice_url + fetch_image_url
fetch_image_r = rq.request(method="get", url=fetch_image_url_parsed, cookies=mwm_cookies, headers=header,
                           params={"id": floor_image_key})
if fetch_image_r.status_code == 200:
    print("Fetch Floor Image Successful")
    img_arr = np.fromstring(fetch_image_r.content, np.uint8)
    floor_img = cv2.imdecode(img_arr, cv2.IMREAD_ANYCOLOR)
    h, w, _ = floor_img.shape
    feet_to_pixel_scale = floor_length / w
else:
    print("Fetch Floor Image Failed")

wifi_radius_feet = 40

# Get managed devices locations
fetch_placement_url_parsed = mwm_url + webservice_url + webservice_version_url + fetch_placement_url
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
        device_signal_strength = observing_device_list.get(device_box_id)
        if device_box_id in observing_device_list.keys():
            print(("[Device: %s] [Box ID: %02d] [Strength: %02d%%] [Location: (%5.4f, %5.4f)]") %
                  (device_name, device_box_id, device_signal_strength, x_coord, y_coord))
            cv2.circle(floor_img, (int(x_coord / feet_to_pixel_scale), int(y_coord / feet_to_pixel_scale)),
                       radius=5,
                       color=(255, 0, 0),
                       thickness=5)
            cv2.circle(floor_img, (int(x_coord / feet_to_pixel_scale), int(y_coord / feet_to_pixel_scale)),
                       radius=int(wifi_radius_feet / feet_to_pixel_scale),
                       color=(0, 0, 255),
                       lineType=0)

cv2.imshow("Floor", floor_img)
cv2.waitKey(0)
cv2.destroyAllWindows()
