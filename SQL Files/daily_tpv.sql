declare @start as date , @end as date , @now as date;

set @now	= getdate()						-- Today
set @end	= dateadd(d,-1,@now)	-- Yesterday
set @start	= dateadd(d,0,@end)	-- Yesterday minus one

select
    txn.PostDate_R as Date , c.Vertical,         
    sum(txn.amount) Txn_Amount, count(*) as Txn_Count
from                      
    YapstoneDM.dbo.[Transaction] txn with (nolock)                        
    inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId   
where    1 = 1                 
		and txn.PostDate_R between @start and @end            
		and txn.ProcessorId not in (14,16)                    
		and txn.TransactionCycleId in (1)  
		and txn.PlatformId in (1) -- No HA-Intl for now        
group by
	txn.PostDate_R, c.Vertical