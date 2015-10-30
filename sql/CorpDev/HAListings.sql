
 declare @start date, @end date
 
set @start       = '2010-01-01'
set @end         = cast(dateadd(ss, -1, dateadd(month, datediff(month, 0, getdate()), 0)) as date)


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
 

if object_id('tempdb..#PPB_Commissions_Branch_HA') is not null drop table #PPB_Commissions_Branch_HA
select year(t.posted) year , month(t.posted) month ,
	cast(t.id as varchar) + ':' + cast(t.classId as varchar) CommissionsIdClassId ,
	'USD' Currency, mri.masterReferenceId ,  ct.accountId AccountId, 
	sum( cast(t.amount as decimal(18,2))/100 ) as PPB_Commissions_Volume, sum( cast(pf.amount as decimal)/100 ) as PPB_Commissions_Fees , count(*) as txn_count
	into #PPB_Commissions_Branch_HA
from 
	HAReportsTemp.dbo.Transfer t                                                                                                                                                                                  
	inner join HAReportsTemp.dbo.Invoice i on t.invoiceID = i.Id and t.invoiceClassID = i.classId           
	inner join HAReportsTemp.dbo.Propertyfee pf on pf.invoiceID = i.Id and pf.invoiceClassId = i.classId                                    inner join HAReportsTemp.dbo.PropertyFeeCategory pfc on pfc.Id = pf.propertyFeeCategoryId                
	inner join HAReportsTemp.dbo.Community ct on ct.id = t.BusinessEntity_companyId and ct.classId = t.BusinessEntity_companyClassId        inner join HAReportsTemp.dbo.Company c on c.Id = ct.id and c.classId = ct.classId
	inner join HAReportsTemp.dbo.LineItem li on li.invoiceId = i.id and li.invoiceClassId = i.classId                                       inner join HAReportsTemp.dbo.LineItemCategory lc on lc.id = li.categoryId and lc.classId = li.categoryClassId
	inner join HAReportsTemp.dbo.MasterReferenceInvoice mri on mri.invoiceId = i.id and mri.invoiceClassId = i.classId
	left join  rpReportsTemp.rp.CardBin cardbin  on left(t.uiaccountnumber,6) = cardbin.bin
where
	t.posted between @start and  dateadd(s,-1,dateadd(d,1,cast(@end as datetime)))
	and i.businessEntity_CompanyId not in (87868, 87739, 87862, 87872, 87858) -- eng. test properties
	and pfc.categoryDescription not like ('%Value Added Tax%')   -- only pay commissions on the ex-tax amount   
	and lc.name like '%PayPerBooking%'
	and ( ct.aggregateId like '1|2|125214%'
	)
    and i.status not in (0, 3, 4, 6)
    --and t.classId in (36, 39, 40, 41) -- cards/ach gross/refunds and i.classId in (47,105)
group by year(t.posted) , month(t.posted) ,
       mri.masterReferenceId, cast(t.id as varchar) + ':' + cast(t.classId as varchar) , ct.accountId
       
if object_id('tempdb..#PPB_Rent_Branch_HA') is not null drop table #PPB_Rent_Branch_HA
select year(t.posted) year , month(t.posted) month ,
	'USD' Currency, mri.masterReferenceId , 
	cast(t.id as varchar) + ':' + cast(t.classId as varchar) as RentIdClassId ,  ct.accountId as AccountId, 
	sum( cast(t.amount as decimal(18,2))/100 ) as PPB_Rent_Volume, sum( cast(pf.amount as decimal)/100 ) as PPB_Rent_Fees
	into #PPB_Rent_Branch_HA
from 
	HAReportsTemp.dbo.Transfer t                                                                                                                                                                                  
	inner join HAReportsTemp.dbo.Invoice i on t.invoiceID = i.Id and t.invoiceClassID = i.classId           
	inner join HAReportsTemp.dbo.Propertyfee pf on pf.invoiceID = i.Id and pf.invoiceClassId = i.classId                                                         inner join HAReportsTemp.dbo.PropertyFeeCategory pfc on pfc.Id = pf.propertyFeeCategoryId                
	inner join HAReportsTemp.dbo.Community ct on ct.id = t.BusinessEntity_companyId and ct.classId = t.BusinessEntity_companyClassId        inner join HAReportsTemp.dbo.Company c on c.Id = ct.id and c.classId = ct.classId
	inner join HAReportsTemp.dbo.LineItem li on li.invoiceId = i.id and li.invoiceClassId = i.classId                                                                  inner join HAReportsTemp.dbo.LineItemCategory lc on lc.id = li.categoryId and lc.classId = li.categoryClassId
	inner join HAReportsTemp.dbo.MasterReferenceInvoice mri on mri.invoiceId = i.id and mri.invoiceClassId = i.classId
	left join  rpReportsTemp.rp.CardBin cardbin  on left(t.uiaccountnumber,6) = cardbin.bin
where 
	t.posted between @start and   dateadd(s,-1,dateadd(d,1,cast(@end as datetime)))
    and i.status not in (0, 3, 4, 6)  -- to match the TS report in the web app 
    and i.businessEntity_CompanyId not in (87868, 87739, 87862, 87872, 87858) -- eng. test properties
    and pfc.categoryDescription not like ('%Value Added Tax%')   -- only pay commissions on the ex-tax amount   
    and lc.name not like '%PayPerBooking%'
    --and t.classId in (36, 39, 40, 41) -- cards/ach gross/refunds --and i.classId in (47,105)
group by year(t.posted) , month(t.posted) ,
       mri.masterReferenceId, 
       cast(t.id as varchar) + ':' + cast(t.classId as varchar) ,  ct.accountId

if object_id('tempdb..#PPB_Transfer_Ids') is not null drop table #PPB_Transfer_Ids
select inner_query.*
	into #PPB_Transfer_Ids
from ( 
	select CommissionsIdClassId IdClassId from #PPB_Commissions_Branch_HA union all
	select PPB_Rent_Branch.RentIdClassId IdClassId from #PPB_Commissions_Branch_HA PPB_Commissions_Branch
		left join #PPB_Rent_Branch_HA PPB_Rent_Branch on 
			PPB_Commissions_Branch.masterReferenceId = PPB_Rent_Branch.masterReferenceId and
			PPB_Commissions_Branch.Currency = PPB_Rent_Branch.Currency and
			PPB_Commissions_Branch.year = PPB_Rent_Branch.year and
			PPB_Commissions_Branch.month = PPB_Rent_Branch.month 
) inner_query

if object_id('tempdb..#Ancillary_Ids') is not null drop table #Ancillary_Ids
select year(t.posted) Year , month(t.posted) Month ,
	cast(t.id as varchar) + ':' + cast(t.classId as varchar) IdClassId ,
	'USD' Currency, mri.masterReferenceId ,  ct.accountId AccountId, 
	sum( cast(t.amount as decimal(18,2))/100 ) as Ancillary_Volume,  count(*) as txn_count
	into #Ancillary_Ids
from 
	HAReportsTemp.dbo.Transfer t                                                                                                                                                                                  
	inner join HAReportsTemp.dbo.Invoice i on t.invoiceID = i.Id and t.invoiceClassID = i.classId           
	/*inner join HAReportsTemp.dbo.Propertyfee pf on pf.invoiceID = i.Id and pf.invoiceClassId = i.classId */                                  /*inner join HAReportsTemp.dbo.PropertyFeeCategory pfc on pfc.Id = pf.propertyFeeCategoryId */               
	inner join HAReportsTemp.dbo.Community ct on ct.id = t.BusinessEntity_companyId and ct.classId = t.BusinessEntity_companyClassId        inner join HAReportsTemp.dbo.Company c on c.Id = ct.id and c.classId = ct.classId
	inner join HAReportsTemp.dbo.LineItem li on li.invoiceId = i.id and li.invoiceClassId = i.classId                                       inner join HAReportsTemp.dbo.LineItemCategory lc on lc.id = li.categoryId and lc.classId = li.categoryClassId
	inner join HAReportsTemp.dbo.MasterReferenceInvoice mri on mri.invoiceId = i.id and mri.invoiceClassId = i.classId
where
	t.posted between @start and   dateadd(s,-1,dateadd(d,1,cast(@end as datetime)))
	and i.businessEntity_CompanyId not in (87868, 87739, 87862, 87872, 87858) -- eng. test properties
	and ct.aggregateId like '1|2|1008|%'
    and i.status not in (0, 3, 4, 6)
    --and t.classId in (36, 39, 40, 41) -- cards/ach gross/refunds and i.classId in (47,105)
group by year(t.posted) , month(t.posted) ,
       mri.masterReferenceId, cast(t.id as varchar) + ':' + cast(t.classId as varchar) , ct.accountId

if object_id('tempdb..#Ancillary_Revenue') is not null drop table #Ancillary_Revenue
select
	Year, Month, 'HA' as Vertical, 'Ancillary' as Product_Type, 'USD' as Currency, 
	sum(Charge) Revenue
	into #Ancillary_Revenue
from
	ETLStaging..PropertyPaidBilling billing
where
	PlatformID in (3)
	and billing.Year between year(@start) and year(@end)
	and Charge > 0
group by
	Year, Month
 
if object_id('tempdb..#HA_Analytics_HA') is not null drop table #HA_Analytics_HA
select year(txn.PostDate_R) Year , month(txn.PostDate_R) Month , 
	cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R) , 0)) as date) Date ,
	'HA' as Vertical, 'USD' as CharCode ,
	case when PPB.IdClassId is not null then 'PPB' when Ancillary.IdClassId is not null then 'Ancillary' else 'PPS' end   Product_Type , 
	sum(txn.Amount) as TPV,  sum(txn.AmtNetPropFee) as Revenue, 
	sum(txn.Amount) as TPV_USD,  sum(txn.AmtNetPropFee) as Revenue_USD,
	count(*) as Txn_Count,
	sum(case when txn.PaymentTypeId in (1,2,3) then txn.Amount else 0 end) as Credit_Card_TPV_USD,
	count(distinct(c.AccountId)) #of_Merchants
	into #HA_Analytics_HA
from                                            
   YapstoneDM.dbo.[Transaction] txn
   inner join YapstoneDM.dbo.Company c		on txn.PlatformId = c.PlatformId and txn.Ref_CompanyId = c.CompanyId  
   left join #PPB_Transfer_Ids PPB			on txn.IdClassId = PPB.IdClassId and txn.PlatformId in (3)
   left join #Ancillary_Ids	Ancillary		on txn.IdClassId = Ancillary.IdClassId and txn.PlatformId in (3)
where             
	txn.PostDate_R between @start and @end 
	and txn.PlatformId in (3)
	and txn.PaymentTypeId in (1,2,3,11,12)
	and txn.TransactionCycleId in (1)
group by year(txn.PostDate_R) , month(txn.PostDate_R) ,  
	case when PPB.IdClassId is not null then 'PPB' when Ancillary.IdClassId is not null then 'Ancillary' else 'PPS' end   
order by  Year , Month, cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R) , 0)) as date)

if object_id('tempdb..#HA_Analytics_HA_Report') is not null drop table #HA_Analytics_HA_Report
select
	HA.Year, HA.Month, HA.Date, HA.Vertical, HA.CharCode, HA.Product_Type, HA.TPV, sum(HA.Revenue + isnull(Anc.Revenue,0)) Revenue, 
	HA.TPV_USD, sum(HA.Revenue + isnull(Anc.Revenue,0)) Revenue_USD, HA.Txn_Count , HA.Credit_Card_TPV_USD, HA.#of_Merchants
	into #HA_Analytics_HA_Report
from 
	#HA_Analytics_HA HA
	left join #Ancillary_Revenue Anc on HA.Year = Anc.Year and HA.Month = Anc.Month 
		and HA.Product_Type = Anc.Product_Type and HA.Vertical = Anc.Vertical
group by
	HA.Year, HA.Month, HA.Date, HA.Vertical, HA.CharCode, HA.Product_Type, HA.TPV, 
	HA.TPV_USD, HA.Txn_Count , HA.Credit_Card_TPV_USD, HA.#of_Merchants



if object_id('tempdb..#PPB_Commissions_Branch_GD1') is not null drop table #PPB_Commissions_Branch_GD1
select year(t.posted) year , month(t.posted) month , 
		cast(t.id as varchar) + ':' + cast(t.classId as varchar) CommissionsIdClassId ,
		Currency.CharCode Currency, mri.masterReferenceId , 
		ct.accountId AccountId, 
		sum( cast(t.amount as decimal(18,2))/100 ) as PPB_Commissions_Volume, /*sum( cast(pf.amount as decimal)/100 ) as PPB_Commissions_Fees ,*/ count(*) as txn_count
		into #PPB_Commissions_Branch_GD1
from 
		GD1ReportsTemp.dbo.Transfer t		inner join GD1ReportsTemp.dbo.Currency on Currency.id = t.currencyCode
		inner join GD1ReportsTemp.dbo.Invoice i on t.invoiceID = i.Id and t.invoiceClassID = i.classId	 
		--inner join GD1ReportsTemp.dbo.Propertyfee pf on pf.invoiceID = i.Id and pf.invoiceClassId = i.classId								inner join GD1ReportsTemp.dbo.PropertyFeeCategory pfc on pfc.Id = pf.propertyFeeCategoryId
		inner join GD1ReportsTemp.dbo.Community ct on ct.id = t.BusinessEntity_companyId and ct.classId = t.BusinessEntity_companyClassId	inner join GD1ReportsTemp.dbo.Company c on c.Id = ct.id and c.classId = ct.classId
		inner join GD1ReportsTemp.dbo.LineItem li on li.invoiceId = i.id and li.invoiceClassId = i.classId									inner join GD1ReportsTemp.dbo.LineItemCategory lc on lc.id = li.categoryId and lc.classId = li.categoryClassId
		inner join GD1ReportsTemp.dbo.MasterReferenceInvoice mri on mri.invoiceId = i.id and mri.invoiceClassId = i.classId
where
		t.posted between @start and  dateadd(s,-1,dateadd(d,1,cast(@end as datetime)))
		and i.status not in (4, 6)  -- to match the TS report in the web app
		and i.businessEntity_CompanyId not in (87868, 87739, 87862, 87872, 87858) -- eng. test properties
		--and pfc.categoryDescription not like ('%Value Added Tax%') -- only pay commissions on the ex-tax amount   
		and lc.name like '%PayPerBooking%'
		--and t.classId in (36,40) -- Gross Payments
		and ( ct.aggregateId like '1|87645|111105|%'
		)
		--and t.classId in (40, 36) -- credit card, ach gross payment
group by year(t.posted) , month(t.posted) ,  
		mri.masterReferenceId,
		cast(t.id as varchar) + ':' + cast(t.classId as varchar),
		ct.accountId, Currency.CharCode
       
if object_id('tempdb..#PPB_Rent_Branch_GD1') is not null drop table #PPB_Rent_Branch_GD1
select year(t.posted) year , month(t.posted) month , 
		Currency.CharCode Currency, mri.masterReferenceId , 
		cast(t.id as varchar) + ':' + cast(t.classId as varchar) as RentIdClassId ,
		ct.accountId as AccountId, 
		sum( cast(t.amount as decimal(18,2))/100 ) as PPB_Rent_Volume, sum( cast(pf.amount as decimal)/100 ) as PPB_Rent_Fees
		into #PPB_Rent_Branch_GD1
from 
		GD1ReportsTemp.dbo.Transfer t
		inner join GD1ReportsTemp.dbo.Invoice i on t.invoiceID = i.Id and t.invoiceClassID = i.classId				inner join GD1ReportsTemp.dbo.Currency on Currency.id = t.currencyCode
		inner join GD1ReportsTemp.dbo.Propertyfee pf on pf.invoiceID = i.Id and pf.invoiceClassId = i.classId		inner join GD1ReportsTemp.dbo.PropertyFeeCategory pfc on pfc.Id = pf.propertyFeeCategoryId
		inner join GD1ReportsTemp.dbo.Community ct on ct.id = t.BusinessEntity_companyId and ct.classId = t.BusinessEntity_companyClassId		inner join GD1ReportsTemp.dbo.Company c on c.Id = ct.id and c.classId = ct.classId
		inner join GD1ReportsTemp.dbo.LineItem li on li.invoiceId = i.id and li.invoiceClassId = i.classId			inner join GD1ReportsTemp.dbo.LineItemCategory lc on lc.id = li.categoryId and lc.classId = li.categoryClassId
		inner join GD1ReportsTemp.dbo.MasterReferenceInvoice mri on mri.invoiceId = i.id and mri.invoiceClassId = i.classId
where
		t.posted between @start and  dateadd(s,-1,dateadd(d,1,cast(@end as datetime)))
		and i.status not in (4, 6) -- to match the TS report in the web app
		and i.businessEntity_CompanyId not in (87868, 87739, 87862, 87872, 87858) -- eng. test properties
		and pfc.categoryDescription not like ('%Value Added Tax%') -- only pay commissions on the ex-tax amount   
		and lc.name not like '%PayPerBooking%'
		--and t.classId in (40, 36) -- credit card, ach gross payment
group by year(t.posted) , month(t.posted) ,
       mri.masterReferenceId,
       cast(t.id as varchar) + ':' + cast(t.classId as varchar) , 
       Currency.CharCode , ct.accountId
      
if object_id('tempdb..#PPB_Transfer_Ids_GD1') is not null drop table #PPB_Transfer_Ids_GD1
select inner_query.*
       into #PPB_Transfer_Ids_GD1
from ( 
       select CommissionsIdClassId IdClassId from #PPB_Commissions_Branch_GD1 union all
       select PPB_Rent_Branch.RentIdClassId IdClassId from #PPB_Commissions_Branch_GD1 PPB_Commissions_Branch
               left join #PPB_Rent_Branch_GD1 PPB_Rent_Branch on 
                      PPB_Commissions_Branch.masterReferenceId = PPB_Rent_Branch.masterReferenceId and
                      PPB_Commissions_Branch.Currency = PPB_Rent_Branch.Currency and
                      PPB_Commissions_Branch.year = PPB_Rent_Branch.year and
                      PPB_Commissions_Branch.month = PPB_Rent_Branch.month 
) inner_query


if object_id('tempdb..#HA_Analytics_GD1') is not null drop table #HA_Analytics_GD1
select year(txn.PostDate_R) Year , month(txn.PostDate_R) Month , 
	cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R) , 0)) as date) Date ,
	'HA-Intl' as Vertical, 
	Currency.CharCode ,
	case when PPB.IdClassId is not null then 'PPB'  else 'PPS' end   Product_Type ,  
	sum(txn.Amount) as TPV,  sum(txn.AmtNetPropFee) as Revenue,  
	sum(txn.Amount * fx.Rate) as TPV_USD,
	sum(txn.AmtNetPropFee ) as Revenue_USD, 
	count(*) as Txn_Count ,
	sum(case when txn.PaymentTypeId in (1,2,3) then txn.Amount else 0 end * fx.Rate) as Credit_Card_TPV_USD,
	count(distinct(c.AccountId)) #of_Merchants
	into #HA_Analytics_GD1
from                                            
   YapstoneDM.dbo.[Transaction] txn
   inner join YapstoneDM.dbo.Company c              on txn.PlatformId = c.PlatformId and txn.Ref_CompanyId = c.CompanyId  
   inner join YapstoneDM.dbo.Currency				on txn.CurrencyId = Currency.CurrencyId
   left join #PPB_Transfer_Ids_GD1 PPB              on txn.IdClassId = PPB.IdClassId and txn.PlatformId in (4)
   inner join #Rates fx on  txn.PostDate_R = fx.Date and txn.CurrencyId = fx.CurrencyId
where             
	txn.PostDate_R between @start and @end 
	and txn.PlatformId in (4)
	and txn.PaymentTypeId in (1,2,3,11,12)
	and txn.TransactionCycleId in (1)
group by year(txn.PostDate_R) , month(txn.PostDate_R) ,  cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R) , 0)) as date) , Currency.CharCode ,
       case when PPB.IdClassId is not null then 'PPB' else 'PPS' end   
order by  Year , Month

select * 
from #HA_Analytics_HA_Report
union
select * 
from #HA_Analytics_GD1






