# Admin bootstrap

The application now uses `wa_admins` as an explicit allow-list. Creating a Supabase Auth user alone does not grant campaign administration.

1. Apply `supabase/migrations/001_initial.sql`, then `002_admin_security.sql` in the Supabase SQL editor or migration workflow.
2. Create/sign up the intended administrator in Supabase Authentication.
3. In Supabase Authentication > Users, copy that user's UUID.
4. Run this once in the Supabase SQL editor, replacing the placeholder UUID:

```sql
insert into public.wa_admins(user_id)
values ('00000000-0000-0000-0000-000000000000')
on conflict (user_id) do nothing;
```

Do not put the service-role key in the browser or source repository. API routes that perform privileged actions must authenticate the signed-in user and verify membership in `wa_admins`; background queue/webhook operations use protected server credentials.
