-- 1. Create forum-images bucket if it doesn't exist (Supabase Storage)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('forum-images', 'forum-images', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Create forum_posts table
CREATE TABLE IF NOT EXISTS forum_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('Announcements', 'Q&A', 'Workshops')),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    tags TEXT[] DEFAULT '{}',
    
    -- Q&A specifics
    is_solved BOOLEAN DEFAULT false,
    accepted_answer_id UUID, -- References forum_comments(id) later
    
    -- Workshop specifics
    event_date TIMESTAMP WITH TIME ZONE,
    meeting_link TEXT,
    participant_limit INTEGER,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 3. Create forum_comments table
CREATE TABLE IF NOT EXISTS forum_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_accepted BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Note: Now that forum_comments exists, we can add the foreign key to forum_posts safely
-- ALter table forum_posts add foreign key (accepted_answer_id) references forum_comments(id) on delete set null;
-- (Skipping explicit constraint to avoid circular dependency issues, application logic handles it safely)

-- 4. Create forum_likes table
CREATE TABLE IF NOT EXISTS forum_likes (
    post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (post_id, user_id)
);

-- 5. Create forum_bookmarks table
CREATE TABLE IF NOT EXISTS forum_bookmarks (
    post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (post_id, user_id)
);

-- 6. Create forum_workshop_participants table
CREATE TABLE IF NOT EXISTS forum_workshop_participants (
    post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (post_id, user_id)
);

-- 7. Create forum_reports table
CREATE TABLE IF NOT EXISTS forum_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES forum_comments(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    CHECK (post_id IS NOT NULL OR comment_id IS NOT NULL)
);
