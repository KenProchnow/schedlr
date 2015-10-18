
declare @start as date = '2015-01-01' , @now as date,
@end as date,  
@PaymentTypeGroup as nvarchar(max) 

set @now   = getdate()    -- Today
set @end = dateadd(d,-1 , dateadd(mm,(year(@now)- 1900) * 12 + month(@now) - 1 , 0))

-- Temp Tables
if object_id('tempdb..#PaymentTypeGroup') is not null drop table #PaymentTypeGroup
create table #PaymentTypeGroup (PaymentType nvarchar(max), PaymentTypeGroup nvarchar(max))

set @PaymentTypeGroup = '
insert into #PaymentTypeGroup select ''Discover'',''Credit''
insert into #PaymentTypeGroup select ''NYCE'',''Debit''
insert into #PaymentTypeGroup select ''Master Card'',''Credit''
insert into #PaymentTypeGroup select ''Visa'',''Credit''
insert into #PaymentTypeGroup select ''American Express'',''AmEx''
insert into #PaymentTypeGroup select ''Pulse'',''Debit''
insert into #PaymentTypeGroup select ''Visa Debit'',''Debit''
insert into #PaymentTypeGroup select ''Cash'',''Cash''
insert into #PaymentTypeGroup select ''eCheck'',''ACH''
insert into #PaymentTypeGroup select ''Star'',''Debit''
insert into #PaymentTypeGroup select ''Scan'',''ACH''
insert into #PaymentTypeGroup select ''Debit Card'',''Debit''
insert into #PaymentTypeGroup select ''MC Debit'',''Debit'''
exec sp_executesql @PaymentTypeGroup



select 
	cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R), 0)) as date) as Date ,
	c.ParentAccountId, c.ParentName , ptg.PaymentTypeGroup,
	sum(txn.Amount) as TPV, sum(txn.AmtNetConvFee) as ConvFee_Revenue, count(*) as Txn_Count

from
	YapstoneDM..[Transaction] txn
	join ETLStaging..FinanceParentTable c on txn.PlatformId = c.PlatformId and txn.Ref_CompanyId = c.ChildCompanyId
	join YapstoneDM..PaymentType pt on txn.PaymentTypeId = pt.PaymentTypeId
	left join #PaymentTypeGroup ptg on pt.Name = ptg.PaymentType
where
	txn.PostDate_R between @start and @end
	and txn.TransactionCycleId in (1)
	and txn.ProcessorId not in (14,16)
	and c.Vertical in ('Rent')
	and txn.AmtNetConvFee <> 0 -- Conv Fee
	and txn.PlatformId in (1)
group by
    cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R), 0)) as date) ,
	c.ParentAccountId, c.ParentName , ptg.PaymentTypeGroup

        
