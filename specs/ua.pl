use strict;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->proxy(['http', 'https'] => 'http://localhost:8080');
$ua->get('http://52.52.224.143/em/api/v2/systems?name=Parabank');
