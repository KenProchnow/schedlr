var 
  parse = require('./../../parse.js').parseSQL,
  query = require('./../../query.js').executeQuery,
  format = require('./../../lib/format.js').cleanData,
	html = false, // send results as html?
  folder = 'Misc',
  file = 'test'
  ; 

if (html) { var email = require('./../../email.js').email; } else { var email = require('./../../lib/email_library/email.js').email; }
 
parse(folder, file, function(sql){
  query(sql, folder, file, function(data, folder, file){
    email(data, folder, file);  
  });
});