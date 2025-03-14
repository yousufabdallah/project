/*
  # Create user roles table and view

  1. Changes
    - Create user_roles table to store role information
    - Create secure view for role access
  
  2. Security
    - Enable RLS
    - Add appropriate policies
*/

-- Create user_roles table first
CREATE TABLE IF NOT EXISTS public.user_roles_table (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT,
  is_admin BOOLEAN DEFAULT false,
  meta_is_admin TEXT
);

-- Enable RLS on the table
ALTER TABLE public.user_roles_table ENABLE ROW LEVEL SECURITY;

-- Create the view
CREATE OR REPLACE VIEW public.user_roles AS
SELECT 
  u.id,
  u.email,
  u.is_admin,
  u.raw_user_meta_data->>'is_admin' as meta_is_admin
FROM auth.users u;

-- Add RLS policy for the table
CREATE POLICY "Users can only view their own role"
  ON public.user_roles_table
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Grant access to authenticated users
GRANT SELECT ON public.user_roles TO authenticated;
GRANT SELECT ON public.user_roles_table TO authenticated;