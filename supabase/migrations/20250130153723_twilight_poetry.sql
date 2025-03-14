/*
  # Create user roles structure

  1. New Tables
    - `user_roles` table to store user role information
      - `id` (uuid, references auth.users)
      - `is_admin` (boolean)
      - `meta_is_admin` (text)

  2. Security
    - Enable RLS on user_roles table
    - Add policy for users to view their own role
    - Add policy for admins to view all roles
*/

-- Create user roles table
CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    is_admin BOOLEAN DEFAULT false,
    meta_is_admin TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own role"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Admins can view all roles"
    ON public.user_roles
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles AS ur
            WHERE ur.id = auth.uid() AND (ur.is_admin = true OR ur.meta_is_admin = 'true')
        )
    );

-- Grant access to authenticated users
GRANT SELECT ON public.user_roles TO authenticated;

-- Function to sync user roles
CREATE OR REPLACE FUNCTION public.sync_user_roles()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'is_admin' = 'true', false),
        NEW.raw_user_meta_data->>'is_admin'
    )
    ON CONFLICT (id) DO UPDATE
    SET
        is_admin = COALESCE(NEW.raw_user_meta_data->>'is_admin' = 'true', false),
        meta_is_admin = NEW.raw_user_meta_data->>'is_admin',
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for user role sync
DROP TRIGGER IF EXISTS sync_user_roles_trigger ON auth.users;
CREATE TRIGGER sync_user_roles_trigger
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_user_roles();

-- Insert initial admin user if not exists
INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
SELECT id, true, 'true'
FROM auth.users
WHERE email = 'yousufabdallah2000@gmail.com'
ON CONFLICT (id) DO UPDATE
SET is_admin = true, meta_is_admin = 'true', updated_at = now();