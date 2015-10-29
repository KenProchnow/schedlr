
declare @start as date, @end as date, @dates as nvarchar(max), @query as nvarchar(max);

set @start           = '2014-01-01'
set @end             =  cast(DATEADD(ss, -1, DATEADD(month, DATEDIFF(month, 0, getdate()), 0)) as DATE)




if object_id('tempdb..#CapacitySub') is not null drop table #CapacitySub
select year(txn.postdate_r) Year, month(txn.postdate_r) Month ,
       c.PlatformId ,  c.ParentAccountId, c.ParentName , yc.Capacity
       into #CapacitySub
from
       YapstoneDM..[Transaction] txn
       inner join ETLStaging..FinanceParentTable c on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId 
       inner join YapstoneDM..Company yc on c.PlatformId = yc.PlatformId and c.ChildAccountId = yc.AccountId
where
       txn.postdate_r between @start and @end
       and c.PlatformId in (1)
       and c.Vertical in ('Rent','Dues')
       and c.ChildAccountId not in ('85-88710976')
       and c.ParentAccountId not in ('15-44066397')
       and yc.isActive = 1
group by year(txn.postdate_r) , month(txn.postdate_r)  ,
       c.PlatformId ,  c.ParentAccountId, c.ParentName, yc.Capacity
       
if object_id('tempdb..#Capacity') is not null drop table #Capacity
select cs.Year, cs.Month, cs.PlatformId, cs.ParentAccountId, cs.ParentName, sum(cs.Capacity) Capacity
       into #Capacity
from
       #CapacitySub cs
group by cs.Year, cs.Month, cs.PlatformId, cs.ParentAccountId, cs.ParentName


if object_id('tempdb..#Report') is not null drop table #Report
select   year(txn.postdate_r) Year, month(txn.postdate_r) Month, 
	dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R), 0)) as Date ,
	txn.PlatformId ,
    c.Vertical,  c.ParentAccountId, c.ParentName ,   isnull(Capacity.Capacity,0) Capacity ,
    count(distinct(txn.Ref_PersonId)) as PeopleTransacting ,                      
   case when pt.Name in ('Visa','Master Card','Discover','Visa Debit','MC Debit') then 'Card' when pt.Name in ('eCheck','Scan')        then 'ACH' else 'Other' end PaymentType ,
    sum(txn.amount) Txn_Amount, count(*) as Txn_Count
    into #Report
from                       
    YapstoneDM.dbo.[Transaction] txn with (nolock)                         
    inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId                        
    inner join #Capacity Capacity on c.PlatformId = Capacity.PlatformId and c.ParentAccountId = Capacity.ParentAccountId and Capacity.Year = year(txn.PostDate_r) and Capacity.Month = month(txn.PostDate_r)
    inner join YapstoneDM..PaymentType pt on txn.PaymentTypeId = pt.PaymentTypeId
where    1 = 1                  
       and txn.PostDate_R between @start and @end             
       and txn.ProcessorId not in (14,16)                     
       and txn.TransactionCycleId in (1)               
       and txn.PlatformId in (1)                
       and c.Vertical in ('Rent','Dues') 
group by      
    year(txn.postdate_r) , month(txn.postdate_r) , 
    dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R), 0)) ,
    txn.PlatformId , c.Vertical,                       
    c.ParentAccountId,     c.ParentName , isnull(Capacity.Capacity,0),
       case when pt.Name in ('Visa','Master Card','Discover','Visa Debit','MC Debit') then 'Card' when pt.Name in ('eCheck','Scan')        then 'ACH' else 'Other' end
      
       
      
if object_id('tempdb..#Parents') is not null drop table #Parents

select 
	cast(Date as date) Date ,
       Vertical, ParentName,
       isnull(Capacity,0) Capacity ,
       sum(PeopleTransacting) TotalPeople
 into #Parents
from #Report

where  1 =1
       and Vertical in ('Rent','Dues')
       
group by  Date, Vertical , ParentName, isnull(Capacity,0)

select @dates = stuff((select ',' + quotename(colName) from (
       select distinct(Date) as colName 
       from #Parents
       ) sub order by colName for xml path(''), type).value('.', 'nvarchar(max)'),1,1,'')


set @query = '
select * from (
select Date,Vertical,ParentName,[%] from (
select *
        ,convert(decimal(10,2),case when Capacity <> 0 and TotalPeople <> 0 then cast(TotalPeople as decimal(10,2))/ cast(Capacity as decimal(10,2)) * 100 else 0 end) as [%] 
from #Parents
where Vertical in (''Rent'')
) src
group by Date, Vertical,ParentName,[%]
) src
pivot ( 
	sum([%])
	for [Date] in ('+@dates+')
) pt
'

exec sp_executesql @query