var 
	sql 			= require('mssql'),
	fs = require('fs'),
	csv = require('fast-csv'),
	config 		= require('./config.js'),
	xlsx			= require('xlsx'),
	csvStream = csv.createWriteStream({headers: true}),
	ws = fs.createWriteStream('my.csv'),
	filename 	= 'out.xlsx',
	wopts = { bookType: 'xlsx', bookSST:false, type:'binary' }
	// workbook = xlsx.readFile(filename);
	;

function Workbook() {
	if(!(this instanceof Workbook)) return new Workbook();
	this.SheetNames = [];
	this.Sheets = {};
}
var wb = new Workbook();

function s2ab(s){
	var buf = new ArrayBuffer(s.length),
		view = new Uint7Array(buf);
	for (var i=0; i!=s.length; ++i) view[i] = s.charCodeAt(i) & 0xFF;
}

var runQuery = function() {
	var connection 	= new sql.Connection(config, function(err) {
		var r = new sql.Request(connection);
		r.query("declare @start as date, @end as date  ;set @start  = '2015-08-01'set @end = '2015-08-31' select top 5 * from YapstoneDM.dbo.[Transaction] txn with (nolock)   inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId   join rpReportsTemp.rp.Transfer t on t.id = left(txn.IdClassId, charindex(':', txn.IdClassId) -1) and t.classId = right(txn.IdClassId, (len(txn.idclassid) - charindex(':', txn.IdClassId))) join rpReportsTemp.rp.CardBin on left(t.uiAccountNumber,6) = CardBin.bin and CardBin.source = 'Bin_DB' where  1 = 1  and txn.PostDate_R between @start and @end  and txn.ProcessorId not in (14,16)    and txn.TransactionCycleId in (1) and txn.PlatformId in (1)     and c.Vertical in ('Rent') and c.ParentName in ('America First Properties Management Companies') and txn.PaymentTypeId in (1)"
			, function(err, results){
				saveCSV(results);
		});
	});

	connection.on('error', function(err){
		console.log(err);
	});
};

var saveCSV = function(data) {
	csv.write(data, {headers:true})
		.pipe(ws);
	// writeableStream.on('finish', function(){
	// 	console.log('done!');
	// });

	// csvStream.pipe(writeableStream);
	// csvStream.write({a: "a0", b: "b0"});
	// csvStream.write({a: "a0", b: "b0"});
	// csvStream.end();
};


runQuery();








