from flask import Flask, request
from psycopg2 import connect
from json import dumps
import pendulum


#>>> from psycopg2 import connect
#>>> with connect(dbname='tracker', user='jojo') as conn:
#...  with conn.cursor() as cursor:
#...   cursor.execute('select * from users where avid = %s', ['caf5386a-7dbe-488f-b194-5a7b681d9e9b',])
#...   res = cursor.fetchone()
#...   if res is None:
#...    print("New user!")
#...   else:
#...    print(res)
#... 
#('caf5386a-7dbe-488f-b194-5a7b681d9e9b', False, False, False, 0, 0, datetime.datetime(2021, 11, 27, 1, 28, 48, 145014), datetime.datetime(2021, 11, 27, 1, 28, 48, 145014), None)


# A quick sloppy converter for datetime to json
def jsonconvert(o):
    return o.__str__()

# The Flask app:

app = Flask(__name__)

# Read-side API:

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


@app.route('/travel/<avid>', methods = ['POST'])
@app.route('/travel/<avid>/<away>', methods = ['POST'])
@app.route('/travel/<avid>/<away>/<recover>', methods = ['POST'])
def travel(avid, away=0, recover=0):
  app.logger.info(f"travel({avid}, {away}, {recover})")
  print(f"travel({avid}, {away}, {recover})")

  tt = int(away)
  rt = int(recover)

  if tt == 0:
    rt = 0
  elif rt < tt:
    rt = tt

  app.logger.info(f"fixed travel({avid}, {tt}, {rt})")
  print(f"fixed travel({avid}, {tt}, {rt})")

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


# Our one read-write API, which is still a GET 
# even though it can create an object

@app.route('/get/<avid>')
def get(avid):
  app.logger.info(f"get({avid})")
  print(f"get({avid})")

  try:
    with connect(dbname='tracker', user='jojo') as conn:
      with conn.cursor() as cursor:
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
