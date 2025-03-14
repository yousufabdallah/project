/*
  # Add Requests Management System

  1. New Tables
    - `requests`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `service_type` (text)
      - `description` (text)
      - `status` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on requests table
    - Add policies for users to manage their requests
    - Add policies for admins to manage all requests
*/

-- Create requests table
CREATE TABLE IF NOT EXISTS public.requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    service_type TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;

-- Policies for users to view their own requests
CREATE POLICY "Users can view their own requests"
    ON public.requests
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Policy for users to create their own requests
CREATE POLICY "Users can create their own requests"
    ON public.requests
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Policy for admins to view all requests
CREATE POLICY "Admins can view all requests"
    ON public.requests
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Policy for admins to update any request
CREATE POLICY "Admins can update any request"
    ON public.requests
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );