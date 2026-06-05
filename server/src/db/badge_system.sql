-- Add badge column to mentors table
ALTER TABLE mentors ADD COLUMN IF NOT EXISTS badge TEXT DEFAULT '🌱 New Mentor' NOT NULL;

-- Add attended column to meetings table
ALTER TABLE meetings ADD COLUMN IF NOT EXISTS attended BOOLEAN DEFAULT false NOT NULL;
