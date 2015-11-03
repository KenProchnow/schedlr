
-- HA Visa Promotion Query 
declare @pivot as date

set @pivot	= '2015-10-20' 

if object_id('tempdb..#AllPropertyOwners') is not null drop table #AllPropertyOwners
select 
	c.PlatformId,
	c.AccountId PropertyOwnerAccountId, c.Name PropertyOwnerName, ha.propertyId HomeAwayPropertyId,
	(isnull(c.Address_Street1, ' ')+' '+isnull(c.Address_Street2,' ')) StreetAddress, isnull(c.Address_City,' ') City, isnull(c.Address_StateProvince,' ') State, isnull(c.Address_PostalCode,' ') Zip
	into #AllPropertyOwners	
from 
	YapstoneDM..Company c
	inner join haReportsTemp..Community ct on c.PlatformId = 3 and c.CompanyId = ct.Id and ct.classId in (19)
	left join haReportsTemp..HAProperty ha on ct.code = ha.code and ha.externalid = ct.ext1   
where 1=1
	and c.PlatformId = 3
	and c.AggregateId like '1|2|1001|______'  -- Property Owner level only
group by
	c.PlatformId,
	c.AccountId, c.Name,
	(isnull(c.Address_Street1, ' ')+' '+isnull(c.Address_Street2,' ')) , isnull(c.Address_City,' ') ,isnull(c.Address_StateProvince,' '),isnull(c.Address_PostalCode,' '),
	ha.propertyId 
	
--select * from #AllPropertyOwners where PropertyOwnerAccountId = '56-32989893'	
	
if object_id('tempdb..#NotEligible')is not null drop table #NotEligible     
select
	c.PlatformId, 
	txn.Ref_CompanyId PropertyCompanyId, 
	c.PropertyOwnerAccountId, c.PropertyOwnerName
	into #NotEligible
from
	ETLStaging..FinanceHAPropertyOwners c
	inner join YapstoneDM..[Transaction] txn on txn.PlatformId = c.PlatformId and txn.Ref_CompanyId = c.ChildCompanyId
where
	c.PlatformId = 3
	and txn.TransactionCycleId = 1
	and txn.ProcessorId not in (14,16)
	and txn.PostDate_R < @pivot
group by
	c.PlatformId,
	txn.Ref_CompanyId,
	c.PropertyOwnerAccountId, c.PropertyOwnerName

--select  * from #NotEligible  where PropertyOwnerAccountId = '56-32989893'	

if object_id('tempdb..#Eligible')is not null drop table #Eligible     
select 
	AllPropertyOwners.PlatformId,
	AllPropertyOwners.PropertyOwnerAccountId, AllPropertyOwners.PropertyOwnerName,
	AllPropertyOwners.StreetAddress, AllPropertyOwners.City,AllPropertyOwners.State, AllPropertyOwners.Zip, 
	AllPropertyOwners.HomeAwayPropertyId
	into #Eligible
from 
	#AllPropertyOwners AllPropertyOwners 
	left join #NotEligible NotEligible on NotEligible.PropertyOwnerAccountId = AllPropertyOwners.PropertyOwnerAccountId and NotEligible.PlatformId = AllPropertyOwners.PlatformId
where
	NotEligible.PlatformId is null
group by
	AllPropertyOwners.PlatformId,
	AllPropertyOwners.PropertyOwnerAccountId, AllPropertyOwners.PropertyOwnerName,
	AllPropertyOwners.StreetAddress, AllPropertyOwners.City,AllPropertyOwners.State, AllPropertyOwners.Zip ,
	AllPropertyOwners.HomeAwayPropertyId

--select * from #Eligible where PropertyOwnerAccountId = '56-32989893'	


if object_id('tempdb..#Report') is not null drop table #Report
select 
	txn.PlatformId,
	ha.propertyId HomeawayPropertyId ,
	Eligible.PropertyOwnerAccountId, Eligible.PropertyOwnerName,
	Eligible.StreetAddress, Eligible.City,Eligible.State, Eligible.Zip,
	c.ChildAccountId as ListingAccountId, count(distinct(txn.IdClassId)) #of_Txns
	into #Report
from 
	#Eligible Eligible
	left join ETLStaging..FinanceHAPropertyOwners c on c.PlatformId = Eligible.PlatformId and c.PropertyOwnerAccountId = Eligible.PropertyOwnerAccountId
	left join YapstoneDM..[Transaction] txn on txn.PlatformId = c.PlatformId and txn.Ref_CompanyId = c.ChildCompanyId
	left join haReportsTemp..Community ct on c.PlatformId = 3 and c.ChildCompanyId = ct.Id and ct.classId in (19)
	left join haReportsTemp..HAProperty ha on ct.code = ha.code and ha.externalid = ct.ext1  
where
	txn.TransactionCycleId = 1
	and txn.PostDate_R >=@pivot
	and txn.PlatformId = 3	
group by 
	txn.PlatformId,
	Eligible.PropertyOwnerAccountId, Eligible.PropertyOwnerName,
	Eligible.StreetAddress, Eligible.City,Eligible.State, Eligible.Zip,
	c.ChildAccountId, ha.propertyId 
	
select 
	PropertyOwnerAccountId, PropertyOwnerName, StreetAddress, City, State, Zip,
	stuff((select cast(', '+ cast(HomeawayPropertyId as varchar(max)) as varchar(max))
		from #Report sub
		where sub.PropertyOwnerAccountId = Report.PropertyOwnerAccountId
		for xml path('')),1,2,'') as PropertyId
from 
	#Report Report
group by 
	PropertyOwnerAccountId, PropertyOwnerName, StreetAddress, City, State, Zip 