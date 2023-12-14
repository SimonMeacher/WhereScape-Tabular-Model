-- ProcedureVersion:003 MinVersion:8210 MaxVersion:* TargetType:AzureDW ModelType:* ProcedureType:Procedure

 CREATE TRIGGER azuredw_trg_ind_to_nonunique
 ON ws_index_header
 AFTER INSERT,UPDATE
 AS
 BEGIN
   UPDATE ws_index_header
   SET    ih_unique = 'N'
   FROM   inserted
   JOIN   ws_index_header
   ON     inserted.ih_index_key = ws_index_header.ih_index_key
 END
