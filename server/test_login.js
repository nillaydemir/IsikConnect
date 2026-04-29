const supabase = require('./src/config/supabase');

async function test() {
  const email = `testmentor_${Date.now()}@example.com`;
  const password = 'hashedpassword123';
  
  console.log("Creating user...");
  const { data: createData, error: createError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  });
  if (createError) {
      console.log("Create Error:", createError.message);
      return;
  }
  console.log("Created:", createData.user.id);
  
  console.log("Logging in...");
  const { data: loginData, error: loginError } = await supabase.auth.signInWithPassword({
    email,
    password
  });
  if (loginError) console.log("Login Error:", loginError.message);
  else console.log("Logged in:", loginData.user.id);
  
  // Cleanup
  await supabase.auth.admin.deleteUser(createData.user.id);
}
test();
