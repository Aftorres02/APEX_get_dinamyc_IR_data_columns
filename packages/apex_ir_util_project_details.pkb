-- alter session set PLSQL_CCFLAGS='VERBOSE_OUTPUT:TRUE';
create or replace package body apex_ir_util_project_details
is


gc_scope_prefix constant VARCHAR2(31) := lower($$PLSQL_UNIT) || '.';




/**
 * This download_tasks
 *
 *
 * @example
 *
 * @issue
 *
 * @author Angel Flores
 * @created sábado, 14 mayo 2022
 * @param p_app_id
 * @param p_page_id
 * @param p_static_id
 * @param p_file_name
 */
procedure download_tasks(
    p_app_id               in apex_application_page_regions.application_id%type
  , p_page_id              in apex_application_page_regions.page_id%type
  , p_static_id            in apex_application_page_regions.static_id%type
  , p_file_name            in varchar2
)
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'download_tasks';
  l_params logger.tab_param;


  l_exclude_columns_tbl    apex_ir_util.t_varchar_tbl;
begin
  logger.append_param(l_params, 'p_app_id', p_app_id);
  logger.append_param(l_params, 'p_page_id', p_page_id);
  logger.append_param(l_params, 'p_static_id', p_static_id);
  logger.append_param(l_params, 'p_file_name', p_file_name);
  logger.log('BEGIN', l_scope, null, l_params);

   apex_ir_util.get_report_data_into_gtt(
      p_app_id          => p_app_id
    , p_page_id         => p_page_id
    , p_static_id       => p_static_id
    , p_pk_column_name  => 'ID'
    , p_add_headers     => true
    , p_remove_html_from_header  => true
  );

  -- If you want exclude a column
  -- l_exclude_columns_tbl := apex_ir_util.t_varchar_tbl();
  -- l_exclude_columns_tbl.extend;
  -- l_exclude_columns_tbl(l_exclude_columns_tbl.last) := 1;

  apex_ir_util.download(
      p_filename                  => p_file_name || '_' || to_char(sysdate,'yyyymmdd') || '.csv'
    , p_exclude_columns_tbl       => l_exclude_columns_tbl
  );

  logger.log('END', l_scope, null, l_params);
  exception
    when OTHERS then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
end download_tasks;





/**
 * This download_project_tasks
 *
 *
 * @example
 *
 * @issue
 *
 * @author Angel Flores
 * @created sábado, 14 mayo 2022
 * @param p_app_id
 * @param p_page_id
 * @param p_static_id
 * @param p_file_name
 */
procedure download_project_tasks(
    p_app_id               in apex_application_page_regions.application_id%type
  , p_page_id              in apex_application_page_regions.page_id%type
  , p_static_id            in apex_application_page_regions.static_id%type
  , p_file_name            in varchar2
)
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'download_project_tasks';
  l_params logger.tab_param;


  l_exclude_columns_tbl     apex_ir_util.t_varchar_tbl;
  l_cursor                  sys_refcursor;
  l_sql                     varchar2(32767);
  l_sql_headers             varchar2(32767);
  l_additional_cols         varchar2(1000);
  l_exits_details           number;
  l_line_number             number;
  l_project_id              number;
  i                         number;
begin
  logger.append_param(l_params, 'p_app_id', p_app_id);
  logger.append_param(l_params, 'p_page_id', p_page_id);
  logger.append_param(l_params, 'p_static_id', p_static_id);
  logger.append_param(l_params, 'p_file_name', p_file_name);
  logger.log('BEGIN', l_scope, null, l_params);

  apex_ir_util.get_report_data_into_gtt(
      p_app_id          => p_app_id
    , p_page_id         => p_page_id
    , p_static_id       => p_static_id
    , p_pk_column_name  => 'ID'
    , p_add_headers     => true
    , p_remove_html_from_header  => true
  );


  logger.log('.. Adding aditional headers', l_scope, null, l_params);
  -- get current totals columns
  i := apex_ir_util.g_columns_count;

 -- increase the headers to print
 -- we added 5 new headers with the detail
  apex_ir_util.g_columns_count := apex_ir_util.g_columns_count + 5;


  l_sql :=
  'update download_300_cols_gtt'
    || ' set '
    || '  col' || trim(to_char(i + 1, '000')) || ' = '' Task'''
    || ', col' || trim(to_char(i + 2, '000')) || ' = '' Assignee '''
    || ', col' || trim(to_char(i + 3, '000')) || ' = '' Start Date '''
    || ', col' || trim(to_char(i + 4, '000')) || ' = '' End Date '''
    || ', col' || trim(to_char(i + 5, '000')) || ' = '' Cost '''
    || ' where line_number = 0';
  logger.log(l_sql, l_scope, null, l_params);

  -- update columns
  execute immediate l_sql;

  -- Allocation columns
  l_additional_cols :=
     ', col' || trim(to_char(i + 1, '000'))
  || ', col' || trim(to_char(i + 2, '000'))
  || ', col' || trim(to_char(i + 3, '000'))
  || ', col' || trim(to_char(i + 4, '000'))
  || ', col' || trim(to_char(i + 5, '000'));

  -- Example column headers
  /*
  l_sql_headers :=
  'insert into download_300_cols_gtt (
      line_number
    , row_level
    , first_order '
  || l_additional_cols
  || q'[
  )
  select :l_line_number
       , 1 row_level
       , 2 first_order
       , 'Task'  task
       , 'Assignee'  assignee
       , 'Start Date'  start_date
       , 'End Date'  end_date
       , 'Cost'  cost
    from dual
  ]';
 */

  l_sql :=
  'insert into download_300_cols_gtt (
      line_number
    , row_level
    , first_order '
  || l_additional_cols
  || q'[
  )
  select :l_line_number
       , 1 row_level
       , 3 first_order
       , name
       , assignee
       , start_date
       , end_date
       , cost
    from eba_project_tasks
   where project_id = :project_id
  ]';

  $IF $$VERBOSE_OUTPUT $THEN
  logger.log('.. Alloc insert SQL', l_scope);
  logger.log(l_sql, l_scope);
  $END


  -- Insert each detail to the parent
  open l_cursor for
   'select line_number, ' || apex_ir_util.g_pk_column || ' id
      from download_300_cols_gtt
     where line_number != 0';
  loop

    fetch l_cursor into l_line_number, l_project_id;
    exit when l_cursor%notfound;

    -- validation to prevent insert empty headers
    select count(*)
      into l_exits_details
      from eba_project_tasks
     where project_id = l_project_id;

    if l_exits_details > 0 then
       --execute immediate l_sql_headers using l_line_number; -- example column headers
       execute immediate l_sql using l_line_number, l_project_id;
    end if;

  end loop;
  close l_cursor;


  -- If you want exclude a column
  -- l_exclude_columns_tbl := apex_ir_util.t_varchar_tbl();
  -- l_exclude_columns_tbl.extend;
  -- l_exclude_columns_tbl(l_exclude_columns_tbl.last) := 1;

  apex_ir_util.download(
      p_filename                  => p_file_name || '_' || to_char(sysdate,'yyyymmdd') || '.csv'
    , p_exclude_columns_tbl       => l_exclude_columns_tbl
  );

  logger.log('END', l_scope, null, l_params);
  exception
    when OTHERS then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
end download_project_tasks;



end apex_ir_util_project_details;
/
