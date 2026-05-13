-- 1. Create profiles table
CREATE TABLE profiles (
    id uuid PRIMARY KEY,
    organization_id uuid NOT NULL,
    role text CHECK (role IN ('admin', 'worker')) NOT NULL,
    email text UNIQUE NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- 2. Create projects table
CREATE TABLE projects (
    id uuid PRIMARY KEY,
    organization_id uuid NOT NULL,
    owner_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- 3. Create documents table
CREATE TABLE documents (
    id uuid PRIMARY KEY,
    organization_id uuid NOT NULL,
    project_id uuid REFERENCES projects(id) ON DELETE CASCADE,
    worker_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
    uploader_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
    expires_at timestamp with time zone,
    file_url text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- 4. Enable RLS
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policy: Only admins can see/upload documents for workers in their organization
CREATE POLICY "Admins can access org documents"
    ON documents
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid()
              AND role = 'admin'
              AND organization_id = documents.organization_id
        )
    );

CREATE POLICY "Admins can insert org documents"
    ON documents
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid()
              AND role = 'admin'
              AND organization_id = documents.organization_id
        )
    );
