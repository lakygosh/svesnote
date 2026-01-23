-- Create processes table
CREATE TABLE IF NOT EXISTS processes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  CONSTRAINT processes_name_not_empty CHECK (char_length(name) > 0),
  CONSTRAINT processes_description_not_empty CHECK (char_length(description) > 0)
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS idx_processes_user_id ON processes(user_id);

-- Create index on status for filtering active/paused processes
CREATE INDEX IF NOT EXISTS idx_processes_status ON processes(status);

-- Enable Row Level Security
ALTER TABLE processes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own processes
CREATE POLICY "Users can view their own processes"
  ON processes
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own processes
CREATE POLICY "Users can create their own processes"
  ON processes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own processes
CREATE POLICY "Users can update their own processes"
  ON processes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own processes
CREATE POLICY "Users can delete their own processes"
  ON processes
  FOR DELETE
  USING (auth.uid() = user_id);
