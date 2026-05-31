-- Create job_postings table
CREATE TABLE IF NOT EXISTS public.job_postings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mentor_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    company TEXT NOT NULL,
    description TEXT NOT NULL,
    requirements TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create job_applications table (student_id references students(id) directly for perfect joins)
CREATE TABLE IF NOT EXISTS public.job_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES public.job_postings(id) ON DELETE CASCADE NOT NULL,
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
    cover_note TEXT,
    cv_url TEXT,
    status TEXT NOT NULL DEFAULT 'applied', -- 'applied', 'accepted', 'rejected'
    feedback TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_job_student UNIQUE (job_id, student_id)
);

-- CRITICAL: Explicit GRANT statements to make these tables accessible via Supabase Data API (PostgREST)
GRANT ALL ON TABLE public.job_postings TO postgres, anon, authenticated, service_role;
GRANT ALL ON TABLE public.job_applications TO postgres, anon, authenticated, service_role;

-- Enable Row Level Security (RLS)
ALTER TABLE public.job_postings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow read access to authenticated users" ON public.job_postings;
DROP POLICY IF EXISTS "Allow insert for mentors and admins" ON public.job_postings;
DROP POLICY IF EXISTS "Allow update and delete for owners" ON public.job_postings;

DROP POLICY IF EXISTS "Allow student inserts for applications" ON public.job_applications;
DROP POLICY IF EXISTS "Allow student to read own applications" ON public.job_applications;
DROP POLICY IF EXISTS "Allow mentor to read applications for their jobs" ON public.job_applications;
DROP POLICY IF EXISTS "Allow mentor to update status" ON public.job_applications;

-- RLS Policies for job_postings
CREATE POLICY "Allow read access to authenticated users" ON public.job_postings
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert for mentors and admins" ON public.job_postings
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = mentor_id);

CREATE POLICY "Allow update and delete for owners" ON public.job_postings
    FOR ALL TO authenticated USING (auth.uid() = mentor_id);

-- RLS Policies for job_applications
CREATE POLICY "Allow student inserts for applications" ON public.job_applications
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = student_id);

-- Everyone authenticated can select, but to be safe: students see theirs, mentors see theirs
CREATE POLICY "Allow student to read own applications" ON public.job_applications
    FOR SELECT TO authenticated USING (
        auth.uid() = student_id OR 
        auth.uid() IN (SELECT mentor_id FROM public.job_postings WHERE id = job_id)
    );

CREATE POLICY "Allow mentor to update status" ON public.job_applications
    FOR UPDATE TO authenticated USING (
        auth.uid() IN (SELECT mentor_id FROM public.job_postings WHERE id = job_id)
    );
