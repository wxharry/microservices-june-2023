import urllib.request
import urllib.error

jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InNpZ24ifQ.eyJpYXQiOjE2NzUyMDA4MTMsImlzcyI6ImFwaUtleTEiLCJhdWQiOiJhcGlTZXJ2aWNlIiwic3ViIjoiYXBpS2V5MSJ9._6L_Ff29p9AWHLLZ-jEZdihy-H1glooSq_z162VKghA"
authstring = "Bearer " + jwt
req = urllib.request.Request("http://host.docker.internal")
req.add_header("Authorization", authstring)
try:
    with urllib.request.urlopen(req) as response:
        the_page = response.read()
        message = response.getheader("X-MESSAGE")
        print("200 " + message)
except urllib.error.URLError as e:
    print(str(e.code) + " " + e.msg)
