const supabase = require('./src/config/supabase');

async function checkAndCreateBucket() {
  const bucketName = 'profile-images';
  console.log(`Checking if bucket '${bucketName}' exists...`);
  
  const { data: buckets, error } = await supabase.storage.listBuckets();
  
  if (error) {
    console.error('Error listing buckets:', error);
    return;
  }
  
  const exists = buckets.find(b => b.name === bucketName);
  
  if (exists) {
    console.log(`Bucket '${bucketName}' already exists.`);
  } else {
    console.log(`Bucket '${bucketName}' does not exist. Creating it...`);
    const { data, error: createError } = await supabase.storage.createBucket(bucketName, {
      public: true, // Make it public so images can be viewed
      allowedMimeTypes: ['image/png', 'image/jpeg', 'image/jpg', 'image/gif'],
      fileSizeLimit: 5242880 // 5MB
    });
    
    if (createError) {
      console.error('Error creating bucket:', createError);
    } else {
      console.log('Bucket created successfully!', data);
    }
  }
}

checkAndCreateBucket();
