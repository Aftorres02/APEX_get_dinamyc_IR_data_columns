-- alter session set PLSQL_CCFLAGS='VERBOSE_OUTPUT:TRUE';
create or replace package body apex_ir_util
is


gc_scope_prefix constant VARCHAR2(31) := lower($$PLSQL_UNIT) || '.';

g_app_id           apex_application_page_regions.application_id%type;
g_page_id          apex_application_page_regions.page_id%type;
g_static_id        apex_application_page_regions.static_id%type;




/**
 * This get the current report on the page
 * include the filters and bind variables
 * This will use the global variables  app_id, page_id, static_id
 *
 *
 * @author Angel Flores
 * @created Thursday, 07 April 2022
 * @return apex_ir.t_report  Array with the report info
 */
function get_report_info
  return apex_ir.t_report
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'get_report_info';
  l_params logger.tab_param;

  l_report_id   number;
  l_region_id   number;
  l_report      apex_ir.t_report;

begin
  logger.log('START', l_scope, null, l_params);

  select region_id
    into l_region_id
    from apex_application_page_regions
   where application_id = g_app_id
     and page_id = g_page_id
     and static_id = g_static_id;

    begin
      l_report_id := apex_ir.get_last_viewed_report_id (p_page_id     => g_page_id
                                                      , p_region_id   => l_region_id);
    exception
      when others then
        l_report_id := null;
    end;

    l_report := apex_ir.get_report (p_page_id     => g_page_id
                                  , p_region_id   => l_region_id
                                  , p_report_id   => l_report_id
                );

    return l_report;

  exception
    when OTHERS then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
end get_report_info;






/**
 * Convert the Columns Alias to the Report format label
 * Accept a parameter to removed an HTML
 *
 * @author Angel Flores
 * @created Friday, 08 April 2022
 * @param p_column_alias
 * @param p_remove_html_from_header
 * @return varchar2 The column label
 */
function get_column_label(
    p_column_alias                      in   apex_application_page_ir_col.column_alias%type
  , p_remove_html_from_header           in   boolean default false
) return varchar2
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'get_column_label';
  l_params logger.tab_param;

  l_column_report_label     apex_application_page_ir_col.report_label%type;
begin
  $IF $$VERBOSE_OUTPUT $THEN
  logger.append_param(l_params, 'p_column_alias', p_column_alias);
  logger.log('START', l_scope, null, l_params);
  $END

    select ic.report_label
      into l_column_report_label
      from apex_application_page_ir_col ic
     inner join apex_application_page_regions r on r.application_id = ic.application_id
                                               and r.page_id = ic.page_id
                                               and r.region_id = ic.region_id
     where r.application_id = g_app_id
       and r.page_id = g_page_id
       and r.static_id = g_static_id
       and ic.column_alias = p_column_alias;


    if p_remove_html_from_header then
      l_column_report_label := replace(l_column_report_label,'<br>',' ');
      l_column_report_label := replace(l_column_report_label,'<br/>',' ');
    end if;

    return l_column_report_label;

  exception
    when OTHERS then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
end get_column_label;








/**
 * Get the currently running query on a page, including all user filters
 * Then run the query and insert it into the temporary table download_300_cols_gtt
 * The table supports at least 200 columns of the IR report
 * p_add_headers is a boolean, used to append to the report the Header labels of the IR
 * The result is to have download_300_cols_gtt with the same information that the user is viewing on the page
 *
 * @author Angel Flores
 * @created Thursday, 07 April 2022
 * @param p_app_id
 * @param p_page_id
 * @param p_static_id
 * @param p_pk_column_name [Optional] specify the PK column in the report, if available, the COLnnn value is set in g_pk_column
 * @param p_add_headers
 * @param p_remove_html_from_header
 */
procedure get_report_data_into_gtt(
    p_app_id                        in apex_application_page_regions.application_id%type
  , p_page_id                       in apex_application_page_regions.page_id%type
  , p_static_id                     in apex_application_page_regions.static_id%type
  , p_pk_column_name                in varchar2 default null
  , p_add_headers                   in boolean default false
  , p_remove_html_from_header       in boolean default false
)
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'get_report_data_into_gtt';
  l_params logger.tab_param;

  type t_varchar_tbl is table of varchar2(255) index by pls_integer;
  l_columns_values_tbl t_varchar_tbl;

  l_report                     apex_ir.t_report;
  l_source_cursor              pls_integer;
  l_destination_cursor         pls_integer;
  l_status                     pls_integer;
  l_status_destination         pls_integer;
  l_varchar_type               varchar2(4000);
  l_rows_count                 number := 0;
  l_description_tab            dbms_sql.desc_tab;
  l_cols                       varchar2(32767);
  l_cols_bind                  varchar2(32767);
  l_destination_sql            varchar2(32767);
  l_column_report_label        apex_application_page_ir_col.report_label%type;
  l_bind_column                varchar2 (50);

  $IF $$VERBOSE_OUTPUT $THEN
  l_out_rows                   varchar2(32767);
  $END

begin

  logger.append_param(l_params, 'p_app_id', p_app_id);
  logger.append_param(l_params, 'p_page_id', p_page_id);
  logger.append_param(l_params, 'p_static_id', p_static_id);
  logger.log('BEGIN', l_scope, null, l_params);

  -- set globals
  g_app_id := p_app_id;
  g_page_id := p_page_id;
  g_static_id := p_static_id;

  l_report := get_report_info;

  l_source_cursor := dbms_sql.open_cursor;
  dbms_sql.parse (l_source_cursor, l_report.sql_query, dbms_sql.native);

  logger.log(' ... l_source_sql: ' || l_report.sql_query);


  for i in 1 .. l_report.binds.count
  loop
    $IF $$VERBOSE_OUTPUT $THEN
    logger.log('... param(' || i || ') name(' || l_report.binds(i).name || ') value('|| l_report.binds(i).value || ')', l_scope);
    $END

    dbms_sql.bind_variable(
        l_source_cursor
      , l_report.binds(i).name
      , l_report.binds(i).value
      , 32765
    );
  end loop;

  dbms_sql.describe_columns (l_source_cursor, g_columns_count, l_description_tab);
  $IF $$VERBOSE_OUTPUT $THEN
  logger.log(' .. Columns on the source sql: '||  g_columns_count);
  $END

  -- START BUILDING DESTINATION QUERY
  -- The destination is a table dummy to store x number of columns determined by the source statement (select)
  -- we need to prepare the columns to insert and the binds

  -- Build the column list
  -- l_cols = col001
  -- l_cols = col001, col002, ...
  -- 
  -- l_cols_bind = :col001
  -- l_cols_bind = :col001, :col002, ...
  for i in 1 .. g_columns_count
  loop
    l_cols := l_cols || ', col' || trim(to_char(i,'000'));
    l_cols_bind := l_cols_bind || ', :col' || trim(to_char(i,'000'));
  end loop;

  -- Build the full insert statement
  l_destination_sql := 'insert into download_300_cols_gtt ( line_number, row_level, first_order ';
  l_destination_sql := l_destination_sql || l_cols || ') values (:line_number, :row_level, :first_order ' || l_cols_bind || ')';

  $IF $$VERBOSE_OUTPUT $THEN
  logger.log(' ... l_destination_sql: ' || l_destination_sql);
  $END

  l_destination_cursor := dbms_sql.open_cursor;
  dbms_sql.parse(l_destination_cursor,l_destination_sql,dbms_sql.native);

  -- END BUILDING DESTINATION QUERY of the form:
  --    insert into download_300_cols_gtt ( line_number, row_level, col001, col002, ...)
  --    value (:line_number, :row_level, :col001, :col002, ...);
  ------------------------------------------------------------------------------


  -- define source columns
  for i in 1 .. g_columns_count loop
    dbms_sql.define_column(l_source_cursor, i, l_varchar_type, 200);
  end loop;


  l_status := dbms_sql.execute(l_source_cursor);

  if p_add_headers then -- insert headers label to the dummy table
    dbms_sql.bind_variable(l_destination_cursor, 'line_number', 0);
    dbms_sql.bind_variable(l_destination_cursor, 'row_level', 0);   -- row level 0 is reserved for the headers labels
    dbms_sql.bind_variable(l_destination_cursor, 'first_order', 1); -- all the data starts grouped together, order = 1

    for i in 1 .. g_columns_count
    loop
      l_column_report_label := get_column_label(
         p_column_alias => l_description_tab(i).col_name
       , p_remove_html_from_header  => p_remove_html_from_header
      );
      l_bind_column  := 'col'|| trim(to_char(i,'000'));
      dbms_sql.bind_variable(l_destination_cursor, l_bind_column,  l_column_report_label);

      if l_description_tab(i).col_name = p_pk_column_name then
        -- Find the PK and save the column position, for example PK_ID → col002
        -- 
        g_pk_column := l_bind_column;
      end if;

    end loop;
    -- Execute the insert into the table
    l_status_destination := dbms_sql.execute(l_destination_cursor);

  end if; -- end  p_add_headers


  --------- Fecth the results from the SOURCE SQL and then insert into the DESTINATION table
  while dbms_sql.fetch_rows (l_source_cursor) > 0
  loop
    l_rows_count := l_rows_count + 1 ;
    dbms_sql.bind_variable(l_destination_cursor, 'line_number', l_rows_count);
    dbms_sql.bind_variable(l_destination_cursor, 'row_level', 1); --- by default the row level is 1. Headers are level zero.
    dbms_sql.bind_variable(l_destination_cursor, 'first_order', 1); -- all the data starts grouped together, order = 1

    for i in 1 .. g_columns_count
    loop
      dbms_sql.column_value (l_source_cursor, i, l_varchar_type);
      $IF $$VERBOSE_OUTPUT $THEN
      l_out_rows := l_out_rows || ' | ' || l_varchar_type;
      $END

      l_bind_column  := 'col'|| trim(to_char(i,'000'));
      dbms_sql.bind_variable(l_destination_cursor, l_bind_column, l_varchar_type);

    end loop;
    l_status_destination := dbms_sql.execute(l_destination_cursor);

    $IF $$VERBOSE_OUTPUT $THEN
    l_out_rows := l_out_rows || ' | ' ;
    logger.log(' ... row(' || l_rows_count || ') => ' || l_out_rows);
    l_out_rows := null;
    $END

  end loop;

  logger.log(' ... Total rows processed ' ||  l_rows_count || ' and columns: ' || g_columns_count , l_scope);

  dbms_sql.close_cursor(l_source_cursor);
  dbms_sql.close_cursor(l_destination_cursor);


  logger.log('END', l_scope, null, l_params);
  exception
    when OTHERS then
      if dbms_sql.is_open(l_source_cursor) then
        dbms_sql.close_cursor(l_source_cursor);
      end if;
      if dbms_sql.is_open(l_destination_cursor) then
        dbms_sql.close_cursor(l_destination_cursor);
      end if;
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
end get_report_data_into_gtt;







/**
 * The download process creates a CSV file with the information from the table download_300_cols_gtt
 * The number of columns are dynamically created using the information from the current report
 * p_exclude_columns_tbl Contains the number of the column or columns that you don't want to download
 * Warning: this will execute apex_application.stop_apex_engine to complete the download process
 *
 *
 * @author Angel Flores
 * @created Friday, 08 April 2022
 * @param p_filename
 * @param p_mime_header
 * @param p_content_disposition
 * @param p_cache_control_max_age
 * @param p_exclude_columns_tbl
 */
procedure download(
    p_filename                       in varchar2
  , p_mime_header                    in varchar2 default 'text/csv'
  , p_content_disposition            in varchar2 default 'attachment'
  , p_cache_control_max_age          in varchar2 default '0'
  , p_exclude_columns_tbl            in t_varchar_tbl
)
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'download';
  l_params logger.tab_param;

  l_sql               varchar2(32767);
  l_first_element     boolean := true;
begin
  logger.append_param(l_params, 'p_filename', p_filename);
  logger.log('BEGIN', l_scope, null, l_params);

  sys.htp.init;
  sys.owa_util.mime_header( p_mime_header , FALSE );
  sys.htp.p('Content-Disposition: ' || p_content_disposition || '; filename="' || p_filename || '"' );
  sys.htp.p('Cache-Control: max-age=' ||  p_cache_control_max_age );  -- tell the browser to cache for one hour, adjust as necessary
  sys.owa_util.http_header_close;


  l_sql := q'[
    begin
      for r in (
        select ]';

  -- append the number of columns to print, avoid or skip the columns in p_exclude_columns_tbl (like col001)
 for i in 1.. g_columns_count loop
    if i member of p_exclude_columns_tbl then
      continue;
    else
      if l_first_element then
        l_sql := l_sql || ' col' || trim(to_char(i,'000'));
        l_first_element := false;
      else
        l_sql := l_sql || ', col' || trim(to_char(i,'000'));
      end if;
    end if;
  end loop;

  $IF $$VERBOSE_OUTPUT $THEN
  logger.log('.. Columns to select', l_scope, null, l_params);
  logger.log(l_sql, l_scope, null, l_params);
  $END

  l_sql := l_sql || '
    from download_300_cols_gtt
    order by line_number
           , first_order
    )
    loop
    -- Print out the row
    -- separated by commas and ended by a CR
      htp.prn( ';

  l_first_element := true;
  for i in 1.. g_columns_count loop
    if i member of p_exclude_columns_tbl then
      continue;
    else
      if l_first_element then
        l_sql := l_sql || q'[ '"'  || r.col]' || trim(to_char(i,'000'))  || q'[ || '"' ]';
        l_first_element := false;
      else
        l_sql := l_sql || q'[  || ',"' || r.col]' || trim(to_char(i,'000'))  || q'[ || '"' ]';
      end if;
    end if;
  end loop;

   l_sql := l_sql ||
    ' || chr(13));
      end loop;

    end;
  ';

  $IF $$VERBOSE_OUTPUT $THEN
  logger.log(' ... SQL to download: ' || l_sql );
  $END

  execute immediate l_sql;

  logger.log('END', l_scope, null, l_params);

  -- Since we're downloading from APEX we need to tell it to stop processing
  apex_application.stop_apex_engine;

  exception
    when apex_application.e_stop_apex_engine then
      null;

    when OTHERS then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
end download;







end apex_ir_util;
/
