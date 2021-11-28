from flask import Flask, request
from psycopg2 import connect
from json import dumps
from re import search
from urllib.parse import unquote
import pendulum


# The Flask app:

app = Flask(__name__)

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
        locked = row[0]
        if not locked:
          print("arrived safely, not locked")
          return {avid: True}
        expires = pendulum.instance(row[1], 'local')
        if now < expires:
          print("arrived safely, in travel window")
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

        return {avid: False}
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

@app.route('/lock/<avid>', methods = ['POST'])
@app.route('/lock/<avid>/<state>', methods = ['POST'])
def lock(avid, state=True):
  app.logger.info(f"lock({avid}, {state})")
  print(f"lock({avid}, {state})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('UPDATE users SET locked = %s WHERE avid = %s', [state, avid])
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


@app.route('/lockout/<avid>', methods = ['POST'])
@app.route('/lockout/<avid>/<state>', methods = ['POST'])
def lockout(avid, state=True):
  app.logger.info(f"lockout({avid}, {state})")
  print(f"lockout({avid}, {state})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('UPDATE users SET lockout = %s WHERE avid = %s', [state, avid])
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
        cursor.execute('UPDATE users SET travel = %s, recover = %s WHERE avid = %s', [tt, rt, avid])
        return {avid: [tt, rt]}
  except Exception as e:
    print(f"Sharks! {e}") 
    return str(e), 500


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
        return {avid: owner}
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
        return {avid: owner}
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

  # Fixup args a bit.  If a dwell was specified but no per, push the bitch
  if dwell != 0 and per == 0:
    per = dwell
  
  print(f"Adding/updating {location} to {dwell} mins per {per} hours")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('''
          INSERT INTO locations (avid, location, dwell, per) VALUES (%s, %s, %s, %s)
          ON CONFLICT (avid, location) DO UPDATE SET dwell = %s, per = %s''', 
          [avid, location, dwell, per, dwell, per])
          # [avid, location, dwell, per])
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
        print(f"Home {home} region is {region}")
        cursor.execute(
          '''INSERT INTO locations (avid, location, dwell, per) VALUES (%s, %s, 0, 0)
              ON CONFLICT (avid, location) DO UPDATE SET dwell = 0, per = 0''',
              [avid, region]
        )
        return {avid: home}
  except Exception as e:
    print(f"Frogs! {e}") 
    return str(e), 500


# Our one read-write API, which is still a GET 
# even though it can create an object

@app.route('/get/<avid>')
def get(avid):
  app.logger.info(f"get({avid})")
  print(f"get({avid})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
        cursor.execute('SELECT locked, tracking, lockout, travel, recover, home FROM users WHERE avid = %s', [avid, ])
        rows = cursor.fetchone()
        # print(rows)
        if rows:
          result = {'locked': rows[0],
                    'tracking': rows[1],
                    'lockout': rows[2],
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
          cursor.execute('SELECT location, dwell, per FROM locations WHERE avid = %s', [avid, ])
          row3 = cursor.fetchall()
          # print(row3)
          for row in row3:
            result['locations'].append({
              'location': row[0],
              'dwell': row[1],
              'per': row[2]
            })
        else:
          result = create(conn, avid)
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
    cursor.execute('SELECT locked, tracking, lockout, travel, recover FROM users WHERE avid = %s', [avid, ])
    rows = cursor.fetchone()
    # print(rows)
    if rows:
      result = {'locked': rows[0],
                'tracking': rows[1],
                'lockout': rows[2],
                'travel': rows[3],
                'recover': rows[4],
                'owners': [],
                'locations': []}
    return result


# Let's kick this pig

if __name__ == "__main__":
  try:
    app.run()
  except Exception as e:
    print(f"{e}") 
