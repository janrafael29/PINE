// Copy to config.js (gitignored) and fill in values.
//
// Supabase: Settings → API → Project URL + anon public key.
// Admin user: Authentication → Users → Raw app metadata → "admin": true
//
// Optional — create/delete users from the admin “Users” panel:
//   1. Deploy: supabase functions deploy pine-admin-create-user
//              supabase functions deploy pine-admin-delete-user
//              supabase functions deploy pine-admin-update-user-profile
//   2. Set secret: supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
//   URLs default under `${supabaseUrl}/functions/v1/...`.
//   Override createUserFunctionUrl / deleteUserFunctionUrl / updateUserProfileFunctionUrl if needed.

window.PINE_ADMIN_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
  supabaseAnonKey: 'YOUR_ANON_PUBLIC_KEY',
  createUserFunctionUrl: '',
  deleteUserFunctionUrl: '',
  updateUserProfileFunctionUrl: '',
};
