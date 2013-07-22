package LoadThread::SiteConfig;

our $HOST = '111.111.111.111';
our $USERNAME = 'testuser';
our $PASSWORD = 'testpasswd';
our $DATABASE='testdbname';

our $MYSQL = "mysql -h$HOST -u$USERNAME -p$PASSWORD $DATABASE";
our $DSN      = "DBI:mysql:host=$HOST;database=$DATABASE";

our $SITE = 'http://www.xxx.com';

our $CHARSET  = 'gbk';

our $USER_EMAIL  = 'test@test.test';
our $USER_PASSWD = 'justfortest';
our $USER_IP     = '88.88.88.88';
our @SALT_CHARS  = ( 0 .. 9, 'a' .. 'z' );

our $FILE_CHARSET = 'utf8';
1;
