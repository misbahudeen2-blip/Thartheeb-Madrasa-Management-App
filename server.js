const express = require('express');
const cors = require('cors');
const sqlite3 = require('sqlite3');
const { open } = require('sqlite');
const path = require('path');
const multer = require('multer');
const xlsx = require('xlsx');
const nodemailer = require('nodemailer');
const fs = require('fs');

// Helper to send registration email
async function sendRegistrationEmail(toEmail, madrasaName, adminName, institutionCode) {
  let smtpConfig = null;
  const configPath = path.join(__dirname, 'config.json');
  
  // Try reading from config.json first
  if (fs.existsSync(configPath)) {
    try {
      const fileData = fs.readFileSync(configPath, 'utf8');
      const parsed = JSON.parse(fileData);
      if (parsed.smtp) {
        smtpConfig = parsed.smtp;
      }
    } catch (e) {
      console.error('Error reading config.json:', e);
    }
  }

  // Fallback to process.env if not in config.json
  if (!smtpConfig) {
    smtpConfig = {
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT) : null,
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
      from: process.env.SMTP_FROM || 'no-reply@thartheeb.com'
    };
  }

  // Validate SMTP config presence
  if (!smtpConfig.host || !smtpConfig.user || !smtpConfig.pass) {
    console.log(`[Email Simulator] SMTP is not configured. Logged details:
      To: ${toEmail}
      Institution Code: ${institutionCode}
      Madrasa Name: ${madrasaName}
      Admin Name: ${adminName}`);
    return false;
  }

  try {
    const transporter = nodemailer.createTransport({
      host: smtpConfig.host,
      port: smtpConfig.port ? parseInt(smtpConfig.port) : 587,
      secure: smtpConfig.port === 465, // true for 465, false for other ports
      auth: {
        user: smtpConfig.user,
        pass: smtpConfig.pass
      }
    });

    const mailOptions = {
      from: `"${madrasaName || 'Tartheeb Madrasa App'}" <${smtpConfig.from || smtpConfig.user}>`,
      to: toEmail,
      subject: `Welcome to Tartheeb - Madrasa Registration Success`,
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px; line-height: 1.6; max-width: 600px; border: 1px solid #e2e8f0; border-radius: 8px;">
          <h2 style="color: #485217; margin-bottom: 20px;">Registration Successful!</h2>
          <p>Dear <strong>${adminName || 'Admin'}</strong>,</p>
          <p>Thank you for registering <strong>${madrasaName}</strong> on the Tartheeb Madrasa Management platform. Your administrative account has been successfully created.</p>
          
          <div style="background-color: #f8fafc; padding: 15px; border-radius: 6px; border-left: 4px solid #485217; margin: 20px 0;">
            <p style="margin: 0 0 8px 0; font-size: 14px; color: #64748b;">YOUR INSTITUTION DETAILS:</p>
            <p style="margin: 0; font-size: 18px; font-weight: bold; color: #1e293b;">
              Institution Code: <span style="color: #059669; font-family: monospace; font-size: 20px; letter-spacing: 1px;">${institutionCode}</span>
            </p>
            <p style="margin: 8px 0 0 0; font-size: 14px; color: #1e293b;">
              Admin Username: <strong>${toEmail}</strong>
            </p>
          </div>

          <p>Please share the <strong>Institution Code</strong> with your teachers and parents so they can log in using their respective credentials.</p>
          <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;" />
          <p style="font-size: 12px; color: #64748b; margin: 0;">This is an automated message from Tartheeb Madrasa Management App. Please do not reply directly to this email.</p>
        </div>
      `
    };

    await transporter.sendMail(mailOptions);
    console.log(`[Email Success] Registration email successfully sent to ${toEmail}`);
    return true;
  } catch (err) {
    console.error('[Email Error] Failed to send SMTP email:', err);
    return false;
  }
}
const app = express();
const PORT = process.env.PORT || 8081;

// Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(express.text({
  type: (req) => {
    return req.path.startsWith('/iclock');
  },
  limit: '10mb'
}));
app.get(['/', '/index.html'], (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, max-age=0');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.use(express.static(path.join(__dirname, 'public'), {
  etag: false,
  maxAge: 0,
  setHeaders: (res, path) => {
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
  }
}));

// Request logger middleware to diagnose device URL paths
app.use((req, res, next) => {
  const method = req.method;
  const url = req.url;
  let body = req.body;
  
  // Format body if it is an object
  if (typeof body === 'object' && body !== null) {
    body = JSON.stringify(body);
  }

  try {
    const fs = require('fs');
    const logMsg = `\n--- [${new Date().toISOString()}] ${method} ${url} ---\nHeaders: ${JSON.stringify(req.headers)}\nBody: ${body}\n`;
    fs.appendFileSync(path.join(__dirname, 'all_requests.log'), logMsg);
  } catch (e) { /* ignore */ }

  console.log(`[HTTP Request] ${method} ${url}`);
  next();
});

// Setup Multer for Excel file uploads
const upload = multer({ storage: multer.memoryStorage() });

let db;

// Helper to format Date/Time
function getLocalDateString(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function getLocalTimeString(date = new Date()) {
  return date.toTimeString().split(' ')[0]; // HH:MM:SS
}

function getLocalTimestampString(date = new Date()) {
  return `${getLocalDateString(date)} ${getLocalTimeString(date)}`;
}

function getAbsoluteCheckinStartTime(startTimeStr, offsetMinutesStr) {
  if (!startTimeStr) return '00:00:00';
  if (!offsetMinutesStr) return '00:00:00';
  
  // If it's already an absolute time format (like '08:00:00'), return it directly
  if (offsetMinutesStr.includes(':')) {
    return offsetMinutesStr;
  }

  const offsetMinutes = parseInt(offsetMinutesStr, 10);
  if (isNaN(offsetMinutes)) return '00:00:00';

  const parts = startTimeStr.split(':');
  const h = parseInt(parts[0] || '0', 10);
  const m = parseInt(parts[1] || '0', 10);
  const s = parseInt(parts[2] || '0', 10);
  
  const startSeconds = (h * 3600) + (m * 60) + s;
  let startOffsetSeconds = startSeconds - (offsetMinutes * 60);

  if (startOffsetSeconds < 0) startOffsetSeconds = 0; // limit to midnight

  const outH = Math.floor(startOffsetSeconds / 3600);
  const outM = Math.floor((startOffsetSeconds % 3600) / 60);
  const outS = startOffsetSeconds % 60;

  return `${String(outH).padStart(2, '0')}:${String(outM).padStart(2, '0')}:${String(outS).padStart(2, '0')}`;
}

// Database Connection
// Database Connection
async function connectDb() {
  db = await open({
    filename: path.join(__dirname, 'attendance.db'),
    driver: sqlite3.Database
  });
  await db.run('PRAGMA foreign_keys = ON');

  // 0. Create users table and seed official account
  await db.run(`
    CREATE TABLE IF NOT EXISTS users (
      username TEXT PRIMARY KEY,
      password TEXT NOT NULL,
      madrasa_name TEXT DEFAULT 'My Madrasa',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Migrate users to add columns if they don't exist
  try {
    await db.run(`ALTER TABLE users ADD COLUMN madrasa_name TEXT DEFAULT 'My Madrasa'`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'staff'`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN permissions TEXT DEFAULT ''`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'active'`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN plan_name TEXT DEFAULT 'Pro'`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN plan_expiry TEXT DEFAULT ''`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN payment_status TEXT DEFAULT 'paid'`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN phone TEXT DEFAULT ''`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN place TEXT DEFAULT ''`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE users ADD COLUMN biometric_enabled INTEGER DEFAULT 1`);
  } catch (e) { /* already exists */ }

  // Seed Super Admin Master Account
  const superAdminUsername = 'thartheeb@786';
  const _cryptoModule = require('crypto');
  const superAdminPassword = _cryptoModule.createHash('sha256').update('Thartheeb@786').digest('hex');
  await db.run(`
    INSERT INTO users (username, password, madrasa_name, role, status, plan_name, payment_status)
    VALUES (?, ?, 'Thartheeb Master Command', 'superadmin', 'active', 'Enterprise', 'paid')
    ON CONFLICT(username) DO UPDATE SET
      role = 'superadmin',
      status = 'active',
      password = excluded.password
  `, [superAdminUsername, superAdminPassword]);



  // 1. Create shifts table
  await db.run(`
    CREATE TABLE IF NOT EXISTS shifts (
      shift_id TEXT PRIMARY KEY,
      shift_name TEXT,
      start_time TEXT,
      end_time TEXT DEFAULT '17:00:00',
      grace_minutes INTEGER DEFAULT 15,
      checkin_start TEXT DEFAULT '00:00:00',
      checkin_end TEXT DEFAULT '23:59:59',
      is_flexible INTEGER DEFAULT 0,
      alt_day TEXT,
      alt_start_time TEXT,
      alt_end_time TEXT DEFAULT '13:00:00',
      alt_checkin_start TEXT,
      alt_checkin_end TEXT
    )
  `);

  try {
    await db.run("ALTER TABLE shifts ADD COLUMN end_time TEXT DEFAULT '17:00:00'");
  } catch (e) { /* already exists */ }

  try {
    await db.run("ALTER TABLE shifts ADD COLUMN alt_end_time TEXT DEFAULT '13:00:00'");
  } catch (e) { /* already exists */ }

  // Seed UNORGANIZED fallback shift
  await db.run(`
    INSERT OR IGNORE INTO shifts (shift_id, shift_name, start_time, end_time, grace_minutes, checkin_start, checkin_end, is_flexible)
    VALUES ('UNORGANIZED', 'Unorganized / No Shift', '00:00:00', '23:59:59', 1440, '00:00:00', '23:59:59', 1)
  `);

  // 2. Create batches table and alter to add shift_id
  await db.run(`
    CREATE TABLE IF NOT EXISTS batches (
      batch_id TEXT PRIMARY KEY,
      batch_name TEXT
    )
  `);

  try {
    await db.run(`ALTER TABLE batches ADD COLUMN shift_id TEXT`);
  } catch (e) { /* already exists */ }

  try {
    await db.run("ALTER TABLE shifts ADD COLUMN tenant_id TEXT");
  } catch (e) { /* already exists */ }

  try {
    await db.run("ALTER TABLE batches ADD COLUMN tenant_id TEXT");
  } catch (e) { /* already exists */ }

  // Migrating batches table to remove old columns if they exist
  try {
    const tableInfo = await db.all("PRAGMA table_info(batches)");
    const hasStartTime = tableInfo.some(col => col.name === 'start_time');
    if (hasStartTime) {
      console.log("Migrating batches table to remove old columns...");
      await db.run("ALTER TABLE batches RENAME TO batches_old");
      await db.run(`
        CREATE TABLE batches (
          batch_id TEXT PRIMARY KEY,
          batch_name TEXT,
          shift_id TEXT
        )
      `);
      await db.run(`
        INSERT OR IGNORE INTO batches (batch_id, batch_name, shift_id)
        SELECT batch_id, batch_name, shift_id FROM batches_old
      `);
      await db.run("DROP TABLE batches_old");
      console.log("Batches table migration complete!");
    }
  } catch (err) {
    console.error("Failed to run batches table cleanup migration:", err);
  }

  // Create students table if it doesn't exist
  await db.run(`
    CREATE TABLE IF NOT EXISTS students (
      user_id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      card_number TEXT,
      batch_id TEXT,
      role TEXT DEFAULT 'student',
      FOREIGN KEY (batch_id) REFERENCES batches(batch_id) ON DELETE SET NULL
    )
  `);

  // Add missing columns to students table if they don't exist
  const studentsCols = [
    { name: 'tenant_id', type: 'TEXT' },
    { name: 'admission_date', type: 'TEXT' },
    { name: 'roll_number', type: 'TEXT' },
    { name: 'gender', type: 'TEXT' },
    { name: 'dob', type: 'TEXT' },
    { name: 'caste', type: 'TEXT' },
    { name: 'father', type: 'TEXT' },
    { name: 'mother', type: 'TEXT' },
    { name: 'primary_number', type: 'TEXT' },
    { name: 'secondary_number', type: 'TEXT' },
    { name: 'aadhar_number', type: 'TEXT' },
    { name: 'school_name', type: 'TEXT' },
    { name: 'monthly_fee', type: 'REAL' },
    { name: 'password', type: 'TEXT' },
    { name: 'address', type: 'TEXT' },
    { name: 'photo', type: 'TEXT' },
    { name: 'age', type: 'TEXT' },
    { name: 'school_going_time', type: 'TEXT' },
    { name: 'school_return_time', type: 'TEXT' },
    { name: 'salary', type: 'REAL DEFAULT 0' },
    { name: 'attendance_mode', type: 'TEXT DEFAULT \'single\'' },
    { name: 'permissions', type: 'TEXT DEFAULT \'\'' }
  ];

  for (const col of studentsCols) {
    try {
      await db.run(`ALTER TABLE students ADD COLUMN ${col.name} ${col.type}`);
    } catch (err) {
      // Column already exists, ignore
    }
  }

  // Migrating students table to fix corrupted batches_old foreign key if exists
  try {
    const studentsSchemaRow = await db.get("SELECT sql FROM sqlite_master WHERE name='students'");
    if (studentsSchemaRow && studentsSchemaRow.sql.includes('batches_old')) {
      console.log("Migrating students table to fix corrupted foreign key reference...");
      await db.run("PRAGMA foreign_keys = OFF");
      await db.run("ALTER TABLE students RENAME TO students_old");
      await db.run(`
        CREATE TABLE students (
          user_id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          card_number TEXT,
          batch_id TEXT,
          FOREIGN KEY (batch_id) REFERENCES batches(batch_id) ON DELETE SET NULL
        )
      `);
      await db.run(`
        INSERT OR IGNORE INTO students (user_id, name, card_number, batch_id)
        SELECT user_id, name, card_number, batch_id FROM students_old
      `);
      await db.run("DROP TABLE students_old");
      await db.run("PRAGMA foreign_keys = ON");
      console.log("Students table foreign key migration complete!");
    }
  } catch (err) {
    console.error("Failed to run students table cleanup migration:", err);
  }

  // Auto-seed UNORGANIZED fallback batch
  await db.run(`
    INSERT OR IGNORE INTO batches (batch_id, batch_name, shift_id)
    VALUES (?, ?, ?)
  `, ['UNORGANIZED', 'Unorganized / No Batch', 'UNORGANIZED']);

  // Auto-migrate existing batch schedules to shifts table
  try {
    const existingBatches = await db.all("SELECT * FROM batches");
    for (const b of existingBatches) {
      if (b.batch_id === 'UNORGANIZED') {
        await db.run(`UPDATE batches SET shift_id = 'UNORGANIZED' WHERE batch_id = 'UNORGANIZED'`);
        continue;
      }

      if (!b.shift_id) {
        const generatedShiftId = `SHIFT_${b.batch_id}`;
        // Extract timing properties from batches table if they exist
        const start_time = b.start_time || '09:00:00';
        const grace_minutes = b.grace_minutes !== undefined ? b.grace_minutes : 15;
        const checkin_start = b.checkin_start || '08:00:00';
        const checkin_end = b.checkin_end || '10:30:00';
        const is_flexible = b.is_flexible !== undefined ? b.is_flexible : 0;
        const alt_day = b.alt_day || null;
        const alt_start_time = b.alt_start_time || null;
        const alt_checkin_start = b.alt_checkin_start || null;
        const alt_checkin_end = b.alt_checkin_end || null;

        // Insert into shifts
        await db.run(`
          INSERT OR IGNORE INTO shifts (
            shift_id, shift_name, start_time, grace_minutes, checkin_start, checkin_end,
            is_flexible, alt_day, alt_start_time, alt_checkin_start, alt_checkin_end
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `, [
          generatedShiftId, `${b.batch_name} Shift`, start_time, grace_minutes, checkin_start, checkin_end,
          is_flexible, alt_day, alt_start_time, alt_checkin_start, alt_checkin_end
        ]);

        // Link batch to shift
        await db.run(`UPDATE batches SET shift_id = ? WHERE batch_id = ?`, [generatedShiftId, b.batch_id]);
      }
    }
  } catch (err) {
    console.warn("Migration warning:", err.message);
  }

  // Create tables for fingerprints, devices, and remote commands
  await db.run(`
    CREATE TABLE IF NOT EXISTS devices (
      serial_number TEXT PRIMARY KEY,
      ip_address TEXT,
      device_name TEXT,
      last_seen TEXT,
      status TEXT,
      tenant_id TEXT
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS fingerprints (
      user_id TEXT,
      finger_id INTEGER,
      template_data TEXT,
      PRIMARY KEY(user_id, finger_id),
      FOREIGN KEY(user_id) REFERENCES students(user_id) ON DELETE CASCADE
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS device_commands (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_sn TEXT,
      command_text TEXT,
      status TEXT DEFAULT 'PENDING',
      created_at TEXT
    )
  `);

  // Create daily_attendance table if it does not exist
  await db.run(`
    CREATE TABLE IF NOT EXISTS daily_attendance (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      work_date TEXT NOT NULL,
      check_in TEXT NOT NULL,
      late_minutes INTEGER DEFAULT 0,
      attendance_status TEXT,
      remarks TEXT
    )
  `);

  // Migrate daily_attendance to add check_out and role if they don't exist
  try {
    await db.run(`ALTER TABLE daily_attendance ADD COLUMN check_out TEXT`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE daily_attendance ADD COLUMN role TEXT DEFAULT 'student'`);
  } catch (e) { /* already exists */ }
  try {
    await db.run(`ALTER TABLE daily_attendance ADD COLUMN batch_id TEXT`);
  } catch (e) { /* already exists */ }

  // Rebuild daily_attendance migration to support multi-shift teachers (changing unique constraint and null check_in)
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
    }
  } catch (err) {
    console.error("Failed to run daily_attendance constraint migration:", err);
  }

  // Migrate students to add role if it doesn't exist
  try {
    await db.run(`ALTER TABLE students ADD COLUMN role TEXT DEFAULT 'student'`);
  } catch (e) { /* already exists */ }

  // Create teacher_assignments table
  await db.run(`
    CREATE TABLE IF NOT EXISTS teacher_assignments (
      user_id TEXT,
      batch_id TEXT,
      shift_id TEXT,
      checkin_time TEXT,
      checkout_time TEXT,
      PRIMARY KEY (user_id, batch_id),
      FOREIGN KEY (user_id) REFERENCES students(user_id) ON DELETE CASCADE,
      FOREIGN KEY (batch_id) REFERENCES batches(batch_id) ON DELETE CASCADE
    )
  `);

  // Create habits table
  await db.run(`
    CREATE TABLE IF NOT EXISTS habits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      work_date TEXT NOT NULL,
      habit_name TEXT NOT NULL,
      status TEXT NOT NULL,
      remarks TEXT,
      UNIQUE(user_id, work_date, habit_name)
    )
  `);

  // Create prayers table
  await db.run(`
    CREATE TABLE IF NOT EXISTS prayers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      work_date TEXT NOT NULL,
      prayer_name TEXT NOT NULL,
      status TEXT NOT NULL,
      UNIQUE(user_id, work_date, prayer_name)
    )
  `);

  // Create fcm_tokens table for push notifications
  await db.run(`
    CREATE TABLE IF NOT EXISTS fcm_tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      fcm_token TEXT NOT NULL UNIQUE,
      device_type TEXT DEFAULT 'android',
      updated_at TEXT,
      FOREIGN KEY (user_id) REFERENCES students(user_id) ON DELETE CASCADE
    )
  `);

  // Create notification_logs table
  await db.run(`
    CREATE TABLE IF NOT EXISTS notification_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_value TEXT,
      sent_count INTEGER DEFAULT 0,
      created_at TEXT,
      tenant_id TEXT
    )
  `);

  // Create parent_checks table
  await db.run(`
    CREATE TABLE IF NOT EXISTS parent_checks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      work_date TEXT NOT NULL,
      check_name TEXT NOT NULL,
      status TEXT NOT NULL,
      UNIQUE(user_id, work_date, check_name)
    )
  `);

  // Create fees table
  await db.run(`
    CREATE TABLE IF NOT EXISTS fees (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      month TEXT NOT NULL,
      paid_amount REAL DEFAULT 0,
      status TEXT NOT NULL,
      payment_date TEXT,
      UNIQUE(user_id, month)
    )
  `);

  // Create student_additional_fees table
  await db.run(`
    CREATE TABLE IF NOT EXISTS student_additional_fees (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      fee_type TEXT NOT NULL,
      amount REAL DEFAULT 0,
      purpose TEXT NOT NULL,
      status TEXT DEFAULT 'PENDING',
      payment_date TEXT
    )
  `);

  // Create habit_definitions table
  await db.run(`
    CREATE TABLE IF NOT EXISTS habit_definitions (
      habit_id TEXT PRIMARY KEY,
      text_ml TEXT NOT NULL,
      text_en TEXT NOT NULL,
      tenant_id TEXT
    )
  `);

  // Add missing columns to habit_definitions table if they don't exist
  const habitDefCols = [
    { name: 'start_date', type: 'TEXT' },
    { name: 'end_date', type: 'TEXT' },
    { name: 'target_batch', type: 'TEXT' }
  ];
  for (const col of habitDefCols) {
    try {
      await db.run(`ALTER TABLE habit_definitions ADD COLUMN ${col.name} ${col.type}`);
    } catch (err) {
      // Column already exists, ignore
    }
  }

  console.log('Connected to SQLite Database, ran migrations, and verified UNORGANIZED fallback batch.');
}

// Initialize Database connection on server start
connectDb().catch(err => {
  console.error('Database connection failed:', err);
  process.exit(1);
});

// ==========================================
// ZKTECO / ESSL PUSH PROTOCOL ENDPOINTS
// ==========================================

/**
 * 1. Heartbeat check-in
 * Endpoint: GET /iclock/getrequest
 */
app.get(/getrequest/, async (req, res) => {
  const { SN, Stamp } = req.query;
  const ipAddress = req.ip || req.socket.remoteAddress;

  console.log(`[Heartbeat] Device SN: ${SN}, Stamp: ${Stamp}, IP: ${ipAddress}`);

  if (SN) {
    try {
      const nowStr = getLocalTimestampString();
      // Upsert device
      await db.run(`
        INSERT INTO devices (serial_number, ip_address, device_name, last_seen, status)
        VALUES (?, ?, ?, ?, 'ONLINE')
        ON CONFLICT(serial_number) DO UPDATE SET
          ip_address = excluded.ip_address,
          last_seen = excluded.last_seen,
          status = 'ONLINE'
      `, [SN, ipAddress, `Device-${SN.slice(-4)}`, nowStr]);
    } catch (err) {
      console.error('Error logging device heartbeat:', err);
    }
  }

  // Query pending commands for this device
  let commandResponse = 'OK';
  if (SN) {
    try {
      const cmd = await db.get(`
        SELECT id, command_text FROM device_commands
        WHERE device_sn = ? AND status = 'PENDING'
        ORDER BY id ASC LIMIT 1
      `, [SN]);

      if (cmd) {
        commandResponse = `C:${cmd.id}:${cmd.command_text}`;
        // Update status to SENT
        await db.run('UPDATE device_commands SET status = "SENT" WHERE id = ?', [cmd.id]);
        console.log(`[Command Sent] To Device SN: ${SN} -> Command: ${commandResponse}`);
      }
    } catch (err) {
      console.error('Error fetching device command:', err);
    }
  }

  res.setHeader('Content-Type', 'text/plain');
  res.send(commandResponse);
});

/**
 * 2. Event push
 * Endpoint: POST /iclock/cdata
 */
app.post(/cdata/, async (req, res) => {
  const { table, SN } = req.query;
  const payload = req.body;

  // Log incoming cdata payload for debugging
  try {
    const fs = require('fs');
    const logMsg = `\n--- [${new Date().toISOString()}] Table: ${table}, SN: ${SN} ---\n${payload}\n`;
    fs.appendFileSync(path.join(__dirname, 'cdata_debug.log'), logMsg);
  } catch (e) { /* ignore */ }

  console.log(`[Push Data Received] Table: ${table}, Device SN: ${SN}`);

  // Register device heartbeat from cdata request
  if (SN) {
    try {
      const nowStr = getLocalTimestampString();
      const ipAddress = req.ip || req.socket.remoteAddress;
      await db.run(`
        INSERT INTO devices (serial_number, ip_address, device_name, last_seen, status)
        VALUES (?, ?, ?, ?, 'ONLINE')
        ON CONFLICT(serial_number) DO UPDATE SET
          ip_address = excluded.ip_address,
          last_seen = excluded.last_seen,
          status = 'ONLINE'
      `, [SN, ipAddress, `Device-${SN.slice(-4)}`, nowStr]);
    } catch (err) {
      console.error('Error logging device connection from cdata:', err);
    }
  }

  if (!payload || typeof payload !== 'string') {
    res.setHeader('Content-Type', 'text/plain');
    return res.send('OK');
  }

  // Parse fingerprint templates (if device pushes templates)
  if (table === 'TEMPLATE' || table === 'template' || table === 'FINGERTMP' || table === 'fingertmp') {
    const lines = payload.trim().split('\n');
    console.log(`Received ${lines.length} fingerprint templates from device SN: ${SN}`);
    
    for (const line of lines) {
      if (!line.trim()) continue;
      const fields = line.split('\t');
      const userId = fields[0]?.trim();
      const fingerId = fields[1] ? parseInt(fields[1].trim()) : 0;
      const template = fields[2]?.trim();

      if (userId && template) {
        try {
          await db.run(`
            INSERT INTO fingerprints (user_id, finger_id, template_data)
            VALUES (?, ?, ?)
            ON CONFLICT(user_id, finger_id) DO UPDATE SET
              template_data = excluded.template_data
          `, [userId, fingerId, template]);
          console.log(`Saved Fingerprint for User ID: ${userId}, Finger index: ${fingerId}`);
        } catch (err) {
          console.error('Error saving fingerprint template:', err);
        }
      }
    }
    res.setHeader('Content-Type', 'text/plain');
    return res.send('OK');
  }

  // Parse user registration details from device
  if (table === 'USER' || table === 'user' || table === 'USERINFO' || table === 'userinfo') {
    const lines = payload.trim().split('\n');
    console.log(`Received ${lines.length} user registrations from device SN: ${SN}`);
    
    for (const line of lines) {
      if (!line.trim()) continue;
      const fields = line.split('\t');
      const userId = fields[0]?.trim();
      const name = fields[1]?.trim() || `User-${userId}`;
      const cardNumber = fields[3]?.trim() || '';

      if (userId) {
        try {
          const existing = await db.get('SELECT user_id FROM students WHERE user_id = ?', [userId]);
          if (!existing) {
            await db.run(`
              INSERT INTO students (user_id, name, card_number, batch_id)
              VALUES (?, ?, ?, 'UNORGANIZED')
            `, [userId, name, cardNumber]);
            console.log(`Auto-created Student Profile from device register: User ID ${userId}`);
          } else if (cardNumber) {
            await db.run(`
              UPDATE students SET card_number = ? WHERE user_id = ?
            `, [cardNumber, userId]);
          }
        } catch (err) {
          console.error('Error auto-registering user from device:', err);
        }
      }
    }
    res.setHeader('Content-Type', 'text/plain');
    return res.send('OK');
  }

  // Parse operation logs (some devices push users and fingerprints here)
  if (table === 'OPERLOG' || table === 'operlog') {
    const lines = payload.trim().split('\n');
    console.log(`Received ${lines.length} operation log entries from device SN: ${SN}`);
    
    let userCount = 0;
    let fpCount = 0;

    for (const line of lines) {
      if (!line.trim()) continue;
      
      if (line.startsWith('USER ')) {
        const cleanLine = line.substring(5); // strip "USER "
        const tokens = cleanLine.split('\t');
        const data = {};
        
        for (const token of tokens) {
          const eqIdx = token.indexOf('=');
          if (eqIdx !== -1) {
            const key = token.substring(0, eqIdx).trim().toLowerCase();
            const val = token.substring(eqIdx + 1).trim();
            data[key] = val;
          }
        }

        const userId = data.pin;
        const name = data.name || `User-${userId}`;
        const cardNumber = data.card || '';

        if (userId) {
          try {
            const existing = await db.get('SELECT user_id FROM students WHERE user_id = ?', [userId]);
            if (!existing) {
              await db.run(`
                INSERT INTO students (user_id, name, card_number, batch_id)
                VALUES (?, ?, ?, 'UNORGANIZED')
              `, [userId, name, cardNumber]);
              console.log(`Auto-created Student from OPERLOG USER: User ID ${userId}`);
            } else {
              await db.run(`
                UPDATE students SET name = ?, card_number = ? WHERE user_id = ?
              `, [name, cardNumber, userId]);
              console.log(`Updated Student from OPERLOG USER: User ID ${userId}`);
            }
            userCount++;
          } catch (err) {
            console.error('Error saving student from OPERLOG USER:', err);
          }
        }
      } else if (line.startsWith('FP ')) {
        const cleanLine = line.substring(3); // strip "FP "
        const tokens = cleanLine.split('\t');
        const data = {};
        
        for (const token of tokens) {
          const eqIdx = token.indexOf('=');
          if (eqIdx !== -1) {
            const key = token.substring(0, eqIdx).trim().toLowerCase();
            const val = token.substring(eqIdx + 1).trim();
            data[key] = val;
          }
        }

        const userId = data.pin;
        const fingerId = data.fid ? parseInt(data.fid) : 0;
        const template = data.tmp;

        if (userId && template) {
          try {
            await db.run(`
              INSERT INTO fingerprints (user_id, finger_id, template_data)
              VALUES (?, ?, ?)
              ON CONFLICT(user_id, finger_id) DO UPDATE SET
                template_data = excluded.template_data
            `, [userId, fingerId, template]);
            console.log(`Saved Fingerprint from OPERLOG FP: User ID ${userId}, Finger index ${fingerId}`);
            fpCount++;
          } catch (err) {
            console.error('Error saving fingerprint from OPERLOG FP:', err);
          }
        }
      }
    }

    console.log(`[OPERLOG Parsed] Successfully synced ${userCount} users and ${fpCount} fingerprints.`);
    res.setHeader('Content-Type', 'text/plain');
    return res.send('OK');
  }

  if (table !== 'ATTLOG') {
    res.setHeader('Content-Type', 'text/plain');
    return res.send('OK');
  }

  if (!payload || typeof payload !== 'string') {
    res.setHeader('Content-Type', 'text/plain');
    return res.send('OK');
  }

  const lines = payload.trim().split('\n');
  console.log(`Parsing ${lines.length} lines of attendance logs...`);

  for (const line of lines) {
    if (!line.trim()) continue;

    // Fields are separated by horizontal tabs (\t)
    const fields = line.split('\t');
    
    // Check-in record format: PIN \t Time \t VerifyState \t VerifyMode \t WorkCode
    const userId = fields[0]?.trim();
    const punchTimeStr = fields[1]?.trim(); // YYYY-MM-DD HH:MM:SS
    const punchState = fields[2] ? parseInt(fields[2].trim()) : 0;
    const verifyMode = fields[3] ? parseInt(fields[3].trim()) : 0;

    if (!userId || !punchTimeStr) {
      console.log(`Skipping invalid line: ${line}`);
      continue;
    }

    try {
      // 1. Insert into raw punches (allow insert or ignore to prevent unique constraint error aborting processing)
      await db.run(`
        INSERT OR IGNORE INTO raw_punches (user_id, device_sn, punch_time, verify_mode, punch_state)
        VALUES (?, ?, ?, ?, ?)
      `, [userId, SN, punchTimeStr, verifyMode, punchState]);

      console.log(`Processed Raw Punch (Ingested): User ID ${userId} at ${punchTimeStr}`);

      // 2. Query student profile and active shift rules through batches (select role column and shift_id)
      const student = await db.get(`
        SELECT s.user_id, s.name, s.batch_id, s.role, s.attendance_mode,
               sh.shift_id, sh.start_time, sh.grace_minutes, sh.checkin_start, sh.checkin_end,
               sh.is_flexible, sh.alt_day, sh.alt_start_time, sh.alt_checkin_start, sh.alt_checkin_end
        FROM students s
        LEFT JOIN batches b ON s.batch_id = b.batch_id
        LEFT JOIN shifts sh ON b.shift_id = sh.shift_id
        WHERE s.roll_number = ? OR s.user_id = ? OR s.card_number = ?
      `, [userId, userId, userId]);

      if (!student) {
        console.warn(`[Verification Failed] User ID ${userId} has not been uploaded to the software database yet. Skipping attendance marking.`);
        continue;
      }

      // 3. Resolve check-in / check-out
      const punchDate = punchTimeStr.split(' ')[0]; // YYYY-MM-DD
      const punchTime = punchTimeStr.split(' ')[1]; // HH:MM:SS

      if (student.role === 'teacher') {
        const assignments = await db.all(`
          SELECT ta.*, sh.start_time as shift_start, sh.end_time as shift_end, sh.is_flexible, sh.alt_day, sh.alt_start_time, sh.alt_end_time
          FROM teacher_assignments ta
          LEFT JOIN shifts sh ON ta.shift_id = sh.shift_id
          WHERE ta.user_id = ?
        `, [student.user_id]);

        let matchedBatch = 'UNORGANIZED';
        let matchedShift = 'UNORGANIZED';
        let matchedTime = '09:00:00';
        let isCheckoutPunch = false;

        const [ph, pm, ps] = punchTime.split(':').map(Number);
        const punchSeconds = (ph * 3600) + (pm * 60) + (ps || 0);

        const attMode = student.attendance_mode || 'single';

        if (attMode === 'single') {
          let earliestCiSec = Infinity;
          let latestCoSec = -Infinity;
          let earliestCiStr = '09:00:00';
          let latestCoStr = '17:00:00';

          if (assignments && assignments.length > 0) {
            const dateParts = punchDate.split('-');
            const punchDateObj = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
            const dayOfWeek = punchDateObj.toLocaleDateString('en-US', { weekday: 'long' });

            assignments.forEach(a => {
              let expectedCheckin, expectedCheckout;
              if (a.alt_day && dayOfWeek.toLowerCase() === a.alt_day.toLowerCase()) {
                expectedCheckin = a.alt_start_time || a.shift_start || '09:00:00';
                expectedCheckout = a.alt_end_time || '13:00:00';
              } else {
                expectedCheckin = a.shift_start || a.checkin_time || '09:00:00';
                expectedCheckout = a.shift_end || a.checkout_time || '17:00:00';
              }

              const [ciH, ciM, ciS] = expectedCheckin.split(':').map(Number);
              const ciSec = (ciH * 3600) + (ciM * 60) + (ciS || 0);
              if (ciSec < earliestCiSec) {
                earliestCiSec = ciSec;
                earliestCiStr = expectedCheckin;
              }

              const [coH, coM, coS] = expectedCheckout.split(':').map(Number);
              const coSec = (coH * 3600) + (coM * 60) + (coS || 0);
              if (coSec > latestCoSec) {
                latestCoSec = coSec;
                latestCoStr = expectedCheckout;
              }
            });
          }

          if (earliestCiSec === Infinity) earliestCiSec = 9 * 3600;
          if (latestCoSec === -Infinity) latestCoSec = 17 * 3600;

          const ciDiff = Math.abs(punchSeconds - earliestCiSec);
          const coDiff = Math.abs(punchSeconds - latestCoSec);

          if (ciDiff < coDiff) {
            isCheckoutPunch = false;
            matchedTime = earliestCiStr;
          } else {
            isCheckoutPunch = true;
            matchedTime = latestCoStr;
          }
          matchedBatch = 'DAILY_OVERALL';
        } else {
          if (assignments && assignments.length > 0) {
            let minDiff = Infinity;
            const dateParts = punchDate.split('-');
            const punchDateObj = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
            const dayOfWeek = punchDateObj.toLocaleDateString('en-US', { weekday: 'long' });

            assignments.forEach(a => {
              let expectedCheckin, expectedCheckout;
              if (a.alt_day && dayOfWeek.toLowerCase() === a.alt_day.toLowerCase()) {
                expectedCheckin = a.alt_start_time || a.shift_start || '09:00:00';
                expectedCheckout = a.alt_end_time || '13:00:00';
              } else {
                expectedCheckin = a.shift_start || a.checkin_time || '09:00:00';
                expectedCheckout = a.shift_end || a.checkout_time || '17:00:00';
              }

              // Check-in difference
              const [ciH, ciM, ciS] = expectedCheckin.split(':').map(Number);
              const expectedCiSec = (ciH * 3600) + (ciM * 60) + (ciS || 0);
              const ciDiff = Math.abs(punchSeconds - expectedCiSec);

              if (ciDiff < minDiff) {
                minDiff = ciDiff;
                matchedBatch = a.batch_id;
                matchedShift = a.shift_id;
                matchedTime = expectedCheckin;
                isCheckoutPunch = false;
              }

              // Check-out difference
              const [coH, coM, coS] = expectedCheckout.split(':').map(Number);
              const expectedCoSec = (coH * 3600) + (coM * 60) + (coS || 0);
              const coDiff = Math.abs(punchSeconds - expectedCoSec);

              if (coDiff < minDiff) {
                minDiff = coDiff;
                matchedBatch = a.batch_id;
                matchedShift = a.shift_id;
                matchedTime = expectedCheckout;
                isCheckoutPunch = true;
              }
            });
          }
        }

        // Look for existing attendance for this teacher, date, and matchedBatch
        const existingAttendance = await db.get(`
          SELECT * FROM daily_attendance
          WHERE user_id = ? AND work_date = ? AND batch_id = ?
        `, [student.user_id, punchDate, matchedBatch]);

        if (!isCheckoutPunch) {
          // Check-in
          if (!existingAttendance) {
            const [startH, startM, startS] = matchedTime.split(':').map(Number);
            const expectedSeconds = (startH * 3600) + (startM * 60) + (startS || 0);
            const diffMinutes = Math.floor((punchSeconds - expectedSeconds) / 60);
            const graceMinutes = 10;

            let status = 'Present';
            let lateMinutes = 0;
            if (diffMinutes > graceMinutes) {
              status = 'Late';
              lateMinutes = diffMinutes;
            }

            let remarkMsg = attMode === 'single' ? `Teacher Checked In (Daily Overall)` : `Teacher Checked In (Batch: ${matchedBatch})`;
            if (status === 'Late') {
              remarkMsg = attMode === 'single' ? `Teacher Late by ${lateMinutes} mins (Daily Overall)` : `Teacher Late by ${lateMinutes} mins (Batch: ${matchedBatch})`;
            }

            await db.run(`
              INSERT INTO daily_attendance (user_id, work_date, check_in, check_out, late_minutes, attendance_status, remarks, role, batch_id)
              VALUES (?, ?, ?, NULL, ?, ?, ?, 'teacher', ?)
            `, [student.user_id, punchDate, punchTimeStr, lateMinutes, status, remarkMsg, matchedBatch]);
            
            console.log(`[Teacher Ingestion] Checked In for batch ${matchedBatch}. status: ${status}`);
          } else {
            console.log(`[Teacher Ingestion] Check-in already exists for batch ${matchedBatch}. Ignoring duplicate.`);
          }
        } else {
          // Check-out
          if (existingAttendance) {
            const [endH, endM, endS] = matchedTime.split(':').map(Number);
            const expectedSeconds = (endH * 3600) + (endM * 60) + (endS || 0);
            const leftEarlyMinutes = Math.floor((expectedSeconds - punchSeconds) / 60);

            let remarkMsg = attMode === 'single' ? `Teacher Checked Out (Daily Overall)` : `Teacher Checked Out (Batch: ${matchedBatch})`;
            if (leftEarlyMinutes > 0) {
              remarkMsg = attMode === 'single' ? `Teacher Left Early by ${leftEarlyMinutes} mins (Daily Overall)` : `Teacher Left Early by ${leftEarlyMinutes} mins (Batch: ${matchedBatch})`;
            }

            await db.run(`
              UPDATE daily_attendance
              SET check_out = ?, remarks = ?
              WHERE id = ?
            `, [punchTimeStr, remarkMsg, existingAttendance.id]);

            console.log(`[Teacher Ingestion] Checked Out for batch ${matchedBatch} at ${punchTimeStr}`);
          } else {
            // Checked out without checking in first
            let remarkMsg = attMode === 'single' ? `Teacher Checked Out (No Check-in, Daily Overall)` : `Teacher Checked Out (No Check-in, Batch: ${matchedBatch})`;
            await db.run(`
              INSERT INTO daily_attendance (user_id, work_date, check_in, check_out, late_minutes, attendance_status, remarks, role, batch_id)
              VALUES (?, ?, NULL, ?, 0, 'Present', ?, 'teacher', ?)
            `, [student.user_id, punchDate, punchTimeStr, remarkMsg, matchedBatch]);
            
            console.log(`[Teacher Ingestion] Checked Out (No Check-in) for batch ${matchedBatch} at ${punchTimeStr}`);
          }
        }
        continue;
      }

      // Check if attendance already recorded for this student today
      const existingAttendance = await db.get(`
        SELECT id FROM daily_attendance
        WHERE user_id = ? AND work_date = ?
      `, [student.user_id, punchDate]);

      if (existingAttendance) {
        console.log(`Attendance already marked for Student ${student.name} (${student.user_id}) on ${punchDate}. Ignoring duplicate punch.`);
        continue;
      }

      // Validate if batch rules are set
      if (!student.start_time || !student.checkin_start || !student.checkin_end) {
        // No batch associated, mark as "Present" directly
        await db.run(`
          INSERT INTO daily_attendance (user_id, work_date, check_in, late_minutes, attendance_status, remarks, role, batch_id)
          VALUES (?, ?, ?, ?, ?, ?, 'student', ?)
        `, [student.user_id, punchDate, punchTimeStr, 0, 'Present', 'No Batch Configured', student.batch_id || 'UNORGANIZED']);
        console.log(`[Attendance Marked] ${student.name} (${student.user_id}) marked Present (No Batch Config).`);
        continue;
      }

      // Resolve whether to use standard timings or alternate day timings
      let startTime = student.start_time;
      let checkinStart = getAbsoluteCheckinStartTime(student.start_time, student.checkin_start);
      let checkinEnd = student.checkin_end;
      let isAltDay = false;

      // If flexible timing is checked, the check-in window is open all day (allowing them to mark attendance at any time), but we still calculate lateness relative to start_time
      if (student.is_flexible === 1) {
        checkinStart = '00:00:00';
        checkinEnd = '23:59:59';
      }

      if (student.alt_day) {
        const [yr, mo, dy] = punchDate.split('-').map(Number);
        const dateObj = new Date(yr, mo - 1, dy);
        const daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const punchDayName = daysOfWeek[dateObj.getDay()];

        if (punchDayName.toLowerCase() === student.alt_day.toLowerCase() && student.alt_start_time) {
          startTime = student.alt_start_time;
          checkinStart = getAbsoluteCheckinStartTime(student.alt_start_time, student.alt_checkin_start || student.checkin_start);
          checkinEnd = student.alt_checkin_end || checkinEnd;
          isAltDay = true;
        }
      }

      // Check if punch falls before the check-in start window (Early punch)
      if (punchTime < checkinStart) {
        await db.run(`
          INSERT INTO daily_attendance (user_id, work_date, check_in, late_minutes, attendance_status, remarks, role, batch_id)
          VALUES (?, ?, ?, ?, ?, ?, 'student', ?)
        `, [student.user_id, punchDate, punchTimeStr, 0, 'Early', 'Punched before limit', student.batch_id || 'UNORGANIZED']);
        console.log(`[Attendance Marked] ${student.name} (${student.user_id}) marked Early (Punched before limit: ${punchTime}).`);
      } else {
        // Calculate late minutes relative to shift start_time
        const [startH, startM, startS] = startTime.split(':').map(Number);
        const [punchH, punchM, punchS] = punchTime.split(':').map(Number);
        
        const expectedSeconds = (startH * 3600) + (startM * 60) + (startS || 0);
        const punchSeconds = (punchH * 3600) + (punchM * 60) + (punchS || 0);
        
        const diffMinutes = Math.floor((punchSeconds - expectedSeconds) / 60);
        const graceMinutes = (student.grace_minutes !== undefined && student.grace_minutes !== null) ? student.grace_minutes : 10;
        
        let status = 'Present';
        let lateMinutes = 0;
        
        const isFallback = (student.shift_id === 'UNORGANIZED' || !student.shift_id);
        if (!isFallback && diffMinutes > graceMinutes) {
          status = 'Late';
          lateMinutes = Math.min(diffMinutes, 180); // Cap lateness to 180 mins maximum
        }

        let remarkMsg = 'On Time';
        if (status === 'Late') {
          remarkMsg = `Late by ${lateMinutes} mins`;
        } else if (isAltDay) {
          remarkMsg = 'On Time (Alt Schedule)';
        }

        await db.run(`
          INSERT INTO daily_attendance (user_id, work_date, check_in, late_minutes, attendance_status, remarks, role, batch_id)
          VALUES (?, ?, ?, ?, ?, ?, 'student', ?)
        `, [student.user_id, punchDate, punchTimeStr, lateMinutes, status, remarkMsg, student.batch_id || 'UNORGANIZED']);

        console.log(`[Attendance Marked] ${student.name} (${student.user_id}) marked ${status}. Lateness: ${lateMinutes} mins`);

        // Trigger Automated Push Notification Alert to Parent
        try {
          const notifyTitle = status === 'Late' ? '⚠️ Student Late Arrival Alert' : '✅ Attendance Marked';
          const notifyBody = status === 'Late' 
            ? `${student.name} arrived late at madrasa at ${punchTimeStr} (Late by ${lateMinutes} mins).`
            : `${student.name} has arrived at madrasa and attendance was marked at ${punchTimeStr}.`;
          
          sendPushNotification(student.user_id, notifyTitle, notifyBody, {
            type: 'attendance_alert',
            status: status,
            check_in: punchTimeStr,
            work_date: punchDate
          });
        } catch (nErr) {
          console.error('[Push Alert Error]', nErr);
        }
      }

    } catch (err) {
      if (err.message && err.message.includes('UNIQUE constraint failed')) {
        console.log(`Duplicate punch ignored for User ID ${userId} at ${punchTimeStr}`);
      } else {
        console.error('Error resolving attendance logic:', err);
        try {
          const fs = require('fs');
          const errorMsg = `\n--- [${new Date().toISOString()}] Error resolving attendance for User ${userId} at ${punchTimeStr} ---\n${err.stack || err.message || err}\n`;
          fs.appendFileSync(path.join(__dirname, 'server_errors.log'), errorMsg);
        } catch (e) { /* ignore */ }
      }
    }
  }

  // Response must be plain text 'OK'
  res.setHeader('Content-Type', 'text/plain');
  res.send('OK');
});

// ==========================================
// SYSTEM APIS FOR STUDENT & REPORT MANAGEMENT
// ==========================================

/**
 * 3. Excel Import Endpoint
 * Endpoint: POST /api/students/import
 */
app.post('/api/students/import', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No Excel file provided' });
  }

  const { tenant_id } = req.query;

  try {
    const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const data = xlsx.utils.sheet_to_json(sheet);

    console.log(`Received Excel sheet with ${data.length} records. Tenant ID: ${tenant_id}`);
    let importCount = 0;

    // Load existing batches for smart normalization matching
    const dbBatches = await db.all('SELECT batch_id, batch_name FROM batches');

    for (const row of data) {
      // Expect columns: "User ID", "Name", "Card Number", "Batch ID"
      const userId = String(row['User ID'] || row['userId'] || '').trim();
      const name = String(row['Name'] || row['name'] || '').trim();
      const cardNumber = String(row['Card Number'] || row['cardNumber'] || '').trim();
      const batchId = String(row['Batch ID'] || row['batchId'] || '').trim();

      if (!userId || !name) {
        console.warn('Skipping row due to missing User ID or Name:', row);
        continue;
      }

      // Verify if batch exists (matching by either Batch ID or Batch Name with numeric padding check)
      let activeBatch = 'UNORGANIZED';
      if (batchId) {
        const matched = dbBatches.find(b => {
          const bidLower = b.batch_id.toLowerCase();
          const bnameLower = (b.batch_name || '').toLowerCase();
          const xlLower = batchId.toLowerCase();

          if (bidLower === xlLower || bnameLower === xlLower) return true;

          // Numeric normalization match (e.g. '01' matches '1')
          const dbIdNum = parseInt(b.batch_id, 10);
          const xlIdNum = parseInt(batchId, 10);
          if (!isNaN(dbIdNum) && !isNaN(xlIdNum) && dbIdNum === xlIdNum) return true;

          return false;
        });

        if (matched) {
          activeBatch = matched.batch_id;
        } else {
          // Auto-create unrecognized batch on the fly
          console.log(`[Auto-creating Batch] Batch "${batchId}" not found, creating on the fly...`);
          await db.run(`
            INSERT OR IGNORE INTO batches (batch_id, batch_name, shift_id, tenant_id)
            VALUES (?, ?, 'UNORGANIZED', ?)
          `, [batchId, batchId, tenant_id || null]);
          activeBatch = batchId;
          dbBatches.push({ batch_id: batchId, batch_name: batchId });
        }
      }

      await db.run(`
        INSERT INTO students (user_id, name, card_number, batch_id, tenant_id)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
          name = excluded.name,
          card_number = excluded.card_number,
          batch_id = excluded.batch_id,
          tenant_id = COALESCE(excluded.tenant_id, students.tenant_id)
      `, [userId, name, cardNumber, activeBatch, tenant_id || null]);

      importCount++;
    }

    res.json({ success: true, message: `Successfully imported/updated ${importCount} student records.` });
  } catch (err) {
    console.error('Error importing Excel data:', err);
    res.status(500).json({ error: 'Failed to process Excel import', details: err.message });
  }
});

/**
 * 4. Get active devices
 * Endpoint: GET /api/devices
 */
app.get('/api/devices', async (req, res) => {
  try {
    const devices = await db.all('SELECT * FROM devices ORDER BY last_seen DESC');
    res.json(devices);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/devices', async (req, res) => {
  const { serial_number, device_name, tenant_id } = req.body;
  if (!serial_number) {
    return res.status(400).json({ error: 'Missing Device Serial Number.' });
  }
  try {
    const nowStr = getLocalTimestampString();
    await db.run(`
      INSERT INTO devices (serial_number, device_name, tenant_id, last_seen, status)
      VALUES (?, ?, ?, ?, 'OFFLINE')
      ON CONFLICT(serial_number) DO UPDATE SET
        device_name = COALESCE(excluded.device_name, devices.device_name),
        tenant_id = COALESCE(excluded.tenant_id, devices.tenant_id)
    `, [serial_number.trim(), device_name ? device_name.trim() : `Device-${serial_number.slice(-4)}`, tenant_id || null, nowStr]);
    res.json({ success: true, message: 'Device successfully registered.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/devices/:serial_number', async (req, res) => {
  const { serial_number } = req.params;
  try {
    await db.run('DELETE FROM devices WHERE serial_number = ?', [serial_number]);
    res.json({ success: true, message: 'Device successfully removed.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 5. Get registered students
 * Endpoint: GET /api/students
 */
app.get('/api/students', async (req, res) => {
  const { tenant_id } = req.query;
  try {
    if (tenant_id) {
      const tenantUser = await db.get('SELECT status, biometric_enabled FROM users WHERE LOWER(username) = LOWER(?)', [tenant_id]);
      if (tenantUser && (tenantUser.status === 'suspended' || tenantUser.status === 'disabled')) {
        return res.status(403).json({ error: 'Madrasa account access is suspended.' });
      }
    }
    let query = `
      SELECT s.*, b.batch_name,
             (SELECT COUNT(*) FROM fingerprints f WHERE f.user_id = s.user_id) as fp_count
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.batch_id
    `;
    const params = [];
    if (tenant_id) {
      query += ' WHERE s.tenant_id = ?';
      params.push(tenant_id);
    }
    query += ' ORDER BY CAST(s.user_id AS INTEGER) ASC';
    
    const students = await db.all(query, params);
    res.json(students);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 6. Get Attendance Report for a specific date
 * Endpoint: GET /api/attendance
 * Query: ?date=YYYY-MM-DD
 */
app.get('/api/attendance', async (req, res) => {
  const targetDate = req.query.date || getLocalDateString();
  const tenant_id = req.query.tenant_id;

  try {
    // 1. Get all students with their batch details, fingerprint count, and assigned teacher (ONLY role = 'student' or null/empty)
    let students;
    if (tenant_id) {
      students = await db.all(`
        SELECT s.user_id, s.name, s.roll_number, s.card_number, s.batch_id, b.batch_name,
               (SELECT COUNT(*) FROM fingerprints f WHERE f.user_id = s.user_id) as fp_count,
               (SELECT s2.name FROM teacher_assignments ta JOIN students s2 ON ta.user_id = s2.user_id WHERE ta.batch_id = s.batch_id LIMIT 1) as teacher_name
        FROM students s
        LEFT JOIN batches b ON s.batch_id = b.batch_id
        WHERE (s.role = 'student' OR s.role IS NULL OR s.role = '') AND s.tenant_id = ?
        ORDER BY CAST(s.user_id AS INTEGER) ASC
      `, [tenant_id]);
    } else {
      students = await db.all(`
        SELECT s.user_id, s.name, s.roll_number, s.card_number, s.batch_id, b.batch_name,
               (SELECT COUNT(*) FROM fingerprints f WHERE f.user_id = s.user_id) as fp_count,
               (SELECT s2.name FROM teacher_assignments ta JOIN students s2 ON ta.user_id = s2.user_id WHERE ta.batch_id = s.batch_id LIMIT 1) as teacher_name
        FROM students s
        LEFT JOIN batches b ON s.batch_id = b.batch_id
        WHERE s.role = 'student' OR s.role IS NULL OR s.role = ''
        ORDER BY CAST(s.user_id AS INTEGER) ASC
      `);
    }

    // 2. Get attendance logs recorded for that date
    const attendanceLogs = await db.all(`
      SELECT user_id, check_in, check_out, late_minutes, attendance_status, remarks
      FROM daily_attendance
      WHERE work_date = ?
    `, [targetDate]);

    // Map logs for constant time lookup
    const logsMap = new Map();
    attendanceLogs.forEach(log => logsMap.set(log.user_id, log));

    // 3. Compile report matching student database with incoming logs
    const report = students.map(student => {
      const log = logsMap.get(student.user_id);
      
      return {
        userId: student.user_id,
        rollNumber: student.roll_number,
        admissionNumber: /^s-\d+/.test(student.user_id) ? '' : student.user_id,
        name: student.name,
        cardNumber: student.card_number,
        hasFingerprint: student.fp_count > 0,
        batchName: student.batch_name || 'N/A',
        teacherName: student.teacher_name || 'None',
        checkInTime: log ? log.check_in.split(' ')[1] : '-',
        lateMinutes: log ? log.late_minutes : 0,
        status: log ? log.attendance_status : 'Absent',
        remarks: log ? log.remarks : 'No punch recorded'
      };
    });

    // 4. Get active teachers for each batch on that date
    let activeTeachers;
    if (tenant_id) {
      activeTeachers = await db.all(`
        SELECT ta.batch_id, s.name as teacher_name, s.user_id, da.check_in, da.check_out, da.attendance_status
        FROM teacher_assignments ta
        JOIN students s ON ta.user_id = s.user_id
        LEFT JOIN daily_attendance da ON ta.user_id = da.user_id AND (ta.batch_id = da.batch_id OR da.batch_id = 'DAILY_OVERALL') AND da.work_date = ?
        WHERE s.role = 'teacher' AND s.tenant_id = ?
      `, [targetDate, tenant_id]);
    } else {
      activeTeachers = await db.all(`
        SELECT ta.batch_id, s.name as teacher_name, s.user_id, da.check_in, da.check_out, da.attendance_status
        FROM teacher_assignments ta
        JOIN students s ON ta.user_id = s.user_id
        LEFT JOIN daily_attendance da ON ta.user_id = da.user_id AND (ta.batch_id = da.batch_id OR da.batch_id = 'DAILY_OVERALL') AND da.work_date = ?
        WHERE s.role = 'teacher'
      `, [targetDate]);
    }

    // 5. Get all batches with their shift details
    let dbBatches;
    if (tenant_id) {
      dbBatches = await db.all(`
        SELECT b.batch_id, b.batch_name, b.shift_id, s.shift_name, s.start_time
        FROM batches b
        LEFT JOIN shifts s ON b.shift_id = s.shift_id
        WHERE b.tenant_id = ?
      `, [tenant_id]);
    } else {
      dbBatches = await db.all(`
        SELECT b.batch_id, b.batch_name, b.shift_id, s.shift_name, s.start_time
        FROM batches b
        LEFT JOIN shifts s ON b.shift_id = s.shift_id
      `);
    }

    // Compile batch-specific statistics
    const batchStats = dbBatches.map(b => {
      const batchStudents = report.filter(r => r.batchName === b.batch_name || (b.batch_id === 'UNORGANIZED' && r.batchName === 'N/A'));
      const teachersForBatch = activeTeachers.filter(t => t.batch_id === b.batch_id);
      
      let scheduleType = 'Morning';
      let label = 'Morning Schedule';
      if (b.start_time) {
        const hour = parseInt(b.start_time.split(':')[0], 10);
        if (hour >= 12) {
          scheduleType = 'Evening';
          label = 'Evening Schedule';
        }
      } else {
        scheduleType = 'Morning';
        label = 'General Schedule';
      }

      const total = batchStudents.length;
      const present = batchStudents.filter(r => r.status === 'Present' || r.status === 'Late' || r.status === 'Early').length;
      const late = batchStudents.filter(r => r.status === 'Late').length;
      const absent = total - present;

      return {
        batchId: b.batch_id,
        batchName: b.batch_name,
        shiftName: b.shift_name || 'No Shift',
        startTime: b.start_time || 'N/A',
        scheduleType,
        label,
        totalStudents: total,
        presentCount: present,
        lateCount: late,
        absentCount: absent,
        students: batchStudents.map(s => ({
          userId: s.userId,
          rollNumber: s.rollNumber,
          admissionNumber: s.admissionNumber,
          name: s.name,
          cardNumber: s.cardNumber,
          checkInTime: s.checkInTime,
          status: s.status,
          lateMinutes: s.lateMinutes
        })),
        teachers: teachersForBatch.map(t => ({
          userId: t.user_id,
          name: t.teacher_name,
          checkInTime: t.check_in ? t.check_in.split(' ')[1] : null,
          checkOutTime: t.check_out ? t.check_out.split(' ')[1] : null,
          status: t.check_in ? (t.check_out ? 'Checked Out' : 'Available') : 'Offline'
        }))
      };
    });

    // 6. Query teacher logs for today
    const dbTeachers = await db.all(`
      SELECT user_id, name FROM students WHERE role = 'teacher'
    `);
    const teacherNameMap = new Map();
    dbTeachers.forEach(t => {
      teacherNameMap.set(t.user_id, t.name);
    });

    // Get all teacher-batch assignments with per-batch attendance
    const teachersAssLogs = await db.all(`
      SELECT ta.user_id, ta.batch_id, b.batch_name, da.check_in, da.check_out, da.attendance_status
      FROM teacher_assignments ta
      JOIN batches b ON ta.batch_id = b.batch_id
      LEFT JOIN daily_attendance da ON ta.user_id = da.user_id AND ta.batch_id = da.batch_id AND da.work_date = ?
      WHERE ta.user_id IN (SELECT user_id FROM students WHERE role = 'teacher')
    `, [targetDate]);

    // Build one row per teacher-batch assignment
    const teacherBatchRows = [];
    const teachersWithAssignments = new Set();

    teachersAssLogs.forEach(log => {
      teachersWithAssignments.add(log.user_id);
      const row = {
        userId: log.user_id,
        name: teacherNameMap.get(log.user_id) || log.user_id,
        batchName: log.batch_name || 'Unknown',
        checkInTime: null,
        checkOutTime: null,
        status: 'Absent'
      };
      if (log.check_in) {
        row.checkInTime = log.check_in.includes(' ') ? log.check_in.split(' ')[1] : log.check_in;
        row.status = log.attendance_status || 'Present';
      }
      if (log.check_out) {
        row.checkOutTime = log.check_out.includes(' ') ? log.check_out.split(' ')[1] : log.check_out;
      }
      teacherBatchRows.push(row);
    });

    // Also check DAILY_OVERALL attendance for teachers (applies check-in to all their batch rows)
    const teacherDailyAtt = await db.all(`
      SELECT user_id, check_in, check_out, attendance_status
      FROM daily_attendance
      WHERE work_date = ? AND (batch_id = 'DAILY_OVERALL') AND user_id IN (SELECT user_id FROM students WHERE role = 'teacher')
    `, [targetDate]);

    teacherDailyAtt.forEach(da => {
      // Apply overall check-in to all batch rows for this teacher (if they don't have per-batch attendance)
      teacherBatchRows.forEach(row => {
        if (row.userId === da.user_id && !row.checkInTime && da.check_in) {
          row.checkInTime = da.check_in.includes(' ') ? da.check_in.split(' ')[1] : da.check_in;
          row.checkOutTime = da.check_out ? (da.check_out.includes(' ') ? da.check_out.split(' ')[1] : da.check_out) : null;
          row.status = da.attendance_status || 'Present';
        }
      });
    });

    // Teachers with no assignments get a single row
    dbTeachers.forEach(t => {
      if (!teachersWithAssignments.has(t.user_id)) {
        teacherBatchRows.push({
          userId: t.user_id,
          name: t.name,
          batchName: 'No Assignment',
          checkInTime: null,
          checkOutTime: null,
          status: 'Absent'
        });
      }
    });

    const teacherRecords = teacherBatchRows;

    res.json({
      date: targetDate,
      totalStudents: students.length,
      presentCount: report.filter(r => r.status === 'Present' || r.status === 'Late' || r.status === 'Early').length,
      absentCount: report.filter(r => r.status === 'Absent').length,
      lateCount: report.filter(r => r.status === 'Late').length,
      records: report,
      batchStats,
      teacherLogs: teacherRecords
    });

  } catch (err) {
    console.error('Error fetching attendance report:', err);
    res.status(500).json({ error: 'Failed to compile attendance report.' });
  }
});

/**
 * 6b. Post Manual Attendance updates for multiple students
 * Endpoint: POST /api/attendance/manual
 */
app.post('/api/attendance/manual', async (req, res) => {
  const { date, batch_id, records } = req.body;

  if (!date || !batch_id || !Array.isArray(records)) {
    return res.status(400).json({ error: 'Missing required parameters: date, batch_id, and records array.' });
  }

  try {
    // Start transaction for consistency
    await db.run('BEGIN TRANSACTION');

    for (const rec of records) {
      const { user_id, status } = rec;
      if (!user_id || !status) continue;

      let checkIn = null;
      let checkOut = null;

      if (status === 'Present') {
        checkIn = `${date} 09:00:00`;
        checkOut = `${date} 10:30:00`;
      } else if (status === 'Late') {
        checkIn = `${date} 09:15:00`;
        checkOut = `${date} 10:30:00`;
      }

      await db.run(`
        INSERT INTO daily_attendance (user_id, work_date, check_in, check_out, attendance_status, remarks, role, batch_id)
        VALUES (?, ?, ?, ?, ?, 'Manual Entry', 'student', ?)
        ON CONFLICT(user_id, work_date, batch_id) DO UPDATE SET
          check_in = excluded.check_in,
          check_out = excluded.check_out,
          attendance_status = excluded.attendance_status,
          remarks = excluded.remarks
      `, [user_id, date, checkIn, checkOut, status, batch_id]);
    }

    await db.run('COMMIT');
    res.json({ success: true, message: 'Manual attendance log saved successfully.' });
  } catch (err) {
    try { await db.run('ROLLBACK'); } catch(e) {}
    console.error('Error saving manual attendance:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * 7. Get all batches
 * Endpoint: GET /api/batches
 */
app.get('/api/batches', async (req, res) => {
  const { tenant_id } = req.query;
  try {
    let query = `
      SELECT b.batch_id, b.batch_name, b.shift_id, b.tenant_id, s.shift_name, s.start_time, s.grace_minutes, s.checkin_start, s.checkin_end, s.is_flexible, s.alt_day, s.alt_start_time, s.alt_checkin_start, s.alt_checkin_end
      FROM batches b
      LEFT JOIN shifts s ON b.shift_id = s.shift_id
    `;
    const params = [];
    if (tenant_id) {
      query += ' WHERE b.tenant_id = ?';
      params.push(tenant_id);
    }
    query += ' ORDER BY b.batch_id ASC';
    
    const batches = await db.all(query, params);
    res.json(batches);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/batches', async (req, res) => {
  const { batch_id, batch_name, shift_id, tenant_id, old_batch_id } = req.body;

  if (!batch_id || !batch_name) {
    return res.status(400).json({ error: 'Missing required batch fields (batch_id, batch_name)' });
  }

  const finalShiftId = shift_id ? shift_id.trim() : 'UNORGANIZED';

  try {
    if (old_batch_id && old_batch_id.trim() !== batch_id.trim()) {
      // Verify new Batch ID is not duplicate
      const existing = await db.get('SELECT batch_id FROM batches WHERE batch_id = ?', [batch_id]);
      if (existing) {
        return res.status(400).json({ error: 'New Batch ID is already taken.' });
      }

      await db.run('UPDATE batches SET batch_id = ?, batch_name = ?, shift_id = ?, tenant_id = ? WHERE batch_id = ?', [batch_id, batch_name, finalShiftId, tenant_id || null, old_batch_id]);
      await db.run('UPDATE students SET batch_id = ? WHERE batch_id = ?', [batch_id, old_batch_id]);
      await db.run('UPDATE teachers SET batch_id = ? WHERE batch_id = ?', [batch_id, old_batch_id]);
      await db.run('UPDATE daily_attendance SET batch_id = ? WHERE batch_id = ?', [batch_id, old_batch_id]);
    } else {
      await db.run(`
        INSERT INTO batches (batch_id, batch_name, shift_id, tenant_id)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(batch_id) DO UPDATE SET
          batch_name = excluded.batch_name,
          shift_id = excluded.shift_id,
          tenant_id = excluded.tenant_id
      `, [batch_id, batch_name, finalShiftId, tenant_id || null]);
    }

    res.json({ success: true, message: `Batch ${batch_name} successfully saved.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/batches/:batch_id', async (req, res) => {
  const { batch_id } = req.params;
  if (batch_id === 'UNORGANIZED') {
    return res.status(400).json({ error: 'Cannot delete fallback batch.' });
  }
  try {
    await db.run('UPDATE students SET batch_id = "UNORGANIZED" WHERE batch_id = ?', [batch_id]);
    await db.run('DELETE FROM batches WHERE batch_id = ?', [batch_id]);
    res.json({ success: true, message: 'Batch deleted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// === SHIFTS ENDPOINTS ===

app.get('/api/shifts', async (req, res) => {
  const { tenant_id } = req.query;
  try {
    let query = 'SELECT * FROM shifts';
    const params = [];
    if (tenant_id) {
      query += ' WHERE tenant_id = ?';
      params.push(tenant_id);
    }
    query += ' ORDER BY shift_id ASC';
    const shifts = await db.all(query, params);
    res.json(shifts);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/shifts', async (req, res) => {
  const {
    shift_id, shift_name, start_time, end_time, grace_minutes, checkin_start, checkin_end,
    is_flexible, alt_day, alt_start_time, alt_end_time, alt_checkin_start, alt_checkin_end, tenant_id, old_shift_id
  } = req.body;

  if (!shift_id || !shift_name || !start_time || !checkin_start || !checkin_end) {
    return res.status(400).json({ error: 'Missing required shift fields' });
  }

  const normalizeTime = (t) => {
    if (!t) return null;
    t = t.trim();
    if (!t) return null;

    // If it's a plain number (minutes offset), return it directly
    if (/^\d+$/.test(t)) {
      return t;
    }

    // Check if 12-hour AM/PM format is present
    const ampmMatch = t.match(/^(\d{1,2}):(\d{2})\s*([aApP][mM])$/);
    if (ampmMatch) {
      let hours = parseInt(ampmMatch[1], 10);
      const minutes = ampmMatch[2];
      const ampm = ampmMatch[3].toUpperCase();

      if (ampm === 'PM' && hours < 12) {
        hours += 12;
      } else if (ampm === 'AM' && hours === 12) {
        hours = 0;
      }
      return `${String(hours).padStart(2, '0')}:${minutes}:00`;
    }

    const parts = t.split(':');
    if (parts.length === 2) {
      return `${parts[0].padStart(2, '0')}:${parts[1].padStart(2, '0')}:00`;
    }
    if (parts.length === 3) {
      return `${parts[0].padStart(2, '0')}:${parts[1].padStart(2, '0')}:${parts[2].padStart(2, '0')}`;
    }
    return t;
  };

  const norm_start = normalizeTime(start_time);
  const norm_end = normalizeTime(end_time || '17:00 PM');
  const norm_checkin_start = normalizeTime(checkin_start);
  const norm_checkin_end = normalizeTime(checkin_end);
  const norm_alt_start = normalizeTime(alt_start_time);
  const norm_alt_end = normalizeTime(alt_end_time || '13:00 PM');
  const norm_alt_checkin_start = normalizeTime(alt_checkin_start);
  const norm_alt_checkin_end = normalizeTime(alt_checkin_end);

  try {
    if (old_shift_id && old_shift_id.trim() !== shift_id.trim()) {
      // Verify new Shift ID is not duplicate
      const existing = await db.get('SELECT shift_id FROM shifts WHERE shift_id = ?', [shift_id]);
      if (existing) {
        return res.status(400).json({ error: 'New Shift ID is already taken.' });
      }

      await db.run(`
        UPDATE shifts SET
          shift_id = ?, shift_name = ?, start_time = ?, end_time = ?, grace_minutes = ?, checkin_start = ?, checkin_end = ?,
          is_flexible = ?, alt_day = ?, alt_start_time = ?, alt_end_time = ?, alt_checkin_start = ?, alt_checkin_end = ?, tenant_id = ?
        WHERE shift_id = ?
      `, [
        shift_id, shift_name, norm_start, norm_end, grace_minutes || 15, norm_checkin_start, norm_checkin_end,
        is_flexible ? 1 : 0, alt_day || null, norm_alt_start, norm_alt_end, norm_alt_checkin_start, norm_alt_checkin_end,
        tenant_id || null, old_shift_id
      ]);

      await db.run('UPDATE batches SET shift_id = ? WHERE shift_id = ?', [shift_id, old_shift_id]);
    } else {
      await db.run(`
        INSERT INTO shifts (
          shift_id, shift_name, start_time, end_time, grace_minutes, checkin_start, checkin_end,
          is_flexible, alt_day, alt_start_time, alt_end_time, alt_checkin_start, alt_checkin_end, tenant_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(shift_id) DO UPDATE SET
          shift_name = excluded.shift_name,
          start_time = excluded.start_time,
          end_time = excluded.end_time,
          grace_minutes = excluded.grace_minutes,
          checkin_start = excluded.checkin_start,
          checkin_end = excluded.checkin_end,
          is_flexible = excluded.is_flexible,
          alt_day = excluded.alt_day,
          alt_start_time = excluded.alt_start_time,
          alt_end_time = excluded.alt_end_time,
          alt_checkin_start = excluded.alt_checkin_start,
          alt_checkin_end = excluded.alt_checkin_end,
          tenant_id = excluded.tenant_id
      `, [
        shift_id, shift_name, norm_start, norm_end, grace_minutes || 15, norm_checkin_start, norm_checkin_end,
        is_flexible ? 1 : 0, alt_day || null, norm_alt_start, norm_alt_end, norm_alt_checkin_start, norm_alt_checkin_end,
        tenant_id || null
      ]);
    }

    res.json({ success: true, message: `Shift ${shift_name} successfully saved.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/shifts/:shift_id', async (req, res) => {
  const { shift_id } = req.params;
  if (shift_id === 'UNORGANIZED') {
    return res.status(400).json({ error: 'Cannot delete fallback shift.' });
  }
  try {
    await db.run('UPDATE batches SET shift_id = "UNORGANIZED" WHERE shift_id = ?', [shift_id]);
    await db.run('DELETE FROM shifts WHERE shift_id = ?', [shift_id]);
    res.json({ success: true, message: 'Shift deleted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/teachers/assignments', async (req, res) => {
  try {
    const assignments = await db.all(`
      SELECT ta.*, s.name as teacher_name, b.batch_name, sh.shift_name
      FROM teacher_assignments ta
      JOIN students s ON ta.user_id = s.user_id
      JOIN batches b ON ta.batch_id = b.batch_id
      LEFT JOIN shifts sh ON ta.shift_id = sh.shift_id
    `);
    res.json(assignments);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/register', async (req, res) => {
  const { username, password, madrasa_name, admin_name, institution_code, phone, place } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  try {
    const cleanUsername = username.trim().toLowerCase();
    const cleanMadrasa = madrasa_name ? madrasa_name.trim() : 'My Madrasa';
    const existing = await db.get('SELECT username FROM users WHERE username = ?', [cleanUsername]);
    if (existing) {
      return res.status(400).json({ error: 'Username is already taken' });
    }

    const crypto = require('crypto');
    const hashed = crypto.createHash('sha256').update(password).digest('hex');
    
    // Check if this is the first user registering
    const userCount = await db.get('SELECT COUNT(*) as count FROM users');
    const isFirstUser = (!userCount || userCount.count === 0);
    
    if (isFirstUser) {
      await db.run(`
        INSERT INTO users (username, password, madrasa_name, role, permissions, phone, place) 
        VALUES (?, ?, ?, 'admin', 'view_dashboard,manage_roster,manage_settings,generate_reports,student_reports,biometric_actions', ?, ?)
      `, [cleanUsername, hashed, cleanMadrasa, phone || '', place || '']);
    } else {
      await db.run('INSERT INTO users (username, password, madrasa_name, role, permissions, phone, place) VALUES (?, ?, ?, \'staff\', \'\', ?, ?)', [cleanUsername, hashed, cleanMadrasa, phone || '', place || '']);
    }
    
    // Trigger async email notification (won't block register route response if SMTP times out)
    const cleanAdminName = admin_name ? admin_name.trim() : 'Admin';
    const cleanInstCode = institution_code ? institution_code.trim() : 'M' + String(Date.now()).slice(-5);
    sendRegistrationEmail(cleanUsername, cleanMadrasa, cleanAdminName, cleanInstCode).catch(e => {
      console.error('SMTP Background Dispatch Error:', e);
    });

    res.json({ success: true, message: 'Registration successful! You can now log in.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  try {
    const cleanUsername = username.trim().toLowerCase();
    const user = await db.get('SELECT * FROM users WHERE LOWER(username) = ?', [cleanUsername]);
    if (!user) {
      return res.status(400).json({ error: 'Invalid username or password' });
    }

    // Check account status
    if (user.role !== 'superadmin' && (user.status === 'disabled' || user.status === 'suspended')) {
      return res.status(403).json({ error: 'Your Madrasa account access is suspended or disabled. Please contact Super Admin.' });
    }

    const crypto = require('crypto');
    const hashed = crypto.createHash('sha256').update(password).digest('hex');
    if (user.password !== hashed) {
      return res.status(400).json({ error: 'Invalid username or password' });
    }

    res.json({ 
      success: true, 
      username: user.username, 
      madrasa_name: user.madrasa_name || 'My Madrasa', 
      role: user.role || 'staff',
      permissions: user.permissions || '',
      status: user.status || 'active',
      plan_name: user.plan_name || 'Pro',
      biometric_enabled: (user.biometric_enabled === 0 || user.biometric_enabled === '0') ? 0 : 1,
      message: 'Login successful!' 
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/member-login', async (req, res) => {
  const { role, username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }
  try {
    const cleanUsername = (username || '').trim().toLowerCase();
    const cleanPassword = (password || '').trim();

    if (role === 'teacher') {
      // Query teacher by user_id OR email (card_number) with case-insensitive and trimmed matching
      const teacher = await db.get(`
        SELECT s.*, b.batch_name, u.madrasa_name FROM students s
        LEFT JOIN batches b ON s.batch_id = b.batch_id
        LEFT JOIN users u ON s.tenant_id = u.username
        WHERE s.role = 'teacher' 
          AND (LOWER(TRIM(s.user_id)) = ? OR LOWER(TRIM(s.card_number)) = ?) 
          AND TRIM(s.password) = ?
      `, [cleanUsername, cleanUsername, cleanPassword]);
      if (teacher) {
        return res.json({ success: true, member: teacher });
      }
    } else if (role === 'parent') {
      // Query student by user_id OR roll_number with case-insensitive matching
      const student = await db.get(`
        SELECT s.*, b.batch_name, u.madrasa_name FROM students s
        LEFT JOIN batches b ON s.batch_id = b.batch_id
        LEFT JOIN users u ON s.tenant_id = u.username
        WHERE (s.role = 'student' OR s.role IS NULL OR s.role = '') 
          AND (LOWER(TRIM(s.user_id)) = ? OR LOWER(TRIM(s.roll_number)) = ?) 
          AND TRIM(s.password) = ?
      `, [cleanUsername, cleanUsername, cleanPassword]);
      if (student) {
        return res.json({ success: true, member: student });
      }
    }
    res.status(401).json({ error: 'Invalid ID or Password' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin authorization middleware
async function isAdmin(req, res, next) {
  const requester = req.headers['x-requester-username'];
  if (!requester) {
    return res.status(401).json({ error: 'Unauthorized. Requester header missing.' });
  }
  try {
    const user = await db.get('SELECT role FROM users WHERE username = ?', [requester.trim().toLowerCase()]);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden. Admin access required.' });
    }
    next();
  } catch (err) {
    res.status(500).json({ error: 'Authorization error.' });
  }
}

// Get all users (Admin only)
app.get('/api/users', isAdmin, async (req, res) => {
  try {
    const users = await db.all('SELECT username, role, permissions, madrasa_name, created_at FROM users ORDER BY username ASC');
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create new user (Admin only)
app.post('/api/users', isAdmin, async (req, res) => {
  const { username, password, role, permissions, madrasa_name } = req.body;
  if (!username || !password || !role) {
    return res.status(400).json({ error: 'Username, password, and role are required' });
  }
  try {
    const cleanUsername = username.trim().toLowerCase();
    const existing = await db.get('SELECT username FROM users WHERE username = ?', [cleanUsername]);
    if (existing) {
      return res.status(400).json({ error: 'Username is already taken' });
    }
    const crypto = require('crypto');
    const hashed = crypto.createHash('sha256').update(password).digest('hex');
    const cleanMadrasa = madrasa_name ? madrasa_name.trim() : 'My Madrasa';
    
    await db.run('INSERT INTO users (username, password, role, permissions, madrasa_name) VALUES (?, ?, ?, ?, ?)', [
      cleanUsername, hashed, role, permissions || '', cleanMadrasa
    ]);
    res.json({ success: true, message: 'User account created successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update user details (Admin only)
app.put('/api/users/:username', isAdmin, async (req, res) => {
  const { username } = req.params;
  const { password, role, permissions, madrasa_name } = req.body;
  try {
    const cleanUsername = username.trim().toLowerCase();
    const user = await db.get('SELECT * FROM users WHERE username = ?', [cleanUsername]);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const cleanMadrasa = madrasa_name ? madrasa_name.trim() : user.madrasa_name;
    const cleanRole = role || user.role;
    const cleanPerms = permissions !== undefined ? permissions : user.permissions;

    if (password && password.trim() !== '') {
      const crypto = require('crypto');
      const hashed = crypto.createHash('sha256').update(password).digest('hex');
      await db.run('UPDATE users SET password = ?, role = ?, permissions = ?, madrasa_name = ? WHERE username = ?', [
        hashed, cleanRole, cleanPerms, cleanMadrasa, cleanUsername
      ]);
    } else {
      await db.run('UPDATE users SET role = ?, permissions = ?, madrasa_name = ? WHERE username = ?', [
        cleanRole, cleanPerms, cleanMadrasa, cleanUsername
      ]);
    }
    res.json({ success: true, message: 'User account updated successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete user account (Admin only)
app.delete('/api/users/:username', isAdmin, async (req, res) => {
  const { username } = req.params;
  const cleanUsername = username.trim().toLowerCase();
  
  if (cleanUsername === 'qubamadrasavaduthala@gmail.com') {
    return res.status(400).json({ error: 'Cannot delete the master admin account.' });
  }

  const requester = req.headers['x-requester-username'].trim().toLowerCase();
  if (cleanUsername === requester) {
    return res.status(400).json({ error: 'Cannot delete your own logged-in account.' });
  }

  try {
    await db.run('DELETE FROM users WHERE username = ?', [cleanUsername]);
    res.json({ success: true, message: 'User account deleted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/teachers/assignments', async (req, res) => {
  const { user_id, batch_id, shift_id, checkin_time, checkout_time } = req.body;

  if (!user_id || !batch_id) {
    return res.status(400).json({ error: 'Missing required assignment fields (user_id, batch_id)' });
  }

  try {
    await db.run(`
      INSERT INTO teacher_assignments (user_id, batch_id, shift_id, checkin_time, checkout_time)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(user_id, batch_id) DO UPDATE SET
        shift_id = excluded.shift_id,
        checkin_time = excluded.checkin_time,
        checkout_time = excluded.checkout_time
    `, [user_id, batch_id, shift_id || null, checkin_time || null, checkout_time || null]);

    res.json({ success: true, message: 'Teacher assignment saved successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/teachers/assignments/:user_id/:batch_id', async (req, res) => {
  const { user_id, batch_id } = req.params;
  try {
    await db.run('DELETE FROM teacher_assignments WHERE user_id = ? AND batch_id = ?', [user_id, batch_id]);
    res.json({ success: true, message: 'Teacher assignment deleted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/teachers/assignments/:user_id', async (req, res) => {
  const { user_id } = req.params;
  try {
    await db.run('DELETE FROM teacher_assignments WHERE user_id = ?', [cleanUserId]);
    res.json({ success: true, message: 'All assignments for teacher deleted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.1. Create or Update a Single Student / Teacher
 * Endpoint: POST /api/students
 */
app.post('/api/students', async (req, res) => {
  const {
    old_user_id, user_id, name, card_number, batch_id, role,
    admission_date, roll_number, gender, dob, caste,
    father, mother, primary_number, secondary_number, aadhar_number,
    school_name, monthly_fee, password, address, photo, age,
    school_going_time, school_return_time, additional_fees
  } = req.body;

  if (!user_id || !name) {
    return res.status(400).json({ error: 'Missing User ID or Name' });
  }

  try {
    const cleanUserId = String(user_id).trim();
    if (old_user_id && String(old_user_id).trim() !== cleanUserId) {
      const cleanOld = String(old_user_id).trim();
      // Safely migrate all historical attendance and related logs to new user_id
      await db.run('UPDATE daily_attendance SET user_id = ? WHERE user_id = ?', [cleanUserId, cleanOld]);
      try { await db.run('UPDATE parent_checks SET user_id = ? WHERE user_id = ?', [cleanUserId, cleanOld]); } catch(e){}
      try { await db.run('UPDATE habit_logs SET user_id = ? WHERE user_id = ?', [cleanUserId, cleanOld]); } catch(e){}
      try { await db.run('UPDATE fee_records SET user_id = ? WHERE user_id = ?', [cleanUserId, cleanOld]); } catch(e){}
      try { await db.run('UPDATE fingerprints SET user_id = ? WHERE user_id = ?', [cleanUserId, cleanOld]); } catch(e){}
      try { await db.run('UPDATE student_additional_fees SET user_id = ? WHERE user_id = ?', [cleanUserId, cleanOld]); } catch(e){}
      await db.run('DELETE FROM students WHERE user_id = ?', [cleanOld]);
    }

    const activeBatchId = batch_id ? batch_id.trim() : 'UNORGANIZED';
    const matchedBatch = await db.get('SELECT batch_id FROM batches WHERE batch_id = ? OR batch_name = ?', [activeBatchId, activeBatchId]);
    const finalBatch = matchedBatch ? matchedBatch.batch_id : 'UNORGANIZED';
    const finalRole = role ? role.trim() : 'student';

    await db.run(`
      INSERT INTO students (
        user_id, name, card_number, batch_id, role,
        admission_date, roll_number, gender, dob, caste,
        father, mother, primary_number, secondary_number, aadhar_number,
        school_name, monthly_fee, password, address, photo, age,
        school_going_time, school_return_time
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        name = excluded.name,
        card_number = excluded.card_number,
        batch_id = excluded.batch_id,
        role = excluded.role,
        admission_date = excluded.admission_date,
        roll_number = excluded.roll_number,
        gender = excluded.gender,
        dob = excluded.dob,
        caste = excluded.caste,
        father = excluded.father,
        mother = excluded.mother,
        primary_number = excluded.primary_number,
        secondary_number = excluded.secondary_number,
        aadhar_number = excluded.aadhar_number,
        school_name = excluded.school_name,
        monthly_fee = excluded.monthly_fee,
        password = excluded.password,
        address = excluded.address,
        photo = excluded.photo,
        age = excluded.age,
        school_going_time = excluded.school_going_time,
        school_return_time = excluded.school_return_time
    `, [
      String(user_id).trim(), String(name).trim(), String(card_number || '').trim(), finalBatch, finalRole,
      admission_date || '', roll_number || '', gender || '', dob || '', caste || '',
      father || '', mother || '', primary_number || '', secondary_number || '', aadhar_number || '',
      school_name || '', monthly_fee || 0, password || '', address || '', photo || '', age || '',
      school_going_time || '', school_return_time || ''
    ]);

    // Sync additional fees if provided
    if (additional_fees && Array.isArray(additional_fees)) {
      await db.run('DELETE FROM student_additional_fees WHERE user_id = ?', [String(user_id).trim()]);
      for (const f of additional_fees) {
        const feeId = f.id || 'fee-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
        await db.run(`
          INSERT INTO student_additional_fees (id, user_id, fee_type, amount, purpose, status, payment_date)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `, [feeId, String(user_id).trim(), f.fee_type, f.amount || 0, f.purpose || '', f.status || 'PENDING', f.payment_date || null]);
      }
    }

    res.json({ success: true, message: `Student/Teacher ${name} successfully saved.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * -------------------------------------------------------------
 * PUSH NOTIFICATION MODULE (FCM / BROADCAST / TRIGGERING)
 * -------------------------------------------------------------
 */

// Helper function to send push notification via FCM / WebPush / Expo
async function sendPushNotification(user_id, title, body, extraData = {}) {
  try {
    const tokens = await db.all('SELECT fcm_token FROM fcm_tokens WHERE user_id = ?', [user_id]);
    if (!tokens || tokens.length === 0) return { success: false, reason: 'No registered FCM token for user' };
    
    console.log(`[PUSH NOTIFICATION] Sending to user ${user_id} (${tokens.length} devices): "${title}" - "${body}"`);
    // Firebase Admin / FCM SDK call goes here.
    return { success: true, count: tokens.length };
  } catch (err) {
    console.error(`[PUSH NOTIFICATION ERROR] User: ${user_id}`, err);
    return { success: false, error: err.message };
  }
}

// 1. Register / Update FCM Device Token
app.post('/api/notifications/register-token', async (req, res) => {
  const { user_id, fcm_token, device_type } = req.body;
  if (!user_id || !fcm_token) {
    return res.status(400).json({ error: 'Missing user_id or fcm_token' });
  }
  try {
    const nowStr = getLocalTimestampString();
    await db.run(`
      INSERT INTO fcm_tokens (user_id, fcm_token, device_type, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(fcm_token) DO UPDATE SET
        user_id = excluded.user_id,
        device_type = excluded.device_type,
        updated_at = excluded.updated_at
    `, [String(user_id).trim(), String(fcm_token).trim(), device_type || 'android', nowStr]);
    res.json({ success: true, message: 'FCM Token registered successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 2. Admin Custom Notification / Broadcast Dispatcher Endpoint
app.post('/api/notifications/send-broadcast', async (req, res) => {
  const { title, body, target_type, target_value, tenant_id, month } = req.body;

  if (!title || !body || !target_type) {
    return res.status(400).json({ error: 'Missing title, body, or target_type' });
  }

  try {
    let targetUsers = [];
    
    if (target_type === 'all') {
      // All students and teachers in tenant
      let query = 'SELECT DISTINCT user_id FROM students';
      const params = [];
      if (tenant_id) {
        query += ' WHERE tenant_id = ?';
        params.push(tenant_id);
      }
      targetUsers = await db.all(query, params);
    } 
    else if (target_type === 'batch') {
      // Filter by Batch ID
      targetUsers = await db.all('SELECT DISTINCT user_id FROM students WHERE batch_id = ?', [target_value]);
    } 
    else if (target_type === 'individual') {
      // Specific list of user_ids (array or string)
      const userIds = Array.isArray(target_value) ? target_value : [target_value];
      const placeholders = userIds.map(() => '?').join(',');
      targetUsers = await db.all(`SELECT DISTINCT user_id FROM students WHERE user_id IN (${placeholders})`, userIds);
    } 
    else if (target_type === 'pending_fees') {
      // Filter students with pending fees for a specific month or generally
      const targetMonth = month || 'June';
      const paidRecords = await db.all('SELECT DISTINCT user_id FROM fee_records WHERE fee_month = ? AND status = \'PAID\'', [targetMonth]);
      const paidUserIds = paidRecords.map(r => r.user_id);
      
      let query = 'SELECT DISTINCT user_id FROM students';
      const params = [];
      if (tenant_id) {
        query += ' WHERE tenant_id = ?';
        params.push(tenant_id);
      }
      const allStudents = await db.all(query, params);
      targetUsers = allStudents.filter(s => !paidUserIds.includes(s.user_id));
    }

    const uniqueUserIds = [...new Set(targetUsers.map(u => u.user_id))];
    const nowStr = getLocalTimestampString();

    // Log notification in DB
    await db.run(`
      INSERT INTO notification_logs (title, body, target_type, target_value, sent_count, created_at, tenant_id)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `, [title, body, target_type, JSON.stringify(target_value || ''), uniqueUserIds.length, nowStr, tenant_id || '']);

    // Trigger push notification dispatch for target users
    let sentCount = 0;
    for (const uid of uniqueUserIds) {
      const resNotify = await sendPushNotification(uid, title, body, { type: 'admin_broadcast' });
      if (resNotify.success) sentCount++;
    }

    res.json({
      success: true,
      message: `Notification broadcast queued successfully for ${uniqueUserIds.length} target recipient(s).`,
      recipientsCount: uniqueUserIds.length,
      deviceDeliveries: sentCount
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 3. Fetch Notification History Logs
app.get('/api/notifications/logs', async (req, res) => {
  const { tenant_id } = req.query;
  try {
    let query = 'SELECT * FROM notification_logs';
    const params = [];
    if (tenant_id) {
      query += ' WHERE tenant_id = ?';
      params.push(tenant_id);
    }
    query += ' ORDER BY id DESC LIMIT 50';
    const logs = await db.all(query, params);
    res.json(logs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.1b. Get Additional Fees for a student
 * Endpoint: GET /api/students/:id/additional-fees
 */
app.get('/api/students/:id/additional-fees', async (req, res) => {
  const { id } = req.params;
  try {
    const fees = await db.all('SELECT * FROM student_additional_fees WHERE user_id = ?', [id]);
    res.json(fees);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.1c. Add Additional Fee for a student
 * Endpoint: POST /api/students/:id/additional-fees
 */
app.post('/api/students/:id/additional-fees', async (req, res) => {
  const { id } = req.params;
  const { purpose, amount, fee_type } = req.body;
  if (!purpose || amount === undefined || !fee_type) {
    return res.status(400).json({ error: 'Missing required parameters: purpose, amount, or fee_type' });
  }
  try {
    const feeId = 'fee-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
    await db.run(`
      INSERT INTO student_additional_fees (id, user_id, fee_type, amount, purpose, status, payment_date)
      VALUES (?, ?, ?, ?, ?, 'PENDING', null)
    `, [feeId, id, fee_type, amount, purpose]);
    res.json({ success: true, message: 'Additional fee added successfully.', id: feeId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.1d. Update Additional Fee Status
 * Endpoint: POST /api/fees/additional/:fee_id/status
 */
app.post('/api/fees/additional/:fee_id/status', async (req, res) => {
  const { fee_id } = req.params;
  const { status } = req.body;
  if (!status) {
    return res.status(400).json({ error: 'Missing status parameter' });
  }
  try {
    const paymentDate = status === 'PAID' ? new Date().toISOString().split('T')[0] : null;
    await db.run(`
      UPDATE student_additional_fees
      SET status = ?, payment_date = ?
      WHERE id = ?
    `, [status, paymentDate, fee_id]);
    res.json({ success: true, message: 'Additional fee status updated successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.1e. Delete Additional Fee
 * Endpoint: DELETE /api/fees/additional/:fee_id
 */
app.delete('/api/fees/additional/:fee_id', async (req, res) => {
  const { fee_id } = req.params;
  try {
    await db.run('DELETE FROM student_additional_fees WHERE id = ?', [fee_id]);
    res.json({ success: true, message: 'Additional fee deleted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.2. Trigger Fingerprint Enrollment on Device
 * Endpoint: POST /api/students/enroll-fp
 */
app.post('/api/students/enroll-fp', async (req, res) => {
  const { user_id, device_sn } = req.body;

  if (!user_id || !device_sn) {
    return res.status(400).json({ error: 'Missing User ID or Device Serial Number' });
  }

  try {
    // 1. Verify student exists
    const student = await db.get('SELECT name FROM students WHERE user_id = ?', [user_id]);
    if (!student) {
      return res.status(404).json({ error: 'Student/Teacher profile does not exist. Please save the profile first.' });
    }

    // 2. Queue command
    const nowStr = getLocalTimestampString();
    await db.run(`
      INSERT INTO device_commands (device_sn, command_text, status, created_at)
      VALUES (?, ?, 'PENDING', ?)
    `, [device_sn, `EnrollFP PIN=${user_id} FID=0`, nowStr]);

    console.log(`[Enrollment Queued] Fingerprint enrollment command queued for User ${user_id} on Device ${device_sn}`);
    res.json({ success: true, message: 'Fingerprint enrollment queued! Please scan finger 3 times when prompted on the machine.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.3. Get active command execution status (for polling)
 * Endpoint: GET /api/students/enroll-status
 */
app.get('/api/students/enroll-status', async (req, res) => {
  const { user_id } = req.query;

  if (!user_id) {
    return res.status(400).json({ error: 'Missing user_id query parameter' });
  }

  try {
    // Check if fingerprint is in the database
    const fp = await db.get('SELECT finger_id FROM fingerprints WHERE user_id = ? LIMIT 1', [user_id]);
    if (fp) {
      return res.json({ status: 'SUCCESS', message: 'Fingerprint successfully registered!' });
    }

    // Check if command is still pending or sent
    const cmd = await db.get(`
      SELECT status FROM device_commands
      WHERE command_text LIKE ? AND (status = 'PENDING' OR status = 'SENT')
      ORDER BY id DESC LIMIT 1
    `, [`%EnrollFP PIN=${user_id}%`]);

    if (cmd) {
      return res.json({ status: cmd.status, message: cmd.status === 'SENT' ? 'Please scan finger 3 times on the device...' : 'Waiting for device heartbeat...' });
    }

    res.json({ status: 'NOT_FOUND', message: 'No active enrollment process. Press enroll to start.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.4. Get all registered students
 * Endpoint: GET /api/students
 */
app.get('/api/students', async (req, res) => {
  const { tenant_id } = req.query;
  try {
    let query = `
      SELECT s.*, b.batch_name,
             (SELECT COUNT(*) FROM fingerprints f WHERE f.user_id = s.user_id) as fp_count
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.batch_id
    `;
    const params = [];
    if (tenant_id) {
      query += ' WHERE s.tenant_id = ?';
      params.push(tenant_id);
    }
    query += ' ORDER BY CAST(s.user_id AS INTEGER) ASC';
    
    const students = await db.all(query, params);
    res.json(students);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.6. Force device to upload all user info and templates to server
 * Endpoint: POST /api/devices/sync-from-device
 */
app.post('/api/devices/sync-from-device', async (req, res) => {
  const { device_sn } = req.body;

  if (!device_sn) {
    return res.status(400).json({ error: 'Missing Device Serial Number' });
  }

  try {
    const nowStr = getLocalTimestampString();
    
    // Queue USERINFO query command
    await db.run(`
      INSERT INTO device_commands (device_sn, command_text, status, created_at)
      VALUES (?, 'DATA QUERY USERINFO', 'PENDING', ?)
    `, [device_sn, nowStr]);

    // Queue FINGERTMP query command
    await db.run(`
      INSERT INTO device_commands (device_sn, command_text, status, created_at)
      VALUES (?, 'DATA QUERY FINGERTMP', 'PENDING', ?)
    `, [device_sn, nowStr]);

    // Queue ATTLOG query command to pull transaction logs history
    await db.run(`
      INSERT INTO device_commands (device_sn, command_text, status, created_at)
      VALUES (?, 'DATA QUERY ATTLOG', 'PENDING', ?)
    `, [device_sn, nowStr]);

    console.log(`[Device Sync Triggered] Queued DATA QUERY commands (USERINFO, FINGERTMP, ATTLOG) for Device: ${device_sn}`);
    res.json({ success: true, message: 'Sync command sent to machine. It will upload user list, fingerprints, and attendance logs shortly.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.6b. Push all user details and fingerprints from software to device
 * Endpoint: POST /api/devices/push-to-device
 */
app.post('/api/devices/push-to-device', async (req, res) => {
  const { device_sn } = req.body;
  if (!device_sn) {
    return res.status(400).json({ error: 'Missing Device Serial Number' });
  }

  try {
    const nowStr = getLocalTimestampString();
    
    // 1. Fetch all students & teachers
    const users = await db.all('SELECT user_id, name, card_number, role FROM students');
    
    let commandCount = 0;
    for (const u of users) {
      const privilege = (u.role === 'admin' || u.role === 'teacher') ? 3 : 0;
      const cleanCard = u.card_number || '';
      
      // Queue USERINFO update command
      const userCmd = `DATA UPDATE USERINFO PIN=${u.user_id}\tName=${u.name}\tCard=${cleanCard}\tPri=${privilege}\tPass=\tGroup=1`;
      await db.run(`
        INSERT INTO device_commands (device_sn, command_text, status, created_at)
        VALUES (?, ?, 'PENDING', ?)
      `, [device_sn, userCmd, nowStr]);
      commandCount++;

      // 2. Fetch fingerprints
      const fps = await db.all('SELECT finger_id, template_data FROM fingerprints WHERE user_id = ?', [u.user_id]);
      for (const fp of fps) {
        const size = fp.template_data ? fp.template_data.length : 0;
        
        // Queue templatev10 format
        const fpCmd1 = `DATA UPDATE templatev10 Pin=${u.user_id}\tFingerID=${fp.finger_id}\tSize=${size}\tValid=1\tTemplate=${fp.template_data}`;
        await db.run(`
          INSERT INTO device_commands (device_sn, command_text, status, created_at)
          VALUES (?, ?, 'PENDING', ?)
        `, [device_sn, fpCmd1, nowStr]);
        commandCount++;

        // Queue FINGERTMP format (as fallback)
        const fpCmd2 = `DATA UPDATE FINGERTMP PIN=${u.user_id}\tFingerID=${fp.finger_id}\tSize=${size}\tValid=1\tTMP=${fp.template_data}`;
        await db.run(`
          INSERT INTO device_commands (device_sn, command_text, status, created_at)
          VALUES (?, ?, 'PENDING', ?)
        `, [device_sn, fpCmd2, nowStr]);
        commandCount++;
      }
    }

    console.log(`[Device Push Triggered] Queued ${commandCount} update commands for Device: ${device_sn}`);
    res.json({ success: true, message: `Successfully queued ${commandCount} push commands to sync names, cards, and fingerprints back to the machine.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.6c. Push custom log range pull query to device
 * Endpoint: POST /api/devices/pull-logs-date-filtered
 */
app.post('/api/devices/pull-logs-date-filtered', async (req, res) => {
  const { device_sn, start_date, end_date } = req.body;
  if (!device_sn || !start_date || !end_date) {
    return res.status(400).json({ error: 'Missing Device Serial Number, Start Date, or End Date' });
  }

  try {
    const nowStr = getLocalTimestampString();
    
    // Command format for querying attendance logs in date range
    const queryCmd = `DATA QUERY ATTLOG StartTime=${start_date} 00:00:00\tEndTime=${end_date} 23:59:59`;
    
    await db.run(`
      INSERT INTO device_commands (device_sn, command_text, status, created_at)
      VALUES (?, ?, 'PENDING', ?)
    `, [device_sn, queryCmd, nowStr]);

    console.log(`[Device Log Range Query] Queued custom query: "${queryCmd}" for Device: ${device_sn}`);
    res.json({ success: true, message: `Successfully queued log pull command for date range ${start_date} to ${end_date}. The device will upload the logs shortly.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


/**
 * 8.7. Delete a student profile from software
 * Endpoint: DELETE /api/students/:id
 */
app.delete('/api/students/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await db.run('DELETE FROM students WHERE user_id = ?', [id]);
    res.json({ success: true, message: 'Student profile successfully deleted.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/students/bulk-delete', async (req, res) => {
  const { ids } = req.body;
  if (!ids || !Array.isArray(ids) || ids.length === 0) {
    return res.status(400).json({ error: 'No student IDs provided.' });
  }

  try {
    await db.run('BEGIN TRANSACTION');
    const placeholders = ids.map(() => '?').join(',');
    await db.run(`DELETE FROM students WHERE user_id IN (${placeholders})`, ids);
    await db.run('COMMIT');
    res.json({ success: true, message: `Successfully deleted ${ids.length} student records.` });
  } catch (err) {
    try {
      await db.run('ROLLBACK');
    } catch (rbErr) {}
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/teachers', async (req, res) => {
  const { tenant_id } = req.query;
  try {
    let query = 'SELECT * FROM students WHERE role = \'teacher\'';
    const params = [];
    if (tenant_id) {
      query += ' AND tenant_id = ?';
      params.push(tenant_id);
    }
    query += ' ORDER BY CAST(user_id AS INTEGER) ASC';
    const teachers = await db.all(query, params);

    // Fetch all teacher assignments for batches
    const assignments = await db.all(`
      SELECT ta.user_id, ta.batch_id, b.batch_name
      FROM teacher_assignments ta
      JOIN batches b ON ta.batch_id = b.batch_id
    `);

    const assignmentsMap = {};
    assignments.forEach(a => {
      if (!assignmentsMap[a.user_id]) {
        assignmentsMap[a.user_id] = [];
      }
      assignmentsMap[a.user_id].push({ id: a.batch_id, name: a.batch_name });
    });

    const result = teachers.map(t => {
      const assigned = assignmentsMap[t.user_id] || [];
      return {
        ...t,
        id: t.user_id,
        email: t.card_number,
        salary: t.salary || 0,
        attendance_mode: t.attendance_mode || 'single',
        permissions: t.permissions || 'view_dashboard,mark_attendance,view_students,view_fees,view_amal',
        assignedBatches: assigned,
        assignedBatchNames: assigned.map(b => b.name).join(', '),
        assignedBatchIds: assigned.map(b => b.id)
      };
    });

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/teachers', async (req, res) => {
  const { user_id, name, email, password, salary, attendance_mode, permissions, batch_ids, tenant_id } = req.body;
  if (!user_id || !name) {
    return res.status(400).json({ error: 'Missing Teacher ID or Name' });
  }
  try {
    const cleanUserId = (user_id || '').trim();
    const cleanName = (name || '').trim();
    const cleanEmail = (email || '').trim();
    const cleanPassword = (password || '').trim();
    const cleanPermissions = Array.isArray(permissions) ? permissions.join(',') : (permissions || '');

    await db.run(`
      INSERT INTO students (user_id, name, card_number, role, password, salary, attendance_mode, permissions, tenant_id)
      VALUES (?, ?, ?, 'teacher', ?, ?, ?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        name = excluded.name,
        card_number = excluded.card_number,
        password = excluded.password,
        salary = excluded.salary,
        attendance_mode = excluded.attendance_mode,
        permissions = excluded.permissions,
        tenant_id = excluded.tenant_id
    `, [cleanUserId, cleanName, cleanEmail, cleanPassword, salary || 0, attendance_mode || 'single', cleanPermissions, tenant_id || null]);

    // Clear and rewrite batch assignments in teacher_assignments
    await db.run('DELETE FROM teacher_assignments WHERE user_id = ?', [user_id]);

    if (batch_ids && Array.isArray(batch_ids)) {
      for (const bId of batch_ids) {
        const batch = await db.get('SELECT shift_id FROM batches WHERE batch_id = ?', [bId]);
        const sId = batch ? batch.shift_id : 'UNORGANIZED';
        await db.run(`
          INSERT INTO teacher_assignments (user_id, batch_id, shift_id)
          VALUES (?, ?, ?)
        `, [cleanUserId, bId, sId]);
      }
    }

    res.json({ success: true, message: `Teacher ${name} saved successfully.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


/**
 * Bulk Teacher Excel Import Endpoint
 * Endpoint: POST /api/teachers/import
 */
app.post('/api/teachers/import', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No Excel file provided' });
  }

  const { tenant_id } = req.query;

  try {
    const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const data = xlsx.utils.sheet_to_json(sheet);

    console.log(`Received Teachers Excel sheet with ${data.length} records. Tenant ID: ${tenant_id}`);
    let importCount = 0;

    for (const row of data) {
      const userId = String(row['User ID'] || row['Biometric PIN'] || row['PIN'] || row['user_id'] || '').trim();
      const name = String(row['Teacher Name'] || row['Name'] || row['name'] || '').trim();
      const email = String(row['Email'] || row['Username'] || row['email'] || '').trim();
      const password = String(row['Password'] || row['password'] || 'Rushda1@').trim();
      const salary = parseFloat(row['Salary'] || row['salary'] || 0);
      const attModeRaw = String(row['Attendance Mode'] || row['attendance_mode'] || 'single').trim().toLowerCase();
      const attendanceMode = (attModeRaw.includes('separate') || attModeRaw.includes('batch')) ? 'separate' : 'single';
      const assignedBatchesRaw = String(row['Assigned Batches'] || row['Batches'] || row['batch_ids'] || '').trim();

      if (!name) {
        console.warn('Skipping row due to missing Teacher Name:', row);
        continue;
      }

      const cleanUserId = userId || ('t-' + Date.now() + '-' + Math.floor(Math.random() * 1000));

      await db.run(`
        INSERT INTO students (user_id, name, card_number, role, password, salary, attendance_mode, permissions, tenant_id)
        VALUES (?, ?, ?, 'teacher', ?, ?, ?, 'view_dashboard,mark_attendance,view_students,view_fees,view_amal', ?)
        ON CONFLICT(user_id) DO UPDATE SET
          name = excluded.name,
          card_number = excluded.card_number,
          password = excluded.password,
          salary = excluded.salary,
          attendance_mode = excluded.attendance_mode,
          tenant_id = excluded.tenant_id
      `, [cleanUserId, name, email || (cleanUserId + '@madrasa.com'), password, salary, attendanceMode, tenant_id || null]);

      if (assignedBatchesRaw) {
        await db.run('DELETE FROM teacher_assignments WHERE user_id = ?', [cleanUserId]);
        const batchItems = assignedBatchesRaw.split(',').map(s => s.trim()).filter(Boolean);
        for (const bId of batchItems) {
          const batch = await db.get('SELECT batch_id, shift_id FROM batches WHERE batch_id = ? OR LOWER(batch_name) = ?', [bId, bId.toLowerCase()]);
          const targetBatchId = batch ? batch.batch_id : bId;
          const shiftId = batch ? batch.shift_id : 'UNORGANIZED';
          await db.run(`
            INSERT OR IGNORE INTO teacher_assignments (user_id, batch_id, shift_id)
            VALUES (?, ?, ?)
          `, [cleanUserId, targetBatchId, shiftId]);
        }
      }

      importCount++;
    }

    res.json({ success: true, count: importCount, message: `Successfully imported ${importCount} teachers from Excel!` });
  } catch (err) {
    console.error('Error importing teachers Excel:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * Sample Teacher Excel Template Endpoint
 * Endpoint: GET /api/teachers/sample-template
 */
app.get('/api/teachers/sample-template', (req, res) => {
  try {
    const sampleData = [
      {
        'User ID': '101',
        'Teacher Name': 'Ahmad Usthad',
        'Email': 'ahmad.example@gmail.com',
        'Password': 'MyPass@123',
        'Salary': 15000,
        'Attendance Mode': 'single',
        'Assigned Batches': '07, 08'
      },
      {
        'User ID': '102',
        'Teacher Name': 'Fathima Teacher',
        'Email': 'fathima.example@gmail.com',
        'Password': 'MyPass@456',
        'Salary': 16000,
        'Attendance Mode': 'single',
        'Assigned Batches': '4, 14'
      }
    ];

    const ws = xlsx.utils.json_to_sheet(sampleData);
    const wb = xlsx.utils.book_new();
    xlsx.utils.book_append_sheet(wb, ws, 'Teachers');

    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename="sample_teachers.xlsx"');
    res.send(buf);
  } catch(e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/api/teachers/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await db.run('DELETE FROM students WHERE role = \'teacher\' AND user_id = ?', [id]);
    await db.run('DELETE FROM teacher_assignments WHERE user_id = ?', [id]);
    res.json({ success: true, message: 'Teacher deleted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.8. Bulk Delete Students
 * Endpoint: POST /api/students/bulk-delete
 */
app.post('/api/students/bulk-delete', async (req, res) => {
  const { user_ids } = req.body;

  if (!user_ids || !Array.isArray(user_ids) || user_ids.length === 0) {
    return res.status(400).json({ error: 'No user IDs provided for deletion.' });
  }

  try {
    const placeholders = user_ids.map(() => '?').join(',');
    await db.run(`DELETE FROM students WHERE user_id IN (${placeholders})`, user_ids);
    res.json({ success: true, message: `Successfully deleted ${user_ids.length} student profiles.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8.9. Bulk Import Students
 * Endpoint: POST /api/students/bulk-import
 */
app.post('/api/students/bulk-import', async (req, res) => {
  const { students } = req.body;
  if (!students || !Array.isArray(students) || students.length === 0) {
    return res.status(400).json({ error: 'No student records provided.' });
  }

  try {
    // Begin transaction for fast bulk operations
    await db.run('BEGIN TRANSACTION');
    
    // Load existing batches for smart normalization matching
    const dbBatches = await db.all('SELECT batch_id, batch_name FROM batches');
    
    for (const s of students) {
      const userId = String(s.id || s.admissionNumber || '').trim();
      const name = String(s.name || '').trim();
      if (!userId || !name) continue;

      let activeBatch = String(s.batchId || 'UNORGANIZED').trim();
      
      // Smart check: match by batch_id, batch_name or s.standard
      const matched = dbBatches.find(b => {
        const bid = b.batch_id.toLowerCase();
        const bname = (b.batch_name || '').toLowerCase();
        const active = activeBatch.toLowerCase();
        const std = String(s.standard || '').trim().toLowerCase();
        return bid === active || bname === active || bname === std;
      });

      if (matched) {
        activeBatch = matched.batch_id;
      } else {
        // Create batch on the fly
        const batchName = String(s.standard || activeBatch || 'Unorganized').trim();
        await db.run(`
          INSERT OR IGNORE INTO batches (batch_id, batch_name, shift_id, tenant_id)
          VALUES (?, ?, 'UNORGANIZED', ?)
        `, [activeBatch, batchName, s.tenantId || null]);
        dbBatches.push({ batch_id: activeBatch, batch_name: batchName });
      }

      await db.run(`
        INSERT INTO students (
          user_id, name, card_number, batch_id, role, tenant_id,
          roll_number, gender, dob, father, mother, primary_number,
          secondary_number, school_name, monthly_fee, password,
          photo, age, school_going_time, school_return_time
        )
        VALUES (?, ?, ?, ?, 'student', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
          name = excluded.name,
          card_number = excluded.card_number,
          batch_id = excluded.batch_id,
          tenant_id = COALESCE(excluded.tenant_id, students.tenant_id),
          roll_number = excluded.roll_number,
          gender = excluded.gender,
          dob = excluded.dob,
          father = excluded.father,
          mother = excluded.mother,
          primary_number = excluded.primary_number,
          secondary_number = excluded.secondary_number,
          school_name = excluded.school_name,
          monthly_fee = excluded.monthly_fee,
          password = excluded.password,
          photo = excluded.photo,
          age = excluded.age,
          school_going_time = excluded.school_going_time,
          school_return_time = excluded.school_return_time
      `, [
        userId, name, s.cardId || null, activeBatch, s.tenantId || null,
        s.rollNumber || null, s.gender || null, s.dob || null, s.father || null, s.mother || null, s.primaryNumber || null,
        s.secondaryNumber || null, s.schoolName || null, s.monthlyFee || null, s.password || null,
        s.photo || null, s.age || null, s.schoolGoingTime || null, s.schoolReturnTime || null
      ]);
    }
    
    await db.run('COMMIT');
    res.json({ success: true, message: `Successfully imported ${students.length} student records.` });
  } catch (err) {
    try {
      await db.run('ROLLBACK');
    } catch (rbErr) {}
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/diagnostics/excel-headers', (req, res) => {
  const { fileName, headers, rawHeaders } = req.body;
  console.log(`[DIAGNOSTICS] Uploaded File: ${fileName}`);
  console.log(`[DIAGNOSTICS] Raw Headers:`, rawHeaders);
  console.log(`[DIAGNOSTICS] Cleaned Headers:`, headers);
  res.json({ ok: true });
});

/**
/**
 * 8.4b. Dashboard Candlestick Data - Daily attendance breakdown for current month
 * Endpoint: GET /api/reports/dashboard-candlestick
 * Query: ?tenant_id=xxx
 */
app.get('/api/reports/dashboard-candlestick', async (req, res) => {
  const { tenant_id, month: monthParam } = req.query;
  if (!tenant_id) {
    return res.status(400).json({ error: 'Missing tenant_id.' });
  }
  try {
    const todayStr = getLocalDateString(); // e.g. "2026-07-17"
    const [currentYear, currentMonth] = todayStr.split('-');
    
    let targetMonth = monthParam;
    if (!targetMonth || !/^\d{4}-\d{2}$/.test(targetMonth)) {
      targetMonth = `${currentYear}-${currentMonth}`;
    }

    const [year, month] = targetMonth.split('-');
    const startDate = `${year}-${month}-01`;
    
    let endDate;
    if (targetMonth === `${currentYear}-${currentMonth}`) {
      endDate = todayStr;
    } else {
      const lastDay = new Date(parseInt(year), parseInt(month), 0).getDate();
      endDate = `${year}-${month}-${String(lastDay).padStart(2, '0')}`;
    }

    // Get total students for this tenant
    const totalRow = await db.get(
      `SELECT COUNT(*) as total FROM students WHERE tenant_id = ? AND (role = 'student' OR role IS NULL OR role = '')`,
      [tenant_id]
    );
    const totalStudents = totalRow ? totalRow.total : 0;

    // Get daily attendance status breakdown for the target month
    const rows = await db.all(`
      SELECT da.work_date,
             SUM(CASE WHEN da.attendance_status = 'Present' THEN 1 ELSE 0 END) as present_count,
             SUM(CASE WHEN da.attendance_status = 'Late' THEN 1 ELSE 0 END) as late_count,
             SUM(CASE WHEN da.attendance_status = 'Holiday' THEN 1 ELSE 0 END) as holiday_count,
             COUNT(DISTINCT da.user_id) as total_recorded
      FROM daily_attendance da
      JOIN students s ON da.user_id = s.user_id
      WHERE s.tenant_id = ?
        AND da.work_date BETWEEN ? AND ?
        AND (s.role = 'student' OR s.role IS NULL OR s.role = '')
      GROUP BY da.work_date
      ORDER BY da.work_date ASC
    `, [tenant_id, startDate, endDate]);

    // Build day-by-day trend data from 1st to end using timezone-proof local date string parsing
    const days = [];
    const [yearNum, monthNum, endDayNum] = endDate.split('-').map(Number);

    for (let dayNum = 1; dayNum <= endDayNum; dayNum++) {
      const dayStr = String(dayNum).padStart(2, '0');
      const ds = `${yearNum}-${String(monthNum).padStart(2, '0')}-${dayStr}`;

      // Correctly check if the day is a Friday (index 5)
      const dObj = new Date(yearNum, monthNum - 1, dayNum);
      const isFriday = dObj.getDay() === 5;

      if (isFriday) {
        // Fridays: no school - skip
        continue;
      }

      const row = rows.find(r => r.work_date === ds);

      if (row) {
        const presentCount = row.present_count || 0;
        const lateCount = row.late_count || 0;
        const holidayCount = row.holiday_count || 0;
        const isHoliday = holidayCount > 0 && presentCount === 0;
        const absentCount = Math.max(0, totalStudents - presentCount - lateCount);
        const attendanceRate = totalStudents > 0
          ? Math.round(((presentCount + lateCount) / totalStudents) * 100)
          : 0;

        days.push({
          date: ds,
          day: dayNum,
          present: presentCount,
          late: lateCount,
          absent: absentCount,
          holiday: isHoliday ? 1 : 0,
          total: totalStudents,
          rate: attendanceRate,
          isHoliday,
          hasData: true
        });
      } else {
        // No records yet for this day — treat as no-data (future or unrecorded)
        const isPast = (targetMonth !== `${currentYear}-${currentMonth}`) || (dayNum < endDayNum);
        days.push({
          date: ds,
          day: dayNum,
          present: 0,
          late: 0,
          absent: isPast ? totalStudents : 0,
          holiday: 0,
          total: totalStudents,
          rate: 0,
          isHoliday: false,
          hasData: false,
          isPast
        });
      }
    }

    res.json({ days, totalStudents, month: `${yearNum}-${String(monthNum).padStart(2, '0')}` });
  } catch (err) {
    console.error('Candlestick error:', err);
    res.status(500).json({ error: 'Failed to compile candlestick data.' });
  }
});

/**
 * 8.5. Get Monthly Attendance Report
 * Endpoint: GET /api/reports/monthly
 * Query: ?month=YYYY-MM&batch_id=XXX
 */
app.get('/api/reports/monthly', async (req, res) => {
  const { month, batch_id } = req.query;

  if (!month || !batch_id) {
    return res.status(400).json({ error: 'Missing month or batch_id query parameters.' });
  }

  try {
    // 1. Get total active working days in that month (days with at least one check-in in the database)
    const workingDays = await db.all(`
      SELECT DISTINCT work_date FROM daily_attendance
      WHERE work_date LIKE ? AND attendance_status != 'Holiday'
      ORDER BY work_date ASC
    `, [`${month}%`]);
    const totalWorkingDays = workingDays.length;

    // 2. Get all students in the target batch
    const students = await db.all(`
      SELECT user_id, name, roll_number, card_number
      FROM students
      WHERE batch_id = ?
      ORDER BY user_id ASC
    `, [batch_id]);

    // 3. Get all attendance logs for the month
    const attendanceLogs = await db.all(`
      SELECT user_id, work_date, attendance_status
      FROM daily_attendance
      WHERE work_date LIKE ?
    `, [`${month}%`]);

    // Group logs by student user_id
    const logsByStudent = {};
    attendanceLogs.forEach(log => {
      if (!logsByStudent[log.user_id]) {
        logsByStudent[log.user_id] = [];
      }
      logsByStudent[log.user_id].push(log);
    });

    // 4. Compile the report stats
    const report = students.map(s => {
      const studentLogs = logsByStudent[s.user_id] || [];
      const onTimeDays = studentLogs.filter(l => l.attendance_status === 'Present').length;
      const lateDays = studentLogs.filter(l => l.attendance_status === 'Late').length;
      const earlyDays = studentLogs.filter(l => l.attendance_status === 'Early').length;
      
      const presentDays = onTimeDays + lateDays + earlyDays;
      const absentDays = Math.max(0, totalWorkingDays - presentDays);

      const attendanceRate = totalWorkingDays > 0 
        ? Math.round((presentDays / totalWorkingDays) * 100) 
        : 0;

      // Punctuality rate ONLY considers On-Time (Present) and Late days. Early days are excluded.
      const punctualityDenominator = onTimeDays + lateDays;
      const punctualityRate = punctualityDenominator > 0 
        ? Math.round((onTimeDays / punctualityDenominator) * 100) 
        : 100;

      return {
        userId: s.user_id,
        rollNumber: s.roll_number,
        admissionNumber: /^s-\d+/.test(s.user_id) ? '' : s.user_id,
        name: s.name,
        cardNumber: s.card_number,
        workingDays: totalWorkingDays,
        presentDays,
        earlyDays,
        lateDays,
        absentDays,
        attendanceRate,
        punctualityRate
      };
    });

    res.json({
      month,
      batchId: batch_id,
      totalWorkingDays,
      records: report
    });

  } catch (err) {
    console.error('Error compiling monthly report:', err);
    res.status(500).json({ error: 'Failed to compile monthly report.' });
  }
});

/**
 * 8.10. Get Batch Compliance Report (Attendance + Fees)
 * Endpoint: GET /api/reports/batch-compliance
 */
app.get('/api/reports/batch-compliance', async (req, res) => {
  let { batch_id, start_date, end_date, month } = req.query;

  if (month) {
    start_date = `${month}-01`;
    end_date = `${month}-31`;
  }

  if (!batch_id || !start_date || !end_date) {
    return res.status(400).json({ error: 'Missing batch_id, start_date or end_date.' });
  }

  try {
    // 1. Get students in the target batch
    const students = await db.all(`
      SELECT user_id, name, card_number
      FROM students
      WHERE batch_id = ? AND role = 'student'
      ORDER BY user_id ASC
    `, [batch_id]);

    const studentUserIds = students.map(s => s.user_id);
    let workingDays = [];
    let attendanceLogs = [];

    if (studentUserIds.length > 0) {
      const placeholders = studentUserIds.map(() => '?').join(',');
      workingDays = await db.all(`
        SELECT DISTINCT work_date FROM daily_attendance
        WHERE work_date BETWEEN ? AND ? AND attendance_status != 'Holiday'
        AND user_id IN (${placeholders})
        ORDER BY work_date ASC
      `, [start_date, end_date, ...studentUserIds]);

      attendanceLogs = await db.all(`
        SELECT user_id, work_date, attendance_status
        FROM daily_attendance
        WHERE work_date BETWEEN ? AND ?
        AND user_id IN (${placeholders})
      `, [start_date, end_date, ...studentUserIds]);
    }

    const totalWorkingDays = workingDays.length;

    // Group logs by student user_id
    const logsByStudent = {};
    attendanceLogs.forEach(log => {
      if (!logsByStudent[log.user_id]) logsByStudent[log.user_id] = [];
      logsByStudent[log.user_id].push(log);
    });

    // Helper: find months in date range
    const getMonthNamesInRange = (startDateStr, endDateStr) => {
      const start = new Date(startDateStr);
      const end = new Date(endDateStr);
      const monthNames = [];
      const names = ["June", "July", "August", "September", "October", "November", "December", "January", "February", "March", "April", "May"];
      
      let current = new Date(start.getFullYear(), start.getMonth(), 1);
      while (current <= end) {
        // Find index of month name in our school calendar
        const monthIndex = current.getMonth();
        // JavaScript Date getMonth returns 0-11, map to standard English name
        const stdNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        const monthName = stdNames[monthIndex];
        if (!monthNames.includes(monthName)) {
          monthNames.push(monthName);
        }
        current.setMonth(current.getMonth() + 1);
      }
      return monthNames;
    };

    const targetMonths = getMonthNamesInRange(start_date, end_date);

    // 4. Fetch fee records for students in this batch
    const feeRecords = await db.all(`
      SELECT user_id, month, status
      FROM fees
      WHERE user_id IN (SELECT user_id FROM students WHERE batch_id = ? AND role = 'student')
    `, [batch_id]);

    const feeMap = {};
    feeRecords.forEach(f => {
      const key = `${f.user_id}_${f.month}`;
      const st = String(f.status || '').toUpperCase();
      feeMap[key] = (st === 'PAID' || st === '1' || st === 'TRUE') ? 'PAID' : 'UNPAID';
    });

    // 5. Compile the stats
    const report = students.map(s => {
      const studentLogs = logsByStudent[s.user_id] || [];
      const onTimeDays = studentLogs.filter(l => l.attendance_status === 'Present').length;
      const lateDays = studentLogs.filter(l => l.attendance_status === 'Late').length;
      const earlyDays = studentLogs.filter(l => l.attendance_status === 'Early').length;
      
      const presentDays = onTimeDays + lateDays + earlyDays;
      const absentDays = Math.max(0, totalWorkingDays - presentDays);

      const attendanceRate = totalWorkingDays > 0 
        ? Math.round((presentDays / totalWorkingDays) * 100) 
        : 0;

      const punctualityPoints = onTimeDays * 10;
      const maxPunctualityPoints = totalWorkingDays * 10;

      const punctualityDenominator = onTimeDays + lateDays;
      const punctualityRate = punctualityDenominator > 0 
        ? Math.round((onTimeDays / punctualityDenominator) * 100) 
        : 0;

      // Fees status mapping for each month in range
      const feesStatus = {};
      targetMonths.forEach(m => {
        const key = `${s.user_id}_${m}`;
        feesStatus[m] = feeMap[key] || 'UNPAID';
      });

      return {
        userId: s.user_id,
        name: s.name,
        cardNumber: s.card_number,
        workingDays: totalWorkingDays,
        presentDays,
        earlyDays,
        lateDays,
        absentDays,
        attendanceRate,
        punctualityPoints,
        maxPunctualityPoints,
        punctualityRate,
        feesStatus
      };
    });

    res.json({
      batchId: batch_id,
      startDate: start_date,
      endDate: end_date,
      months: targetMonths,
      totalWorkingDays,
      records: report
    });
  } catch (err) {
    console.error('Error compiling batch compliance report:', err);
    res.status(500).json({ error: 'Failed to compile batch compliance report.' });
  }
});

/**
 * 8.11. Get Amal Compliance Report (Habits checklist)
 * Endpoint: GET /api/reports/amal-compliance
 */
app.get('/api/reports/amal-compliance', async (req, res) => {
  let { batch_id, start_date, end_date, month } = req.query;

  if (month) {
    start_date = `${month}-01`;
    end_date = `${month}-31`;
  }

  if (!batch_id || !start_date || !end_date) {
    return res.status(400).json({ error: 'Missing batch_id, start_date or end_date.' });
  }

  try {
    // 1. Fetch students in the target batch
    const students = await db.all(`
      SELECT user_id, name FROM students 
      WHERE batch_id = ? AND role = 'student'
      ORDER BY user_id ASC
    `, [batch_id]);

    // 2. Fetch habit definitions targeting this batch (or ALL/null)
    const habits = await db.all(`
      SELECT habit_id, text_ml, text_en, start_date, end_date, target_batch
      FROM habit_definitions
      WHERE target_batch = ? OR target_batch = 'ALL' OR target_batch IS NULL OR target_batch = ''
    `, [batch_id]);

    // 3. Fetch all checks in this date range
    const parentChecks = await db.all(`
      SELECT user_id, work_date, check_name, status
      FROM parent_checks
      WHERE work_date BETWEEN ? AND ?
    `, [start_date, end_date]);

    // Group checks by student user_id and check_name
    const checksMap = {};
    parentChecks.forEach(c => {
      const key = `${c.user_id}_${c.check_name}`;
      if (!checksMap[key]) checksMap[key] = [];
      checksMap[key].push(c);
    });

    // Helper to calculate total valid days between two ranges
    const getOverlapDaysCount = (s1, e1, s2, e2) => {
      const start = new Date(s1 > s2 ? s1 : s2);
      const end = new Date(e1 < e2 ? e1 : e2);
      if (start > end) return 0;
      return Math.round((end - start) / (1000 * 60 * 60 * 24)) + 1;
    };

    // 4. Compile the Amal compliance stats for each student
    const records = students.map(s => {
      const studentHabits = habits.map(h => {
        const hStart = h.start_date || '2020-01-01';
        const hEnd = h.end_date || '2030-12-31';
        const totalValidDays = getOverlapDaysCount(start_date, end_date, hStart, hEnd);

        const checkKey = `${s.user_id}_${h.habit_id}`;
        const checks = checksMap[checkKey] || [];
        const completedCount = checks.filter(c => c.status === 'true' || c.status === '1').length;
        const missingCount = Math.max(0, totalValidDays - completedCount);

        return {
          habitId: h.habit_id,
          textMl: h.text_ml,
          textEn: h.text_en,
          totalValidDays,
          completedCount,
          missingCount
        };
      });

      return {
        userId: s.user_id,
        name: s.name,
        habits: studentHabits
      };
    });

    res.json({
      batchId: batch_id,
      startDate: start_date,
      endDate: end_date,
      habits,
      records
    });
  } catch (err) {
    console.error('Error compiling Amal report:', err);
    res.status(500).json({ error: 'Failed to compile Amal compliance report.' });
  }
});

/**
 * GET /api/reports/student
 * Query: ?user_id=XXX&start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
 */
app.get('/api/reports/student', async (req, res) => {
  const { user_id, start_date, end_date } = req.query;
  if (!user_id || !start_date || !end_date) {
    return res.status(400).json({ error: 'user_id, start_date, and end_date query parameters are required' });
  }

  try {
    // 1. Fetch student info
    const student = await db.get(`
      SELECT s.user_id, s.name, s.card_number, s.batch_id, b.batch_name 
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.batch_id
      WHERE s.user_id = ?
    `, [user_id]);

    if (!student) {
      return res.status(404).json({ error: 'Student/Teacher profile not found' });
    }

    // 2. Fetch all daily attendance records for this student in range
    const records = await db.all(`
      SELECT work_date, check_in, check_out, late_minutes, attendance_status 
      FROM daily_attendance 
      WHERE user_id = ? AND work_date BETWEEN ? AND ?
      ORDER BY work_date ASC
    `, [user_id, start_date, end_date]);

    // 3. Calculate statistics
    let presentCount = 0;
    let absentCount = 0;
    let lateCount = 0;
    let earlyCount = 0;

    records.forEach(r => {
      if (r.attendance_status === 'Present') {
        presentCount++;
      } else if (r.attendance_status === 'Late') {
        lateCount++;
      } else if (r.attendance_status === 'Early') {
        earlyCount++;
      } else if (r.attendance_status === 'Absent') {
        absentCount++;
      }
    });

    res.json({
      success: true,
      student: {
        user_id: student.user_id,
        name: student.name,
        batch_id: student.batch_id,
        batch_name: student.batch_name || 'Unorganized',
        card_number: student.card_number
      },
      stats: {
        totalDays: records.length,
        presentCount,
        lateCount,
        earlyCount,
        absentCount,
        attendedCount: presentCount + lateCount + earlyCount
      },
      records
    });
  } catch (err) {
    console.error('Error compiling student report:', err);
    res.status(500).json({ error: 'Failed to compile student report.' });
  }
});

/**
 * GET /api/reports/teacher
 * Query: ?user_id=XXX&start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
 */
app.get('/api/reports/teacher', async (req, res) => {
  const { user_id, start_date, end_date } = req.query;
  if (!user_id || !start_date || !end_date) {
    return res.status(400).json({ error: 'user_id, start_date, and end_date query parameters are required' });
  }

  try {
    const teacher = await db.get('SELECT * FROM students WHERE role = \'teacher\' AND user_id = ?', [user_id]);
    if (!teacher) {
      return res.status(404).json({ error: 'Teacher profile not found' });
    }

    // Fetch all daily attendance records for this teacher in range
    const records = await db.all(`
      SELECT work_date, check_in, check_out, late_minutes, attendance_status, remarks, batch_id
      FROM daily_attendance 
      WHERE user_id = ? AND work_date BETWEEN ? AND ?
      ORDER BY work_date ASC
    `, [user_id, start_date, end_date]);

    // Calculate working days in range (excluding Fridays)
    const start = new Date(start_date);
    const end = new Date(end_date);
    const workingDaysList = [];
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const dayOfWeek = d.getDay(); // 0 = Sunday, 5 = Friday, 6 = Saturday
      if (dayOfWeek !== 5) { // Friday is typical Madrasa holiday
        workingDaysList.push(d.toISOString().split('T')[0]);
      }
    }

    const totalWorkingDays = workingDaysList.length;

    // Group logs by work_date
    const recordsByDate = {};
    records.forEach(r => {
      if (!recordsByDate[r.work_date]) {
        recordsByDate[r.work_date] = [];
      }
      recordsByDate[r.work_date].push(r);
    });

    let presentDays = 0;
    let absentDays = 0;
    let lateCheckins = 0;
    let missedCheckouts = 0;

    const dailyDetails = [];

    for (const wDate of workingDaysList) {
      const logs = recordsByDate[wDate] || [];
      const hasPunch = logs.some(l => l.check_in || l.check_out);

      if (hasPunch) {
        presentDays++;
        
        // Check if any check-in was late
        const wasLate = logs.some(l => l.attendance_status === 'Late' || l.late_minutes > 0);
        if (wasLate) {
          lateCheckins++;
        }

        // Check if check-out was missed (i.e. check_in exists but check_out is null, or all check_out values are null)
        const hasCheckin = logs.some(l => l.check_in !== null);
        const hasCheckout = logs.some(l => l.check_out !== null);
        if (hasCheckin && !hasCheckout) {
          missedCheckouts++;
        }

        // Merge remarks and status for detailed view
        dailyDetails.push({
          date: wDate,
          check_in: logs.map(l => l.check_in ? l.check_in.split(' ')[1] : '-').join(', '),
          check_out: logs.map(l => l.check_out ? l.check_out.split(' ')[1] : '-').join(', '),
          status: wasLate ? 'Late' : 'Present',
          remarks: logs.map(l => l.remarks || 'Punched').join('; ')
        });
      } else {
        absentDays++;
        dailyDetails.push({
          date: wDate,
          check_in: '-',
          check_out: '-',
          status: 'Absent',
          remarks: 'No punch recorded'
        });
      }
    }

    res.json({
      success: true,
      teacher: {
        user_id: teacher.user_id,
        name: teacher.name,
        email: teacher.card_number,
        salary: teacher.salary || 0,
        attendance_mode: teacher.attendance_mode || 'single'
      },
      stats: {
        totalWorkingDays,
        presentDays,
        absentDays,
        lateCheckins,
        missedCheckouts
      },
      records: dailyDetails
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/reports/earliest-date
 */
app.get('/api/reports/earliest-date', async (req, res) => {
  try {
    const row = await db.get(`SELECT MIN(work_date) as earliestDate FROM daily_attendance WHERE work_date IS NOT NULL AND work_date != ''`);
    const earliest = row && row.earliestDate ? row.earliestDate : new Date().toISOString().split('T')[0];
    res.json({ success: true, earliestDate: earliest });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 9. Device command feedback (Optional)
 * Endpoint: POST /devicecmd
 */
app.post(/devicecmd/, async (req, res) => {
  const { SN } = req.query;
  let payload = req.body;
  
  console.log(`[Device Cmd Feedback] SN: ${SN}, Payload Type: ${typeof payload}`);

  if (!payload) {
    res.setHeader('Content-Type', 'text/plain');
    return res.send('OK');
  }

  // Handle if body was parsed as an object (e.g. key-value)
  if (typeof payload === 'object') {
    const id = payload.ID || payload.id;
    const retVal = payload.Return || payload.return || payload.RET || payload.ret;
    if (id) {
      try {
        const status = String(retVal) === '0' ? 'SUCCESS' : 'ERROR';
        await db.run('UPDATE device_commands SET status = ? WHERE id = ?', [status, id]);
        console.log(`Command ID ${id} executed with status: ${status}`);
      } catch (err) {
        console.error('Error updating command feedback:', err);
      }
    }
  } else if (typeof payload === 'string') {
    const lines = payload.trim().split('\n');
    for (const line of lines) {
      if (!line.trim()) continue;
      
      const params = new URLSearchParams(line.trim());
      const id = params.get('ID');
      const retVal = params.get('Return');

      if (id) {
        try {
          const status = retVal === '0' ? 'SUCCESS' : 'ERROR';
          await db.run('UPDATE device_commands SET status = ? WHERE id = ?', [status, id]);
          console.log(`Command ID ${id} executed with status: ${status}`);
        } catch (err) {
          console.error('Error updating command feedback:', err);
        }
      }
    }
  }

  res.setHeader('Content-Type', 'text/plain');
  res.send('OK');
});

// ==========================================
// UNIFIED PORTAL MANAGEMENT API ENDPOINTS
// ==========================================

app.get('/api/habit-definitions', async (req, res) => {
  const { tenant_id } = req.query;
  try {
    let query = 'SELECT * FROM habit_definitions';
    const params = [];
    if (tenant_id) {
      query += ' WHERE tenant_id = ?';
      params.push(tenant_id);
    }
    const rows = await db.all(query, params);
    res.json(rows.map(r => ({
      id: r.habit_id,
      title: r.text_en || r.text_ml || '',
      textMl: r.text_ml || r.text_en || '',
      textEn: r.text_en || r.text_ml || '',
      tenantId: r.tenant_id,
      startDate: r.start_date || '',
      endDate: r.end_date || '',
      targetBatch: r.target_batch || ''
    })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/habit-definitions', async (req, res) => {
  const { habit_id, title, text_ml, text_en, tenant_id, start_date, end_date, target_batch } = req.body;
  const activityTitle = (title || text_en || text_ml || '').trim();
  if (!habit_id || !activityTitle) {
    return res.status(400).json({ error: 'Missing required parameters (habit_id or title)' });
  }
  try {
    await db.run(`
      INSERT INTO habit_definitions (habit_id, text_ml, text_en, tenant_id, start_date, end_date, target_batch)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(habit_id) DO UPDATE SET
        text_ml = excluded.text_ml,
        text_en = excluded.text_en,
        tenant_id = excluded.tenant_id,
        start_date = excluded.start_date,
        end_date = excluded.end_date,
        target_batch = excluded.target_batch
    `, [habit_id, activityTitle, activityTitle, tenant_id || null, start_date || '', end_date || '', target_batch || '']);
    res.json({ success: true, message: 'Habit definition saved successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/habit-definitions/bulk', async (req, res) => {
  const { items, tenant_id } = req.body;
  if (!items || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'No habit items provided' });
  }
  try {
    for (const item of items) {
      const hId = item.habit_id || ('h-' + Date.now() + '-' + Math.floor(Math.random() * 1000));
      const activityTitle = (item.title || item.text_en || item.text_ml || '').trim();
      if (!activityTitle) continue;

      await db.run(`
        INSERT INTO habit_definitions (habit_id, text_ml, text_en, tenant_id, start_date, end_date, target_batch)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(habit_id) DO UPDATE SET
          text_ml = excluded.text_ml,
          text_en = excluded.text_en,
          tenant_id = excluded.tenant_id,
          start_date = excluded.start_date,
          end_date = excluded.end_date,
          target_batch = excluded.target_batch
      `, [hId, activityTitle, activityTitle, tenant_id || null, item.start_date || '', item.end_date || '', item.target_batch || '']);
    }
    res.json({ success: true, message: `${items.length} Habit definition(s) saved successfully.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/habit-definitions/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await db.run('DELETE FROM habit_definitions WHERE habit_id = ?', [id]);
    res.json({ success: true, message: 'Habit definition deleted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== SUPER ADMIN MASTER API ROUTES ====================

// GET /api/superadmin/tenants - Get list of all madrasa tenant accounts and system analytics
app.get('/api/superadmin/tenants', async (req, res) => {
  try {
    const tenants = await db.all(`
      SELECT 
        u.username,
        u.madrasa_name,
        u.role,
        u.status,
        u.plan_name,
        u.plan_expiry,
        u.payment_status,
        u.phone,
        u.place,
        u.biometric_enabled,
        u.created_at,
        (SELECT COUNT(*) FROM students s WHERE s.tenant_id = u.username AND (s.role = 'student' OR s.role IS NULL OR s.role = '')) as student_count,
        (SELECT COUNT(*) FROM students s WHERE s.tenant_id = u.username AND s.role = 'teacher') as teacher_count
      FROM users u
      WHERE (u.role IS NULL OR u.role != 'superadmin') AND LOWER(u.username) NOT LIKE '%thartheeb%'
      ORDER BY u.created_at DESC
    `);
    res.json(tenants);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/superadmin/tenants - Onboard a new Madrasa account
app.post('/api/superadmin/tenants', async (req, res) => {
  const { username, password, madrasa_name, plan_name, plan_expiry, payment_status, phone, place } = req.body;
  if (!username || !password || !madrasa_name) {
    return res.status(400).json({ error: 'Username, password, and madrasa name are required.' });
  }
  try {
    const cleanUsername = username.trim().toLowerCase();
    const crypto = require('crypto');
    const hashed = crypto.createHash('sha256').update(password.trim()).digest('hex');

    await db.run(`
      INSERT INTO users (username, password, madrasa_name, role, status, plan_name, plan_expiry, payment_status, phone, place)
      VALUES (?, ?, ?, 'admin', 'active', ?, ?, ?, ?, ?)
      ON CONFLICT(username) DO UPDATE SET
        madrasa_name = excluded.madrasa_name,
        password = excluded.password,
        plan_name = excluded.plan_name,
        plan_expiry = excluded.plan_expiry,
        payment_status = excluded.payment_status,
        phone = excluded.phone,
        place = excluded.place
    `, [
      cleanUsername, 
      hashed, 
      madrasa_name.trim(), 
      plan_name || 'Pro', 
      plan_expiry || '', 
      payment_status || 'paid', 
      phone || '', 
      place || ''
    ]);

    res.json({ success: true, message: `Madrasa ${madrasa_name} onboarded successfully.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/superadmin/tenants/:id/status - Toggle active/disabled/suspended status
app.put('/api/superadmin/tenants/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  if (!status || !['active', 'disabled', 'suspended'].includes(status)) {
    return res.status(400).json({ error: 'Valid status (active, disabled, suspended) is required.' });
  }
  try {
    await db.run('UPDATE users SET status = ? WHERE username = ?', [status, id]);
    res.json({ success: true, message: `Madrasa status updated to ${status}.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/superadmin/tenants/:id/subscription - Manage plan, expiry date & payment status
app.put('/api/superadmin/tenants/:id/subscription', async (req, res) => {
  const { id } = req.params;
  const { plan_name, plan_expiry, payment_status } = req.body;
  try {
    await db.run(`
      UPDATE users 
      SET plan_name = COALESCE(?, plan_name),
          plan_expiry = COALESCE(?, plan_expiry),
          payment_status = COALESCE(?, payment_status)
      WHERE username = ?
    `, [plan_name || 'Pro', plan_expiry || '', payment_status || 'paid', id]);
    res.json({ success: true, message: 'Subscription details updated successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/superadmin/tenants/:id/biometric-toggle - Enable or Disable Biometrics
app.put('/api/superadmin/tenants/:id/biometric-toggle', async (req, res) => {
  const { id } = req.params;
  const { biometric_enabled } = req.body;
  try {
    await db.run('UPDATE users SET biometric_enabled = ? WHERE username = ?', [biometric_enabled ? 1 : 0, id]);
    res.json({ success: true, biometric_enabled: biometric_enabled ? 1 : 0, message: `Biometric feature ${biometric_enabled ? 'enabled' : 'disabled'} for ${id}.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/superadmin/tenants/:id - Delete a Madrasa account
app.delete('/api/superadmin/tenants/:id', async (req, res) => {
  const { id } = req.params;
  if (id === 'Thartheeb@786' || id === 'thartheeb@786') {
    return res.status(400).json({ error: 'Cannot delete Super Admin master account.' });
  }
  try {
    await db.run('DELETE FROM users WHERE username = ?', [id]);
    await db.run('DELETE FROM students WHERE tenant_id = ?', [id]);
    await db.run('DELETE FROM batches WHERE tenant_id = ?', [id]);
    res.json({ success: true, message: 'Madrasa account and associated tenant data deleted.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/superadmin/impersonate/:username - 1-Click Access/Impersonate a Madrasa Dashboard
app.get('/api/superadmin/impersonate/:username', async (req, res) => {
  const { username } = req.params;
  try {
    const tenant = await db.get('SELECT username, madrasa_name, role, status, permissions, biometric_enabled FROM users WHERE LOWER(username) = LOWER(?)', [username]);
    if (!tenant) {
      return res.status(404).json({ error: 'Madrasa institution not found.' });
    }
    res.json({
      success: true,
      tenant: {
        id: tenant.username,
        name: tenant.madrasa_name || 'Madrasa Institution',
        role: 'admin',
        status: tenant.status || 'active',
        biometric_enabled: (tenant.biometric_enabled === 0 || tenant.biometric_enabled === '0') ? 0 : 1,
        permissions: tenant.permissions || 'view_dashboard,manage_roster,manage_settings,generate_reports,student_reports,biometric_actions'
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/habits - Fetch habits list
app.get('/api/habits', async (req, res) => {
  const { user_id, date } = req.query;
  try {
    let query = 'SELECT * FROM habits';
    const params = [];
    if (user_id && date) {
      query += ' WHERE user_id = ? AND work_date = ?';
      params.push(user_id, date);
    } else if (user_id) {
      query += ' WHERE user_id = ?';
      params.push(user_id);
    } else if (date) {
      query += ' WHERE work_date = ?';
      params.push(date);
    }
    const rows = await db.all(query, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/habits - Add/Update habit log
app.post('/api/habits', async (req, res) => {
  const { user_id, work_date, habit_name, status, remarks } = req.body;
  if (!user_id || !work_date || !habit_name || !status) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }
  try {
    await db.run(`
      INSERT INTO habits (user_id, work_date, habit_name, status, remarks)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(user_id, work_date, habit_name) DO UPDATE SET
        status = excluded.status,
        remarks = excluded.remarks
    `, [user_id, work_date, habit_name, status, remarks || '']);
    res.json({ success: true, message: 'Habit record saved successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/prayers - Fetch prayers list
app.get('/api/prayers', async (req, res) => {
  const { user_id, date } = req.query;
  try {
    let query = 'SELECT * FROM prayers';
    const params = [];
    if (user_id && date) {
      query += ' WHERE user_id = ? AND work_date = ?';
      params.push(user_id, date);
    } else if (user_id) {
      query += ' WHERE user_id = ?';
      params.push(user_id);
    } else if (date) {
      query += ' WHERE work_date = ?';
      params.push(date);
    }
    const rows = await db.all(query, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/prayers - Add/Update prayer log
app.post('/api/prayers', async (req, res) => {
  const { user_id, work_date, prayer_name, status } = req.body;
  if (!user_id || !work_date || !prayer_name || !status) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }
  try {
    await db.run(`
      INSERT INTO prayers (user_id, work_date, prayer_name, status)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(user_id, work_date, prayer_name) DO UPDATE SET
        status = excluded.status
    `, [user_id, work_date, prayer_name, status]);
    res.json({ success: true, message: 'Prayer record saved successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/parent_checks - Fetch parent checks
app.get('/api/parent_checks', async (req, res) => {
  const { user_id, date } = req.query;
  try {
    let query = 'SELECT * FROM parent_checks';
    const params = [];
    if (user_id && date) {
      query += ' WHERE user_id = ? AND work_date = ?';
      params.push(user_id, date);
    } else if (user_id) {
      query += ' WHERE user_id = ?';
      params.push(user_id);
    } else if (date) {
      query += ' WHERE work_date = ?';
      params.push(date);
    }
    const rows = await db.all(query, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/parent_checks - Add/Update parent checks log
app.post('/api/parent_checks', async (req, res) => {
  const { user_id, work_date, check_name, status } = req.body;
  if (!user_id || !work_date || !check_name || !status) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }
  try {
    await db.run(`
      INSERT INTO parent_checks (user_id, work_date, check_name, status)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(user_id, work_date, check_name) DO UPDATE SET
        status = excluded.status
    `, [user_id, work_date, check_name, status]);
    res.json({ success: true, message: 'Parent check record saved successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/fees - Fetch tuition fees
app.get('/api/fees', async (req, res) => {
  const { user_id, month, tenant_id } = req.query;
  try {
    let query = 'SELECT f.* FROM fees f';
    const params = [];
    const conditions = [];
    
    if (tenant_id) {
      query += ' JOIN students s ON f.user_id = s.user_id';
      conditions.push('s.tenant_id = ?');
      params.push(tenant_id);
    }
    
    if (user_id) {
      conditions.push('f.user_id = ?');
      params.push(user_id);
    }
    
    if (month) {
      conditions.push('f.month = ?');
      params.push(month);
    }
    
    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }
    
    const rows = await db.all(query, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/fees - Add/Update tuition fee payment
app.post('/api/fees', async (req, res) => {
  const { user_id, student_id, month, paid_amount, status, is_paid, payment_date } = req.body;
  const targetUserId = user_id || student_id;
  
  let targetStatus = status;
  if (targetStatus === undefined && is_paid !== undefined) {
    targetStatus = (is_paid === 1 || is_paid === true) ? 'Paid' : 'Unpaid';
  }

  if (!targetUserId || !month || !targetStatus) {
    return res.status(400).json({ error: 'Missing required parameters: user_id/student_id, month, and status/is_paid.' });
  }
  try {
    await db.run(`
      INSERT INTO fees (user_id, month, paid_amount, status, payment_date)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(user_id, month) DO UPDATE SET
        paid_amount = excluded.paid_amount,
        status = excluded.status,
        payment_date = excluded.payment_date
    `, [targetUserId, month, paid_amount || 0, targetStatus, payment_date || new Date().toISOString().split('T')[0]]);
    res.json({ success: true, message: 'Fee record saved successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Periodic Job to mark devices offline if they haven't checked in for 2 minutes
setInterval(async () => {
  if (!db) return;
  try {
    const twoMinutesAgo = new Date(Date.now() - 120000);
    const limitTimestamp = getLocalTimestampString(twoMinutesAgo);

    await db.run(`
      UPDATE devices
      SET status = 'OFFLINE'
      WHERE last_seen < ? AND status = 'ONLINE'
    `, [limitTimestamp]);
  } catch (err) {
    console.error('Error in device offline checker:', err);
  }
}, 30000);

// Global Process Error Logging
process.on('unhandledRejection', (reason, promise) => {
  try {
    const fs = require('fs');
    const errorMsg = `\n--- [${new Date().toISOString()}] Unhandled Rejection ---\nReason: ${reason.stack || reason.message || reason}\n`;
    fs.appendFileSync(path.join(__dirname, 'server_errors.log'), errorMsg);
  } catch (e) { }
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (err) => {
  try {
    const fs = require('fs');
    const errorMsg = `\n--- [${new Date().toISOString()}] Uncaught Exception ---\nError: ${err.stack || err.message || err}\n`;
    fs.appendFileSync(path.join(__dirname, 'server_errors.log'), errorMsg);
  } catch (e) { }
  console.error('Uncaught Exception:', err);
});

// Start Server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`eSSL Push Server listening on: http://0.0.0.0:${PORT}`);
  console.log(`- Device cloud ADMS target URL: http://<server_ip>:${PORT}`);
  console.log(`- Heartbeat URL: http://<server_ip>:${PORT}/iclock/getrequest`);
  console.log(`- Ingestion URL: http://<server_ip>:${PORT}/iclock/cdata`);
});
