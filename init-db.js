const sqlite3 = require('sqlite3');
const { open } = require('sqlite');
const path = require('path');

async function initializeDatabase() {
  const dbPath = path.join(__dirname, 'attendance.db');
  console.log(`Initializing database at: ${dbPath}`);

  // Open SQLite database file
  const db = await open({
    filename: dbPath,
    driver: sqlite3.Database
  });

  // Enable foreign keys
  await db.run('PRAGMA foreign_keys = ON');

  // Create Batches Table
  await db.exec(`
    CREATE TABLE IF NOT EXISTS batches (
      batch_id TEXT PRIMARY KEY,
      batch_name TEXT NOT NULL,
      start_time TEXT NOT NULL,       -- HH:MM:SS format
      grace_minutes INTEGER DEFAULT 15,
      checkin_start TEXT NOT NULL,    -- HH:MM:SS format
      checkin_end TEXT NOT NULL       -- HH:MM:SS format
    )
  `);

  // Create Students Table
  await db.exec(`
    CREATE TABLE IF NOT EXISTS students (
      user_id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      card_number TEXT,
      batch_id TEXT,
      FOREIGN KEY (batch_id) REFERENCES batches(batch_id) ON DELETE SET NULL
    )
  `);

  // Create Devices Table
  await db.exec(`
    CREATE TABLE IF NOT EXISTS devices (
      serial_number TEXT PRIMARY KEY,
      ip_address TEXT,
      device_name TEXT,
      last_seen TEXT,
      status TEXT DEFAULT 'OFFLINE'
    )
  `);

  // Create Raw Punches Table (Log of every received HTTP event)
  await db.exec(`
    CREATE TABLE IF NOT EXISTS raw_punches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      device_sn TEXT,
      punch_time TEXT NOT NULL,       -- YYYY-MM-DD HH:MM:SS format
      verify_mode INTEGER,            -- 1: Finger, 2: Card, etc.
      punch_state INTEGER,            -- 0: Check-In, etc.
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(user_id, punch_time)     -- Prevent duplicates
    )
  `);

  // Create Daily Attendance Table
  await db.exec(`
    CREATE TABLE IF NOT EXISTS daily_attendance (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      work_date TEXT NOT NULL,        -- YYYY-MM-DD format
      check_in TEXT NOT NULL,         -- YYYY-MM-DD HH:MM:SS format
      late_minutes INTEGER DEFAULT 0,
      attendance_status TEXT CHECK(attendance_status IN ('Present', 'Late', 'Absent')),
      remarks TEXT,
      FOREIGN KEY (user_id) REFERENCES students(user_id) ON DELETE CASCADE,
      UNIQUE(user_id, work_date)      -- Single daily attendance sheet per student
    )
  `);

  console.log('Tables created successfully.');

  // Seed default batch
  await db.run(`
    INSERT OR IGNORE INTO batches (batch_id, batch_name, start_time, grace_minutes, checkin_start, checkin_end)
    VALUES (?, ?, ?, ?, ?, ?)
  `, ['CS_BATCH_A', 'Computer Science - Batch A', '09:00:00', 15, '08:00:00', '10:30:00']);

  // Seed mock students
  const mockStudents = [
    ['1001', 'John Doe', 'RFID_1001', 'CS_BATCH_A'],
    ['1002', 'Jane Smith', 'RFID_1002', 'CS_BATCH_A'],
    ['1003', 'Alice Johnson', 'RFID_1003', 'CS_BATCH_A']
  ];

  for (const student of mockStudents) {
    await db.run(`
      INSERT OR IGNORE INTO students (user_id, name, card_number, batch_id)
      VALUES (?, ?, ?, ?)
    `, student);
  }

  console.log('Default seed data inserted.');
  await db.close();
  console.log('Database initialization complete.');
}

initializeDatabase().catch(err => {
  console.error('Failed to initialize database:', err);
  process.exit(1);
});
