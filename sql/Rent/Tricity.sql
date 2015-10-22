declare @now as date , @start as date , @end as date , @ParentName as nvarchar(max) 

set @now       = getdate()    -- Today
set @start     = dateadd(mm,(year(@now)- 1900) * 12 + month(@now) - 1 - 1 , 0)  -- Yesterday minus one
set @end       = dateadd(d,-1 , dateadd(mm,(year(@now)- 1900) * 12 + month(@now) - 1 , 0))  -- Yesterday
set @ParentName = 'TRI CITY RENTALS PARENT'

if OBJECT_ID('tempdb.dbo.#capacitysub') is not null
drop table #capacitysub
;with CapacitySub as (
select 
level = 0
,c.Platformid
,c.parentCompanyId
,pc.Name ParentName
,pc.accountid ParentAccountId
,c.CompanyId
,c.name ChildName
,yc.accountid ChildAccountId
,c.vertical
,c.IsActive
,yc.Capacity
from etlstaging..companyparsedaggregateid (nolock) c 
 join yapstonedm..Company (Nolock) yc on c.CompanyId = yc.CompanyId and c.PlatformId = yc.platformid
join yapstonedm..Company (Nolock) pc on c.parentCompanyId = pc.CompanyId and c.PlatformId = pc.platformid
where c.name = @ParentName and c.PlatformId = 1
UNION ALL
select 
 level+1
,c.Platformid
,c.parentCompanyId
,pc.Name ParentName
,pc.accountid ParentAccountId
,c.CompanyId
,c.name ChildName
,yc.accountid ChildAccountId
,c.vertical
,c.IsActive
,yc.Capacity
from etlstaging..companyparsedaggregateid (nolock) c 
 join yapstonedm..Company (Nolock) yc on c.CompanyId = yc.CompanyId and c.PlatformId = yc.platformid
join yapstonedm..Company (Nolock) pc on c.parentCompanyId = pc.CompanyId and c.PlatformId = pc.platformid
join CapacitySub on c.parentCompanyId = CapacitySub.CompanyId 
 where c.PlatformId = 1 ) 

select * into #capacitysub from CapacitySub where IsActive = 1
       
if OBJECT_ID('tempdb.dbo.#capacity') is not null
drop table #capacity

select cs.PlatformId
       , cs.ParentAccountId
       , cs.ParentName 
       , cs.ChildAccountId
       , cs.ChildName
       ,sum(cs.Capacity) Capacity
   into #capacity
from
       #CapacitySub cs
group by cs.PlatformId
       , cs.ParentAccountId
       , cs.ParentName 
       , cs.ChildAccountId
       , cs.ChildName
       
       
if OBJECT_ID('tempdb.dbo.#txn') is not null
drop table #txn
select  
    txn.PlatformId
    ,txn.ref_companyid
    , count(distinct(txn.Ref_PersonId)) as PeopleTransacting
    , case when pt.Name in ('Visa','Master Card','Discover','American Express') then 'Credit'
                 when pt.Name in ('Visa Debit','MC Debit') then 'Debit' 
           when pt.Name in ('eCheck') then 'ACH'         -- Wayne I changed this
           when pt.Name in ('Scan') then 'Scan'             -- Wayne I changed this
           when pt.Name in ('Cash') then 'Cash'
           else 'Other' end PaymentType
    , sum(txn.amount) Txn_Amount, count(*) as Txn_Count
   into #txn
from  #CapacitySub c                       
      join YapstoneDM.dbo.[Transaction] (nolock) txn on  c.platformid = txn.PlatformId and c.companyId = txn.Ref_CompanyId                         
      left join YapstoneDM..PaymentType pt on txn.PaymentTypeId = pt.PaymentTypeId
where                 
       txn.PostDate_R between cast(@start as date) and cast(@end as date)
       and txn.ProcessorId not in (14,16)                     
       and txn.TransactionCycleId in (1)               
       and txn.PlatformId in (1)   
       and c.Vertical in ('Rent','Dues') 
group by      
    txn.PlatformId
    ,txn.ref_companyid
    , case when pt.Name in ('Visa','Master Card','Discover','American Express') then 'Credit'
                 when pt.Name in ('Visa Debit','MC Debit') then 'Debit' 
           when pt.Name in ('eCheck') then 'ACH'            -- Wayne I changed this
           when pt.Name in ('Scan') then 'Scan'             -- Wayne I changed this
           when pt.Name in ('Cash') then 'Cash'
           else 'Other' end 
           

if OBJECT_ID('tempdb.dbo.#report') is not null
drop table #report
select  
     c.PlatformId
    , c.Vertical
    , c.ParentAccountId
    , c.ParentName
    , c.ChildAccountId
    , c.ChildName
    , isnull(txn.PeopleTransacting,0) PeopleTransacting
    , isnull(txn.PaymentType,0) PaymentType
    , isnull(txn.Txn_Amount,0) Txn_Amount
    , isnull(txn.Txn_Count,0) Txn_Count
    into #report
from  #CapacitySub c                       
      left join #txn txn on  c.platformid = txn.PlatformId and c.companyId = txn.Ref_CompanyId
      where c.level >0  -- addresses hierarchy level, pulls only children
group by      
     c.PlatformId
    , c.Vertical
    , c.ParentAccountId
    , c.ParentName
    , c.ChildAccountId
    , c.ChildName
    , txn.PeopleTransacting
    , txn.PaymentType
    , txn.Txn_Amount
    , txn.Txn_Count
      
if OBJECT_ID('tempdb.dbo.#children') is not null
drop table #children
       select 
       txn.ChildName
       ,sum(case when PaymentType in ('Credit') then Txn_Amount else 0 end) Credit_Volume
       ,sum(case when PaymentType in ('Credit') then Txn_Count else 0 end) Credit_Count
       ,sum(case when PaymentType in ('Debit') then Txn_Amount else 0 end) Debit_Volume
       ,sum(case when PaymentType in ('Debit') then Txn_Count else 0 end) Debit_Count       
       ,sum(case when PaymentType in ('ACH') then Txn_Amount else 0 end) ACH_Volume   
       ,sum(case when PaymentType in ('ACH') then Txn_Count else 0 end) ACH_Count     
       ,sum(case when PaymentType in ('Scan') then Txn_Amount else 0 end) Scan_Volume 
       ,sum(case when PaymentType in ('Scan') then Txn_Count else 0 end) Scan_Count   
       ,sum(Txn_Amount) Total_Volume
       ,sum(Txn_Count) Total_Count
       ,sum(PeopleTransacting) as Distinct_Users_Transacting
       , Capacity
   into #children
from #Report txn
    inner join #Capacity c on txn.PlatformId = c.PlatformId and txn.ChildAccountId = c.ChildAccountId 
where  Vertical in ('Rent','Dues')
group by 
       txn.ChildName
      , Capacity
---original was trashing precision, is  formatted in SSRS, took to 4 for acccuracy

if object_id('tempdb..#ChildLevel') is not null drop table #ChildLevel
select * into #ChildLevel from (
select 
       *
      , convert(decimal(10,4)   
       ,case when Capacity <> 0 and Distinct_Users_Transacting <> 0 
        then cast(Distinct_Users_Transacting as decimal(10,4))/ cast(Capacity as decimal(10,4))  else 0 end)*100 as [%] 
from #Children
) src
order by ChildName asc

if object_id('tempdb..#Rollup') is not null drop table #Rollup
select * into #Rollup from (
  select 
       'Total' Name
       ,sum(case when PaymentType in ('Credit') then Txn_Amount else 0 end) Credit_Volume
       ,sum(case when PaymentType in ('Credit') then Txn_Count else 0 end) Credit_Count
       ,sum(case when PaymentType in ('Debit') then Txn_Amount else 0 end) Debit_Volume
       ,sum(case when PaymentType in ('Debit') then Txn_Count else 0 end) Debit_Count       
       ,sum(case when PaymentType in ('ACH') then Txn_Amount else 0 end) ACH_Volume   
       ,sum(case when PaymentType in ('ACH') then Txn_Count else 0 end) ACH_Count     
       ,sum(case when PaymentType in ('Scan') then Txn_Amount else 0 end) Scan_Volume 
       ,sum(case when PaymentType in ('Scan') then Txn_Count else 0 end) Scan_Count   
       ,sum(Txn_Amount) Total_Volume
       ,sum(Txn_Count) Total_Count
       ,sum(PeopleTransacting) as Distinct_Users_Transacting
       ,sum(Capacity) Capacity
       ,cast(sum(PeopleTransacting) as decimal(10,4))/cast(sum(Capacity) as decimal(10,4))*100 [%]
  from #Report txn
    inner join #Capacity c on txn.PlatformId = c.PlatformId and txn.ChildAccountId = c.ChildAccountId 
  where  Vertical in ('Rent','Dues')
) src

select * from #ChildLevel
union all
select * from #Rollup
