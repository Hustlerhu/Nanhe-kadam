-- DESTRUCTIVE: drops application tables. Take a backup before running remotely.
PRAGMA foreign_keys = ON;
DROP TABLE IF EXISTS teacher_attendance;
DROP TABLE IF EXISTS teacher_salaries;
DROP TABLE IF EXISTS teacher_assignments;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS admission_enquiries;
DROP TABLE IF EXISTS gallery_items;
DROP TABLE IF EXISTS gallery_sections;
DROP TABLE IF EXISTS notices;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS classes;
DROP TABLE IF EXISTS media;
DROP TABLE IF EXISTS teachers;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS socials;
DROP TABLE IF EXISTS settings;
-- Common legacy names from earlier versions.
DROP TABLE IF EXISTS salaries;
DROP TABLE IF EXISTS payroll_history;
DROP TABLE IF EXISTS attendance;
DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS gallery;
DROP TABLE IF EXISTS enquiries;
DROP TABLE IF EXISTS admins;
DROP TABLE IF EXISTS school_settings;
CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE COLLATE NOCASE, password_hash TEXT NOT NULL, salt TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('super_admin','co_admin','teacher')), must_change_password INTEGER NOT NULL DEFAULT 0 CHECK(must_change_password IN (0,1)), created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE UNIQUE INDEX one_super_admin ON users(role) WHERE role='super_admin';
CREATE TABLE teachers (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, name TEXT NOT NULL, bio TEXT NOT NULL DEFAULT '', photo_id INTEGER REFERENCES media(id) ON DELETE SET NULL);
CREATE TABLE media (id INTEGER PRIMARY KEY, mime TEXT NOT NULL, data TEXT NOT NULL, owner_teacher_id INTEGER REFERENCES teachers(id) ON DELETE CASCADE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE classes (id INTEGER PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', icon TEXT NOT NULL DEFAULT '', image_id INTEGER REFERENCES media(id) ON DELETE SET NULL, sort_order INTEGER NOT NULL DEFAULT 0);
CREATE TABLE teacher_assignments (teacher_id INTEGER NOT NULL REFERENCES teachers(id) ON DELETE CASCADE, class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE, PRIMARY KEY(teacher_id,class_id));
CREATE TABLE teacher_salaries (id INTEGER PRIMARY KEY, teacher_id INTEGER NOT NULL REFERENCES teachers(id) ON DELETE CASCADE, amount INTEGER NOT NULL CHECK(amount>=0), period TEXT NOT NULL, note TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE teacher_attendance (id INTEGER PRIMARY KEY, teacher_id INTEGER NOT NULL REFERENCES teachers(id) ON DELETE CASCADE, date TEXT NOT NULL, status TEXT NOT NULL, UNIQUE(teacher_id,date));
CREATE TABLE sessions (id TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires_at INTEGER NOT NULL);
CREATE INDEX sessions_user_idx ON sessions(user_id);
CREATE TABLE notices (id INTEGER PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', date TEXT NOT NULL, is_new INTEGER NOT NULL DEFAULT 0 CHECK(is_new IN (0,1)), class_id INTEGER REFERENCES classes(id) ON DELETE CASCADE, author_id INTEGER REFERENCES users(id) ON DELETE SET NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE events (id INTEGER PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', date TEXT NOT NULL);
CREATE TABLE gallery_sections (id INTEGER PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '');
CREATE TABLE gallery_items (id INTEGER PRIMARY KEY, section_id INTEGER NOT NULL REFERENCES gallery_sections(id) ON DELETE CASCADE, title TEXT NOT NULL, media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE, class_id INTEGER REFERENCES classes(id) ON DELETE CASCADE, author_id INTEGER REFERENCES users(id) ON DELETE SET NULL);
CREATE TABLE admission_enquiries (id INTEGER PRIMARY KEY, parent_name TEXT NOT NULL, child_name TEXT NOT NULL, phone TEXT NOT NULL, email TEXT NOT NULL DEFAULT '', class_name TEXT NOT NULL DEFAULT '', message TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE socials (platform TEXT PRIMARY KEY, url TEXT NOT NULL DEFAULT '', handle TEXT NOT NULL DEFAULT '', message TEXT NOT NULL DEFAULT '', enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)));
INSERT INTO settings VALUES ('school_name','Nanhe Kadam Public School'),('tagline','Public School'),('address','Near Sudha Factory, Chorawa Icha, Bihar'),('phone','+91 95591 04341'),('email','nanhekadam@gmail.com'),('opening_date',''),('principal','Amita Kumari'),('director','R K'),('hero_title','Nanhe Kadam Public School'),('hero_subtitle','A Great Start for a Bright Future'),('about','Nanhe Kadam Public School is a happy place where young minds explore, discover and grow. We nurture every child with care, curiosity and creativity.'),('logo_id',''),('hero_image_id',''),('google_map_url','');
INSERT INTO socials(platform) VALUES ('whatsapp'),('instagram'),('facebook'),('youtube');
INSERT INTO classes(name,description,icon,sort_order) VALUES ('Play Class','Learning through play and discovery.','',1),('Nursery','Building curiosity and confidence.','',2),('LKG','Little learners, big ideas.','',3),('UKG','Growing ready for the next step.','',4),('Class 1','A confident step into primary school.','',5),('Class 2','Building knowledge and curiosity.','',6),('Class 3','Learning and growing together.','',7),('Class 4','Exploring ideas with confidence.','',8),('Class 5','Ready for bigger adventures.','',9);
INSERT INTO gallery_sections(title,description) VALUES ('Little Learners','Everyday moments of discovery'),('Celebrations','Happy days together'),('Creative Corner','Imagination at work');
-- Example dates are illustrative and can be edited from the portal.
INSERT INTO notices(title,body,date,is_new) VALUES ('School will remain closed on 25th November 2026.','','2026-11-23',1),('Annual Function Practice from 24th Nov.','','2026-11-20',0),('Winter Dress is Compulsory from 1st December.','','2026-11-18',0);
DROP TABLE IF EXISTS login_attempts;
CREATE TABLE login_attempts (key TEXT PRIMARY KEY, count INTEGER NOT NULL, until INTEGER NOT NULL);

-- Initial credential is intentionally known and MUST be changed on first login.
INSERT INTO users(username,password_hash,salt,role,must_change_password) VALUES ('Rakesh@1','ee810a7498051e64997a5f1c510ebb1834271ab0b629a4665189ab2d855b3cd3','127f60c5b699c703dc594f43388cdb54','super_admin',1);
