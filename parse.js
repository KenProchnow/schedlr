var 
	fs 	= require('fs')				
	, path = require('path')
	, data = ''
	, fileDir = './sql'
	;

var parseSQL = function(folder, file, cb){ 
	parseFile(folder, file, cb); 
};

var parseFile = function(folder, file, cb){
	var sqlFile 		= fs.createReadStream(path.join(fileDir, folder, file + '.sql'));

	sqlFile.on('data', function(chunk){ data+=chunk; });

	sqlFile.on('end', function() {
		cleanUp(data, cb);
	});

};

var cleanUp = function(sql,cb){
  sql.replace(/(\r\n|\n|\r)/gm," "); 	// remove newlines
  sql.replace(/\s+/g, ' '); 					// excess white space

  cb(sql);
};

exports.parseSQL = parseSQL;