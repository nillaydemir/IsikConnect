-- Bu script Supabase SQL Editor'a yapıştırılıp çalıştırılabilir.
-- Sadece Eşleştirme (Matching) algoritmasını ve Admin panelini test etmek için
-- rastgele UUID'lerle sahte kullanıcılar oluşturur. 
-- Not: Bu kullanıcılar auth.users tablosunda olmadığı için bunlarla 'Login' olamazsınız, 
-- sadece listelerde görünürler ve admin panelinden onaylanabilirler.

-- 3 adet rastgele UUID üretiyoruz
DO $$
DECLARE
    mentor1_id UUID := gen_random_uuid();
    mentor2_id UUID := gen_random_uuid();
    mentor3_id UUID := gen_random_uuid();
BEGIN

    -- 1. USERS TABLOSUNA EKLEME
    INSERT INTO public.users (id, first_name, last_name, email, role, phone, is_approved)
    VALUES 
    (mentor1_id, 'Ahmet', 'Yılmaz', 'ahmet.yilmaz@test.com', 'mentor', '5551112233', false),
    (mentor2_id, 'Ayşe', 'Kaya', 'ayse.kaya@test.com', 'mentor', '5552223344', false),
    (mentor3_id, 'Mehmet', 'Demir', 'mehmet.demir@test.com', 'mentor', '5553334455', false);

    -- 2. MENTORS TABLOSUNA EKLEME
    -- 'interests' alanına case-insensitive (büyük/küçük harf duyarsız) eşleşmeyi test etmek için
    -- özellikle farklı formatlarda alanlar ekledik.
    INSERT INTO public.mentors (id, graduation_document_url, company, job_title, graduation_year, max_students, interests, available_days, status)
    VALUES 
    (mentor1_id, 'https://example.com/doc1.pdf', 'Google', 'Senior Software Engineer', '2018', 3, '["Yapay Zeka", "Siber Güvenlik"]'::jsonb, '["Monday", "Wednesday"]'::jsonb, 'pending'),
    (mentor2_id, 'https://example.com/doc2.pdf', 'Microsoft', 'Data Scientist', '2020', 2, '["veri bilimi", "Makine Öğrenmesi"]'::jsonb, '["Tuesday", "Thursday"]'::jsonb, 'pending'),
    (mentor3_id, 'https://example.com/doc3.pdf', 'Trendyol', 'Mobile Developer', '2021', 5, '["mobil geliştirme", "Yapay Zeka"]'::jsonb, '["Friday"]'::jsonb, 'pending');

    -- 3. APPLICATIONS TABLOSUNA EKLEME (Admin Panelinde Görünmesi İçin)
    INSERT INTO public.applications (user_id, role, document_url, status)
    VALUES 
    (mentor1_id, 'mentor', 'https://example.com/doc1.pdf', 'pending'),
    (mentor2_id, 'mentor', 'https://example.com/doc2.pdf', 'pending'),
    (mentor3_id, 'mentor', 'https://example.com/doc3.pdf', 'pending');

END $$;
