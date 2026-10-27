ALTER TABLE units ADD CONSTRAINT units_name_chk CHECK (length(trim(name)) > 0);
ALTER TABLE suppliers ADD CONSTRAINT suppliers_name_chk CHECK (length(trim(name)) > 0);
ALTER TABLE sites ADD CONSTRAINT sites_name_chk CHECK (length(trim(name)) > 0);
ALTER TABLE materials ADD CONSTRAINT materials_name_chk CHECK (length(trim(name)) > 0), ADD CONSTRAINT materials_article_no_chk CHECK (length(trim(article_no)) > 0);
