# list zscaler ipv4 hubs 
# dj0Nz apr 2023

import json
import ipaddress
import requests

# function to check if input is a valid ipv4 network
def is_ipv4_net(network):
    try:
        valid_net = ipaddress.IPv4Network(network)
        return True
    except:
        return False

# store response and get json content
response = requests.get('https://api.config.zscaler.com/zscaler.net/hubs/cidr/json/recommended')
zs_hublist = response.json()

# extract hub prefixes list
hub_prefixes = zs_hublist['hubPrefixes']

# loop through prefixes list and print entries
for hub in hub_prefixes:
    if is_ipv4_net(hub):
        print(hub)
