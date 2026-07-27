const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('attendance.db');

const userId = '501';
const punchTimeStr = '2026-07-13 16:37:56';
const SN = 'NFZ8255300541';
const punchState = 0;
const verifyMode = 1;

const origGet = db.get.bind(db);
const origAll = db.all.bind(db);

db.getAsync = function(sql, params) {
  return new Promise((resolve, reject) => {
    origGet(sql, params, (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });
};
db.allAsync = function(sql, params) {
  return new Promise((resolve, reject) => {
    origAll(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
};

async function run() {
  try {
    const student = await db.getAsync(`
      SELECT s.user_id, s.name, s.batch_id, s.role,
             sh.shift_id, sh.start_time, sh.grace_minutes, sh.checkin_start, sh.checkin_end,
             sh.is_flexible, sh.alt_day, sh.alt_start_time, sh.alt_checkin_start, sh.alt_checkin_end
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.batch_id
      LEFT JOIN shifts sh ON b.shift_id = sh.shift_id
      WHERE s.user_id = ?
    `, [userId]);

    console.log('Student:', student);

    const punchDate = punchTimeStr.split(' ')[0]; // YYYY-MM-DD
    const punchTime = punchTimeStr.split(' ')[1]; // HH:MM:SS

    if (student.role === 'teacher') {
      const assignments = await db.allAsync(`
        SELECT ta.*, sh.start_time as shift_start, sh.end_time as shift_end, sh.is_flexible, sh.alt_day, sh.alt_start_time, sh.alt_end_time
        FROM teacher_assignments ta
        LEFT JOIN shifts sh ON ta.shift_id = sh.shift_id
        WHERE ta.user_id = ?
      `, [userId]);

      console.log('Assignments:', assignments);

      let matchedBatch = 'UNORGANIZED';
      let matchedShift = 'UNORGANIZED';
      let matchedTime = '09:00:00';
      let isCheckoutPunch = false;

      const [ph, pm, ps] = punchTime.split(':').map(Number);
      const punchSeconds = (ph * 3600) + (pm * 60) + (ps || 0);

      let minDiff = Infinity;
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

      console.log(`Matched Batch: ${matchedBatch}, isCheckout: ${isCheckoutPunch}, matchedTime: ${matchedTime}`);

      const existingAttendance = await db.getAsync(`
        SELECT * FROM daily_attendance
        WHERE user_id = ? AND work_date = ? AND batch_id = ?
      `, [userId, punchDate, matchedBatch]);

      console.log('Existing attendance:', existingAttendance);

      if (!isCheckoutPunch) {
        if (!existingAttendance) {
          console.log('Inserting check-in to daily_attendance for batch', matchedBatch);
        } else {
          console.log('Duplicate check-in, skipping.');
        }
      } else {
        if (existingAttendance) {
          console.log('Updating checkout in daily_attendance for batch', matchedBatch);
        } else {
          console.log('Checkout without check-in, inserting check-out to daily_attendance for batch', matchedBatch);
        }
      }
    }
  } catch (err) {
    console.error('Error:', err);
  } finally {
    db.close();
  }
}

run();
