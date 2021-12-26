from flask import Flask, request
from psycopg2 import connect
from json import dumps
from re import search
from urllib.parse import unquote
from passlib.hash import pbkdf2_sha256
from uuid import uuid1
import pendulum


# The Flask app:

app = Flask(__name__)

# The JSON API
# Basically, a call router for the URL API

@app.route('/api/tracker/v1', methods = ['POST'])
def api():
  content = request.get_json()
  app.logger.info(f"Tracker v1 API call: {content}")
  print(f"Tracker v1 API call: {content}")

  try:
    # Route based on 'cmd'
    if not 'cmd' in content:
      return 'No command to execute', 501
    
    if content['cmd'] == 'login':
      if not 'username' in content or not 'password' in content:
        return 'Username or Password not specified', 501
      return login(content['username'], content['password'])

    if not 'avid' in content:
      return 'Avatar ID not specified', 501

    elif content['cmd'] == 'get':
      if 'dn' in content:
        ret = get(content['avid'], content['dn'])
      else:
        ret = get(content['avid'])
      return ret
    
    elif content['cmd'] == 'password':
      if not 'password' in content or not 'username' in content:
        return 'Username or Password not specified', 501
      ret = password(content['avid'], content['username'], content['password'])
      print(f"password said: {ret}")
      return ret

    elif content['cmd'] == 'displayname':
      if not 'username' in content:
        return 'Username not specified', 501
      ret = displayname(content['avid'], content['username'])
      print(f"displayname said: {ret}")
      return ret

    elif content['cmd'] == 'arrive':
      if not 'landing' in content:
        return 'Landing point not specified', 501
      ret = arrive(content['avid'], content['landing'])
      print(f"arrive said: {ret}")
      return ret

    elif content['cmd'] == 'travel':
      return travel(content['avid'])
    
    elif content['cmd'] == 'lock':
      if 'state' in content:
        return lock(content['avid'], content['state'].lower().startswith('tru'))
      else:
        return lock(content['avid'])
    
    elif content['cmd'] == 'track':
      if 'state' in content:
        return track(content['avid'], content['state'].lower().startswith('tru'))
      else:
        return track(content['avid'])
    
    elif content['cmd'] == 'lockdown':
      if 'state' in content:
        return lockdown(content['avid'], content['state'].lower().startswith('tru'))
      else:
        return lockdown(content['avid'])
    
    elif content['cmd'] == 'addowner':
      if not 'owner' in content:
        return 'Owner not specified', 501
      else:
        return addowner(content['avid'], content['owner'])
    
    elif content['cmd'] == 'delowner':
      if not 'owner' in content:
        return 'Owner not specified', 501
      else:
        return delowner(content['avid'], content['owner'])
    
    elif content['cmd'] == 'addloc':
      if not 'location' in content:
        return 'Location not specified', 501
      if 'dwell' in content:
        if 'per' in content:
          return addloc(content['avid'], content['location'], content['dwell'], content['per'])
        else:
          return addloc(content['avid'], content['location'], content['dwell'])
      else:
        return addloc(content['avid'], content['location'])
    
    elif content['cmd'] == 'delloc':
      if not 'location' in content:
        return 'Location not specified', 501
      else:
        return delloc(content['avid'], content['location'])
    
    elif content['cmd'] == 'settravel':
      # settravel(avid, away=0, recover=0)
      if 'away' in content:
        if 'recover' in content:
          return settravel(content['avid'], content['away'], content['recover'])
      else:
        return settravel(content['avid'], content['away'])
    
    elif content['cmd'] == 'sethome':
      # Somewhat different, we pass the home as a string
      if not 'home' in content:
        return 'Home not specified', 501
      m = search('(.*)/(.*)/(.*)/(.*)', content['home'])
      # sethome(avid, region, x, y, z)
      return sethome(content['avid'], m.group(1), m.group(2), m.group(3), m.group(4))
    
    # We didn't understand the request, barf it back
    return content, 501

  except Exception as e:
    print(f"Uh-oh! {e}") 
    return str(e), 500


# Web support API

@app.route('/login/<username>/<password>', methods = ['POST'])
def login(username, password):
  app.logger.info(f"login(, {username}, {password})")
  print(f"login({username}, {password})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        print(f"Looking for {username}:")
        cursor.execute("SELECT password, ownid FROM passwords WHERE username = %s", [username, ])
        print("Got that without excepting")
        row = cursor.fetchone()
        print(row)
        if not row:
          return "Login failed", 401
        if not pbkdf2_sha256.verify(password, row[0]):
          return "Invalid login", 401
        session = uuid1()
        cursor.execute("UPDATE passwords SET session = %s WHERE ownid = %s", [str(session), row[1]])
        print(f"session cookie {session} for {row[1]} {type(row[1])}")
        conn.commit()
        return {row[1]: str(session)}
  except Exception as e:
    print(f"log what? {e}") 
    return str(e), 500

# Read-side API:

@app.route('/arrive/<avid>/<landing>', methods = ['POST'])
def arrive(avid, landing):
  app.logger.info(f"arrive({avid}, {landing})")
  print(f"arrive({avid}, {landing})")

  # Be generous, don't penalize user for DB connect time, etc
  now = pendulum.now()

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('SELECT locked, expires FROM users WHERE avid = %s', [avid,])
        row = cursor.fetchone()
        if not row:
          return f"Uknown avatar: {avid}", 501
        locked = row[0]
        expires = pendulum.instance(row[1], 'local')
        print(f"locked: {locked}, travel: {expires}, now: {now}")
        if not locked:
          print("arrived safely: not locked")
          return {avid: True}
        if now < expires:
          print("arrived safely: in travel window")
          return {avid: True}
        # Is this an allowed location (and in time window?)
        cursor.execute(
          'SELECT dwell, per, expires, recovers FROM locations WHERE avid = %s AND location = %s',
          [avid, landing])
        row = cursor.fetchone()
        print(row)
        if row is None:
          print("arrived in unregistered sim, bitch!")
          return {avid: False}
        # Are we allowed to be in this sim NOW?
        dwell = int(row[0])
        if dwell == 0:
          print(f"Always allowed to be in {landing}")
          return {avid: True}
        expires = pendulum.instance(row[2], 'local')
        if now < expires:
          print(f"Allowed to be in {landing} until {expires}")
          return {avid: True}
        # Are we IN the recovery window?
        recovers = pendulum.instance(row[3], 'local')
        if now < recovers:
          print(f"In recovery for {landing} until {recovers} biatch!")
          return {avid:False}
        # Recovery window has passed, open a new window
        per = int(row[1])
        expires = now.add(minutes = dwell)
        recovers = now.add(minutes = dwell, hours=per)
        print(f"Arrived for {dwell} minutes until {recovers}")
        cursor.execute(
          'UPDATE locations SET expires = %s, recovers = %s WHERE avid = %s AND location = %s',
          [expires, recovers, avid, landing]
        )
        print(f"Opened visit time for {landing}")
        return {avid: True}
  except Exception as e:
    print(f"Cunt! {e}") 
    return str(e), 500


@app.route('/travel/<avid>', methods = ['POST'])
def travel(avid, state=True):
  app.logger.info(f"travel({avid})")
  print(f"travel({avid})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('SELECT expires, recovers, travel, recover FROM users WHERE avid = %s', [avid,])
        row = cursor.fetchone()
        expires = pendulum.instance(row[0], 'local')
        now = pendulum.now()
        print(f"travel({avid}): travel expires/d: {expires} now: {now}")
        if now < expires:
          # We are IN the travel window
          print(f"travel: in travel time")
          return {avid: True}
        recovers = pendulum.instance(row[1], 'local')
        print(f"travel({avid}): travel recovers/ed: {recovers} now: {now}")
        if recovers < now:
          print("We are OUT OF the recovery window")
          travel = int(row[2])
          print(f"Travel minutes: {travel}")
          recover = int(row[3])
          print(f"Recover minutes: {recover}")
          print(f"Now: {now.naive()}")
          expires = now.add(minutes = travel).naive()
          print(f"New expiration: {expires}")
          recovers = now.add(minutes = (travel + recover)).naive()
          print(f"New recovers: {recovers}")
          print(f"UPDATE users SET expires = {expires}, recovers = {recovers} WHERE avid = {avid}")
          cursor.execute(
            'UPDATE users SET expires = %s, recovers = %s WHERE avid = %s',
            [expires, recovers, avid])
          return {avid: True}
        else:
          # IN the recovery window, so no
          print(f"travel: not recovered until {recovers}")
        return {avid: False}
  except Exception as e:
    print(f"Shit! {e}") 
    return str(e), 500


# Write-side API:

@app.route('/password/<avid>/<username>/<password>', methods = ['POST'])
def password(avid, username, password):
  app.logger.info(f"password({avid}, {username}, {password}")
  print(f"password({avid}, {username}, {password}")

  hash = pbkdf2_sha256.hash(password)

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('''
          INSERT INTO passwords (ownid, username, password) VALUES (%s, %s, %s)
          ON CONFLICT (ownid) DO UPDATE SET username = %s, password = %s''',
          [avid, username, hash, username, hash])
        return {avid: username}
  except Exception as e:
    print(f"Crappin crappity crap! {e}") 
    return str(e), 500


@app.route('/displayname/<avid>/<name>', methods = ['POST'])
def displayname(avid, name):
  app.logger.info(f"displayname({avid}, {name})")
  print(f"displayname({avid}, {name})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('''
          INSERT INTO displaynames (avid, name) VALUES (%s, %s)
          ON CONFLICT (avid) DO UPDATE SET name = %s''',
          [avid, name, name])
        return {avid: name}
  except Exception as e:
    print(f"Fungool: {e}") 
    return str(e), 500


@app.route('/lock/<avid>', methods = ['POST'])
@app.route('/lock/<avid>/<state>', methods = ['POST'])
def lock(avid, state=True):
  app.logger.info(f"lock({avid}, {state})")
  print(f"lock({avid}, {state})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        if state:
          cursor.execute('UPDATE users SET locked = %s WHERE avid = %s', [state, avid])
        else:
          cursor.execute('UPDATE users SET locked = %s, lockdown = %s WHERE avid = %s', [state, state, avid])
        return {avid: state}
  except Exception as e:
    print(f"Fuck! {e}") 
    return str(e), 500


@app.route('/track/<avid>', methods = ['POST'])
@app.route('/track/<avid>/<state>', methods = ['POST'])
def track(avid, state=True):
  app.logger.info(f"track({avid}, {state})")
  print(f"track({avid}, {state})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('UPDATE users SET tracking = %s WHERE avid = %s', [state, avid])
        return {avid: state}
  except Exception as e:
    print(f"Rats! {e}") 
    return str(e), 500


@app.route('/lockdown/<avid>', methods = ['POST'])
@app.route('/lockdown/<avid>/<state>', methods = ['POST'])
def lockdown(avid, state=True):
  app.logger.info(f"lockdown({avid}, {state})")
  print(f"lockdown({avid}, {state})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        if state:
          cursor.execute('UPDATE users SET lockdown = %s, locked = %s WHERE avid = %s', [state, state, avid])
        else:
          cursor.execute('UPDATE users SET lockdown = %s WHERE avid = %s', [state, avid])
        return {avid: state}
  except Exception as e:
    print(f"Sharks! {e}") 
    return str(e), 500


@app.route('/settravel/<avid>', methods = ['POST'])
@app.route('/settravel/<avid>/<away>', methods = ['POST'])
@app.route('/settravel/<avid>/<away>/<recover>', methods = ['POST'])
def settravel(avid, away=0, recover=0):
  app.logger.info(f"settravel({avid}, {away}, {recover})")
  print(f"settravel({avid}, {away}, {recover})")

  tt = int(away)
  rt = int(recover)

  if tt == 0:
    rt = 0
  elif rt < tt:
    rt = tt

  app.logger.info(f"fixed settravel({avid}, {tt}, {rt})")
  print(f"fixed settravel({avid}, {tt}, {rt})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('UPDATE users SET travel = %s, recover = %s, expires = now(), recovers = now() WHERE avid = %s', [tt, rt, avid])
        return {avid: [tt, rt]}
  except Exception as e:
    print(f"Sharks! {e}") 
    return str(e), 500


# Add and delete owner return the full owners list
# so the script can be certain it has the right list.
# Also so we can look up the owner display names.

@app.route('/addowner/<avid>/<owner>', methods = ['POST'])
def addowner(avid, owner):
  app.logger.info(f"addowner({avid}, {owner})")
  print(f"addowner({avid}, {owner})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute(
          'INSERT INTO owners (avid, owner) VALUES (%s, %s) ON CONFLICT DO NOTHING', 
          [avid, owner])

        cursor.execute('SELECT owner FROM owners WHERE avid = %s', [avid, ])
        row2 = cursor.fetchall()
        # print(row2)
        owners = []
        for row in row2:
          # print(row)
          owners.append(row[0])

        return {avid: owners}
  except Exception as e:
    print(f"Minnows! {e}") 
    return str(e), 500


@app.route('/delowner/<avid>/<owner>', methods = ['POST'])
def delowner(avid, owner):
  app.logger.info(f"delowner({avid}, {owner})")
  print(f"delowner({avid}, {owner})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute(
          'DELETE FROM owners WHERE avid = %s AND owner = %s', 
          [avid, owner])

        cursor.execute('SELECT owner FROM owners WHERE avid = %s', [avid, ])
        row2 = cursor.fetchall()
        # print(row2)
        owners = []
        for row in row2:
          # print(row)
          owners.append(row[0])

        return {avid: owners}
  except Exception as e:
    print(f"Minnows! {e}") 
    return str(e), 500


@app.route('/addloc/<avid>/<location>', methods = ['POST'])
@app.route('/addloc/<avid>/<location>/<dwell>', methods = ['POST'])
@app.route('/addloc/<avid>/<location>/<dwell>/<per>', methods = ['POST'])
def addloc(avid, location, dwell=0, per=0):
  app.logger.info(f"addloc({avid}, {location}, {dwell}, {per})")
  print(f"addloc({avid}, {location}, {dwell}, {per})")

  dwell = int(dwell)
  per = int(per)

  # Fixup args a bit.  If a dwell was specified but no per, make per day
  if dwell != 0 and per == 0:
    per = 24
  
  print(f"Adding/updating {location} to {dwell} mins per {per} hours")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('''
          INSERT INTO locations (avid, location, dwell, per) VALUES (%s, %s, %s, %s)
          ON CONFLICT (avid, location) DO UPDATE SET dwell = %s, per = %s''', 
          [avid, location, dwell, per, dwell, per])
        return {avid: location}
  except Exception as e:
    print(f"Guppies! {e}") 
    return str(e), 500


@app.route('/delloc/<avid>/<location>', methods = ['POST'])
def delloc(avid, location):
  app.logger.info(f"delloc({avid}, {location})")
  print(f"delloc({avid}, {location})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute(
          'DELETE FROM locations WHERE avid = %s AND location = %s', 
          [avid, location])
        return {avid: location}
  except Exception as e:
    print(f"Eeels! {e}") 
    return str(e), 500


@app.route('/sethome/<avid>/<region>/<x>/<y>/<z>', methods = ['POST'])
def sethome(avid, region, x, y, z):
  home = f"{region}/{x}/{y}/{z}"
  app.logger.info(f"sethome({avid}, {home})")
  print(f"sethome({avid}, {home})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute(
          'UPDATE users SET home = %s WHERE avid = %s', 
          [home, avid])
        # unencode the region for the Locations table, just in case
        region = unquote(region)
        print(f"Home {home} region is {region} (fully enabled)")
        cursor.execute(
          '''INSERT INTO locations (avid, location, dwell, per, expires, recovers) VALUES (%s, %s, 0, 0, now(), now())
              ON CONFLICT (avid, location) DO UPDATE SET dwell = 0, per = 0, expires=now(), recovers=now()''',
              [avid, region]
        )
        return {avid: home}
  except Exception as e:
    print(f"Frogs! {e}") 
    return str(e), 500


# Our one read-write API, which is still a GET 
# even though it can create an object

@app.route('/get/<avid>/<dn>')
def get(avid, dn = None):
  app.logger.info(f"get({avid}, {dn})")
  print(f"get({avid}, {dn})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('SELECT locked, tracking, lockdown, travel, recover, home FROM users WHERE avid = %s', [avid, ])
        rows = cursor.fetchone()
        # print(rows)
        if rows:
          result = {'locked': rows[0],
                    'tracking': rows[1],
                    'lockdown': rows[2],
                    'travel': rows[3],
                    'recover': rows[4],
                    'home': rows[5],
                    'owners': [],
                    'locations': []}
          cursor.execute('SELECT owner FROM owners WHERE avid = %s', [avid, ])
          row2 = cursor.fetchall()
          # print(row2)
          for row in row2:
            # print(row)
            result['owners'].append(row[0])
          # Only send location names
          # The LSL json parser is too fucking stupid to handle
          # any more, and all we need are the names for delete.
          cursor.execute('SELECT location FROM locations WHERE avid = %s', [avid, ])
          row3 = cursor.fetchall()
          # print(row3)
          for row in row3:
            result['locations'].append(row[0])
        else:
          result = create(conn, avid)
        
        if dn is not None:
          cursor.execute('''
            INSERT INTO displaynames (avid, name) VALUES (%s, %s)
            ON CONFLICT (avid) DO UPDATE SET name = %s''',
            [avid, dn, dn])
          
        return result
  except Exception as e:
    print(f"Oops! {e}")
    return str(e), 500

# Helper function, not a linked function

def create(conn, avid):
  app.logger.info(f"create({avid})")
  print(f"create({avid})")

  with conn.cursor() as cursor:
    cursor.execute('INSERT INTO users (avid) VALUES (%s)', [avid, ])
    cursor.execute('SELECT locked, tracking, lockdown, travel, recover FROM users WHERE avid = %s', [avid, ])
    rows = cursor.fetchone()
    # print(rows)
    if rows:
      result = {'locked': rows[0],
                'tracking': rows[1],
                'lockdown': rows[2],
                'travel': rows[3],
                'recover': rows[4],
                'owners': [],
                'locations': []}
    return result


# Let's kick this pig

if __name__ == "__main__":
  try:
    # app.config['SERVER_NAME'] = 'magic.softweyr.com'
    app.run()
  except Exception as e:
    print(f"{e}") 
