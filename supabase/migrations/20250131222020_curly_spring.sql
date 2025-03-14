-- Create a secure function for admin user registration
CREATE OR REPLACE FUNCTION auth.register_employee(
    p_email TEXT,
    p_password TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Check if the current user is an admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE id = auth.uid() 
        AND is_admin = true
    ) THEN
        RAISE EXCEPTION 'Only administrators can register employees';
    END IF;

    -- Create the user in auth.users
    v_user_id := (
        SELECT id FROM auth.users
        WHERE email = p_email
        LIMIT 1
    );

    IF v_user_id IS NULL THEN
        v_user_id := extensions.uuid_generate_v4();
        
        INSERT INTO auth.users (
            id,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            email_change,
            email_change_token_new,
            recovery_token
        )
        VALUES (
            v_user_id,
            p_email,
            crypt(p_password, gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}',
            '{}',
            now(),
            now(),
            '',
            '',
            '',
            ''
        );

        -- Create user role
        INSERT INTO public.user_roles (id, is_admin)
        VALUES (v_user_id, false);
    END IF;

    RETURN v_user_id;
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION auth.register_employee TO authenticated;