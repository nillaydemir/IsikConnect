require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function main() {
  const buckets = ['mentor-docs', 'documents'];
  for (const b of buckets) {
    const { data, error } = await supabase.storage.updateBucket(b, {
      public: true,
    });
    
    if (error) {
      console.log(`Error updating ${b}:`, error.message);
      
      // If it says not found, let's just try to create it as public
      if (error.message.includes('not found')) {
          const { data: cData, error: cError } = await supabase.storage.createBucket(b, { public: true });
          if (cError) {
              console.log(`Error creating ${b}:`, cError.message);
          } else {
              console.log(`Successfully created public bucket: ${b}`);
          }
      }
    } else {
      console.log(`Successfully updated bucket ${b} to be public.`);
    }
  }
}

main();
