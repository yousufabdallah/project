/*
  # Add Office Management Schema

  1. New Tables
    - `office_assignments`
      - `id` (uuid, primary key)
      - `region_id` (uuid, references regions)
      - `user_id` (uuid, references auth.users)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `office_assignments` table
    - Add policies for admins to manage assignments
    - Add policies for office staff to view their assignments

  3. Views
    - Create view for office assignments with user and region information
*/

-- Create office assignments table
CREATE TABLE IF NOT EXISTS public.office_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id UUID REFERENCES public.regions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(region_id, user_id)
);

-- Enable RLS
ALTER TABLE public.office_assignments ENABLE ROW LEVEL SECURITY;

-- Create policies for office assignments
CREATE POLICY "Admins can manage office assignments"
    ON public.office_assignments
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

CREATE POLICY "Users can view their own office assignments"
    ON public.office_assignments
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Create view for office assignments
CREATE OR REPLACE VIEW public.office_assignments_view AS
SELECT 
    oa.id,
    oa.region_id,
    oa.user_id,
    r.name as region_name,
    auth.get_user_email(oa.user_id) as user_email,
    oa.created_at,
    oa.updated_at
FROM public.office_assignments oa
JOIN public.regions r ON r.id = oa.region_id;

-- Grant necessary permissions
GRANT ALL ON public.office_assignments TO authenticated;
GRANT SELECT ON public.office_assignments_view TO authenticated;

-- Create function to update office assignments
CREATE OR REPLACE FUNCTION public.assign_office_staff(
    p_region_id UUID,
    p_user_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_assignment_id UUID;
BEGIN
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    -- Check if region exists
    IF NOT EXISTS (SELECT 1 FROM public.regions WHERE id = p_region_id) THEN
        RAISE EXCEPTION 'Region not found';
    END IF;

    -- Insert or update assignment
    INSERT INTO public.office_assignments (region_id, user_id)
    VALUES (p_region_id, p_user_id)
    ON CONFLICT (region_id, user_id) 
    DO UPDATE SET updated_at = now()
    RETURNING id INTO v_assignment_id;

    RETURN v_assignment_id;
END;
$$;