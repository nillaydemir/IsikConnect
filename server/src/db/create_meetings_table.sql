CREATE TABLE IF NOT EXISTS meetings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    meeting_type TEXT NOT NULL CHECK (meeting_type IN ('1-on-1', 'Workshop')),
    meeting_date TIMESTAMP WITH TIME ZONE NOT NULL,
    mentor_id UUID REFERENCES users(id) ON DELETE CASCADE,
    student_id UUID REFERENCES users(id) ON DELETE CASCADE,
    capacity INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table to handle multiple participants (students) for a Workshop meeting
CREATE TABLE IF NOT EXISTS workshop_participants (
    meeting_id UUID REFERENCES meetings(id) ON DELETE CASCADE,
    student_id UUID REFERENCES users(id) ON DELETE CASCADE,
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (meeting_id, student_id)
);
