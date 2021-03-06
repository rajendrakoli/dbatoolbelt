--http://www.mssqltips.com/sqlservertip/1681/gathering-status-and-detail-information-for-sql-server-full-text-catalogs/?utm_source=dailynewsletter&utm_medium=email&utm_content=headline&utm_campaign=2012124

set transaction isolation level read uncommitted
set nocount on
declare @tbl sysname
declare @cat sysname
create table #temp_ca( 
TABLE_OWNER varchar(100),
TABLE_NAME varchar(256),
FULLTEXT_KEY_INDEX_NAME varchar(256),
FULLTEXT_KEY_COLID int,
FULLTEXT_INDEX_ACTIVE int,
FULLTEXT_CATALOG_NAME varchar(256)
)
create table #temp_status(
Catalog varchar(64),
TblName varchar(64), 
[IsEnabled] bit,
ChangeTracking varchar(24),
PopulateStatus varchar(64),
RowCnt int,
FTS_CT int,
Delta int,
PercentCompleted varchar(128), 
path nvarchar(260)
)
insert into #temp_ca
exec sp_help_fulltext_tables 
declare ca_cursor cursor for
select TABLE_NAME, FULLTEXT_CATALOG_NAME from #temp_ca
open ca_cursor
fetch next from ca_cursor into @tbl, @cat
while @@fetch_STATUS = 0
begin
insert into #temp_status
select 
cast (@cat as varchar(40)) Catalog
, cast(object_name(si.id) as varchar(25)) TblName
, cast(OBJECTPROPERTY(tbl.id,'TableHasActiveFulltextIndex') as bit) as [IsEnabled]
, case isnull(OBJECTPROPERTY(tbl.id,'TableFullTextBackgroundUpdateIndexon'),0) 
+ ISNULL(OBJECTPROPERTY(tbl.id,'TableFullTextChangeTrackingon'),0) 
when 0 then 'Do not track changes'
when 1 then 'Manual'
when 2 then 'Automatic'
end [ChangeTracking]
, case FULLTEXTCATALOGPROPERTY ( @cat , 'PopulateStatus' ) 
when 0 then 'Idle' 
when 1 then 'Full population in progress'
when 2 then 'Paused' 
when 3 then 'Throttled' 
when 4 then 'Recovering' 
when 5 then 'Shutdown' 
when 6 then 'Incremental population in progress' 
when 7 then 'Building index' 
when 8 then 'Disk is full. Paused.'
when 9 then 'Change tracking'
end PopulateStatus
, si.RowCnt, fulltextcatalogproperty(@cat, 'ItemCount') FTS_CT 
, si.RowCnt - fulltextcatalogproperty(@cat, 'ItemCount') Delta 
, cast ( 100.0 * fulltextcatalogproperty(@cat, 'ItemCount') 
/ cast(si.RowCnt as decimal (14,2))
as varchar) +'%' as PercentCompleted
, ISNULL(cat.path, 'Check Default Path')
from 
dbo.sysobjects as tbl
INNER JOIN sysusers as stbl on stbl.uid = tbl.uid
INNER JOIN sysfulltextcatalogs as cat 
on (cat.ftcatid=OBJECTPROPERTY(tbl.id, 'TableFullTextCatalogId')) 
AND (1=CasT(OBJECTPROPERTY(tbl.id, 'TableFullTextCatalogId') as bit))
INNER JOIN sysindexes as si on si.id = tbl.id 
where si.indid in (0,1) and si.id = object_id(@tbl)
fetch next from ca_cursor into @tbl, @cat
end
close ca_cursor
deallocate ca_cursor
select * from #temp_status
drop table #temp_ca
drop table #temp_status