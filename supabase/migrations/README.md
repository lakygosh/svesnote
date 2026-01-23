# Database Migrations

## How to Apply Migrations

### Option 1: Using Supabase Dashboard (SQL Editor)

1. Go to your Supabase project dashboard at https://supabase.com/dashboard
2. Navigate to the SQL Editor (left sidebar)
3. Click "New query"
4. Copy and paste the contents of `create_processes_table.sql`
5. Click "Run" to execute the migration

### Option 2: Using Supabase CLI

If you have the Supabase CLI installed:

```bash
# Navigate to the project root
cd d:\lazar\Documents\Repositories\svesnote

# Run the migration
supabase db push
```

## Migrations

### create_processes_table.sql

Creates the `processes` table with the following structure:

- `id` (UUID, primary key)
- `user_id` (UUID, foreign key to auth.users)
- `name` (text, not empty)
- `description` (text, not empty)
- `status` (text, either 'active' or 'paused', defaults to 'active')
- `created_at` (timestamptz, defaults to NOW())
- `end_date` (timestamptz, nullable - null for lifetime processes)

Includes:
- Indexes on `user_id` and `status` for performance
- Row Level Security (RLS) policies for user data isolation
- Check constraints to ensure data validity
