
create or replace package apex_ir_util
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
g_columns_count number;
g_pk_column     varchar2(128);


procedure get_report_data_into_gtt(
    p_app_id                        in apex_application_page_regions.application_id%type
  , p_page_id                       in apex_application_page_regions.page_id%type
  , p_static_id                     in apex_application_page_regions.static_id%type
  , p_pk_column_name                in varchar2 default null
  , p_add_headers                   in boolean default false
  , p_remove_html_from_header       in boolean default false
);


procedure download(
    p_filename                       in varchar2
  , p_mime_header                    in varchar2 default 'text/csv'
  , p_content_disposition            in varchar2 default 'attachment'
  , p_cache_control_max_age          in varchar2 default '3600'
  , p_exclude_columns_tbl            in t_varchar_tbl
);

end apex_ir_util;
/
