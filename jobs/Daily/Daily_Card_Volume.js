var 
  parse = require('./../../parse.js').parseSQL,
  query = require('./../../query.js').executeQuery,
  format = require('./../../lib/format.js').cleanData,
  html = true, // send results as html?
  folder = 'Daily',
  file = 'Daily_Card_Volume'
  ; 

if (html) { var email = require('./../../email.js').email; } else { var email = require('./../../lib/email_library/email.js').email; }
 
parse(folder, file, function(sql){
  query(sql, file, function(data, file){
    email(data, file);  
  });
});
