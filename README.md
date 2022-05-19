# APEX get dynamic IR data columns and append details

The propose of this "Toolkit" is get dynamically the data from the current IR report on APEX, it will include any users filters.
Additionally append details for each row.


## Maint steps
  1) Get SQL query from current Interactive Report (include the filters and search options).
  1) Use ` DBMS_SQL ` to read the current SQL.
  1) Use ` DBMS_SQL ` to write into a temporary table the values from the main query.
  1) Modify as you want the information on the temporary table, in this first version, we are appending extra detail columns for each row.
  1) Using the temporary table, Download into a csv file

## Packages description

### **apex_ir_util**

#### *apex_ir_util.get_report_data_into_gtt*

Get the currently running query on a page, including all user filters.

Then run the query and insert it into the temporary table download_300_cols_gtt.

The table supports at least 300 columns of the IR report.

The result is to have download_300_cols_gtt with the same information that the user is viewing on the page.

#### Params:

- ` p_pk_column_name ` look in the current query the column with the primary key, and store the column into ` apex_ir_util.g_pk_column `

- ` p_add_headers ` is a boolean, used to add into the report the Header labels of the IR

- ` p_remove_html_from_header ` if you want to print the header, it could contains html like ` <br>, <b>, etc `, if you want to remove it, set it as ` true  `

``` sql
  procedure get_report_data_into_gtt(
      p_app_id                        in apex_application_page_regions.application_id%type
    , p_page_id                       in apex_application_page_regions.page_id%type
    , p_static_id                     in apex_application_page_regions.static_id%type
    , p_pk_column_name                in varchar2 default null
    , p_add_headers                   in boolean default false
    , p_remove_html_from_header       in boolean default false
  );
```


#### *apex_ir_util.download*


  The download process creates a CSV file with the information from the table download_300_cols_gtt.

  The number of columns are dynamically created using the information from the current report.

  Warning: this will execute apex_application.stop_apex_engine to complete the download process.
#### Params:

  - ` p_filename ` name of the file to download.

  - ` p_exclude_columns_tbl ` Contains the number of the column or columns that you don't want to download.

``` sql
  procedure download(
      p_filename                       in varchar2
    , p_mime_header                    in varchar2 default 'text/csv'
    , p_content_disposition            in varchar2 default 'attachment'
    , p_cache_control_max_age          in varchar2 default '3600'
    , p_exclude_columns_tbl            in t_varchar_tbl
  );
```

---

### **apex_ir_util_project_details**

#### *apex_ir_util_project_details.download_project_tasks*

Prepare the data into temporary table download_300_cols_gtt using ` apex_ir_util.get_report_data_into_gtt `.

Append additinal colummns specific for this report, number of columns and query to download its fixed.

The result is to have download_300_cols_gtt with the same information that the user is viewing on the page with the details information for each row.

#### Params:

- ` p_app_id ` Application ID

- ` p_page_id ` Page ID

- ` p_static_id ` Static ID of the report to download

- ` p_file_name ` Name of the file to download

```sql
  procedure download_project_tasks(
      p_app_id               in apex_application_page_regions.application_id%type
    , p_page_id              in apex_application_page_regions.page_id%type
    , p_static_id            in apex_application_page_regions.static_id%type
    , p_file_name            in varchar2
  )
```