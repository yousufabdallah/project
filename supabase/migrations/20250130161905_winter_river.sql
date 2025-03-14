/*
  # Add regions management

  1. New Tables
    - `regions`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `regions` table
    - Add policies for admins to manage regions
    - Add policies for authenticated users to view regions
*/

-- Create regions table
CREATE TABLE IF NOT EXISTS public.regions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Anyone can view regions"
    ON public.regions
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can manage regions"
    ON public.regions
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );