-- server/src/db/reviews_table.sql

CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    mentor_id UUID NOT NULL REFERENCES public.mentors(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(mentor_id, student_id)
);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON public.reviews
    FOR SELECT USING (true);

-- Allow all operations for authenticated users or service role
CREATE POLICY "Enable all operations for authenticated users" ON public.reviews
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');
