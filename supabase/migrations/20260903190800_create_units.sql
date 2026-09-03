CREATE TABLE units (
  id bigint CONSTRAINT units_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  code text CONSTRAINT units_code_uq UNIQUE NOT NULL CONSTRAINT units_code_chk CHECK (code = lower(trim(code))),
  name text NOT NULL,
  sort_order integer
  );
  
