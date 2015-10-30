declare @start as date, @end as date    
       
set @start = '2014-01-01'       
set @end   = '2015-09-30'    



if object_id('tempdb..#CurrencyCodes') is not null drop table #CurrencyCodes
select Currency.CharCode, Currency.CurrencyId into #CurrencyCodes
from YapstoneDM..Currency
group by Currency.CharCode, Currency.CurrencyId
  
if object_id('tempdb..#Dates') is not null drop table #Dates
select * into #Dates from (
       select txn.postDate_R Date, c.CharCode, c.CurrencyId 
       from   YapstoneDM..[Transaction] txn
       cross join (
               select Currency.CharCode, Currency.CurrencyId
               from YapstoneDM..Currency
               group by Currency.CharCode, Currency.CurrencyId
       ) c
       where  txn.PostDate_R between @start and @end
       group by txn.PostDate_R , c.CharCode, c.CurrencyId
) src
 
-- FX Rates
if object_id('tempdb..#EURUSD') is not null                drop table #EURUSD
select fx.Date, fx.ExchangeRate                                           into #EURUSD                
from YapstoneDM..CurrencyExchangeRate fx
where  BaseCurrencyId in (1) and fx.CounterCurrencyId in (3)
     and (   fx.Date between @start and @end  )
group by fx.Date, fx.ExchangeRate
if object_id('tempdb..#RatesPREPROCESSED') is not null                 drop table #RatesPREPROCESSED
select * into #RatesPREPROCESSED from (
     select isnull(fx.Date,d.Date) Date, isnull(Currency.CharCode,d.CharCode) CharCode, isnull(Currency.CurrencyId,d.CurrencyId) CurrencyId,
                      1 / ( fx.ExchangeRate / usd.ExchangeRate ) Rate
     from #Dates d left join YapstoneDM..CurrencyExchangeRate fx  on d.Date = fx.Date
               left join YapstoneDM..Currency on fx.CounterCurrencyId = Currency.CurrencyId
               left join #EURUSD usd on fx.Date = usd.Date
     where  (   d.Date between @start and @end )
     group by  isnull(fx.Date,d.Date) , isnull(Currency.CharCode,d.CharCode) , isnull(Currency.CurrencyId,d.CurrencyId)
                      , 1 / ( fx.ExchangeRate / usd.ExchangeRate )
     union
       select isnull(fx.Date,d.Date) Date, d.CharCode, d.CurrencyId ,fx.ExchangeRate                     
       from   #Dates d left join YapstoneDM..CurrencyExchangeRate fx  on d.Date = fx.Date and d.CurrencyId = fx.BaseCurrencyId
               and BaseCurrencyId in (1) and fx.CounterCurrencyId in (3)
               left join YapstoneDM..Currency on fx.CounterCurrencyId = Currency.CurrencyId
       where  d.CurrencyId in (1)
               and  (   d.Date between @start and @end  )
       group by isnull(fx.Date,d.Date) , d.CharCode, d.CurrencyId, fx.ExchangeRate
) src
order by Date asc
 
 
if object_id('tempdb..#FallbackRates') is not null drop table #FallBackRates
select * into #FallbackRates from (
       select 'EUR' CharCode, 1.35 as Rate union select 'GBP', 1.6 union select 'CAD', 0.9 union select 'USD', 1
) src
 
if object_id('tempdb..#Rates') is not null                 drop table #Rates
select Date,src.CharCode,CurrencyId,isnull(src.Rate,fallback.Rate) Rate  into #Rates from (
       select Date,CharCode,CurrencyId,(
               select top 1 Rate
               from   #RatesPREPROCESSED r1
               where  r1.Date <= r.Date
                              and r1.Rate is not null
                              and r1.CharCode = r.CharCode
               order by r1.Date desc
       ) Rate
       from #RatesPREPROCESSED r
) src left join #FallBackRates fallback on fallback.CharCode = src.CharCode
 

if object_id('tempdb..#MonthlyBilled') is not null drop table #MonthlyBilled
select 
    cast(dateadd(d, -1 , dateadd(mm, (billing.Year - 1900) * 12 + billing.Month, 0)) as date) as Date,
    billing.PlatformId BillingPlatformId , c.Vertical BillingVertical ,
    c.ChildAccountId BillingChildAccountId, c.ChildName BillingChildName, 
    SUM(isnull(billing.charge,0)) PP_Revenue ,
    c.DateFirstSeen, c.DateLastSeen         
    into #MonthlyBilled
from
        ETLStaging.dbo.PropertyPaidBilling billing
        inner join ETLStaging.dbo.FinanceParentTable c on billing.PlatformID = c.PlatformId and billing.ChildAccountID = c.ChildAccountId
where
    billing.Year between year(@start) and year(@end) 
group by
      cast(dateadd(d, -1 , dateadd(mm, (billing.Year - 1900) * 12 + billing.Month, 0)) as date),
      billing.PlatformId , c.Vertical ,c.ChildAccountId, c.ChildName , c.DateFirstSeen, c.DateLastSeen
        
--select * from #MonthlyBilled 

if object_id('tempdb..#TxnTable') is not null drop table #TxnTable   
select 
    cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R), 0)) as date) as Date ,
        txn.PlatformId txnPlatformId,   c.Vertical txnVertical,  
        c.ChildAccountId txnChildAccountId, c.ChildName txnChildName,
    sum(AmtNetConvFee * fx.Rate) Conv_Fee_Revenue ,
    SUM(txn.AmtNetPropFee * fx.Rate) Net_Settled_Revenue
    into #TxnTable 
from  
    YapstoneDM.dbo.[Transaction] txn with (nolock)   inner join YapstoneDM.dbo.PaymentType pt with (nolock) on pt.PaymentTypeId = txn.PaymentTypeId
        inner join ETLStaging.dbo.FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId 
        inner join YapstoneDM.dbo.Currency cur with (nolock) on cur.CurrencyId = txn.CurrencyId  
        inner join YapstoneDM.dbo.Company on Company.PlatformId = c.PlatformId and Company.AccountId = c.ChildAccountId
   inner join #Rates fx on  txn.PostDate_R = fx.Date and txn.CurrencyId = fx.CurrencyId
where
        txn.ProcessorId not in (14,16)
        and txn.TransactionCycleId in (1)     
        and txn.PaymentTypeId not in (14,16) -- no cash  
        and txn.PostDate_R between  @start and @end 
        --and c.ParentAccountId = '75-92131049'
group by      
    cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R), 0)) as date),  
        txn.PlatformId,c.ChildAccountId, c.ChildName, c.Vertical
        
 --select * from #TxnTable

if object_id('tempdb..#Revenue') is not null drop table #Revenue
select     
  isnull(txn.Date,billing.Date) Date,
        sum(isnull(billing.PP_Revenue,0)) PP_Revenue,
        sum(isnull(txn.Conv_Fee_Revenue,0)) Conv_Fee_Revenue,
        sum(isnull(txn.Net_Settled_Revenue,0)) Net_Settled_Revenue
        into #Revenue
from
        #TxnTable txn    
        full outer join #MonthlyBilled billing on billing.Date = txn.Date and billing.BillingPlatformId = txn.txnPlatformId 
                        and billing.BillingChildAccountId = txn.txnChildAccountId
group by        
  isnull(txn.Date,billing.Date)

select * from #Revenue order by 1



