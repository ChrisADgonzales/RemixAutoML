#' @title AutoDataDictionaries
#'
#' @description AutoDataDictionaries is a function to return data dictionary data in table form
#'
#' @author Adrian Antico
#'
#' @family Database
#'
#' @param Type = "sqlserver" is currently the only system supported
#' @param DBConnection This is a RODBC connection object for sql server
#' @param DDType Select from 1 - 6 based on this article
#' @param Query Supply a query
#' @param ASIS Set to TRUE to pull in values without coercing types
#' @param CloseChannel Set to TRUE to disconnect
#'
#' @export
AutoDataDictionaries <- function(Type = "sqlserver",
                                 DBConnection,
                                 DDType = 1L,
                                 Query = NULL,
                                 ASIS = FALSE,
                                 CloseChannel = TRUE) {

  # Ensure DBConnection is proper----
  if(!class(DBConnection) == "RODBC") return("Invalid DBConnection")

  library(RODBC)

  # Queries----
  if(!is.null(Query)) {
    x <- data.table::as.data.table(RODBC::sqlQuery(DBConnection, Query, as.is = ASIS))
    if(CloseChannel) close(DBConnection)
    return(x)
  }

  # Tables and number of columns----
  if(DDType == 1L) {
    qry <- "select schema_name(tab.schema_id) as schema_name,
       tab.name as table_name,
       tab.create_date as created,
       tab.modify_date as last_modified,
       p.rows as num_rows,
       ep.value as comments
  from sys.tables tab
       inner join (select distinct
                          p.object_id,
                          sum(p.rows) rows
                     from sys.tables t
                          inner join sys.partitions p
                              on p.object_id = t.object_id
                    group by p.object_id,
                          p.index_id) p
            on p.object_id = tab.object_id
        left join sys.extended_properties ep
            on tab.object_id = ep.major_id
           and ep.name = 'MS_Description'
           and ep.minor_id = 0
           and ep.class_desc = 'OBJECT_OR_COLUMN'
  order by schema_name,
        table_name"

    # Return data----
    x <- data.table::as.data.table(sqlQuery(DBConnection, qry))
    if(CloseChannel) close(DBConnection)
    return(x)
  }

  # Tables and number of columns----
  if(DDType == 2L) {
    qry <- "select schema_name(v.schema_id) as schema_name,
       v.name as view_name,
       v.create_date as created,
       v.modify_date as last_modified,
       m.definition,
       ep.value as comments
  from sys.views v
       left join sys.extended_properties ep
           on v.object_id = ep.major_id
          and ep.name = 'MS_Description'
          and ep.minor_id = 0
          and ep.class_desc = 'OBJECT_OR_COLUMN'
       inner join sys.sql_modules m
           on m.object_id = v.object_id
 order by schema_name,
          view_name"

    # Return data----
    x <- data.table::as.data.table(sqlQuery(DBConnection, qry))
    if(CloseChannel) close(DBConnection)
    return(x)
  }

  # Tables and number of columns----
  if(DDType == 3L) {
    qry <- "select schema_name(tab.schema_id) as schema_name,
       tab.name as table_name,
       col.name as column_name,
       t.name as data_type,
       t.name +
       case when t.is_user_defined = 0 then
                 isnull('(' +
                 case when t.name in ('binary', 'char', 'nchar',
                           'varchar', 'nvarchar', 'varbinary') then
                           case col.max_length
                                when -1 then 'MAX'
                                else
                                     case when t.name in ('nchar',
                                               'nvarchar') then
                                               cast(col.max_length/2
                                               as varchar(4))
                                          else cast(col.max_length
                                               as varchar(4))
                                     end
                           end
                      when t.name in ('datetime2', 'datetimeoffset',
                           'time') then
                           cast(col.scale as varchar(4))
                      when t.name in ('decimal', 'numeric') then
                            cast(col.precision as varchar(4)) + ', ' +
                            cast(col.scale as varchar(4))
                 end + ')', '')
            else ':' +
                 (select c_t.name +
                         isnull('(' +
                         case when c_t.name in ('binary', 'char',
                                   'nchar', 'varchar', 'nvarchar',
                                   'varbinary') then
                                    case c.max_length
                                         when -1 then 'MAX'
                                         else
                                              case when t.name in
                                                        ('nchar',
                                                        'nvarchar') then
                                                        cast(c.max_length/2
                                                        as varchar(4))
                                                   else cast(c.max_length
                                                        as varchar(4))
                                              end
                                    end
                              when c_t.name in ('datetime2',
                                   'datetimeoffset', 'time') then
                                   cast(c.scale as varchar(4))
                              when c_t.name in ('decimal', 'numeric') then
                                   cast(c.precision as varchar(4)) + ', '
                                   + cast(c.scale as varchar(4))
                         end + ')', '')
                    from sys.columns as c
                         inner join sys.types as c_t
                             on c.system_type_id = c_t.user_type_id
                   where c.object_id = col.object_id
                     and c.column_id = col.column_id
                     and c.user_type_id = col.user_type_id
                 )
        end as data_type_ext,
        case when col.is_nullable = 0 then 'N'
             else 'Y' end as nullable,
        case when def.definition is not null then def.definition
             else '' end as default_value,
        case when pk.column_id is not null then 'PK'
             else '' end as primary_key,
        case when fk.parent_column_id is not null then 'FK'
             else '' end as foreign_key,
        case when uk.column_id is not null then 'UK'
             else '' end as unique_key,
        case when ch.check_const is not null then ch.check_const
             else '' end as check_contraint,
        cc.definition as computed_column_definition,
        ep.value as comments
   from sys.tables as tab
        left join sys.columns as col
            on tab.object_id = col.object_id
        left join sys.types as t
            on col.user_type_id = t.user_type_id
        left join sys.default_constraints as def
            on def.object_id = col.default_object_id
        left join (
                  select index_columns.object_id,
                         index_columns.column_id
                    from sys.index_columns
                         inner join sys.indexes
                             on index_columns.object_id = indexes.object_id
                            and index_columns.index_id = indexes.index_id
                   where indexes.is_primary_key = 1
                  ) as pk
            on col.object_id = pk.object_id
           and col.column_id = pk.column_id
        left join (
                  select fc.parent_column_id,
                         fc.parent_object_id
                    from sys.foreign_keys as f
                         inner join sys.foreign_key_columns as fc
                             on f.object_id = fc.constraint_object_id
                   group by fc.parent_column_id, fc.parent_object_id
                  ) as fk
            on fk.parent_object_id = col.object_id
           and fk.parent_column_id = col.column_id
        left join (
                  select c.parent_column_id,
                         c.parent_object_id,
                         'Check' check_const
                    from sys.check_constraints as c
                   group by c.parent_column_id,
                         c.parent_object_id
                  ) as ch
            on col.column_id = ch.parent_column_id
           and col.object_id = ch.parent_object_id
        left join (
                  select index_columns.object_id,
                         index_columns.column_id
                    from sys.index_columns
                         inner join sys.indexes
                             on indexes.index_id = index_columns.index_id
                            and indexes.object_id = index_columns.object_id
                    where indexes.is_unique_constraint = 1
                    group by index_columns.object_id,
                          index_columns.column_id
                  ) as uk
            on col.column_id = uk.column_id
           and col.object_id = uk.object_id
        left join sys.extended_properties as ep
            on tab.object_id = ep.major_id
           and col.column_id = ep.minor_id
           and ep.name = 'MS_Description'
           and ep.class_desc = 'OBJECT_OR_COLUMN'
        left join sys.computed_columns as cc
            on tab.object_id = cc.object_id
           and col.column_id = cc.column_id
  order by schema_name, table_name"

    # Return data----
    x <- data.table::as.data.table(sqlQuery(DBConnection, qry))
    if(CloseChannel) close(DBConnection)
    return(x)
  }

  # Tables and number of columns----
  if(DDType == 4L) {
    qry <- "SELECT
       schema_name(tab.schema_id) AS table_schema_name,
       tab.name AS table_name,
       col.name AS column_name,
       fk.name AS constraint_name,
       schema_name(tab_prim.schema_id) AS primary_table_schema_name,
       tab_prim.name AS primary_table_name,
       col_prim.name AS primary_table_column,
       schema_name(tab.schema_id) + '.' + tab.name + '.' + col.name + ' = ' + schema_name(tab_prim.schema_id) + '.' + tab_prim.name + '.' + col_prim.name AS join_condition,
       case when count(*) over (partition by fk.name) > 1 then 'Y' else 'N' end AS complex_fk,
       fkc.constraint_column_id AS fk_part
    FROM sys.tables AS tab
       INNER JOIN sys.foreign_keys AS fk
           ON tab.object_id = fk.parent_object_id
       INNER JOIN sys.foreign_key_columns AS fkc
           ON fk.object_id = fkc.constraint_object_id
       INNER JOIN sys.columns AS col
           ON fkc.parent_object_id = col.object_id
          AND fkc.parent_column_id = col.column_id
       INNER JOIN sys.columns AS col_prim
           ON fkc.referenced_object_id = col_prim.object_id
          AND fkc.referenced_column_id = col_prim.column_id
       INNER JOIN sys.tables AS tab_prim
           ON fk.referenced_object_id = tab_prim.object_id
     ORDER BY
       table_schema_name,
       table_name,
       primary_table_name,
       fk_part"

    # Return data----
    x <- data.table::as.data.table(sqlQuery(DBConnection, qry))
    if(CloseChannel) close(DBConnection)
    return(x)
  }

  # Views and Columns----
  if(DDType == 5L) {
    qry <- "SELECT
      schema_name(v.schema_id) AS schema_name,
      v.name AS view_name,
      col.name AS column_name,
      t.name AS data_type,
      t.name +
      CASE WHEN t.is_user_defined = 0 THEN
                 ISNULL('(' +
                 CASE WHEN t.name IN ('binary', 'char', 'nchar','varchar', 'nvarchar', 'varbinary') THEN
                   CASE col.max_length when -1 THEN 'MAX'
                     ELSE
                       CASE WHEN t.name IN ('nchar','nvarchar') THEN
                         CAST(col.max_length/2 AS varchar(4)) ELSE
                         CAST(col.max_length AS varchar(4))
                   END
                 END
                      when t.name IN ('datetime2',
                           'datetimeoffset', 'time') THEN
                            cast(col.scale AS varchar(4))
                      when t.name IN ('decimal', 'numeric') THEN
                           cast(col.precision AS varchar(4)) + ', ' +
                           cast(col.scale AS varchar(4))
                 END + ')', '')
            ELSE ':' +
                 (SELECT c_t.name +
                         ISNULL('(' +
                         CASE WHEN c_t.name IN ('binary','char','nchar', 'varchar', 'nvarchar','varbinary') THEN
                           CASE c.max_length
                             WHEN -1 THEN 'MAX'
                             ELSE
                               CASE WHEN t.name IN ('nchar','nvarchar')
                                 THEN cast(c.max_length/2 AS varchar(4))
                                 ELSE cast(c.max_length AS varchar(4))
                                             END
                                   END
                              WHEN c_t.name IN ('datetime2',
                                   'datetimeoffset', 'time') THEN
                                   cast(c.scale AS varchar(4))
                              WHEN c_t.name IN ('decimal', 'numeric') THEN
                                   cast(c.precision AS varchar(4)) +
                                   ', ' + cast(c.scale AS varchar(4))
                         END + ')', '')
                  FROM
                    sys.columns AS c
                  INNER JOIN
                    sys.types AS c_t
                  ON
                    c.system_type_id = c_t.user_type_id
                  WHERE c.object_id = col.object_id
                    and c.column_id = col.column_id
                    and c.user_type_id = col.user_type_id
                 ) END AS data_type_ext,
       CASE WHEN col.is_nullable = 0 THEN 'N' ELSE 'Y' END AS nullable,
       ep.value AS comments
  FROM
    sys.views AS v
  JOIN
    sys.columns AS col
  ON
    v.object_id = col.object_id
  LEFT JOIN
    sys.types AS t
  ON
    col.user_type_id = t.user_type_id
  LEFT JOIN
    sys.extended_properties AS ep
  ON
    v.object_id = ep.major_id
    AND col.column_id = ep.minor_id
    AND ep.name = 'MS_Description'
    AND ep.class_desc = 'OBJECT_OR_COLUMN'
 ORDER BY
   schema_name,
   view_name,
   column_name"

    # Return data----
    x <- data.table::as.data.table(sqlQuery(DBConnection, qry))
    if(CloseChannel) close(DBConnection)
    return(x)
  }

  # Tables and number of columns----
  if(DDType == 6L) {
    qry <- "SELECT
    schema_name(tab.schema_id) AS schema_name,
      tab.name AS table_name,
      COUNT(*) AS columns
    FROM sys.tables AS tab
    INNER JOIN
      sys.columns AS col
    ON
      tab.object_id = col.object_id
    GROUP BY
      schema_name(tab.schema_id),
      tab.name
    ORDER BY
      COUNT(*) DESC"

    # Return data----
    x <- data.table::as.data.table(sqlQuery(DBConnection, qry))
    if(CloseChannel) close(DBConnection)
    return(x)
  }
}

#' @title SQL_Server_DBConnection
#'
#' @description SQL_Server_DBConnection makes a connection to a sql server database
#'
#' @author Adrian Antico
#'
#' @family Database
#'
#' @param DataBaseName Name of the database
#' @param Server Name of the server to use
#'
#' @export
SQL_Server_DBConnection <- function(DataBaseName = "",
                                    Server = "") {
  return(RODBC::odbcDriverConnect(connection  = paste0("Driver={SQL Server};
                                  server=",Server,"; database=",DataBaseName,";
                                  trusted_connection=yes;")))
}

#' @title SQL_Query_Push
#'
#' @description SQL_Query_Push push data to a database table
#'
#' @author Adrian Antico
#'
#' @family Database
#'
#' @param DBConnection RemixAutoML::SQL_Server_DBConnection()
#' @param Query The SQL statement you want to run
#' @param CloseChannel TRUE to close when done, FALSE to leave the channel open
#'
#' @export
SQL_Query_Push <- function(DBConnection,
                           Query,
                           CloseChannel = TRUE) {
  library(RODBC)
  if(!class(DBConnection) == "RODBC") stop("Invalid DBConnection")
  if(!is.null(Query)) {
    RODBC::sqlQuery(channel = DBConnection, query = Query)
    if(CloseChannel) close(DBConnection)
  }
}

#' @title SQL_Query
#'
#' @description SQL_Query get data from a database table
#'
#' @author Adrian Antico
#'
#' @family Database
#'
#' @param DBConnection RemixAutoML::SQL_Server_DBConnection()
#' @param Query The SQL statement you want to run
#' @param ASIS Auto column typing
#' @param CloseChannel TRUE to close when done, FALSE to leave the channel open
#' @param RowsPerBatch Rows default is 1024
#'
#' @export
SQL_Query <- function(DBConnection,
                      Query,
                      ASIS = FALSE,
                      CloseChannel = TRUE,
                      RowsPerBatch = 1024) {
  library(RODBC)
  if(!class(DBConnection) == "RODBC") stop("Invalid DBConnection")
  if(!is.null(Query)) {
    x <- data.table::as.data.table(RODBC::sqlQuery(channel = DBConnection, query = Query, as.is = ASIS, rows_at_time = RowsPerBatch))
    if(CloseChannel) close(DBConnection)
    return(x)
  }
}

#' @title SQL_ClearTable
#'
#' @description SQL_ClearTable remove all rows from a database table
#'
#' @author Adrian Antico
#'
#' @family Database
#'
#' @param DBConnection RemixAutoML::SQL_Server_DBConnection()
#' @param SQLTableName The SQL statement you want to run
#' @param CloseChannel TRUE to close when done, FALSE to leave the channel open
#' @param Errors Set to TRUE to halt, FALSE to return -1 in cases of errors
#'
#' @export
SQL_ClearTable <- function(DBConnection,
                           SQLTableName = "",
                           CloseChannel = TRUE,
                           Errors = TRUE) {
  library(RODBC)
  if(!class(DBConnection) == "RODBC") stop("Invalid DBConnection")
  RODBC::sqlClear(
    channel = DBConnection,
    sqtable = SQLTableName,
    errors  = Errors)
  if(CloseChannel) close(DBConnection)
}

#' @title SQL_DropTable
#'
#' @description SQL_DropTable drop a database table
#'
#' @author Adrian Antico
#'
#' @family Database
#'
#' @param DBConnection RemixAutoML::SQL_Server_DBConnection()
#' @param SQLTableName The SQL statement you want to run
#' @param CloseChannel TRUE to close when done, FALSE to leave the channel open
#' @param Errors Set to TRUE to halt, FALSE to return -1 in cases of errors
#'
#' @export
SQL_DropTable <- function(DBConnection,
                          SQLTableName = "",
                          CloseChannel = TRUE,
                          Errors = TRUE) {
  library(RODBC)
  if(!class(DBConnection) == "RODBC") stop("Invalid DBConnection")
  RODBC::sqlDrop(
    channel = DBConnection,
    sqtable = SQLTableName,
    errors  = Errors)
  if(CloseChannel) close(DBConnection)
}

#' @title SQL_SaveTable
#'
#' @description SQL_SaveTable create a database table
#'
#' @author Adrian Antico
#'
#' @family Database
#'
#' @param DataToPush data to be sent to warehouse
#' @param DBConnection RemixAutoML::SQL_Server_DBConnection()
#' @param SQLTableName The SQL statement you want to run
#' @param RowNames c("Segment","Date")
#' @param ColNames Column names in first row
#' @param AppendData TRUE or FALSE
#' @param AddPK Add a PK column to table
#' @param CloseChannel TRUE to close when done, FALSE to leave the channel open
#' @param Safer TRUE
#'
#' @export
SQL_SaveTable <- function(DataToPush,
                          DBConnection,
                          SQLTableName = "",
                          RowNames = NULL,
                          ColNames = TRUE,
                          CloseChannel = TRUE,
                          AppendData = FALSE,
                          AddPK = TRUE,
                          Safer = TRUE) {
  library(RODBC)
  if(!class(DBConnection) == "RODBC") stop("Invalid DBConnection")
  RODBC::sqlSave(rownames=RowNames,colnames=ColNames,channel=DBConnection,dat=DataToPush,tablename=SQLTableName,addPK=AddPK,append=AppendData,safer=Safer)
  if(CloseChannel) close(DBConnection)
}

#' @title SQL_UpdateTable
#'
#' @description SQL_UpdateTable update a database table
#'
#' @author Adrian Antico
#'
#' @family Database
#'
#' @param DataToPush Update data table in warehouse with new values
#' @param DBConnection RemixAutoML::SQL_Server_DBConnection()
#' @param SQLTableName The SQL statement you want to run
#' @param Index Column name of index
#' @param Verbose TRUE or FALSE
#' @param Test Set to TRUE to see if what you plan to do will work
#' @param NAString Supply character string to supply missing values
#' @param Fast Set to TRUE to update table in one shot versus row by row
#' @param CloseChannel TRUE to close when done, FALSE to leave the channel open
#'
#' @export
SQL_UpdateTable <- function(DataToPush,
                            DBConnection,
                            SQLTableName = "",
                            Index = NULL,
                            CloseChannel = TRUE,
                            Verbose = TRUE,
                            Test = FALSE,
                            NAString = "NA",
                            Fast = TRUE) {
  library(RODBC)
  if(!class(DBConnection) == "RODBC") stop("Invalid DBConnection")
  RODBC::sqlUpdate(
    channel   = DBConnection,
    dat       = DataToPush,
    tablename = SQLTableName,
    index     = Index,
    verbose   = Verbose,
    test      = Test,
    nastring  = NAString,
    fast      = Fast)
  if(CloseChannel) close(DBConnection)
}

#' @title ExecuteSSIS
#'
#' @description Run an SSIS package from R. Function will check to make sure you can run an SSIS package and it will remove the output file if it exists so as to not append data on top of it.
#'
#' @family DataBase
#'
#' @author Adrian Antico
#'
#' @param PkgPath Path to SSIS package includin the package name and the package extension .dtsx
#' @param CSVPath Path to the csv output data location including the name of the file and the .csv extension
#'
#' @export
ExecuteSSIS <- function(PkgPath = NULL,
                        CSVPath = NULL) {

  # Modify paths
  PkgPath <- gsub("/", "\\\\", PkgPath)
  OutputPath <- gsub("/", "\\\\", OutputPath)

  # Ensure env var exists
  EnvVars <- data.table::as.data.table(unlist(data.table::tstrsplit(x = Sys.getenv("PATH"), split = ";", fixed = TRUE)))
  EnvVars[, V1 := gsub("\\\\", ".", V1)]

  # Stop if vars don't exist
  if(EnvVars[, sum(data.table::fifelse(V1 %like% "C:.Program Files.Microsoft SQL Server.150.DTS.Binn.", 1, 0)) == 0]) {
    Err <- paste("Need to add C:\\Program Files\\Microsoft SQL Server\\150\\DTS.Binn\\ to the PATH environment variable list")
    stop(eval(Err))
  }

  # Delete csv if it exists
  if(file.exists(CSVPath)) {
    shell(paste0("del ", CSVPath))
  }

  # Create command prompt script
  Cmd <- paste0("DTExec.exe -f ", shQuote(type = "cmd", string = PkgPath))

  # Run SSIS package
  system(Cmd)
}

#' @title SQL_Server_BulkPull
#'
#' @description Pull data from a sql server warehouse using bulk copy process
#'
#' @family Database
#'
#' @author Adrian Antico
#'
#' @param Server Server name
#' @param DBName Name of the database
#' @param TableName Name of the table to pull
#' @param Query Leave NULL to pull entire talbe or supply a query
#' @param FinalColumnNames Supply this if you supply a query that isn't a select * query
#' @param SavePath Path file to where you want the text file saved
#' @param SaveFileName Name of the text file to create
#' @param DeleteTextFile Remove text file when done loading into R
#'
#' @export
SQL_Server_BulkPull <- function(Server = NULL,
                                DBName = NULL,
                                TableName = NULL,
                                Query = NULL,
                                FinalColumnNames = NULL,
                                SavePath = NULL,
                                SaveFileName = NULL,
                                DeleteTextFile = TRUE) {

  # Check ----
  if(!is.nul(Query) && !grepl(pattern = "*", Query, fixed = TRUE) && is.null(FinalColumnNames)) stop("You have supply FinalColumnNames for this type of run")

  # Convert timestamp columns ----
  if(is.null(Query) || grepl(pattern = "*", Query, fixed = TRUE)) {

    # Metadata ----
    TabNames <- data.table::tstrsplit(TableName, ".", fixed = TRUE)
    TabNames <- TabNames[[length(TableName)]]
    TableInfo <- AutoDataDictionaries(
      Type = "sqlserver",
      DBConnection = SQL_Server_DBConnection(DataBaseName = DBName, Server = Server),
      DDType = 3L,
      Query = NULL,
      ASIS = FALSE,
      CloseChannel = TRUE)
    Cols <- TableInfo$column_name
    Types <- as.character(TableInfo$data_type)

    # Build query
    if(any(Types %chin% "timestamp")) {
      Colss <- noquote(paste0(Cols[-which(Types == "timestamp")], sep = ","))
      Colsss <- c(Colss, noquote(Cols[which(Types == "timstamp")]))
      Colsss <- paste(gsub(pattern = ",", replacement = "", Colsss))
      BadCols <- length(Cols[which(Types == "timestamp")])
      if(BadCols == 1L) {
        star <- c(Colss, paste0("convert(varchar, ", Cols[which(Types == "timestamp")],", 23) AS ", Cols[which(Types == "timestamp")]))
        star <- paste(star, collapse = " ")
      } else {
        ColNameVector <- c()
        for(z in BadCols) {
          if(z != BadCols) {
            ColNameVector <- c(ColNameVector, paste0("convert(varchar, ", Cols[which(Types == "timestamp")][z],", 23) AS ", Cols[which(Types == "timestamp")][z], ","))
          } else {
            ColNameVector <- c(ColNameVector, paste0("convert(varchar, ", Cols[which(Types == "timestamp")][z],", 23) AS ", Cols[which(Types == "timestamp")][z]))
            ColNameVector <- paste(ColNameVector, collapse = " ")
            Colss <- c(Colss, ColNameVector)
            star <- paste(Colss, collapse = " ")
          }
        }
      }
    }

    # Build Query ----
    if(is.null(Query)) {
      Query <- paste0("SELECT ", star, " FROM ", TableName)
      Query <- gsub("[\r\n]", "", Query)
    } else {
      Query <- gsub(pattern = "\\*", replacement = star, x = Query)
      Query <- gsub("[\r\n]", "", Query)
    }
  }

  # Create shell script ----
  CommandString <- paste0("bcp ", Query,
                          " queryout ",
                          file.path(SavePath, SaveFileName),
                          " -S ",
                          Server, " -T -d ", DBName, " -C RAW -c")

  # bcp pull ----
  ShellStartTime <- Sys.time()
  shell(CommandString)
  ShellEndTime <- Sys.time()
  print("Warehouse to text file run time of: ", ShellEndTime - ShellStartTime)

  # Load data into R ----
  data <- data.table::fread(file = file.path(SavePath, SaveFileName))

  # Add column names to data ----
  if(exists("Colsss")) {
    data.table::setnames(data, c(names(data)), c(eval(Colsss)))
  } else {
    data.table::setnames(data, c(names(data)), c(eval(as.character(FinalColumnNames))))
  }

  # Delete text file ----
  if(DeleteTextFile) {

    # Prepare path ----
    Path <- file.path(SavePath, SaveFileName)
    Path <- gsub("/", "\\", Path, fixed = TRUE)
    Path <- paste0("del ", Path)

    # Run shell command ----
    DeleteTextFileStart <- Sys.time()
    shell(Path)
    DeleteTextFileEnd <- Sys.time()
    print(paste0("Delete text file run time of: ", DeleteTextFileEnd - DeleteTextFileStart))
  }

  # Return data ----
  return(data)
}

#' @title SQL_Server_BulkPush
#'
#' @description Push data to a sql server warehouse via bulk copy process
#'
#' @family Database
#'
#' @author Adrian Antico
#'
#' @param Server Server name
#' @param DBName Name of the database
#' @param TableName Name of the table to pull
#' @param SavePath Path file to where you want the text file saved
#' @param SaveFileName Name of the text file to create
#' @param DeleteTextFile Remove text file when done loading into R
#'
#' @export
SQL_Server_BulkPush <- function(Server = NULL,
                                DBName = NULL,
                                TableName = NULL,
                                SavePath = NULL,
                                SaveFileName = NULL,
                                DeleteTextFile = TRUE) {

  # Command Script ----
  CommandScript <- paste0(
    "bcp ", DBName,
    ".", TableName,
    " in ", file.path(SavePath, SaveFileName),
    " -c -T -S ", Server)

  # Push data ----
  PushStartTime <- Sys.time()
  shell(CommandScript)
  PushEndTime <- Sys.time()
  print(paste0("Bulk insert run time of: ", PushEndTime - PushStartTime))

  # Delete text file ----
  if(DeleteTextFile) {

    # Command Script ----
    Path <- file.path(SavePath, SaveFileName)
    Path <- gsub("/", "\\", Path)
    Path <- paste0("del ", Path)

    # Run command ----
    DeleteStartTime <- Sys.time()
    shell(Path)
    DeleteEndTime <- Sys.time()
    print(paste0("Delete text file run time of: ", DeleteEndTime - DeleteStartTime))
  }
}
