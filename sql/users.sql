-- Jojo

INSERT INTO USERS (avid) VALUES ('caf5386a-7dbe-488f-b194-5a7b681d9e9b');
INSERT INTO OWNERS (avid, owner) VALUES ('caf5386a-7dbe-488f-b194-5a7b681d9e9b', 'e2f9ce85-b524-4736-907d-7c8a62f19842');
INSERT INTO OWNERS (avid, owner) VALUES ('caf5386a-7dbe-488f-b194-5a7b681d9e9b', '17603264-e62a-45ae-88ca-9057e57a59a5');

INSERT INTO locations (avid, location) VALUES ('caf5386a-7dbe-488f-b194-5a7b681d9e9b', 'Six Lakes');
INSERT INTO locations (avid, location) VALUES ('caf5386a-7dbe-488f-b194-5a7b681d9e9b', 'Fhiraldon');
INSERT INTO locations (avid, location, dwell, per) VALUES ('caf5386a-7dbe-488f-b194-5a7b681d9e9b', 'Sensual Freedom', 60, 1);

-- Megan

INSERT INTO users (avid) VALUES ('1fb5306d-3113-438c-b9a9-123288ce762b');
INSERT INTO owners (avid, owner) VALUES ('1fb5306d-3113-438c-b9a9-123288ce762b', 'e2f9ce85-b524-4736-907d-7c8a62f19842');

INSERT INTO locations (avid, location) VALUES ('1fb5306d-3113-438c-b9a9-123288ce762b', 'Six Lakes');
INSERT INTO locations (avid, location) VALUES ('1fb5306d-3113-438c-b9a9-123288ce762b', 'Fhiraldon');
INSERT INTO locations (avid, location, dwell, per) VALUES ('1fb5306d-3113-438c-b9a9-123288ce762b', 'Sensual Freedom', 60, 1);

-- Gwen

INSERT INTO users (avid) VALUES ('7019e661-3532-4716-900e-f13ff7212de7');
INSERT INTO owners (avid, owner) VALUES ('7019e661-3532-4716-900e-f13ff7212de7', '17603264-e62a-45ae-88ca-9057e57a59a5');

INSERT INTO locations (avid, location) VALUES ('7019e661-3532-4716-900e-f13ff7212de7', 'Six Lakes');
INSERT INTO locations (avid, location) VALUES ('7019e661-3532-4716-900e-f13ff7212de7', 'Fhiraldon');
INSERT INTO locations (avid, location) VALUES ('7019e661-3532-4716-900e-f13ff7212de7', 'Sensual Freedom');

-- Gwennie's shopping controls
INSERT INTO locations (avid, location, dwell, per) VALUES ('7019e661-3532-4716-900e-f13ff7212de7', 'FaMESHed', 30, 7);
INSERT INTO locations (avid, location, dwell, per) VALUES ('7019e661-3532-4716-900e-f13ff7212de7', '8 8', 30, 7);
INSERT INTO locations (avid, location, dwell, per) VALUES ('7019e661-3532-4716-900e-f13ff7212de7', 'Liberty City', 30, 7);
INSERT INTO locations (avid, location, dwell, per) VALUES ('7019e661-3532-4716-900e-f13ff7212de7', 'No Comment', 30, 7);

-- Random non-user

INSERT INTO users (avid) VALUES ('f8dc96e8-3559-49ad-bc87-c88e9e5ea629');
INSERT INTO owners (avid, owner) VALUES ('f8dc96e8-3559-49ad-bc87-c88e9e5ea629', 'e2f9ce85-b524-4736-907d-7c8a62f19842');
INSERT INTO owners (avid, owner) VALUES ('f8dc96e8-3559-49ad-bc87-c88e9e5ea629', '17603264-e62a-45ae-88ca-9057e57a59a5');
INSERT INTO locations (avid, location) VALUES ('f8dc96e8-3559-49ad-bc87-c88e9e5ea629', 'Six Lakes');
INSERT INTO locations (avid, location) VALUES ('f8dc96e8-3559-49ad-bc87-c88e9e5ea629', 'Fhiraldon');
INSERT INTO locations (avid, location, dwell, per) VALUES ('f8dc96e8-3559-49ad-bc87-c88e9e5ea629', 'Sensual Freedom', 60, 1);

-- Make user this removes owners and locations as well
DELETE FROM users WHERE avid = 'f8dc96e8-3559-49ad-bc87-c88e9e5ea629';
