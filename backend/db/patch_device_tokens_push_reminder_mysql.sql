-- Optional: tracks last engagement reminder per device token.
-- Safe to skip: cron/push-reminders also adds this column automatically when missing.
ALTER TABLE device_tokens
  ADD COLUMN last_push_reminder_at DATETIME NULL AFTER last_seen_at;
