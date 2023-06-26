import os
import sys
import urllib.request
import urllib.error

jotfile = "/run/secrets/jot"
jwt = ""
if os.path.isfile(jotfile):
    with open(jotfile) as jwtfile:
        for line in jwtfile:
            jwt = "Bearer " + line
else:
    print("Error:file not present ", file=sys.stderr)
    sys.exit(1)

req = urllib.request.Request("http://host.docker.internal")
req.add_header("Authorization", jwt)
try:
    with urllib.request.urlopen(req) as response:
        the_page = response.read()
        message = response.getheader('X-MESSAGE')
        print("200 " + message, file=sys.stderr)
except urllib.error.URLError as e:
    print(str(e.code) + " " + e.msg, file=sys.stderr)
