# create ipset with zscaler ipv4 hubs to use in iptables firewall ruleset
# dj0Nz apr 2023

import json
import ipaddress
import requests
import os

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

# create or reset zsclaer ipset
os.system('/usr/sbin/ipset -q create zscaler hash:net')
os.system('/usr/sbin/ipset flush zscaler')

# loop through prefixes list and create ipset entries
for hub in hub_prefixes:
    if is_ipv4_net(hub):
        add_net = "/usr/sbin/ipset add zscaler " + str(hub) 
        os.system(add_net)

