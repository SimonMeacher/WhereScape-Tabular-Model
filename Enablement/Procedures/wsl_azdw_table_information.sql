-- TemplateVersion:003 MinVersion:8210 MaxVersion:* TargetType:AzureDW ModelType:* ProcedureType:Block
--
-- (c) WhereScape Inc 2020. WhereScape Inc permits you to copy this SQL Block solely for use with the RED software, and to modify this Template
-- for the purposes of using that modified SQL Block with the RED software, but does not permit copying or modification for any other purpose.
--
-- =============================================================================
--
-- DBMS Name          : Azure SQL DW
-- Block Name         : wsl_azdw_table_information
-- RED Version        : 8.2.1.0
-- Description        : This SQL Block returns table information to be used in conjunction with the wsl_azdw_alter_ddl template
--
-- =============================================================================
--
--
-- Notes / History
--

SELECT table_catalog
     , table_schema
     , table_name
FROM information_schema.tables
WHERE UPPER(table_schema) = UPPER('$SCHEMA$')
AND UPPER(table_name) = UPPER('$TABLE$')
ORDER BY table_catalog, table_schema, table_name
;

SELECT table_catalog
     , table_schema
     , table_name
     , ordinal_position
     , column_name
     , CONCAT(data_type, CASE WHEN COALESCE(character_maximum_length
                                          , numeric_precision
                                          , datetime_precision
                                   ) IS NOT NULL
                              THEN CONCAT('('
                                         ,CONCAT(CAST(COALESCE(character_maximum_length
                                                             , numeric_precision
                                                             , datetime_precision
                                                      ) AS VARCHAR(20)
                                                 )
                                               , CONCAT(CASE WHEN numeric_scale IS NOT NULL
                                                             THEN CONCAT(', '
                                                                       , CAST(numeric_scale AS VARCHAR(20))
                                                                  )
                                                             ELSE ''
                                                        END
                                                       ,')'
                                                 )
                                          )
                                   )
                              ELSE ''
                         END
       ) data_type
    , 'NULLABLE'
    , 'Nullable'
    , COALESCE(IS_NULLABLE,'~~~~') AS IS_NULLABLE
FROM information_schema.columns
WHERE UPPER(table_schema) = UPPER('$SCHEMA$')
AND UPPER(table_name) = UPPER('$TABLE$')
ORDER BY table_catalog, table_schema, table_name, ordinal_position
;
