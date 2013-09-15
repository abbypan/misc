//var casper = require('casper').create({logLevel: 'debug', verbose: true});
var casper = require('casper').create({
  pageSettings: {
        loadImages:  false,        // do not load images
        loadPlugins: false         // do not load NPAPI plugins (Flash, Silverlight, ...)
    }
}
);
casper.userAgent('Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:18.0) Gecko/20130119 Firefox/18.0');
var fs = require('fs');

var usr = casper.cli.get(0);
var passwd = casper.cli.get(1);
var cookie_file = casper.cli.get(2);

console.log("login baidu" );

var login_url = 'https://passport.baidu.com/v2/?login&amp;tpl=mn&amp;u=http%3A%2F%2Fwww.baidu.com%2F';
casper.start(login_url);
casper.wait(1000, function(){
    this.click('#pass-user-login');
});

casper.thenEvaluate(function(usr,passwd) {
    document.querySelector('#TANGRAM__3__userName').setAttribute('value', usr);
    document.querySelector('#TANGRAM__3__password').setAttribute('value', passwd);
}, { 'usr' : usr, 'passwd' : passwd });
casper.wait(1000, function () {
    this.click('#TANGRAM__3__submit');
});

casper.wait(1000, function () {
    var cookies = JSON.stringify(phantom.cookies);
    fs.write(cookie_file, cookies, 644);
    console.log("write cookie file : " + cookie_file );
});

casper.run();
