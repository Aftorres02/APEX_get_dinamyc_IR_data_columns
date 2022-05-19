
create or replace package apex_ir_util_project_details
is

--------------------------------------------------------------------------------
--*
--* 
--* 
--*
--------------------------------------------------------------------------------

-- CONSTANTS
type t_varchar_tbl is table of number;



-- GLOBALS
g_columns_count    number;
g_pk_column        varchar2(128);


procedure download_tasks(
    p_app_id               in apex_application_page_regions.application_id%type
  , p_page_id              in apex_application_page_regions.page_id%type
  , p_static_id            in apex_application_page_regions.static_id%type
  , p_file_name            in varchar2
);


procedure download_project_tasks(
    p_app_id               in apex_application_page_regions.application_id%type
  , p_page_id              in apex_application_page_regions.page_id%type
  , p_static_id            in apex_application_page_regions.static_id%type
  , p_file_name            in varchar2
);


end apex_ir_util_project_details;
/
