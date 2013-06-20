#!D:\Share\strawberry-perl\perl\bin\perl.exe
use Dancer ':syntax';
use FindBin '$RealBin';
use Plack::Handler::FCGI;

# For some reason Apache SetEnv directives dont propagate
# correctly to the dispatchers, so forcing PSGI and env here 
# is safer.
set apphandler => 'PSGI';
set environment => 'production';

my $psgi = path($RealBin, '..', 'bin', 'app.pl');
my $app = do($psgi);
my $server = Plack::Handler::FCGI->new(nproc => 5, detach => 1);

$server->run($app);
