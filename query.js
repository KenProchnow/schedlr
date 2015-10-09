var 
	fs = require('fs')		
	, path = require('path')
	, csv = require('fast-csv')
	, mssql = require('mssql')
	, db_config = require('./lib/config/database.js')
	, f = require('./lib/format.js')
	, outDir = './../csv'
	;

var executeQuery = function(sql, file, cb) {
	runQuery(sql, file, cb);
};

var runQuery = function(sql, file, cb) {
	var connection 	= new mssql.Connection(db_config, function(err) {
		if (err) console.log(err);
		var r = new mssql.Request(connection);

		r.query(sql, function(err, results){
			if (err) console.log(err);

			transform(results, file, cb);
		});
	});
};

var isDateOrAccountIdColumn = function(item) {
	re = /^((Year)|(Month)|(Date)|(AccountId)|(ParentAccountId)|(ChildAccountId)|(Year_First)|(Year_Last)|(12MonthsBeforeAttrited)|(DateFirstSeen)|(DateLastSeen))$/i

	return re.test(item) ? true : false;
} 

var transform = function(data, file, cb){
	for(var record in data){
		if (data.hasOwnProperty(record)){
			// console.log(data[record]); // logs records

			for(var item in data[record]){
				if(data[record].hasOwnProperty(item)){
					// console.log(data[record][item]);  // logs Values
					// console.log(item); // logs keys
					if (f.isDate(data[record][item])) {
						data[record][item] = f.formatDate(data[record][item]);
					}

					if ( (!isDateOrAccountIdColumn(item)) && !isNaN(parseFloat(data[record][item])) && !f.hasPercentString(data[record][item]) ) {
						data[record][item] = f.formatNumber(parseInt(data[record][item]));
					}
				}
			}

		}
	}

	saveCSV(data, file, cb);
};

var saveCSV = function(data, file, cb) {
	var outFile 		= path.join(outDir, file + '.csv');

	csv.writeToPath(outFile, data, {headers: true})
	.on('finish', function(){
		cb(file);
	});
};


exports.executeQuery = executeQuery;