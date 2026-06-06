const supabase = require('/Users/nilaydemir/IsikConnect/server/src/config/supabase').getAdminClient();

async function inspectMessages() {
  try {
    const { data, error } = await supabase
      .from('messages')
      .select('*')
      .limit(1);

    if (error) throw error;
    console.log('Messages table sample:', data.length > 0 ? data[0] : 'empty');
  } catch (err) {
    console.error('Error:', err);
  }
}

inspectMessages();
