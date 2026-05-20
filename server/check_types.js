const supabase = require('./src/config/supabase');
async function test() {
  const { data, error } = await supabase.from('students').select('available_days, interests').limit(1);
  console.log("students data:", data);
  if (data && data.length > 0) {
    console.log("available_days type:", typeof data[0].available_days, Array.isArray(data[0].available_days) ? "array" : "not array");
    console.log("interests type:", typeof data[0].interests, Array.isArray(data[0].interests) ? "array" : "not array");
  }
}
test();
