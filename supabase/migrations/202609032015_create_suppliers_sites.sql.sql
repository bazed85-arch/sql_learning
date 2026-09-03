CREATE TABLE suppliers (
  id bigint CONSTRAINT suppliers_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  name text CONSTRAINT suppliers_name_nn NOT NULL,
  tax_id text CONSTRAINT suppliers_tax_id_uq UNIQUE,
  contact_person text,
  phone text,
  email text,
  payment_terms_days integer CONSTRAINT suppliers_payment_terms_days_chk CHECK (payment_terms_days >=0),
  is_active boolean CONSTRAINT suppliers_is_active_nn NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz CONSTRAINT suppliers_created_at_nn NOT NULL DEFAULT now()
  );

CREATE TABLE sites (
  id bigint CONSTRAINT sites_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  code text CONSTRAINT sites_code_nn NOT NULL CONSTRAINT sites_code_uq UNIQUE,
  name text CONSTRAINT sites_name_nn NOT NULL,
  address text,
  status text CONSTRAINT sites_status_nn NOT NULL CONSTRAINT sites_status_chk CHECK (status IN ('planned','active','suspended','completed')),
  start_date date,
  planned_end_date date,
  actual_end_date date,
  created_at timestamptz CONSTRAINT sites_created_at_nn NOT NULL DEFAULT now()
  );
  
