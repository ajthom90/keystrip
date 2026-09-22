PRAGMA encoding = 'UTF-16le';
PRAGMA page_size = 1024;
CREATE TABLE meta (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL DEFAULT (''));
CREATE TABLE extension (id TEXT NOT NULL PRIMARY KEY, typecode TEXT NOT NULL, name TEXT NOT NULL DEFAULT (''), modified TEXT NOT NULL);
CREATE TABLE field (extension_id TEXT NOT NULL REFERENCES extension(id) ON UPDATE CASCADE ON DELETE CASCADE, field_id INTEGER NOT NULL, content TEXT NOT NULL DEFAULT (''), PRIMARY KEY (extension_id, field_id));
CREATE TABLE selections (extension_id TEXT NOT NULL PRIMARY KEY REFERENCES extension(id) ON UPDATE CASCADE ON DELETE CASCADE);
CREATE TABLE graphics (hash TEXT NOT NULL PRIMARY KEY,file_size INTEGER NOT NULL, original_name TEXT NOT NULL, content BLOB NOT NULL);
CREATE INDEX field__field_id ON field (field_id);
CREATE INDEX extension__typecode ON extension (typecode);
INSERT INTO meta (key, value) VALUES ('kind', 'dsi');
INSERT INTO meta (key, value) VALUES ('versions', '300, 301, 302, 303');

-- Phone 101: a full 12-key phone.
INSERT INTO extension (id, typecode, name, modified) VALUES ('101', 'AWX9212', 'Alex Rivera', '20240102T090000');
INSERT INTO field (extension_id, field_id, content) VALUES
 ('101', 4796, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc Alex x101}'),
 ('101', 5096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Page\par Phones}'),
 ('101', 6096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Page\par Plant}'),
 ('101', 7096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Sam}'),
 ('101', 8096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Jordan}'),
 ('101', 9096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Taylor}'),
 ('101', 10096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Morgan}'),
 ('101', 11096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Casey}'),
 ('101', 12096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 703}'),
 ('101', 13096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 702}'),
 ('101', 14096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 701}'),
 ('101', 15096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b System\par 2}'),
 ('101', 16096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b System\par 1}');

-- Template: a template phone with blanks, empty labels, and a trailing \par.
INSERT INTO extension (id, typecode, name, modified) VALUES ('Template', 'AWX9212', '', '20211105T115047');
INSERT INTO field (extension_id, field_id, content) VALUES
 ('Template', 4796, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc Template\par }'),
 ('Template', 5096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Page\par Phones}'),
 ('Template', 6096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Page\par Plant}'),
 ('Template', 7096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b }'),
 ('Template', 8096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc }'),
 ('Template', 12096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 703}'),
 ('Template', 13096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 702}'),
 ('Template', 14096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 701}'),
 ('Template', 15096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b System\par 2}'),
 ('Template', 16096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b System\par 1}');

-- Phone 240: a 24-key phone, keys "Key 1" to "Key 24", key 1 at 8 pt.
INSERT INTO extension (id, typecode, name, modified) VALUES ('240', 'AWX9224', 'Robin Lee', '20240325T143336');
INSERT INTO field (extension_id, field_id, content) VALUES
 ('240', 4796, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc Robin 240}'),
 ('240', 5096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs16\qc\b Key 1}');
WITH RECURSIVE k(n) AS (SELECT 2 UNION ALL SELECT n + 1 FROM k WHERE n < 24)
INSERT INTO field (extension_id, field_id, content)
 SELECT '240', 5096 + 1000 * (n - 1), '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Key ' || n || '}' FROM k;

-- Phone 300: an unknown model with a comment field (id 5) and keys 1 and 3.
INSERT INTO extension (id, typecode, name, modified) VALUES ('300', 'ZZ9999', 'Lab Phone', '20190709T101030');
INSERT INTO field (extension_id, field_id, content) VALUES
 ('300', 5, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\ql Comment}'),
 ('300', 4796, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc Lab 300}'),
 ('300', 5096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b One}'),
 ('300', 7096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Three}');

-- Phone 102: the unusual labels. Key 5 is valid RTF the writer would not reproduce;
-- key 6 is not RTF at all.
INSERT INTO extension (id, typecode, name, modified) VALUES ('102', 'AWX9212', 'Chris Ng', '20250829T103509');
INSERT INTO field (extension_id, field_id, content) VALUES
 ('102', 4796, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc Chris x102}'),
 ('102', 5096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green64\blue64;}\f0\cf0\fs18\qc\b Operator\par Assistance}'),
 ('102', 6096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs16\qc\b Page Phones}'),
 ('102', 7096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Caf\''e9}'),
 ('102', 8096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Ben \b0 S}'),
 ('102', 9096, '{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Arial;}}\f0\fs18\qc\b Odd}'),
 ('102', 10096, 'not rtf at all'),
 ('102', 11096, '{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b \u256?}');

INSERT INTO selections (extension_id) VALUES ('102');
