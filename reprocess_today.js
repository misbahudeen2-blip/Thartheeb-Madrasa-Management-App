const sqlite3 = require('sqlite3').verbose();
const { open } = require('sqlite');
const path = require('path');

function getAbsoluteCheckinStartTime(startTime, checkinStartStr) {
  if (!startTime || !checkinStartStr) return '00:00:00';
  if (!isNaN(checkinStartStr)) {
    const mins = parseInt(checkinStartStr);
    const [h, m, s] = startTime.split(':').map(Number);
    let totalSecs = (h * 3600) + (m * 60) + (s || 0);
    totalSecs -= (mins * 60);
    if (totalSecs < 0) totalSecs = 0;
    const rh = Math.floor(totalSecs / 3600);
    const rm = Math.floor((totalSecs % 3600) / 60);
    const rs = totalSecs % 60;
    return `${String(rh).padStart(2, '0')}:${String(rm).padStart(2, '0')}:${String(rs).padStart(2, '0')}`;
  }
  return checkinStartStr;
}

async function run() {
  const db = await open({
    filename: path.join(__dirname, 'attendance.db'),
    driver: sqlite3.Database
  });

  const today = '2026-07-13';
  console.log(`Clearing daily_attendance for ${today}...`);
  await db.run('DELETE FROM daily_attendance WHERE work_date = ?', [today]);

  console.log(`Fetching raw punches for ${today}...`);
  const punches = await db.all('SELECT * FROM raw_punches WHERE punch_time LIKE ? ORDER BY punch_time ASC', [`${today}%`]);
  console.log(`Found ${punches.length} raw punches today. Reprocessing...`);

  for (const p of punches) {
    const userId = p.user_id;
    const punchTimeStr = p.punch_time;
    const SN = p.device_sn;
    const verifyMode = p.verify_mode;
    const punchState = p.punch_state;

    // Get student profile and active shift rules
    const student = await db.get(`
      SELECT s.user_id, s.name, s.batch_id, s.role,
             sh.shift_id, sh.start_time, sh.grace_minutes, sh.checkin_start, sh.checkin_end,
             sh.is_flexible, sh.alt_day, sh.alt_start_time, sh.alt_checkin_start, sh.alt_checkin_end
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.batch_id
      LEFT JOIN shifts sh ON b.shift_id = sh.shift_id
      WHERE s.user_id = ?
    `, [userId]);

    if (!student) {
      console.log(`Skipping unregistered user ID: ${userId}`);
      continue;
    }

    const punchDate = punchTimeStr.split(' ')[0];
    const punchTime = punchTimeStr.split(' ')[1];

    if (student.role === 'teacher') {
      const assignments = await db.all(`
        SELECT ta.*, sh.start_time as shift_start, sh.end_time as shift_end, sh.is_flexible, sh.alt_day, sh.alt_start_time, sh.alt_end_time
        FROM teacher_assignments ta
        LEFT JOIN shifts sh ON ta.shift_id = sh.shift_id
        WHERE ta.user_id = ?
      `, [userId]);

      let matchedBatch = 'UNORGANIZED';
      let matchedShift = 'UNORGANIZED';
      let matchedTime = '09:00:00';
      let isCheckoutPunch = false;

      const [ph, pm, ps] = punchTime.split(':').map(Number);
      const punchSeconds = (ph * 3600) + (pm * 60) + (ps || 0);

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

          // Check-in diff
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

          // Check-out diff
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

      const existingAttendance = await db.get(`
        SELECT * FROM daily_attendance
        WHERE user_id = ? AND work_date = ? AND batch_id = ?
      `, [userId, punchDate, matchedBatch]);

      if (!isCheckoutPunch) {
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

          let remarkMsg = `Teacher Checked In (Batch: ${matchedBatch})`;
          if (status === 'Late') {
            remarkMsg = `Teacher Late by ${lateMinutes} mins (Batch: ${matchedBatch})`;
          }

          await db.run(`
            INSERT INTO daily_attendance (user_id, work_date, check_in, check_out, late_minutes, attendance_status, remarks, role, batch_id)
            VALUES (?, ?, ?, NULL, ?, ?, ?, 'teacher', ?)
          `, [userId, punchDate, punchTimeStr, lateMinutes, status, remarkMsg, matchedBatch]);

          console.log(`[Teacher Reprocess] Checked In ${student.name} (${userId}) for batch ${matchedBatch}.`);
        }
      } else {
        if (existingAttendance) {
          const [endH, endM, endS] = matchedTime.split(':').map(Number);
          const expectedSeconds = (endH * 3600) + (endM * 60) + (endS || 0);
          const leftEarlyMinutes = Math.floor((expectedSeconds - punchSeconds) / 60);

          let remarkMsg = `Teacher Checked Out (Batch: ${matchedBatch})`;
          if (leftEarlyMinutes > 0) {
            remarkMsg = `Teacher Left Early by ${leftEarlyMinutes} mins (Batch: ${matchedBatch})`;
          }

          await db.run(`
            UPDATE daily_attendance
            SET check_out = ?, remarks = ?
            WHERE id = ?
          `, [punchTimeStr, remarkMsg, existingAttendance.id]);

          console.log(`[Teacher Reprocess] Checked Out ${student.name} (${userId}) for batch ${matchedBatch}.`);
        } else {
          await db.run(`
            INSERT INTO daily_attendance (user_id, work_date, check_in, check_out, late_minutes, attendance_status, remarks, role, batch_id)
            VALUES (?, ?, NULL, ?, 0, 'Present', ?, 'teacher', ?)
          `, [userId, punchDate, punchTimeStr, `Teacher Checked Out (No Check-in, Batch: ${matchedBatch})`, matchedBatch]);

          console.log(`[Teacher Reprocess] Checked Out (No Check-in) ${student.name} (${userId}) for batch ${matchedBatch}.`);
        }
      }
      continue;
    }

    // Student Ingestion
    const existingAttendance = await db.get(`
      SELECT id FROM daily_attendance
      WHERE user_id = ? AND work_date = ?
    `, [userId, punchDate]);

    if (existingAttendance) continue;

    if (!student.start_time || !student.checkin_start || !student.checkin_end) {
      await db.run(`
        INSERT INTO daily_attendance (user_id, work_date, check_in, late_minutes, attendance_status, remarks, role, batch_id)
        VALUES (?, ?, ?, 0, 'Present', 'No Batch Configured', 'student', ?)
      `, [userId, punchDate, punchTimeStr, student.batch_id || 'UNORGANIZED']);
      console.log(`[Student Reprocess] Marked Present ${student.name} (${userId}).`);
      continue;
    }

    let startTime = student.start_time;
    let checkinStart = getAbsoluteCheckinStartTime(student.start_time, student.checkin_start);
    let checkinEnd = student.checkin_end;
    let isAltDay = false;

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

    if (punchTime < checkinStart) {
      await db.run(`
        INSERT INTO daily_attendance (user_id, work_date, check_in, late_minutes, attendance_status, remarks, role, batch_id)
        VALUES (?, ?, ?, 0, 'Early', 'Punched before limit', 'student', ?)
      `, [userId, punchDate, punchTimeStr, student.batch_id || 'UNORGANIZED']);
      console.log(`[Student Reprocess] Early punch ${student.name} (${userId}).`);
    } else {
      const [startH, startM, startS] = startTime.split(':').map(Number);
      const [punchH, punchM, punchS] = punchTime.split(':').map(Number);
      const expectedSeconds = (startH * 3600) + (startM * 60) + (startS || 0);
      const punchSeconds = (punchH * 3600) + (punchM * 60) + (punchS || 0);
      const diffMinutes = Math.floor((punchSeconds - expectedSeconds) / 60);
      const graceMinutes = student.grace_minutes !== null ? student.grace_minutes : 10;

      let status = 'Present';
      let lateMinutes = 0;
      const isFallback = (student.shift_id === 'UNORGANIZED' || !student.shift_id);
      if (!isFallback && diffMinutes > graceMinutes) {
        status = 'Late';
        lateMinutes = diffMinutes;
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
      `, [userId, punchDate, punchTimeStr, lateMinutes, status, remarkMsg, student.batch_id || 'UNORGANIZED']);
      console.log(`[Student Reprocess] Marked ${status} ${student.name} (${userId}).`);
    }
  }

  console.log('Today\'s raw punches successfully reprocessed!');
  await db.close();
}

run().catch(console.error);
