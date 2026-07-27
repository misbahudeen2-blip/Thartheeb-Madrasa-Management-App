const sqlite3 = require('sqlite3').verbose();
const { open } = require('sqlite');
const path = require('path');

async function run() {
  const db = await open({
    filename: path.join(__dirname, 'attendance.db'),
    driver: sqlite3.Database
  });

  try {
    const tableSchemaRow = await db.get("SELECT sql FROM sqlite_master WHERE name='daily_attendance'");
    if (tableSchemaRow && tableSchemaRow.sql.includes('UNIQUE(user_id, work_date)') && !tableSchemaRow.sql.includes('UNIQUE(user_id, work_date, batch_id)')) {
      console.log("Migrating daily_attendance to support multi-shift teachers (changing unique constraint and null check_in)...");
      await db.run("PRAGMA foreign_keys = OFF");
      await db.run("ALTER TABLE daily_attendance RENAME TO daily_attendance_old");
      await db.run(`
        CREATE TABLE daily_attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          work_date TEXT NOT NULL,
          check_in TEXT,
          late_minutes INTEGER DEFAULT 0,
          attendance_status TEXT,
          remarks TEXT,
          check_out TEXT,
          role TEXT DEFAULT 'student',
          batch_id TEXT,
          FOREIGN KEY (user_id) REFERENCES students(user_id) ON DELETE CASCADE,
          UNIQUE(user_id, work_date, batch_id)
        )
      `);
      await db.run(`
        INSERT OR IGNORE INTO daily_attendance (id, user_id, work_date, check_in, late_minutes, attendance_status, remarks, check_out, role, batch_id)
        SELECT id, user_id, work_date, check_in, late_minutes, attendance_status, remarks, check_out, role, COALESCE(batch_id, 'UNORGANIZED') FROM daily_attendance_old
      `);
      await db.run("DROP TABLE daily_attendance_old");
      await db.run("PRAGMA foreign_keys = ON");
      console.log("daily_attendance migration complete!");
    } else {
      console.log("daily_attendance already migrated or matches current constraint specifications.");
    }
  } catch (err) {
    console.error("Migration failed:", err);
  } finally {
    await db.close();
  }
}

run();
